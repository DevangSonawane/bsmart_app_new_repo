import '../api/posts_api.dart';
import '../api/reels_api.dart';
import '../models/ad_model.dart';
import '../models/feed_post_model.dart';
import '../models/reel_model.dart';
import 'content_sync_service.dart';
import 'supabase_service.dart';
import '../state/feed_actions.dart';
import '../state/store.dart';
import '../utils/url_helper.dart';
import '../api/api_client.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

class ReelsService {
  static final ReelsService _instance = ReelsService._internal();
  factory ReelsService() => _instance;

  final PostsApi _postsApi = PostsApi();
  final ReelsApi _reelsApi = ReelsApi();
  final SupabaseService _supabase = SupabaseService();
  final List<Reel> _cache = [];
  // Kept alive for the lifetime of the singleton so reel state stays in sync.
  // ignore: unused_field
  late final StreamSubscription<ContentSyncEvent> _syncSub;

  void _handleSyncEvent(ContentSyncEvent event) {
    if (event.followed != null && event.userId.isNotEmpty) {
      var changed = false;
      final followed =
          event.followState == 'requested' ? false : event.followed!;
      for (var i = 0; i < _cache.length; i++) {
        if (_cache[i].userId != event.userId) continue;
        if (_cache[i].isFollowing == followed) continue;
        _cache[i] = _cache[i].copyWith(isFollowing: followed);
        changed = true;
      }
      if (changed) {
        globalStore.dispatch(UpdateUserFollowed(event.userId, followed));
      }
      return;
    }

    if (event.contentId.isEmpty) return;
    final idx = _cache.indexWhere((r) => r.id == event.contentId);
    if (idx == -1) return;

    final current = _cache[idx];
    switch (event.kind) {
      case ContentSyncKind.like:
        if (event.likesCount == null &&
            event.likesDelta == null &&
            current.isLiked == (event.liked ?? current.isLiked)) {
          return;
        }
        final likesCount = event.likesCount ??
            ((event.likesDelta ?? 0) != 0
                ? (current.likes + (event.likesDelta ?? 0))
                    .clamp(0, 1 << 31)
                    .toInt()
                : null);
        final next = current.copyWith(
          isLiked: event.liked ?? current.isLiked,
          likes: likesCount ??
              ((event.liked ?? current.isLiked)
                  ? current.likes + 1
                  : (current.likes > 0 ? current.likes - 1 : 0)),
        );
        if (next == current) return;
        _cache[idx] = next;
        break;
      case ContentSyncKind.save:
        if (current.isSaved == (event.saved ?? current.isSaved)) return;
        _cache[idx] = current.copyWith(
          isSaved: event.saved ?? current.isSaved,
        );
        break;
      case ContentSyncKind.commentCount:
        if (event.commentsCount == null && event.commentsDelta == null) return;
        final commentsCount = event.commentsCount ??
            ((event.commentsDelta ?? 0) != 0
                ? (current.comments + (event.commentsDelta ?? 0))
                    .clamp(0, 1 << 31)
                    .toInt()
                : null);
        _cache[idx] = current.copyWith(
          comments: commentsCount ?? current.comments,
        );
        break;
      case ContentSyncKind.follow:
        break;
    }
  }

  List<Reel> getReels() => List.unmodifiable(_applyFeedOverrides(_cache));

  void clearCache() {
    _cache.clear();
  }

  void _publishSync({
    required ContentSyncKind kind,
    required String contentId,
    String userId = '',
    bool? liked,
    int? likesCount,
    int? likesDelta,
    bool? saved,
    bool? followed,
    String? followState,
    int? commentsCount,
    int? commentsDelta,
    bool? isTweet,
  }) {
    ContentSyncService().publish(ContentSyncEvent(
      kind: kind,
      contentId: contentId,
      userId: userId,
      liked: liked,
      likesCount: likesCount,
      likesDelta: likesDelta,
      saved: saved,
      followed: followed,
      followState: followState,
      commentsCount: commentsCount,
      commentsDelta: commentsDelta,
      isTweet: isTweet,
    ));
  }

  ReelsService._internal() {
    _syncSub = ContentSyncService().changes.listen(_handleSyncEvent);
  }

  Future<List<Reel>> fetchReels({int limit = 20, int offset = 0}) async {
    final page = (offset ~/ limit) + 1;
    final res = await _fetchMixedPage(page: page, limit: limit);
    final rawItems = _extractList(res);

    final parsed = rawItems
        .map((item) => _parseMixedReel(item))
        .whereType<Reel>()
        .where((reel) => reel.videoUrl.isNotEmpty)
        .toList();
    final synced = _applyFeedOverrides(parsed);

    if (offset == 0) {
      _cache
        ..clear()
        ..addAll(synced);
    } else {
      _cache.addAll(synced);
    }

    return offset == 0 ? getReels() : List.unmodifiable(synced);
  }

  Future<List<FeedPost>> fetchMixedReelsFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    final page = (offset ~/ limit) + 1;
    final res = await _fetchMixedPage(page: page, limit: limit);
    final rawItems = _extractList(res);
    final parsed = rawItems
        .map((item) => _parseMixedFeedPost(item))
        .whereType<FeedPost>()
        .toList();
    return parsed;
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
      final headers = UrlHelper.shouldAttachAuthHeader(url)
          ? authHeaders
          : const <String, String>{};
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

  Future<dynamic> _fetchMixedPage({required int page, required int limit}) {
    return _reelsApi.listMixedReels(page: page, limit: limit);
  }

  Reel? _parseMixedReel(dynamic raw) {
    if (raw is! Map) return null;
    final item = Map<String, dynamic>.from(raw);
    final itemType = (item['item_type'] ?? item['itemType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (itemType == 'ad') {
      return _parseAdReel(item);
    }
    if (itemType == 'promote_reel' || itemType == 'promote-reel') {
      return _parsePromoteReel(item);
    }
    return _parseReel(item);
  }

  FeedPost? _parseMixedFeedPost(dynamic raw) {
    if (raw is! Map) return null;
    final item = Map<String, dynamic>.from(raw);
    final itemType = (item['item_type'] ?? item['itemType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (itemType == 'ad') {
      return _parseAdFeedPost(item);
    }
    if (itemType == 'promote_reel' || itemType == 'promote-reel') {
      return _parsePromoteFeedPost(item);
    }
    final reel = _parseReel(item);
    return reel?.toFeedPost();
  }

  Reel? _parseAdReel(Map<String, dynamic> item) {
    final ad = Ad.fromApi(item);
    final primaryUrl = UrlHelper.normalizeUrl(
      ad.videoUrl != null && ad.videoUrl!.isNotEmpty
          ? ad.videoUrl!
          : (ad.imageUrl ?? ''),
    );
    if (primaryUrl.isEmpty) return null;
    final isVideo = primaryUrl.toLowerCase().endsWith('.mp4') ||
        primaryUrl.toLowerCase().endsWith('.mov') ||
        (ad.videoUrl != null && ad.videoUrl!.isNotEmpty);
    final ownerName = (ad.vendorBusinessName?.trim().isNotEmpty ?? false)
        ? ad.vendorBusinessName!.trim()
        : ((ad.companyName.trim().isNotEmpty)
            ? ad.companyName.trim()
            : 'Sponsored');

    return Reel(
      id: ad.id,
      userId: ad.userId ?? ad.companyId,
      userName: ownerName,
      userAvatarUrl: UrlHelper.normalizeUrl(ad.userAvatarUrl ?? ad.companyLogo),
      videoUrl: primaryUrl,
      thumbnailUrl: isVideo ? UrlHelper.normalizeUrl(ad.imageUrl) : null,
      caption: (ad.caption?.trim().isNotEmpty ?? false)
          ? ad.caption!.trim()
          : ((ad.description.trim().isNotEmpty)
              ? ad.description.trim()
              : ad.title),
      hashtags: ad.hashtags,
      likes: ad.likesCount,
      comments: ad.commentsCount,
      shares: ad.sharesCount,
      views: ad.currentViews,
      isLiked: ad.isLikedByMe,
      isSaved: ad.isSavedByMe,
      isFollowing: false,
      createdAt: ad.createdAt,
      isSponsored: true,
      sponsorBrand: ad.companyName,
      sponsorLogoUrl: UrlHelper.normalizeUrl(ad.companyLogo),
      duration: Duration(
          seconds: ad.watchDurationSeconds > 0 ? ad.watchDurationSeconds : 15),
    );
  }

  Reel? _parsePromoteReel(Map<String, dynamic> item) {
    final post = _parsePromoteFeedPost(item);
    if (post == null) return null;
    return Reel.fromFeedPost(post).copyWith(
      id: post.id,
      isSponsored: true,
      sponsorBrand: post.userName,
      sponsorLogoUrl: post.userAvatar,
    );
  }

  FeedPost? _parseAdFeedPost(Map<String, dynamic> item) {
    final ad = Ad.fromApi(item);
    final primaryUrl = UrlHelper.normalizeUrl(
      ad.videoUrl != null && ad.videoUrl!.isNotEmpty
          ? ad.videoUrl!
          : (ad.imageUrl ?? ''),
    );
    if (primaryUrl.isEmpty) return null;
    final isVideo = primaryUrl.toLowerCase().endsWith('.mp4') ||
        primaryUrl.toLowerCase().endsWith('.mov') ||
        (ad.videoUrl != null && ad.videoUrl!.isNotEmpty);
    final ownerName = (ad.vendorBusinessName?.trim().isNotEmpty ?? false)
        ? ad.vendorBusinessName!.trim()
        : ((ad.companyName.trim().isNotEmpty)
            ? ad.companyName.trim()
            : 'Sponsored');

    return FeedPost(
      id: ad.id,
      userId: ad.userId ?? ad.companyId,
      userName: ownerName,
      fullName: null,
      userAvatar: UrlHelper.normalizeUrl(ad.userAvatarUrl ?? ad.companyLogo),
      mediaType: isVideo ? PostMediaType.video : PostMediaType.image,
      mediaUrls: [primaryUrl],
      thumbnailUrl: isVideo ? UrlHelper.normalizeUrl(ad.imageUrl) : null,
      caption: (ad.caption?.trim().isNotEmpty ?? false)
          ? ad.caption!.trim()
          : ((ad.description.trim().isNotEmpty)
              ? ad.description.trim()
              : ad.title),
      hashtags: ad.hashtags,
      createdAt: ad.createdAt,
      likes: ad.likesCount,
      comments: ad.commentsCount,
      shares: ad.sharesCount,
      isLiked: ad.isLikedByMe,
      isSaved: ad.isSavedByMe,
      isFollowed: false,
      isAd: true,
      adTitle: ad.title,
      adCompanyId: ad.companyId,
      adCompanyName: ad.companyName,
      adCategory: ad.category,
      totalBudgetCoins: ad.totalBudgetCoins,
      targetLocations: ad.targetLocations,
      targetLanguages: ad.targetLanguages,
    );
  }

  FeedPost? _parsePromoteFeedPost(Map<String, dynamic> item) {
    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    bool toBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase().trim();
        return lower == 'true' || lower == '1' || lower == 'yes';
      }
      return false;
    }

    final id = str(item['_id'] ?? item['id'] ?? item['promote_reel_id']);
    if (id == null) return null;

    final user = item['user_id'] is Map
        ? Map<String, dynamic>.from(item['user_id'] as Map)
        : item['user'] is Map
            ? Map<String, dynamic>.from(item['user'] as Map)
            : <String, dynamic>{};
    final userId = str(user['_id'] ?? user['id'] ?? item['user_id']) ?? '';
    final userName =
        str(user['username'] ?? user['full_name'] ?? 'User') ?? 'User';
    final avatar = UrlHelper.normalizeUrl(
      user['avatar_url'] ??
          user['profile_picture'] ??
          user['profilePicture'] ??
          user['profile_pic'] ??
          user['avatarUrl'],
    );

    final media = item['media'];
    if (media is! List || media.isEmpty) return null;
    final first = media.first;
    String? mediaUrl;
    String? thumbnailUrl;
    if (first is String) {
      mediaUrl = first;
    } else if (first is Map) {
      final m = Map<String, dynamic>.from(first);
      mediaUrl =
          (m['fileUrl'] ?? m['file_url'] ?? m['url'] ?? m['link'])?.toString();
      final rawThumb = m['thumbnails'] ??
          m['thumbnail'] ??
          m['thumbnailUrl'] ??
          m['thumbnail_url'] ??
          m['thumb'];
      if (rawThumb is String) {
        thumbnailUrl = rawThumb;
      } else if (rawThumb is Map) {
        final t = Map<String, dynamic>.from(rawThumb);
        thumbnailUrl = (t['fileUrl'] ?? t['file_url'] ?? t['url'] ?? t['path'])
            ?.toString();
      }
    }
    mediaUrl = UrlHelper.normalizeUrl(mediaUrl ?? '');
    if (mediaUrl.isEmpty) return null;
    thumbnailUrl = UrlHelper.normalizeUrl(thumbnailUrl ?? '');

    final productsRaw = item['products'];
    final products = productsRaw is List
        ? productsRaw
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList()
        : const <Map<String, dynamic>>[];

    return FeedPost(
      id: 'promote-$id',
      userId: userId,
      userName: userName,
      userAvatar: avatar.isEmpty ? null : avatar,
      mediaType: PostMediaType.reel,
      mediaUrls: [mediaUrl],
      thumbnailUrl: thumbnailUrl.isEmpty ? null : thumbnailUrl,
      caption: (item['caption'] ?? item['content'] ?? '').toString(),
      hashtags: ((item['tags'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      createdAt: DateTime.tryParse(
            (item['created_at'] ?? item['createdAt'] ?? '').toString(),
          ) ??
          DateTime.now(),
      likes: toInt(item['likes_count'] ?? item['likesCount'] ?? item['likes']),
      comments: toInt(
        item['comments_count'] ?? item['commentsCount'] ?? item['comments'],
      ),
      shares:
          toInt(item['shares_count'] ?? item['sharesCount'] ?? item['shares']),
      views: toInt(item['views_count'] ?? item['viewsCount'] ?? item['views']),
      isLiked: toBool(item['is_liked_by_me'] ?? item['isLikedByMe']),
      isSaved: toBool(item['is_saved_by_me'] ?? item['isSavedByMe']),
      isFollowed: toBool(item['is_followed_by_me'] ?? item['isFollowedByMe']),
      isAd: false,
      promotedProducts: products,
    );
  }

  Reel? _parseReel(dynamic raw) {
    if (raw is! Map) return null;
    final item = Map<String, dynamic>.from(raw);

    final id =
        _string(item['_id']) ?? _string(item['id']) ?? _string(item['post_id']);
    if (id == null || id.isEmpty) return null;

    final userField =
        item['user_id'] ?? item['userId'] ?? item['user'] ?? item['author'];
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
        videoUrl = _string(first);
      } else if (first is Map) {
        final media = Map<String, dynamic>.from(first);
        videoUrl = _string(media['fileUrl']) ??
            _string(media['url']) ??
            _string(media['videoUrl']) ??
            _string(media['file_url']);

        final thumbField = media['thumbnail'] ??
            media['thumbnails'] ??
            media['thumbnailUrl'] ??
            media['thumb'];
        if (thumbField is String) {
          thumbnailUrl = _string(thumbField);
        } else if (thumbField is Map) {
          final thumbMap = Map<String, dynamic>.from(thumbField);
          thumbnailUrl = _string(thumbMap['fileUrl']) ??
              _string(thumbMap['url']) ??
              _string(thumbMap['file_url']);
        } else if (thumbField is List && thumbField.isNotEmpty) {
          final firstThumb = thumbField.first;
          if (firstThumb is String) {
            thumbnailUrl = _string(firstThumb);
          } else if (firstThumb is Map) {
            final thumbMap = Map<String, dynamic>.from(firstThumb);
            thumbnailUrl = _string(thumbMap['fileUrl']) ??
                _string(thumbMap['url']) ??
                _string(thumbMap['file_url']);
          }
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
        _string(item['userId']) ??
        _string(item['user_id']) ??
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
    _publishSync(
      kind: ContentSyncKind.like,
      contentId: reelId,
      liked: optimistic.isLiked,
      likesCount: optimistic.likes,
      likesDelta: nextLiked ? 1 : -1,
    );

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
      _publishSync(
        kind: ContentSyncKind.like,
        contentId: reelId,
        liked: original.isLiked,
        likesCount: original.likes,
        likesDelta: original.isLiked ? 1 : -1,
      );
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
    _publishSync(
      kind: ContentSyncKind.save,
      contentId: reelId,
      saved: optimistic.isSaved,
    );

    try {
      final saved = await _supabase.setPostSaved(reelId, save: nextSaved);
      bool serverSaved = saved;
      try {
        final p = await _supabase.getPostById(reelId);
        serverSaved = (p?['is_saved_by_me'] as bool?) ?? saved;
      } catch (_) {}

      _cache[idx] = optimistic.copyWith(isSaved: serverSaved);
      globalStore.dispatch(UpdatePostSaved(reelId, serverSaved));
      _publishSync(
        kind: ContentSyncKind.save,
        contentId: reelId,
        saved: serverSaved,
      );
    } catch (_) {
      _cache[idx] = original;
      globalStore.dispatch(UpdatePostSaved(reelId, original.isSaved));
      _publishSync(
        kind: ContentSyncKind.save,
        contentId: reelId,
        saved: original.isSaved,
      );
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
    _publishSync(
      kind: ContentSyncKind.follow,
      contentId: '',
      userId: userId,
      followed: next,
      followState: next ? 'following' : 'not_following',
    );
  }
}