import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/reel_model.dart';
import '../services/reels_service.dart';
import '../services/supabase_service.dart';
import '../utils/url_helper.dart';
import '../widgets/comments_sheet.dart';

class ReelsScreen extends StatefulWidget {
  final bool isActive;
  const ReelsScreen({super.key, this.isActive = true});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen>
    with AutomaticKeepAliveClientMixin {
  final ReelsService _reelsService = ReelsService();
  final SupabaseService _supabase = SupabaseService();
  final PageController _pageController = PageController();
  final FocusNode _keyboardFocusNode =
      FocusNode(debugLabel: 'reels-feed-focus');

  final Map<int, VideoPlayerController> _videoControllers =
      <int, VideoPlayerController>{};
  final Set<int> _controllerSetupInProgress = <int>{};
  final Set<int> _failedControllerIndexes = <int>{};
  final Map<int, int> _controllerRetryAttempts = <int, int>{};
  final Map<String, bool> _captionExpanded = {};

  List<Reel> _reels = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isMuted = true;
  bool _isFollowLoading = false;
  bool _isCommentsOpen = false;
  bool _isNavigating = false;
  Timer? _navigationUnlockTimer;
  String? _error;
  Map<String, String>? _mediaHeaders;
  Future<void> _poolOps = Future<void>.value();
  int _poolGeneration = 0;
  bool _autoplayKickScheduled = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final cached = _reelsService.getReels();
    if (cached.isNotEmpty) {
      _reels = cached;
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _reels.isEmpty || !widget.isActive) return;
        _poolOps = _poolOps.then<void>((_) async {
          await _initializePoolAt(_currentIndex);
          if (!mounted) return;
          await _activateCurrentReelPlayback();
          if (mounted) setState(() {});
        }).catchError((_) {});
      });
    }
    _loadReels();
  }

  @override
  void dispose() {
    _navigationUnlockTimer?.cancel();
    _keyboardFocusNode.dispose();
    _pageController.dispose();
    _disposeAllControllers();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (_reels.isEmpty || _currentIndex < 0 || _currentIndex >= _reels.length) {
      return;
    }
    if (widget.isActive) {
      _poolOps = _poolOps.then<void>((_) async {
        if (_controllerForIndex(_currentIndex) == null) {
          await _initializePoolAt(_currentIndex);
        }
        await _activateCurrentReelPlayback();
      }).catchError((_) {});
    } else {
      for (final controller in _videoControllers.values) {
        unawaited(_setControllerVolumeSafely(controller, 0));
      }
      _disposeAllControllers();
    }
  }

  Future<void> _loadReels() async {
    final hasCached = _reelsService.getReels().isNotEmpty;
    setState(() {
      _isLoading = !hasCached;
      _error = null;
    });

    try {
      final reels = await _reelsService.fetchReels(limit: 20, offset: 0);
      if (!mounted) return;

      setState(() {
        _reels = reels;
        _currentIndex = 0;
        _isLoading = false;
      });

      if (_reels.isNotEmpty) {
        unawaited(_reelsService.incrementViews(_reels.first.id));
        if (!widget.isActive) return;
        _poolOps = _poolOps.then<void>((_) async {
          await _initializePoolAt(_currentIndex);
          if (!mounted) return;
          await _activateCurrentReelPlayback();
          if (mounted) setState(() {});
        }).catchError((_) {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _reels.isEmpty ? e.toString() : null;
      });
    } finally {
      if (mounted && _reels.isEmpty) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _disposeController(VideoPlayerController? controller, int? index) {
    if (controller == null) return;
    try {
      unawaited(controller.dispose());
      debugPrint('[Reels] controller disposed index=$index');
    } catch (_) {}
  }

  void _disposeAllControllers() {
    _poolGeneration++;
    for (final entry in _videoControllers.entries) {
      _disposeController(entry.value, entry.key);
    }
    _videoControllers.clear();
    _controllerSetupInProgress.clear();
  }

  VideoPlayerController? _controllerForIndex(int index) =>
      _videoControllers[index];

  Future<VideoPlayerController?> _createControllerForIndex(
    int index, {
    required int generation,
  }) async {
    if (index < 0 || index >= _reels.length) return null;
    final existing = _videoControllers[index];
    if (existing != null) return existing;
    if (_controllerSetupInProgress.contains(index)) return null;
    _controllerSetupInProgress.add(index);
    final reel = _reels[index];
    final url = UrlHelper.absoluteUrl(reel.videoUrl);
    if (url.isEmpty) {
      _controllerSetupInProgress.remove(index);
      return null;
    }

    try {
      await _ensureMediaHeaders();
      if (!mounted) return null;
      final headerCandidates = _playbackHeaderCandidates(url);
      Object? lastError;
      for (final headers in headerCandidates) {
        VideoPlayerController? controller;
        try {
          debugPrint(
            '[Reels] preparing source index=$index id=${reel.id} url=$url authHeader=${headers.containsKey('Authorization')}',
          );
          controller = VideoPlayerController.networkUrl(
            Uri.parse(url),
            httpHeaders: headers,
          );
          await controller.initialize();
          if (!mounted || generation != _poolGeneration) {
            await controller.dispose();
            return null;
          }
          await controller.setLooping(true);
          await controller.setVolume(_isMuted ? 0 : 1);
          _videoControllers[index] = controller;
          debugPrint('[Reels] video initialized index=$index id=${reel.id}');
          if (mounted) {
            setState(() {});
          }
          if (index == _currentIndex && widget.isActive) {
            unawaited(controller.play().catchError((_) {}));
          }
          _failedControllerIndexes.remove(index);
          _controllerRetryAttempts.remove(index);
          debugPrint('[Reels] controller created index=$index id=${reel.id}');
          return controller;
        } catch (e) {
          lastError = e;
          try {
            await controller?.dispose();
          } catch (_) {}
        }
      }
      _failedControllerIndexes.add(index);
      debugPrint(
        '[Reels] controller create failed index=$index id=${reel.id} url=$url error=$lastError',
      );
      return null;
    } finally {
      _controllerSetupInProgress.remove(index);
    }
  }

  Future<void> _ensureMediaHeaders() async {
    if (_mediaHeaders != null) return;
    final token = await ApiClient().getToken();
    final headers = <String, String>{'User-Agent': 'ReelsScreen-App'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    _mediaHeaders = headers;
  }

  Map<String, String> _headersForUrl(String url) {
    // React web uses plain <video src="..."> without auth headers for media.
    // Keep parity and avoid 403s on media/CDN URLs that reject bearer auth.
    return const {};
  }

  List<Map<String, String>> _playbackHeaderCandidates(String url) {
    final candidates = <Map<String, String>>[const <String, String>{}];
    final authHeaders = _mediaHeaders;
    if (authHeaders != null && authHeaders.containsKey('Authorization')) {
      candidates.add(Map<String, String>.from(authHeaders));
    }
    return candidates;
  }

  Future<void> _initializePoolAt(int index) async {
    if (index < 0 || index >= _reels.length) return;
    if (!widget.isActive) return;
    final generation = ++_poolGeneration;
    _currentIndex = index;
    final next = index + 1 < _reels.length ? index + 1 : null;
    final keep = <int>{index, if (next != null) next};

    final remove = _videoControllers.keys.where((k) => !keep.contains(k)).toList();
    for (final k in remove) {
      _disposeController(_videoControllers.remove(k), k);
    }

    // Prioritize current reel startup first, then warm neighbors in background.
    await _createControllerForIndex(index, generation: generation);
    if (next != null) {
      unawaited(_createControllerForIndex(next, generation: generation));
    }
    if (_controllerForIndex(index) == null) {
      _scheduleControllerRetry(index);
    }
  }

  Future<void> _rotatePoolToIndex(int newIndex) async {
    if (newIndex < 0 || newIndex >= _reels.length) return;
    if (!widget.isActive) return;
    await _initializePoolAt(newIndex);
    if (!mounted) return;
    await _activateCurrentReelPlayback();
  }

  Future<void> _pauseControllerForIndex(int index) async {
    final controller = _controllerForIndex(index);
    if (controller == null) return;
    try {
      await controller.pause();
      await controller.seekTo(Duration.zero);
    } catch (_) {}
  }

  Future<void> _setControllerVolumeSafely(
    VideoPlayerController? controller,
    double volume,
  ) async {
    if (controller == null) return;
    try {
      await controller.setVolume(volume);
    } catch (_) {}
  }

  Future<void> _playControllerForIndex(int index) async {
    final controller = _controllerForIndex(index);
    if (controller == null) return;
    try {
      await controller.setVolume(widget.isActive && !_isMuted ? 1 : 0);
      if (!mounted || _controllerForIndex(index) != controller) return;
      if (widget.isActive) {
        await controller.play();
        debugPrint(
          '[Reels] video started playing index=$index id=${_reels[index].id}',
        );
      }
    } catch (e) {
      debugPrint(
        '[Reels] play failed index=$index id=${_reels[index].id} error=$e',
      );
    }
  }

  Future<void> _activateCurrentReelPlayback() async {
    if (!widget.isActive) return;
    final index = _currentIndex;
    if (_controllerForIndex(index) == null) {
      await _initializePoolAt(index);
    }
    if (!mounted || index != _currentIndex) return;
    final otherIndexes = _videoControllers.keys.where((k) => k != index).toList();
    for (final i in otherIndexes) {
      await _pauseControllerForIndex(i);
    }
    await _playControllerForIndex(index);
  }

  void _onPageChanged(int index) {
    if (_reels.isEmpty || index < 0 || index >= _reels.length) return;
    setState(() {
      _currentIndex = index;
    });
    unawaited(_reelsService.incrementViews(_reels[index].id));
    _poolOps = _poolOps
        .then<void>((_) => _rotatePoolToIndex(index))
        .catchError((_) {});
  }

  void _scheduleControllerRetry(int index) {
    final attempts = _controllerRetryAttempts[index] ?? 0;
    if (attempts >= 2) {
      if (index == _currentIndex && _reels.length > 1) {
        final nextIndex = (_currentIndex + 1) % _reels.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _goToIndex(nextIndex);
        });
      }
      return;
    }
    _controllerRetryAttempts[index] = attempts + 1;
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      if (index != _currentIndex) return;
      if (_controllerForIndex(index) != null) return;
      unawaited(() async {
        await _initializePoolAt(index);
        if (!mounted) return;
        await _activateCurrentReelPlayback();
        if (mounted) setState(() {});
      }());
    });
  }

  Future<void> _retryCurrentReel() async {
    if (_reels.isEmpty) return;
    final idx = _currentIndex;
    _failedControllerIndexes.remove(idx);
    _controllerRetryAttempts.remove(idx);
    setState(() {});
    await _initializePoolAt(idx);
    if (!mounted) return;
    await _activateCurrentReelPlayback();
    if (mounted) setState(() {});
  }

  Future<void> _toggleLike() async {
    if (_reels.isEmpty) return;
    final reelId = _reels[_currentIndex].id;
    try {
      await _reelsService.toggleLike(reelId);
      if (!mounted) return;
      setState(() {
        _reels = _reelsService.getReels();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reels = _reelsService.getReels();
      });
    }
  }

  Future<void> _toggleSave() async {
    if (_reels.isEmpty) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save posts')),
        );
      }
      return;
    }
    final reelId = _reels[_currentIndex].id;
    try {
      await _reelsService.toggleSave(reelId);
      if (!mounted) return;
      setState(() {
        _reels = _reelsService.getReels();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reels = _reelsService.getReels();
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_reels.isEmpty) return;
    if (_isFollowLoading) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to follow users')),
        );
      }
      return;
    }

    final reel = _reels[_currentIndex];
    final userId = reel.userId;
    if (userId.trim().isEmpty) return;

    final wasFollowing = reel.isFollowing;
    setState(() {
      _isFollowLoading = true;
    });

    _reelsService.toggleFollow(userId);
    setState(() {
      _reels = _reelsService.getReels();
    });

    try {
      final ok = wasFollowing
          ? await _supabase.unfollowUser(userId)
          : await _supabase.followUser(userId);
      if (!ok) {
        throw Exception('follow_update_failed');
      }
    } catch (_) {
      _reelsService.toggleFollow(userId);
      if (mounted) {
        setState(() {
          _reels = _reelsService.getReels();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow status')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowLoading = false;
        });
      }
    }
  }

  Future<void> _openComments() async {
    if (_reels.isEmpty) return;
    setState(() {
      _isCommentsOpen = true;
    });
    try {
      final postId = _reels[_currentIndex].id;
      final isDesktop = MediaQuery.of(context).size.width >= 768;
      if (isDesktop) {
        await showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Comments',
          barrierColor: Colors.black.withValues(alpha: 0.50),
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, _, __) {
            final height = MediaQuery.of(context).size.height * 0.78;
            return SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 84),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 340,
                      height: height.clamp(0.0, 640.0),
                      child: CommentsSheet(postId: postId),
                    ),
                  ),
                ),
              ),
            );
          },
          transitionBuilder: (context, animation, _, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            );
          },
        );
      } else {
        await CommentsSheet.show(context, postId);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCommentsOpen = false;
        });
      }
    }
  }

  Future<void> _shareCurrent() async {
    if (_reels.isEmpty) return;
    unawaited(_reelsService.incrementShares(_reels[_currentIndex].id));
    final url = _buildShareUrl(_reels[_currentIndex].id);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reel link copied')),
    );
  }

  void _goToIndex(int index) {
    if (_isCommentsOpen) return;
    if (_isNavigating) return;
    if (index < 0 || index >= _reels.length) return;
    _isNavigating = true;
    _navigationUnlockTimer?.cancel();
    _navigationUnlockTimer = Timer(const Duration(milliseconds: 500), () {
      _isNavigating = false;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _scheduleAutoplayKick() {
    if (_autoplayKickScheduled) return;
    _autoplayKickScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoplayKickScheduled = false;
      if (!mounted || !widget.isActive || _reels.isEmpty) return;
      final controller = _controllerForIndex(_currentIndex);
      if (controller == null || !controller.value.isInitialized) {
        if (_controllerSetupInProgress.contains(_currentIndex)) return;
        _poolOps = _poolOps
            .then<void>((_) => _rotatePoolToIndex(_currentIndex))
            .catchError((_) {});
        return;
      }
      if (!controller.value.isPlaying) {
        _poolOps = _poolOps
            .then<void>((_) => _activateCurrentReelPlayback())
            .catchError((_) {});
      }
    });
  }

  String _buildShareUrl(String reelId) {
    try {
      final apiUri = Uri.parse(ApiConfig.baseUrl);
      final scheme = apiUri.scheme.isEmpty ? 'https' : apiUri.scheme;
      final apiHost = apiUri.host;
      final appHost = apiHost.startsWith('api.')
          ? 'app.${apiHost.substring(4)}'
          : 'app.bebsmart.online';
      return '$scheme://$appHost/reels/$reelId';
    } catch (_) {
      return 'https://app.bebsmart.online/reels/$reelId';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _scheduleAutoplayKick();
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(height: 12),
              Text('Loading reels...',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_error != null && _reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Failed to load reels',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _loadReels,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child:
              Text('No reels found', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent || _isCommentsOpen) return;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _goToIndex(_currentIndex + 1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _goToIndex(_currentIndex - 1);
          }
        },
        child: Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent || _isCommentsOpen) return;
            if (event.scrollDelta.dy.abs() < 20) return;
            _goToIndex(
              event.scrollDelta.dy > 0 ? _currentIndex + 1 : _currentIndex - 1,
            );
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_keyboardFocusNode.hasFocus) {
                _keyboardFocusNode.requestFocus();
              }
            },
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: Stack(
                children: [
                  if (!isDesktop)
                    _buildVideoCard(isDesktop: false)
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: SizedBox(
                                width: 380,
                                child: _buildVideoCard(isDesktop: true),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 28, bottom: 26),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _buildDesktopActions(),
                          ),
                        ),
                      ],
                    ),
                  if (isDesktop) _buildDesktopArrows(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard({required bool isDesktop}) {
    final current = _reels[_currentIndex];

    return ClipRRect(
      borderRadius: isDesktop ? BorderRadius.circular(20) : BorderRadius.zero,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              itemCount: _reels.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return _buildReelPlayer(
                  index,
                  _reels[index],
                  isDesktop: isDesktop,
                );
              },
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 280,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(0, 0, 0, 0.0),
                        Color.fromRGBO(0, 0, 0, 0.62),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 60,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isMuted = !_isMuted;
                  });
                  final volume = _isMuted ? 0.0 : 1.0;
                  for (final controller in _videoControllers.values) {
                    unawaited(_setControllerVolumeSafely(controller, volume));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (!isDesktop)
              Positioned(
                right: 10,
                bottom: 10,
                child: _buildMobileActions(current),
              ),
            Positioned(
              left: 12,
              right: isDesktop ? 14 : 66,
              bottom: isDesktop ? 20 : 18,
              child: _buildBottomInfo(current),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelPlayer(int index, Reel reel, {required bool isDesktop}) {
    final controller = _controllerForIndex(index);
    final thumb = reel.thumbnailUrl == null
        ? null
        : UrlHelper.absoluteUrl(reel.thumbnailUrl!);
    final aspectRatio = _aspectRatioForReel(reel);

    return _ReelPlayerItem(
      key: ValueKey('reel-item-$index-${reel.id}'),
      controller: controller,
      thumbnailUrl: thumb,
      headers:
          thumb == null || thumb.isEmpty ? const {} : _headersForUrl(thumb),
      aspectRatio: aspectRatio,
      isFailed: _failedControllerIndexes.contains(index),
      onRetry: index == _currentIndex ? _retryCurrentReel : null,
    );
  }

  double _aspectRatioForReel(Reel reel) {
    final ratio = reel.aspectRatio?.trim();
    if (ratio == '1:1') return 1.0;
    if (ratio == '16:9') return 16 / 9;
    if (ratio == '4:5') return 4 / 5;
    if (ratio == '9:16') return 9 / 16;
    if (ratio != null) {
      final parts = ratio.split(':');
      if (parts.length == 2) {
        final w = double.tryParse(parts[0]);
        final h = double.tryParse(parts[1]);
        if (w != null && h != null && h > 0) return w / h;
      }
    }
    return 9 / 16;
  }

  Widget _buildMobileActions(Reel reel) {
    return Column(
      children: [
        _buildMobileAction(
          icon: reel.isLiked ? Icons.favorite : LucideIcons.heart,
          count: _formatCount(reel.likes),
          color: reel.isLiked ? Colors.red : Colors.white,
          onTap: _toggleLike,
        ),
        const SizedBox(height: 18),
        _buildMobileAction(
          icon: LucideIcons.messageCircle,
          count: _formatCount(reel.comments),
          onTap: () => unawaited(_openComments()),
        ),
        const SizedBox(height: 18),
        IconButton(
          onPressed: () => unawaited(_shareCurrent()),
          icon: const Icon(LucideIcons.send, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        const Icon(LucideIcons.ellipsis, color: Colors.white, size: 24),
        const SizedBox(height: 12),
        _buildAvatarThumb(reel, size: 36),
      ],
    );
  }

  Widget _buildMobileAction({
    required IconData icon,
    required String count,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 26),
        ),
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopActions() {
    final reel = _reels[_currentIndex];

    Widget circleButton({
      required VoidCallback onTap,
      required Widget child,
      bool active = false,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF3B82F6)
                : Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: active
                  ? const Color(0xFF60A5FA)
                  : Colors.white.withValues(alpha: 0.22),
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(child: child),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circleButton(
          onTap: _toggleLike,
          child: Icon(
            reel.isLiked ? Icons.favorite : LucideIcons.heart,
            size: 21,
            color: reel.isLiked ? Colors.red : Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(_formatCount(reel.likes),
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 14),
        circleButton(
          onTap: () => unawaited(_openComments()),
          child: const Icon(LucideIcons.messageCircle,
              size: 21, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(_formatCount(reel.comments),
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 14),
        circleButton(
          onTap: () => unawaited(_shareCurrent()),
          child: const Icon(LucideIcons.send, size: 21, color: Colors.white),
        ),
        const SizedBox(height: 14),
        circleButton(
          onTap: _toggleSave,
          child: Icon(
            reel.isSaved ? Icons.bookmark : Icons.bookmark_border,
            size: 21,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        circleButton(
          onTap: () {},
          child:
              const Icon(LucideIcons.ellipsis, size: 21, color: Colors.white),
        ),
        const SizedBox(height: 10),
        _buildAvatarThumb(reel, size: 36),
      ],
    );
  }

  Widget _buildAvatarThumb(Reel reel, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white54, width: 1.4),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: reel.userAvatarUrl != null && reel.userAvatarUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: UrlHelper.absoluteUrl(reel.userAvatarUrl!),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _avatarFallback(reel),
            )
          : _avatarFallback(reel),
    );
  }

  Widget _avatarFallback(Reel reel) {
    final ch = reel.userName.isEmpty ? 'U' : reel.userName[0].toUpperCase();
    return Container(
      color: const Color(0xFFF97316),
      alignment: Alignment.center,
      child: Text(
        ch,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottomInfo(Reel reel) {
    final isExpanded = _captionExpanded[reel.id] ?? false;
    final caption = reel.caption ?? '';
    final words = caption.trim().isEmpty
        ? <String>[]
        : caption.trim().split(RegExp(r'\s+'));
    final isLong = words.length > 5;
    final preview = isLong ? words.take(5).join(' ') : caption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.grey[700],
              backgroundImage:
                  reel.userAvatarUrl != null && reel.userAvatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(
                          UrlHelper.absoluteUrl(reel.userAvatarUrl!))
                      : null,
              child: reel.userAvatarUrl == null || reel.userAvatarUrl!.isEmpty
                  ? Text(
                      (reel.userName.isEmpty ? 'U' : reel.userName[0])
                          .toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reel.userName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: _isFollowLoading ? null : () => unawaited(_toggleFollow()),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: reel.isFollowing ? Colors.white30 : Colors.white54,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                child: Text(
                  _isFollowLoading
                      ? '...'
                      : (reel.isFollowing ? 'Following' : 'Follow'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (caption.isNotEmpty)
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, height: 1.35),
              children: [
                TextSpan(text: isExpanded || !isLong ? caption : preview),
                if (isLong)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _captionExpanded[reel.id] = !isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Text(
                          isExpanded ? 'less' : '... more',
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (reel.hashtags.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            reel.hashtags.map((t) => '#$t').join(' '),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(LucideIcons.music2, color: Colors.white, size: 11),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Original Audio - ${reel.userName}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopArrows() {
    final canGoUp = _currentIndex > 0;
    final canGoDown = _currentIndex < _reels.length - 1;

    Widget arrowButton(
        {required bool enabled,
        required IconData icon,
        required VoidCallback onTap}) {
      return GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.25,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      );
    }

    return Positioned(
      right: 20,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            arrowButton(
              enabled: canGoUp,
              icon: Icons.keyboard_arrow_up,
              onTap: () => _goToIndex(_currentIndex - 1),
            ),
            const SizedBox(height: 10),
            arrowButton(
              enabled: canGoDown,
              icon: Icons.keyboard_arrow_down,
              onTap: () => _goToIndex(_currentIndex + 1),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}

class _ReelPlayerItem extends StatefulWidget {
  final VideoPlayerController? controller;
  final String? thumbnailUrl;
  final Map<String, String> headers;
  final double aspectRatio;
  final bool isFailed;
  final VoidCallback? onRetry;

  const _ReelPlayerItem({
    super.key,
    required this.controller,
    required this.thumbnailUrl,
    required this.headers,
    required this.aspectRatio,
    required this.isFailed,
    required this.onRetry,
  });

  @override
  State<_ReelPlayerItem> createState() => _ReelPlayerItemState();
}

class _ReelPlayerItemState extends State<_ReelPlayerItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final thumbnailUrl = widget.thumbnailUrl;
    final controller = widget.controller;
    final isInitialized = controller?.value.isInitialized == true;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      httpHeaders: widget.headers,
                      errorWidget: (_, __, ___) =>
                          Container(color: Colors.black),
                    )
                  else
                    Container(color: Colors.black),
                  if (controller != null && isInitialized)
                    FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!isInitialized)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.isFailed)
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    else
                      const Icon(
                        Icons.wifi_tethering_error_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isFailed ? 'Could not load reel' : 'Loading reel',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (widget.isFailed && widget.onRetry != null) ...[
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: widget.onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white12,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
