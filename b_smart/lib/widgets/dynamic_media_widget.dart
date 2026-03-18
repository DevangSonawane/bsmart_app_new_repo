import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../services/media_aspect_cache.dart';
import '../services/video_pool.dart';

/// Displays network image or video with a cached, one-time-resolved aspect ratio.
/// Plays only when [isActive] is true (parent-controlled center item).
class DynamicMediaWidget extends StatefulWidget {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final bool isVideo;
  final bool isActive;

  const DynamicMediaWidget({
    super.key,
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.isVideo,
    required this.isActive,
  });

  @override
  State<DynamicMediaWidget> createState() => _DynamicMediaWidgetState();
}

class _DynamicMediaWidgetState extends State<DynamicMediaWidget> {
  double? _ratio;
  VideoPlayerController? _videoCtl;
  bool _loadingVideo = false;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    _primeRatio();
  }

  @override
  void didUpdateWidget(covariant DynamicMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.thumbnailUrl != widget.thumbnailUrl) {
      _ratio = MediaAspectCache.instance.get(widget.url) ??
          (widget.thumbnailUrl != null
              ? MediaAspectCache.instance.get(widget.thumbnailUrl!)
              : null);
      _primeRatio();
      _disposeVideo();
    }
    if (widget.isVideo && widget.isActive) {
      _ensureVideo();
    } else {
      _disposeVideo();
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
      if (mounted) setState(() => _ratio = r);
    } else {
      final thumb = widget.thumbnailUrl;
      if (thumb != null && thumb.trim().isNotEmpty) {
        final cachedThumb = MediaAspectCache.instance.get(thumb);
        if (cachedThumb != null) {
          if (mounted) setState(() => _ratio = cachedThumb);
          return;
        }
        final r = await MediaAspectCache.instance.resolveImageRatio(thumb);
        if (mounted) setState(() => _ratio = r);
        return;
      }
      if (mounted) setState(() => _ratio = 9 / 16);
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
    try {
      final ctl = await VideoPool.instance.attach(widget.id, url);
      if (!mounted) {
        _loadingVideo = false;
        return;
      }
      if (!ctl.value.isInitialized) {
        await ctl.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Video init timed out'),
        );
      }
      if (!mounted) {
        _loadingVideo = false;
        return;
      }
      setState(() {
        _videoCtl = ctl;
        _ratio = ctl.value.isInitialized ? ctl.value.aspectRatio : (_ratio ?? 9 / 16);
        _videoFailed = false;
      });
      await ctl.play();
    } on PlatformException catch (e) {
      debugPrint('DynamicMediaWidget: PlatformException for ${widget.id}: ${e.message}');
      if (mounted) setState(() => _videoFailed = true);
    } on TimeoutException catch (e) {
      debugPrint('DynamicMediaWidget: Timeout for ${widget.id}: $e');
      if (mounted) setState(() => _videoFailed = true);
    } catch (e) {
      debugPrint('DynamicMediaWidget: Unknown error for ${widget.id}: $e');
      if (mounted) setState(() => _videoFailed = true);
    } finally {
      _loadingVideo = false;
    }
  }

  Future<void> _disposeVideo() async {
    if (_videoCtl != null) {
      await VideoPool.instance.pauseIf(widget.id);
      _videoCtl = null;
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _ratio ?? 1.0;
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
      httpHeaders: const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      placeholder: (_, __) => const ColoredBox(color: Colors.black12),
      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
    );
  }

  Widget _buildVideo() {
    if (widget.isActive && _videoCtl == null && !_videoFailed) {
      _ensureVideo();
    }
    if (_videoFailed) return _buildVideoPlaceholder();
    if (!widget.isActive) {
      return _buildVideoPlaceholder();
    }
    if (_videoCtl == null || !_videoCtl!.value.isInitialized) {
      return _buildVideoPlaceholder();
    }
    try {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoCtl!.value.size.width,
          height: _videoCtl!.value.size.height,
          child: VideoPlayer(_videoCtl!),
        ),
      );
    } catch (e) {
      try {
        print('DynamicMediaWidget: error while building VideoPlayer for id=${widget.id} error=$e');
      } catch (_) {}
      return _buildVideoPlaceholder();
    }
  }

  Widget _buildVideoPlaceholder() {
    final thumb = widget.thumbnailUrl;
    if (thumb != null && thumb.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumb.trim(),
        cacheKey: thumb.trim(),
        httpHeaders: const {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        placeholder: (_, __) => const ColoredBox(color: Colors.black12),
        errorWidget: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image)),
      );
    }
    return const ColoredBox(color: Colors.black12);
  }
}
