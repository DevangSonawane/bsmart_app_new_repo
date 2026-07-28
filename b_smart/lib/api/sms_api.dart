import 'api_client.dart';

/// REST API wrapper for `/sms` OTP endpoints.
///
/// Mirrors the React web app usage:
/// - POST /sms/send-otp   { phone, purpose }
/// - POST /sms/verify-otp { phone, otp, purpose }
class SmsApi {
  static final SmsApi _instance = SmsApi._internal();
  factory SmsApi() => _instance;
  SmsApi._internal();

  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> sendOtp({
    required String phone,
    required String purpose,
  }) async {
    final res = await _client.post(
      '/sms/send-otp',
      body: {
        'phone': phone,
        'purpose': purpose,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    required String purpose,
  }) async {
    final res = await _client.post(
      '/sms/verify-otp',
      body: {
        'phone': phone,
        'otp': otp,
        'purpose': purpose,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }
}
