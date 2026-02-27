import 'api_client.dart';
import '../config/api_config.dart';

/// REST API wrapper for `/posts` endpoints.
///
/// Endpoints:
///   POST   /posts          – Create a post (protected)
///   GET    /posts/feed     – Get paginated feed (protected)
///   GET    /posts/:id      – Get single post (protected)
///   DELETE /posts/:id      – Delete a post (protected)
///   POST   /posts/:id/like   – Like a post (protected)
///   POST   /posts/:id/unlike – Unlike a post (protected)
///   GET    /posts/:id/likes  – Get users who liked a post (protected)
class PostsApi {
  static final PostsApi _instance = PostsApi._internal();
  factory PostsApi() => _instance;
  PostsApi._internal();

  final ApiClient _client = ApiClient();
  String get _basePath {
    final base = ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  /// Create a new post.
  ///
  /// [media] is a list of media items: `{ fileName, ratio, filter, type }`.
  /// Returns the created Post object.
  Future<Map<String, dynamic>> createPost({
    required List<Map<String, dynamic>> media,
    String? caption,
    String? location,
    List<String>? tags,
    bool? hideLikesCount,
    bool? turnOffCommenting,
    List<Map<String, dynamic>>? peopleTags,
    String type = 'post', // post | reel | promote | advertise
  }) async {
    final body = <String, dynamic>{
      'media': media,
    };
    if (caption != null) body['caption'] = caption;
    if (location != null) body['location'] = location;
    if (tags != null && tags.isNotEmpty) body['tags'] = tags;
    if (hideLikesCount != null) body['hide_likes_count'] = hideLikesCount;
    if (turnOffCommenting != null) body['turn_off_commenting'] = turnOffCommenting;
    if (peopleTags != null && peopleTags.isNotEmpty) body['people_tags'] = peopleTags;
    if (type != 'post') body['type'] = type;

    final res = await _client.post('$_basePath/posts', body: body);
    return res as Map<String, dynamic>;
  }

  /// Get the paginated feed.
  Future<dynamic> getFeed({int page = 1, int limit = 20}) async {
    final res = await _client.get('$_basePath/posts/feed', queryParams: {
      'page': page.toString(),
      'limit': limit.toString(),
    });
    return res;
  }

  /// Get a single post by ID.
  Future<Map<String, dynamic>> getPost(String postId) async {
    final res = await _client.get('$_basePath/posts/$postId');
    return res as Map<String, dynamic>;
  }

  /// Delete a post.
  Future<Map<String, dynamic>> deletePost(String postId) async {
    final res = await _client.delete('$_basePath/posts/$postId');
    return res as Map<String, dynamic>;
  }

  /// Like a post.
  ///
  /// Returns `{ message, likes_count, liked: true }`.
  Future<Map<String, dynamic>> likePost(String postId) async {
    final res = await _client.post('$_basePath/posts/$postId/like');
    return res as Map<String, dynamic>;
  }

  /// Unlike a post.
  ///
  /// Returns `{ message, likes_count, liked: false }`.
  Future<Map<String, dynamic>> unlikePost(String postId) async {
    final res = await _client.post('$_basePath/posts/$postId/unlike');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> savePost(String postId) async {
    final res = await _client.post('$_basePath/posts/$postId/save');
    return res as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unsavePost(String postId) async {
    final res = await _client.post('$_basePath/posts/$postId/unsave');
    return res as Map<String, dynamic>;
  }

  /// Get users who liked a post.
  ///
  /// Returns `{ total, users: [...] }`.
  Future<Map<String, dynamic>> getLikes(String postId) async {
    final res = await _client.get('$_basePath/posts/$postId/likes');
    return res as Map<String, dynamic>;
  }
}
