import '../api/posts_api.dart';
import '../api/promote_reels_api.dart';

/// Fetches promote (sponsored video) content. When backend has a
/// promoted_videos (or similar) table, add the query here and remove fallback.
/// Until then, returns mock data matching React Promote.jsx.
class PromoteService {
  static final PromoteService _instance = PromoteService._internal();
  factory PromoteService() => _instance;
  PromoteService._internal();

  final PostsApi _postsApi = PostsApi();
  final PromoteReelsApi _promoteReelsApi = PromoteReelsApi();

  Map<String, dynamic> mapPromote(dynamic raw) {
    final item =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

    String asId(dynamic v) => (v ?? '').toString().trim();

    final id = asId(item['_id'] ?? item['id'] ?? item['promote_reel_id']);
    final user = item['users'] is Map
        ? Map<String, dynamic>.from(item['users'] as Map)
        : (item['user'] is Map
            ? Map<String, dynamic>.from(item['user'] as Map)
            : null);
    final userId = item['user_id'] is Map
        ? Map<String, dynamic>.from(item['user_id'] as Map)
        : null;
    final pickedUser = userId ?? user;
    final pickedUserId = asId(
      pickedUser?['_id'] ?? pickedUser?['id'] ?? pickedUser?['user_id'],
    );
    final username = (pickedUser?['username'] ??
            pickedUser?['full_name'] ??
            pickedUser?['name'] ??
            'User')
        .toString();
    final avatarUrl = (pickedUser?['avatar_url'] ??
            pickedUser?['profile_picture'] ??
            pickedUser?['profilePicture'] ??
            pickedUser?['profile_pic'] ??
            pickedUser?['avatarUrl'])
        ?.toString()
        .trim();

    final media = item['media'];
    List<dynamic> mediaList = const [];
    if (media is List) mediaList = media;

    Object? videoUrlObj;
    if (mediaList.isNotEmpty) {
      final first = mediaList.first;
      if (first is String) {
        videoUrlObj = first;
      } else if (first is Map) {
        final fm = Map<String, dynamic>.from(first);
        videoUrlObj =
            fm['url'] ?? fm['fileUrl'] ?? fm['video_url'] ?? fm['link'];
      }
    }
    final videoUrl = (videoUrlObj ?? '').toString().trim();

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final likesCount =
        toInt(item['likes_count'] ?? item['likesCount'] ?? item['like_count']);
    final commentsCount = toInt(item['comments_count'] ??
        item['commentsCount'] ??
        item['comment_count']);
    final viewsCount = toInt(item['views_count'] ??
        item['viewsCount'] ??
        item['currentViews'] ??
        item['current_views'] ??
        item['views']);
    final isLikedByMe = item['is_liked_by_me'] == true ||
        item['liked_by_me'] == true ||
        item['isLikedByMe'] == true;
    final isSavedByMe = item['is_saved_by_me'] == true ||
        item['saved_by_me'] == true ||
        item['isSavedByMe'] == true;

    final tagsRaw = item['tags'];
    final tags = <String>[];
    if (tagsRaw is List) {
      for (final t in tagsRaw) {
        final s = (t ?? '').toString().trim();
        if (s.isNotEmpty) tags.add(s.startsWith('#') ? s : '#$s');
      }
    }

    final rawProducts = item['products'];
    final products = <Map<String, dynamic>>[];
    if (rawProducts is List) {
      for (final p in rawProducts) {
        if (p is! Map) continue;
        final pm = Map<String, dynamic>.from(p);
        final name = (pm['product_name'] ?? pm['name'] ?? pm['title'] ?? '')
            .toString()
            .trim();
        final desc =
            (pm['product_description'] ?? pm['description'] ?? '').toString().trim();
        final img =
            (pm['promote_img'] ?? pm['image'] ?? pm['img'] ?? pm['imageUrl'] ?? '')
                .toString()
                .trim();
        final link = (pm['visit_link'] ??
                pm['website_url'] ??
                pm['websiteUrl'] ??
                pm['url'] ??
                pm['link'] ??
                '')
            .toString()
            .trim();
        final price = pm['product_price'] ?? pm['price'];
        final discount = pm['discount_amount'];

        num? toNum(dynamic v) {
          if (v is num) return v;
          if (v is String) return num.tryParse(v);
          return null;
        }

        final priceNum = toNum(price) ?? 0;
        final discountNum = toNum(discount) ?? 0;
        final mrpNum = (discountNum > 0) ? (priceNum + discountNum) : 0;

        products.add({
          'id': pm['_id'] ?? pm['id'] ?? name,
          'title': name.isEmpty ? 'Product' : name,
          if (desc.isNotEmpty) 'description': desc,
          'image': img,
          'websiteUrl': link,
          'price': priceNum,
          if (mrpNum > 0) 'mrp': mrpNum,
        });
      }
    }

    return {
      'id': id,
      'postId': asId(item['postId'] ??
          item['post_id'] ??
          item['post']?['_id'] ??
          item['post']?['id']),
      'userId': pickedUserId,
      'username': username,
      'avatarUrl': (avatarUrl ?? ''),
      'videoUrl': videoUrl.isEmpty
          ? 'https://assets.mixkit.co/videos/preview/mixkit-working-on-a-new-project-4240-large.mp4'
          : videoUrl,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'viewsCount': viewsCount,
      'isLikedByMe': isLikedByMe,
      'isSavedByMe': isSavedByMe,
      'likes': likesCount.toString(),
      'comments': commentsCount.toString(),
      'description': (item['caption'] ?? item['description'] ?? '').toString(),
      'caption': (item['caption'] ?? item['description'] ?? '').toString(),
      'tags': tags,
      'brandName':
          (item['brandName'] ?? item['ad_company_name'] ?? item['company_name'] ?? '')
              .toString(),
      'rating': 4.0,
      'products': products,
    };
  }

  static List<Map<String, dynamic>> _defaultPromotes() {
    return [
      {
        'id': 'p1',
        'userId': '',
        'username': 'business_growth',
        'avatarUrl': '',
        'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-working-on-a-new-project-4240-large.mp4',
        'likes': '1.2k',
        'comments': '34',
        'likesCount': 1200,
        'commentsCount': 34,
        'isLikedByMe': false,
        'description': 'Boost your business with our new tools! 🚀 #growth #business',
        'caption': 'Boost your business with our new tools! 🚀 #growth #business',
        'tags': ['#growth', '#business'],
        'brandName': 'Growth Tools Inc.',
        'rating': 4.5,
        'products': [
          {
            'id': 1,
            'image': 'https://images.unsplash.com/photo-1556742049-0cfed4f7a07d?w=400&h=300&fit=crop',
            'title': 'Product A',
            'description': 'Featured product',
            'price': 999,
            'mrp': 1299,
            'websiteUrl': 'https://example.com',
            'rating': 4.6,
          },
          {
            'id': 2,
            'image': 'https://images.unsplash.com/photo-1556740758-90de374c12ad?w=400&h=300&fit=crop',
            'title': 'Product B',
            'description': 'Featured product',
            'price': 799,
            'mrp': 1099,
            'websiteUrl': 'https://example.com',
            'rating': 4.4,
          },
        ],
      },
      {
        'id': 'p2',
        'userId': '',
        'username': 'marketing_pro',
        'avatarUrl': '',
        'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-discussion-of-a-marketing-project-4248-large.mp4',
        'likes': '850',
        'comments': '22',
        'likesCount': 850,
        'commentsCount': 22,
        'isLikedByMe': false,
        'description': 'Marketing strategies that work. 📈 #marketing #tips',
        'caption': 'Marketing strategies that work. 📈 #marketing #tips',
        'tags': ['#marketing', '#tips'],
        'brandName': 'MarketMaster',
        'rating': 4.2,
        'products': [
          {
            'id': 1,
            'image': 'https://images.unsplash.com/photo-1533750516457-a7f992034fec?w=400&h=300&fit=crop',
            'title': 'Tool X',
            'description': 'Featured product',
            'price': 499,
            'mrp': 699,
            'websiteUrl': 'https://example.com',
            'rating': 4.2,
          },
        ],
      },
    ];
  }

  /// Fetches promote list. When backend is ready, query e.g. promoted_videos
  /// and map to this shape; on error or empty return default mock list.
  Future<List<Map<String, dynamic>>> fetchPromotes({int limit = 20}) async {
    try {
      // Prefer the dedicated PromoteReels API. React uses:
      //   GET /api/promote-reels?page=1&limit=10
      final res = await _promoteReelsApi.listPromoteReels(page: 1, limit: limit);
      List<dynamic> items = const [];
      if (res is Map) {
        final data = res['data'];
        if (data is List) items = data;
      } else if (res is List) {
        items = res;
      }

      if (items.isEmpty) {
        // Backward-compatible fallback: derive from feed if promote-reels
        // endpoint isn't deployed in this environment.
        final feedRes = await _postsApi.getFeed(limit: limit);
        final allPosts = feedRes is Map ? (feedRes['posts'] as List<dynamic>? ?? []) : const [];
        items = allPosts.where((p) {
          if (p is! Map) return false;
          final type = (p['type'] ?? p['media_type'] ?? 'post').toString();
          return type == 'promote';
        }).toList();
      }

      if (items.isEmpty) return _defaultPromotes();

      return items.map(mapPromote).toList();
    } catch (_) {
      return _defaultPromotes();
    }
  }

  Future<List<Map<String, dynamic>>> searchPromotes({
    required String q,
    int page = 1,
    int limit = 20,
  }) async {
    final query = q.trim();
    if (query.isEmpty) return const [];

    final res = await _promoteReelsApi.searchPromoteReels(
      q: query,
      page: page,
      limit: limit,
    );

    List<dynamic> items = const [];
    if (res is Map) {
      final data = res['data'] ?? res['results'] ?? res['items'];
      if (data is List) items = data;
      if (data is Map && data['data'] is List) items = data['data'] as List;
    } else if (res is List) {
      items = res;
    }

    return items.map(mapPromote).toList(growable: false);
  }
}
