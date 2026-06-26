import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/media_aspect_cache.dart';
import '../../../utils/url_helper.dart';
import '../../safe_network_image.dart';
import '../chat_bubble_theme.dart';

class ImageMessageContent extends StatefulWidget {
  final List<String> urls;
  final String caption;
  final bool isOutgoing;
  final VoidCallback? onTap;

  const ImageMessageContent({
    super.key,
    required this.urls,
    required this.caption,
    required this.isOutgoing,
    this.onTap,
  });

  @override
  State<ImageMessageContent> createState() => _ImageMessageContentState();
}

class _ImageMessageContentState extends State<ImageMessageContent> {
  final PageController _controller = PageController();
  final Map<String, double> _ratios = <String, double>{};
  int _index = 0;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _primeRatios();
  }

  @override
  void didUpdateWidget(covariant ImageMessageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameUrls(oldWidget.urls, widget.urls)) return;
    _index = 0;
    _primeRatios();
  }

  bool _sameUrls(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].trim() != b[i].trim()) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  double _fallbackRatio() => widget.isOutgoing ? 4 / 5 : 1.0;

  double _ratioForUrl(String url) {
    final normalized = UrlHelper.normalizeUrl(url);
    return _ratios[normalized] ?? MediaAspectCache.instance.get(normalized) ??
        _fallbackRatio();
  }

  double _ratioForIndex(int index) {
    if (widget.urls.isEmpty) return _fallbackRatio();
    final safeIndex = index.clamp(0, widget.urls.length - 1);
    return _ratioForUrl(widget.urls[safeIndex]);
  }

  void _primeRatios() {
    final urls = widget.urls
        .map((e) => UrlHelper.normalizeUrl(e))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (urls.isEmpty) return;
    for (final url in urls) {
      final cached = MediaAspectCache.instance.get(url);
      if (cached != null) {
        _ratios[url] = cached;
        continue;
      }
      unawaited(() async {
        final ratio = await MediaAspectCache.instance.resolveImageRatio(url);
        if (_disposed || !mounted) return;
        setState(() {
          _ratios[url] = ratio;
        });
      }());
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatBubbleTheme.of(context);
    final colors = theme.colors;
    final fg = widget.isOutgoing ? colors.outgoingText : colors.incomingText;
    final w = MediaQuery.sizeOf(context).width;
    final maxW = w * 0.72;
    final frames = widget.urls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final hasMultiple = frames.length > 1;
    final ratio = _ratioForIndex(_index).clamp(0.5, 2.2);

    Widget imageFrame(String url) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SafeNetworkImage(
          url: UrlHelper.normalizeUrl(url),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    Widget imageBody;
    if (frames.isEmpty) {
      imageBody = const SizedBox.shrink();
    } else if (!hasMultiple) {
      imageBody = AspectRatio(
        aspectRatio: ratio,
        child: imageFrame(frames.first),
      );
    } else {
      imageBody = AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AspectRatio(
          aspectRatio: ratio,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: frames.length,
                onPageChanged: (i) {
                  if (!mounted) return;
                  setState(() => _index = i);
                },
                itemBuilder: (context, i) => imageFrame(frames[i]),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      '${_index + 1}/${frames.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: imageBody,
          ),
        ),
        if (widget.caption.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            widget.caption.trim(),
            style: theme.typography.message.copyWith(color: fg),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ],
      ],
    );
  }
}
