import 'api_client.dart';

/// REST API wrapper for follow / followers endpoints.
///
/// Endpoints:
///   POST /follow                 – Follow a user (body: { userId })
///   POST /unfollow               – Unfollow a user (body: { userId })
///   GET  /users/{id}/followers   – List followers of a user
///   GET  /users/{id}/following   – List users the given user is following
///   GET  /followers              – Get all follower relationships
///   GET  /following              – Get all following relationships
///   POST /follows/{userId}       – Follow a user by ID (alias)
class FollowsApi {
  static final FollowsApi _instance = FollowsApi._internal();
  factory FollowsApi() => _instance;
  FollowsApi._internal();

  final ApiClient _client = ApiClient();

  /// Follow a user.
  ///
  /// Accepts either body `{ "followedUserId": "<id>" }` or path `/follows/{userId}` depending on server.
  Future<Map<String, dynamic>> follow(String userId) async {
    final res = await _client.post('/follow', body: {
      'followedUserId': userId,
    });
    return res as Map<String, dynamic>;
  }

  /// Follow a user by ID via `/follows/{userId}` alias.
  Future<Map<String, dynamic>> followById(String userId) async {
    final res = await _client.post('/follows/$userId');
    return res as Map<String, dynamic>;
  }

  /// Unfollow a user.
  Future<Map<String, dynamic>> unfollow(String userId) async {
    final res = await _client.post('/unfollow', body: {
      'followedUserId': userId,
    });
    return res as Map<String, dynamic>;
  }

  /// List followers of a user.
  ///
  /// GET /users/{id}/followers
  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final res = await _client.get('/users/$userId/followers');
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (res is Map) {
      final map = res as Map;
      final list = map['data'] ??
          map['followers'] ??
          map['items'] ??
          map['results'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// List users the given user is following.
  ///
  /// GET /users/{id}/following
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final res = await _client.get('/users/$userId/following');
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (res is Map) {
      final map = res as Map;
      final list = map['data'] ??
          map['following'] ??
          map['items'] ??
          map['results'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// Followers count for a user (non-paginated, just a number).
  ///
  /// Expected response: { "count": <int> } or { "total": <int> }.
  Future<int> getFollowersCount(String userId) async {
    final res = await _client.get('/users/$userId/followers/count');
    if (res is Map<String, dynamic>) {
      if (res['count'] is int) return res['count'] as int;
      if (res['total'] is int) return res['total'] as int;
    }
    if (res is int) return res;
    return 0;
  }

  /// Following count for a user (non-paginated, just a number).
  ///
  /// Expected response: { "count": <int> } or { "total": <int> }.
  Future<int> getFollowingCount(String userId) async {
    final res = await _client.get('/users/$userId/following/count');
    if (res is Map<String, dynamic>) {
      if (res['count'] is int) return res['count'] as int;
      if (res['total'] is int) return res['total'] as int;
    }
    if (res is int) return res;
    return 0;
  }

  /// Get all follower relationships.
  ///
  /// GET /followers
  Future<List<Map<String, dynamic>>> getAllFollowers() async {
    final res = await _client.get('/followers');
    if (res is List) {
      return res.cast<Map<String, dynamic>>();
    }
    if (res is Map && res['data'] is List) {
      return (res['data'] as List).cast<Map<String, dynamic>>();
    }
    return <Map<String, dynamic>>[];
  }

  /// Get all following relationships.
  ///
  /// GET /following
  Future<List<Map<String, dynamic>>> getAllFollowing() async {
    final res = await _client.get('/following');
    if (res is List) {
      return res.cast<Map<String, dynamic>>();
    }
    if (res is Map && res['data'] is List) {
      return (res['data'] as List).cast<Map<String, dynamic>>();
    }
    return <Map<String, dynamic>>[];
  }
}
