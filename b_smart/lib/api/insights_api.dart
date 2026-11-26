import 'api_client.dart';
import '../config/api_config.dart';

/// REST API wrapper for the Insights endpoints (see `insights-api.md`).
///
///   GET /posts/:id/stats                         – single post / reel
///   GET /promote-reels/:id/stats                 – promoted reel
///   GET /users/:id/insights                      – account-wide
///   GET /users/:id/content-performance?days=28   – period comparison
///
/// All are owner-only: requesting someone else's content returns 403.
class InsightsApi {
  static final InsightsApi _instance = InsightsApi._internal();
  factory InsightsApi() => _instance;
  InsightsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    return base.endsWith('/api') ? '' : '/api';
  }

  Future<Map<String, dynamic>> getPostStats(String postId) async {
    final res = await _client.get('$_basePath/posts/$postId/stats');
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> getPromoteReelStats(String id) async {
    final res = await _client.get('$_basePath/promote-reels/$id/stats');
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> getUserInsights(String userId) async {
    final res = await _client.get('$_basePath/users/$userId/insights');
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> getContentPerformance(
    String userId, {
    int days = 28,
  }) async {
    final clamped = days.clamp(7, 90);
    final res = await _client.get(
      '$_basePath/users/$userId/content-performance',
      queryParams: {'days': clamped.toString()},
    );
    return _unwrap(res);
  }

  /// Accepts `{...}`, `{data: {...}}`, `{stats: {...}}` or `{insights: {...}}`.
  Map<String, dynamic> _unwrap(dynamic res) {
    if (res is! Map) return const {};
    final map = Map<String, dynamic>.from(res);
    for (final key in const ['data', 'stats', 'insights', 'result']) {
      final inner = map[key];
      if (inner is Map) return Map<String, dynamic>.from(inner);
    }
    return map;
  }
}
