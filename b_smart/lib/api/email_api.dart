import 'api_client.dart';

/// REST API wrapper for `/email` endpoints (OTP + password reset).
///
/// Mirrors the React web app usage:
/// - POST /email/send-otp       { email, purpose }
/// - POST /email/verify-otp     { email, otp, purpose }
/// - POST /email/forgot-password { email }
/// - POST /email/reset-password { token, newPassword }
class EmailApi {
  static final EmailApi _instance = EmailApi._internal();
  factory EmailApi() => _instance;
  EmailApi._internal();

  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> sendOtp({
    required String email,
    required String purpose,
  }) async {
    final res = await _client.post(
      '/email/send-otp',
      body: {
        'email': email,
        'purpose': purpose,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
    required String purpose,
  }) async {
    final res = await _client.post(
      '/email/verify-otp',
      body: {
        'email': email,
        'otp': otp,
        'purpose': purpose,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    final res = await _client.post(
      '/email/forgot-password',
      body: {'email': email},
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final res = await _client.post(
      '/email/reset-password',
      body: {
        'token': token,
        'newPassword': newPassword,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }
}

