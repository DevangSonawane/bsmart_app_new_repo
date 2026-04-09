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
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (res is Map) {
      final map = res;
      final list =
          map['data'] ?? map['followers'] ?? map['items'] ?? map['results'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// List followers of a user with pagination + search (web parity).
  ///
  /// GET /users/{id}/followers?search=&page=&limit=
  ///
  /// Expected response: { users: [...], total: <int> }
  Future<Map<String, dynamic>> getFollowersPage(
    String userId, {
    String search = '',
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _client.get(
      '/users/$userId/followers',
      queryParams: <String, String>{
        'search': search,
        'page': '$page',
        'limit': '$limit',
      },
    );
    return _toPagedUsersResponse(res, fallbackKey: 'followers');
  }

  /// List users the given user is following.
  ///
  /// GET /users/{id}/following
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final res = await _client.get('/users/$userId/following');
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (res is Map) {
      final map = res;
      final list =
          map['data'] ?? map['following'] ?? map['items'] ?? map['results'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// List users the given user is following with pagination + search (web parity).
  ///
  /// GET /users/{id}/following?search=&page=&limit=
  ///
  /// Expected response: { users: [...], total: <int> }
  Future<Map<String, dynamic>> getFollowingPage(
    String userId, {
    String search = '',
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _client.get(
      '/users/$userId/following',
      queryParams: <String, String>{
        'search': search,
        'page': '$page',
        'limit': '$limit',
      },
    );
    return _toPagedUsersResponse(res, fallbackKey: 'following');
  }

  /// Check follow status for a single user (web parity).
  ///
  /// GET /follows/check/{userId}
  Future<Map<String, dynamic>> checkFollowStatus(String userId) async {
    final res = await _client.get('/follows/check/$userId');
    if (res is Map) return Map<String, dynamic>.from(res);
    return <String, dynamic>{};
  }

  /// Bulk check follow statuses (web parity).
  ///
  /// POST /follows/status/bulk { userIds: [...] }
  Future<List<Map<String, dynamic>>> bulkCheckFollowStatus(
    List<String> userIds,
  ) async {
    final res = await _client.post(
      '/follows/status/bulk',
      body: <String, dynamic>{'userIds': userIds},
    );
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (res is Map) {
      final list =
          res['data'] ?? res['users'] ?? res['results'] ?? res['items'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  /// Remove a follower (web parity).
  ///
  /// DELETE /follows/remove/{followerId}
  Future<Map<String, dynamic>> removeFollower(String followerId) async {
    final res = await _client.delete('/follows/remove/$followerId');
    if (res is Map) return Map<String, dynamic>.from(res);
    return <String, dynamic>{'success': true};
  }

  /// Get follower/following counts (web parity).
  ///
  /// GET /users/{id}/follow-counts
  Future<Map<String, dynamic>> getFollowCounts(String userId) async {
    final res = await _client.get('/users/$userId/follow-counts');
    if (res is Map) return Map<String, dynamic>.from(res);
    return <String, dynamic>{};
  }

  /// Follow suggestions (used as "Vendors" tab to match web UX).
  ///
  /// GET /follows/suggestions?limit=
  Future<dynamic> getSuggestions({int limit = 10}) async {
    final res = await _client.get(
      '/follows/suggestions',
      queryParams: <String, String>{'limit': '$limit'},
    );
    return res;
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

  Map<String, dynamic> _toPagedUsersResponse(
    dynamic res, {
    required String fallbackKey,
  }) {
    if (res is Map) {
      final map = Map<String, dynamic>.from(res);
      final usersRaw = map['users'] ??
          map['data'] ??
          map[fallbackKey] ??
          map['items'] ??
          map['results'];
      final totalRaw = map['total'] ?? map['count'] ?? map['totalCount'];
      final users = usersRaw is List
          ? usersRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      final total = totalRaw is num ? totalRaw.toInt() : users.length;
      return <String, dynamic>{
        'users': users,
        'total': total,
      };
    }
    if (res is List) {
      final users = res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      return <String, dynamic>{'users': users, 'total': users.length};
    }
    return const <String, dynamic>{
      'users': <Map<String, dynamic>>[],
      'total': 0
    };
  }
}
