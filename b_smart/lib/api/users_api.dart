import 'api_client.dart';
import 'api_exceptions.dart';
import 'search_api.dart';

/// Result wrapper for username/email/phone availability checks.
class AvailabilityCheckResult {
  final bool available;
  final String message;
  final int? statusCode;

  const AvailabilityCheckResult({
    required this.available,
    required this.message,
    this.statusCode,
  });
}

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

  Future<AvailabilityCheckResult> _checkAvailability({
    required String path,
    required String fieldName,
    required String value,
  }) async {
    try {
      final res = await _client.post(
        path,
        body: <String, dynamic>{fieldName: value.trim()},
      );
      final data = res is Map<String, dynamic>
          ? res
          : <String, dynamic>{'available': true, 'message': 'Available'};
      return AvailabilityCheckResult(
        available: data['available'] == true,
        message: (data['message'] ?? 'Available').toString(),
        statusCode: 200,
      );
    } on ApiException catch (e) {
      final body = e.body;
      final available = body?['available'] == true;
      final message = (body?['message'] ?? e.message).toString();
      return AvailabilityCheckResult(
        available: available,
        message: message,
        statusCode: e.statusCode,
      );
    }
  }

  /// Get a user's profile along with their posts.
  ///
  /// Returns `{ user: {...}, posts: [...] }`.
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final res = await _client.get('/users/$userId');
    return res as Map<String, dynamic>;
  }

  /// Get a user's posts.
  ///
  /// Returns a list of posts or an object containing `posts`.
  Future<List<Map<String, dynamic>>> getUserPosts(String userId) async {
    final res = await _client.get('/users/$userId/posts');
    List<dynamic> raw = [];
    if (res is Map<String, dynamic>) {
      final posts =
          res['posts'] ?? res['data'] ?? res['items'] ?? res['userPosts'];
      if (posts is List) raw = posts;
    } else if (res is List) {
      raw = res;
    }
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
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
    bool? twoFAEnabled,
    Map<String, dynamic>? extra,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (phone != null) body['phone'] = phone;
    if (username != null) body['username'] = username;
    if (twoFAEnabled != null) {
      body['twoFA'] = {'enabled': twoFAEnabled};
    }
    if (extra != null && extra.isNotEmpty) {
      body.addAll(extra);
    }

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

  /// Check whether an email is available for a new account.
  Future<AvailabilityCheckResult> checkEmailAvailability(String email) {
    return _checkAvailability(
      path: '/users/check/email',
      fieldName: 'email',
      value: email,
    );
  }

  /// Check whether a username is available for a new account.
  Future<AvailabilityCheckResult> checkUsernameAvailability(String username) {
    return _checkAvailability(
      path: '/users/check/username',
      fieldName: 'username',
      value: username,
    );
  }

  /// Check whether a phone number is available for a new account.
  Future<AvailabilityCheckResult> checkPhoneAvailability(String phone) {
    return _checkAvailability(
      path: '/users/check/phone',
      fieldName: 'phone',
      value: phone,
    );
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
      list = (res['users'] as List<dynamic>?) ??
          (res['data'] as List<dynamic>?) ??
          [];
    } else if (res is List) {
      list = res;
    }

    // React app structure: items might be { user: {...} } or just {...}
    final users = list.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      final embedded = map['user'];
      if (embedded is Map) {
        return Map<String, dynamic>.from(embedded);
      }
      return map;
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

  /// Find a user by email by scanning the public users list.
  ///
  /// The React forgot-password flow first checks whether the email belongs to
  /// an account before requesting a reset email. We mirror that behavior here.
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    final res = await SearchApi().search(query: normalized, limit: 20);
    final results = res['results'];
    if (results is! Map) return null;
    final usersRaw = results['users'];
    if (usersRaw is! List) return null;

    for (final item in usersRaw) {
      if (item is! Map) continue;
      final user = Map<String, dynamic>.from(item);
      final embedded = user['user'];
      final candidate = embedded is Map
          ? Map<String, dynamic>.from(embedded)
          : user;
      final userEmail = (candidate['email'] as String?)?.trim().toLowerCase();
      if (userEmail == normalized) {
        return candidate;
      }
    }

    return null;
  }

  /// Get user's ad interest categories for profile.
  ///
  /// Endpoint: GET /users/:id/interests
  /// Response shape (React parity):
  ///   { ad_interests: [...], available_categories: [...] }
  Future<Map<String, dynamic>> getAdInterests(String userId) async {
    final res = await _client.get('/users/$userId/interests');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  /// Add/update ad interest categories for logged-in user.
  ///
  /// Endpoint: POST /users/:id/interests
  /// Body:
  ///   { interests?: [...], add?: [...], remove?: [...] }
  Future<Map<String, dynamic>> updateAdInterests(
    String userId, {
    List<String>? interests,
    List<String>? add,
    List<String>? remove,
  }) async {
    final body = <String, dynamic>{};
    if (interests != null) body['interests'] = interests;
    if (add != null) body['add'] = add;
    if (remove != null) body['remove'] = remove;
    final res = await _client.post('/users/$userId/interests', body: body);
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }
}
