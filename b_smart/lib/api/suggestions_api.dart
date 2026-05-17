import '../config/api_config.dart';
import 'api_client.dart';

/// REST API wrapper for suggestions endpoints.
///
/// React web app calls:
/// - GET `/api/suggestions/users?limit=10`
/// - GET `/api/suggestions/reels?limit=10`
/// - GET `/api/suggestions/ads?limit=10`
/// - GET `/api/suggestions?limit=10` (combined)
class SuggestionsApi {
  static final SuggestionsApi _instance = SuggestionsApi._internal();
  factory SuggestionsApi() => _instance;
  SuggestionsApi._internal();

  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  List<Map<String, dynamic>> _extractList(dynamic res) {
    dynamic list = res;
    if (res is Map) {
      final map = Map<String, dynamic>.from(res);
      for (final key in const [
        'data',
        'users',
        'suggestions',
        'results',
        'items',
        'ads',
        'reels',
        'vendors',
      ]) {
        if (map[key] is List) {
          list = map[key];
          break;
        }
        if (map[key] is Map) {
          final nested = Map<String, dynamic>.from(map[key]);
          for (final nestedKey in const [
            'data',
            'items',
            'results',
            'users',
            'ads',
            'reels',
            'vendors',
          ]) {
            if (nested[nestedKey] is List) {
              list = nested[nestedKey];
              break;
            }
          }
        }
        if (list is List) break;
      }
    }

    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> getCombined({int limit = 10}) async {
    final res = await _client.get(
      '$_basePath/suggestions',
      queryParams: <String, String>{'limit': '$limit'},
    );
    if (res is Map) return Map<String, dynamic>.from(res);
    return <String, dynamic>{'data': res};
  }

  Future<List<Map<String, dynamic>>> getUserSuggestions(
      {int limit = 10}) async {
    final res = await _client.get(
      '$_basePath/suggestions/users',
      queryParams: <String, String>{'limit': '$limit'},
    );
    return _extractList(res);
  }

  Future<List<Map<String, dynamic>>> getReelSuggestions(
      {int limit = 10}) async {
    final res = await _client.get(
      '$_basePath/suggestions/reels',
      queryParams: <String, String>{'limit': '$limit'},
    );
    return _extractList(res);
  }

  Future<List<Map<String, dynamic>>> getAdSuggestions({int limit = 10}) async {
    final res = await _client.get(
      '$_basePath/suggestions/ads',
      queryParams: <String, String>{'limit': '$limit'},
    );
    return _extractList(res);
  }

  Future<List<Map<String, dynamic>>> getVendorSuggestions(
      {int limit = 10}) async {
    final res = await _client.get(
      '$_basePath/suggestions/vendors',
      queryParams: <String, String>{'limit': '$limit'},
    );
    return _extractList(res);
  }
}
