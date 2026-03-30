import '../config/api_config.dart';
import 'api_client.dart';

class SearchApi {
  static final SearchApi _instance = SearchApi._internal();
  factory SearchApi() => _instance;
  SearchApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  Future<Map<String, dynamic>> search({
    required String query,
    int limit = 10,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return const <String, dynamic>{};
    final res = await _client.get(
      '$_basePath/search',
      queryParams: {
        'q': q,
        'limit': limit.toString(),
      },
    );
    if (res is Map<String, dynamic>) return res;
    return const <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> getHistory(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return const [];
    final res = await _client.get('$_basePath/search/history/$uid');
    if (res is List) {
      return res.map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{'text': e.toString()};
      }).toList();
    }
    if (res is Map<String, dynamic>) {
      final list = (res['history'] as List?) ?? (res['data'] as List?) ?? const [];
      return list.map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{'text': e.toString()};
      }).toList();
    }
    return const [];
  }

  Future<void> clearHistory(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return;
    await _client.delete('$_basePath/search/history/$uid');
  }

  Future<void> deleteHistoryItem(String userId, String historyId) async {
    final uid = userId.trim();
    final hid = historyId.trim();
    if (uid.isEmpty || hid.isEmpty) return;
    await _client.delete('$_basePath/search/history/$uid/$hid');
  }
}
