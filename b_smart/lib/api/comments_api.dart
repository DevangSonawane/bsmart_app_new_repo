 import 'api_client.dart';
 import '../config/api_config.dart';

/// REST API wrapper for comment & reply endpoints.
///
/// Endpoints:
///   POST   /posts/:postId/comments       – Add comment or reply (protected)
///   GET    /posts/:postId/comments       – Get comments for a post (public, paginated)
///   DELETE /comments/:id                  – Delete a comment (protected)
///   POST   /comments/:commentId/like     – Like a comment (protected)
///   POST   /comments/:commentId/unlike   – Unlike a comment (protected)
///   GET    /comments/:commentId/replies  – Get replies for a comment (public, paginated)
class CommentsApi {
  static final CommentsApi _instance = CommentsApi._internal();
  factory CommentsApi() => _instance;
  CommentsApi._internal();

  final ApiClient _client = ApiClient();
  String get _basePath {
    final base = ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  /// Add a comment (or reply) to a post.
  ///
  /// Pass [parentId] to create a reply instead of a top-level comment.
  /// Returns the created Comment object.
  Future<Map<String, dynamic>> addComment(
    String postId, {
    required String text,
    String? parentId,
  }) async {
    final body = <String, dynamic>{'text': text};
    if (parentId != null) body['parent_id'] = parentId;

    final res = await _client.post('$_basePath/posts/$postId/comments', body: body);
    return res as Map<String, dynamic>;
  }

  /// Get paginated comments for a post.
  ///
  /// Returns either:
  /// - `{ page, limit, total, comments: [...] }`
  /// - `{ data: [...] }`
  /// - `[...]`
  Future<dynamic> getComments(
    String postId, {
    int page = 1,
    int limit = 10,
  }) async {
    final res = await _client.get('$_basePath/posts/$postId/comments', queryParams: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    return res;
  }

  /// Delete a comment.
  Future<Map<String, dynamic>> deleteComment(String commentId) async {
    final res = await _client.delete('$_basePath/comments/$commentId');
    return res as Map<String, dynamic>;
  }

  /// Like a comment.
  ///
  /// Returns `{ liked: true, likes_count }`.
  Future<Map<String, dynamic>> likeComment(String commentId) async {
    final res = await _client.post('$_basePath/comments/$commentId/like');
    return res as Map<String, dynamic>;
  }

  /// Unlike a comment.
  ///
  /// Returns `{ liked: false, likes_count }`.
  Future<Map<String, dynamic>> unlikeComment(String commentId) async {
    final res = await _client.post('$_basePath/comments/$commentId/unlike');
    return res as Map<String, dynamic>;
  }

  /// Get paginated replies for a comment.
  ///
  /// Returns `{ page, limit, total, replies: [...] }`.
  Future<Map<String, dynamic>> getReplies(
    String commentId, {
    int page = 1,
    int limit = 10,
  }) async {
    final res = await _client.get('$_basePath/comments/$commentId/replies', queryParams: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    return res as Map<String, dynamic>;
  }
}
