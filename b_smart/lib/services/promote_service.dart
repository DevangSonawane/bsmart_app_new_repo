import '../api/posts_api.dart';

/// Fetches promote (sponsored video) content. When backend has a
/// promoted_videos (or similar) table, add the query here and remove fallback.
/// Until then, returns mock data matching React Promote.jsx.
class PromoteService {
  static final PromoteService _instance = PromoteService._internal();
  factory PromoteService() => _instance;
  PromoteService._internal();

  final PostsApi _postsApi = PostsApi();

  static List<Map<String, dynamic>> _defaultPromotes() {
    return [
      {
        'id': 'p1',
        'username': 'business_growth',
        'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-working-on-a-new-project-4240-large.mp4',
        'likes': '1.2k',
        'comments': '34',
        'description': 'Boost your business with our new tools! 🚀 #growth #business',
        'brandName': 'Growth Tools Inc.',
        'rating': 4.5,
        'products': [
          {'id': 1, 'image': 'https://images.unsplash.com/photo-1556742049-0cfed4f7a07d?w=400&h=300&fit=crop', 'title': 'Product A'},
          {'id': 2, 'image': 'https://images.unsplash.com/photo-1556740758-90de374c12ad?w=400&h=300&fit=crop', 'title': 'Product B'},
        ],
      },
      {
        'id': 'p2',
        'username': 'marketing_pro',
        'videoUrl': 'https://assets.mixkit.co/videos/preview/mixkit-discussion-of-a-marketing-project-4248-large.mp4',
        'likes': '850',
        'comments': '22',
        'description': 'Marketing strategies that work. 📈 #marketing #tips',
        'brandName': 'MarketMaster',
        'rating': 4.2,
        'products': [
          {'id': 1, 'image': 'https://images.unsplash.com/photo-1533750516457-a7f992034fec?w=400&h=300&fit=crop', 'title': 'Tool X'},
        ],
      },
    ];
  }

  /// Fetches promote list. When backend is ready, query e.g. promoted_videos
  /// and map to this shape; on error or empty return default mock list.
  Future<List<Map<String, dynamic>>> fetchPromotes({int limit = 20}) async {
    try {
      final res = await _postsApi.getFeed(limit: limit);
      final allPosts = res['posts'] as List<dynamic>? ?? [];
      
      final items = allPosts.where((p) {
        final type = p['type'] as String? ?? p['media_type'] as String? ?? 'post';
        return type == 'promote';
      }).toList();

      if (items.isEmpty) return _defaultPromotes();
      
      return items.map((item) {
        final user = item['users'] as Map<String, dynamic>? ?? item['user'] as Map<String, dynamic>?;
        final media = item['media'] as List<dynamic>? ?? [];
        Object? videoUrlObj;
        if (media.isNotEmpty) {
          final first = media.first;
          if (first is String) videoUrlObj = first;
          else if (first is Map) videoUrlObj = first['url'] ?? first['video_url'];
        }
        final videoUrl = videoUrlObj?.toString() ?? '';
        return {
          'id': item['id'] as String? ?? '',
          'username': user?['username'] as String? ?? 'user',
          'videoUrl': videoUrl.isEmpty ? 'https://assets.mixkit.co/videos/preview/mixkit-working-on-a-new-project-4240-large.mp4' : videoUrl,
          'likes': (item['likes_count'] as int? ?? 0).toString(),
          'comments': (item['comments_count'] as int? ?? 0).toString(),
          'description': item['caption'] as String? ?? '',
          'brandName': item['ad_company_name'] as String? ?? '',
          'rating': 4.0,
          'products': <Map<String, dynamic>>[],
        };
      }).toList();
    } catch (_) {
      return _defaultPromotes();
    }
  }
}
