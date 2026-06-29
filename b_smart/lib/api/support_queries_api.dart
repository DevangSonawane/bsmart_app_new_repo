import 'api_client.dart';

class SupportQueriesApi {
  static final SupportQueriesApi _instance = SupportQueriesApi._internal();
  factory SupportQueriesApi() => _instance;
  SupportQueriesApi._internal();

  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> submitSupportQuery({
    required String subject,
    required String message,
    required String category,
    String appSource = 'bsmart',
  }) async {
    final body = <String, dynamic>{
      'subject': subject.trim(),
      'message': message.trim(),
      'category': category.trim(),
      'app_source': appSource.trim().isEmpty ? 'bsmart' : appSource.trim(),
    };
    final res = await _client.post('/support-queries', body: body);
    if (res is Map<String, dynamic>) {
      final query = res['query'];
      if (query is Map) return Map<String, dynamic>.from(query);
      return res;
    }
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getMySupportQueries({
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
      '/support-queries/my',
      queryParams: queryParams,
    );
    if (res is Map<String, dynamic>) {
      final queries = res['queries'] ?? res['items'] ?? res['data'];
      if (queries is List) {
        return queries
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

  Future<Map<String, dynamic>> getMySupportQuery(String id) async {
    final queryId = id.trim();
    if (queryId.isEmpty) return <String, dynamic>{};
    final res = await _client.get('/support-queries/my/$queryId');
    if (res is Map<String, dynamic>) {
      final query = res['query'];
      if (query is Map) return Map<String, dynamic>.from(query);
      return res;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> deleteMySupportQuery(String id) async {
    final queryId = id.trim();
    if (queryId.isEmpty) return <String, dynamic>{};
    final res = await _client.delete('/support-queries/my/$queryId');
    if (res is Map<String, dynamic>) {
      return res;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> replyToMySupportQuery({
    required String id,
    required String message,
  }) async {
    final queryId = id.trim();
    final body = <String, dynamic>{
      'message': message.trim(),
    };
    final res = await _client.post(
      '/support-queries/my/$queryId/reply',
      body: body,
    );
    if (res is Map<String, dynamic>) {
      return res;
    }
    return <String, dynamic>{};
  }
}
