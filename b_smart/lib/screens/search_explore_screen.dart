import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api_client.dart';
import '../api/posts_api.dart';
import '../api/reels_api.dart';
import '../models/feed_post_model.dart';
import '../utils/url_helper.dart';
import '../screens/post_detail_screen.dart';
import '../widgets/post_detail_modal.dart';
import 'search_screen.dart';

class ExploreSearchScreen extends StatefulWidget {
  const ExploreSearchScreen({super.key});

  @override
  State<ExploreSearchScreen> createState() => _ExploreSearchScreenState();
}

class _ExploreSearchScreenState extends State<ExploreSearchScreen> {
  final PostsApi _postsApi = PostsApi();
  final ReelsApi _reelsApi = ReelsApi();

  bool _loading = false;
  List<_ExploreItem> _items = const [];
  Map<String, String>? _imageHeaders;

  @override
  void initState() {
    super.initState();
    unawaited(_primeHeaders());
    unawaited(_loadExplore());
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

  Future<void> _loadExplore({bool force = false}) async {
    if (_loading) return;
    if (!force && _items.isNotEmpty) return;
    setState(() => _loading = true);
    try {
      // Use the paginated feed to avoid mixing in non-post types (e.g. tweets)
      // that sometimes appear in the "default" feed response.
      final feedRes = await _postsApi.getFeed(page: 1, limit: 60);
      final reelsRes = await _reelsApi.listReels(page: 1, limit: 60);

      final posts = _dedupeById(_extractPosts(feedRes));
      final reels = _dedupeById(_extractReels(reelsRes));

      final mixed = _mixExplore(posts, reels);
      if (!mounted) return;
      setState(() => _items = mixed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_ExploreItem> _extractPosts(dynamic res) {
    final list = (res is List)
        ? res
        : (res is Map)
            ? (res['posts'] as List?) ??
                (res['feed'] as List?) ??
                (res['data'] as List?) ??
                const []
            : const [];
    final out = <_ExploreItem>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      if (_isDeletedLike(item)) continue;
      final id =
          (item['_id'] ?? item['id'] ?? item['post_id'] ?? item['postId'])
                  ?.toString()
                  .trim() ??
              '';
      if (id.isEmpty) continue;
      if (_looksLikeTweet(item)) continue;
      final type = (item['type'] ??
              item['post_type'] ??
              item['postType'] ??
              item['media_type'] ??
              item['mediaType'])
          ?.toString()
          .toLowerCase()
          .trim();
      // Feed can include reels; avoid showing them twice in the explore grid.
      if (type == 'reel' || type == 'reels') continue;
      // Hide tweets and ad-like post types from the explore grid.
      if (type == 'tweet' ||
          type == 'tweets' ||
          type == 'promote' ||
          type == 'advertise' ||
          type == 'ad') {
        continue;
      }
      // If backend explicitly says it's not a regular post, skip it.
      if (type != null &&
          type.isNotEmpty &&
          type != 'post' &&
          type != 'posts') {
        continue;
      }
      final thumb = _extractMediaUrl(item);
      if (thumb.isEmpty) continue;
      out.add(_ExploreItem.post(id: id, thumbnailUrl: thumb, raw: item));
    }
    return out;
  }

  bool _looksLikeTweet(Map<String, dynamic> item) {
    final type = (item['type'] ?? item['post_type'] ?? item['postType'])
        ?.toString()
        .toLowerCase()
        .trim();
    if (type == 'tweet' || type == 'tweets') return true;
    // Heuristics: some tweet payloads have these fields even without a type.
    if (item.containsKey('tweet') ||
        item.containsKey('tweetId') ||
        item.containsKey('tweet_id') ||
        item.containsKey('tweet_text') ||
        item.containsKey('tweetText')) {
      return true;
    }
    return false;
  }

  bool _isDeletedLike(Map<String, dynamic> item) {
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final v = value.trim().toLowerCase();
        if (v == 'true' || v == '1' || v == 'yes') return true;
        if (v == 'false' || v == '0' || v == 'no') return false;
      }
      return false;
    }

    if (parseBool(item['isDeleted']) ||
        parseBool(item['is_deleted']) ||
        parseBool(item['deleted'])) {
      return true;
    }
    final deletedAt = item['deletedAt'] ?? item['deleted_at'];
    if (deletedAt != null && deletedAt.toString().trim().isNotEmpty) {
      return true;
    }
    final status = (item['status'] ?? item['post_status'] ?? item['postStatus'])
        ?.toString()
        .toLowerCase()
        .trim();
    if (status == 'deleted' ||
        status == 'removed' ||
        status == 'inactive' ||
        status == 'disabled') {
      return true;
    }
    if (item.containsKey('isActive') && parseBool(item['isActive']) == false) {
      return true;
    }
    if (item.containsKey('active') && parseBool(item['active']) == false) {
      return true;
    }
    return false;
  }

  bool _isAdPost(Map<String, dynamic> item) {
    final itemType =
        (item['item_type'] ?? item['itemType'] ?? '').toString().toLowerCase();
    if (itemType == 'ad') return true;
    if (item['vendor_id'] != null || item['vendorId'] != null) return true;
    if (item['total_budget_coins'] != null ||
        item['totalBudgetCoins'] != null) {
      return true;
    }
    return false;
  }

  List<_ExploreItem> _dedupeById(List<_ExploreItem> items) {
    if (items.isEmpty) return const [];
    final seen = <String>{};
    final out = <_ExploreItem>[];
    for (final item in items) {
      if (seen.add(item.id)) out.add(item);
    }
    return out;
  }

  List<_ExploreItem> _extractReels(dynamic res) {
    final list = (res is List)
        ? res
        : (res is Map)
            ? (res['reels'] as List?) ??
                (res['posts'] as List?) ??
                (res['data'] as List?) ??
                const []
            : const [];
    final out = <_ExploreItem>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      if (_isDeletedLike(item)) continue;
      final id =
          (item['_id'] ?? item['id'] ?? item['post_id'] ?? item['postId'])
                  ?.toString()
                  .trim() ??
              '';
      if (id.isEmpty) continue;
      final thumb = _extractReelThumb(item);
      if (thumb.isEmpty) continue;
      out.add(_ExploreItem.reel(id: id, thumbnailUrl: thumb, raw: item));
    }
    return out;
  }

  List<_ExploreItem> _mixExplore(
    List<_ExploreItem> posts,
    List<_ExploreItem> reels,
  ) {
    if (posts.isEmpty && reels.isEmpty) return const [];
    final maxPairs = posts.length < reels.length ? posts.length : reels.length;
    final out = <_ExploreItem>[];
    for (var i = 0; i < maxPairs; i++) {
      out.add(posts[i]);
      out.add(reels[i]);
    }
    if (posts.length > maxPairs) out.addAll(posts.skip(maxPairs));
    if (reels.length > maxPairs) out.addAll(reels.skip(maxPairs));

    // Ensure absolutely no duplicates. Reels are posts too, so de-dupe by `id`
    // (not `kind+id`). If both exist, prefer the reel tile.
    final indexById = <String, int>{};
    final unique = <_ExploreItem>[];
    for (final item in out) {
      final existingIndex = indexById[item.id];
      if (existingIndex == null) {
        indexById[item.id] = unique.length;
        unique.add(item);
        continue;
      }
      final existing = unique[existingIndex];
      if (existing.kind == _ExploreKind.post &&
          item.kind == _ExploreKind.reel) {
        unique[existingIndex] = item;
      }
    }
    return unique;
  }

  String _extractReelThumb(Map<String, dynamic> item) {
    // Try reel specific thumbnail keys first.
    final direct = item['thumbnailUrl'] ??
        item['thumbnail_url'] ??
        item['thumb'] ??
        item['image_url'] ??
        item['image'];
    if (direct != null) {
      return UrlHelper.normalizeUrl(direct.toString());
    }
    // Fall back to generic post/reel media parsing.
    return _extractMediaUrl(item);
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

  String _bestThumbnailFromMediaMap(Map<String, dynamic> m) {
    final thumbs = m['thumbnails'];
    if (thumbs is List && thumbs.isNotEmpty) {
      for (final t in thumbs) {
        if (t is! Map) continue;
        final tm = Map<String, dynamic>.from(t);
        final url = tm['fileUrl'] ?? tm['file_url'] ?? tm['url'] ?? tm['path'];
        if (url == null) continue;
        final normalized = UrlHelper.normalizeUrl(url.toString());
        if (normalized.isNotEmpty && !_looksLikeVideoUrl(normalized)) {
          return normalized;
        }
      }
    }
    final direct = m['thumbnail_url'] ?? m['thumbnailUrl'] ?? m['thumbnail'];
    if (direct != null) {
      final normalized = UrlHelper.normalizeUrl(direct.toString());
      if (normalized.isNotEmpty && !_looksLikeVideoUrl(normalized)) {
        return normalized;
      }
    }
    return '';
  }

  String _extractMediaUrl(Map<String, dynamic> item) {
    dynamic media = item['media'] ?? item['mediaUrls'] ?? item['media_urls'];
    if (media is List && media.isNotEmpty) {
      final first = media.first;
      if (first is Map) {
        final m = Map<String, dynamic>.from(first);
        final bestThumb = _bestThumbnailFromMediaMap(m);
        if (bestThumb.isNotEmpty) return bestThumb;
        final url = m['thumbnail_url'] ??
            m['thumbnailUrl'] ??
            m['thumbnail'] ??
            m['image_url'] ??
            m['image'] ??
            m['fileUrl'] ??
            m['file_url'] ??
            m['url'];
        if (url != null) {
          final normalized = UrlHelper.normalizeUrl(url.toString());
          if (normalized.isNotEmpty && !_looksLikeVideoUrl(normalized)) {
            return normalized;
          }
        }
      } else if (first is String) {
        final normalized = UrlHelper.normalizeUrl(first);
        if (normalized.isNotEmpty && !_looksLikeVideoUrl(normalized)) {
          return normalized;
        }
        return '';
      }
    }
    final direct = item['image_url'] ??
        item['thumbnail_url'] ??
        item['image'] ??
        item['thumb'];
    if (direct != null) {
      final normalized = UrlHelper.normalizeUrl(direct.toString());
      if (normalized.isNotEmpty && !_looksLikeVideoUrl(normalized)) {
        return normalized;
      }
    }
    return '';
  }

  void _showPostDetail(Map<String, dynamic> item) {
    final postId = (item['_id'] ?? item['id'] ?? item['post_id'] ?? item['postId'])
            ?.toString()
            .trim() ??
        '';
    if (postId.isEmpty) return;
    if (_isAdPost(item)) {
      Navigator.of(context).pushNamed('/ad/$postId');
      return;
    }
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final initialPost = FeedPost.fromJson(item);
    if (isMobile) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            postId: postId,
            initialPost: initialPost,
            isTweet: initialPost.isTweet,
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: PostDetailModal(
            postId: postId,
            initialPost: item,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    }
  }

  Future<void> _openSearch() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const SearchScreen(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
        ),
      ),
      child: InkWell(
        onTap: _openSearch,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Icon(LucideIcons.search, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final theme = Theme.of(context);
    final seamColor = theme.brightness == Brightness.dark
        ? const Color(0xFF0B0B0C)
        : const Color(0xFFF3F4F6);
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_loading && _items.isEmpty) {
      return Center(
        child: Text(
          'Nothing to explore yet',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ColoredBox(
      // If device pixel rounding creates hairline gaps, this reduces contrast.
      color: seamColor,
      child: RefreshIndicator(
        onRefresh: () => _loadExplore(force: true),
        child: GridView.builder(
          padding: EdgeInsets.zero,
          itemCount: _items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final item = _items[index];
            final url = item.thumbnailUrl;
            final shouldAuth = UrlHelper.shouldAttachAuthHeader(url);
            return GestureDetector(
              onTap: () {
                if (item.kind == _ExploreKind.reel) {
                  final reelId = item.id;
                  Navigator.of(context).pushNamed(
                    '/reels',
                    arguments: {'initialReelId': reelId},
                  );
                } else {
                  _showPostDetail(item.raw);
                }
              },
              child: Transform.scale(
                // Slight overlap helps remove 1px seams on some screens.
                scale: 1.01,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: seamColor,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        httpHeaders: shouldAuth ? _imageHeaders : null,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ColoredBox(color: seamColor),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                    if (item.kind == _ExploreKind.reel)
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(child: _buildGrid(context)),
          ],
        ),
      ),
    );
  }
}

enum _ExploreKind { post, reel }

class _ExploreItem {
  final String id;
  final _ExploreKind kind;
  final String thumbnailUrl;
  final Map<String, dynamic> raw;

  const _ExploreItem._({
    required this.id,
    required this.kind,
    required this.thumbnailUrl,
    required this.raw,
  });

  factory _ExploreItem.post({
    required String id,
    required String thumbnailUrl,
    required Map<String, dynamic> raw,
  }) {
    return _ExploreItem._(
      id: id,
      kind: _ExploreKind.post,
      thumbnailUrl: UrlHelper.absoluteUrl(thumbnailUrl),
      raw: raw,
    );
  }

  factory _ExploreItem.reel({
    required String id,
    required String thumbnailUrl,
    required Map<String, dynamic> raw,
  }) {
    return _ExploreItem._(
      id: id,
      kind: _ExploreKind.reel,
      thumbnailUrl: UrlHelper.absoluteUrl(thumbnailUrl),
      raw: raw,
    );
  }
}
