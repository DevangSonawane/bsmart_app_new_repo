import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/feed_post_model.dart';
import '../api/api_client.dart';
import 'safe_network_image.dart';
import '../utils/url_helper.dart';

class PostsGrid extends StatefulWidget {
  final List<FeedPost> posts;
  final void Function(FeedPost) onTap;

  const PostsGrid({super.key, required this.posts, required this.onTap});

  @override
  State<PostsGrid> createState() => _PostsGridState();
}

class _PostsGridState extends State<PostsGrid> {
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    ApiClient().getToken().then((token) {
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        setState(() {
          _headers = {'Authorization': 'Bearer $token'};
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final seamColor = theme.brightness == Brightness.dark
        ? const Color(0xFF0B0B0C)
        : const Color(0xFFF3F4F6);

    return ColoredBox(
      // Helps hide 1px outer seams on some devices.
      color: seamColor,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.posts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
        ),
        itemBuilder: (context, index) {
          final p = widget.posts[index];
          final raw =
              (p.thumbnailUrl != null && p.thumbnailUrl!.trim().isNotEmpty)
                  ? p.thumbnailUrl
                  : (p.mediaUrls.isNotEmpty ? p.mediaUrls.first : null);
          final normalized = (raw != null && raw.trim().isNotEmpty)
              ? UrlHelper.normalizeUrl(raw)
              : '';
          final thumb = normalized.isNotEmpty ? normalized : null;
          final headers =
              (thumb != null && UrlHelper.shouldAttachAuthHeader(thumb))
                  ? _headers
                  : null;
          return GestureDetector(
            onTap: () => widget.onTap(p),
            child: Transform.scale(
              // Slight overlap helps remove 1px seams on some screens.
              scale: 1.01,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: seamColor,
                    child: thumb != null
                        ? SafeNetworkImage(
                            url: thumb,
                            headers: headers,
                            cacheKey: '$thumb#${headers?['Authorization'] ?? ''}',
                            fit: BoxFit.cover,
                            placeholder: ColoredBox(color: seamColor),
                            errorWidget: ColoredBox(
                              color: seamColor,
                              child: const Icon(Icons.broken_image),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (p.mediaType == PostMediaType.reel)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        LucideIcons.video,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
