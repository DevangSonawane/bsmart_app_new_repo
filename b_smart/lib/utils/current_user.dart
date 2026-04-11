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

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    return s.isEmpty ? null : s;
  }

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
        final userId = _asString(payload['user_id']) ??
            _asString(payload['userId']) ??
            _asString(payload['id']) ??
            _asString(payload['_id']) ??
            _asString(payload['sub']);
        if (userId != null) {
          _cachedId = userId;
          return userId;
        }
      } catch (_) {}
      // Fallback: ask the server who we are
      try {
        final me = await AuthApi().me();
        final userId = _asString(me['id']) ??
            _asString(me['_id']) ??
            _asString(me['user_id']) ??
            _asString(me['userId']);
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
