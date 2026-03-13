enum NotificationType {
  ad,
  system,
  activity,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String? relatedId; // ID of related ad, post, etc.

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.relatedId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    NotificationType t = NotificationType.system;
    final typeStr = (json['type'] ?? json['notification_type'] ?? 'system')
        .toString()
        .toLowerCase();
    if (typeStr == 'ad') t = NotificationType.ad;
    if (typeStr == 'activity') t = NotificationType.activity;

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
      type: t,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: parsedTime,
      isRead: isRead,
      relatedId: (json['related_id'] ?? json['relatedId'])?.toString(),
    );
  }

  NotificationItem copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? relatedId,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId ?? this.relatedId,
    );
  }
}
