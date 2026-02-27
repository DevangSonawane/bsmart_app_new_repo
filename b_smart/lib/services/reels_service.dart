import '../api/posts_api.dart';
import '../models/reel_model.dart';
import '../config/api_config.dart';
import '../utils/url_helper.dart';
import '../state/store.dart';
import '../state/feed_actions.dart';
import '../models/feed_post_model.dart';

class ReelsService {
  static final ReelsService _instance = ReelsService._internal();
  factory ReelsService() => _instance;
  ReelsService._internal() {
    // Seed with mock data so UI shows immediately (no loading spinner)
    _cache.addAll(_defaultMockReels());
    _init();
  }

  final PostsApi _postsApi = PostsApi();
  final List<Reel> _cache = [];

  static List<Reel> _defaultMockReels() {
    return [
      Reel(
        id: 'reel-1',
        userId: 'user-dance',
        userName: 'dance_queen',
        userAvatarUrl: 'https://i.pravatar.cc/150?u=dance_queen',
        videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-girl-dancing-happy-in-a-room-4179-large.mp4',
        thumbnailUrl: 'https://images.unsplash.com/photo-1547153760-18fc86324498?w=800&q=80',
        caption: 'Dancing vibes! 💃 #dance #fun',
        hashtags: ['dance', 'fun'],
        audioTitle: 'Original Audio - dance_quee',
        audioArtist: null,
        audioId: null,
        likes: 12500,
        comments: 120,
        shares: 10,
        views: 50000,
        isLiked: false,
        isSaved: false,
        isFollowing: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isSponsored: false,
        sponsorBrand: null,
        sponsorLogoUrl: null,
        productTags: null,
        remixEnabled: true,
        audioReuseEnabled: true,
        originalReelId: null,
        originalCreatorId: null,
        originalCreatorName: null,
        isRisingCreator: false,
        isTrending: false,
        duration: const Duration(seconds: 30),
      ),
      Reel(
        id: 'reel-2',
        userId: 'user-nature',
        userName: 'nature_walks',
        userAvatarUrl: 'https://i.pravatar.cc/150?u=nature_walks',
        videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-tree-branches-in-the-breeze-1188-large.mp4',
        thumbnailUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
        caption: 'Peaceful morning 🌳 #nature',
        hashtags: ['nature'],
        audioTitle: 'Original Audio - nature_walks',
        audioArtist: null,
        audioId: null,
        likes: 8200,
        comments: 45,
        shares: 5,
        views: 20000,
        isLiked: false,
        isSaved: false,
        isFollowing: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isSponsored: false,
        sponsorBrand: null,
        sponsorLogoUrl: null,
        productTags: null,
        remixEnabled: true,
        audioReuseEnabled: true,
        originalReelId: null,
        originalCreatorId: null,
        originalCreatorName: null,
        isRisingCreator: false,
        isTrending: false,
        duration: const Duration(seconds: 25),
      ),
      Reel(
        id: 'reel-3',
        userId: 'user-city',
        userName: 'city_life',
        userAvatarUrl: 'https://i.pravatar.cc/150?u=city_life',
        videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-traffic-in-the-city-at-night-4228-large.mp4',
        thumbnailUrl: 'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&q=80',
        caption: 'City lights 🌃 #nightlife',
        hashtags: ['city', 'nightlife'],
        audioTitle: 'Original Audio - city_life',
        audioArtist: null,
        audioId: null,
        likes: 25000,
        comments: 500,
        shares: 40,
        views: 120000,
        isLiked: false,
        isSaved: false,
        isFollowing: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        isSponsored: false,
        sponsorBrand: null,
        sponsorLogoUrl: null,
        productTags: null,
        remixEnabled: true,
        audioReuseEnabled: true,
        originalReelId: null,
        originalCreatorId: null,
        originalCreatorName: null,
        isRisingCreator: false,
        isTrending: true,
        duration: const Duration(seconds: 30),
      ),
    ];
  }

  /// When backend has posts with media_type=reel, fetchReels uses them; otherwise mock is shown.
  Future<void> _init() async {
    try {
      final fetched = await fetchReels(limit: 20, offset: 0);
      if (fetched.isNotEmpty) {
        _cache.clear();
        _cache.addAll(fetched);
      }
    } catch (_) {
      // Keep seeded mock data on fetch failure
    }
  }

  // Synchronous getter used by UI components that expect an immediate list
  List<Reel> getReels() => List.unmodifiable(_cache);

  Future<List<Reel>> fetchReels({int limit = 20, int offset = 0}) async {
    try {
      final page = (offset ~/ limit) + 1;
      final res = await _postsApi.getFeed(page: page, limit: limit);
      final allPosts = res['posts'] as List<dynamic>? ?? [];
      
      // Filter for reels client-side since API doesn't support type filtering yet
      final items = allPosts.where((p) {
        final type = (p['type'] as String? ?? p['media_type'] as String? ?? 'post').toLowerCase();
        return type == 'reel' || type == 'video';
      }).toList();

      final list = items.map((item) {
        final user = item['users'] as Map<String, dynamic>? ?? item['user'] as Map<String, dynamic>?;
        final media = item['media'] as List<dynamic>? ?? [];
        String videoUrl = '';
        String? thumbnailUrl;
        if (media.isNotEmpty) {
          final first = media.first;
          if (first is String) {
            videoUrl = first;
          } else if (first is Map) {
            final m = Map<String, dynamic>.from(first as Map);
            videoUrl = (m['url'] ?? m['fileUrl'] ?? m['videoUrl'] ?? '').toString();
            final thumbField = m['thumbnail'] ?? m['thumbnailUrl'] ?? m['thumb'];
            if (thumbField is List && thumbField.isNotEmpty) {
              thumbnailUrl = thumbField.first.toString();
            } else if (thumbField is String) {
              thumbnailUrl = thumbField;
            }
          }
        }
        return Reel(
          id: item['id'] as String,
          userId: item['user_id'] as String? ?? user?['id'] as String? ?? '',
          userName: user?['username'] as String? ?? 'user',
          userAvatarUrl: UrlHelper.normalizeUrl(user?['avatar_url'] as String?),
          videoUrl: UrlHelper.normalizeUrl(videoUrl),
          thumbnailUrl: thumbnailUrl != null ? UrlHelper.normalizeUrl(thumbnailUrl) : null,
          caption: item['caption'] as String?,
          hashtags: ((item['hashtags'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
          audioTitle: null,
          audioArtist: null,
          audioId: null,
          likes: item['likes_count'] as int? ?? 0,
          comments: item['comments_count'] as int? ?? 0,
          shares: item['shares_count'] as int? ?? 0,
          views: item['views_count'] as int? ?? 0,
          isLiked: item['is_liked_by_me'] as bool? ?? false,
          isSaved: false,
          isFollowing: false,
          createdAt: DateTime.tryParse(item['created_at'] as String? ?? '') ?? DateTime.now(),
          isSponsored: item['is_ad'] as bool? ?? false,
          sponsorBrand: item['ad_company_name'] as String?,
          sponsorLogoUrl: null,
          productTags: null,
          remixEnabled: true,
          audioReuseEnabled: true,
          originalReelId: null,
          originalCreatorId: null,
          originalCreatorName: null,
          isRisingCreator: false,
          isTrending: false,
          duration: const Duration(seconds: 30),
        );
      }).toList();
      // update cache if offset == 0
      if (offset == 0) {
        _cache.clear();
        _cache.addAll(list);
        // Dispatch to Redux to sync with Home Feed
        globalStore.dispatch(SetFeedPosts(list.map((r) => r.toFeedPost()).toList()));
      }
      return list;
    } catch (e) {
      // Fallback to mock reels (match React app sample)
      return [
        Reel(
          id: 'reel-1',
          userId: 'user-dance',
          userName: 'dance_queen',
          userAvatarUrl: 'https://i.pravatar.cc/150?u=dance_queen',
          videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-girl-dancing-happy-in-a-room-4179-large.mp4',
          thumbnailUrl: null,
          caption: 'Dancing vibes! 💃 #dance #fun',
          hashtags: ['dance','fun'],
          audioTitle: null,
          audioArtist: null,
          audioId: null,
          likes: 12500,
          comments: 120,
          shares: 10,
          views: 50000,
          isLiked: false,
          isSaved: false,
          isFollowing: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          isSponsored: false,
          sponsorBrand: null,
          sponsorLogoUrl: null,
          productTags: null,
          remixEnabled: true,
          audioReuseEnabled: true,
          originalReelId: null,
          originalCreatorId: null,
          originalCreatorName: null,
          isRisingCreator: false,
          isTrending: false,
          duration: const Duration(seconds: 30),
        ),
        Reel(
          id: 'reel-2',
          userId: 'user-nature',
          userName: 'nature_walks',
          userAvatarUrl: 'https://i.pravatar.cc/150?u=nature_walks',
          videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-tree-branches-in-the-breeze-1188-large.mp4',
          thumbnailUrl: null,
          caption: 'Peaceful morning 🌳 #nature',
          hashtags: ['nature'],
          audioTitle: null,
          audioArtist: null,
          audioId: null,
          likes: 8200,
          comments: 45,
          shares: 5,
          views: 20000,
          isLiked: false,
          isSaved: false,
          isFollowing: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          isSponsored: false,
          sponsorBrand: null,
          sponsorLogoUrl: null,
          productTags: null,
          remixEnabled: true,
          audioReuseEnabled: true,
          originalReelId: null,
          originalCreatorId: null,
          originalCreatorName: null,
          isRisingCreator: false,
          isTrending: false,
          duration: const Duration(seconds: 25),
        ),
        Reel(
          id: 'reel-3',
          userId: 'user-city',
          userName: 'city_life',
          userAvatarUrl: 'https://i.pravatar.cc/150?u=city_life',
          videoUrl: 'https://assets.mixkit.co/videos/preview/mixkit-traffic-in-the-city-at-night-4228-large.mp4',
          thumbnailUrl: null,
          caption: 'City lights 🌃 #nightlife',
          hashtags: ['city','nightlife'],
          audioTitle: null,
          audioArtist: null,
          audioId: null,
          likes: 25000,
          comments: 500,
          shares: 40,
          views: 120000,
          isLiked: false,
          isSaved: false,
          isFollowing: false,
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
          isSponsored: false,
          sponsorBrand: null,
          sponsorLogoUrl: null,
          productTags: null,
          remixEnabled: true,
          audioReuseEnabled: true,
          originalReelId: null,
          originalCreatorId: null,
          originalCreatorName: null,
          isRisingCreator: false,
          isTrending: true,
          duration: const Duration(seconds: 30),
        ),
      ];
    }
  }

  Future<void> incrementViews(String reelId) async {
    // API doesn't support view increment yet
  }

  Future<void> incrementShares(String reelId) async {
    // API doesn't support share increment yet
  }

  // Local cache helpers for UI interactions (optimistic)
  void toggleLike(String reelId) {
    final idx = _cache.indexWhere((r) => r.id == reelId);
    if (idx != -1) {
      final r = _cache[idx];
      final newLiked = !r.isLiked;
      final updatedReel = r.copyWith(isLiked: newLiked, likes: newLiked ? r.likes + 1 : r.likes - 1);
      _cache[idx] = updatedReel;
      
      // Update Redux store
      globalStore.dispatch(UpdatePostLikedWithCount(reelId, newLiked, updatedReel.likes));
      
      // async backend update
      if (newLiked) {
        _postsApi.likePost(reelId);
      } else {
        _postsApi.unlikePost(reelId);
      }
    }
  }

  void toggleSave(String reelId) {
    final idx = _cache.indexWhere((r) => r.id == reelId);
    if (idx != -1) {
      final r = _cache[idx];
      final newSaved = !r.isSaved;
      final updatedReel = r.copyWith(isSaved: newSaved);
      _cache[idx] = updatedReel;
      
      // Update Redux store
      globalStore.dispatch(UpdatePostSaved(reelId, newSaved));
    }
  }

  void toggleFollow(String userId) {
    for (int i = 0; i < _cache.length; i++) {
      if (_cache[i].userId == userId) {
        _cache[i] = _cache[i].copyWith(isFollowing: !_cache[i].isFollowing);
      }
    }
    // backend follow action (not supported in new API yet)
  }
}
