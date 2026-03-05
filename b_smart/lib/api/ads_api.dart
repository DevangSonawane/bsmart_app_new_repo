import '../config/api_config.dart';
import 'api_client.dart';

/// REST API wrapper for `/ads` endpoints.
///
/// Endpoints:
///   GET  /ads/categories  – fetch ad category list
///   POST /ads             – create ad
class AdsApi {
  static final AdsApi _instance = AdsApi._internal();
  factory AdsApi() => _instance;
  AdsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  Future<List<String>> getCategories() async {
    final res = await _client.get('$_basePath/ads/categories');
    if (res is Map<String, dynamic>) {
      final list = (res['categories'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      return list;
    }
    if (res is List) {
      return res.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> createAd(Map<String, dynamic> payload) async {
    final res = await _client.post('$_basePath/ads', body: payload);
    return (res as Map).cast<String, dynamic>();
  }
}

