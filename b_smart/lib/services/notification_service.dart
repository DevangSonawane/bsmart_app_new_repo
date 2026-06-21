// ignore_for_file: unnecessary_type_check, dead_code

import '../models/notification_model.dart';
import 'dart:async';
import 'dart:math';
import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../config/api_config.dart';
import '../utils/current_user.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final ApiClient _client = ApiClient();
  List<NotificationItem> _notifications = [];
  final StreamController<List<NotificationItem>> _controller = StreamController.broadcast();
  StreamSubscription<dynamic>? _subscription;
  String? _activeUserId;

  // Server-backed notifications (no seeded mock data).
  NotificationService._internal() {
    // Seed stream with empty list so UI can render immediately.
    _controller.add(const <NotificationItem>[]);
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

  String _normalizeType(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  bool _typeMatches(NotificationItem item, String filter) {
    final normalizedFilter = _normalizeType(filter);
    if (normalizedFilter.isEmpty || normalizedFilter == 'all') return true;

    final type = _normalizeType(item.typeKey);
    if (normalizedFilter == 'unread') {
      return !item.isRead;
    }

    if (type == normalizedFilter) return true;

    final filterAliases = <String, List<String>>{
      'like': const ['like', 'ad_like'],
      'comment': const ['comment', 'ad_comment'],
      'follow': const ['follow', 'follow_request', 'follow_accepted'],
      'mention': const ['mention', 'tag', 'tagged'],
      'ad': const ['ad', 'ad_approved', 'ad_rejected', 'ad_submitted', 'ad_expired', 'ad_view'],
    };
    final aliases = filterAliases[normalizedFilter];
    if (aliases != null && aliases.contains(type)) return true;

    return type.contains(normalizedFilter);
  }

  List<NotificationItem> _filterNotifications(
    List<NotificationItem> items, {
    String? typeFilter,
    bool? isRead,
  }) {
    return items.where((item) {
      if (isRead != null && item.isRead != isRead) return false;
      return _typeMatches(item, typeFilter ?? 'all');
    }).toList(growable: false);
  }

  String? _normalizeUserId(String? userId) {
    final trimmed = userId?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<String?> _resolveCurrentUserId() async {
    try {
      return _normalizeUserId(await CurrentUser.id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _bindToCurrentUser({bool notifyIfChanged = true}) async {
    final currentUserId = await _resolveCurrentUserId();
    if (currentUserId == _activeUserId) return;
    _activeUserId = currentUserId;
    _notifications = [];
    if (notifyIfChanged) {
      _controller.add(const <NotificationItem>[]);
    }
  }

  void _replaceCache(List<NotificationItem> items) {
    _notifications = items;
    _controller.add(_sortedCopy(_notifications));
  }

  void clearSessionCache() {
    _activeUserId = null;
    _notifications = [];
    if (!_controller.isClosed) {
      _controller.add(const <NotificationItem>[]);
    }
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
    bool updateCache = true,
  }) async {
    await _bindToCurrentUser();
    if (!forceRefresh && _notifications.isNotEmpty) {
      return NotificationPage(items: _sortedCopy(_notifications), total: _notifications.length);
    }
    try {
      final normalizedFilter = _normalizeType(typeFilter);
      final requestLimit =
          normalizedFilter.isNotEmpty && normalizedFilter != 'all'
              ? max(limit, 200)
              : limit;
      final query = <String, String>{
        'page': page.toString(),
        'limit': requestLimit.toString(),
      };
      if (normalizedFilter.isNotEmpty && normalizedFilter != 'all') {
        if (normalizedFilter == 'unread') {
          query['isRead'] = 'false';
        } else {
          query['type'] = normalizedFilter;
        }
      }
      if (isRead != null) {
        query['isRead'] = isRead ? 'true' : 'false';
      }
      final res = await _client.get('$_basePath/notifications', queryParams: query);
      final parsed = _parseNotifications(res);
      final filtered = _filterNotifications(
        parsed,
        typeFilter: normalizedFilter,
        isRead: isRead,
      );
      if (updateCache) {
        _replaceCache(filtered);
      }
      final resultItems = updateCache ? _sortedCopy(_notifications) : _sortedCopy(filtered);
      int total = filtered.length;
      if (res is Map<String, dynamic>) {
        final v = res['total'] ?? (res['data'] is Map ? (res['data'] as Map)['total'] : null);
        final hasFilter = normalizedFilter.isNotEmpty && normalizedFilter != 'all';
        if (!hasFilter) {
          if (v is int) total = v;
          if (v is num) total = v.toInt();
          if (v is String) total = int.tryParse(v) ?? total;
        }
      }
      return NotificationPage(items: resultItems, total: total);
    } catch (_) {
      // keep cached notifications if network/API fails
    }
    return NotificationPage(items: _sortedCopy(_notifications), total: _notifications.length);
  }

  Future<int> getUnreadCount() async {
    await _bindToCurrentUser();
    try {
      final page = await getNotifications(
        forceRefresh: true,
        page: 1,
        limit: 200,
        typeFilter: 'unread',
        updateCache: false,
      );
      return page.total > 0 ? page.total : page.items.length;
    } catch (_) {
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
    }
    return _notifications.where((n) => !n.isRead).length;
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _bindToCurrentUser();
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
    await _bindToCurrentUser();
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
    await _bindToCurrentUser();
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
    await _bindToCurrentUser();
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
  Future<void> addNotification(NotificationItem notification, {String? userId}) async {
    final scopeUserId = _normalizeUserId(userId) ?? await _resolveCurrentUserId();
    if (scopeUserId == null) {
      return;
    }
    if (_activeUserId != scopeUserId) {
      _activeUserId = scopeUserId;
      _notifications = [];
    }
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
    unawaited(addNotification(notification));
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
    final id = _normalizeUserId(userId);
    if (id == null) return;
    if (_activeUserId != id) {
      _activeUserId = id;
      _notifications = [];
      if (!_controller.isClosed) {
        _controller.add(const <NotificationItem>[]);
      }
    }
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
