import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/reel_model.dart';
import '../services/reels_service.dart';
import '../utils/url_helper.dart';
import 'reel_comments_screen.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final ReelsService _reelsService = ReelsService();
  final PreloadPageController _pageController = PreloadPageController();

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _isInitializing = {};
  final Map<String, bool> _hasError = {};
  final Map<String, bool> _captionExpanded = {};

  List<Reel> _reels = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isMuted = true;
  String? _error;
  Map<String, String>? _mediaHeaders;

  @override
  void initState() {
    super.initState();
    _loadReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeAllControllers();
    super.dispose();
  }

  Future<void> _loadReels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reels = await _reelsService.fetchReels(limit: 20, offset: 0);
      if (!mounted) return;

      setState(() {
        _reels = reels;
        _currentIndex = 0;
      });

      if (_reels.isNotEmpty) {
        unawaited(_reelsService.incrementViews(_reels.first.id));
        await _ensureControllerForIndex(0);
        unawaited(_ensureControllerForIndex(1));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _disposeAllControllers() {
    for (final c in _controllers.values) {
      _cleanupController(c);
    }
    _controllers.clear();
    _isInitializing.clear();
    _hasError.clear();
  }

  void _cleanupController(VideoPlayerController? c) {
    if (c == null) return;
    try {
      c.pause();
      c.setVolume(0);
      c.dispose();
    } catch (_) {}
  }

  Future<void> _ensureControllerForIndex(int index) async {
    if (index < 0 || index >= _reels.length) return;

    final reel = _reels[index];
    final url = UrlHelper.absoluteUrl(reel.videoUrl);
    if (url.isEmpty) return;

    if (_controllers.containsKey(reel.id)) {
      final c = _controllers[reel.id]!;
      if (c.value.isInitialized) {
        c.setVolume(_isMuted ? 0 : 1);
        if (index == _currentIndex) {
          unawaited(c.play());
        }
      }
      return;
    }

    if (_isInitializing[reel.id] == true) return;
    _isInitializing[reel.id] = true;
    _hasError[reel.id] = false;

    try {
      await _ensureMediaHeaders();
      if (!mounted) return;

      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _headersForUrl(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      _controllers[reel.id] = c;
      await c.initialize();
      if (!mounted) return;

      c.setLooping(true);
      c.setVolume(_isMuted ? 0 : 1);
      if (index == _currentIndex) {
        unawaited(c.play());
      }

      setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError[reel.id] = true;
        final c = _controllers.remove(reel.id);
        _cleanupController(c);
      });
    } finally {
      _isInitializing[reel.id] = false;
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
    final headers = _mediaHeaders;
    if (headers == null || headers.isEmpty) return const {};
    if (!headers.containsKey('Authorization')) return const {};

    try {
      final uri = Uri.parse(url);
      final baseUri = Uri.parse(ApiConfig.baseUrl);
      if (uri.host == baseUri.host) return headers;
    } catch (_) {}

    if (url.startsWith('http://localhost') || url.startsWith('http://10.0.2.2')) {
      return headers;
    }
    return const {};
  }

  void _onPageChanged(int index) {
    if (_reels.isEmpty || index < 0 || index >= _reels.length) return;

    if (_currentIndex >= 0 && _currentIndex < _reels.length) {
      final prevId = _reels[_currentIndex].id;
      _controllers[prevId]?.pause();
      _controllers[prevId]?.seekTo(Duration.zero);
    }

    setState(() {
      _currentIndex = index;
    });

    unawaited(_reelsService.incrementViews(_reels[index].id));

    final keepIds = <String>{
      _reels[index].id,
      if (index + 1 < _reels.length) _reels[index + 1].id,
    };

    final toDispose = _controllers.keys.where((id) => !keepIds.contains(id)).toList();
    for (final id in toDispose) {
      final c = _controllers.remove(id);
      _cleanupController(c);
      _isInitializing.remove(id);
      _hasError.remove(id);
    }

    unawaited(_ensureControllerForIndex(index));
    unawaited(_ensureControllerForIndex(index + 1));
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

  void _toggleFollow() {
    if (_reels.isEmpty) return;
    _reelsService.toggleFollow(_reels[_currentIndex].userId);
    setState(() {
      _reels = _reelsService.getReels();
    });
  }

  void _openComments() {
    if (_reels.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReelCommentsScreen(reel: _reels[_currentIndex]),
      ),
    );
  }

  void _shareCurrent() {
    if (_reels.isEmpty) return;
    unawaited(_reelsService.incrementShares(_reels[_currentIndex].id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reel link copied')),
    );
  }

  void _goToIndex(int index) {
    if (index < 0 || index >= _reels.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(height: 12),
              Text('Loading reels...', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
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
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
          child: Text('No reels found', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: Colors.black,
      body: MediaQuery.removePadding(
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
            PreloadPageView.builder(
              controller: _pageController,
              preloadPagesCount: 2,
              scrollDirection: Axis.vertical,
              itemCount: _reels.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return _buildReelPlayer(_reels[index], isDesktop: isDesktop);
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
                  for (final c in _controllers.values) {
                    if (c.value.isInitialized) {
                      c.setVolume(_isMuted ? 0 : 1);
                    }
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

  Widget _buildReelPlayer(Reel reel, {required bool isDesktop}) {
    final controller = _controllers[reel.id];
    final isInitialized = controller != null && controller.value.isInitialized;
    final hasError = _hasError[reel.id] ?? false;
    final thumb = reel.thumbnailUrl == null ? null : UrlHelper.absoluteUrl(reel.thumbnailUrl!);
    final mobileAspect = _mobileAspectForReel(reel);

    return SizedBox.expand(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frameHeight = isDesktop
              ? constraints.maxHeight
              : (constraints.maxWidth / mobileAspect).clamp(0.0, constraints.maxHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: frameHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumb != null && thumb.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: thumb,
                          fit: BoxFit.contain,
                          httpHeaders: _headersForUrl(thumb),
                          errorWidget: (_, __, ___) => Container(color: Colors.black),
                        )
                      else
                        Container(color: Colors.black),

                      if (isInitialized)
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

              if (!isInitialized && !hasError)
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                  ),
                ),

              if (hasError)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white70, size: 32),
                      const SizedBox(height: 10),
                      const Text('Could not load video', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () {
                          final idx = _reels.indexWhere((r) => r.id == reel.id);
                          if (idx != -1) {
                            _hasError[reel.id] = false;
                            final c = _controllers.remove(reel.id);
                            _cleanupController(c);
                            unawaited(_ensureControllerForIndex(idx));
                            setState(() {});
                          }
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _mobileAspectForReel(Reel reel) {
    final ratio = reel.aspectRatio?.trim();
    if (ratio == '1:1') return 1 / 1;
    if (ratio == '16:9') return 16 / 9;
    if (ratio == '4:5') return 4 / 5;
    return 9 / 16;
  }

  Widget _buildMobileActions(Reel reel) {
    return Column(
      children: [
        _buildMobileAction(
          icon: LucideIcons.heart,
          count: _formatCount(reel.likes),
          color: reel.isLiked ? Colors.red : Colors.white,
          onTap: _toggleLike,
        ),
        const SizedBox(height: 18),
        _buildMobileAction(
          icon: LucideIcons.messageCircle,
          count: _formatCount(reel.comments),
          onTap: _openComments,
        ),
        const SizedBox(height: 18),
        IconButton(
          onPressed: _shareCurrent,
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
            color: active ? const Color(0xFF3B82F6) : Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: active ? const Color(0xFF60A5FA) : Colors.white.withValues(alpha: 0.22),
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
            LucideIcons.heart,
            size: 21,
            color: reel.isLiked ? Colors.red : Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(_formatCount(reel.likes), style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 14),
        circleButton(
          onTap: _openComments,
          child: const Icon(LucideIcons.messageCircle, size: 21, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(_formatCount(reel.comments), style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 14),
        circleButton(
          onTap: _shareCurrent,
          child: const Icon(LucideIcons.send, size: 21, color: Colors.white),
        ),
        const SizedBox(height: 14),
        circleButton(
          onTap: _toggleSave,
          child: Icon(LucideIcons.bookmark, size: 21, color: reel.isSaved ? Colors.white : Colors.white),
        ),
        const SizedBox(height: 14),
        circleButton(
          onTap: () {},
          child: const Icon(LucideIcons.ellipsis, size: 21, color: Colors.white),
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
    final words = caption.trim().isEmpty ? <String>[] : caption.trim().split(RegExp(r'\s+'));
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
              backgroundImage: reel.userAvatarUrl != null && reel.userAvatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(UrlHelper.absoluteUrl(reel.userAvatarUrl!))
                  : null,
              child: reel.userAvatarUrl == null || reel.userAvatarUrl!.isEmpty
                  ? Text(
                      (reel.userName.isEmpty ? 'U' : reel.userName[0]).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reel.userName,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!reel.isFollowing)
              GestureDetector(
                onTap: _toggleFollow,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  child: const Text(
                    'Follow',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (caption.isNotEmpty)
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
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
                          style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
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

    Widget arrowButton({required bool enabled, required IconData icon, required VoidCallback onTap}) {
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
