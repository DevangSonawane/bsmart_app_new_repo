import '../api/highlights_api.dart';
import '../models/story_model.dart';
import '../utils/url_helper.dart';

/// Service layer for highlight-related data transformations.
///
/// Key contract:
///   When loading items for a highlight via [fetchHighlightItems], each returned
///   [Story.id] is set to the *highlight item id* (`_itemId`), NOT the story item
///   `_id`. This is intentional — it allows callers to pass `story.id` directly
///   to [HighlightsApi.deleteItem] without needing a separate lookup.
///
///   If you need the original story item id (e.g. to cross-reference with the
///   feed), it is available in the [Story.id] field ONLY when stories are loaded
///   from sources other than highlight items (feed, archive). Be careful not to
///   mix the two contexts.
class HighlightService {
  final HighlightsApi _api = HighlightsApi();

  StoryMediaType _mediaType(Map<String, dynamic>? media, String url) {
    final type = (media?['type'] as String?)?.toLowerCase() ?? '';
    final hls = media?['hls'] == true;
    if (type.contains('reel') || type.contains('video') || hls) {
      return StoryMediaType.video;
    }
    final lower = url.toLowerCase();
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m3u8')) {
      return StoryMediaType.video;
    }
    return StoryMediaType.image;
  }

  /// Maps raw item maps (from archive or highlight items endpoint) into [Story]
  /// objects.
  ///
  /// [useItemIdAsStoryId] — when `true` (default for highlight items), the
  /// [Story.id] is set to `_itemId` so it can be used directly in delete calls.
  /// Pass `false` when mapping archive items that will be used only for display /
  /// selection (where you need the story `_id` to add to a highlight).
  List<Story> mapHighlightItems(
    List<Map<String, dynamic>> items, {
    String? ownerUserName,
    String? ownerAvatar,
    bool useItemIdAsStoryId = false,
  }) {
    final sorted = List<Map<String, dynamic>>.from(items);
    sorted.sort((a, b) {
      final ad = (a['order'] as num?)?.toInt() ?? 0;
      final bd = (b['order'] as num?)?.toInt() ?? 0;
      return ad.compareTo(bd);
    });

    return sorted.map<Story>((m) {
      final rawMedia = m['media'];
      Map<String, dynamic>? media;
      if (rawMedia is List && rawMedia.isNotEmpty && rawMedia.first is Map) {
        media = Map<String, dynamic>.from(rawMedia.first as Map);
      } else if (rawMedia is Map) {
        media = Map<String, dynamic>.from(rawMedia);
      }

      final mediaUrl = UrlHelper.absoluteUrl(media?['url'] as String? ?? '');
      final thumbnailUrl = media?['thumbnail'] as String?;
      final mediaType = _mediaType(media, mediaUrl);

      final texts = (m['texts'] is List)
          ? (m['texts'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : null;
      final mentions = (m['mentions'] is List)
          ? (m['mentions'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : null;
      final transform = (m['transform'] is Map)
          ? Map<String, dynamic>.from(m['transform'] as Map)
          : null;
      final filter = (m['filter'] is Map)
          ? Map<String, dynamic>.from(m['filter'] as Map)
          : null;
      final rawDuration = media != null ? media['durationSec'] : null;
      final int? durationSec =
          rawDuration is int ? rawDuration : (m['durationSec'] as int?);

      // _itemId is the highlight-item link id — needed for deleteItem().
      // _id is the underlying story item id — needed for addItems().
      final storyId = (m['_id'] as String?) ?? '';
      final itemId = (m['_itemId'] as String?) ?? '';

      // When loading items FROM a highlight, prefer _itemId so the returned
      // Story.id can be passed directly to HighlightsApi.deleteItem().
      final resolvedId =
          useItemIdAsStoryId && itemId.isNotEmpty ? itemId : storyId;

      return Story(
        id: resolvedId.isNotEmpty ? resolvedId : 'item',
        userId: (m['user_id'] as String?) ?? '',
        userName: ownerUserName ?? '',
        userAvatar: ownerAvatar,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl != null && thumbnailUrl.isNotEmpty
            ? UrlHelper.absoluteUrl(thumbnailUrl)
            : null,
        mediaType: mediaType,
        createdAt:
            DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        views: 0,
        isViewed: false,
        expiresAt: DateTime.tryParse(m['expiresAt'] as String? ?? ''),
        isDeleted: (m['isDeleted'] as bool?) ?? false,
        texts: texts,
        mentions: mentions,
        transform: transform,
        filter: filter,
        durationSec: durationSec,
      );
    }).toList();
  }

  /// Fetches and maps items for a given highlight.
  ///
  /// Returned [Story.id] values are the *highlight item ids* (`_itemId`), ready
  /// to be passed to [HighlightsApi.deleteItem].
  Future<List<Story>> fetchHighlightItems(
    String highlightId, {
    String? ownerUserName,
    String? ownerAvatar,
  }) async {
    final rawItems = await _api.items(highlightId);
    final items = List<Map<String, dynamic>>.from(
      rawItems.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    return mapHighlightItems(
      items,
      ownerUserName: ownerUserName,
      ownerAvatar: ownerAvatar,
      useItemIdAsStoryId: true, // ← critical: use _itemId for delete calls
    );
  }
}
