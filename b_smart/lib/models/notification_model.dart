class NotificationItem {
  final String id;
  final String typeKey;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? relatedId; // ID of related ad, post, etc.
  final Map<String, dynamic>? sender;
  final String? link;
  final Map<String, dynamic>? metadata;

  NotificationItem({
    required this.id,
    required this.typeKey,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.relatedId,
    this.sender,
    this.link,
    this.metadata,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final typeStr =
        (json['type'] ?? json['notification_type'] ?? 'system')
            .toString()
            .toLowerCase();

    final timestampValue =
        json['timestamp'] ?? json['created_at'] ?? json['createdAt'];
    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(
          timestampValue?.toString() ?? DateTime.now().toIso8601String());
    } catch (_) {
      parsedTime = DateTime.now();
    }

    final readValue = json['is_read'] ?? json['isRead'] ?? json['read'];
    final isRead = readValue == true ||
        readValue == 1 ||
        readValue?.toString().toLowerCase() == 'true';

    return NotificationItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      typeKey: typeStr,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: parsedTime,
      isRead: isRead,
      relatedId: (json['related_id'] ?? json['relatedId'])?.toString(),
      sender: json['sender'] is Map
          ? Map<String, dynamic>.from(json['sender'] as Map)
          : null,
      link: json['link']?.toString(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  NotificationItem copyWith({
    String? id,
    String? typeKey,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? relatedId,
    Map<String, dynamic>? sender,
    String? link,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      typeKey: typeKey ?? this.typeKey,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId ?? this.relatedId,
      sender: sender ?? this.sender,
      link: link ?? this.link,
      metadata: metadata ?? this.metadata,
    );
  }
}

class NotificationPage {
  final List<NotificationItem> items;
  final int total;
  const NotificationPage({required this.items, required this.total});
}
