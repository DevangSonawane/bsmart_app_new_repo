import 'api_client.dart';
import '../models/auth/apple_authentication_result.dart';

/// REST API wrapper for `/auth` endpoints.
///
/// Endpoints:
///   POST /auth/register  – Register a new user
///   POST /auth/login     – Login with email & password
///   GET  /auth/me        – Get current authenticated user (protected)
///   GET  /auth/google     – Initiate Google OAuth flow (browser redirect)
class AuthApi {
  static final AuthApi _instance = AuthApi._internal();
  factory AuthApi() => _instance;
  AuthApi._internal();

  final ApiClient _client = ApiClient();

  String? _extractToken(Map<String, dynamic> data) {
    final candidates = [
      data['token'],
      data['jwt'],
      data['access_token'],
      data['accessToken'],
      data['data'] is Map ? (data['data'] as Map)['token'] : null,
      data['data'] is Map ? (data['data'] as Map)['jwt'] : null,
      data['data'] is Map ? (data['data'] as Map)['access_token'] : null,
      data['data'] is Map ? (data['data'] as Map)['accessToken'] : null,
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Future<void> _persistTokenIfPresent(Map<String, dynamic> data) async {
    final token = _extractToken(data);
    if (token != null) {
      await _client.saveToken(token);
    }
  }

  /// Register a new user.
  ///
  /// Returns `{ token: String, user: Map }`.
  /// Throws [BadRequestException] if user already exists or role is invalid.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    String? fullName,
    String? phone,
    String role = 'member',
    String? clientTimezoneName,
    int? clientTimezoneOffsetMinutes,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'username': username,
      'role': role,
    };
    if (fullName != null) body['full_name'] = fullName;
    if (phone != null) body['phone'] = phone;
    if (clientTimezoneName != null && clientTimezoneName.trim().isNotEmpty) {
      body['client_timezone_name'] = clientTimezoneName.trim();
    }
    if (clientTimezoneOffsetMinutes != null) {
      body['client_timezone_offset_minutes'] = clientTimezoneOffsetMinutes;
    }

    final res = await _client.post('/auth/register', body: body);
    final data = res as Map<String, dynamic>;

    await _persistTokenIfPresent(data);
    return data;
  }

  /// Login with email & password.
  ///
  /// Returns `{ token: String, user: Map }`.
  /// Throws [BadRequestException] if credentials are invalid.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? otp,
    String? clientTimezoneName,
    int? clientTimezoneOffsetMinutes,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (otp != null && otp.trim().isNotEmpty) {
      body['otp'] = otp.trim();
    }
    if (clientTimezoneName != null && clientTimezoneName.trim().isNotEmpty) {
      body['client_timezone_name'] = clientTimezoneName.trim();
    }
    if (clientTimezoneOffsetMinutes != null) {
      body['client_timezone_offset_minutes'] = clientTimezoneOffsetMinutes;
    }

    final res = await _client.post('/auth/login', body: body);
    final data = res as Map<String, dynamic>;

    await _persistTokenIfPresent(data);
    return data;
  }

  /// Fetch the current authenticated user.
  ///
  /// Returns the full User object.
  /// Throws [UnauthorizedException] if not logged in.
  Future<Map<String, dynamic>> me() async {
    final res = await _client.get('/auth/me');
    return res as Map<String, dynamic>;
  }

  /// Login with Google ID token (native sign-in flow).
  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    String? clientTimezoneName,
    int? clientTimezoneOffsetMinutes,
  }) async {
    final body = <String, dynamic>{
      'id_token': idToken,
    };
    if (clientTimezoneName != null && clientTimezoneName.trim().isNotEmpty) {
      body['client_timezone_name'] = clientTimezoneName.trim();
    }
    if (clientTimezoneOffsetMinutes != null) {
      body['client_timezone_offset_minutes'] = clientTimezoneOffsetMinutes;
    }
    final res = await _client.post('/auth/google/token', body: body);
    final data = res as Map<String, dynamic>;
    await _persistTokenIfPresent(data);
    return data;
  }

  /// Logout – clears the stored token.
  Future<void> logout() async {
    await _client.clearToken();
  }

  /// Change password for the current user.
  ///
  /// Mirrors React web app call:
  /// `POST /auth/change-password { currentPassword, newPassword, user_id }`
  Future<Map<String, dynamic>> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _client.post('/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'user_id': userId,
    });
    return res as Map<String, dynamic>;
  }

  /// Save a token obtained externally (e.g. Google OAuth redirect).
  Future<void> saveExternalToken(String token) async {
    await _client.saveToken(token);
  }

  /// Exchange the native Apple identity token with the backend JWT session.
  Future<Map<String, dynamic>> completeAppleSignIn(
    AppleAuthenticationResult result,
  ) async {
    final payload = result.toBackendPayload();
    final res = await _client.post('/auth/apple/token', body: payload);
    final data = res as Map<String, dynamic>;
    await _persistTokenIfPresent(data);
    return data;
  }
}
