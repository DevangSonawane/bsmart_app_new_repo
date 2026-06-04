import 'api_client.dart';
import '../config/api_config.dart';
import 'upload_api.dart';

class StoriesApi {
  final ApiClient _client = ApiClient();

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  String _path(String suffix) => '$_basePath$suffix';

  /// GET /api/stories/user/{userId}
  /// Returns a list of Story documents (not items). Used by highlights picker.
  Future<List<Map<String, dynamic>>> userStories(String userId) async {
    final res = await _client.get(_path('/stories/user/$userId'));
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (res is Map) {
      final dynamic list = res['stories'] ?? res['data'] ?? res['items'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> upload(List<int> bytes) async {
    return UploadApi().uploadStoryBytes(
      bytes: bytes,
      filename: 'story_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    return UploadApi().uploadStoryFile(filePath);
  }

  Future<Map<String, dynamic>> create(
      List<Map<String, dynamic>> itemsPayload) async {
    final body = {'items': itemsPayload};
    final res = await _client.post(
      _path('/stories'),
      body: body,
    );
    return (res as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> createFlexible(
      List<Map<String, dynamic>> itemsPayload) async {
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
    if (res is List) return List<Map<String, dynamic>>.from(res);
    if (res is Map && res['stories'] is List) {
      return List<Map<String, dynamic>>.from(res['stories'] as List);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> items(String storyId) async {
    final res = await _client.get(_path('/stories/$storyId/items'));
    if (res is List) return List<Map<String, dynamic>>.from(res);
    if (res is Map && res['items'] is List) {
      return List<Map<String, dynamic>>.from(res['items'] as List);
    }
    return const <Map<String, dynamic>>[];
  }

  Future<void> viewItem(String itemId) async {
    await _client.post(_path('/stories/items/$itemId/view'));
  }

  /// GET /api/stories/items/{itemId}/views
  /// Returns the owner-only viewers summary for a single story item.
  Future<Map<String, dynamic>> viewSummary(String itemId) async {
    final res = await _client.get(_path('/stories/items/$itemId/views'));
    if (res is Map) {
      return res.cast<String, dynamic>();
    }
    if (res is List) {
      return <String, dynamic>{'viewers': res};
    }
    return const <String, dynamic>{};
  }

  /// Compatibility helper that returns only the viewer list for a story item.
  Future<List<Map<String, dynamic>>> viewers(String itemId) async {
    final summary = await viewSummary(itemId);
    final dynamic list = summary['viewers'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> archive() async {
    final res = await _client.get(_path('/stories/archive'));
    if (res is Map && res['stories'] is List) {
      return List<Map<String, dynamic>>.from(res['stories'] as List);
    }
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> delete(String storyId) async {
    await _client.delete(_path('/stories/$storyId'));
  }

  Future<Map<String, dynamic>> deleteItem(String itemId) async {
    final res = await _client.delete(_path('/stories/items/$itemId'));
    if (res is Map) {
      return res.cast<String, dynamic>();
    }
    return const <String, dynamic>{};
  }
}
