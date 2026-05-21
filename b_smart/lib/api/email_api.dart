import 'api_client.dart';

/// REST API wrapper for `/email` endpoints (OTP + password reset).
///
/// Mirrors the React web app usage:
/// - POST /email/send-otp       { email, purpose }
/// - POST /email/verify-otp     { email, otp, purpose }
/// - POST /email/forgot-password { email }
/// - POST /email/reset-password { token, newPassword }
/// - POST /email/send          { to, subject, ...content }
class EmailApi {
  static final EmailApi _instance = EmailApi._internal();
  factory EmailApi() => _instance;
  EmailApi._internal();

  final ApiClient _client = ApiClient();

  /// Send an email (generic endpoint).
  ///
  /// Backend payload shape varies across implementations; we send a superset of
  /// common fields so the server can pick what it needs.
  Future<Map<String, dynamic>> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? html,
    Map<String, dynamic>? extra,
  }) async {
    final payload = <String, dynamic>{
      'to': to,
      'email': to,
      'recipient': to,
      'subject': subject,
      // Common names for the message content:
      'body': body,
      'message': body,
      'text': body,
      if (html != null && html.isNotEmpty) 'html': html,
      if (extra != null && extra.isNotEmpty) ...extra,
    };
    final res = await _client.post('/email/send', body: payload);
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

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
