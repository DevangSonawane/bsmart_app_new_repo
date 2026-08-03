import 'api_client.dart';

/// REST API wrapper for legal/data-control endpoints.
class LegalDataApi {
  static final LegalDataApi _instance = LegalDataApi._internal();
  factory LegalDataApi() => _instance;
  LegalDataApi._internal();

  final ApiClient _client = ApiClient();

  /// Export the current user's data as CSV text.
  Future<String> exportMyData() async {
    final res = await _client.get(
      '/settings/account/export',
      extraHeaders: <String, String>{
        'Accept': 'text/csv, application/json;q=0.9, */*;q=0.8',
      },
    );

    if (res is String) return res;
    return res.toString();
  }

  /// Clear the current user's content and chat data.
  Future<Map<String, dynamic>> deleteMyData() async {
    final res = await _client.delete('/settings/account/clear-content');
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return <String, dynamic>{'success': true};
  }
}
