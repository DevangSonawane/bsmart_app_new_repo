// ignore_for_file: unnecessary_type_check, dead_code

import '../models/notification_model.dart';
import 'dart:async';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  
  List<NotificationItem> _notifications = [];
  final StreamController<List<NotificationItem>> _controller = StreamController.broadcast();
  StreamSubscription<dynamic>? _subscription;

  // Initialize with dummy notifications
  NotificationService._internal() {
    _notifications = _generateDummyNotifications();
    // seed controller
    _controller.add(getNotifications());
  }

  List<NotificationItem> _generateDummyNotifications() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: 'notif-1',
        type: NotificationType.ad,
        title: 'New Ad Available',
        message: 'A new ad has been added. Check it out now.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        isRead: false,
        relatedId: 'ad-1',
      ),
      NotificationItem(
        id: 'notif-2',
        type: NotificationType.activity,
        title: 'New Follower',
        message: 'Alice Smith started following you',
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: false,
      ),
    ];
  }

  // Get all notifications (latest first)
  List<NotificationItem> getNotifications() {
    return List.from(_notifications)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Get unread count
  int getUnreadCount() {
    return _notifications.where((n) => !n.isRead).length;
  }

  // Mark notification as read
  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _controller.add(getNotifications());
    }
  }

  // Mark all as read
  void markAllAsRead() {
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _controller.add(getNotifications());
  }

  // Clear all notifications
  void clearAll() {
    _notifications.clear();
    _controller.add(getNotifications());
  }

  // Add new notification (for new ads, etc.)
  void addNotification(NotificationItem notification) {
    _notifications.insert(0, notification);
    _controller.add(getNotifications());
  }

  // Simulate receiving a new ad notification
  void addNewAdNotification(String adId, String adTitle) {
    final notification = NotificationItem(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      type: NotificationType.ad,
      title: 'New Ad Available',
      message: adTitle.isNotEmpty
          ? '$adTitle - Check it out now!'
          : 'A new ad has been added. Check it out now.',
      timestamp: DateTime.now(),
      isRead: false,
      relatedId: adId,
    );
    addNotification(notification);
  }

  // Get notification by ID
  NotificationItem? getNotificationById(String id) {
    try {
      return _notifications.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }

  // Initialize realtime subscription for a user
  void startRealtimeForUser(String userId) {
    // Realtime notifications are not yet supported in the REST API.
    // Keeping this stub for future implementation.
  }

  // Get notifications stream (for real-time updates)
  Stream<List<NotificationItem>> getNotificationsStream() {
    // Always return the controller stream; it is seeded with current notifications.
    return _controller.stream;
  }

  // Dispose realtime channel
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
