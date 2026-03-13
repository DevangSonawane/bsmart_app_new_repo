import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
    if (_loadingVideo || _videoCtl != null) return;
    _loadingVideo = true;
    final ctl = await VideoPool.instance.attach(widget.id, widget.url);
    if (!mounted) return;
    setState(() {
      _videoCtl = ctl;
      _ratio = ctl.value.isInitialized ? ctl.value.aspectRatio : (_ratio ?? 9 / 16);
    });
    await ctl.play();
    _loadingVideo = false;
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
      fit: BoxFit.cover,
      filterQuality: FilterQuality.low,
      placeholder: (_, __) => const ColoredBox(color: Colors.black12),
      errorWidget: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
    );
  }

  Widget _buildVideo() {
    if (widget.isActive && _videoCtl == null) {
      _ensureVideo();
    }
    if (!widget.isActive) {
      return _buildVideoPlaceholder();
    }
    if (_videoCtl == null || !_videoCtl!.value.isInitialized) {
      return _buildVideoPlaceholder();
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _videoCtl!.value.size.width,
        height: _videoCtl!.value.size.height,
        child: VideoPlayer(_videoCtl!),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    final thumb = widget.thumbnailUrl;
    if (thumb != null && thumb.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumb.trim(),
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
