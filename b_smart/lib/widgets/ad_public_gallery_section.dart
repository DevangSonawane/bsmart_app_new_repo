import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AdPublicGallerySection extends StatelessWidget {
  final List<String> urls;
  final Map<String, String>? httpHeaders;

  const AdPublicGallerySection({
    super.key,
    required this.urls,
    this.httpHeaders,
  });

  @override
  Widget build(BuildContext context) {
    final items =
        urls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.movie, size: 16, color: Colors.pink.shade400),
            const SizedBox(width: 8),
            Text(
              'Gallery',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int columns = 3;
            if (width >= 520) columns = 4;
            if (width >= 740) columns = 5;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 9 / 16,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _GalleryTile(
                  url: items[index],
                  index: index,
                  urls: items,
                  httpHeaders: httpHeaders,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final String url;
  final int index;
  final List<String> urls;
  final Map<String, String>? httpHeaders;

  const _GalleryTile({
    required this.url,
    required this.index,
    required this.urls,
    required this.httpHeaders,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black,
              pageBuilder: (_, __, ___) => _GalleryLightbox(
                urls: urls,
                initialIndex: index,
                httpHeaders: httpHeaders,
              ),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                httpHeaders: httpHeaders,
                placeholder: (context, _) => const ColoredBox(
                  color: Color(0x11000000),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, _, __) => const ColoredBox(
                  color: Color(0x11000000),
                  child: Center(
                    child: Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryLightbox extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  final Map<String, String>? httpHeaders;

  const _GalleryLightbox({
    required this.urls,
    required this.initialIndex,
    required this.httpHeaders,
  });

  @override
  State<_GalleryLightbox> createState() => _GalleryLightboxState();
}

class _GalleryLightboxState extends State<_GalleryLightbox> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.urls.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, i) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.urls[i],
                      fit: BoxFit.contain,
                      httpHeaders: widget.httpHeaders,
                      placeholder: (context, _) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, _, __) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Close',
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '${_index + 1}/${widget.urls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

