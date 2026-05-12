import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/auth_api.dart';
import '../api/api_client.dart';
import '../api/chat_api.dart';
import '../services/chat_socket_service.dart';
import '../services/supabase_service.dart';
import '../services/chat_unread_service.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../widgets/safe_network_image.dart';
import 'chat_conversation_screen.dart';
import 'group_chat_conversation_screen.dart';
import 'new_group_chat_screen.dart';

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
  bool _onlineLoading = false;
  String? _error;
  List<Map<String, dynamic>> _normalConversations = const [];
  List<Map<String, dynamic>> _requestConversations = const [];
  Set<String> _onlineUserIds = const <String>{};
  final ChatSocketService _chatSocket = ChatSocketService();
  Timer? _socketRefreshDebounce;
  SocketHandler? _onSocketNewMessage;
  SocketHandler? _onSocketOnlineUsers;

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

  @override
  void dispose() {
    _socketRefreshDebounce?.cancel();
    if (_onSocketNewMessage != null) {
      _chatSocket.off('new-message', _onSocketNewMessage!);
    }
    if (_onSocketOnlineUsers != null) {
      _chatSocket.off('online-users-updated', _onSocketOnlineUsers!);
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = await CurrentUser.id;
    if (!mounted) return;
    setState(() => _currentUserId = uid);
    await Future.wait([_loadMe(), _loadNormal()]);
    await _initSocket();
    await _refreshOnlineUsers();
    if (!mounted) return;
    final cid = widget.initialConversationId;
    if (cid != null && cid.isNotEmpty) {
      var conv = _normalConversations.firstWhere(
        (c) => (c['_id']?.toString() ?? c['id']?.toString()) == cid,
        orElse: () => const <String, dynamic>{},
      );
      if (conv.isEmpty) {
        try {
          await _loadRequests();
          if (!mounted) return;
          conv = _requestConversations.firstWhere(
            (c) => (c['_id']?.toString() ?? c['id']?.toString()) == cid,
            orElse: () => const <String, dynamic>{},
          );
        } catch (_) {
          // Ignore.
        }
      }
      if (conv.isNotEmpty) {
        _openConversation(conv);
      }
    }
  }

  Future<void> _initSocket() async {
    final token = await ApiClient().getToken();
    final uid = (_currentUserId ?? '').trim();
    if (token == null || token.trim().isEmpty) return;
    _chatSocket.connect(token: token, userId: uid.isEmpty ? null : uid);

    _onSocketNewMessage ??= (data) {
      // Robust approach: debounce and refresh lists from REST.
      _socketRefreshDebounce?.cancel();
      _socketRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        unawaited(_refreshAll());
      });
    };
    _chatSocket.on('new-message', _onSocketNewMessage!);

    _onSocketOnlineUsers ??= (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final list = map['onlineUserIds'] ??
            map['online_user_ids'] ??
            map['users'] ??
            map['items'] ??
            map['data'];
        if (list is List) {
          final next = list
              .map((e) => e?.toString().trim() ?? '')
              .where((e) => e.isNotEmpty)
              .toSet();
          if (mounted) setState(() => _onlineUserIds = next);
          return;
        }
      }
    };
    _chatSocket.on('online-users-updated', _onSocketOnlineUsers!);
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

  List<Map<String, dynamic>> _currentConversations() {
    return _selectedFilter == 3 ? _requestConversations : _normalConversations;
  }

  List<Map<String, dynamic>> _sortByLastMessageAt(
      List<Map<String, dynamic>> data) {
    data.sort((a, b) {
      final aAt = DateTime.tryParse((a['lastMessageAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bAt = DateTime.tryParse((b['lastMessageAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bAt.compareTo(aAt);
    });
    return data;
  }

  Future<void> _loadNormal({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _chatApi.getConversations(type: 'normal');
      if (!mounted) return;
      _sortByLastMessageAt(data);
      setState(() => _normalConversations = data);
      if (showLoading) setState(() => _loading = false);
      ChatUnreadService().setFromConversations(data);
      _refreshOnlineUsers();
    } catch (e) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRequests({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await _chatApi.getConversations(type: 'requests');
      if (!mounted) return;
      _sortByLastMessageAt(data);
      setState(() => _requestConversations = data);
      if (showLoading) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      if (showLoading) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadCurrent() async {
    if (_selectedFilter == 3) {
      await _loadRequests();
      return;
    }
    await _loadNormal();
  }

  Future<void> _refreshAll() async {
    if (_selectedFilter == 3) {
      await Future.wait([
        _loadNormal(showLoading: false),
        _loadRequests(showLoading: true),
      ]);
      return;
    }
    await _loadNormal();
  }

  Future<void> _refreshOnlineUsers() async {
    if (_onlineLoading) return;
    final ids = _candidateOnlineUserIds().toList();
    if (ids.isEmpty) {
      if (!mounted) return;
      setState(() => _onlineUserIds = const <String>{});
      return;
    }

    if (mounted) setState(() => _onlineLoading = true);
    try {
      final list = await _chatApi.getOnlineUsers(ids: ids);
      if (!mounted) return;
      setState(() => _onlineUserIds = list.toSet());
    } catch (_) {
      // Best-effort: keep previous value on failure.
    } finally {
      if (mounted) setState(() => _onlineLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _currentUserName?.trim().isNotEmpty == true
        ? _currentUserName!.trim()
        : '...';
    final visibleConversations = _filteredConversations();
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'New group chat',
            icon: const Icon(LucideIcons.users),
            onPressed: () async {
              final res = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NewGroupChatScreen(
                    suggestedUsers: _activeUsers(),
                  ),
                ),
              );
              if (!mounted) return;
              if (res is Map) {
                _openConversation(Map<String, dynamic>.from(res));
                return;
              }
              _loadNormal();
            },
          ),
        ],
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
              onRefresh: _refreshAll,
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
                                onPressed: _loadCurrent,
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
                          itemCount: visibleConversations.isEmpty
                              ? 1
                              : visibleConversations.length,
                          itemBuilder: (context, index) {
                            if (visibleConversations.isEmpty) {
                              final q = _searchQuery.trim();
                              final msg = q.isNotEmpty
                                  ? 'No results for "$q"'
                                  : _selectedFilter == 3
                                      ? 'No message requests'
                                      : 'No conversations yet';
                              return Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 80, 16, 24),
                                child: Center(
                                  child: Text(
                                    msg,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withValues(alpha: 0.7) ??
                                          Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final conv = visibleConversations[index];
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
    var list = _currentConversations();

    if (_selectedFilter == 0) {
      // Primary conversations: backend already returns `type=normal` by default.
      // Avoid over-filtering based on `isRequest`, since the new API includes
      // request metadata fields on the conversation object.
      list = list.where((c) => !_isCommunity(c)).toList();
    } else if (_selectedFilter == 1) {
      list = list
          .where((c) => ((c['unreadCount'] as num?)?.toInt() ?? 0) > 0)
          .toList();
    } else if (_selectedFilter == 2) {
      list = list.where(_isCommunity).toList();
    } else if (_selectedFilter == 3) {
      // Requests tab: backend is queried with `type=requests`, but keep a
      // best-effort local guard in case the server returns mixed results.
      list = list.where(_isRequest).toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) => _conversationSearchText(c).contains(q)).toList();
    }

    return _reorderToMatchActiveHeader(list);
  }

  bool _isCommunity(Map<String, dynamic> conversation) {
    return conversation['isCommunity'] == true ||
        conversation['type']?.toString().toLowerCase() == 'community';
  }

  bool _isGroup(Map<String, dynamic> conversation) {
    final explicit = conversation['isGroup'] ?? conversation['is_group'];
    if (explicit is bool) return explicit;
    final name = (conversation['groupName'] ?? conversation['group_name'])
        ?.toString()
        .trim();
    if (name != null && name.isNotEmpty) return true;
    return conversation['groupAdmin'] != null ||
        conversation['group_admin'] != null;
  }

  bool _isRequest(Map<String, dynamic> conversation) {
    final status = (conversation['requestStatus'] ??
            conversation['request_status'] ??
            conversation['requestState'] ??
            conversation['request_state'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (status == 'pending' || status == 'requested') return true;

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
    final isGroup = _isGroup(conversation);
    final other = _otherParticipant(conversation);
    final name = isCommunity
        ? (conversation['name']?.toString() ?? 'Community')
        : isGroup
            ? (conversation['groupName'] ??
                    conversation['group_name'] ??
                    'Group')
                .toString()
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
    for (final conv in _normalConversations) {
      if (_isCommunity(conv) || _isRequest(conv)) continue;
      final other = _otherParticipant(conv);
      if (other == null) continue;
      final id = _userId(other);
      if (id == null || id.isEmpty) continue;
      if (uid != null && uid.isNotEmpty && id == uid) continue;
      if (seen.add(id)) users.add(other);
      if (users.length >= 12) break;
    }
    return users;
  }

  List<Map<String, dynamic>> _onlineActiveUsers() {
    final online = _onlineUserIds;
    if (online.isEmpty) return const <Map<String, dynamic>>[];
    final users = _activeUsers();
    return users.where((u) {
      final id = _userId(u);
      return id != null && id.isNotEmpty && online.contains(id);
    }).toList();
  }

  Set<String> _candidateOnlineUserIds() {
    final out = <String>{};
    final uid = _currentUserId?.trim();
    for (final conv in _normalConversations) {
      if (_isCommunity(conv) || _isRequest(conv) || _isGroup(conv)) continue;
      final other = _otherParticipant(conv);
      final id = _userId(other);
      if (id == null || id.isEmpty) continue;
      if (uid != null && uid.isNotEmpty && id == uid) continue;
      out.add(id);
    }
    return out;
  }

  List<Map<String, dynamic>> _reorderToMatchActiveHeader(
      List<Map<String, dynamic>> list) {
    final orderedOnlineIds = <String>[];
    for (final u in _onlineActiveUsers()) {
      final id = _userId(u);
      if (id != null && id.isNotEmpty) orderedOnlineIds.add(id);
    }
    if (orderedOnlineIds.isEmpty) return list;
    final orderedOnlineSet = orderedOnlineIds.toSet();

    final buckets = <String, List<Map<String, dynamic>>>{};
    final remaining = <Map<String, dynamic>>[];

    for (final conv in list) {
      final other = _otherParticipant(conv);
      final otherId = _userId(other);
      if (otherId != null &&
          otherId.isNotEmpty &&
          orderedOnlineSet.contains(otherId)) {
        (buckets[otherId] ??= <Map<String, dynamic>>[]).add(conv);
      } else {
        remaining.add(conv);
      }
    }

    final out = <Map<String, dynamic>>[];
    for (final id in orderedOnlineIds) {
      final bucket = buckets[id];
      if (bucket != null && bucket.isNotEmpty) out.addAll(bucket);
    }
    out.addAll(remaining);
    return out;
  }

  Widget _buildActiveUsersRow(BuildContext context) {
    final all = _activeUsers();
    if (all.isEmpty) return const SizedBox.shrink();

    final users = _onlineActiveUsers();
    if (users.isEmpty) {
      return SizedBox(
        height: 52,
        child: Center(
          child: Text(
            _onlineLoading
                ? 'Checking who’s online…'
                : 'No one online right now',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withValues(alpha: 0.65) ??
                      Colors.grey,
                ),
          ),
        ),
      );
    }

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
          final id = _userId(user);
          final online = id != null && _onlineUserIds.contains(id);
          return InkWell(
            onTap: () {
              final userId = _userId(user);
              if (userId == null || userId.isEmpty) return;
              final existing = _normalConversations.firstWhere(
                (c) {
                  final other = _otherParticipant(c);
                  final oid = _userId(other);
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
                      if (online)
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
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
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
                        onTap: () {
                          if (_selectedFilter == index) return;
                          setState(() => _selectedFilter = index);
                          _loadCurrent();
                        },
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

  String? _userId(Map<String, dynamic>? user) {
    if (user == null) return null;
    return (user['_id'] ?? user['id'] ?? user['user_id'] ?? user['userId'])
        ?.toString()
        .trim();
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
    final text = (lastMessage['text'] ?? '').toString().trim();
    if (text.isNotEmpty) return mine ? 'You: $text' : text;

    final mediaType = (lastMessage['mediaType'] ??
            lastMessage['media_type'] ??
            lastMessage['type'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (mediaType == 'audio') {
      return mine
          ? 'You sent a voice message 🎤'
          : '$name sent you a voice message 🎤';
    }

    final mediaUrl = (lastMessage['mediaUrl'] ?? lastMessage['media_url'] ?? '')
        .toString()
        .trim();
    if (mediaUrl.isNotEmpty) {
      return mine ? 'You sent an attachment.' : '$name sent you an attachment.';
    }
    return 'Start chatting';
  }

  void _openConversation(Map<String, dynamic> conversation) {
    final id = (conversation['_id'] ??
            conversation['id'] ??
            conversation['conversationId'] ??
            conversation['conversation_id'])
        ?.toString();
    if (id == null || id.isEmpty) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => _isGroup(conversation)
                ? GroupChatConversationScreen(
                    conversationId: id,
                    initialConversation: conversation,
                  )
                : ChatConversationScreen(
                    conversationId: id,
                    initialConversation: conversation,
                  ),
          ),
        )
        .then((_) => _refreshAll());
  }

  Widget _conversationTile(Map<String, dynamic> conversation) {
    final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
    final isCommunity = _isCommunity(conversation);
    final isGroup = _isGroup(conversation);
    final other = _otherParticipant(conversation);
    final otherId = _userId(other);
    final showOnlineDot = !isCommunity &&
        !isGroup &&
        otherId != null &&
        otherId.isNotEmpty &&
        _onlineUserIds.contains(otherId);
    final name = isCommunity
        ? (conversation['name']?.toString() ?? 'Community')
        : isGroup
            ? ((conversation['groupName'] ?? conversation['group_name'])
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true
                ? (conversation['groupName'] ?? conversation['group_name'])
                    .toString()
                    .trim()
                : 'Group')
            : _userName(other);
    final avatarUrl = isCommunity
        ? null
        : isGroup
            ? (conversation['groupAvatar'] ??
                    conversation['group_avatar'] ??
                    '')
                .toString()
            : (_avatar(other) ?? '');

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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (isGroup &&
                        (avatarUrl == null || avatarUrl.trim().isEmpty))
                      _mergedGroupAvatar(conversation, 44)
                    else if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
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
                        backgroundColor: isCommunity
                            ? DesignTokens.instaOrange
                            : DesignTokens.instaPink,
                        child: Text(
                          (name.trim().isNotEmpty ? name.trim() : 'G')
                              .characters
                              .first
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (showOnlineDot)
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
                              color: Theme.of(context).cardColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
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

  Widget _mergedGroupAvatar(Map<String, dynamic> conversation, double size) {
    final borderColor = Theme.of(context).cardColor;
    final uid = (_currentUserId ?? '').trim();
    final raw = conversation['participants'];
    final participants = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const <Map<String, dynamic>>[];

    final others = participants
        .where((p) => (p['_id'] ?? p['id'] ?? p['user_id'])?.toString() != uid)
        .take(2)
        .toList();

    // Ensure we have 2 (fill from all if needed).
    while (others.length < 2 && participants.length > others.length) {
      final extra = participants.firstWhere(
        (p) => !others.contains(p),
        orElse: () => const <String, dynamic>{},
      );
      if (extra.isEmpty) break;
      others.add(extra);
    }

    Widget avatarCircle(Map<String, dynamic> user,
        {required double circleSize}) {
      final url = (user['avatar_url'] ?? user['avatarUrl'])?.toString().trim();
      final label = _userName(user).trim();
      return Container(
        width: circleSize,
        height: circleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: ClipOval(
          child: (url != null && url.isNotEmpty)
              ? SafeNetworkImage(
                  url: url,
                  width: circleSize,
                  height: circleSize,
                  fit: BoxFit.cover,
                )
              : CircleAvatar(
                  radius: circleSize / 2,
                  backgroundColor: DesignTokens.instaPink,
                  child: Text(
                    label.isNotEmpty
                        ? label.characters.first.toUpperCase()
                        : 'G',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: circleSize * 0.4,
                    ),
                  ),
                ),
        ),
      );
    }

    if (others.length <= 1) {
      final single =
          others.isNotEmpty ? others.first : const <String, dynamic>{};
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: avatarCircle(single, circleSize: size),
        ),
      );
    }

    final circleSize = size * 0.72;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: avatarCircle(others[0], circleSize: circleSize),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: avatarCircle(others[1], circleSize: circleSize),
          ),
        ],
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
