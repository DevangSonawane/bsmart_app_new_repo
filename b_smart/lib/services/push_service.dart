import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api/api_client.dart';
import '../utils/app_navigator.dart';
import '../models/notification_model.dart';
import '../utils/current_user.dart';
import 'notification_service.dart';

class PushService {
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;
  PushService._internal();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();
  final ApiClient _api = ApiClient();
  final NotificationService _notificationService = NotificationService();

  late final FlutterSecureStorage _storage;
  final Map<String, String> _memoryStorage = {};

  static const String _storedTokenKey = 'push_fcm_token_last_registered';
  static const String _pendingLinkKey = 'push_pending_link';
  static const String _channelId = 'bsmart_channel';

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _tokenRefreshSub;

  bool _initialized = false;
  bool _localNotifsReady = false;
  bool _firebaseAvailable = false;

  void _log(String message) {
    if (kReleaseMode) return;
    debugPrint('[PushService] $message');
  }

  static const bool _logTokens =
      bool.fromEnvironment('PUSH_LOG_TOKENS', defaultValue: false);

  String _redact(String? value) {
    if (value == null || value.isEmpty) return '';
    if (_logTokens) return value;
    if (value.length <= 10) return '***';
    return '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
  }

  Future<void> initialize({required bool firebaseAvailable}) async {
    if (kIsWeb) return;
    if (_initialized) return;
    _initialized = true;
    _firebaseAvailable = firebaseAvailable;

    _log('initialize() start');
    if (!_firebaseAvailable) {
      _log('firebase unavailable; skipping push setup');
      return;
    }

    _messaging = FirebaseMessaging.instance;
    _storage = const FlutterSecureStorage(
      webOptions: WebOptions(
        dbName: 'b_smart_secure',
        publicKey: 'b_smart_push',
      ),
    );

    // Ask FCM/APNs-level permission first (Android 13+ will also need runtime
    // POST_NOTIFICATIONS which we request below as a backup).
    try {
      final fcmSettings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      _log(
          'messaging.requestPermission() status=${fcmSettings.authorizationStatus}');
    } catch (e) {
      _log('messaging.requestPermission() failed: $e');
    }

    // Android 13+ runtime permission (backup).
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      _log('notification permission: $status');
    }

    await _initLocalNotifications();
    _log('local notifications ready=$_localNotifsReady');

    _onMessageSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenFromMessage);
    _tokenRefreshSub = _messaging!.onTokenRefresh.listen((token) async {
      _log('onTokenRefresh token=${_redact(token)}');
      await _registerIfAuthenticated(token, force: false);
    });

    await _messaging!.setAutoInitEnabled(true);

    // Register current token if user is already logged in.
    final token = await _getFcmTokenSafely();
    if (token != null && token.isNotEmpty) {
      _log('getToken() token=${_redact(token)}');
      await _registerIfAuthenticated(token, force: false);
    } else {
      _log('getToken() returned empty/null');
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        unawaited(_retryTokenRegistrationAfterDelay());
      }
    }

    // If the app was launched by tapping a notification.
    final initial = await _messaging!.getInitialMessage();
    if (initial != null) {
      _log(
          'getInitialMessage() present; dataKeys=${initial.data.keys.toList()}');
      await _handleOpenFromMessage(initial);
    } else {
      _log('getInitialMessage() null');
    }
    _log('initialize() done');
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    await _tokenRefreshSub?.cancel();
    _onMessageSub = null;
    _onMessageOpenedSub = null;
    _tokenRefreshSub = null;
  }

  Future<void> syncTokenWithBackend() async {
    if (kIsWeb) return;
    if (!_firebaseAvailable) return;
    _log('syncTokenWithBackend()');
    final messaging = _messaging;
    if (messaging == null) return;
    final token = await _getFcmTokenSafely();
    if (token == null || token.isEmpty) {
      _log('syncTokenWithBackend(): getToken() empty/null');
      return;
    }
    await _registerIfAuthenticated(token, force: false);
  }

  /// Force-register the current token with backend even if it hasn't changed.
  /// Useful when backend-side token storage/SNS endpoints were reset.
  Future<void> forceRegisterWithBackend() async {
    if (kIsWeb) return;
    if (!_firebaseAvailable) return;
    _log('forceRegisterWithBackend()');
    final messaging = _messaging;
    if (messaging == null) return;
    final token = await _getFcmTokenSafely();
    if (token == null || token.isEmpty) {
      _log('forceRegisterWithBackend(): getToken() empty/null');
      return;
    }
    await _registerIfAuthenticated(token, force: true);
  }

  /// Clears the locally remembered "last registered" token so the next sync
  /// will register again.
  Future<void> clearLastRegisteredToken() async {
    if (kIsWeb) return;
    if (!_firebaseAvailable) return;
    _log('clearLastRegisteredToken()');
    await _write(_storedTokenKey, '');
  }

  Future<void> unregisterFromBackend() async {
    if (kIsWeb) return;
    if (!_firebaseAvailable) return;
    _log('unregisterFromBackend()');
    try {
      // Must be called before token is cleared (needs Authorization header).
      await _api.delete('/push/unregister');
      _log('backend unregister success');
    } catch (e, st) {
      // Best-effort cleanup; logout should still continue.
      _log('backend unregister failed (ignored): $e');
      _log(st.toString());
    } finally {
      await _write(_storedTokenKey, '');
    }
  }

  Future<String?> _getFcmTokenSafely() async {
    final messaging = _messaging;
    if (messaging == null) return null;
    try {
      return await messaging.getToken();
    } catch (e) {
      _log('getToken() failed (ignored for startup): $e');
      return null;
    }
  }

  Future<void> _retryTokenRegistrationAfterDelay() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!_firebaseAvailable) return;
    final token = await _getFcmTokenSafely();
    if (token == null || token.isEmpty) {
      _log('retry getToken() still empty/null');
      return;
    }
    _log('retry getToken() token=${_redact(token)}');
    await _registerIfAuthenticated(token, force: false);
  }

  Future<void> _initLocalNotifications() async {
    const androidInit =
        AndroidInitializationSettings('@drawable/ic_stat_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifs.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          final link = (json['link'] ?? '').toString();
          if (link.isNotEmpty) {
            await _navigate(link);
          }
        } catch (_) {
          // ignore malformed payload
        }
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'Bsmart Notifications',
      description: 'Bsmart social notifications',
      importance: Importance.high,
    );

    final androidPlugin = _localNotifs.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    _localNotifsReady = true;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!_localNotifsReady) return;
    _log(
      'onMessage (foreground) dataKeys=${message.data.keys.toList()} title=${message.notification?.title ?? message.data['title']}',
    );
    final title =
        message.notification?.title ?? (message.data['title'] ?? 'Bsmart');
    final body = message.notification?.body ?? (message.data['body'] ?? '');
    final link = (message.data['link'] ?? '').toString();
    final type = (message.data['type'] ?? '').toString();

    final payload = jsonEncode(<String, dynamic>{
      'link': link,
      'type': type,
    });

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      'Bsmart Notifications',
      channelDescription: 'Bsmart social notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _localNotifs.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title.toString(),
      body.toString(),
      const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload,
    );

    await _recordNotificationForBadge(message);
  }

  Future<void> _recordNotificationForBadge(RemoteMessage message) async {
    final data = message.data;
    final now = DateTime.now();
    final id = (data['id'] ??
            data['_id'] ??
            message.messageId ??
            'push-${now.millisecondsSinceEpoch}')
        .toString();
    if (_notificationService.getNotificationById(id) != null) return;

    final typeKey = (data['type'] ?? data['notification_type'] ?? 'system')
        .toString()
        .toLowerCase();
    final title =
        (message.notification?.title ?? data['title'] ?? 'Bsmart').toString();
    final body = (message.notification?.body ?? data['body'] ?? '').toString();
    final link = (data['link'] ?? '').toString().trim();
    final relatedId =
        (data['related_id'] ?? data['relatedId']).toString().trim();
    final currentUserId = await CurrentUser.id;

    await _notificationService.addNotification(
      NotificationItem(
        id: id,
        typeKey: typeKey,
        title: title,
        message: body,
        timestamp: now,
        isRead: false,
        relatedId: relatedId.isEmpty ? null : relatedId,
        link: link.isEmpty ? null : link,
        metadata: data.isEmpty ? null : Map<String, dynamic>.from(data),
      ),
      userId: currentUserId,
    );
  }

  Future<void> _handleOpenFromMessage(RemoteMessage message) async {
    final link = (message.data['link'] ?? '').toString().trim();
    if (link.isEmpty) return;
    _log('onMessageOpenedApp/getInitialMessage link=$link');
    await _navigate(link);
  }

  Future<void> _navigate(String link) async {
    // If navigator isn't ready yet, keep it to replay later.
    final navigator = AppNavigator.state;
    if (navigator == null) {
      _log('navigator not ready; storing pending link=$link');
      await _write(_pendingLinkKey, link);
      return;
    }
    await _write(_pendingLinkKey, '');
    _log('navigating pushNamed($link)');
    unawaited(navigator.pushNamed(link));
  }

  Future<void> replayPendingNavigationIfAny() async {
    final link = await _read(_pendingLinkKey);
    if (link == null || link.trim().isEmpty) return;
    _log('replayPendingNavigationIfAny link=$link');
    await _navigate(link.trim());
  }

  Future<void> _registerIfAuthenticated(
    String fcmToken, {
    required bool force,
  }) async {
    final hasAuth = await _api.hasToken;
    if (!hasAuth) {
      _log('skip register: not authenticated (no JWT)');
      return;
    }

    final last = await _read(_storedTokenKey);
    if (!force && last != null && last == fcmToken) {
      _log('skip register: token unchanged');
      return;
    }

    try {
      _log(
        'registering token with backend force=$force token=${_redact(fcmToken)}',
      );
      await _api.post('/push/register-fcm', body: {'fcm_token': fcmToken});
      await _write(_storedTokenKey, fcmToken);
      _log('backend register success');
    } catch (e, st) {
      // Best-effort; will retry on next app start or login.
      _log('backend register failed (will retry later): $e');
      _log(st.toString());
    }
  }

  Future<String?> _read(String key) async {
    try {
      final v = await _storage.read(key: key);
      return v ?? _memoryStorage[key];
    } catch (_) {
      return _memoryStorage[key];
    }
  }

  Future<void> _write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      _memoryStorage[key] = value;
    }
  }
}
