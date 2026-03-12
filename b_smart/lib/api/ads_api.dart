import '../config/api_config.dart';
import 'api_client.dart';
import 'api_exceptions.dart';

/// REST API wrapper for `/ads` endpoints.
///
/// Endpoints:
///   GET  /ads/categories  – fetch ad category list
///   GET  /ads/feed        – fetch active ads feed (optional category)
///   GET  /ads/user/:userId – fetch ads for vendor (optional category)
///   GET  /ads             – list all ads (admin only)
///   GET  /ads/search      – search ads with pagination and filters
///   GET  /ads/:id         – get ad details by id
///   DELETE /ads/:id       – delete ad by id (vendor)
///   POST /ads/:id/view    – record ad view
///   POST /ads/:id/like    – like ad
///   POST /ads/:id/dislike – reverse a previous like
///   POST /ads/:id/save    – save ad
///   POST /ads/:id/unsave  – unsave ad
///   POST /ads/:id/comments – add comment to ad
///   GET  /ads/:id/comments – get comments for ad
///   GET  /ads/comments/:commentId/replies – get replies for ad comment
///   DELETE /ads/comments/:commentId – delete ad comment
///   POST /ads/comments/:id/like – like/unlike ad comment
///   POST /ads/comments/:id/dislike – dislike/undislike ad comment
///   PATCH /admin/ads/:id – admin update ad status
///   DELETE /admin/ads/:id – admin delete ad (soft delete)
///   POST /ads/categories  – add ad category
///   POST /ads             – create ad
class AdsApi {
  static final AdsApi _instance = AdsApi._internal();
  factory AdsApi() => _instance;
  AdsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  Future<List<String>> getCategories() async {
    final res = await _client.get('$_basePath/ads/categories');
    if (res is Map<String, dynamic>) {
      final list = (res['categories'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      return list;
    }
    if (res is List) {
      return res.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }
    await _client.post(
      '$_basePath/ads/categories',
      body: {'name': trimmed},
    );
  }

  Future<List<Map<String, dynamic>>> getFeed({String? category}) async {
    final normalizedCategory = category?.trim();
    final query = (normalizedCategory == null ||
            normalizedCategory.isEmpty ||
            normalizedCategory.toLowerCase() == 'all')
        ? null
        : <String, String>{'category': normalizedCategory};
    final res = await _client.get('$_basePath/ads/feed', queryParams: query);

    List<dynamic> rawList = const [];
    if (res is List) {
      rawList = res;
    } else if (res is Map) {
      if (res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res['data'] is Map && (res['data'] as Map)['ads'] is List) {
        rawList = (res['data'] as Map)['ads'] as List;
      } else if (res['ads'] is List) {
        rawList = res['ads'] as List;
      }
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getUserAds(
    String userId, {
    String? category,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    final normalizedCategory = category?.trim();
    final query = (normalizedCategory == null ||
            normalizedCategory.isEmpty ||
            normalizedCategory.toLowerCase() == 'all')
        ? null
        : <String, String>{'category': normalizedCategory};
    final res =
        await _client.get('$_basePath/ads/user/$uid', queryParams: query);

    List<dynamic> rawList = const [];
    if (res is List) {
      rawList = res;
    } else if (res is Map) {
      if (res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res['data'] is Map && (res['data'] as Map)['ads'] is List) {
        rawList = (res['data'] as Map)['ads'] as List;
      } else if (res['ads'] is List) {
        rawList = res['ads'] as List;
      }
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAllAds() async {
    final res = await _client.get('$_basePath/ads');

    List<dynamic> rawList = const [];
    if (res is List) {
      rawList = res;
    } else if (res is Map) {
      if (res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res['data'] is Map && (res['data'] as Map)['ads'] is List) {
        rawList = (res['data'] as Map)['ads'] as List;
      } else if (res['ads'] is List) {
        rawList = res['ads'] as List;
      }
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> searchAds({
    String? q,
    String? category,
    String? hashtag,
    String? userId,
    String? status,
    String? contentType,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{};

    void putIfNotBlank(String key, String? value) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        query[key] = normalized;
      }
    }

    putIfNotBlank('q', q);
    putIfNotBlank('category', category);
    putIfNotBlank('hashtag', hashtag);
    putIfNotBlank('user_id', userId);
    putIfNotBlank('status', status);
    putIfNotBlank('content_type', contentType);
    query['page'] = (page < 1 ? 1 : page).toString();
    query['limit'] = (limit < 1 ? 1 : (limit > 50 ? 50 : limit)).toString();

    final res = await _client.get('$_basePath/ads/search', queryParams: query);

    if (res is Map<String, dynamic>) {
      final rawAds = res['ads'] is List
          ? (res['ads'] as List)
          : (res['data'] is Map && (res['data'] as Map)['ads'] is List)
              ? ((res['data'] as Map)['ads'] as List)
              : const <dynamic>[];

      return {
        'total': res['total'],
        'page': res['page'],
        'limit': res['limit'],
        'totalPages': res['totalPages'],
        'ads': rawAds
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      };
    }

    if (res is List) {
      return {
        'total': res.length,
        'page': page,
        'limit': limit,
        'totalPages': 1,
        'ads': res
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      };
    }

    return {
      'total': 0,
      'page': page,
      'limit': limit,
      'totalPages': 0,
      'ads': const <Map<String, dynamic>>[],
    };
  }

  Future<Map<String, dynamic>?> getAdById(String id) async {
    final adId = id.trim();
    if (adId.isEmpty) {
      throw ArgumentError('id cannot be empty');
    }

    try {
      final res = await _client.get('$_basePath/ads/$adId');
      if (res is Map<String, dynamic>) {
        if (res['ad'] is Map) {
          return Map<String, dynamic>.from(res['ad'] as Map);
        }
        if (res['data'] is Map) {
          return Map<String, dynamic>.from(res['data'] as Map);
        }
        return res;
      }
      return null;
    } on NotFoundException {
      return null;
    }
  }

  Future<bool> deleteAd(String id) async {
    final adId = id.trim();
    if (adId.isEmpty) {
      throw ArgumentError('id cannot be empty');
    }
    final res = await _client.delete('$_basePath/ads/$adId');
    if (res is Map<String, dynamic>) {
      final ok = res['success'];
      if (ok is bool) return ok;
    }
    return true;
  }

  Future<Map<String, dynamic>> recordAdView({
    required String adId,
    required String userId,
  }) async {
    final normalizedAdId = adId.trim();
    final normalizedUserId = userId.trim();
    if (normalizedAdId.isEmpty) {
      throw ArgumentError('adId cannot be empty');
    }
    if (normalizedUserId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }
    final res = await _client.post(
      '$_basePath/ads/$normalizedAdId/view',
      body: {
        'user': {'id': normalizedUserId},
      },
    );
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> likeAd({
    required String adId,
    String? userId,
  }) async {
    final normalizedAdId = adId.trim();
    final normalizedUserId = userId?.trim();
    if (normalizedAdId.isEmpty) {
      throw ArgumentError('adId cannot be empty');
    }
    if (normalizedUserId != null && normalizedUserId.isEmpty) {
      throw ArgumentError('userId cannot be empty when provided');
    }
    final path = '$_basePath/ads/$normalizedAdId/like';
    try {
      final body = normalizedUserId == null
          ? null
          : <String, dynamic>{
              'user': {'id': normalizedUserId},
            };
      final res = await _client.post(path, body: body);
      return (res as Map).cast<String, dynamic>();
    } on BadRequestException {
      if (normalizedUserId == null) rethrow;
      final res = await _client.post(path);
      return (res as Map).cast<String, dynamic>();
    }
  }

  Future<Map<String, dynamic>> dislikeAd({
    required String adId,
    String? userId,
  }) async {
    final normalizedAdId = adId.trim();
    final normalizedUserId = userId?.trim();
    if (normalizedAdId.isEmpty) {
      throw ArgumentError('adId cannot be empty');
    }
    if (normalizedUserId != null && normalizedUserId.isEmpty) {
      throw ArgumentError('userId cannot be empty when provided');
    }
    final path = '$_basePath/ads/$normalizedAdId/dislike';
    try {
      final body = normalizedUserId == null
          ? null
          : <String, dynamic>{
              'user': {'id': normalizedUserId},
            };
      final res = await _client.post(path, body: body);
      return (res as Map).cast<String, dynamic>();
    } on BadRequestException {
      if (normalizedUserId == null) rethrow;
      final res = await _client.post(path);
      return (res as Map).cast<String, dynamic>();
    }
  }

  Future<Map<String, dynamic>> saveAd(String adId) async {
    final normalizedAdId = adId.trim();
    if (normalizedAdId.isEmpty) {
      throw ArgumentError('adId cannot be empty');
    }
    final res = await _client.post('$_basePath/ads/$normalizedAdId/save');
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> unsaveAd(String adId) async {
    final normalizedAdId = adId.trim();
    if (normalizedAdId.isEmpty) {
      throw ArgumentError('adId cannot be empty');
    }
    final res = await _client.post('$_basePath/ads/$normalizedAdId/unsave');
    return (res as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getAdComments(String adId) async {
    final normalizedAdId = adId.trim();
    if (normalizedAdId.isEmpty) {
      throw ArgumentError('adId cannot be empty');
    }

    final res = await _client.get('$_basePath/ads/$normalizedAdId/comments');

    List<dynamic> rawList = const <dynamic>[];
    if (res is List) {
      rawList = res;
    } else if (res is Map<String, dynamic>) {
      if (res['comments'] is List) {
        rawList = res['comments'] as List;
      } else if (res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res['data'] is Map &&
          (res['data'] as Map)['comments'] is List) {
        rawList = (res['data'] as Map)['comments'] as List;
      }
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> addAdComment({
    required String adId,
    required String text,
    String? parentId,
  }) async {
    final normalizedAdId = adId.trim();
    final normalizedText = text.trim();
    final normalizedParentId = parentId?.trim();

    if (normalizedAdId.isEmpty) {
      throw ArgumentError('adId cannot be empty');
    }
    if (normalizedText.isEmpty) {
      throw ArgumentError('text cannot be empty');
    }

    final body = <String, dynamic>{
      'text': normalizedText,
    };
    if (normalizedParentId != null && normalizedParentId.isNotEmpty) {
      body['parent_id'] = normalizedParentId;
    }

    final res = await _client.post('$_basePath/ads/$normalizedAdId/comments',
        body: body);
    return (res as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getAdCommentReplies(
      String commentId) async {
    final normalizedCommentId = commentId.trim();
    if (normalizedCommentId.isEmpty) {
      throw ArgumentError('commentId cannot be empty');
    }

    final res = await _client
        .get('$_basePath/ads/comments/$normalizedCommentId/replies');

    List<dynamic> rawList = const <dynamic>[];
    if (res is List) {
      rawList = res;
    } else if (res is Map<String, dynamic>) {
      if (res['replies'] is List) {
        rawList = res['replies'] as List;
      } else if (res['data'] is List) {
        rawList = res['data'] as List;
      } else if (res['data'] is Map &&
          (res['data'] as Map)['replies'] is List) {
        rawList = (res['data'] as Map)['replies'] as List;
      }
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<bool> deleteAdComment(String commentId) async {
    final normalizedCommentId = commentId.trim();
    if (normalizedCommentId.isEmpty) {
      throw ArgumentError('commentId cannot be empty');
    }

    final res =
        await _client.delete('$_basePath/ads/comments/$normalizedCommentId');
    if (res is Map<String, dynamic>) {
      final ok = res['success'];
      if (ok is bool) return ok;
    }
    return true;
  }

  Future<Map<String, dynamic>> toggleAdCommentLike(String commentId) async {
    final normalizedCommentId = commentId.trim();
    if (normalizedCommentId.isEmpty) {
      throw ArgumentError('commentId cannot be empty');
    }
    final res =
        await _client.post('$_basePath/ads/comments/$normalizedCommentId/like');
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> toggleAdCommentDislike(String commentId) async {
    final normalizedCommentId = commentId.trim();
    if (normalizedCommentId.isEmpty) {
      throw ArgumentError('commentId cannot be empty');
    }
    final res = await _client
        .post('$_basePath/ads/comments/$normalizedCommentId/dislike');
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> adminUpdateAdStatus({
    required String adId,
    required String status,
    String? rejectionReason,
  }) async {
    final normalizedAdId = adId.trim();
    final normalizedStatus = status.trim();
    final normalizedReason = rejectionReason?.trim();
    if (normalizedAdId.isEmpty) {
      throw ArgumentError('adId cannot be empty');
    }
    if (normalizedStatus.isEmpty) {
      throw ArgumentError('status cannot be empty');
    }

    final body = <String, dynamic>{'status': normalizedStatus};
    if (normalizedReason != null && normalizedReason.isNotEmpty) {
      body['rejection_reason'] = normalizedReason;
    }

    final res =
        await _client.patch('$_basePath/admin/ads/$normalizedAdId', body: body);
    return (res as Map).cast<String, dynamic>();
  }

  Future<bool> adminDeleteAd(String adId) async {
    final normalizedAdId = adId.trim();
    if (normalizedAdId.isEmpty) {
      throw ArgumentError('adId cannot be empty');
    }
    final res = await _client.delete('$_basePath/admin/ads/$normalizedAdId');
    if (res is Map<String, dynamic>) {
      final ok = res['success'];
      if (ok is bool) return ok;
    }
    return true;
  }

  Future<Map<String, dynamic>> createAd(Map<String, dynamic> payload) async {
    final res = await _client.post('$_basePath/ads', body: payload);
    return (res as Map).cast<String, dynamic>();
  }
}
