import 'api_client.dart';

class BugReportsApi {
  static final BugReportsApi _instance = BugReportsApi._internal();
  factory BugReportsApi() => _instance;
  BugReportsApi._internal();

  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> submitBugReport({
    required String category,
    required String description,
    List<Map<String, dynamic>> attachments = const <Map<String, dynamic>>[],
    required String appVersion,
    required String osType,
    required String osVersion,
    required String deviceModel,
    required String networkType,
  }) async {
    final body = <String, dynamic>{
      'category': category.trim(),
      'description': description.trim(),
      'attachments': attachments,
      'app_version': appVersion.trim(),
      'os_type': osType.trim(),
      'os_version': osVersion.trim(),
      'device_model': deviceModel.trim(),
      'network_type': networkType.trim(),
    };
    final res = await _client.post('/bug-reports', body: body);
    if (res is Map<String, dynamic>) {
      final data = res['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return res;
    }
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getMyBugReports({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    final normalizedStatus = status?.trim().toLowerCase();
    if (normalizedStatus != null && normalizedStatus.isNotEmpty) {
      queryParams['status'] = normalizedStatus;
    }

    final res = await _client.get(
      '/bug-reports/my',
      queryParams: queryParams,
    );
    if (res is Map<String, dynamic>) {
      final reports = res['reports'] ?? res['items'] ?? res['data'];
      if (reports is List) {
        return reports
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }
}
