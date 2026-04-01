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

  // ── 1. Create Highlight ──────────────────────────────────────────────────

  /// POST /api/highlights
  /// Creates a new empty highlight. Returns the created highlight map.
  Future<Map<String, dynamic>> create({
    required String title,
    String? coverUrl,
  }) async {
    final body = <String, dynamic>{'title': title.trim()};
    if (coverUrl != null && coverUrl.trim().isNotEmpty) {
      body['cover_url'] = coverUrl.trim();
    }
    final res = await _client.post(_path('/highlights'), body: body);
    return (res as Map).cast<String, dynamic>();
  }

  // ── 2. Get User Highlights ───────────────────────────────────────────────

  /// GET /api/highlights/user/{userId}
  /// Returns highlights sorted by order ascending.
  Future<List<Map<String, dynamic>>> userHighlights(String userId) async {
    final res = await _client.get(_path('/highlights/user/$userId'));
    return List<Map<String, dynamic>>.from(res as List);
  }

  // ── 3. Add Story Items to Highlight ─────────────────────────────────────

  /// POST /api/highlights/{id}/items
  /// Attaches story items to a highlight. Duplicates are ignored.
  /// Returns { success: true, items_count: N }
  Future<Map<String, dynamic>> addItems(
    String highlightId,
    List<String> storyItemIds,
  ) async {
    final body = <String, dynamic>{
      'story_item_ids': storyItemIds,
    };
    final res = await _client.post(
      _path('/highlights/$highlightId/items'),
      body: body,
    );
    return (res as Map).cast<String, dynamic>();
  }

  // ── 4. Get Highlight Items ───────────────────────────────────────────────

  /// GET /api/highlights/{id}/items
  /// Returns populated StoryItem data with _itemId and order fields.
  /// NOTE: use _itemId (not _id) for delete-item calls.
  Future<List<Map<String, dynamic>>> items(String highlightId) async {
    final res = await _client.get(_path('/highlights/$highlightId/items'));
    return List<Map<String, dynamic>>.from(res as List);
  }

  // ── 5. Update Highlight ──────────────────────────────────────────────────

  /// PATCH /api/highlights/{id}
  /// Update title and/or cover_url. Omitted fields remain unchanged.
  Future<Map<String, dynamic>> update(
    String highlightId, {
    String? title,
    String? coverUrl,
  }) async {
    final body = <String, dynamic>{};
    if (title != null && title.trim().isNotEmpty) {
      body['title'] = title.trim();
    }
    if (coverUrl != null && coverUrl.trim().isNotEmpty) {
      body['cover_url'] = coverUrl.trim();
    }
    final res = await _client.patch(
      _path('/highlights/$highlightId'),
      body: body,
    );
    return (res as Map).cast<String, dynamic>();
  }

  // ── 6. Remove One Item From Highlight ───────────────────────────────────

  /// DELETE /api/highlights/{id}/items/{itemId}
  /// IMPORTANT: itemId = _itemId from GET items response, NOT the story _id.
  Future<Map<String, dynamic>> deleteItem(
    String highlightId,
    String highlightItemId,
  ) async {
    final res = await _client.delete(
      _path('/highlights/$highlightId/items/$highlightItemId'),
    );
    if (res is Map) return res.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  // ── 7. Delete Entire Highlight ───────────────────────────────────────────

  /// DELETE /api/highlights/{id}
  /// Deletes the highlight and all its items.
  Future<Map<String, dynamic>> delete(String highlightId) async {
    final res = await _client.delete(_path('/highlights/$highlightId'));
    if (res is Map) return res.cast<String, dynamic>();
    return const <String, dynamic>{};
  }
}
