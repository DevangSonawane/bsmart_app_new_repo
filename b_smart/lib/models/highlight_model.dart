import '../utils/url_helper.dart';

/// Represents a single Highlight (the circle shown on profile).
class Highlight {
  final String id;
  final String userId;
  final String title;
  final String? coverUrl;
  final int itemsCount;
  final int order;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Highlight({
    required this.id,
    required this.userId,
    required this.title,
    this.coverUrl,
    required this.itemsCount,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Highlight.fromMap(Map<String, dynamic> m) {
    final id = (m['_id'] as String?) ?? (m['id'] as String?) ?? '';
    final rawCover = (m['cover_url'] as String?) ?? '';
    return Highlight(
      id: id,
      userId: (m['user_id'] as String?) ??
          (m['userId'] as String?) ??
          (m['owner_id'] as String?) ??
          (m['ownerId'] as String?) ??
          '',
      title: (m['title'] as String?) ?? '',
      coverUrl: rawCover.isNotEmpty ? UrlHelper.absoluteUrl(rawCover) : null,
      itemsCount: (m['items_count'] as num?)?.toInt() ?? 0,
      order: (m['order'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Highlight copyWith({
    String? title,
    String? coverUrl,
    int? itemsCount,
    int? order,
  }) {
    return Highlight(
      id: id,
      userId: userId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      itemsCount: itemsCount ?? this.itemsCount,
      order: order ?? this.order,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
