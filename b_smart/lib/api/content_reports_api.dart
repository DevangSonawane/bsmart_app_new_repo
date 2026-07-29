import '../config/api_config.dart';
import 'api_client.dart';

class ContentReportsApi {
  static final ContentReportsApi _instance = ContentReportsApi._internal();
  factory ContentReportsApi() => _instance;
  ContentReportsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  List<String> _parseReasons(dynamic res) {
    if (res is Map) {
      final reasons = res['reasons'] ?? res['data'];
      if (reasons is List) {
        return reasons
            .map((e) {
              if (e is Map) {
                return (e['reason'] ?? e['name'] ?? e['title'] ?? '')
                    .toString()
                    .trim();
              }
              return e.toString().trim();
            })
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    if (res is List) {
      return res
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Future<List<String>> getReasons() async {
    final res = await _client.get('$_basePath/content-reports/reasons');
    final reasons = _parseReasons(res);
    if (reasons.isNotEmpty) return reasons;
    return const <String>[
      "I just don't like it",
      'Bullying or unwanted contact',
      'Suicide, self-injury or eating disorders',
      'Violence, hate or exploitation',
      'Selling or promoting restricted items',
      'Nudity or sexual activity',
      'Scam, fraud or spam',
      'False information',
    ];
  }

  Future<Map<String, dynamic>> submitReport({
    required String contentType,
    required String contentId,
    required String reason,
    String? details,
  }) async {
    final payload = <String, dynamic>{
      'content_type': contentType.trim().toLowerCase(),
      'content_id': contentId.trim(),
      'reason': reason.trim(),
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
    };
    final res = await _client.post(
      '$_basePath/content-reports',
      body: payload,
    );
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return <String, dynamic>{'success': true};
  }

  Future<List<Map<String, dynamic>>> getMyReports() async {
    final res = await _client.get('$_basePath/content-reports/my');
    if (res is Map) {
      final raw = res['reports'] ?? res['data'] ?? const [];
      if (raw is List) {
        return raw
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
    return const [];
  }
}
