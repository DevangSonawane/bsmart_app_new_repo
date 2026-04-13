import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/auth_api.dart';
import '../api/api_client.dart';
import '../api/chat_api.dart';
import '../services/supabase_service.dart';
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
  int _selectedFilter = 0; // 0=Primary, 1=Unread, 2=Community, 3=Requests

  final _chatApi = ChatApi();
  final _supabase = SupabaseService();
  String? _currentUserId;
  String? _currentUserName;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _conversations = const [];

  @override
  void initState() {
    super.initState();
    _init();
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q == _searchQuery) return;
      setState(() => _searchQuery = q);
    });
  }

  Future<void> _init() async {
    final uid = await CurrentUser.id;
    if (!mounted) return;
    setState(() => _currentUserId = uid);
    await Future.wait([_loadMe(), _load()]);
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

  Future<void> _loadMe() async {
    try {
      final token = await ApiClient().getToken();
      if (token != null && token.isNotEmpty) {
        final payload = JwtDecoder.decode(token);
        final fromToken = (payload['username'] ??
                payload['user_name'] ??
                payload['userName'] ??
                payload['handle'] ??
                payload['name'] ??
                payload['full_name'] ??
                payload['fullName'])
            ?.toString()
            .trim();
        if (fromToken != null && fromToken.isNotEmpty) {
          if (!mounted) return;
          setState(() => _currentUserName = fromToken);
        }
      }
    } catch (_) {
      // Ignore.
    }

    try {
      final raw = await AuthApi().me();
      if (!mounted) return;
      final me = _normalizeMe(raw);
      final name = (me['username'] ??
              me['user_name'] ??
              me['userName'] ??
              me['handle'] ??
              me['full_name'] ??
              me['fullName'] ??
              me['name'])
          ?.toString()
          .trim();
      if (name != null && name.isNotEmpty) {
        setState(() => _currentUserName = name);
      }
    } catch (_) {
      // Ignore and fall back to a generic title.
    }

    final uid = _currentUserId?.trim();
    if (uid != null &&
        uid.isNotEmpty &&
        (_currentUserName == null || _currentUserName!.trim().isEmpty)) {
      try {
        final me = await _supabase.getUserById(uid);
        if (!mounted) return;
        final name = (me?['username'] ??
                me?['user_name'] ??
                me?['userName'] ??
                me?['handle'] ??
                me?['full_name'] ??
                me?['fullName'] ??
                me?['name'])
            ?.toString()
            .trim();
        if (name != null && name.isNotEmpty) {
          setState(() => _currentUserName = name);
        }
      } catch (_) {}
    }
  }

  Map<String, dynamic> _normalizeMe(dynamic raw) {
    if (raw is! Map) return const <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    if (map['user'] is Map) {
      return Map<String, dynamic>.from(map['user'] as Map);
    }
    if (map['data'] is Map) {
      final data = Map<String, dynamic>.from(map['data'] as Map);
      if (data['user'] is Map) {
        return Map<String, dynamic>.from(data['user'] as Map);
      }
      return data;
    }
    return map;
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
        final aAt = DateTime.tryParse((a['lastMessageAt'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = DateTime.tryParse((b['lastMessageAt'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _currentUserName?.trim().isNotEmpty == true
        ? _currentUserName!.trim()
        : '...';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSearchBar(context),
                ),
                const SizedBox(height: 12),
                _buildActiveUsersRow(context),
                const SizedBox(height: 12),
                _buildFilterToggles(context),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: DesignTokens.instaPink))
                  : _error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Icon(LucideIcons.circleAlert,
                                color: Colors.redAccent),
                            const SizedBox(height: 8),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton.icon(
                                onPressed: _load,
                                icon:
                                    const Icon(LucideIcons.refreshCw, size: 16),
                                label: const Text('Retry'),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
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
    var list = _conversations;

    if (_selectedFilter == 0) {
      list = list.where((c) => !_isCommunity(c) && !_isRequest(c)).toList();
    } else if (_selectedFilter == 1) {
      list = list
          .where((c) => ((c['unreadCount'] as num?)?.toInt() ?? 0) > 0)
          .toList();
    } else if (_selectedFilter == 2) {
      list = list.where(_isCommunity).toList();
    } else if (_selectedFilter == 3) {
      list = list.where(_isRequest).toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) => _conversationSearchText(c).contains(q)).toList();
    }

    return list;
  }

  bool _isCommunity(Map<String, dynamic> conversation) {
    return conversation['isCommunity'] == true ||
        conversation['type']?.toString().toLowerCase() == 'community';
  }

  bool _isRequest(Map<String, dynamic> conversation) {
    final type = conversation['type']?.toString().toLowerCase();
    final folder = conversation['folder']?.toString().toLowerCase();
    final category = conversation['category']?.toString().toLowerCase();
    final isRequest = conversation['isRequest'] == true ||
        conversation['is_request'] == true ||
        conversation['request'] == true ||
        type == 'request' ||
        folder == 'requests' ||
        category == 'requests';
    if (isRequest) return true;
    final approved = conversation['isApproved'];
    if (approved is bool && approved == false) return true;
    return false;
  }

  String _conversationSearchText(Map<String, dynamic> conversation) {
    final isCommunity = _isCommunity(conversation);
    final other = _otherParticipant(conversation);
    final name = isCommunity
        ? (conversation['name']?.toString() ?? 'Community')
        : _userName(other);
    final lastMessage = conversation['lastMessage'] is Map
        ? Map<String, dynamic>.from(conversation['lastMessage'] as Map)
        : null;
    final text = lastMessage?['text']?.toString() ?? '';
    return '$name $text'.toLowerCase();
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search,
              size: 18, color: theme.iconTheme.color?.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (_searchQuery.trim().isNotEmpty)
            InkWell(
              onTap: () => _searchController.clear(),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(LucideIcons.x,
                    size: 16,
                    color: theme.iconTheme.color?.withValues(alpha: 0.7)),
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _activeUsers() {
    final uid = _currentUserId;
    final seen = <String>{};
    final users = <Map<String, dynamic>>[];
    for (final conv in _conversations) {
      if (_isCommunity(conv) || _isRequest(conv)) continue;
      final other = _otherParticipant(conv);
      if (other == null) continue;
      final id = (other['_id'] ?? other['id'] ?? other['user_id'])?.toString();
      if (id == null || id.isEmpty) continue;
      if (uid != null && uid.isNotEmpty && id == uid) continue;
      if (seen.add(id)) users.add(other);
      if (users.length >= 12) break;
    }
    return users;
  }

  Widget _buildActiveUsersRow(BuildContext context) {
    final users = _activeUsers();
    if (users.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final user = users[index];
          final name = _userName(user);
          final avatarUrl = _avatar(user);
          return InkWell(
            onTap: () {
              final userId =
                  (user['_id'] ?? user['id'] ?? user['user_id'])?.toString();
              if (userId == null || userId.isEmpty) return;
              final existing = _conversations.firstWhere(
                (c) {
                  final other = _otherParticipant(c);
                  final oid =
                      (other?['_id'] ?? other?['id'] ?? other?['user_id'])
                          ?.toString();
                  return oid == userId;
                },
                orElse: () => const <String, dynamic>{},
              );
              if (existing.isNotEmpty) _openConversation(existing);
            },
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 62,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                        ClipOval(
                          child: SafeNetworkImage(
                            url: avatarUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: DesignTokens.instaPink,
                          child: Text(
                            name.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC71),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterToggles(BuildContext context) {
    const labels = ['Primary', 'Unread', 'Community', 'Requests'];
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final track = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2);

    return SizedBox(
      height: 34,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < labels.length; index++) ...[
                      if (index > 0) const SizedBox(width: 8),
                      InkWell(
                        onTap: () => setState(() => _selectedFilter = index),
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedFilter == index
                                ? DesignTokens.instaPink
                                : track,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: _selectedFilter == index
                                  ? Colors.white
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
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
      if (id != null && id.isNotEmpty && id != uid) {
        return Map<String, dynamic>.from(p);
      }
    }
    final p0 = participants.first;
    return p0 is Map ? Map<String, dynamic>.from(p0) : null;
  }

  String _userName(Map<String, dynamic>? user) {
    if (user == null) return 'User';
    return (user['full_name'] ?? user['name'] ?? user['username'] ?? 'User')
        .toString();
  }

  String? _avatar(Map<String, dynamic>? user) {
    if (user == null) return null;
    return (user['avatar_url'] ??
            user['avatarUrl'] ??
            user['profile_pic'] ??
            user['profilePic'])
        ?.toString();
  }

  String _preview(Map<String, dynamic>? lastMessage, bool mine, String name) {
    if (lastMessage == null || lastMessage.isEmpty) return 'Start chatting';
    if (lastMessage['isDeleted'] == true) return 'Message unsent';
    final text = lastMessage['text']?.toString() ?? '';
    if (text.isNotEmpty) return mine ? 'You: $text' : text;
    final mediaUrl = lastMessage['mediaUrl']?.toString() ?? '';
    if (mediaUrl.isNotEmpty) {
      return mine ? 'You sent an attachment.' : '$name sent an attachment.';
    }
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
    final isCommunity = _isCommunity(conversation);
    final other = _otherParticipant(conversation);
    final name = isCommunity
        ? (conversation['name']?.toString() ?? 'Community')
        : _userName(other);
    final avatarUrl = isCommunity ? null : _avatar(other);

    final lastMessage = conversation['lastMessage'] is Map
        ? Map<String, dynamic>.from(conversation['lastMessage'] as Map)
        : null;
    final uid = _currentUserId ?? '';
    final sender = lastMessage?['sender'];
    final senderId = (sender is Map
            ? (sender['_id'] ?? sender['id'] ?? sender['user_id'])
            : sender)
        ?.toString();
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
                    child: SafeNetworkImage(
                        url: avatarUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover),
                  )
                else
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isCommunity
                        ? DesignTokens.instaOrange
                        : DesignTokens.instaPink,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
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
                        color: Theme.of(context).textTheme.bodySmall?.color ??
                            Colors.grey,
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
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
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
