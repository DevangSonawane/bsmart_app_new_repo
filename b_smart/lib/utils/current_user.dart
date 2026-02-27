import 'package:jwt_decoder/jwt_decoder.dart';
import '../api/api.dart';

/// Provides the current user ID (and basic info) from whichever auth
/// backend is active – REST API JWT first, then Supabase session fallback.
///
/// Usage:
/// ```dart
/// final userId = await CurrentUser.id;
/// ```
class CurrentUser {
  CurrentUser._();

  static String? _cachedId;

  /// Get the current user ID.
  ///
  /// 1. Checks for a REST API JWT and decodes `user_id` (or `id` / `sub`).
  /// 2. Falls back to calling `/auth/me` to read the user id if decoding fails.
  /// 3. Returns `null` if not authenticated.
  static Future<String?> get id async {
    if (_cachedId != null && _cachedId!.isNotEmpty) return _cachedId;
    // Try REST API JWT first
    final token = await ApiClient().getToken();
    if (token != null) {
      try {
        final payload = JwtDecoder.decode(token);
        final userId = payload['user_id'] as String? ??
            payload['id'] as String? ??
            payload['sub'] as String?;
        if (userId != null) {
          _cachedId = userId;
          return userId;
        }
      } catch (_) {}
      // Fallback: ask the server who we are
      try {
        final me = await AuthApi().me();
        final userId = me['id'] as String? ?? me['_id'] as String?;
        if (userId != null && userId.isNotEmpty) {
          _cachedId = userId;
          return userId;
        }
      } catch (_) {}
    }

    return null;
  }

  /// Whether the user is authenticated via either backend.
  static Future<bool> get isAuthenticated async {
    final uid = await id;
    return uid != null;
  }
}
