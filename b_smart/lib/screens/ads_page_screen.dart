import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'dart:math' as math;
import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../models/ad_model.dart';
import '../models/ad_category_model.dart';
import '../services/ads_service.dart';
import '../services/supabase_service.dart';
import '../state/feed_actions.dart';
import '../state/store.dart';
import '../utils/current_user.dart';

class AdsPageScreen extends StatefulWidget {
  const AdsPageScreen({super.key});

  @override
  State<AdsPageScreen> createState() => _AdsPageScreenState();
}

class _AdsPageScreenState extends State<AdsPageScreen> {
  final AdsService _adsService = AdsService();
  static final Set<String> _sessionViewedAdIds = <String>{};

  List<AdCategory> _categories = [];
  String _selectedCategoryId = 'All';
  String _searchQuery = '';
  List<Ad> _ads = [];

  bool _isLoading = true;
  String? _error;
  final PageController _pageController = PageController();
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'ads-feed-focus');
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadCategoriesAndAds();
  }

  Future<void> _loadCategoriesAndAds() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await _adsService.fetchCategories();
      final hasSelectedCategory =
          categories.any((c) => c.id == _selectedCategoryId);
      final selectedCategory =
          hasSelectedCategory ? _selectedCategoryId : 'All';
      final normalizedSearch = _searchQuery.trim();
      final ads = normalizedSearch.isNotEmpty
          ? ((await _adsService.searchAds(
                q: normalizedSearch,
                category: selectedCategory == 'All' ? null : selectedCategory,
              ))['ads'] as List<Ad>? ??
              const <Ad>[])
          : await _adsService.fetchAds(category: selectedCategory);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategoryId = selectedCategory;
        _ads = ads;
        _isLoading = false;
      });
      if (_ads.isNotEmpty) {
        final initialIndex = _focusedIndex.clamp(0, _ads.length - 1).toInt();
        unawaited(_recordViewForAd(_ads[initialIndex]));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categories = _adsService.getFallbackCategories();
        _ads = [];
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onCategorySelected(String categoryId) async {
    if (_selectedCategoryId == categoryId) return;

    setState(() {
      _selectedCategoryId = categoryId;
      _focusedIndex = 0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    await _loadCategoriesAndAds();
  }

  Future<void> _openSearchDialog() async {
    final controller = TextEditingController(text: _searchQuery);
    final query = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Ads'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search by keyword, hashtag, caption...',
          ),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );

    if (query == null) return;
    setState(() {
      _searchQuery = query.trim();
      _focusedIndex = 0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    await _loadCategoriesAndAds();
  }

  Future<void> _recordViewForAd(Ad ad) async {
    if (ad.id.isEmpty || _sessionViewedAdIds.contains(ad.id)) return;
    final userId = await CurrentUser.id;
    if (userId == null || userId.trim().isEmpty) return;

    _sessionViewedAdIds.add(ad.id);
    try {
      await _adsService.recordAdView(adId: ad.id, userId: userId);
    } catch (_) {
      _sessionViewedAdIds.remove(ad.id);
    }
  }

  Future<void> _openAdComments(Ad ad) async {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    if (isDesktop) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Comments',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, _, __) {
          return SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 360,
                height: MediaQuery.of(context).size.height * 0.78,
                margin: const EdgeInsets.only(right: 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                clipBehavior: Clip.antiAlias,
                child: AdCommentsSheet(adId: ad.id),
              ),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: AdCommentsSheet(adId: ad.id),
      ),
    );
  }

  void _goToPage(int index) {
    if (_ads.isEmpty) return;
    final next = index.clamp(0, _ads.length - 1);
    if (next == _focusedIndex) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _handleKeyboard(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _goToPage(_focusedIndex + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _goToPage(_focusedIndex - 1);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.scrollDelta.dy.abs() < 20) return;
    if (event.scrollDelta.dy > 0) {
      _goToPage(_focusedIndex + 1);
    } else {
      _goToPage(_focusedIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final feedView = KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyboard,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: (index) {
            setState(() {
              _focusedIndex = index;
            });
            if (index >= 0 && index < _ads.length) {
              unawaited(_recordViewForAd(_ads[index]));
            }
          },
          itemCount: _ads.length,
          itemBuilder: (context, index) {
            final ad = _ads[index];
            return AdVideoItem(
              key: ValueKey('ad-video-${ad.id}'),
              ad: ad,
              isActive: index == _focusedIndex,
              onAutoNext: () {
                if (index + 1 < _ads.length) {
                  _goToPage(index + 1);
                }
              },
              onOpenComments: () async {
                await _openAdComments(ad);
              },
            );
          },
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Layer 1: Main Content (Video Feed)
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : _error != null
                  ? _buildErrorState()
                  : _ads.isEmpty
                      ? _buildEmptyState()
                      : isDesktop
                          ? Center(
                              child: Container(
                                width: 360,
                                height: MediaQuery.of(context).size.height * 0.9,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xAA000000),
                                      blurRadius: 28,
                                      offset: Offset(0, 14),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: feedView,
                              ),
                            )
                          : feedView,

          // Layer 2: Top Navigation Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildTopBar(isDesktop: isDesktop),
            ),
          ),
          if (!_isLoading && _error == null && _ads.isNotEmpty && isDesktop)
            Positioned(
              right: 20,
              top: MediaQuery.of(context).size.height * 0.45,
              child: Column(
                children: [
                  _navButton(
                    icon: Icons.keyboard_arrow_up,
                    onTap: _focusedIndex > 0 ? () => _goToPage(_focusedIndex - 1) : null,
                  ),
                  const SizedBox(height: 10),
                  _navButton(
                    icon: Icons.keyboard_arrow_down,
                    onTap: _focusedIndex < _ads.length - 1
                        ? () => _goToPage(_focusedIndex + 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _navButton({required IconData icon, VoidCallback? onTap}) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Icon(
          icon,
          color: disabled ? Colors.white38 : Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildTopBar({required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 6 : 8,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: isDesktop ? const Color(0xE60A0A0A) : null,
        border: isDesktop
            ? Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              )
            : null,
        gradient: isDesktop
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
      ),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: Icon(
              LucideIcons.chevronLeft,
              color: isDesktop ? Colors.white70 : Colors.white,
              size: isDesktop ? 22 : 28,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),

          // Categories List
          Expanded(
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                children: _categories
                    .map((c) => _buildCategoryChip(c.id, c.name, isDesktop))
                    .toList(),
              ),
            ),
          ),

          // Search Button
          IconButton(
            icon: Icon(
              LucideIcons.search,
              color: isDesktop ? Colors.white70 : Colors.white,
              size: isDesktop ? 20 : 24,
            ),
            onPressed: _openSearchDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label, bool isDesktop) {
    final isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () => _onCategorySelected(id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 12 : 16,
          vertical: isDesktop ? 5 : 6,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : (isDesktop
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: isDesktop ? 0.10 : 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : Colors.white.withValues(alpha: isDesktop ? 0.75 : 0.9),
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 12 : 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.videoOff, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          Text(
            'No ads available in this category',
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.circleAlert,
                color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load ads',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadCategoriesAndAds,
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class AdVideoItem extends StatefulWidget {
  final Ad ad;
  final bool isActive;
  final Future<void> Function() onOpenComments;
  final VoidCallback onAutoNext;

  const AdVideoItem({
    super.key,
    required this.ad,
    required this.isActive,
    required this.onOpenComments,
    required this.onAutoNext,
  });

  @override
  State<AdVideoItem> createState() => _AdVideoItemState();
}

class _AdVideoItemState extends State<AdVideoItem>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  final AdsService _adsService = AdsService();
  final SupabaseService _supabase = SupabaseService();
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isSaved = false;
  bool _isFollowing = false;
  bool _isMuted = false;
  bool _isLikeLoading = false;
  bool _isDislikeLoading = false;
  bool _isFollowLoading = false;
  int _likesCount = 0;
  bool _userPaused = false;
  bool _resumeAttemptInFlight = false;
  double _progress = 0;
  Timer? _imageProgressTimer;
  bool _captionExpanded = false;

  // Animation for music disc
  late AnimationController _discController;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.ad.isLikedByMe;
    _isDisliked = widget.ad.isDislikedByMe;
    _isSaved = widget.ad.isSavedByMe;
    _likesCount = widget.ad.likesCount;
    _discController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    unawaited(_loadFollowState());
    if (widget.isActive) _discController.repeat();
    _initializeVideo();
    _startOrStopProgress();
  }

  @override
  void didUpdateWidget(AdVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.id != widget.ad.id) {
      _isLiked = widget.ad.isLikedByMe;
      _isDisliked = widget.ad.isDislikedByMe;
      _isSaved = widget.ad.isSavedByMe;
      _likesCount = widget.ad.likesCount;
      _captionExpanded = false;
      _isInitialized = false;
      _userPaused = false;
      _progress = 0;
      _controller?.removeListener(_onVideoTick);
      unawaited(_controller?.dispose());
      _controller = null;
      unawaited(_loadFollowState());
      _initializeVideo();
      _startOrStopProgress();
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _userPaused = false;
        _controller?.setVolume(_isMuted ? 0 : 1);
        unawaited(_controller?.play());
        _discController.repeat();
      } else {
        _controller?.setVolume(0);
        _userPaused = true;
        unawaited(_controller?.pause());
        _discController.stop();
      }
      _startOrStopProgress();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    _imageProgressTimer?.cancel();
    _discController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final url = widget.ad.videoUrl;
    if (url != null && url.isNotEmpty) {
      _controller?.removeListener(_onVideoTick);
      await _controller?.dispose();
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await _controller!.initialize();
        await _controller!.setLooping(true);
        await _controller!.setVolume(widget.isActive ? (_isMuted ? 0 : 1) : 0);
        _controller!.addListener(_onVideoTick);
        if (widget.isActive) {
          await _controller!.play();
        }
        _startOrStopProgress();
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } catch (e) {
        debugPrint('Error initializing video: $e');
      }
    }
  }

  void _onVideoTick() {
    final controller = _controller;
    if (!mounted || controller == null || !widget.isActive || !_isInitialized) {
      return;
    }
    if (_userPaused) return;

    final value = controller.value;
    if (!value.isInitialized || value.hasError) return;
    if (value.duration > Duration.zero) {
      final pct = (value.position.inMilliseconds / value.duration.inMilliseconds)
          .clamp(0.0, 1.0);
      if ((_progress - pct).abs() > 0.004 && mounted) {
        setState(() {
          _progress = pct;
        });
      }
    }

    final duration = value.duration;
    if (duration > Duration.zero &&
        value.position >= duration - const Duration(milliseconds: 180)) {
      unawaited(controller.seekTo(Duration.zero));
      if (mounted) {
        setState(() {
          _progress = 0;
        });
      }
      if (!value.isPlaying) {
        unawaited(controller.play());
      }
      return;
    }

    if (!value.isPlaying && !value.isBuffering && !_resumeAttemptInFlight) {
      _resumeAttemptInFlight = true;
      unawaited(() async {
        try {
          await controller.play();
        } catch (_) {
          // Ignore transient playback errors.
        } finally {
          _resumeAttemptInFlight = false;
        }
      }());
    }
  }

  bool get _isVideoAd => (widget.ad.videoUrl ?? '').trim().isNotEmpty;

  void _startOrStopProgress() {
    _imageProgressTimer?.cancel();
    if (!widget.isActive) return;
    if (_isVideoAd) return;

    final start = DateTime.now();
    const total = Duration(seconds: 15);
    setState(() {
      _progress = 0;
    });
    _imageProgressTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !widget.isActive) {
        timer.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(start);
      final pct = (elapsed.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
      setState(() {
        _progress = pct;
      });
      if (pct >= 1) {
        timer.cancel();
        widget.onAutoNext();
      }
    });
  }

  void _togglePlay() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _userPaused = true;
        unawaited(_controller!.pause());
        _discController.stop();
      } else {
        _userPaused = false;
        _controller!.setVolume(_isMuted ? 0 : 1);
        unawaited(_controller!.play());
        _discController.repeat();
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_isLikeLoading || widget.ad.id.isEmpty) return;

    final previousLiked = _isLiked;
    final previousLikes = _likesCount;
    final nextLiked = !previousLiked;
    final nextLikes = nextLiked
        ? previousLikes + 1
        : (previousLikes > 0 ? previousLikes - 1 : 0);

    setState(() {
      _isLikeLoading = true;
      _isLiked = nextLiked;
      _likesCount = nextLikes;
      if (nextLiked) {
        _isDisliked = false;
      }
    });

    try {
      final currentUserId = await CurrentUser.id;
      final userId = currentUserId?.trim();
      if (userId == null || userId.isEmpty) {
        throw Exception('Please log in to like ads');
      }

      bool? readBool(Map<String, dynamic> data, List<String> keys) {
        for (final key in keys) {
          final value = data[key];
          if (value is bool) return value;
          if (value is num) return value != 0;
          if (value is String) {
            final lower = value.trim().toLowerCase();
            if (lower == 'true' || lower == '1') return true;
            if (lower == 'false' || lower == '0') return false;
          }
        }
        return null;
      }

      int? readInt(Map<String, dynamic> data, List<String> keys) {
        for (final key in keys) {
          final value = data[key];
          if (value is int) return value;
          if (value is num) return value.toInt();
          if (value is String) {
            final parsed = int.tryParse(value);
            if (parsed != null) return parsed;
          }
        }
        return null;
      }

      if (nextLiked) {
        final res =
            await _adsService.likeAd(adId: widget.ad.id, userId: userId);
        final serverLikes = readInt(res, const ['likes_count', 'likesCount']);
        final serverLiked = readBool(
          res,
          const [
            'is_liked',
            'liked',
            'isLiked',
            'is_liked_by_me',
            'liked_by_me'
          ],
        );
        if (mounted) {
          setState(() {
            if (serverLikes != null) {
              _likesCount = serverLikes;
            }
            if (serverLiked != null) {
              _isLiked = serverLiked;
            }
            if (_isLiked) {
              _isDisliked = false;
            }
          });
        }
      } else {
        final res =
            await _adsService.dislikeAd(adId: widget.ad.id, userId: userId);
        final serverLikes = readInt(res, const ['likes_count', 'likesCount']);
        final isDisliked =
            readBool(res, const ['is_disliked', 'disliked', 'isDisliked']);
        final serverLiked = readBool(
          res,
          const [
            'is_liked',
            'liked',
            'isLiked',
            'is_liked_by_me',
            'liked_by_me'
          ],
        );
        if (mounted) {
          setState(() {
            if (serverLikes != null) {
              _likesCount = serverLikes;
            }
            if (serverLiked != null) {
              _isLiked = serverLiked;
            }
            if (isDisliked is bool && isDisliked) {
              _isLiked = false;
              _isDisliked = true;
            }
          });
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // Keep UI consistent with server semantics for common edge cases.
      if (nextLiked && e.statusCode == 409) {
        setState(() {
          _isLiked = true;
          if (_likesCount < previousLikes) {
            _likesCount = previousLikes;
          }
        });
      } else if (!nextLiked && e.statusCode == 400) {
        setState(() {
          _isLiked = false;
          _likesCount = previousLikes > 0 ? previousLikes - 1 : 0;
        });
      } else {
        setState(() {
          _isLiked = previousLiked;
          _likesCount = previousLikes;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = previousLiked;
          _likesCount = previousLikes;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
        });
      }
    }
  }

  Future<void> _toggleDislike() async {
    if (_isDislikeLoading || widget.ad.id.isEmpty) return;

    final previousDisliked = _isDisliked;
    final previousLiked = _isLiked;
    final previousLikes = _likesCount;
    final nextDisliked = !previousDisliked;

    setState(() {
      _isDislikeLoading = true;
      _isDisliked = nextDisliked;
      if (nextDisliked && _isLiked) {
        _isLiked = false;
        _likesCount = _likesCount > 0 ? _likesCount - 1 : 0;
      }
    });

    try {
      final currentUserId = await CurrentUser.id;
      final userId = currentUserId?.trim();
      if (userId == null || userId.isEmpty) {
        throw Exception('Please log in to dislike ads');
      }

      final res = nextDisliked
          ? await _adsService.dislikeAd(adId: widget.ad.id, userId: userId)
          : await _adsService.likeAd(adId: widget.ad.id, userId: userId);

      bool? readBool(Map<String, dynamic> data, List<String> keys) {
        for (final key in keys) {
          final value = data[key];
          if (value is bool) return value;
          if (value is num) return value != 0;
          if (value is String) {
            final lower = value.trim().toLowerCase();
            if (lower == 'true' || lower == '1') return true;
            if (lower == 'false' || lower == '0') return false;
          }
        }
        return null;
      }

      int? readInt(Map<String, dynamic> data, List<String> keys) {
        for (final key in keys) {
          final value = data[key];
          if (value is int) return value;
          if (value is num) return value.toInt();
          if (value is String) {
            final parsed = int.tryParse(value);
            if (parsed != null) return parsed;
          }
        }
        return null;
      }

      final serverDisliked =
          readBool(res, const ['is_disliked', 'disliked', 'isDisliked']);
      final serverLiked = readBool(res, const [
        'is_liked',
        'liked',
        'isLiked',
        'is_liked_by_me',
        'liked_by_me'
      ]);
      final serverLikes = readInt(res, const ['likes_count', 'likesCount']);

      if (!mounted) return;
      setState(() {
        if (serverDisliked != null) _isDisliked = serverDisliked;
        if (serverLiked != null) _isLiked = serverLiked;
        if (serverLikes != null) _likesCount = serverLikes;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDisliked = previousDisliked;
        _isLiked = previousLiked;
        _likesCount = previousLikes;
      });
    } finally {
      if (mounted) {
        setState(() => _isDislikeLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;
    final targetUserId = widget.ad.userId?.trim() ?? '';
    if (targetUserId.isEmpty) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to follow users')),
        );
      }
      return;
    }

    final previous = _isFollowing;
    final next = !previous;
    setState(() {
      _isFollowLoading = true;
      _isFollowing = next;
    });
    globalStore.dispatch(UpdateUserFollowed(targetUserId, next));

    try {
      final ok = previous
          ? await _supabase.unfollowUser(targetUserId)
          : await _supabase.followUser(targetUserId);
      if (!ok) {
        throw Exception('follow_update_failed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFollowing = previous;
      });
      globalStore.dispatch(UpdateUserFollowed(targetUserId, previous));
    } finally {
      if (mounted) {
        setState(() {
          _isFollowLoading = false;
        });
      }
    }
  }

  Future<void> _loadFollowState() async {
    final targetUserId = widget.ad.userId?.trim() ?? '';
    if (targetUserId.isEmpty) return;
    final meId = await CurrentUser.id;
    if (meId == null || meId.trim().isEmpty) return;

    try {
      final followed = await _supabase.getFollowedUserIds(meId);
      if (!mounted) return;
      setState(() {
        _isFollowing = followed.contains(targetUserId);
      });
    } catch (_) {}
  }

  Future<void> _toggleSaveAd() async {
    if (widget.ad.id.isEmpty) return;
    setState(() {
      _isSaved = !_isSaved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video Player
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            color: Colors.black,
            child: _isInitialized && _controller != null && _isVideoAd
                ? ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  )
                : widget.ad.imageUrl != null
                    ? Image.network(
                        widget.ad.imageUrl!,
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: CircularProgressIndicator(color: Colors.white)),
          ),
        ),

        // Gradient Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.6),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),
        ),

        // 2. Progress Bar (Top)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 2.5,
            color: Colors.white.withValues(alpha: 0.22),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _progress,
              child: Container(color: Colors.white),
            ),
          ),
        ),

        if (widget.ad.coinReward > 0)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.coins, color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '+${widget.ad.coinReward}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 3. Right Side Actions
        Positioned(
          right: 8,
          bottom: 160,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGlassAction(
                icon: _isLiked ? Icons.favorite : LucideIcons.heart,
                label: _formatCount(_likesCount),
                iconColor: _isLiked ? Colors.red : Colors.white,
                fillColor: _isLiked ? Colors.red : null,
                onTap: _toggleLike,
              ),
              const SizedBox(height: 16),
              _buildGlassAction(
                icon: _isDisliked ? Icons.thumb_down_alt : Icons.thumb_down_alt_outlined,
                label: _isDisliked ? 'Disliked' : 'Dislike',
                iconColor: _isDisliked ? Colors.blue : Colors.white,
                onTap: _toggleDislike,
              ),
              const SizedBox(height: 16),
              _buildGlassAction(
                icon: LucideIcons.messageCircle,
                label: _formatCount(widget.ad.commentsCount),
                onTap: () => unawaited(widget.onOpenComments()),
              ),
              const SizedBox(height: 16),
              _buildGlassAction(
                icon: LucideIcons.send,
                label: 'Share',
                onTap: () {},
                rotate: -0.2, // ~12 degrees
              ),
              const SizedBox(height: 16),
              _buildGlassAction(
                icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                label: 'Save',
                iconColor: Colors.white,
                onTap: _toggleSaveAd,
              ),
              const SizedBox(height: 16),
              _buildGlassAction(
                icon: Icons.more_horiz,
                label: '',
                onTap: () {},
              ),
              const SizedBox(height: 24),
              // Spinning Disc
              _buildMusicDisc(),
            ],
          ),
        ),

        // 4. Mute Button (Floating) - video ads only
        if (_isVideoAd)
          Positioned(
            right: 60,
            bottom: 140,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _isMuted = !_isMuted;
                  _controller?.setVolume(_isMuted ? 0 : 1);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),

        // 5. Bottom Info Overlay
        Positioned(
          left: 16,
          right: 80,
          bottom: 84,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User/Company Info
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3), width: 1),
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: (widget.ad.userAvatarUrl ??
                                  widget.ad.companyLogo) !=
                              null
                          ? NetworkImage(
                              widget.ad.userAvatarUrl ?? widget.ad.companyLogo!)
                          : null,
                      child: (widget.ad.userAvatarUrl ??
                                  widget.ad.companyLogo) ==
                              null
                          ? Text(
                              (widget.ad.vendorBusinessName ??
                                  widget.ad.userName ??
                                  widget.ad.companyName)[0],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.ad.vendorBusinessName ??
                                widget.ad.userName ??
                                widget.ad.companyName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.ad.totalBudgetCoins > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.4)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.coins,
                                    color: Colors.amber, size: 10),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCount(widget.ad.totalBudgetCoins),
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isFollowing
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.1),
                            border: Border.all(
                                color: _isFollowing
                                    ? Colors.green.withValues(alpha: 0.45)
                                    : Colors.white.withValues(alpha: 0.4)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: GestureDetector(
                            onTap: _isFollowLoading ? null : _toggleFollow,
                            child: Text(
                              _isFollowLoading
                                  ? '...'
                                  : (_isFollowing ? 'Following' : 'Follow'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Description
              Builder(builder: (context) {
                final caption =
                    (widget.ad.caption ?? widget.ad.description).trim().isEmpty
                        ? 'Sponsored'
                        : (widget.ad.caption ?? widget.ad.description);
                final words = caption.trim().split(RegExp(r'\s+'));
                final isLong = words.length > 5;
                final preview = isLong ? words.take(5).join(' ') : caption;
                return RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4),
                    children: [
                      TextSpan(text: _captionExpanded || !isLong ? caption : preview),
                      if (!_captionExpanded && isLong)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => setState(() => _captionExpanded = true),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 3),
                              child: Text(
                                '... more',
                                style: TextStyle(
                                  color: Color(0xCCFFFFFF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_captionExpanded && isLong)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: GestureDetector(
                            onTap: () => setState(() => _captionExpanded = false),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                'less',
                                style: TextStyle(
                                  color: Color(0xCCFFFFFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),

              // Category
              if ((widget.ad.category ?? '').isNotEmpty ||
                  widget.ad.targetCategories.isNotEmpty)
                Text(
                  widget.ad.category ?? widget.ad.targetCategories.first,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),

              const SizedBox(height: 8),

              // Music/Audio
              Row(
                children: [
                  const Icon(LucideIcons.music2,
                      color: Colors.white70, size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 20,
                      child: MarqueeWidget(
                        text:
                            '${widget.ad.targetLocations.isEmpty ? 'Global' : widget.ad.targetLocations.join(', ')}'
                            ' · '
                            '${widget.ad.targetLanguages.isEmpty ? 'All Languages' : widget.ad.targetLanguages.join(', ')}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    Color? fillColor,
    double rotate = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(
                  color:
                      Colors.transparent), // React has border but it's subtle
            ),
            child: Transform.rotate(
              angle: rotate,
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
                // fill: fillColor, // IconData doesn't support fill property directly in standard Icon widget usually, unless using specific icon set that supports it or fill property. LucideIcons are outline by default.
              ),
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                      color: Colors.black45,
                      offset: Offset(0, 1),
                      blurRadius: 2),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMusicDisc() {
    return AnimatedBuilder(
      animation: _discController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _discController.value * 2 * math.pi,
          child: child,
        );
      },
      child: Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black87,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 8),
        ),
        child: CircleAvatar(
          backgroundImage: widget.ad.companyLogo != null
              ? NetworkImage(widget.ad.companyLogo!)
              : null,
          backgroundColor: Colors.grey[800],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class MarqueeWidget extends StatefulWidget {
  final String text;
  final TextStyle style;

  const MarqueeWidget({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);

    _animationController.addListener(() {
      if (_scrollController.hasClients) {
        if (_scrollController.position.maxScrollExtent > 0) {
          double maxScroll = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(_animation.value * maxScroll);
        }
      }
    });

    // Start animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animationController.repeat();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style),
          const SizedBox(width: 30),
          Text(widget.text,
              style: widget
                  .style), // Duplicate for smooth loop effect (simplified)
          const SizedBox(width: 30),
          Text(widget.text, style: widget.style),
        ],
      ),
    );
  }
}

class AdCommentsSheet extends StatefulWidget {
  final String adId;

  const AdCommentsSheet({super.key, required this.adId});

  @override
  State<AdCommentsSheet> createState() => _AdCommentsSheetState();
}

class _AdCommentsSheetState extends State<AdCommentsSheet> {
  final AdsService _adsService = AdsService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  final Map<String, List<Map<String, dynamic>>> _repliesByComment =
      <String, List<Map<String, dynamic>>>{};
  final Set<String> _loadingReplies = <String>{};
  final Set<String> _expandedReplies = <String>{};
  bool _loading = true;
  bool _posting = false;
  String? _replyParentId;
  String? _replyingTo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _adsService.fetchAdComments(widget.adId);
      if (!mounted) return;
      setState(() {
        _comments = list;
      });
      await _autoLoadRepliesForComments(list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _autoLoadRepliesForComments(
      List<Map<String, dynamic>> comments) async {
    final futures = <Future<void>>[];
    for (final comment in comments) {
      final commentId = _commentId(comment);
      if (commentId.isEmpty) continue;
      futures.add(() async {
        try {
          final replies = await _adsService.fetchAdCommentReplies(commentId);
          if (!mounted) return;
          if (replies.isNotEmpty) {
            setState(() {
              _repliesByComment[commentId] = replies;
            });
          }
        } catch (_) {}
      }());
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;
    final parentId = _replyParentId;

    setState(() => _posting = true);
    try {
      final created = await _adsService.addAdComment(
        adId: widget.adId,
        text: text,
        parentId: parentId,
      );
      if (!mounted) return;

      final comment = created['comment'] is Map
          ? Map<String, dynamic>.from(created['comment'] as Map)
          : created;
      setState(() {
        if (parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
            _repliesByComment[parentId] ?? const <Map<String, dynamic>>[],
          );
          list.insert(0, comment);
          _repliesByComment[parentId] = list;
          _expandedReplies.add(parentId);
        } else {
          _comments = [comment, ..._comments];
        }
        _controller.clear();
        _replyParentId = null;
        _replyingTo = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  String _commentId(Map<String, dynamic> c) {
    return ((c['_id'] ?? c['id'])?.toString() ?? '').trim();
  }

  String _commentText(Map<String, dynamic> c) {
    return ((c['text'] ?? c['content'])?.toString() ?? '').trim();
  }

  String _commentAuthor(Map<String, dynamic> c) {
    final user = c['user'];
    if (user is Map) {
      final username = user['username'] ?? user['full_name'] ?? user['name'];
      if (username != null && username.toString().trim().isNotEmpty) {
        return username.toString();
      }
    }
    return (c['username'] ?? c['author'] ?? 'user').toString();
  }

  bool _isCommentLiked(Map<String, dynamic> c) {
    return (c['is_liked'] == true) ||
        (c['isLiked'] == true) ||
        (c['is_liked_by_me'] == true) ||
        (c['liked_by_me'] == true) ||
        (c['liked'] == true);
  }

  int _commentLikeCount(Map<String, dynamic> c) {
    final value = c['likes_count'] ?? c['likesCount'] ?? c['likes'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _isCommentDisliked(Map<String, dynamic> c) {
    return (c['is_disliked'] == true) ||
        (c['isDisliked'] == true) ||
        (c['is_disliked_by_me'] == true) ||
        (c['disliked_by_me'] == true) ||
        (c['disliked'] == true);
  }

  int _commentDislikeCount(Map<String, dynamic> c) {
    final value = c['dislikes_count'] ?? c['dislikesCount'] ?? c['dislikes'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int _commentReplyCount(Map<String, dynamic> c, String id) {
    final loaded = (_repliesByComment[id] ?? const <Map<String, dynamic>>[]).length;
    int parseCount(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final meta = [
      c['reply_count'],
      c['replies_count'],
      c['replyCount'],
      c['repliesCount'],
      c['total_replies'],
      c['totalReplies'],
      c['children_count'],
      c['childrenCount'],
    ].map(parseCount).fold<int>(0, (maxValue, current) => current > maxValue ? current : maxValue);
    return loaded > meta ? loaded : meta;
  }

  Future<void> _toggleCommentLike({
    required String commentId,
    required bool isReply,
    String? parentId,
  }) async {
    if (commentId.isEmpty) return;

    Map<String, dynamic>? target;
    int? targetIndex;
    if (isReply && parentId != null && parentId.isNotEmpty) {
      final list = _repliesByComment[parentId];
      if (list != null) {
        final idx = list.indexWhere((x) => _commentId(x) == commentId);
        if (idx >= 0) {
          target = Map<String, dynamic>.from(list[idx]);
          targetIndex = idx;
        }
      }
    } else {
      final idx = _comments.indexWhere((x) => _commentId(x) == commentId);
      if (idx >= 0) {
        target = Map<String, dynamic>.from(_comments[idx]);
        targetIndex = idx;
      }
    }
    if (target == null || targetIndex == null) return;
    final idx = targetIndex;

    final prevLiked = _isCommentLiked(target);
    final prevLikes = _commentLikeCount(target);
    final optimisticLiked = !prevLiked;
    final optimisticLikes =
        optimisticLiked ? prevLikes + 1 : (prevLikes > 0 ? prevLikes - 1 : 0);

    void applyLike(Map<String, dynamic> map, bool liked, int likes) {
      map['is_liked'] = liked;
      map['liked_by_me'] = liked;
      map['likes_count'] = likes;
    }

    setState(() {
      if (isReply && parentId != null && parentId.isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(
            _repliesByComment[parentId] ?? const []);
        final next = Map<String, dynamic>.from(list[idx]);
        applyLike(next, optimisticLiked, optimisticLikes);
        list[idx] = next;
        _repliesByComment[parentId] = list;
      } else {
        final next = Map<String, dynamic>.from(_comments[idx]);
        applyLike(next, optimisticLiked, optimisticLikes);
        _comments[idx] = next;
      }
    });

    try {
      final res = await _adsService.toggleAdCommentLike(commentId);
      final serverLiked = res['is_liked'];
      final serverLikes = res['likes_count'];
      if (!mounted) return;
      setState(() {
        final liked = serverLiked is bool ? serverLiked : optimisticLiked;
        final likes = serverLikes is int ? serverLikes : optimisticLikes;
        if (isReply && parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
              _repliesByComment[parentId] ?? const []);
          if (idx >= 0 && idx < list.length) {
            final next = Map<String, dynamic>.from(list[idx]);
            applyLike(next, liked, likes);
            list[idx] = next;
            _repliesByComment[parentId] = list;
          }
        } else if (idx >= 0 && idx < _comments.length) {
          final next = Map<String, dynamic>.from(_comments[idx]);
          applyLike(next, liked, likes);
          _comments[idx] = next;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isReply && parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
              _repliesByComment[parentId] ?? const []);
          if (idx >= 0 && idx < list.length) {
            final next = Map<String, dynamic>.from(list[idx]);
            applyLike(next, prevLiked, prevLikes);
            list[idx] = next;
            _repliesByComment[parentId] = list;
          }
        } else if (idx >= 0 && idx < _comments.length) {
          final next = Map<String, dynamic>.from(_comments[idx]);
          applyLike(next, prevLiked, prevLikes);
          _comments[idx] = next;
        }
      });
    }
  }

  Future<void> _toggleCommentDislike({
    required String commentId,
    required bool isReply,
    String? parentId,
  }) async {
    if (commentId.isEmpty) return;

    Map<String, dynamic>? target;
    int? targetIndex;
    if (isReply && parentId != null && parentId.isNotEmpty) {
      final list = _repliesByComment[parentId];
      if (list != null) {
        final idx = list.indexWhere((x) => _commentId(x) == commentId);
        if (idx >= 0) {
          target = Map<String, dynamic>.from(list[idx]);
          targetIndex = idx;
        }
      }
    } else {
      final idx = _comments.indexWhere((x) => _commentId(x) == commentId);
      if (idx >= 0) {
        target = Map<String, dynamic>.from(_comments[idx]);
        targetIndex = idx;
      }
    }
    if (target == null || targetIndex == null) return;
    final idx = targetIndex;

    final prevDisliked = _isCommentDisliked(target);
    final prevDislikes = _commentDislikeCount(target);
    final optimisticDisliked = !prevDisliked;
    final optimisticDislikes = optimisticDisliked
        ? prevDislikes + 1
        : (prevDislikes > 0 ? prevDislikes - 1 : 0);

    void applyDislike(Map<String, dynamic> map, bool disliked, int dislikes) {
      map['is_disliked'] = disliked;
      map['disliked_by_me'] = disliked;
      map['dislikes_count'] = dislikes;
    }

    setState(() {
      if (isReply && parentId != null && parentId.isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(
            _repliesByComment[parentId] ?? const []);
        final next = Map<String, dynamic>.from(list[idx]);
        applyDislike(next, optimisticDisliked, optimisticDislikes);
        list[idx] = next;
        _repliesByComment[parentId] = list;
      } else {
        final next = Map<String, dynamic>.from(_comments[idx]);
        applyDislike(next, optimisticDisliked, optimisticDislikes);
        _comments[idx] = next;
      }
    });

    try {
      final res = await _adsService.toggleAdCommentDislike(commentId);
      final serverDisliked = res['is_disliked'];
      final serverDislikes = res['dislikes_count'];
      if (!mounted) return;
      setState(() {
        final disliked =
            serverDisliked is bool ? serverDisliked : optimisticDisliked;
        final dislikes =
            serverDislikes is int ? serverDislikes : optimisticDislikes;
        if (isReply && parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
              _repliesByComment[parentId] ?? const []);
          if (idx >= 0 && idx < list.length) {
            final next = Map<String, dynamic>.from(list[idx]);
            applyDislike(next, disliked, dislikes);
            list[idx] = next;
            _repliesByComment[parentId] = list;
          }
        } else if (idx >= 0 && idx < _comments.length) {
          final next = Map<String, dynamic>.from(_comments[idx]);
          applyDislike(next, disliked, dislikes);
          _comments[idx] = next;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isReply && parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
              _repliesByComment[parentId] ?? const []);
          if (idx >= 0 && idx < list.length) {
            final next = Map<String, dynamic>.from(list[idx]);
            applyDislike(next, prevDisliked, prevDislikes);
            list[idx] = next;
            _repliesByComment[parentId] = list;
          }
        } else if (idx >= 0 && idx < _comments.length) {
          final next = Map<String, dynamic>.from(_comments[idx]);
          applyDislike(next, prevDisliked, prevDislikes);
          _comments[idx] = next;
        }
      });
    }
  }

  Future<void> _toggleReplies(String commentId) async {
    if (commentId.isEmpty) return;

    if (_expandedReplies.contains(commentId)) {
      setState(() {
        _expandedReplies.remove(commentId);
      });
      return;
    }

    if (_repliesByComment.containsKey(commentId)) {
      setState(() {
        _expandedReplies.add(commentId);
      });
      return;
    }

    setState(() {
      _loadingReplies.add(commentId);
    });
    try {
      final replies = await _adsService.fetchAdCommentReplies(commentId);
      if (!mounted) return;
      setState(() {
        _repliesByComment[commentId] = replies;
        _expandedReplies.add(commentId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load replies: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingReplies.remove(commentId);
        });
      }
    }
  }

  Future<void> _deleteComment({
    required String commentId,
    required bool isReply,
    String? parentId,
  }) async {
    if (commentId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _adsService.deleteAdComment(commentId);
      if (!mounted) return;
      setState(() {
        if (isReply && parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
            _repliesByComment[parentId] ?? const <Map<String, dynamic>>[],
          );
          list.removeWhere((r) => _commentId(r) == commentId);
          _repliesByComment[parentId] = list;
        } else {
          _comments.removeWhere((c) => _commentId(c) == commentId);
          _repliesByComment.remove(commentId);
          _expandedReplies.remove(commentId);
          _loadingReplies.remove(commentId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Comments (${_comments.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('No comments yet'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          final text = _commentText(c);
                          final author = _commentAuthor(c);
                          final id = _commentId(c);
                          final isLiked = _isCommentLiked(c);
                          final likesCount = _commentLikeCount(c);
                          final isDisliked = _isCommentDisliked(c);
                          final dislikesCount = _commentDislikeCount(c);
                          final replies = _repliesByComment[id] ??
                              const <Map<String, dynamic>>[];
                          final replyCount = _commentReplyCount(c, id);
                          final showReplies = _expandedReplies.contains(id);
                          final isLoadingReplies = _loadingReplies.contains(id);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      author,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (id.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18),
                                      tooltip: 'Delete comment',
                                      onPressed: () => _deleteComment(
                                        commentId: id,
                                        isReply: false,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(text.isEmpty ? '-' : text),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: id.isEmpty
                                        ? null
                                        : () => _toggleCommentLike(
                                              commentId: id,
                                              isReply: false,
                                            ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                    ),
                                    child: Text(isLiked ? 'Unlike' : 'Like'),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '$likesCount like${likesCount == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: id.isEmpty
                                        ? null
                                        : () => _toggleCommentDislike(
                                              commentId: id,
                                              isReply: false,
                                            ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                    ),
                                    child: Text(
                                        isDisliked ? 'Undislike' : 'Dislike'),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$dislikesCount',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: id.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          _replyParentId = id;
                                          _replyingTo = author;
                                        });
                                        _focusNode.requestFocus();
                                      },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                ),
                                child: const Text('Reply'),
                              ),
                              if (id.isNotEmpty && replyCount > 0)
                                TextButton(
                                  onPressed: isLoadingReplies
                                      ? null
                                      : () => _toggleReplies(id),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                  ),
                                  child: Text(
                                    isLoadingReplies
                                        ? 'Loading replies...'
                                        : (showReplies
                                            ? 'Hide replies'
                                            : 'View replies ($replyCount)'),
                                  ),
                                ),
                              if (showReplies)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 12, top: 6),
                                  child: replies.isEmpty
                                      ? const Text(
                                          'No replies',
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: replies.map((reply) {
                                            final replyId = _commentId(reply);
                                            final replyLiked =
                                                _isCommentLiked(reply);
                                            final replyLikesCount =
                                                _commentLikeCount(reply);
                                            final replyDisliked =
                                                _isCommentDisliked(reply);
                                            final replyDislikesCount =
                                                _commentDislikeCount(reply);
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          _commentAuthor(reply),
                                                          style:
                                                              const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                      if (replyId.isNotEmpty)
                                                        IconButton(
                                                          icon: const Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              size: 16),
                                                          tooltip:
                                                              'Delete reply',
                                                          onPressed: () =>
                                                              _deleteComment(
                                                            commentId: replyId,
                                                            isReply: true,
                                                            parentId: id,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    _commentText(reply).isEmpty
                                                        ? '-'
                                                        : _commentText(reply),
                                                    style: const TextStyle(
                                                        fontSize: 13),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      TextButton(
                                                        onPressed: replyId
                                                                .isEmpty
                                                            ? null
                                                            : () =>
                                                                _toggleCommentLike(
                                                                  commentId:
                                                                      replyId,
                                                                  isReply: true,
                                                                  parentId: id,
                                                                ),
                                                        style: TextButton
                                                            .styleFrom(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          minimumSize:
                                                              const Size(0, 0),
                                                        ),
                                                        child: Text(replyLiked
                                                            ? 'Unlike'
                                                            : 'Like'),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '$replyLikesCount',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      TextButton(
                                                        onPressed: replyId
                                                                .isEmpty
                                                            ? null
                                                            : () =>
                                                                _toggleCommentDislike(
                                                                  commentId:
                                                                      replyId,
                                                                  isReply: true,
                                                                  parentId: id,
                                                                ),
                                                        style: TextButton
                                                            .styleFrom(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          minimumSize:
                                                              const Size(0, 0),
                                                        ),
                                                        child: Text(
                                                          replyDisliked
                                                              ? 'Undislike'
                                                              : 'Dislike',
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        '$replyDislikesCount',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                ),
                            ],
                          );
                        },
                      ),
          ),
          if (_replyingTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.grey.withValues(alpha: 0.12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to $_replyingTo',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _replyParentId = null;
                        _replyingTo = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _posting ? null : _submit,
                  child: _posting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
