import 'api_client.dart';

/// REST API wrapper for `/users` endpoints.
///
/// Endpoints:
///   GET    /users/:id  – Get user profile with posts (public)
///   PUT    /users/:id  – Update user profile (protected)
///   DELETE /users/:id  – Delete user and their posts (protected)
class UsersApi {
  static final UsersApi _instance = UsersApi._internal();
  factory UsersApi() => _instance;
  UsersApi._internal();

  final ApiClient _client = ApiClient();

  /// Get a user's profile along with their posts.
  ///
  /// Returns `{ user: {...}, posts: [...] }`.
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final res = await _client.get('/users/$userId');
    return res as Map<String, dynamic>;
  }

  /// Update the authenticated user's profile.
  ///
  /// Accepts optional fields: `full_name`, `bio`, `avatar_url`, `phone`, `username`.
  /// Returns the updated user object.
  Future<Map<String, dynamic>> updateUser(
    String userId, {
    String? fullName,
    String? bio,
    String? avatarUrl,
    String? phone,
    String? username,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (phone != null) body['phone'] = phone;
    if (username != null) body['username'] = username;

    final res = await _client.put('/users/$userId', body: body);
    return res as Map<String, dynamic>;
  }

  /// Delete a user and all their posts.
  ///
  /// Returns `{ message: "User deleted successfully" }`.
  Future<Map<String, dynamic>> deleteUser(String userId) async {
    final res = await _client.delete('/users/$userId');
    return res as Map<String, dynamic>;
  }

  /// Search users by query string.
  ///
  /// Returns a list of users matching the query.
  Future<List<Map<String, dynamic>>> search(String query) async {
    // Note: The React app uses GET /users and filters client-side if a query is present.
    // However, if the backend supports /users/search, we should use it.
    // If /users/search is not implemented or returns 404, we might need to fallback to /users.
    // Based on the React code: 
    // const { data } = await api.get('https://bsmart.asynk.store/api/users');
    // It fetches ALL users and filters them in the frontend.
    // Let's replicate that behavior here to ensure consistency if the search endpoint is missing.
    
    final res = await _client.get('/users');
    
    List<dynamic> list = [];
    if (res is Map<String, dynamic>) {
      list = (res['users'] as List<dynamic>?) ?? (res['data'] as List<dynamic>?) ?? [];
    } else if (res is List) {
      list = res;
    }

    // React app structure: items might be { user: {...} } or just {...}
    final users = list.map((item) {
      if (item is Map<String, dynamic> && item.containsKey('user')) {
        return item['user'] as Map<String, dynamic>;
      }
      return item as Map<String, dynamic>;
    }).toList();

    if (query.trim().isEmpty) {
      return users;
    }

    final q = query.trim().toLowerCase();
    return users.where((u) {
      final username = (u['username'] as String?)?.toLowerCase() ?? '';
      final fullName = (u['full_name'] as String?)?.toLowerCase() ?? '';
      return username.contains(q) || fullName.contains(q);
    }).toList();
  }
}
