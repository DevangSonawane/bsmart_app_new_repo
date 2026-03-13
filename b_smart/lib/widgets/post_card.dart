import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:extended_image/extended_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';
import '../models/feed_post_model.dart';
import '../api/api_client.dart';
import '../utils/url_helper.dart';

class PostCard extends StatefulWidget {
  final FeedPost post;
  final bool isTabActive;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;
  final VoidCallback? onUserTap;
  final VoidCallback? onDoubleTapLike;

  const PostCard({
    super.key,
    required this.post,
    this.isTabActive = true,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onFollow,
    this.onMore,
    this.onUserTap,
    this.onDoubleTapLike,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  static Map<String, String>? _sharedAuthHeaders;
  static Future<Map<String, String>>? _sharedAuthHeadersFuture;

  VideoPlayerController? _videoCtl;
  Map<String, String>? _authHeaders;
  double? _mediaAspect;

  // Tracks whether this card is currently in the viewport
  bool _isVisible = false;
  // Tracks whether the user manually paused (tap to pause/resume)
  bool _userWantsPaused = false;
  bool _isMuted = true;
  // Whether the video controller has finished initializing
  bool _videoInitialized = false;
  // Whether we've already started the init process
  bool _initStarted = false;
  bool _showDoubleTapLike = false;
  bool _autoplayKickScheduled = false;
  Timer? _offscreenDisposeTimer;
  Timer? _doubleTapLikeTimer;

  void _safePause() {
    final controller = _videoCtl;
    if (controller == null) return;
    unawaited(controller.pause().catchError((_) {}));
  }

  void _safePlay() {
    final controller = _videoCtl;
    if (controller == null) return;
    unawaited(controller.play().catchError((_) {}));
  }

  void _safeDisposeController() {
    _offscreenDisposeTimer?.cancel();
    _offscreenDisposeTimer = null;
    final controller = _videoCtl;
    _videoCtl = null;
    _videoInitialized = false;
    _initStarted = false;
    if (controller == null) return;
    try {
      controller.dispose();
    } catch (_) {}
  }

  bool get _isVideoPost =>
      widget.post.mediaType == PostMediaType.video ||
      widget.post.mediaType == PostMediaType.reel;

  @override
  void initState() {
    super.initState();
    if (widget.post.aspectRatio != null && widget.post.aspectRatio! > 0) {
      _mediaAspect = _normalizedAspect(widget.post.aspectRatio!);
    }
    _authHeaders = _sharedAuthHeaders;
    // Load auth token once globally — video init starts once visible
    unawaited(_loadAuthHeaders());
  }

  double _normalizedAspect(double raw) {
    if (raw.isNaN || raw <= 0) return 4 / 5;
    return raw.clamp(0.5625, 1.91);
  }

  Future<void> _loadAuthHeaders() async {
    if (_sharedAuthHeaders != null) {
      _authHeaders = _sharedAuthHeaders;
      if (_isVisible && _isVideoPost && !_initStarted) {
        _startVideoInit();
      }
      return;
    }
    _sharedAuthHeadersFuture ??= () async {
      final token = await ApiClient().getToken();
      final next = <String, String>{'User-Agent': 'PostCard-App'};
      if (token != null && token.isNotEmpty) {
        next['Authorization'] = 'Bearer $token';
      }
      _sharedAuthHeaders = next;
      return next;
    }();
    final next = await _sharedAuthHeadersFuture!;
    if (!mounted) return;
    _authHeaders = next;
    // If visibility callback already fired before headers loaded, start init now
    if (_isVisible && _isVideoPost && !_initStarted) {
      _startVideoInit();
    }
  }

  Map<String, String> _getHeaders(String url) {
    // React web media tags do not attach Authorization header.
    return const {};
  }

  /// Called once when the card becomes visible AND headers are ready.
  void _startVideoInit() {
    if (_initStarted || !_isVideoPost) {
      return;
    }
    if (widget.post.mediaUrls.isEmpty) {
      return;
    }

    final rawUrl = widget.post.mediaUrls.first;
    final url = UrlHelper.absoluteUrl(rawUrl);

    if (url.isEmpty) return;

    _initStarted = true;
    unawaited(_initVideo(url));
  }

  Future<void> _initVideo(String url) async {
    if (!mounted || !_isVisible) {
      _initStarted = false;
      return;
    }
    try {
      final headerCandidates = <Map<String, String>>[
        const <String, String>{},
        if ((_authHeaders ?? const {}).containsKey('Authorization'))
          Map<String, String>.from(_authHeaders!),
      ];
      Object? lastError;

      for (final headers in headerCandidates) {
        VideoPlayerController? controller;
        try {
          controller = VideoPlayerController.networkUrl(
            Uri.parse(url),
            httpHeaders: headers,
          );

          await controller.initialize();
          // After initialize(), check if we're still mounted and still want to play
          if (!mounted) {
            await controller.dispose();
            return;
          }

          if (!_isVisible) {
            await controller.dispose();
            _initStarted = false;
            return;
          }

          final existing = _videoCtl;
          if (existing != null && existing != controller) {
            try {
              await existing.dispose();
            } catch (_) {}
          }

          final readyController = controller;
          await readyController.setLooping(true);
          await readyController.setVolume(
            widget.isTabActive && !_isMuted ? 1.0 : 0.0,
          );

          setState(() {
            _videoCtl = readyController;
            _videoInitialized = true;
            _mediaAspect = _normalizedAspect(readyController.value.aspectRatio);
          });

          // Only play if still visible and user hasn't manually paused
          if (widget.isTabActive && _isVisible && !_userWantsPaused) {
            await readyController.play();
          }
          return;
        } catch (e) {
          lastError = e;
          try {
            await controller?.dispose();
          } catch (_) {}
        }
      }
      _initStarted = false;
      debugPrint(
          '[PostCard] video init failed post=${widget.post.id} url=$url error=$lastError');
    } catch (e) {
      debugPrint(
          '[PostCard] video init failed post=${widget.post.id} url=$url error=$e');
      _initStarted = false;
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final nowVisible = info.visibleFraction >= 0.25;

    if (nowVisible == _isVisible) return; // No change
    _isVisible = nowVisible;

    if (nowVisible) {
      _offscreenDisposeTimer?.cancel();
      _offscreenDisposeTimer = null;
      if (!widget.isTabActive) {
        _safePause();
        return;
      }
      // Card came into view
      if (_isVideoPost) {
        if (!_initStarted && _authHeaders != null) {
          _startVideoInit();
        } else if (_videoInitialized && !_userWantsPaused) {
          // Already initialized — just resume
          _safePlay();
        }
        // If headers not ready yet, _loadAuthHeaders will call _startVideoInit when done
      }
    } else {
      // Card left view — pause to save resources
      _safePause();
      _offscreenDisposeTimer?.cancel();
      _offscreenDisposeTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted || _isVisible) return;
        _safeDisposeController();
      });
    }
  }

  void _onTapMedia() {
    if (!_isVideoPost || !_videoInitialized) return;
    setState(() {
      _userWantsPaused = !_userWantsPaused;
      if (_userWantsPaused) {
        _safePause();
      } else {
        _safePlay();
      }
    });
  }

  void _toggleMute() {
    if (!_videoInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoCtl?.setVolume(widget.isTabActive && !_isMuted ? 1.0 : 0.0);
    });
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isTabActive == widget.isTabActive) return;
    if (!widget.isTabActive) {
      _videoCtl?.setVolume(0.0);
      _safePause();
      _offscreenDisposeTimer?.cancel();
      _offscreenDisposeTimer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted || _isVisible) return;
        _safeDisposeController();
      });
      return;
    }
    if (_videoInitialized) {
      _videoCtl?.setVolume(_isMuted ? 0.0 : 1.0);
      if (_isVisible && !_userWantsPaused) {
        _safePlay();
      }
    } else if (_isVisible && !_initStarted && _authHeaders != null) {
      _startVideoInit();
    }
  }

  void _onDoubleTapMedia() {
    widget.onDoubleTapLike?.call();
    _doubleTapLikeTimer?.cancel();
    if (mounted) {
      setState(() => _showDoubleTapLike = true);
    }
    _doubleTapLikeTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _showDoubleTapLike = false);
      }
    });
  }

  void _scheduleAutoplayKick() {
    if (_autoplayKickScheduled) return;
    _autoplayKickScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoplayKickScheduled = false;
      if (!mounted || !widget.isTabActive || !_isVisible || _userWantsPaused) {
        return;
      }
      if (_isVideoPost && !_initStarted && _authHeaders != null) {
        _startVideoInit();
        return;
      }
      if (_videoInitialized) {
        _safePlay();
      }
    });
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  void dispose() {
    _offscreenDisposeTimer?.cancel();
    _doubleTapLikeTimer?.cancel();
    _safeDisposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideoPost && _isVisible) {
      _scheduleAutoplayKick();
    }
    final post = widget.post;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(post, isDark, theme),
          AspectRatio(
            aspectRatio: _mediaAspect ?? 1.0,
            child: GestureDetector(
              onTap: (_isVideoPost && _videoInitialized) ? _onTapMedia : null,
              onDoubleTap:
                  widget.onDoubleTapLike != null ? _onDoubleTapMedia : null,
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_isVideoPost)
                      _buildVideoPlayer(post, isDark)
                    else
                      _buildImageWidget(post, isDark),

                    // Mute button for videos
                    if (_isVideoPost && _videoInitialized)
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: _toggleMute,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isMuted
                                  ? LucideIcons.volumeX
                                  : LucideIcons.volume2,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                    // Play/pause overlay icon
                    if (_isVideoPost && _userWantsPaused)
                      const Center(
                        child: Icon(LucideIcons.play,
                            color: Colors.white, size: 50),
                      ),

                    IgnorePointer(
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          opacity: _showDoubleTapLike ? 1 : 0,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutBack,
                            scale: _showDoubleTapLike ? 1 : 0.65,
                            child: const Icon(
                              Icons.favorite,
                              size: 92,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 12,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildActionBar(post, theme),
          _buildPostDetails(post, theme),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(FeedPost post, bool isDark) {
    // Video is ready — show it
    if (_videoInitialized && _videoCtl != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: _videoCtl!.value.aspectRatio,
          child: VideoPlayer(_videoCtl!),
        ),
      );
    }

    // Not yet initialized — show thumbnail or placeholder
    if (post.thumbnailUrl != null && post.thumbnailUrl!.isNotEmpty) {
      final thumbUrl = UrlHelper.absoluteUrl(post.thumbnailUrl!);
      if (thumbUrl.isNotEmpty) {
        return Image.network(
          thumbUrl,
          headers: _getHeaders(thumbUrl),
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return const ColoredBox(color: Colors.black);
          },
          errorBuilder: (_, __, ___) =>
              _buildPlaceholder(isDark, isVideo: true),
        );
      }
    }

    return _buildPlaceholder(isDark, isVideo: true);
  }

  Widget _buildImageWidget(FeedPost post, bool isDark) {
    if (post.mediaUrls.isEmpty) return _buildPlaceholder(isDark);
    final url = UrlHelper.absoluteUrl(post.mediaUrls.first);
    if (url.isEmpty) return _buildPlaceholder(isDark);

    return ExtendedImage.network(
      url,
      headers: _getHeaders(url),
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      loadStateChanged: (state) {
        if (state.extendedImageLoadState == LoadState.completed) {
          final info = state.extendedImageInfo;
          if (info != null) {
            final real = _normalizedAspect(
              info.image.width / info.image.height,
            );
            if (_mediaAspect != real) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _mediaAspect = real);
              });
            }
          }
        }
        if (state.extendedImageLoadState == LoadState.failed) {
          return _buildPlaceholder(isDark);
        }
        return null;
      },
    );
  }

  Widget _buildPlaceholder(bool isDark, {bool isVideo = false}) {
    if (isVideo) {
      // Video placeholders must stay dark so feed doesn't flash white.
      return const ColoredBox(color: Colors.black);
    }
    return Container(
      color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
      child: Center(
        child: Icon(
          LucideIcons.imageOff,
          color: isDark ? Colors.white24 : Colors.grey.shade400,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildHeader(FeedPost post, bool isDark, ThemeData theme) {
    final avatarUrl =
        post.userAvatar != null ? UrlHelper.absoluteUrl(post.userAvatar!) : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onUserTap,
            child: Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFACC15),
                    Color(0xFFF97316),
                    Color(0xFFEC4899)
                  ],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.scaffoldBackgroundColor,
                ),
                padding: const EdgeInsets.all(1),
                child: CircleAvatar(
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  backgroundColor:
                      isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade200,
                  child: avatarUrl.isEmpty
                      ? Text(
                          post.userName.isNotEmpty
                              ? post.userName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: widget.onUserTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    post.userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.isAd)
                    Text(
                      'Sponsored',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (!post.isAd &&
                      post.fullName != null &&
                      post.fullName!.trim().isNotEmpty)
                    Text(
                      post.fullName!,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          Text(
            _formatTimestamp(post.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(width: 4),
          if (widget.onMore != null)
            GestureDetector(
              onTap: widget.onMore,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(LucideIcons.ellipsis, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(FeedPost post, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            iconSize: 22,
            icon: Icon(
              post.isLiked ? Icons.favorite : LucideIcons.heart,
              color: post.isLiked ? Colors.red : null,
            ),
            onPressed: widget.onLike,
          ),
          IconButton(
            iconSize: 22,
            icon: const Icon(LucideIcons.messageCircle),
            onPressed: widget.onComment,
          ),
          IconButton(
            iconSize: 22,
            icon: const Icon(LucideIcons.send),
            onPressed: widget.onShare,
          ),
          const Spacer(),
          if (widget.onFollow != null)
            GestureDetector(
              onTap: widget.onFollow,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    Icon(
                      post.isFollowed
                          ? LucideIcons.userCheck
                          : LucideIcons.userPlus,
                      size: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.isFollowed ? 'Following' : 'Follow',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            iconSize: 22,
            icon: Icon(
              post.isSaved ? Icons.bookmark : LucideIcons.bookmark,
            ),
            onPressed: widget.onSave,
          ),
        ],
      ),
    );
  }

  Widget _buildPostDetails(FeedPost post, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${post.likes} likes',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (post.isAd &&
              post.adTitle != null &&
              post.adTitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              post.adTitle!.trim(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
          if (post.caption != null && post.caption!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              children: [
                GestureDetector(
                  onTap: widget.onUserTap,
                  child: Text(
                    '${post.userName} ',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Text(
                  post.caption!,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
          if (post.comments > 1) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: widget.onComment,
              child: Text(
                'View all ${post.comments >= 1000 ? '${(post.comments / 1000).toStringAsFixed(1)}K' : post.comments} comments',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
          if (post.latestCommentText != null &&
              post.latestCommentText!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(
                    text:
                        '${(post.latestCommentUser ?? post.userName).trim()} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: post.latestCommentText!.trim(),
                    style: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(post.createdAt).toUpperCase(),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10.5,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
