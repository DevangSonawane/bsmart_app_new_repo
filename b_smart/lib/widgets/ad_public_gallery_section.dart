import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'fullscreen_image_viewer.dart';

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
  final Map<String, String>? httpHeaders;

  const _GalleryTile({
    required this.url,
    required this.httpHeaders,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showFullscreenImageViewer(
        context,
        imageUrl: url,
        httpHeaders: httpHeaders,
      ),
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
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
              errorWidget: (context, _, __) => const ColoredBox(
                color: Colors.black,
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
    );
  }
}
