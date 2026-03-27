import '../api/highlights_api.dart';
import '../models/story_model.dart';
import '../utils/url_helper.dart';

class HighlightService {
  final HighlightsApi _api = HighlightsApi();

  StoryMediaType _mediaType(Map<String, dynamic>? media, String url) {
    final type = (media?['type'] as String?)?.toLowerCase() ?? '';
    final hls = media?['hls'] == true;
    if (type.contains('reel') || type.contains('video') || hls) {
      return StoryMediaType.video;
    }
    final lower = url.toLowerCase();
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.m3u8')) {
      return StoryMediaType.video;
    }
    return StoryMediaType.image;
  }

  List<Story> mapHighlightItems(
    List<Map<String, dynamic>> items, {
    String? ownerUserName,
    String? ownerAvatar,
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
      final int? durationSec = (media?['durationSec'] is int)
          ? (media?['durationSec'] as int)
          : (m['durationSec'] as int?);

      return Story(
        id: (m['_id'] as String?) ?? 'item',
        userId: (m['user_id'] as String?) ?? '',
        userName: ownerUserName ?? '',
        userAvatar: ownerAvatar,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
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
    );
  }
}
