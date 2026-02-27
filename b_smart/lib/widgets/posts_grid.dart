import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/feed_post_model.dart';
import '../api/api_client.dart';
import '../config/api_config.dart';

class PostsGrid extends StatefulWidget {
  final List<FeedPost> posts;
  final void Function(FeedPost) onTap;

  const PostsGrid({Key? key, required this.posts, required this.onTap}) : super(key: key);

  @override
  State<PostsGrid> createState() => _PostsGridState();
}

class _PostsGridState extends State<PostsGrid> {
  Map<String, String>? _headers;
  String _absolute(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }

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
      return const Center(child: Text('No posts yet'));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.posts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final p = widget.posts[index];
        final raw = p.mediaUrls.isNotEmpty ? p.mediaUrls.first : null;
        final thumb = (raw != null && raw.isNotEmpty) ? _absolute(raw) : null;
        return GestureDetector(
          onTap: () => widget.onTap(p),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumb != null)
                  CachedNetworkImage(
                    imageUrl: thumb,
                    httpHeaders: _headers,
                    cacheKey: '${thumb}#${_headers?['Authorization'] ?? ''}',
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(color: Colors.grey[300]),
                    errorWidget: (ctx, url, err) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    ),
                  )
                else
                  Container(color: Colors.grey[200]),
                if (p.mediaType == PostMediaType.reel)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        LucideIcons.play,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
