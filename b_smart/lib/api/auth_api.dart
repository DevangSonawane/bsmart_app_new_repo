import 'api_client.dart';

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
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'username': username,
      'role': role,
    };
    if (fullName != null) body['full_name'] = fullName;
    if (phone != null) body['phone'] = phone;

    final res = await _client.post('/auth/register', body: body);
    final data = res as Map<String, dynamic>;

    // Persist the token automatically.
    final token = data['token'] as String?;
    if (token != null) {
      await _client.saveToken(token);
    }
    return data;
  }

  /// Login with email & password.
  ///
  /// Returns `{ token: String, user: Map }`.
  /// Throws [BadRequestException] if credentials are invalid.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    final data = res as Map<String, dynamic>;

    final token = data['token'] as String?;
    if (token != null) {
      await _client.saveToken(token);
    }
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

  /// Logout – clears the stored token.
  Future<void> logout() async {
    await _client.clearToken();
  }

  /// Save a token obtained externally (e.g. Google OAuth redirect).
  Future<void> saveExternalToken(String token) async {
    await _client.saveToken(token);
  }
}
