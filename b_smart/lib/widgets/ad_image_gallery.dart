import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'fullscreen_image_viewer.dart';

class AdImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final Map<String, String>? httpHeaders;
  final BoxFit fit;
  final double indicatorBottomPadding;
  final bool showThumbnails;
  final bool showIndicators;

  const AdImageGallery({
    super.key,
    required this.imageUrls,
    this.httpHeaders,
    this.fit = BoxFit.cover,
    this.indicatorBottomPadding = 18,
    this.showThumbnails = true,
    this.showIndicators = true,
  });

  @override
  State<AdImageGallery> createState() => _AdImageGalleryState();
}

class _AdImageGalleryState extends State<AdImageGallery> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AdImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.length != widget.imageUrls.length) {
      _index = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (urls.isEmpty) {
      return const Center(
        child: Icon(Icons.broken_image, color: Colors.white54),
      );
    }
    if (urls.length == 1) {
      return GestureDetector(
        onTap: () => showFullscreenImageViewer(
          context,
          imageUrl: urls.first,
          httpHeaders: widget.httpHeaders,
        ),
        child: ColoredBox(
          color: Colors.black,
          child: CachedNetworkImage(
            imageUrl: urls.first,
            fit: widget.fit,
            httpHeaders: widget.httpHeaders,
            placeholder: (context, _) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, _, __) =>
                const Icon(Icons.broken_image, color: Colors.white54),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: urls.length,
          onPageChanged: (value) => setState(() => _index = value),
          itemBuilder: (context, i) {
            return GestureDetector(
              onTap: () => showFullscreenImageViewer(
                context,
                imageUrl: urls[i],
                httpHeaders: widget.httpHeaders,
              ),
              child: ColoredBox(
                color: Colors.black,
                child: CachedNetworkImage(
                  imageUrl: urls[i],
                  fit: widget.fit,
                  httpHeaders: widget.httpHeaders,
                  placeholder: (context, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, _, __) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                  ),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: widget.indicatorBottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.showThumbnails) ...[
                  _ThumbnailsStrip(
                    urls: urls,
                    index: _index.clamp(0, urls.length - 1),
                    httpHeaders: widget.httpHeaders,
                    onSelect: (value) {
                      setState(() => _index = value);
                      if (_controller.hasClients) {
                        _controller.animateToPage(
                          value,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                if (widget.showIndicators)
                  _DotsIndicator(
                    count: urls.length,
                    index: _index.clamp(0, urls.length - 1),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int index;

  const _DotsIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            final selected = i == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: selected ? 16 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ThumbnailsStrip extends StatelessWidget {
  final List<String> urls;
  final int index;
  final Map<String, String>? httpHeaders;
  final ValueChanged<int> onSelect;

  const _ThumbnailsStrip({
    required this.urls,
    required this.index,
    required this.httpHeaders,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final selected = i == index;
            return InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.25),
                    width: selected ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: urls[i],
                  fit: BoxFit.cover,
                  httpHeaders: httpHeaders,
                  errorWidget: (context, _, __) => const ColoredBox(
                    color: Colors.black26,
                    child: Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
