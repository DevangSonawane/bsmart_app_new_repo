import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../services/media_aspect_cache.dart';
import '../services/video_pool.dart';
import '../utils/url_helper.dart';

/// Displays network image or video with a cached, one-time-resolved aspect ratio.
/// Plays only when [isActive] is true (parent-controlled center item).
class DynamicMediaWidget extends StatefulWidget {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final bool isVideo;
  final bool isActive;
  final double? initialAspectRatio;

  const DynamicMediaWidget({
    super.key,
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.isVideo,
    required this.isActive,
    this.initialAspectRatio,
  });

  @override
  State<DynamicMediaWidget> createState() => _DynamicMediaWidgetState();
}

class _DynamicMediaWidgetState extends State<DynamicMediaWidget> {
  static Map<String, String> _cachedAuthHeaders = const {};
  static bool _authHeadersLoaded = false;

  static Future<void> ensureAuthHeaders() async {
    if (_authHeadersLoaded) return;
    _authHeadersLoaded = true;
    try {
      final token = await ApiClient().getToken();
      if (token != null && token.isNotEmpty) {
        _cachedAuthHeaders = {'Authorization': 'Bearer $token'};
        // Pass auth headers to aspect ratio resolver so it can fetch image dimensions
        MediaAspectCache.instance.setAuthHeaders(_cachedAuthHeaders);
      } else {
        // Token not available yet — reset so next call retries
        _authHeadersLoaded = false;
      }
    } catch (_) {
      _authHeadersLoaded = false;
    }
  }

  double? _ratio;
  VideoPlayerController? _videoCtl;
  bool _loadingVideo = false;
  bool _videoFailed = false;

  void _precacheThumbnail() {
    final thumb = widget.thumbnailUrl?.trim();
    if (thumb == null || thumb.isEmpty) return;
    final headers = UrlHelper.shouldAttachAuthHeader(thumb)
        ? _cachedAuthHeaders
        : const <String, String>{};
    final provider = CachedNetworkImageProvider(
      thumb,
      headers: headers,
      cacheKey: thumb,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(provider, context);
    });
  }

  @override
  void initState() {
    super.initState();
    _ratio = MediaAspectCache.instance.get(widget.url) ??
        (widget.thumbnailUrl != null
            ? MediaAspectCache.instance.get(widget.thumbnailUrl!)
            : null);
    _ratio ??= widget.initialAspectRatio;
    _primeRatio();
    if (_cachedAuthHeaders.isEmpty) {
      ensureAuthHeaders().then((_) {
        if (mounted && _cachedAuthHeaders.isNotEmpty) {
          setState(() {});
          _precacheThumbnail();
        }
      });
    } else {
      _precacheThumbnail();
    }
  }

  @override
  void didUpdateWidget(covariant DynamicMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final urlChanged = oldWidget.url != widget.url ||
        oldWidget.thumbnailUrl != widget.thumbnailUrl ||
        oldWidget.initialAspectRatio != widget.initialAspectRatio;

    if (urlChanged) {
      _ratio = MediaAspectCache.instance.get(widget.url) ??
          (widget.thumbnailUrl != null
              ? MediaAspectCache.instance.get(widget.thumbnailUrl!)
              : null);
      _ratio ??= widget.initialAspectRatio;
      // Synchronously null _videoCtl before any async work
      _videoCtl = null;
      _loadingVideo = false;
      _videoFailed = false;
      VideoPool.instance.pauseIf(oldWidget.id);
      _primeRatio();
      _precacheThumbnail();
    }

    if (widget.isVideo) {
      if (widget.isActive && !oldWidget.isActive) {
        // Became active — start loading
        if (_videoCtl == null) {
          _ensureVideo();
        } else {
          _resumeVideoIfNeeded();
        }
      } else if (!widget.isActive && oldWidget.isActive) {
        // Became inactive — pause and release reference
        _loadingVideo = false;
        VideoPool.instance.pauseIf(widget.id);
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _primeRatio() async {
    final cached = MediaAspectCache.instance.get(widget.url);
    if (cached != null) {
      setState(() => _ratio = cached);
      return;
    }
    if (!widget.isVideo) {
      final r = await MediaAspectCache.instance.resolveImageRatio(widget.url);
      if (mounted && _ratio != r) setState(() => _ratio = r);
    } else {
      final thumb = widget.thumbnailUrl;
      if (thumb != null && thumb.trim().isNotEmpty) {
        final cachedThumb = MediaAspectCache.instance.get(thumb);
        if (cachedThumb != null) {
          if (mounted && _ratio != cachedThumb) {
            setState(() => _ratio = cachedThumb);
          }
          return;
        }
        final r = await MediaAspectCache.instance.resolveImageRatio(thumb);
        if (mounted && _ratio != r) setState(() => _ratio = r);
        return;
      }
      if (mounted && _ratio != 9 / 16) setState(() => _ratio = 9 / 16);
    }
  }

  Future<void> _ensureVideo() async {
    if (_loadingVideo || _videoCtl != null || _videoFailed) return;
    
    final url = widget.url.trim();
    if (url.isEmpty) {
      if (mounted) setState(() => _videoFailed = true);
      return;
    }
    
    _loadingVideo = true;
    if (mounted) setState(() {});
    try {
      final ctl = await VideoPool.instance.attach(widget.id, url);
      if (!mounted) {
        _loadingVideo = false;
        return;
      }
      setState(() {
        _videoCtl = ctl;
        _ratio = ctl.value.isInitialized ? ctl.value.aspectRatio : (_ratio ?? 9 / 16);
        _videoFailed = false;
        _loadingVideo = false;
      });
    } on PlatformException catch (e) {
      debugPrint('DynamicMediaWidget: PlatformException for ${widget.id}: ${e.message}');
      if (mounted) setState(() { _videoFailed = true; _loadingVideo = false; });
    } on TimeoutException catch (e) {
      debugPrint('DynamicMediaWidget: Timeout for ${widget.id}: $e');
      if (mounted) setState(() { _videoFailed = true; _loadingVideo = false; });
    } catch (e) {
      debugPrint('DynamicMediaWidget: Unknown error for ${widget.id}: $e');
      if (mounted) setState(() { _videoFailed = true; _loadingVideo = false; });
    }
  }

  Future<void> _resumeVideoIfNeeded() async {
    if (_loadingVideo || _videoFailed) return;
    final url = widget.url.trim();
    if (url.isEmpty) return;
    try {
      final ctl = await VideoPool.instance.attach(widget.id, url);
      if (!mounted) return;
      setState(() {
        _videoCtl = ctl;
        _ratio = ctl.value.isInitialized ? ctl.value.aspectRatio : (_ratio ?? 9 / 16);
        _videoFailed = false;
        _loadingVideo = false;
      });
    } catch (_) {}
  }

  bool _isControllerUsable(VideoPlayerController? ctl) {
    if (ctl == null) return false;
    try {
      return ctl.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  Future<void> _disposeVideo() async {
    final ctl = _videoCtl;
    _videoCtl = null;
    _loadingVideo = false;
    _videoFailed = false;
    if (ctl != null) {
      await VideoPool.instance.pauseIf(widget.id);
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _ratio ?? (widget.isVideo ? 9 / 16 : 4 / 5);
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: aspect,
        child: widget.isVideo ? _buildVideo() : _buildImage(),
      ),
    );
  }

  Widget _buildImage() {
    return CachedNetworkImage(
      imageUrl: widget.url,
      cacheKey: widget.url,
      httpHeaders: UrlHelper.shouldAttachAuthHeader(widget.url)
          ? _cachedAuthHeaders
          : const {},
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholderFadeInDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: (_, __) => const SizedBox.expand(),
      errorWidget: (_, __, ___) => const SizedBox.expand(),
    );
  }

  Widget _buildVideo() {
    // Start loading as soon as widget is active, don't wait for build
    if (widget.isActive && _videoCtl == null && !_videoFailed && !_loadingVideo) {
      _ensureVideo();
    }
    if (!widget.isActive && _videoCtl == null) {
      final prewarmed = VideoPool.instance.peek(widget.id);
      if (prewarmed != null &&
          prewarmed.value.isInitialized) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_videoCtl == null) setState(() => _videoCtl = prewarmed);
        });
      }
    }
    final thumb = _buildVideoPlaceholder();
    final ctl = _videoCtl;
    final canShowVideo = _isControllerUsable(ctl);
    if (ctl != null && !canShowVideo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_videoCtl == ctl) setState(() => _videoCtl = null);
      });
      return thumb;
    }
    try {
      return Stack(
        fit: StackFit.expand,
        children: [
          thumb,
          if (ctl != null)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              opacity: canShowVideo ? 1 : 0,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: ctl.value.size.width,
                  height: ctl.value.size.height,
                  child: VideoPlayer(ctl),
                ),
              ),
            ),
          if (_loadingVideo && widget.isActive)
            const Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
        ],
      );
    } catch (e) {
      try {
        print(
            'DynamicMediaWidget: error while building VideoPlayer for id=${widget.id} error=$e');
      } catch (_) {}
      return thumb;
    }
  }

  Widget _buildVideoPlaceholder() {
    final thumb = widget.thumbnailUrl;
    if (thumb != null && thumb.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumb.trim(),
        cacheKey: thumb.trim(),
        httpHeaders: UrlHelper.shouldAttachAuthHeader(thumb.trim())
            ? _cachedAuthHeaders
            : const {},
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (_, __) => const _VideoPlaceholder(),
        errorWidget: (_, __, ___) => const _VideoPlaceholder(),
      );
    }
    return const _VideoPlaceholder();
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: Colors.black);
  }
}

/// Call once at app startup to pre-cache auth headers for media loading.
Future<void> primeMediaAuthHeaders() async {
  await _DynamicMediaWidgetState.ensureAuthHeaders();
}
