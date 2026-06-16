import 'api_client.dart';

/// REST API wrapper for account email/phone verification endpoints.
///
/// Mirrors the React web app:
/// - POST /settings/account/verify-email/send
/// - POST /settings/account/verify-email/confirm { otp }
/// - POST /settings/account/verify-phone/send
/// - POST /settings/account/verify-phone/confirm { otp }
class AccountVerificationApi {
  static final AccountVerificationApi _instance =
      AccountVerificationApi._internal();
  factory AccountVerificationApi() => _instance;
  AccountVerificationApi._internal();

  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> send({
    required String type,
  }) async {
    final path = type == 'phone'
        ? '/settings/account/verify-phone/send'
        : '/settings/account/verify-email/send';
    final res = await _client.post(path);
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> confirm({
    required String type,
    required String otp,
  }) async {
    final path = type == 'phone'
        ? '/settings/account/verify-phone/confirm'
        : '/settings/account/verify-email/confirm';
    final res = await _client.post(path, body: <String, dynamic>{'otp': otp});
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }
}
