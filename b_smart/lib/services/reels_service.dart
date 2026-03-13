import '../api/posts_api.dart';
import '../api/reels_api.dart';
import '../models/feed_post_model.dart';
import '../models/reel_model.dart';
import 'supabase_service.dart';
import '../state/feed_actions.dart';
import '../state/store.dart';
import '../utils/url_helper.dart';
import '../api/api_client.dart';
import 'package:video_player/video_player.dart';

class ReelsService {
  static final ReelsService _instance = ReelsService._internal();
  factory ReelsService() => _instance;
  ReelsService._internal();

  final PostsApi _postsApi = PostsApi();
  final ReelsApi _reelsApi = ReelsApi();
  final SupabaseService _supabase = SupabaseService();
  final List<Reel> _cache = [];

  List<Reel> getReels() => List.unmodifiable(_applyFeedOverrides(_cache));

  Future<List<Reel>> fetchReels({int limit = 20, int offset = 0}) async {
    final page = (offset ~/ limit) + 1;
    final res = await _reelsApi.listReels(page: page, limit: limit);
    final rawItems = _extractList(res);

    final parsed = rawItems
        .map((item) => _parseReel(item))
        .whereType<Reel>()
        .where((reel) => reel.videoUrl.isNotEmpty)
        .toList();
    final synced = _applyFeedOverrides(parsed);

    if (offset == 0) {
      _cache
        ..clear()
        ..addAll(synced);
      globalStore
          .dispatch(SetFeedPosts(synced.map((r) => r.toFeedPost()).toList()));
    } else {
      _cache.addAll(synced);
    }

    return offset == 0 ? getReels() : List.unmodifiable(synced);
  }

  Future<void> preWarmReels(int count) async {
    if (count <= 0) return;
    final reels = getReels();
    final upperBound = reels.length < count ? reels.length : count;
    final token = await ApiClient().getToken();
    final authHeaders = <String, String>{};
    if (token != null && token.isNotEmpty) {
      authHeaders['Authorization'] = 'Bearer $token';
    }

    for (var i = 0; i < upperBound; i++) {
      final url = UrlHelper.absoluteUrl(reels[i].videoUrl);
      if (url.isEmpty) continue;
      final headers =
          UrlHelper.shouldAttachAuthHeader(url) ? authHeaders : const <String, String>{};
      VideoPlayerController? controller;
      try {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          httpHeaders: headers,
        );
        await controller.initialize();
      } catch (_) {
        // Best-effort warmup only.
      } finally {
        try {
          await controller?.dispose();
        } catch (_) {}
      }
    }
  }

  List<dynamic> _extractList(dynamic payload) {
    if (payload is List<dynamic>) return payload;
    if (payload is Map<String, dynamic>) {
      final candidates = [
        payload['data'],
        payload['reels'],
        payload['posts'],
        payload['results'],
      ];
      for (final c in candidates) {
        if (c is List<dynamic>) return c;
      }
    }
    return const [];
  }

  Reel? _parseReel(dynamic raw) {
    if (raw is! Map) return null;
    final item = Map<String, dynamic>.from(raw);

    final id =
        _string(item['_id']) ?? _string(item['id']) ?? _string(item['post_id']);
    if (id == null || id.isEmpty) return null;

    final userField = item['user_id'];
    final userMap = userField is Map
        ? Map<String, dynamic>.from(userField)
        : item['users'] is Map
            ? Map<String, dynamic>.from(item['users'])
            : item['user'] is Map
                ? Map<String, dynamic>.from(item['user'])
                : <String, dynamic>{};

    final mediaList =
        item['media'] is List ? (item['media'] as List) : const [];
    String? videoUrl;
    String? thumbnailUrl;
    String? aspectRatio;

    if (mediaList.isNotEmpty) {
      final first = mediaList.first;
      if (first is String) {
        videoUrl = first;
      } else if (first is Map) {
        final media = Map<String, dynamic>.from(first);
        videoUrl = _string(media['fileUrl']) ??
            _string(media['url']) ??
            _string(media['videoUrl']) ??
            _string(media['file_url']);

        final thumbField =
            media['thumbnail'] ?? media['thumbnailUrl'] ?? media['thumb'];
        if (thumbField is String) {
          thumbnailUrl = thumbField;
        } else if (thumbField is Map) {
          final thumbMap = Map<String, dynamic>.from(thumbField);
          thumbnailUrl = _string(thumbMap['fileUrl']) ??
              _string(thumbMap['url']) ??
              _string(thumbMap['file_url']);
        } else if (thumbField is List && thumbField.isNotEmpty) {
          thumbnailUrl = _string(thumbField.first);
        }

        final mediaCrop = media['crop'] is Map
            ? Map<String, dynamic>.from(media['crop'])
            : const <String, dynamic>{};
        aspectRatio = _string(mediaCrop['aspect_ratio']) ??
            _string(media['aspect_ratio']);
      }
    }

    final reelCrop = item['crop'] is Map
        ? Map<String, dynamic>.from(item['crop'])
        : const <String, dynamic>{};
    aspectRatio = aspectRatio ??
        _string(reelCrop['aspect_ratio']) ??
        _string(item['aspect_ratio']);

    final tagsRaw = item['tags'] ?? item['hashtags'] ?? const [];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final createdAtRaw =
        _string(item['created_at']) ?? _string(item['createdAt']);

    final userId = _string(userMap['_id']) ??
        _string(userMap['id']) ??
        (userField is String || userField is num ? _string(userField) : null) ??
        '';
    final userName = _string(userMap['username']) ??
        _string(userMap['full_name']) ??
        'Unknown';

    return Reel(
      id: id,
      userId: userId,
      userName: userName,
      userAvatarUrl: UrlHelper.normalizeUrl(_string(userMap['avatar_url'])),
      videoUrl: UrlHelper.normalizeUrl(videoUrl ?? ''),
      thumbnailUrl: UrlHelper.normalizeUrl(thumbnailUrl),
      aspectRatio: aspectRatio,
      caption: _string(item['caption']),
      hashtags: tags,
      audioTitle: null,
      audioArtist: null,
      audioId: null,
      likes: _toInt(item['likes_count']),
      comments: _toInt(item['comments_count']),
      shares: _toInt(item['shares_count']),
      views: _toInt(item['views_count']),
      isLiked: _toBool(item['is_liked_by_me']),
      isSaved: _toBool(item['is_saved_by_me']),
      isFollowing: _toBool(item['is_followed_by_me']),
      createdAt: DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now(),
      isSponsored: _toBool(item['is_ad']),
      sponsorBrand: _string(item['ad_company_name']),
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
  }

  String? _string(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1';
    }
    return false;
  }

  List<Reel> _applyFeedOverrides(List<Reel> reels) {
    if (reels.isEmpty) return reels;
    try {
      final feedById = <String, FeedPost>{
        for (final p in globalStore.state.feedState.posts) p.id: p,
      };
      return reels.map((reel) {
        final feedPost = feedById[reel.id];
        if (feedPost == null) return reel;
        return reel.copyWith(
          likes: feedPost.likes,
          comments: feedPost.comments,
          shares: feedPost.shares,
          views: feedPost.views,
          isLiked: feedPost.isLiked,
          isSaved: feedPost.isSaved,
          isFollowing: feedPost.isFollowed,
        );
      }).toList();
    } catch (_) {
      return reels;
    }
  }

  Future<void> incrementViews(String reelId) async {
    // API does not expose a view increment endpoint yet.
  }

  Future<void> incrementShares(String reelId) async {
    // API does not expose a share increment endpoint yet.
  }

  Future<void> toggleLike(String reelId) async {
    final idx = _cache.indexWhere((r) => r.id == reelId);
    if (idx == -1) return;

    final original = _cache[idx];
    final nextLiked = !original.isLiked;
    final optimistic = original.copyWith(
      isLiked: nextLiked,
      likes: nextLiked
          ? original.likes + 1
          : (original.likes > 0 ? original.likes - 1 : 0),
    );

    _cache[idx] = optimistic;
    globalStore.dispatch(
        UpdatePostLikedWithCount(reelId, optimistic.isLiked, optimistic.likes));

    try {
      if (nextLiked) {
        await _postsApi.likePost(reelId);
      } else {
        await _postsApi.unlikePost(reelId);
      }
    } catch (_) {
      _cache[idx] = original;
      globalStore.dispatch(
          UpdatePostLikedWithCount(reelId, original.isLiked, original.likes));
      rethrow;
    }
  }

  Future<void> toggleSave(String reelId) async {
    final idx = _cache.indexWhere((r) => r.id == reelId);
    if (idx == -1) return;

    final original = _cache[idx];
    final nextSaved = !original.isSaved;
    final optimistic = original.copyWith(isSaved: nextSaved);

    _cache[idx] = optimistic;
    globalStore.dispatch(UpdatePostSaved(reelId, optimistic.isSaved));

    try {
      final saved = await _supabase.setPostSaved(reelId, save: nextSaved);
      bool serverSaved = saved;
      try {
        final p = await _supabase.getPostById(reelId);
        serverSaved = (p?['is_saved_by_me'] as bool?) ?? saved;
      } catch (_) {}

      _cache[idx] = optimistic.copyWith(isSaved: serverSaved);
      globalStore.dispatch(UpdatePostSaved(reelId, serverSaved));
    } catch (_) {
      _cache[idx] = original;
      globalStore.dispatch(UpdatePostSaved(reelId, original.isSaved));
      rethrow;
    }
  }

  void toggleFollow(String userId) {
    final first = _cache.where((r) => r.userId == userId);
    if (first.isEmpty) return;
    final next = !first.first.isFollowing;
    for (var i = 0; i < _cache.length; i++) {
      if (_cache[i].userId == userId) {
        _cache[i] = _cache[i].copyWith(isFollowing: next);
      }
    }
    globalStore.dispatch(UpdateUserFollowed(userId, next));
  }
}
