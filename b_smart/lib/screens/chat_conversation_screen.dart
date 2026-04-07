import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/chat_api.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../widgets/safe_network_image.dart';

class ChatConversationScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic>? initialConversation;

  const ChatConversationScreen({
    super.key,
    required this.conversationId,
    this.initialConversation,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final _chatApi = ChatApi();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();

  String? _currentUserId;
  Map<String, dynamic>? _conversation;
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  static const int _pageLimit = 20;

  @override
  void initState() {
    super.initState();
    _conversation = widget.initialConversation;
    _init();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = await CurrentUser.id;
    if (!mounted) return;
    setState(() => _currentUserId = uid);
    await _load(page: 1, replace: true);
  }

  Map<String, dynamic>? _otherParticipant() {
    final uid = _currentUserId;
    final participants = _conversation?['participants'];
    if (participants is! List || participants.isEmpty) return null;
    if (uid == null || uid.isEmpty) {
      final p0 = participants.first;
      return p0 is Map ? Map<String, dynamic>.from(p0) : null;
    }
    for (final p in participants) {
      if (p is! Map) continue;
      final id = (p['_id'] ?? p['id'] ?? p['user_id'])?.toString();
      if (id != null && id.isNotEmpty && id != uid) return Map<String, dynamic>.from(p);
    }
    final p0 = participants.first;
    return p0 is Map ? Map<String, dynamic>.from(p0) : null;
  }

  String _nameFor(Map<String, dynamic>? user) {
    if (user == null) return 'Messages';
    return (user['full_name'] ?? user['name'] ?? user['username'] ?? 'User').toString();
  }

  String? _avatarFor(Map<String, dynamic>? user) {
    if (user == null) return null;
    return (user['avatar_url'] ?? user['avatarUrl'] ?? user['profile_pic'] ?? user['profilePic'])
        ?.toString();
  }

  Future<void> _load({required int page, required bool replace}) async {
    setState(() {
      _error = null;
      if (replace) _loading = true;
      if (!replace) _loadingMore = true;
    });
    try {
      final res = await _chatApi.getMessages(
        conversationId: widget.conversationId,
        page: page,
        limit: _pageLimit,
      );

      final raw = res['messages'];
      final hasMore = res['hasMore'] == true;

      final items = (raw is List ? raw : const <dynamic>[])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;
      setState(() {
        _messages = replace ? items.reversed.toList() : [...items.reversed, ..._messages];
        _page = page;
        _hasMore = hasMore;
        _loading = false;
        _loadingMore = false;
      });

      // Auto-mark latest message as seen (best-effort, matches web).
      unawaited(_markLatestSeen());

      if (replace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_loading || _loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels <= 80) {
      unawaited(_load(page: _page + 1, replace: false));
    }
  }

  bool _hasSeen(Map<String, dynamic> message, String uid) {
    final seenBy = message['seenBy'];
    if (seenBy is! List) return false;
    return seenBy.any((entry) {
      if (entry is Map) {
        final id = (entry['_id'] ?? entry['id'] ?? entry['user_id'])?.toString();
        return id == uid;
      }
      return entry?.toString() == uid;
    });
  }

  Future<void> _markLatestSeen() async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;
    final latest = _messages.reversed.cast<Map<String, dynamic>?>().firstWhere(
          (m) {
            if (m == null) return false;
            if (m['isDeleted'] == true) return false;
            final sender = m['sender'];
            final senderId = (sender is Map ? (sender['_id'] ?? sender['id'] ?? sender['user_id']) : sender)
                ?.toString();
            if (senderId == null || senderId.isEmpty) return false;
            if (senderId == uid) return false;
            return !_hasSeen(m, uid);
          },
          orElse: () => null,
        );
    if (latest == null) return;
    final messageId = (latest['_id'] ?? latest['id'])?.toString();
    if (messageId == null || messageId.isEmpty) return;
    try {
      final updated = await _chatApi.markMessageSeen(messageId: messageId);
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map((m) => (m['_id']?.toString() == messageId) ? {...m, ...updated} : m)
            .toList();
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final created = await _chatApi.sendMessage(
        conversationId: widget.conversationId,
        payload: {
          'text': text,
          'mediaUrl': '',
          'mediaType': 'none',
          'replyTo': null,
        },
      );
      final msg = Map<String, dynamic>.from(created);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _inputController.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final other = _otherParticipant();
    final otherName = _nameFor(other);
    final otherAvatar = _avatarFor(other);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (otherAvatar != null && otherAvatar.trim().isNotEmpty)
              ClipOval(
                child: SafeNetworkImage(
                  url: otherAvatar,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                ),
              )
            else
              CircleAvatar(
                radius: 16,
                backgroundColor: DesignTokens.instaPink,
                child: Text(
                  otherName.isNotEmpty ? otherName.characters.first.toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                otherName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: DesignTokens.instaPink),
                  )
                : RefreshIndicator(
                    onRefresh: () => _load(page: 1, replace: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: _messages.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loadingMore && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final i = _loadingMore ? index - 1 : index;
                        final message = _messages[i];
                        final uid = _currentUserId ?? '';
                        final sender = message['sender'];
                        final senderId = (sender is Map
                                ? (sender['_id'] ?? sender['id'] ?? sender['user_id'])
                                : sender)
                            ?.toString();
                        final mine = senderId != null && senderId.isNotEmpty && senderId == uid;
                        return _bubble(message, mine);
                      },
                    ),
                  ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.send, color: DesignTokens.instaPink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> message, bool mine) {
    final isDeleted = message['isDeleted'] == true;
    final text = message['text']?.toString() ?? '';
    final mediaUrl = message['mediaUrl']?.toString() ?? '';

    final bg = mine ? const Color(0xFF7C3AED) : Theme.of(context).cardColor;
    final fg = mine ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final border = mine ? Colors.transparent : Colors.black.withValues(alpha: 0.06);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: isDeleted
            ? Text('Message unsent', style: TextStyle(color: fg.withValues(alpha: 0.75), fontStyle: FontStyle.italic))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mediaUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SafeNetworkImage(
                          url: mediaUrl,
                          width: 240,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: TextStyle(color: fg, fontSize: 14, height: 1.25),
                    ),
                ],
              ),
      ),
    );
  }
}

