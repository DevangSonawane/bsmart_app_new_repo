import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
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
  final Set<String> _loggedMissingThumbIds = <String>{};
  final Map<String, Future<Uint8List?>> _generatedThumbFutures =
      <String, Future<Uint8List?>>{};

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
          final thumb = _resolveThumbSource(raw);
          final firstMedia = p.mediaUrls.isNotEmpty ? p.mediaUrls.first : '';
          final videoThumb =
              p.mediaType == PostMediaType.reel && _isVideoUrl(firstMedia)
                  ? UrlHelper.normalizeUrl(firstMedia)
                  : '';
          assert(() {
            if (thumb == null && !_loggedMissingThumbIds.contains(p.id)) {
              _loggedMissingThumbIds.add(p.id);
              final thumbRaw = (p.thumbnailUrl ?? '').trim();
              final first =
                  p.mediaUrls.isNotEmpty ? p.mediaUrls.first.trim() : '';
              debugPrint(
                '[PostsGrid] Missing thumb for id=${p.id} mediaType=${p.mediaType} thumbRaw="$thumbRaw" first="$first"',
              );
            }
            return true;
          }());
          final headers = (thumb != null &&
                  thumb.startsWith('http') &&
                  UrlHelper.shouldAttachAuthHeader(thumb))
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (videoThumb.isNotEmpty)
                          _generatedThumbFor(
                            p.id,
                            videoThumb,
                            seamColor,
                          ),
                        if (thumb != null && p.mediaType == PostMediaType.reel)
                          _renderThumbSource(
                            thumb,
                            headers: headers,
                          ),
                        if (thumb != null && p.mediaType != PostMediaType.reel)
                          SafeNetworkImage(
                            url: thumb,
                            headers: headers,
                            cacheKey:
                                '$thumb#${headers?['Authorization'] ?? ''}',
                            fit: BoxFit.cover,
                            placeholder: ColoredBox(color: seamColor),
                            errorWidget: ColoredBox(
                              color: seamColor,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                      ],
                    ),
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

  Widget _generatedThumbFor(String cacheId, String videoUrl, Color seamColor) {
    final future = _generatedThumbFutures.putIfAbsent(cacheId, () async {
      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: videoUrl,
          imageFormat: ImageFormat.JPEG,
          timeMs: 0,
          quality: 75,
        );
        return bytes != null && bytes.isNotEmpty ? bytes : null;
      } catch (_) {
        return null;
      }
    });

    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty) {
          return ColoredBox(color: seamColor);
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        );
      },
    );
  }

  Widget _renderThumbSource(
    String source, {
    Map<String, String>? headers,
  }) {
    if (_looksLikeLocalFile(source)) {
      final file = _fileForSource(source);
      if (file != null && file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        );
      }
      return const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: source,
      httpHeaders: headers,
      fit: BoxFit.cover,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  File? _fileForSource(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('file://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return null;
      return File(uri.toFilePath());
    }
    return File(trimmed);
  }

  bool _looksLikeLocalFile(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.startsWith('file://')) return true;
    if (trimmed.startsWith('/')) return true;
    final file = File(trimmed);
    return file.existsSync();
  }

  String? _resolveThumbSource(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    if (_looksLikeLocalFile(value)) return value;
    final normalized = UrlHelper.normalizeUrl(value);
    return normalized.isNotEmpty ? normalized : null;
  }

  bool _isVideoUrl(String url) {
    final lower = url.trim().toLowerCase();
    return lower.endsWith('.m3u8') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }
}
