import 'dart:developer' as developer;

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';

typedef SocketHandler = void Function(dynamic data);

class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;
  ChatSocketService._internal();

  io.Socket? _socket;
  String? _userId;

  final Map<String, Set<SocketHandler>> _subscribers =
      <String, Set<SocketHandler>>{
    'new-message': <SocketHandler>{},
    'user-typing': <SocketHandler>{},
    'user-stop-typing': <SocketHandler>{},
    'message-seen-update': <SocketHandler>{},
    'message-reaction-update': <SocketHandler>{},
    'message-removed': <SocketHandler>{},
    'group-member-added': <SocketHandler>{},
    'group-member-removed': <SocketHandler>{},
    'online-users-updated': <SocketHandler>{},
  };

  bool get isConnected => _socket?.connected == true;

  String _socketOrigin() {
    // React parity: socket base is API origin (baseURL without /api).
    final base = ApiConfig.baseUrl.trim().replaceAll(RegExp(r'\/+$'), '');
    return base.replaceFirst(RegExp(r'\/api\/?$'), '');
  }

  void connect({required String token, String? userId}) {
    final t = token.trim();
    if (t.isEmpty) return;
    _userId = userId?.trim().isEmpty == true ? null : userId?.trim();

    // If already connected, just register (if needed).
    final existing = _socket;
    if (existing != null) {
      if (existing.connected && _userId != null) {
        existing.emit('register', _userId);
      }
      return;
    }

    final url = _socketOrigin();
    developer.log('[ChatSocket] connecting url=$url', name: 'ChatSocket');

    final socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1500)
          .setTimeout(10000)
          .setAuth(<String, dynamic>{'token': t})
          .build(),
    );
    _socket = socket;

    void attachListeners() {
      for (final entry in _subscribers.entries) {
        final eventName = entry.key;
        socket.off(eventName);
        socket.on(eventName, (data) {
          for (final cb in List<SocketHandler>.from(entry.value)) {
            try {
              cb(data);
            } catch (e) {
              developer.log(
                '[ChatSocket] subscriber error event=$eventName error=$e',
                name: 'ChatSocket',
              );
            }
          }
        });
      }
    }

    attachListeners();

    socket.on('connect', (_) {
      developer.log('[ChatSocket] connected id=${socket.id}', name: 'ChatSocket');
      if (_userId != null) socket.emit('register', _userId);
    });

    socket.on('connect_error', (err) {
      developer.log('[ChatSocket] connect_error $err', name: 'ChatSocket');
    });

    socket.on('disconnect', (reason) {
      developer.log('[ChatSocket] disconnected reason=$reason', name: 'ChatSocket');
    });
  }

  void disconnect() {
    final socket = _socket;
    if (socket == null) return;
    for (final entry in _subscribers.entries) {
      socket.off(entry.key);
      entry.value.clear();
    }
    socket.disconnect();
    _socket = null;
    _userId = null;
  }

  void on(String event, SocketHandler handler) {
    final set = _subscribers[event];
    if (set == null) return;
    set.add(handler);
  }

  void off(String event, SocketHandler handler) {
    final set = _subscribers[event];
    if (set == null) return;
    set.remove(handler);
  }

  void joinRoom(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return;
    _socket?.emit('join-room', id);
  }

  void leaveRoom(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return;
    _socket?.emit('leave-room', id);
  }

  void emitTyping({required String conversationId, required String userId}) {
    final cid = conversationId.trim();
    final uid = userId.trim();
    if (cid.isEmpty || uid.isEmpty) return;
    _socket?.emit('typing', {'conversationId': cid, 'userId': uid});
  }

  void emitStopTyping({required String conversationId, required String userId}) {
    final cid = conversationId.trim();
    final uid = userId.trim();
    if (cid.isEmpty || uid.isEmpty) return;
    _socket?.emit('stop-typing', {'conversationId': cid, 'userId': uid});
  }

  void emitMessageSeen({
    required String conversationId,
    required String messageId,
    required String userId,
    String? seenAt,
  }) {
    final cid = conversationId.trim();
    final mid = messageId.trim();
    final uid = userId.trim();
    if (cid.isEmpty || mid.isEmpty || uid.isEmpty) return;
    final payload = <String, dynamic>{
      'conversationId': cid,
      'messageId': mid,
      'userId': uid,
      if (seenAt != null && seenAt.trim().isNotEmpty) 'seenAt': seenAt.trim(),
    };
    _socket?.emit('message-seen', payload);
  }

  void emitMessageDeleted({
    required String conversationId,
    required String messageId,
  }) {
    final cid = conversationId.trim();
    final mid = messageId.trim();
    if (cid.isEmpty || mid.isEmpty) return;
    _socket?.emit('message-deleted', {'conversationId': cid, 'messageId': mid});
  }
}
