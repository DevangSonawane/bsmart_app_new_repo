import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/chat_api.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../widgets/safe_network_image.dart';
import 'chat_conversation_screen.dart';

class MessagingScreen extends StatefulWidget {
  final String? initialConversationId;

  const MessagingScreen({super.key, this.initialConversationId});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  int _selectedTab = 0; // 0=All, 1=Unread, 2=Community

  final _chatApi = ChatApi();
  String? _currentUserId;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _conversations = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = await CurrentUser.id;
    if (!mounted) return;
    setState(() => _currentUserId = uid);
    await _load();
    if (!mounted) return;
    final cid = widget.initialConversationId;
    if (cid != null && cid.isNotEmpty) {
      final conv = _conversations.firstWhere(
        (c) => (c['_id']?.toString() ?? c['id']?.toString()) == cid,
        orElse: () => const <String, dynamic>{},
      );
      if (conv.isNotEmpty) {
        _openConversation(conv);
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _chatApi.getConversations();
      if (!mounted) return;
      data.sort((a, b) {
        final aAt = DateTime.tryParse((a['lastMessageAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = DateTime.tryParse((b['lastMessageAt'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });
      setState(() {
        _conversations = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTopTabs(context),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: DesignTokens.instaPink))
                  : _error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Icon(LucideIcons.circleAlert, color: Colors.redAccent),
                            const SizedBox(height: 8),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                onPressed: _load,
                                icon: const Icon(LucideIcons.refreshCw, size: 16),
                                label: const Text('Retry'),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _filteredConversations().length,
                          itemBuilder: (context, index) {
                            final conv = _filteredConversations()[index];
                            return _conversationTile(conv);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filteredConversations() {
    final list = _conversations;
    if (_selectedTab == 1) {
      return list
          .where((c) => ((c['unreadCount'] as num?)?.toInt() ?? 0) > 0)
          .toList();
    }
    if (_selectedTab == 2) {
      return list.where((c) => c['isCommunity'] == true || c['type']?.toString() == 'community').toList();
    }
    return list;
  }

  Widget _buildTopTabs(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final requestColor = (theme.textTheme.bodySmall?.color ??
            (isDark ? Colors.white : Colors.black))
        .withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _tabButton(context, label: 'All', index: 0),
                _tabButton(context, label: 'Unread', index: 1),
                _tabButton(context, label: 'Community', index: 2),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              const Expanded(child: SizedBox.shrink()),
              Expanded(
                child: Center(
                  child: Text(
                    'Requests',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: requestColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabButton(
    BuildContext context, {
    required String label,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? DesignTokens.instaPink : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _otherParticipant(Map<String, dynamic> conversation) {
    final uid = _currentUserId;
    final participants = conversation['participants'];
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

  String _userName(Map<String, dynamic>? user) {
    if (user == null) return 'User';
    return (user['full_name'] ?? user['name'] ?? user['username'] ?? 'User').toString();
  }

  String? _avatar(Map<String, dynamic>? user) {
    if (user == null) return null;
    return (user['avatar_url'] ?? user['avatarUrl'] ?? user['profile_pic'] ?? user['profilePic'])?.toString();
  }

  String _preview(Map<String, dynamic>? lastMessage, bool mine, String name) {
    if (lastMessage == null || lastMessage.isEmpty) return 'Start chatting';
    if (lastMessage['isDeleted'] == true) return 'Message unsent';
    final text = lastMessage['text']?.toString() ?? '';
    if (text.isNotEmpty) return mine ? 'You: $text' : text;
    final mediaUrl = lastMessage['mediaUrl']?.toString() ?? '';
    if (mediaUrl.isNotEmpty) return mine ? 'You sent an attachment.' : '$name sent an attachment.';
    return 'Start chatting';
  }

  void _openConversation(Map<String, dynamic> conversation) {
    final id = (conversation['_id'] ?? conversation['id'])?.toString();
    if (id == null || id.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          conversationId: id,
          initialConversation: conversation,
        ),
      ),
    );
  }

  Widget _conversationTile(Map<String, dynamic> conversation) {
    final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
    final isCommunity = conversation['isCommunity'] == true || conversation['type']?.toString() == 'community';
    final other = _otherParticipant(conversation);
    final name = isCommunity ? (conversation['name']?.toString() ?? 'Community') : _userName(other);
    final avatarUrl = isCommunity ? null : _avatar(other);

    final lastMessage = conversation['lastMessage'] is Map
        ? Map<String, dynamic>.from(conversation['lastMessage'] as Map)
        : null;
    final uid = _currentUserId ?? '';
    final sender = lastMessage?['sender'];
    final senderId = (sender is Map ? (sender['_id'] ?? sender['id'] ?? sender['user_id']) : sender)?.toString();
    final mine = senderId != null && senderId.isNotEmpty && senderId == uid;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openConversation(conversation),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                  ClipOval(
                    child: SafeNetworkImage(url: avatarUrl, width: 44, height: 44, fit: BoxFit.cover),
                  )
                else
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isCommunity ? DesignTokens.instaOrange : DesignTokens.instaPink,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _preview(lastMessage, mine, name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                                  Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(conversation['lastMessageAt']?.toString()),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DesignTokens.instaPink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final m = local.minute.toString().padLeft(2, '0');
      final ap = local.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ap';
    }
    if (local.year == now.year) {
      return '${local.day}/${local.month}';
    }
    return '${local.day}/${local.month}/${local.year}';
  }
}
