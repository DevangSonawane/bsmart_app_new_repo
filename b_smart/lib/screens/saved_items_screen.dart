import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api.dart';
import '../models/feed_post_model.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import '../widgets/safe_network_image.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  final SavedApi _savedApi = SavedApi();
  Map<String, String>? _imageHeaders;

  bool _loading = false;
  String? _error;
  List<FeedPost> _items = const [];

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    return parsed;
  }

  DateTime _savedSortTime(Map<String, dynamic> item, FeedPost post) {
    final candidates = [
      item['savedAt'],
      item['saved_at'],
      item['savedOn'],
      item['saved_on'],
      item['savedDate'],
      item['saved_date'],
      item['bookmarkedAt'],
      item['bookmarked_at'],
      item['bookmarkedOn'],
      item['bookmarked_on'],
      item['addedAt'],
      item['added_at'],
      item['createdAt'],
      item['created_at'],
      item['updatedAt'],
      item['updated_at'],
    ];

    for (final candidate in candidates) {
      final parsed = _parseDateTime(candidate);
      if (parsed != null) return parsed;
    }
    return post.createdAt;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_primeHeaders());
    _loadSaved();
  }

  Future<void> _primeHeaders() async {
    try {
      final token = await ApiClient().getToken();
      if (!mounted) return;
      if (token != null && token.trim().isNotEmpty) {
        setState(() {
          _imageHeaders = <String, String>{'Authorization': 'Bearer $token'};
        });
      }
    } catch (_) {
      // ignore
    }
  }

  bool _isTweetLike(Map<String, dynamic> item) {
    final type = (item['type'] ?? item['post_type'] ?? item['postType'])
        ?.toString()
        .toLowerCase()
        .trim();
    if (type == 'tweet' || type == 'tweets') return true;
    return item.containsKey('tweet') ||
        item.containsKey('tweetId') ||
        item.containsKey('tweet_id') ||
        item.containsKey('tweet_text') ||
        item.containsKey('tweetText');
  }

  bool _isAdLike(Map<String, dynamic> item) {
    final type = (item['type'] ?? item['item_type'] ?? item['itemType'])
        ?.toString()
        .toLowerCase()
        .trim();
    if (type == 'ad' || type == 'advertise' || type == 'promote') return true;
    return item['ad'] is Map ||
        item['ad_id'] != null ||
        item['adId'] != null ||
        item['promote_reel_id'] != null;
  }

  bool _looksLikeVideoUrl(String url) {
    final u = url.toLowerCase();
    return u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.mkv') ||
        u.endsWith('.webm') ||
        u.contains('.m3u8') ||
        u.contains('.mpd');
  }

  String _extractThumbnailValue(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      for (final entry in value) {
        final thumb = _extractThumbnailValue(entry);
        if (thumb.isNotEmpty) return thumb;
      }
      return '';
    }
    if (value is Map) {
      final m = Map<String, dynamic>.from(value);
      final candidates = [
        m['thumbnailUrl'],
        m['thumbnail_url'],
        m['thumbnail'],
        m['thumb'],
        m['poster'],
        m['image_url'],
        m['image'],
        m['fileUrl'],
        m['file_url'],
        m['url'],
        m['path'],
      ];
      for (final candidate in candidates) {
        if (candidate == null) continue;
        final normalized = UrlHelper.normalizeUrl(candidate.toString());
        if (normalized.isNotEmpty && !_looksLikeVideoUrl(normalized)) {
          return normalized;
        }
      }
      return _extractThumbnailValue(m['thumbnails']);
    }
    final normalized = UrlHelper.normalizeUrl(value.toString());
    if (normalized.isEmpty || _looksLikeVideoUrl(normalized)) return '';
    return normalized;
  }

  Map<String, dynamic> _mergeSavedItem(Map<String, dynamic> item) {
    final merged = Map<String, dynamic>.from(item);
    final candidates = [
      item['post'],
      item['reel'],
      item['savedPost'],
      item['savedReel'],
      item['saved_post'],
      item['saved_reel'],
      item['content'],
      item['item'],
      item['media'],
    ];
    for (final candidate in candidates) {
      if (candidate is Map) {
        merged.addAll(Map<String, dynamic>.from(candidate));
      }
    }
    return merged;
  }

  List<Map<String, dynamic>> _collectMaps(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is! Map) return const [];
    final map = Map<String, dynamic>.from(raw);
    final candidates = [
      map['saved'],
      map['savedItems'],
      map['saved_items'],
      map['savedPosts'],
      map['saved_posts'],
      map['savedReels'],
      map['saved_reels'],
      map['posts'],
      map['reels'],
      map['items'],
      map['results'],
      map['data'],
      map['data'] is Map ? (map['data'] as Map)['data'] : null,
      map['data'] is Map ? (map['data'] as Map)['items'] : null,
      map['data'] is Map ? (map['data'] as Map)['posts'] : null,
      map['data'] is Map ? (map['data'] as Map)['reels'] : null,
    ];
    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }

  FeedPost? _toFeedPost(Map<String, dynamic> item) {
    final merged = _mergeSavedItem(item);
    var post = FeedPost.fromJson(merged);
    if (post.id.trim().isEmpty) return null;
    if (_isTweetLike(merged) || _isAdLike(merged)) return null;
    final safeThumb = _extractThumbnailValue(
      merged['thumbnailUrl'] ??
          merged['thumbnail_url'] ??
          merged['thumbnail'] ??
          merged['thumb'] ??
          merged['poster'] ??
          merged['media'] ??
          merged['mediaUrls'] ??
          merged['media_urls'],
    );
    if (safeThumb.isNotEmpty &&
        (post.thumbnailUrl == null ||
            post.thumbnailUrl!.trim().isEmpty ||
            _looksLikeVideoUrl(post.thumbnailUrl!.trim()))) {
      post = post.copyWith(thumbnailUrl: safeThumb);
    }
    return post;
  }

  Future<void> _loadSaved({bool force = false}) async {
    if (_loading && !force) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = await CurrentUser.id;
      if (uid == null || uid.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _items = const [];
          _error = 'Please sign in to view saved items.';
        });
        return;
      }

      final raw = await _savedApi.getSavedItems(uid);
      final items = _collectMaps(raw);
      final seen = <String>{};
      final nextItems = <({FeedPost post, DateTime sortTime, int index})>[];
      var index = 0;

      for (final item in items) {
        final post = _toFeedPost(item);
        if (post == null) continue;
        if (seen.add(post.id)) {
          nextItems.add((
            post: post,
            sortTime: _savedSortTime(item, post),
            index: index,
          ));
        }
        index++;
      }

      nextItems.sort((a, b) {
        final timeCompare = b.sortTime.compareTo(a.sortTime);
        if (timeCompare != 0) return timeCompare;
        return a.index.compareTo(b.index);
      });

      if (!mounted) return;
      setState(() {
        _items = nextItems.map((entry) => entry.post).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load saved items.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openItem(FeedPost post) {
    if (post.mediaType == PostMediaType.reel ||
        post.mediaType == PostMediaType.video) {
      Navigator.of(context).pushNamed(
        '/reels',
        arguments: {'initialReelId': post.id},
      );
      return;
    }
    Navigator.of(context).pushNamed('/post/${post.id}');
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.bookmarkX, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(ThemeData theme) {
    final seamColor = theme.brightness == Brightness.dark
        ? const Color(0xFF0B0B0C)
        : const Color(0xFFF3F4F6);
    final dividerColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    if (!_loading && _items.isEmpty) {
      return Center(
        child: Text(
          'No saved items yet.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ColoredBox(
      color: seamColor,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final item = _items[index];
          final url = item.thumbnailUrl ?? '';
          final shouldAuth = UrlHelper.shouldAttachAuthHeader(url);
          final isLastColumn = (index + 1) % 3 == 0;
          final totalRows = (_items.length / 3).ceil();
          final rowIndex = index ~/ 3;
          final isLastRow = rowIndex == totalRows - 1;
          return GestureDetector(
            onTap: () => _openItem(item),
            child: Transform.scale(
              scale: 1.01,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: seamColor,
                      border: Border(
                        right: isLastColumn
                            ? BorderSide.none
                            : BorderSide(
                                color: dividerColor,
                                width: 0.5,
                              ),
                        bottom: isLastRow
                            ? BorderSide.none
                            : BorderSide(
                                color: dividerColor,
                                width: 0.5,
                              ),
                      ),
                    ),
                    child: SafeNetworkImage(
                      url: url,
                      headers: shouldAuth ? _imageHeaders : null,
                      fit: BoxFit.cover,
                      placeholder: ColoredBox(color: seamColor),
                      errorWidget: const Center(
                        child: Icon(Icons.image, color: Colors.grey),
                      ),
                      assumeRaster: true,
                    ),
                  ),
                  if (item.mediaType == PostMediaType.reel)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        LucideIcons.video,
                        size: 16,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 8),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSaved(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            if (_loading && _items.isEmpty) ...[
              const Center(child: CircularProgressIndicator()),
            ] else ...[
              if (_error != null) ...[
                const SizedBox(height: 16),
                _buildEmptyState(_error!),
              ],
              _buildGrid(theme),
            ],
          ],
        ),
      ),
    );
  }
}
