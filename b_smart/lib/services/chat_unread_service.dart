import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/chat_api.dart';

class ChatUnreadService {
  static final ChatUnreadService _instance = ChatUnreadService._internal();
  factory ChatUnreadService() => _instance;
  ChatUnreadService._internal();

  final ChatApi _chatApi = ChatApi();

  final ValueNotifier<Set<String>> unreadConversationIds =
      ValueNotifier<Set<String>>(<String>{});

  final ValueNotifier<bool> hasUnread = ValueNotifier<bool>(false);

  Timer? _pollTimer;
  int _pollRefCount = 0;
  Duration _pollInterval = const Duration(seconds: 15);

  bool _refreshing = false;
  bool _refreshQueued = false;

  void startPolling({Duration interval = const Duration(seconds: 15)}) {
    _pollRefCount++;
    _pollInterval = interval;
    if (_pollRefCount != 1) return;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(refresh());
    });

    unawaited(refresh());
  }

  void stopPolling() {
    if (_pollRefCount <= 0) return;
    _pollRefCount--;
    if (_pollRefCount != 0) return;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh() async {
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final conversations = await _chatApi.getConversations();
      setFromConversations(conversations);
    } catch (_) {
      // ignore
    } finally {
      _refreshing = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(refresh());
      }
    }
  }

  void setFromConversations(List<Map<String, dynamic>> conversations) {
    final next = <String>{};
    for (final c in conversations) {
      final unread = (c['unreadCount'] as num?)?.toInt() ?? 0;
      if (unread <= 0) continue;
      final id = (c['_id'] ?? c['id'])?.toString();
      if (id == null || id.isEmpty) continue;
      next.add(id);
    }
    _setUnread(next);
  }

  void markConversationRead(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return;
    final cur = unreadConversationIds.value;
    if (!cur.contains(id)) return;
    final next = Set<String>.from(cur)..remove(id);
    _setUnread(next);
  }

  void markConversationUnread(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return;
    final cur = unreadConversationIds.value;
    if (cur.contains(id)) return;
    final next = Set<String>.from(cur)..add(id);
    _setUnread(next);
  }

  void _setUnread(Set<String> next) {
    final cur = unreadConversationIds.value;
    if (_setEquals(cur, next)) return;
    unreadConversationIds.value = next;
    hasUnread.value = next.isNotEmpty;
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final v in a) {
      if (!b.contains(v)) return false;
    }
    return true;
  }
}
