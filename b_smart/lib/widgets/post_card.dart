import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:extended_image/extended_image.dart';
import 'package:video_player/video_player.dart';
import '../models/feed_post_model.dart';
import '../api/api_client.dart';
import '../utils/url_helper.dart';
import '../config/api_config.dart';

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
  Timer? _doubleTapLikeTimer;

  bool get _isVideoPost =>
      widget.post.mediaType == PostMediaType.video ||
      widget.post.mediaType == PostMediaType.reel;

  @override
  void initState() {
    super.initState();
    debugPrint('[PostCard] initState for ${widget.post.id}, mediaType: ${widget.post.mediaType}');
    if (widget.post.aspectRatio != null && widget.post.aspectRatio! > 0) {
      _mediaAspect = _normalizedAspect(widget.post.aspectRatio!);
    }
    // Load auth token eagerly — video init starts once visible
    _loadAuthHeaders();
  }

  double _normalizedAspect(double raw) {
    if (raw.isNaN || raw <= 0) return 4 / 5;
    if (widget.post.isAd) return 1.0;
    return raw.clamp(0.5625, 1.91);
  }

  Future<void> _loadAuthHeaders() async {
    final token = await ApiClient().getToken();
    if (!mounted) return;
    final next = <String, String>{
      'User-Agent': 'PostCard-App',
    };
    if (token != null && token.isNotEmpty) {
      next['Authorization'] = 'Bearer $token';
    }
    setState(() => _authHeaders = next);
    debugPrint('[PostCard] Headers loaded for ${widget.post.id}. Visible: $_isVisible, IsVideo: $_isVideoPost, InitStarted: $_initStarted');
    // If visibility callback already fired before headers loaded, start init now
    if (_isVisible && _isVideoPost && !_initStarted) {
      _startVideoInit();
    }
  }

  Map<String, String> _getHeaders(String url) {
    if (_authHeaders == null) return {};
    try {
      final uri = Uri.parse(url);
      final baseUri = Uri.parse(ApiConfig.baseUrl);
      if (uri.host == baseUri.host) return _authHeaders!;
    } catch (_) {}
    if (url.startsWith('http://localhost') || url.startsWith('http://10.0.2.2')) {
      return _authHeaders!;
    }
    return {};
  }

  /// Called once when the card becomes visible AND headers are ready.
  void _startVideoInit() {
    debugPrint('[PostCard] _startVideoInit called for ${widget.post.id}');
    if (_initStarted || !_isVideoPost) {
       debugPrint('[PostCard] Skipping init: Started=$_initStarted, IsVideo=$_isVideoPost');
       return;
    }
    if (widget.post.mediaUrls.isEmpty) {
      debugPrint('[PostCard] No media URLs for ${widget.post.id}');
      return;
    }

    final rawUrl = widget.post.mediaUrls.first;
    final url = UrlHelper.absoluteUrl(rawUrl);
    debugPrint('[PostCard] Video URL for ${widget.post.id}: $url');
    
    if (url.isEmpty) return;

    _initStarted = true;
    _initVideo(url);
  }

  Future<void> _initVideo(String url) async {
    debugPrint('[PostCard] Initializing video controller for ${widget.post.id}...');
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: _getHeaders(url),
      );

      await controller.initialize();
      debugPrint('[PostCard] Video initialized for ${widget.post.id}');

      // After initialize(), check if we're still mounted and still want to play
      if (!mounted) {
        controller.dispose();
        return;
      }

      controller.setLooping(true);
      controller.setVolume(widget.isTabActive && !_isMuted ? 1.0 : 0.0);

      setState(() {
        _videoCtl = controller;
        _videoInitialized = true;
        _mediaAspect = _normalizedAspect(controller.value.aspectRatio);
      });

      // Only play if still visible and user hasn't manually paused
      if (widget.isTabActive && _isVisible && !_userWantsPaused) {
        debugPrint('[PostCard] Auto-playing video for ${widget.post.id}');
        await controller.play();
      }
    } catch (e) {
      debugPrint('[PostCard] Video init error for ${widget.post.id}: $e');
      if (mounted) setState(() {}); // Show thumbnail fallback
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final nowVisible = info.visibleFraction >= 0.5;
    debugPrint('[PostCard] Visibility changed for ${widget.post.id}: ${info.visibleFraction}');

    if (nowVisible == _isVisible) return; // No change
    _isVisible = nowVisible;

    if (nowVisible) {
      if (!widget.isTabActive) {
        _videoCtl?.pause();
        return;
      }
      // Card came into view
      if (_isVideoPost) {
        if (!_initStarted && _authHeaders != null) {
          // Headers ready — start init
          _startVideoInit();
        } else if (_videoInitialized && !_userWantsPaused) {
          // Already initialized — just resume
          _videoCtl?.play();
          if (mounted) setState(() {});
        }
        // If headers not ready yet, _loadAuthHeaders will call _startVideoInit when done
      }
    } else {
      // Card left view — pause to save resources
      _videoCtl?.pause();
      if (mounted) setState(() {});
    }
  }

  void _onTapMedia() {
    if (!_isVideoPost || !_videoInitialized) return;
    setState(() {
      _userWantsPaused = !_userWantsPaused;
      if (_userWantsPaused) {
        _videoCtl?.pause();
      } else {
        _videoCtl?.play();
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
      _videoCtl?.pause();
      return;
    }
    if (_videoInitialized) {
      _videoCtl?.setVolume(_isMuted ? 0.0 : 1.0);
      if (_isVisible && !_userWantsPaused) {
        _videoCtl?.play();
      }
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

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _doubleTapLikeTimer?.cancel();
    _videoCtl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              onTap: _onTapMedia,
              onDoubleTap: _onDoubleTapMedia,
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
                            _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  // Play/pause overlay icon
                  if (_isVideoPost && _userWantsPaused)
                    const Center(
                      child: Icon(LucideIcons.play, color: Colors.white, size: 50),
                    ),

                  // Loading spinner while video initializes
                  if (_isVideoPost && _isVisible && !_videoInitialized && _initStarted)
                    const Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white70,
                        ),
                      ),
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
        return ExtendedImage.network(
          thumbUrl,
          headers: _getHeaders(thumbUrl),
          fit: BoxFit.cover,
          loadStateChanged: (state) {
            if (state.extendedImageLoadState == LoadState.failed) {
              return _buildPlaceholder(isDark, isVideo: true);
            }
            return null;
          },
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
    return Container(
      color: isDark ? const Color(0xFF262626) : Colors.grey.shade200,
      child: Center(
        child: Icon(
          isVideo ? LucideIcons.video : LucideIcons.imageOff,
          color: isDark ? Colors.white24 : Colors.grey.shade400,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildHeader(FeedPost post, bool isDark, ThemeData theme) {
    final avatarUrl =
        post.userAvatar != null ? UrlHelper.absoluteUrl(post.userAvatar!) : '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: GestureDetector(
        onTap: widget.onUserTap,
        child: CircleAvatar(
          backgroundImage:
              avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
          backgroundColor: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade200,
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
      title: GestureDetector(
        onTap: widget.onUserTap,
        child: Text(
          post.userName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      subtitle: post.location != null && post.location!.isNotEmpty
          ? Text(post.location!, style: const TextStyle(fontSize: 12))
          : null,
      trailing: GestureDetector(
        onTap: widget.onMore,
        child: const Icon(LucideIcons.ellipsis),
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
                      post.isFollowed ? LucideIcons.userCheck : LucideIcons.userPlus,
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
          if (post.caption != null && post.caption!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              children: [
                GestureDetector(
                  onTap: widget.onUserTap,
                  child: Text(
                    '${post.userName} ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Text(
                  post.caption!,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(post.createdAt),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
