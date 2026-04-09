import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/chat_api.dart';
import '../api/users_api.dart';
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
  final _usersApi = UsersApi();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();

  String? _currentUserId;
  Map<String, dynamic>? _conversation;
  Map<String, dynamic>? _otherProfile;
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
      if (id != null && id.isNotEmpty && id != uid)
        return Map<String, dynamic>.from(p);
    }
    final p0 = participants.first;
    return p0 is Map ? Map<String, dynamic>.from(p0) : null;
  }

  String _nameFor(Map<String, dynamic>? user) {
    if (user == null) return 'Messages';
    return (user['full_name'] ?? user['name'] ?? user['username'] ?? 'User')
        .toString();
  }

  String? _avatarFor(Map<String, dynamic>? user) {
    if (user == null) return null;
    return (user['avatar_url'] ??
            user['avatarUrl'] ??
            user['profile_pic'] ??
            user['profilePic'])
        ?.toString();
  }

  String? _idFor(Map<String, dynamic>? user) {
    if (user == null) return null;
    return (user['_id'] ?? user['id'] ?? user['user_id'])?.toString();
  }

  Future<void> _loadOtherProfileIfNeeded() async {
    if (_otherProfile != null) return;
    final other = _otherParticipant();
    final otherId = _idFor(other);
    if (otherId == null || otherId.isEmpty) return;
    try {
      final res = await _usersApi.getUserProfile(otherId);
      final user = res['user'];
      if (!mounted) return;
      if (user is Map) {
        setState(() => _otherProfile = Map<String, dynamic>.from(user));
      } else {
        setState(() => _otherProfile = Map<String, dynamic>.from(res));
      }
    } catch (_) {
      // ignore; show UI without counts
    }
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
        _messages = replace
            ? items.reversed.toList()
            : [...items.reversed, ..._messages];
        _page = page;
        _hasMore = hasMore;
        _loading = false;
        _loadingMore = false;
      });

      // Auto-mark latest message as seen (best-effort, matches web).
      unawaited(_markLatestSeen());
      unawaited(_loadOtherProfileIfNeeded());

      if (replace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
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
        final id =
            (entry['_id'] ?? entry['id'] ?? entry['user_id'])?.toString();
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
        final senderId = (sender is Map
                ? (sender['_id'] ?? sender['id'] ?? sender['user_id'])
                : sender)
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
            .map((m) =>
                (m['_id']?.toString() == messageId) ? {...m, ...updated} : m)
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
    final otherName =
        (_otherProfile?['username'] as String?)?.trim().isNotEmpty == true
            ? (_otherProfile?['username'] as String).trim()
            : _nameFor(other);
    final otherAvatar = _avatarFor(_otherProfile ?? other);
    final otherId = _idFor(_otherProfile ?? other) ?? '';

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
                  otherName.isNotEmpty
                      ? otherName.characters.first.toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling coming soon')),
              );
            },
            icon: const Icon(LucideIcons.phone),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video call coming soon')),
              );
            },
            icon: const Icon(LucideIcons.video),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon')),
              );
            },
            icon: const Icon(LucideIcons.info),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: DesignTokens.instaPink),
                  )
                : RefreshIndicator(
                    onRefresh: () => _load(page: 1, replace: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      itemCount: _messages.length + 1 + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loadingMore && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final base = _loadingMore ? index - 1 : index;
                        if (base == 0) {
                          return _conversationHeader(
                            userId: otherId,
                            username: otherName,
                            avatarUrl: otherAvatar ?? '',
                          );
                        }
                        final i = base - 1;
                        final message = _messages[i];
                        final uid = _currentUserId ?? '';
                        final sender = message['sender'];
                        final senderId = (sender is Map
                                ? (sender['_id'] ??
                                    sender['id'] ??
                                    sender['user_id'])
                                : sender)
                            ?.toString();
                        final mine = senderId != null &&
                            senderId.isNotEmpty &&
                            senderId == uid;
                        final senderMap = sender is Map
                            ? Map<String, dynamic>.from(sender)
                            : null;
                        return _bubble(message, mine, senderMap: senderMap);
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
              child: _bottomComposer(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomComposer() {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.70);
    final hint = cs.onSurface.withValues(alpha: 0.55);
    final bg = cs.onSurface.withValues(alpha: 0.08);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF3B82F6),
          ),
          child: IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Camera coming soon')),
              );
            },
            icon: const Icon(
              LucideIcons.camera,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(color: cs.onSurface),
                    cursorColor: cs.primary,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Message…',
                      hintStyle: TextStyle(color: hint),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Voice recording coming soon')),
                    );
                  },
                  icon: Icon(LucideIcons.mic, size: 20, color: muted),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 22, minHeight: 32),
                ),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gallery coming soon')),
                    );
                  },
                  icon: Icon(LucideIcons.image, size: 20, color: muted),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 22, minHeight: 32),
                ),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Comments coming soon')),
                    );
                  },
                  icon: Icon(LucideIcons.messageCircle, size: 20, color: muted),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 22, minHeight: 32),
                ),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('More options coming soon')),
                    );
                  },
                  icon: Icon(LucideIcons.plus, size: 22, color: muted),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 22, minHeight: 32),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _avatarUrlFromUser(Map<String, dynamic>? user) {
    if (user == null) return null;
    return (user['avatar_url'] ??
            user['avatarUrl'] ??
            user['profile_pic'] ??
            user['profilePic'] ??
            user['avatar'])
        ?.toString();
  }

  String _labelFromUser(Map<String, dynamic>? user) {
    if (user == null) return 'U';
    final username =
        (user['username'] ?? user['name'] ?? user['full_name'])?.toString() ??
            '';
    final trimmed = username.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed.characters.first.toUpperCase();
  }

  Widget _messageAvatar({
    required String label,
    required double size,
    String? avatarUrl,
  }) {
    final cs = Theme.of(context).colorScheme;
    final subtle = cs.onSurface.withValues(alpha: 0.08);
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: subtle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.45,
          ),
        ),
      );
    }

    return ClipOval(
      child: SafeNetworkImage(
        url: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: Container(width: size, height: size, color: subtle),
        errorWidget: Container(
          width: size,
          height: size,
          color: subtle,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(
    Map<String, dynamic> message,
    bool mine, {
    required Map<String, dynamic>? senderMap,
  }) {
    final isDeleted = message['isDeleted'] == true;
    final text = message['text']?.toString() ?? '';
    final mediaUrl = message['mediaUrl']?.toString() ?? '';

    final bg = mine ? const Color(0xFF7C3AED) : Theme.of(context).cardColor;
    final fg = mine
        ? Colors.white
        : Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final border =
        mine ? Colors.transparent : Colors.black.withValues(alpha: 0.06);

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: isDeleted
          ? Text(
              'Message unsent',
              style: TextStyle(
                color: fg.withValues(alpha: 0.75),
                fontStyle: FontStyle.italic,
              ),
            )
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
    );

    if (mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: bubble,
      );
    }

    final otherAvatarUrl = _avatarUrlFromUser(senderMap);
    final otherLabel = _labelFromUser(senderMap);
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _messageAvatar(
              label: otherLabel,
              size: 22,
              avatarUrl: otherAvatarUrl,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(child: bubble),
        ],
      ),
    );
  }

  String _formatCount(num n) {
    final value = n.toDouble();
    if (value >= 1000000000)
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Widget _conversationHeader({
    required String userId,
    required String username,
    required String avatarUrl,
  }) {
    final cs = Theme.of(context).colorScheme;
    final followersRaw =
        (_otherProfile?['followers_count'] ?? _otherProfile?['followersCount']);
    final postsRaw = (_otherProfile?['posts_count'] ??
        _otherProfile?['postsCount'] ??
        _otherProfile?['posts']);
    final followers = followersRaw is num
        ? followersRaw
        : (followersRaw is String ? num.tryParse(followersRaw) : null);
    final posts = postsRaw is num
        ? postsRaw
        : (postsRaw is String ? num.tryParse(postsRaw) : null);
    final stats = (followers != null && posts != null)
        ? '${_formatCount(followers)} followers • ${_formatCount(posts)} posts'
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          const SizedBox(height: 4),
          ClipOval(
            child: SafeNetworkImage(
              url: avatarUrl,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              placeholder: Container(
                width: 96,
                height: 96,
                color: cs.onSurface.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: Text(
                  username.isNotEmpty
                      ? username.characters.first.toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
              ),
              errorWidget: Container(
                width: 96,
                height: 96,
                color: cs.onSurface.withValues(alpha: 0.08),
                alignment: Alignment.center,
                child: Text(
                  username.isNotEmpty
                      ? username.characters.first.toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            username,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (stats != null) ...[
            const SizedBox(height: 6),
            Text(
              stats,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.70),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: userId.isEmpty
                  ? null
                  : () => Navigator.of(context).pushNamed('/profile/$userId'),
              style: OutlinedButton.styleFrom(
                backgroundColor: cs.onSurface.withValues(alpha: 0.06),
                foregroundColor: cs.onSurface,
                side: BorderSide(color: Colors.transparent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: const Text(
                'View profile',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
