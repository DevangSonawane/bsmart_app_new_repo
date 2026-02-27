import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/feed_post_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import '../api/api_client.dart';
import '../config/api_config.dart';
import '../theme/design_tokens.dart';
import '../utils/url_helper.dart';

class _TrianglePainter extends CustomPainter {
  final bool isUp;
  final Color color;

  _TrianglePainter({this.isUp = true, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isUp) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PostCard extends StatefulWidget {
  final FeedPost post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;

  const PostCard({
    Key? key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onFollow,
    this.onMore,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoCtl;
  Future<void>? _initVideo;
  Map<String, String>? _imageHeaders;
  String? _resolvedImageUrl;
  String? _resolvedThumbnailUrl;
  double? _mediaAspect;
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  late final Animation<double> _heartOpacity;
  bool _isHeartAnimating = false;
  bool _isVisible = false;
  bool _isMuted = true;
  bool _isPlaying = true;
  bool _showTags = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_heartController);
    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_heartController);
    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        _isHeartAnimating = false;
      }
    });
    ApiClient().getToken().then((token) {
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        setState(() {
          _imageHeaders = {'Authorization': 'Bearer $token'};
        });
        _setupMedia();
      }
    });
    _setupMedia();

    if (widget.post.isTagged && (widget.post.peopleTags?.isNotEmpty ?? false)) {
      Future.delayed(Duration.zero, () {
        if (mounted) setState(() => _showTags = true);
      });
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _showTags = false);
      });
    }
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFirst = oldWidget.post.mediaUrls.isNotEmpty ? oldWidget.post.mediaUrls.first : '';
    final newFirst = widget.post.mediaUrls.isNotEmpty ? widget.post.mediaUrls.first : '';
    if (oldWidget.post.id != widget.post.id ||
        oldFirst != newFirst ||
        oldWidget.post.mediaType != widget.post.mediaType) {
      _disposeVideo();
      _setupMedia();
    }
  }

  bool _likeAnim = false;

  void _onLikePressed() {
    _toggleLike();
  }

  void _toggleLike({bool onlyLike = false}) {
    final shouldLike = !widget.post.isLiked;
    if (onlyLike && !shouldLike) return;
    setState(() => _likeAnim = true);
    widget.onLike?.call();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _likeAnim = false);
    });
  }

  void _togglePlay() {
    if (_videoCtl == null) return;
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _videoCtl!.play();
      } else {
        _videoCtl!.pause();
      }
    });
  }

  void _toggleMute() {
    if (_videoCtl == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoCtl!.setVolume(_isMuted ? 0 : 1.0);
    });
  }

  void _toggleTags() {
    if (widget.post.isTagged && (widget.post.peopleTags?.isNotEmpty ?? false)) {
      setState(() => _showTags = !_showTags);
    }
  }

  /// Safely extracts a valid non-empty string ID from a dynamic value.
  /// Returns null if the value is null, not a String, empty, or literally "null".
  String? _extractStringId(dynamic value) {
    if (value == null) return null;
    if (value is! String) return null;
    final trimmed = value.trim();
    // Fix: React web app also checks for "undefined" or "null" strings
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null' || trimmed.toLowerCase() == 'undefined') return null;
    return trimmed;
  }

  void _navigateToProfile(Map<String, dynamic> tag) {
    // 1. Try direct string IDs at the top level first
    String? uid = _extractStringId(tag['user_id'])
        ?? _extractStringId(tag['_id'])
        ?? _extractStringId(tag['id']);

    // 2. If not found, check if user_id or user is a populated object and dig into it
    if (uid == null) {
      final nested = tag['user_id'] ?? tag['user'];
      if (nested is Map) {
        uid = _extractStringId(nested['_id'])
            ?? _extractStringId(nested['id'])
            ?? _extractStringId(nested['user_id']);
      }
    }

    final String? username = tag['username']?.toString();

    if (uid != null) {
      debugPrint("Navigating to profile: $uid (@$username)");
      Navigator.of(context).pushNamed('/profile/$uid');
    } else {
      debugPrint("Routing Error: No valid ID found in tag: $tag");
    }
  }

  void _onMediaDoubleTap() {
    if (_isHeartAnimating) return;
    _toggleLike(onlyLike: true);
    _isHeartAnimating = true;
    _heartController.forward(from: 0);
  }

  void _setupMedia() {
    final url = widget.post.mediaUrls.isNotEmpty ? widget.post.mediaUrls.first : '';
    if (url.isEmpty) return;

    if (widget.post.mediaType == PostMediaType.video ||
        widget.post.mediaType == PostMediaType.reel) {
      if (widget.post.thumbnailUrl != null && widget.post.thumbnailUrl!.isNotEmpty) {
        final candidates = _candidateUrls(widget.post.thumbnailUrl!);
        setState(() {
          _resolvedThumbnailUrl = candidates.first;
        });
      }

      if (_isVisible) {
        setState(() {
          _initVideo = _initVideoFromCandidates(_candidateUrls(url));
        });
      } else {
        _disposeVideo();
      }
    } else {
      _resolveImageUrl(url);
    }
  }

  void _disposeVideo() {
    _videoCtl?.dispose();
    _videoCtl = null;
    _initVideo = null;
    _mediaAspect = null;
  }

  @override
  void dispose() {
    _heartController.dispose();
    _disposeVideo();
    super.dispose();
  }

  List<String> _candidateUrls(String url) {
    String abs = UrlHelper.absoluteUrl(url);
    final alts = <String>[abs];
    if (abs.startsWith('http://')) {
      alts.add(abs.replaceFirst('http://', 'https://'));
    }
    if (abs.contains('/api/uploads/')) {
      alts.add(abs.replaceFirst('/api/uploads/', '/uploads/'));
    } else if (abs.contains('/uploads/')) {
      alts.add(abs.replaceFirst('/uploads/', '/api/uploads/'));
    }
    return alts.toSet().toList();
  }

  Future<void> _resolveImageUrl(String url) async {
    final headers = _imageHeaders ?? {};
    final candidates = _candidateUrls(url);
    if (headers.isEmpty) {
      if (mounted) setState(() => _resolvedImageUrl = candidates.first);
      return;
    }
    for (final u in candidates) {
      try {
        final resp = await http.get(
          Uri.parse(u),
          headers: {
            ...headers,
            'Range': 'bytes=0-0',
            'Accept': 'image/*',
          },
        ).timeout(const Duration(seconds: 8));
        final ok = (resp.statusCode >= 200 && resp.statusCode < 300) || resp.statusCode == 206;
        if (ok) {
          if (!mounted) return;
          setState(() => _resolvedImageUrl = u);
          return;
        }
      } catch (_) {}
    }
    for (final u in candidates) {
      try {
        final resp = await http.get(
          Uri.parse(u),
          headers: {
            ...headers,
            'Accept': 'image/*',
          },
        ).timeout(const Duration(seconds: 8));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          if (!mounted) return;
          setState(() => _resolvedImageUrl = u);
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _resolvedImageUrl = candidates.first);
  }

  void _computeImageAspect(ImageProvider provider) {
    final imageStream = provider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h > 0) {
        final ar = w / h;
        if (mounted) setState(() => _mediaAspect = _normalizedAspect(ar));
      }
      imageStream.removeListener(listener!);
    }, onError: (_, __) {
      imageStream.removeListener(listener!);
    });
    imageStream.addListener(listener);
  }

  double _normalizedAspect(double raw) {
    if (raw.isNaN || raw <= 0) return 1.0;
    if (widget.post.isAd) return 1.0;
    if (raw < 0.9) return 4 / 5;
    if (raw > 1.2) return 16 / 9;
    return 1.0;
  }

  Future<void> _initVideoFromCandidates(List<String> candidates) async {
    if (_imageHeaders == null) {
      final token = await ApiClient().getToken();
      if (token != null && token.isNotEmpty) {
        if (mounted) {
          setState(() {
            _imageHeaders = {'Authorization': 'Bearer $token'};
          });
        } else {
          _imageHeaders = {'Authorization': 'Bearer $token'};
        }
      }
    }
    final headers = _imageHeaders ?? {};
    for (final u in candidates) {
      try {
        _videoCtl?.dispose();
        _videoCtl = VideoPlayerController.networkUrl(Uri.parse(u), httpHeaders: headers);
        await _videoCtl!.initialize();
        if (mounted && _isVisible) {
          _videoCtl!.setLooping(true);
          _videoCtl!.setVolume(_isMuted ? 0 : 1.0);
          if (_isPlaying) {
            _videoCtl!.play();
          }
        }
        if (mounted) {
          setState(() {
            _mediaAspect = _normalizedAspect(_videoCtl!.value.aspectRatio);
          });
        }
        return;
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final displayName = post.fullName?.trim().isNotEmpty == true
        ? post.fullName!
        : post.userName;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardColor;
    final textColor = theme.colorScheme.onSurface;
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600;

    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (info) {
        final visibleFraction = info.visibleFraction;
        if (visibleFraction > 0.6) {
          if (!_isVisible) {
            _isVisible = true;
            _setupMedia();
          }
        } else {
          if (_isVisible) {
            _isVisible = false;
            _disposeVideo();
            if (mounted) setState(() {});
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(0),
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: post.userId.isNotEmpty
                          ? () => Navigator.of(context).pushNamed('/profile/${post.userId}')
                          : null,
                      borderRadius: BorderRadius.circular(24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: DesignTokens.instaGradient,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade200,
                                backgroundImage: post.userAvatar != null && post.userAvatar!.isNotEmpty
                                    ? NetworkImage(post.userAvatar!)
                                    : null,
                                child: post.userAvatar == null || post.userAvatar!.isEmpty
                                    ? Text(
                                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                        style: TextStyle(
                                          color: DesignTokens.instaPink,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: textColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (post.isVerified) ...[
                                      const SizedBox(width: 4),
                                      Icon(LucideIcons.badgeCheck, size: 14, color: Colors.blue.shade400),
                                    ],
                                    if (post.mediaType == PostMediaType.reel) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'REEL',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: mutedColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (widget.onFollow != null && !post.isFollowed)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: widget.onFollow,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.transparent : Colors.grey.shade100,
                                border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Follow',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        onPressed: widget.onMore ?? () {},
                        icon: Icon(LucideIcons.ellipsis, size: 24, color: textColor),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Media ────────────────────────────────────────────────────────
            if (post.mediaUrls.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 600),
                width: double.infinity,
                child: AspectRatio(
                  aspectRatio: _mediaAspect ?? 1.0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: _onMediaDoubleTap,
                    onTap: (post.mediaType == PostMediaType.video || post.mediaType == PostMediaType.reel)
                        ? _togglePlay
                        : _toggleTags,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background / media content
                        Container(
                          color: isDark ? Colors.black : Colors.grey.shade200,
                          child: post.isAd
                              ? CachedNetworkImage(
                                  imageUrl: _resolvedImageUrl ?? post.mediaUrls.first,
                                  cacheKey:
                                      '${_resolvedImageUrl ?? post.mediaUrls.first}#${_imageHeaders?['Authorization'] ?? ''}',
                                  httpHeaders: _imageHeaders,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  placeholder: (ctx, url) => Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: DesignTokens.instaPink,
                                    ),
                                  ),
                                  errorWidget: (ctx, url, err) => Center(
                                    child: Icon(LucideIcons.imageOff, size: 48, color: mutedColor),
                                  ),
                                )
                              : (post.mediaType == PostMediaType.video ||
                                      post.mediaType == PostMediaType.reel)
                                  ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // 1. Thumbnail placeholder
                                        if (_resolvedThumbnailUrl != null)
                                          CachedNetworkImage(
                                            imageUrl: _resolvedThumbnailUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (ctx, url) => Container(color: Colors.black),
                                            errorWidget: (ctx, url, err) => Container(color: Colors.black),
                                          )
                                        else
                                          Container(color: Colors.black),

                                        // 2. Video player
                                        if (_videoCtl != null)
                                          FutureBuilder(
                                            future: _initVideo,
                                            builder: (ctx, snap) {
                                              if (snap.connectionState == ConnectionState.done &&
                                                  _videoCtl!.value.isInitialized) {
                                                return Center(
                                                  child: AspectRatio(
                                                    aspectRatio: _videoCtl!.value.aspectRatio,
                                                    child: VideoPlayer(_videoCtl!),
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),

                                        // 3. Loading spinner
                                        if (_videoCtl != null)
                                          FutureBuilder(
                                            future: _initVideo,
                                            builder: (ctx, snap) {
                                              if (snap.connectionState != ConnectionState.done) {
                                                return Center(
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white.withOpacity(0.5),
                                                  ),
                                                );
                                              }
                                              return const SizedBox.shrink();
                                            },
                                          ),

                                        // 4. Reel icon
                                        if (post.mediaType == PostMediaType.reel)
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: Icon(
                                              LucideIcons.play,
                                              color: Colors.white.withOpacity(0.7),
                                              size: 18,
                                            ),
                                          ),
                                      ],
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: _resolvedImageUrl ?? post.mediaUrls.first,
                                      cacheKey:
                                          '${_resolvedImageUrl ?? post.mediaUrls.first}#${_imageHeaders?['Authorization'] ?? ''}',
                                      httpHeaders: _imageHeaders,
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      placeholder: (ctx, url) => Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: DesignTokens.instaPink,
                                        ),
                                      ),
                                      errorWidget: (ctx, url, err) => Center(
                                        child: Icon(LucideIcons.imageOff, size: 48, color: mutedColor),
                                      ),
                                    ),
                        ),

                        // Double-tap heart animation
                        IgnorePointer(
                          child: FadeTransition(
                            opacity: _heartOpacity,
                            child: ScaleTransition(
                              scale: _heartScale,
                              child: Icon(
                                LucideIcons.heart,
                                size: 96,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ),

                        // Pause indicator
                        if (!_isPlaying && _videoCtl != null)
                          IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.play, color: Colors.white, size: 32),
                              ),
                            ),
                          ),

                        // Mute toggle button
                        if (_videoCtl != null)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: GestureDetector(
                              onTap: _toggleMute,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
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

                        // People tag bubbles overlay
                        if (_showTags && post.peopleTags != null && post.peopleTags!.isNotEmpty)
                          ...post.peopleTags!.map((tag) {
                            final x = (tag['x'] as num?)?.toDouble() ?? 50.0;
                            final y = (tag['y'] as num?)?.toDouble() ?? 50.0;
                            final username = tag['username'] as String? ?? 'User';
                            final cx = x.clamp(12.0, 88.0);
                            final cy = y.clamp(12.0, 88.0);
                            final inBottomHalf = y > 55;

                            return Positioned(
                              left: (cx / 100) * MediaQuery.of(context).size.width,
                              top: (cy / 100) *
                                  (_mediaAspect != null
                                      ? MediaQuery.of(context).size.width / _mediaAspect!
                                      : MediaQuery.of(context).size.width),
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -0.5),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.elasticOut,
                                  builder: (context, value, child) {
                                    return Transform.scale(scale: value, child: child);
                                  },
                                  child: GestureDetector(
                                    onTap: () => _navigateToProfile(tag),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!inBottomHalf)
                                          CustomPaint(
                                            size: const Size(12, 6),
                                            painter: _TrianglePainter(
                                              isUp: true,
                                              color: Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.15),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            '@$username',
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ),
                                        if (inBottomHalf)
                                          CustomPaint(
                                            size: const Size(12, 6),
                                            painter: _TrianglePainter(
                                              isUp: false,
                                              color: Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),

                        // Tag indicator button (bottom-left)
                        if (post.peopleTags != null && post.peopleTags!.isNotEmpty)
                          Positioned(
                            bottom: 12,
                            left: 12,
                            child: GestureDetector(
                              onTap: () => setState(() => _showTags = !_showTags),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.user, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )
            else
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade200,
                  child: Center(
                    child: Icon(LucideIcons.image, size: 48, color: mutedColor),
                  ),
                ),
              ),

            // ── Action bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.5, vertical: 0.5),
              child: Row(
                children: [
                  AnimatedScale(
                    scale: _likeAnim ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: IconButton(
                      onPressed: _onLikePressed,
                      icon: Icon(
                        post.isLiked ? Icons.favorite : LucideIcons.heart,
                        size: 24,
                        color: post.isLiked ? Colors.red : textColor,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onComment ?? () {},
                    icon: Icon(LucideIcons.messageCircle, size: 24, color: textColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  IconButton(
                    onPressed: widget.onShare ?? () {},
                    icon: Icon(LucideIcons.send, size: 24, color: textColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onSave ?? () {},
                    icon: Icon(
                      post.isSaved ? Icons.bookmark : LucideIcons.bookmark,
                      size: 24,
                      color: textColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                ],
              ),
            ),

            // ── Likes count ──────────────────────────────────────────────────
            if (post.likes > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                child: Text(
                  '${post.likes} ${post.likes == 1 ? 'like' : 'likes'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
              ),

            // ── Caption ──────────────────────────────────────────────────────
            if ((post.caption ?? '').trim().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: RichText(
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: textColor, height: 1.3),
                    children: [
                      TextSpan(
                        text: '${post.userName} ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: post.caption),
                    ],
                  ),
                ),
              ),
            ],

            // ── People tags list ─────────────────────────────────────────────
            if (post.peopleTags != null && post.peopleTags!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: post.peopleTags!.map((tag) {
                    final username = tag['username'] as String? ?? 'User';
                    return GestureDetector(
                      onTap: () => _navigateToProfile(tag),
                      child: Text(
                        '@$username',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0095F6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            // ── Comments preview ─────────────────────────────────────────────
            if (post.comments > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: GestureDetector(
                  onTap: widget.onComment,
                  child: Text(
                    'View all ${post.comments} ${post.comments == 1 ? 'comment' : 'comments'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // ── Time posted ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 12),
              child: Text(
                _formatTimeAgo(post.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: mutedColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    if (diff.inSeconds > 30) return '${diff.inSeconds}s';
    return 'Just now';
  }
}