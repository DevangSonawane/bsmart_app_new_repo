import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../api/api_client.dart';
import '../utils/app_navigator.dart';

class PushService {
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;
  PushService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();
  final ApiClient _api = ApiClient();

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

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;
    _initialized = true;

    _storage = const FlutterSecureStorage(
      webOptions: WebOptions(
        dbName: 'b_smart_secure',
        publicKey: 'b_smart_push',
      ),
    );

    // Android 13+ needs runtime notification permission.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Permission.notification.request();
    }

    await _initLocalNotifications();

    _onMessageSub =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenFromMessage);
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      await _registerIfAuthenticated(token);
    });

    // Register current token if user is already logged in.
    final token = await _messaging.getToken();
    if (token != null && token.isNotEmpty) {
      await _registerIfAuthenticated(token);
    }

    // If the app was launched by tapping a notification.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await _handleOpenFromMessage(initial);
    }
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
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _registerIfAuthenticated(token);
  }

  Future<void> unregisterFromBackend() async {
    if (kIsWeb) return;
    try {
      // Must be called before token is cleared (needs Authorization header).
      await _api.delete('/api/push/unregister');
    } catch (_) {
      // Best-effort cleanup; logout should still continue.
    } finally {
      await _write(_storedTokenKey, '');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit =
        AndroidInitializationSettings('@drawable/ic_stat_notification');
    const initSettings = InitializationSettings(android: androidInit);

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

    await _localNotifs.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title.toString(),
      body.toString(),
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> _handleOpenFromMessage(RemoteMessage message) async {
    final link = (message.data['link'] ?? '').toString().trim();
    if (link.isEmpty) return;
    await _navigate(link);
  }

  Future<void> _navigate(String link) async {
    // If navigator isn't ready yet, keep it to replay later.
    final navigator = AppNavigator.state;
    if (navigator == null) {
      await _write(_pendingLinkKey, link);
      return;
    }
    await _write(_pendingLinkKey, '');
    unawaited(navigator.pushNamed(link));
  }

  Future<void> replayPendingNavigationIfAny() async {
    final link = await _read(_pendingLinkKey);
    if (link == null || link.trim().isEmpty) return;
    await _navigate(link.trim());
  }

  Future<void> _registerIfAuthenticated(String fcmToken) async {
    final hasAuth = await _api.hasToken;
    if (!hasAuth) return;

    final last = await _read(_storedTokenKey);
    if (last != null && last == fcmToken) return;

    try {
      await _api.post('/api/push/register-fcm', body: {'fcm_token': fcmToken});
      await _write(_storedTokenKey, fcmToken);
    } catch (_) {
      // Best-effort; will retry on next app start or login.
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
