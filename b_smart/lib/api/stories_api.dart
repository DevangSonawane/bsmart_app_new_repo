import 'api_client.dart';
import '../config/api_config.dart';

class StoriesApi {
  final ApiClient _client = ApiClient();

  String get _basePath {
    final base = ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  String _path(String suffix) => '$_basePath$suffix';

  Future<Map<String, dynamic>> upload(List<int> bytes) async {
    final res = await _client.multipartPostBytes(
      _path('/stories/upload'),
      bytes: bytes,
      filename: 'story_${DateTime.now().millisecondsSinceEpoch}.jpg',
      fileField: 'file',
    );
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> create(List<Map<String, dynamic>> itemsPayload) async {
    final body = {'items': itemsPayload};
    final res = await _client.post(
      _path('/stories'),
      body: body,
    );
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> createFlexible(List<Map<String, dynamic>> itemsPayload) async {
    try {
      return await create(itemsPayload);
    } catch (e) {
      // Keep errors visible in console for easier debugging
      // while still surfacing the original exception to callers.
      // ignore: avoid_print
      print('Story creation failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> feed() async {
    final res = await _client.get(_path('/stories/feed'));
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> items(String storyId) async {
    final res = await _client.get(_path('/stories/$storyId/items'));
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> viewItem(String itemId) async {
    await _client.post(_path('/stories/items/$itemId/view'));
  }

  Future<List<Map<String, dynamic>>> viewers(String storyId) async {
    final res = await _client.get(_path('/stories/$storyId/views'));
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<Map<String, dynamic>>> archive() async {
    final res = await _client.get(_path('/stories/archive'));
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> delete(String storyId) async {
    await _client.delete(_path('/stories/$storyId'));
  }

  Future<void> deleteItem(String itemId) async {
    await _client.delete(_path('/stories/items/$itemId'));
  }
}
