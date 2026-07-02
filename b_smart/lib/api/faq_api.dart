import 'api_client.dart';

class FaqApi {
  static final FaqApi _instance = FaqApi._internal();
  factory FaqApi() => _instance;
  FaqApi._internal();

  final ApiClient _client = ApiClient();

  Future<List<Map<String, dynamic>>> getFaqs({
    String? appSource,
    String? category,
  }) async {
    final queryParams = <String, String>{};
    final normalizedSource = appSource?.trim().toLowerCase();
    final normalizedCategory = category?.trim().toLowerCase();

    if (normalizedSource != null && normalizedSource.isNotEmpty) {
      queryParams['app_source'] = normalizedSource;
    }
    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      queryParams['category'] = normalizedCategory;
    }

    final res = await _client.get(
      '/faq',
      queryParams: queryParams.isEmpty ? null : queryParams,
    );

    if (res is Map<String, dynamic>) {
      final data = res['data'] ?? res['faqs'] ?? res['items'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }

    if (res is List) {
      return res
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> getFaqById(String id) async {
    final faqId = id.trim();
    if (faqId.isEmpty) return <String, dynamic>{};

    final res = await _client.get('/faq/$faqId');
    if (res is Map<String, dynamic>) {
      final data = res['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return res;
    }

    return <String, dynamic>{};
  }
}
