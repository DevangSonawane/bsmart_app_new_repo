import 'package:flutter/material.dart';

import '../../safe_network_image.dart';
import '../chat_bubble_theme.dart';

class ImageMessageContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = ChatBubbleTheme.of(context);
    final colors = theme.colors;
    final fg = isOutgoing ? colors.outgoingText : colors.incomingText;
    final w = MediaQuery.sizeOf(context).width;
    final maxW = w * 0.72;
    final frameH = (maxW * 1.1).clamp(180.0, 360.0);

    Widget imageFrame(String url) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SafeNetworkImage(
          url: url,
          width: maxW,
          height: frameH,
          fit: BoxFit.cover,
        ),
      );
    }

    final frames = urls.where((e) => e.trim().isNotEmpty).toList();
    final widgetImage = (frames.length <= 1)
        ? imageFrame(frames.isEmpty ? '' : frames.first)
        : _ImagePager(
            urls: frames,
            width: maxW,
            height: frameH,
            frameBuilder: imageFrame,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: widgetImage,
        ),
        if (caption.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            caption.trim(),
            style: theme.typography.message.copyWith(color: fg),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ],
      ],
    );
  }
}

class _ImagePager extends StatefulWidget {
  final List<String> urls;
  final double width;
  final double height;
  final Widget Function(String url) frameBuilder;

  const _ImagePager({
    required this.urls,
    required this.width,
    required this.height,
    required this.frameBuilder,
  });

  @override
  State<_ImagePager> createState() => _ImagePagerState();
}

class _ImagePagerState extends State<_ImagePager> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = widget.urls.length;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => widget.frameBuilder(widget.urls[i]),
          ),
          if (count > 1)
            Positioned(
              right: 10,
              top: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: cs.onSurface.withValues(alpha: 0.10),
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    '${_index + 1}/$count',
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
    );
  }
}
