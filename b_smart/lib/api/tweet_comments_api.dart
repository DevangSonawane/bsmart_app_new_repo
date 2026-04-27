import 'api_client.dart';
import '../config/api_config.dart';

/// REST API wrapper for tweet comment & reply endpoints.
///
/// Endpoints (parity with React web):
///   POST   /tweets/:tweetId/comments            – Add comment or reply (protected)
///   GET    /tweets/:tweetId/comments            – Get comments (public/protected)
///   DELETE /tweets/comments/:id                 – Delete comment (protected)
///   POST   /tweets/comments/:commentId/like     – Like comment (protected)
///   POST   /tweets/comments/:commentId/unlike   – Unlike comment (protected)
///   GET    /tweets/comments/:commentId/replies  – Get replies (public/protected)
class TweetCommentsApi {
  static final TweetCommentsApi _instance = TweetCommentsApi._internal();
  factory TweetCommentsApi() => _instance;
  TweetCommentsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  Future<Map<String, dynamic>> addComment(
    String tweetId, {
    required String text,
    String? parentId,
  }) async {
    final body = <String, dynamic>{'text': text};
    if (parentId != null && parentId.isNotEmpty) body['parent_id'] = parentId;
    final res =
        await _client.post('$_basePath/tweets/$tweetId/comments', body: body);
    return res as Map<String, dynamic>;
  }

  Future<dynamic> getComments(
    String tweetId, {
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.get(
      '$_basePath/tweets/$tweetId/comments',
      queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    return res;
  }

  Future<Map<String, dynamic>> deleteComment(String commentId) async {
    final res = await _client.delete('$_basePath/tweets/comments/$commentId');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> likeComment(String commentId) async {
    final res = await _client.post('$_basePath/tweets/comments/$commentId/like');
    return _normalizeLikeResponse(res);
  }

  Future<Map<String, dynamic>> unlikeComment(String commentId) async {
    final res =
        await _client.post('$_basePath/tweets/comments/$commentId/unlike');
    return _normalizeLikeResponse(res);
  }

  Map<String, dynamic> _normalizeLikeResponse(dynamic res) {
    Map<String, dynamic> map = <String, dynamic>{};
    if (res is Map) map = Map<String, dynamic>.from(res);
    final nested =
        map['data'] ?? map['result'] ?? map['comment'] ?? map['payload'];
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
      'is_liked_by_me',
      'liked_by_me',
    ]);
    final likes = readInt(const [
      'likes_count',
      'likesCount',
      'count',
      'total',
      'totalCount',
    ]);

    return <String, dynamic>{
      ...map,
      if (liked != null) 'liked': liked,
      if (likes != null) 'likes_count': likes,
    };
  }

  Future<dynamic> getReplies(
    String commentId, {
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _client.get(
      '$_basePath/tweets/comments/$commentId/replies',
      queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    return res;
  }
}
