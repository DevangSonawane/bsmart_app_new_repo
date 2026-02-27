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
    final typeStr = (json['type'] as String?) ?? 'system';
    if (typeStr == 'ad') t = NotificationType.ad;
    if (typeStr == 'activity') t = NotificationType.activity;

    return NotificationItem(
      id: json['id'] as String,
      type: t,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      isRead: json['is_read'] as bool? ?? false,
      relatedId: json['related_id'] as String?,
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
