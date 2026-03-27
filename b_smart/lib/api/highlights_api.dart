import 'api_client.dart';
import '../config/api_config.dart';

class HighlightsApi {
  final ApiClient _client = ApiClient();

  String get _basePath {
    final base = ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  String _path(String suffix) => '$_basePath$suffix';

  Future<Map<String, dynamic>> create({required String title, String? coverUrl}) async {
    final body = <String, dynamic>{'title': title.trim()};
    if (coverUrl != null && coverUrl.trim().isNotEmpty) {
      body['cover_url'] = coverUrl.trim();
    }
    final res = await _client.post(_path('/highlights'), body: body);
    return (res as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> userHighlights(String userId) async {
    final res = await _client.get(_path('/highlights/user/$userId'));
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>> userHighlightsWithStories(String userId) async {
    final res = await _client.get(_path('/highlights/user/$userId/stories'));
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> addItems(
    String highlightId,
    List<String> storyItemIds, {
    String? title,
  }) async {
    final body = <String, dynamic>{
      'story_item_ids': storyItemIds,
    };
    if (title != null && title.trim().isNotEmpty) {
      body['title'] = title.trim();
    }
    final res = await _client.post(_path('/highlights/$highlightId/items'), body: body);
    return (res as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> items(String highlightId) async {
    final res = await _client.get(_path('/highlights/$highlightId/items'));
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>> update(String highlightId, {String? title, String? coverUrl}) async {
    final body = <String, dynamic>{};
    if (title != null && title.trim().isNotEmpty) {
      body['title'] = title.trim();
    }
    if (coverUrl != null && coverUrl.trim().isNotEmpty) {
      body['cover_url'] = coverUrl.trim();
    }
    final res = await _client.patch(_path('/highlights/$highlightId'), body: body);
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> deleteItem(String highlightId, String highlightItemId) async {
    final res = await _client.delete(_path('/highlights/$highlightId/items/$highlightItemId'));
    if (res is Map) {
      return res.cast<String, dynamic>();
    }
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> delete(String highlightId) async {
    final res = await _client.delete(_path('/highlights/$highlightId'));
    if (res is Map) {
      return res.cast<String, dynamic>();
    }
    return const <String, dynamic>{};
  }
}
