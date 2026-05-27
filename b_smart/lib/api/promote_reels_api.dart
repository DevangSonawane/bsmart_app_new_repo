import 'api_client.dart';
import '../config/api_config.dart';

/// REST API wrapper for PromoteReels endpoints.
///
/// Endpoints (from `assets/promote.md`):
///   POST   /promote-reels
///   GET    /promote-reels
///   GET    /promote-reels/:id
///   PATCH  /promote-reels/:id
///   DELETE /promote-reels/:id
///   POST   /promote-reels/:id/like
///   POST   /promote-reels/:id/unlike
///   GET    /promote-reels/:id/likes
///   POST   /promote-reels/:promoteReelId/comments
///   GET    /promote-reels/:promoteReelId/comments
///   DELETE /promote-reels/comments/:id
///   GET    /promote-reels/comments/:commentId/replies
///   DELETE /promote-reels/comments/:commentId/replies/:replyId
///   POST   /promote-reels/comments/:commentId/like
///   POST   /promote-reels/comments/:commentId/unlike
///
/// Search endpoint (React Promote.jsx):
///   GET /search/promote-reels?q=...&page=1&limit=20
class PromoteReelsApi {
  static final PromoteReelsApi _instance = PromoteReelsApi._internal();
  factory PromoteReelsApi() => _instance;
  PromoteReelsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  Future<dynamic> listPromoteReels({int page = 1, int limit = 20}) async {
    final res = await _client.get('$_basePath/promote-reels', queryParams: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    return res;
  }

  Future<dynamic> searchPromoteReels({
    required String q,
    int page = 1,
    int limit = 10,
  }) async {
    final query = q.trim();
    if (query.isEmpty) return const [];
    final res = await _client.get('$_basePath/search/promote-reels', queryParams: {
      'q': query,
      'page': page.toString(),
      'limit': limit.toString(),
    });
    return res;
  }

  Future<Map<String, dynamic>> getPromoteReelById(String id) async {
    final res = await _client.get('$_basePath/promote-reels/$id');
    return _asMap(res);
  }

  Future<Map<String, dynamic>> createPromoteReel(
      Map<String, dynamic> payload) async {
    final res =
        await _client.post('$_basePath/promote-reels', body: payload);
    return _asMap(res);
  }

  Future<Map<String, dynamic>> updatePromoteReel(
      String id, Map<String, dynamic> payload) async {
    final res =
        await _client.patch('$_basePath/promote-reels/$id', body: payload);
    return _asMap(res);
  }

  Future<Map<String, dynamic>> deletePromoteReel(String id) async {
    final res = await _client.delete('$_basePath/promote-reels/$id');
    return _asMap(res);
  }

  Future<Map<String, dynamic>> likePromoteReel(String id) async {
    final res = await _client.post('$_basePath/promote-reels/$id/like');
    return _normalizeLikeResponse(res);
  }

  Future<Map<String, dynamic>> unlikePromoteReel(String id) async {
    final res = await _client.post('$_basePath/promote-reels/$id/unlike');
    return _normalizeLikeResponse(res);
  }

  Future<dynamic> getPromoteReelLikes(String id) async {
    final res = await _client.get('$_basePath/promote-reels/$id/likes');
    return res;
  }

  Future<dynamic> getComments(String promoteReelId) async {
    final res =
        await _client.get('$_basePath/promote-reels/$promoteReelId/comments');
    return res;
  }

  Future<Map<String, dynamic>> addComment(
    String promoteReelId, {
    required String text,
    String? parentId,
  }) async {
    final body = <String, dynamic>{'text': text};
    if (parentId != null && parentId.trim().isNotEmpty) {
      body['parent_id'] = parentId.trim();
    }
    final res = await _client.post(
      '$_basePath/promote-reels/$promoteReelId/comments',
      body: body,
    );
    return _asMap(res);
  }

  Future<Map<String, dynamic>> deleteComment(String commentId) async {
    final res =
        await _client.delete('$_basePath/promote-reels/comments/$commentId');
    return _asMap(res);
  }

  Future<dynamic> getReplies(String commentId) async {
    final res = await _client
        .get('$_basePath/promote-reels/comments/$commentId/replies');
    return res;
  }

  Future<Map<String, dynamic>> deleteReply(
      String commentId, String replyId) async {
    final res = await _client.delete(
      '$_basePath/promote-reels/comments/$commentId/replies/$replyId',
    );
    return _asMap(res);
  }

  Future<Map<String, dynamic>> likeComment(String commentId) async {
    final res = await _client
        .post('$_basePath/promote-reels/comments/$commentId/like');
    return _normalizeLikeResponse(res);
  }

  Future<Map<String, dynamic>> unlikeComment(String commentId) async {
    final res = await _client
        .post('$_basePath/promote-reels/comments/$commentId/unlike');
    return _normalizeLikeResponse(res);
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _normalizeLikeResponse(dynamic res) {
    var map = _asMap(res);
    final nested = map['data'] ?? map['result'] ?? map['payload'];
    if (nested is Map) {
      map = <String, dynamic>{...map, ...Map<String, dynamic>.from(nested)};
    }

    bool? readBool(List<String> keys) {
      for (final k in keys) {
        if (!map.containsKey(k)) continue;
        final v = map[k];
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final s = v.trim().toLowerCase();
          if (s == 'true' || s == '1') return true;
          if (s == 'false' || s == '0') return false;
        }
      }
      return null;
    }

    int? readInt(List<String> keys) {
      for (final k in keys) {
        if (!map.containsKey(k)) continue;
        final v = map[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v);
      }
      return null;
    }

    final liked = readBool(const [
      'liked',
      'is_liked',
      'isLiked',
      'liked_by_me',
      'is_liked_by_me',
    ]);
    final likesCount = readInt(const [
      'likes_count',
      'likesCount',
      'like_count',
      'likeCount',
    ]);

    final out = <String, dynamic>{...map};
    if (liked != null) out['liked'] = liked;
    if (likesCount != null) out['likes_count'] = likesCount;
    return out;
  }
}
