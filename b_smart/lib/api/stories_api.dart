import 'api_client.dart';
import 'api_exceptions.dart';
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

  void _log(String message) {
    // ignore: avoid_print
    print('[StoriesApi] $message');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _unwrapResponseMap(Map<String, dynamic> value) {
    Map<String, dynamic> current = value;
    while (true) {
      final dynamic nested =
          current['data'] ?? current['result'] ?? current['summary'];
      if (nested is Map) {
        final next = nested.cast<String, dynamic>();
        if (next.isEmpty || identical(next, current)) break;
        current = <String, dynamic>{...current, ...next};
        continue;
      }
      break;
    }
    return current;
  }

  List<Map<String, dynamic>> _extractViewerList(dynamic source) {
    if (source is List) {
      return source
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (source is Map) {
      final map = source.cast<String, dynamic>();
      for (final key in const ['viewers', 'views', 'items', 'data', 'result']) {
        final nested = map[key];
        if (nested == null) continue;
        final extracted = _extractViewerList(nested);
        if (extracted.isNotEmpty) return extracted;
      }
    }
    return const <Map<String, dynamic>>[];
  }

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

  bool isPrivacyBlockedError(Object error) {
    return error is ForbiddenException &&
        error.body?['privacy_blocked'] == true;
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

  /// POST /api/stories/items/{itemId}/like
  /// Toggles like/unlike for a story item.
  Future<Map<String, dynamic>> likeItem(String itemId) async {
    final res = await _client.post(_path('/stories/items/$itemId/like'));
    if (res is Map) {
      final map = Map<String, dynamic>.from(res);
      final nested =
          map['data'] ?? map['result'] ?? map['story'] ?? map['item'];
      if (nested is Map) {
        return <String, dynamic>{...map, ...Map<String, dynamic>.from(nested)};
      }
      return map;
    }
    return const <String, dynamic>{};
  }

  /// GET /api/stories/items/{itemId}/views
  /// Returns the owner-only viewers summary for a single story item.
  Future<Map<String, dynamic>> viewSummary(String itemId) async {
    _log('viewSummary request itemId=$itemId');
    final res = await _client.get(_path('/stories/items/$itemId/views'));
    _log('viewSummary responseType=${res.runtimeType}');
    if (res is Map) {
      final map = _unwrapResponseMap(res.cast<String, dynamic>());
      _log(
        'viewSummary keys=${map.keys.toList()} total=${map['total_views']} unique=${map['unique_viewers']} viewersType=${map['viewers']?.runtimeType}',
      );
      return map;
    }
    if (res is List) {
      _log('viewSummary listResponse length=${res.length}');
      return <String, dynamic>{'viewers': res};
    }
    _log('viewSummary empty/non-map response');
    return const <String, dynamic>{};
  }

  /// Compatibility helper that returns only the viewer list for a story item.
  Future<List<Map<String, dynamic>>> viewers(String itemId) async {
    final summary = await viewSummary(itemId);
    final data = _asMap(summary['data']);
    final result = _asMap(summary['result']);
    final meta = _asMap(summary['summary']);
    final dynamic list = summary['viewers'] ??
        summary['views'] ??
        data['viewers'] ??
        data['views'] ??
        result['viewers'] ??
        result['views'] ??
        meta['viewers'] ??
        meta['views'];
    final viewers = _extractViewerList(list);
    _log(
      'viewers parsed itemId=$itemId count=${viewers.length} listType=${list.runtimeType} summaryKeys=${summary.keys.toList()}',
    );
    return viewers;
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
