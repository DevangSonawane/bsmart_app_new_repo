import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../services/media_aspect_cache.dart';
import '../services/video_pool.dart';
import '../utils/url_helper.dart';
import 'safe_network_image.dart';

/// Displays network image or video with a cached, one-time-resolved aspect ratio.
/// Plays only when [isActive] is true (parent-controlled center item).
class DynamicMediaWidget extends StatefulWidget {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final bool isVideo;
  final bool isActive;
  final double? initialAspectRatio;
  final String? filterName;
  final Map<String, int>? adjustments;

  const DynamicMediaWidget({
    super.key,
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.isVideo,
    required this.isActive,
    this.initialAspectRatio,
    this.filterName,
    this.adjustments,
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

  bool get _hasVideoFilter {
    if (!widget.isVideo) return false;
    final name = widget.filterName?.trim().toLowerCase();
    final hasName =
        name != null && name.isNotEmpty && name != 'original' && name != 'none';
    final adj = widget.adjustments ?? const <String, int>{};
    final hasAdj = adj.values.any((v) => v != 0);
    return hasName || hasAdj;
  }

  int _adjValue(String key) {
    final adj = widget.adjustments;
    if (adj == null) return 0;
    final v = adj[key];
    if (v != null) return v;
    if (key == 'saturate') return adj['saturation'] ?? 0;
    if (key == 'sepia') return adj['temperature'] ?? 0;
    if (key == 'opacity') return adj['fade'] ?? 0;
    return 0;
  }

  List<double> _buildFilterMatrixBase({
    double brightness = 1.0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) {
    final b = brightness;
    final c = contrast;
    final s = saturation;
    final invSat = 1 - s;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final scale = c * b;
    return [
      (invSat * lr + s) * scale,
      invSat * lg * scale,
      invSat * lb * scale,
      0,
      0,
      invSat * lr * scale,
      (invSat * lg + s) * scale,
      invSat * lb * scale,
      0,
      0,
      invSat * lr * scale,
      invSat * lg * scale,
      (invSat * lb + s) * scale,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _buildGrayscaleMatrix({
    double contrast = 1.0,
    double brightness = 1.0,
  }) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return [
      r * contrast * brightness,
      g * contrast * brightness,
      b * contrast * brightness,
      0,
      0,
      r * contrast * brightness,
      g * contrast * brightness,
      b * contrast * brightness,
      0,
      0,
      r * contrast * brightness,
      g * contrast * brightness,
      b * contrast * brightness,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _buildSepiaMatrix({
    double amount = 0.2,
    double brightness = 1.0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) {
    final t = 1 - amount;
    final r = 0.393 + 0.607 * t;
    final g = 0.769 - 0.769 * amount;
    final b = 0.189 - 0.189 * amount;
    final invSat = 1 - saturation;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final c = contrast * brightness;
    return [
      (r * saturation + lr * invSat) * c,
      (g * saturation + lg * invSat) * c,
      (b * saturation + lb * invSat) * c,
      0,
      0,
      (0.349 * t + 0.349 * amount) * saturation * c + lr * invSat * c,
      (0.686 + 0.314 * t) * saturation * c + lg * invSat * c,
      (0.168 * t) * saturation * c + lb * invSat * c,
      0,
      0,
      (0.272 * t) * saturation * c + lr * invSat * c,
      (0.534 * t - 0.534 * amount) * saturation * c + lg * invSat * c,
      (0.131 + 0.869 * t) * saturation * c + lb * invSat * c,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _filterMatrixFor(String? name) {
    final n = (name ?? '').trim();
    if (n.isEmpty) return _buildFilterMatrixBase();
    final lower = n.toLowerCase();
    final key = lower.replaceAll('&', 'and').replaceAll(' ', '_');
    switch (n) {
      case 'Clarendon':
        return _buildFilterMatrixBase(
            brightness: 1.0, contrast: 1.2, saturation: 1.25);
      case 'Gingham':
        return _buildFilterMatrixBase(
            brightness: 1.05, contrast: 1.0, saturation: 1.0);
      case 'Moon':
        return _buildGrayscaleMatrix(contrast: 1.1, brightness: 1.1);
      case 'Lark':
        return _buildFilterMatrixBase(
            brightness: 1.0, contrast: 0.9, saturation: 1.0);
      case 'Reyes':
        return _buildSepiaMatrix(
            amount: 0.22, brightness: 1.1, contrast: 0.85, saturation: 0.75);
      case 'Juno':
        return _buildSepiaMatrix(
            amount: 0.2, brightness: 1.1, contrast: 1.2, saturation: 1.4);
      case 'Slumber':
        return _buildSepiaMatrix(
            amount: 0.2, brightness: 1.05, contrast: 1.0, saturation: 0.66);
      case 'Crema':
        return _buildSepiaMatrix(
            amount: 0.2, brightness: 1.0, contrast: 0.9, saturation: 0.9);
      case 'Ludwig':
        return _buildFilterMatrixBase(
            brightness: 1.1, contrast: 0.9, saturation: 0.9);
      case 'Aden':
        return _buildFilterMatrixBase(
            brightness: 1.2, contrast: 0.9, saturation: 0.85);
      case 'Perpetua':
        return _buildFilterMatrixBase(
            brightness: 1.1, contrast: 1.1, saturation: 1.1);
      case 'Original':
        return _buildFilterMatrixBase();
      default:
        break;
    }
    switch (key) {
      case 'none':
      case 'original':
        return _buildFilterMatrixBase();
      case 'vintage':
        return _buildSepiaMatrix(
            amount: 0.35, brightness: 1.05, contrast: 0.95, saturation: 0.9);
      case 'black_white':
      case 'black_and_white':
        return _buildGrayscaleMatrix(contrast: 1.1, brightness: 1.0);
      case 'warm':
        return _buildSepiaMatrix(
            amount: 0.25, brightness: 1.05, contrast: 1.0, saturation: 1.1);
      case 'cool':
        return _buildFilterMatrixBase(
            brightness: 1.0, contrast: 1.0, saturation: 0.85);
      case 'dramatic':
        return _buildFilterMatrixBase(
            brightness: 1.0, contrast: 1.3, saturation: 1.2);
      case 'beauty':
        return _buildSepiaMatrix(
            amount: 0.15, brightness: 1.1, contrast: 1.05, saturation: 1.05);
      case 'ar_effect_1':
        return _buildFilterMatrixBase(
            brightness: 1.05, contrast: 1.05, saturation: 1.2);
      case 'ar_effect_2':
        return _buildFilterMatrixBase(
            brightness: 0.95, contrast: 1.1, saturation: 0.9);
      default:
        return _buildFilterMatrixBase();
    }
  }

  List<double> _buildAdjustmentMatrix({
    double brightness = 1.0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) {
    return _buildFilterMatrixBase(
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    );
  }

  Widget _applyFilterToWidget(Widget child) {
    if (!_hasVideoFilter) return child;
    final lux = ((_adjValue('lux')).clamp(0, 100) / 100.0);
    final luxBC = 1.0 + (lux * 0.35);
    final luxS = 1.0 + (lux * 0.2);
    final b = ((_adjValue('brightness')) / 100.0 + 1.0) * luxBC;
    final c = ((_adjValue('contrast')) / 100.0 + 1.0) * luxBC;
    final s = ((_adjValue('saturate')) / 100.0 + 1.0) * luxS;
    final opacity = 1.0 - (_adjValue('opacity') / 100.0);
    final presetMatrix = _filterMatrixFor(widget.filterName);
    final adjustmentMatrix =
        _buildAdjustmentMatrix(brightness: b, contrast: c, saturation: s);
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(presetMatrix),
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix(adjustmentMatrix),
          child: child,
        ),
      ),
    );
  }

  void _precacheThumbnail() {
    final thumb = widget.thumbnailUrl?.trim();
    if (thumb == null || thumb.isEmpty) return;
    final lower = thumb.toLowerCase();
    // Avoid triggering platform decoder errors during precache for formats we
    // can't safely handle here.
    if (lower.contains('.svg') ||
        lower.contains('.avif') ||
        lower.contains('.heic') ||
        lower.contains('.heif') ||
        !lower.contains('.')) {
      return;
    }
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
        // Became inactive — pause (keep controller reference so the last frame
        // stays visible and we avoid black flashes while scrolling).
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
        _ratio = ctl.value.isInitialized
            ? ctl.value.aspectRatio
            : (_ratio ?? 9 / 16);
        _videoFailed = false;
        _loadingVideo = false;
      });
    } on PlatformException catch (e) {
      debugPrint(
          'DynamicMediaWidget: PlatformException for ${widget.id}: ${e.message}');
      if (mounted)
        setState(() {
          _videoFailed = true;
          _loadingVideo = false;
        });
    } on TimeoutException catch (e) {
      debugPrint('DynamicMediaWidget: Timeout for ${widget.id}: $e');
      if (mounted)
        setState(() {
          _videoFailed = true;
          _loadingVideo = false;
        });
    } catch (e) {
      debugPrint('DynamicMediaWidget: Unknown error for ${widget.id}: $e');
      if (mounted)
        setState(() {
          _videoFailed = true;
          _loadingVideo = false;
        });
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
        _ratio = ctl.value.isInitialized
            ? ctl.value.aspectRatio
            : (_ratio ?? 9 / 16);
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
    return SafeNetworkImage(
      url: widget.url,
      cacheKey: widget.url,
      headers: UrlHelper.shouldAttachAuthHeader(widget.url)
          ? _cachedAuthHeaders
          : const <String, String>{},
      fit: BoxFit.cover,
      placeholder: const SizedBox.expand(),
      errorWidget: const SizedBox.expand(),
    );
  }

  Widget _buildVideo() {
    // Start loading as soon as widget is active, don't wait for build
    if (widget.isActive &&
        _videoCtl == null &&
        !_videoFailed &&
        !_loadingVideo) {
      _ensureVideo();
    }
    final thumb = _applyFilterToWidget(_buildVideoPlaceholder());
    final ctl = _videoCtl;
    final canShowVideo = _isControllerUsable(ctl);
    try {
      return Stack(
        fit: StackFit.expand,
        children: [
          thumb,
          if (ctl != null && canShowVideo)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              opacity: 1,
              child: _applyFilterToWidget(
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: ctl.value.size.width,
                    height: ctl.value.size.height,
                    child: VideoPlayer(ctl),
                  ),
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
      return SafeNetworkImage(
        url: thumb.trim(),
        cacheKey: thumb.trim(),
        headers: UrlHelper.shouldAttachAuthHeader(thumb.trim())
            ? _cachedAuthHeaders
            : const <String, String>{},
        fit: BoxFit.cover,
        placeholder: const _VideoPlaceholder(),
        errorWidget: const _VideoPlaceholder(),
      );
    }
    return const _VideoPlaceholder();
  }
}

class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    // Use a consistently dark placeholder to avoid "white screen" flashes.
    // The actual thumbnail (when present) is drawn above this immediately.
    const c1 = Color(0xFF1B1B1F);
    const c2 = Color(0xFF2A2A2F);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c1, c2],
        ),
      ),
    );
  }
}

/// Call once at app startup to pre-cache auth headers for media loading.
Future<void> primeMediaAuthHeaders() async {
  await _DynamicMediaWidgetState.ensureAuthHeaders();
}
