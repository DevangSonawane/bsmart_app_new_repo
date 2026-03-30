// ignore_for_file: unnecessary_type_check, dead_code

import '../models/notification_model.dart';
import 'dart:async';
import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../config/api_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final ApiClient _client = ApiClient();
  List<NotificationItem> _notifications = [];
  final StreamController<List<NotificationItem>> _controller = StreamController.broadcast();
  StreamSubscription<dynamic>? _subscription;

  // Initialize with dummy notifications
  NotificationService._internal() {
    _notifications = _generateDummyNotifications();
    // seed controller
    _controller.add(_sortedCopy(_notifications));
  }

  List<NotificationItem> _generateDummyNotifications() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: 'notif-1',
        typeKey: 'ad',
        title: 'New Ad Available',
        message: 'A new ad has been added. Check it out now.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        isRead: false,
        relatedId: 'ad-1',
      ),
      NotificationItem(
        id: 'notif-2',
        typeKey: 'follow',
        title: 'New Follower',
        message: 'Alice Smith started following you',
        timestamp: now.subtract(const Duration(hours: 1)),
        isRead: false,
      ),
    ];
  }

  String get _basePath {
    final base =
        ApiConfig.baseUrl.toLowerCase().trim().replaceAll(RegExp(r'\/+$'), '');
    final endsWithApi = base.endsWith('/api');
    return endsWithApi ? '' : '/api';
  }

  List<NotificationItem> _sortedCopy(List<NotificationItem> source) {
    return List<NotificationItem>.from(source)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<NotificationItem> _parseNotifications(dynamic res) {
    List<dynamic> list = const [];
    if (res is List) {
      list = res;
    } else if (res is Map<String, dynamic>) {
      final nestedData = res['data'];
      if (res['notifications'] is List) {
        list = res['notifications'] as List;
      } else if (nestedData is List) {
        list = nestedData;
      } else if (nestedData is Map && nestedData['notifications'] is List) {
        list = nestedData['notifications'] as List;
      } else if (res['items'] is List) {
        list = res['items'] as List;
      } else if (res['results'] is List) {
        list = res['results'] as List;
      }
    }
    return list
        .whereType<Map>()
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<NotificationPage> getNotifications({
    bool forceRefresh = true,
    int page = 1,
    int limit = 15,
    String? typeFilter,
    bool? isRead,
  }) async {
    if (!forceRefresh && _notifications.isNotEmpty) {
      return NotificationPage(items: _sortedCopy(_notifications), total: _notifications.length);
    }
    try {
      final query = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (typeFilter != null && typeFilter.isNotEmpty && typeFilter != 'all') {
        if (typeFilter == 'unread') {
          query['isRead'] = 'false';
        } else {
          query['type'] = typeFilter;
        }
      }
      if (isRead != null) {
        query['isRead'] = isRead ? 'true' : 'false';
      }
      final res = await _client.get('$_basePath/notifications', queryParams: query);
      final parsed = _parseNotifications(res);
      if (parsed.isNotEmpty || _notifications.isEmpty) {
        _notifications = parsed;
        _controller.add(_sortedCopy(_notifications));
      }
      int total = parsed.length;
      if (res is Map<String, dynamic>) {
        final v = res['total'] ?? (res['data'] is Map ? (res['data'] as Map)['total'] : null);
        if (v is int) total = v;
        if (v is num) total = v.toInt();
        if (v is String) total = int.tryParse(v) ?? total;
      }
      return NotificationPage(items: _sortedCopy(_notifications), total: total);
    } catch (_) {
      // keep cached notifications if network/API fails
    }
    return NotificationPage(items: _sortedCopy(_notifications), total: _notifications.length);
  }

  Future<int> getUnreadCount() async {
    try {
      final res = await _client.get('$_basePath/notifications/unread-count');
      if (res is Map<String, dynamic>) {
        final value = res['unread_count'] ??
            res['unreadCount'] ??
            res['count'] ??
            (res['data'] is Map ? (res['data'] as Map)['unread_count'] : null);
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value) ?? 0;
      }
    } catch (_) {
      // fallback to local cached count
    }
    return _notifications.where((n) => !n.isRead).length;
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;
    try {
      await _client.patch('$_basePath/notifications/$id/read');
    } catch (_) {
      // update local cache regardless to keep UX responsive
    }
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _controller.add(_sortedCopy(_notifications));
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;
    try {
      await _client.delete('$_basePath/notifications/$id');
    } catch (_) {
      // best-effort; still update local cache
    }
    _notifications.removeWhere((n) => n.id == id);
    _controller.add(_sortedCopy(_notifications));
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    try {
      await _client.patch('$_basePath/notifications/mark-all-read');
    } on NotFoundException {
      try {
        await _client.patch('$_basePath/notifications/read-all');
      } catch (_) {}
    } catch (_) {}

    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _controller.add(_sortedCopy(_notifications));
  }

  // Clear all notifications
  Future<void> clearAll() async {
    var clearedOnServer = false;
    try {
      await _client.delete('$_basePath/notifications/all');
      clearedOnServer = true;
    } on NotFoundException {
      try {
        await _client.delete('$_basePath/notifications/clear');
        clearedOnServer = true;
      } on NotFoundException {
        try {
          await _client.delete('$_basePath/notifications');
          clearedOnServer = true;
        } catch (_) {}
      } catch (_) {}
    } catch (_) {}

    if (!clearedOnServer && _notifications.isNotEmpty) {
      for (final n in List<NotificationItem>.from(_notifications)) {
        try {
          await _client.delete('$_basePath/notifications/${n.id}');
          clearedOnServer = true;
        } catch (_) {}
      }
    }

    _notifications.clear();
    _controller.add(const <NotificationItem>[]);
  }

  // Add new notification (for new ads, etc.)
  void addNotification(NotificationItem notification) {
    _notifications.insert(0, notification);
    _controller.add(_sortedCopy(_notifications));
  }

  // Simulate receiving a new ad notification
  void addNewAdNotification(String adId, String adTitle) {
    final notification = NotificationItem(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      typeKey: 'ad',
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
