import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/chat_api.dart';
import '../api/follows_api.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../widgets/safe_network_image.dart';

class ShareContentModal extends StatefulWidget {
  final String contentType;
  final String contentId;

  const ShareContentModal({
    super.key,
    required this.contentType,
    required this.contentId,
  });

  static Future<void> show(
    BuildContext context, {
    required String contentType,
    required String contentId,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Share',
      barrierColor: Colors.black.withValues(alpha: 0.70),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, __) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: ShareContentModal(
              contentType: contentType,
              contentId: contentId,
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ShareContentModal> createState() => _ShareContentModalState();
}

class _ShareContentModalState extends State<ShareContentModal> {
  final _chatApi = ChatApi();
  final _followsApi = FollowsApi();
  final _searchController = TextEditingController();

  String _currentUserId = '';
  bool _loadingUsers = true;
  bool _loadingConversations = true;
  bool _submitting = false;

  List<Map<String, dynamic>> _followingUsers = const [];
  List<Map<String, dynamic>> _conversations = const [];
  Set<String> _onlineUserIds = const <String>{};

  final Set<String> _selectedUserIds = <String>{};
  final Set<String> _selectedConversationIds = <String>{};

  Timer? _onlineTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeId(dynamic v) => (v ?? '').toString().trim();

  String _userId(Map<String, dynamic>? u) =>
      _normalizeId(u?['_id'] ?? u?['id'] ?? u?['user_id'] ?? u?['userId']);

  String _userName(Map<String, dynamic>? u) {
    final name = _normalizeId(u?['full_name'] ?? u?['name']);
    if (name.isNotEmpty) return name;
    final username = _normalizeId(u?['username'] ?? u?['handle']);
    return username.isNotEmpty ? username : 'User';
  }

  String _userAvatar(Map<String, dynamic>? u) => _normalizeId(
        u?['avatar_url'] ??
            u?['profile_picture'] ??
            u?['profilePicture'] ??
            u?['profile_pic'] ??
            u?['avatarUrl'],
      );

  bool _isGroup(Map<String, dynamic> c) {
    final explicit = c['isGroup'] ?? c['is_group'];
    if (explicit is bool) return explicit;
    final name = _normalizeId(c['groupName'] ?? c['group_name']);
    if (name.isNotEmpty) return true;
    return c['groupAdmin'] != null || c['group_admin'] != null;
  }

  bool _isRequestConversation(Map<String, dynamic> c) {
    final status = _normalizeId(c['requestStatus'] ?? c['request_status'])
        .toLowerCase();
    if (status == 'pending' || status == 'requested') return true;
    final isRequest = c['isRequest'] == true ||
        c['is_request'] == true ||
        c['request'] == true ||
        _normalizeId(c['type']).toLowerCase() == 'request' ||
        _normalizeId(c['folder']).toLowerCase() == 'requests' ||
        _normalizeId(c['category']).toLowerCase() == 'requests';
    if (isRequest) return true;
    final approved = c['isApproved'];
    if (approved is bool && approved == false) return true;
    return false;
  }

  String _conversationId(Map<String, dynamic> c) =>
      _normalizeId(c['_id'] ?? c['id']);

  List<Map<String, dynamic>> _participants(Map<String, dynamic> c) {
    final raw = c['participants'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic>? _otherParticipant(Map<String, dynamic> c) {
    final participants = _participants(c);
    if (_currentUserId.isEmpty) {
      return participants.isNotEmpty ? participants.first : null;
    }
    for (final p in participants) {
      final id = _userId(p);
      if (id.isNotEmpty && id != _currentUserId) return p;
    }
    return participants.isNotEmpty ? participants.first : null;
  }

  String _conversationName(Map<String, dynamic> c) {
    if (_isGroup(c)) {
      final name = _normalizeId(c['groupName'] ?? c['group_name']);
      return name.isNotEmpty ? name : 'Group chat';
    }
    return _userName(_otherParticipant(c));
  }

  String _conversationAvatar(Map<String, dynamic> c) {
    if (_isGroup(c)) return _normalizeId(c['groupAvatar'] ?? c['group_avatar']);
    return _userAvatar(_otherParticipant(c));
  }

  String _conversationOnlineUserId(Map<String, dynamic> c) {
    if (_isGroup(c)) return '';
    return _userId(_otherParticipant(c));
  }

  Future<void> _init() async {
    final uid = (await CurrentUser.id)?.toString().trim() ?? '';
    if (!mounted) return;
    setState(() => _currentUserId = uid);

    await Future.wait([
      _loadFollowingUsers(),
      _loadConversations(),
    ]);
    await _refreshOnlineUsers();
    _onlineTimer?.cancel();
    _onlineTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_refreshOnlineUsers()),
    );
  }

  Future<void> _loadFollowingUsers() async {
    setState(() => _loadingUsers = true);
    try {
      if (_currentUserId.isEmpty) {
        setState(() {
          _followingUsers = const [];
          _loadingUsers = false;
        });
        return;
      }
      final res = await _followsApi.getFollowingPage(
        _currentUserId,
        page: 1,
        limit: 100,
      );
      final usersRaw = res['users'];
      final users = usersRaw is List
          ? usersRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _followingUsers = users;
        _loadingUsers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _followingUsers = const [];
        _loadingUsers = false;
      });
    }
  }

  Future<void> _loadConversations() async {
    setState(() => _loadingConversations = true);
    try {
      final list = await _chatApi.getConversations(type: 'normal');
      if (!mounted) return;

      final filtered = list.where((c) {
        final participants = _participants(c);
        if (participants.isEmpty) return false;
        if (_currentUserId.isNotEmpty) {
          final includesMe =
              participants.any((p) => _userId(p) == _currentUserId);
          if (!includesMe) return false;
        }
        if (_isRequestConversation(c)) {
          final requestedBy = c['requestedBy'];
          final requestedById = requestedBy is Map
              ? _normalizeId(requestedBy['_id'] ?? requestedBy['id'])
              : _normalizeId(requestedBy);
          if (_normalizeId(c['requestStatus'] ?? c['request_status'])
                  .toLowerCase() ==
              'pending') {
            if (requestedById.isNotEmpty && requestedById != _currentUserId) {
              return false;
            }
          }
        }
        if (_isGroup(c)) return true;
        return participants.length >= 2;
      }).toList();

      setState(() {
        _conversations = filtered;
        _loadingConversations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _conversations = const [];
        _loadingConversations = false;
      });
    }
  }

  Future<void> _refreshOnlineUsers() async {
    final ids = <String>{};
    for (final u in _followingUsers) {
      final id = _userId(u);
      if (id.isNotEmpty) ids.add(id);
    }
    for (final c in _conversations) {
      final id = _conversationOnlineUserId(c);
      if (id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) {
      if (!mounted) return;
      setState(() => _onlineUserIds = const <String>{});
      return;
    }

    try {
      final list = await _chatApi.getOnlineUsers(ids: ids.toList());
      if (!mounted) return;
      setState(() => _onlineUserIds = list.toSet());
    } catch (_) {
      if (!mounted) return;
      setState(() => _onlineUserIds = const <String>{});
    }
  }

  int get _selectedTotal =>
      _selectedUserIds.length + _selectedConversationIds.length;

  List<_ShareTarget> _displayTargets() {
    final q = _searchController.text.trim().toLowerCase();

    final conversations = q.isEmpty
        ? _conversations
        : _conversations
            .where((c) => _conversationName(c).toLowerCase().contains(q))
            .toList();
    final users = q.isEmpty
        ? _followingUsers
        : _followingUsers.where((u) {
            final username = _normalizeId(u['username']).toLowerCase();
            final name = _userName(u).toLowerCase();
            return username.contains(q) || name.contains(q);
          }).toList();

    final out = <_ShareTarget>[];
    for (final c in conversations) {
      final id = _conversationId(c);
      if (id.isEmpty) continue;
      out.add(
        _ShareTarget.conversation(
          id: id,
          conversation: c,
          label: _conversationName(c),
          avatarUrl: _conversationAvatar(c),
          onlineUserId: _conversationOnlineUserId(c),
          selected: _selectedConversationIds.contains(id),
        ),
      );
    }
    for (final u in users) {
      final id = _userId(u);
      if (id.isEmpty) continue;
      out.add(
        _ShareTarget.user(
          id: id,
          user: u,
          label: _normalizeId(u['username']).isNotEmpty
              ? _normalizeId(u['username'])
              : _userName(u),
          avatarUrl: _userAvatar(u),
          onlineUserId: id,
          selected: _selectedUserIds.contains(id),
        ),
      );
    }
    return out;
  }

  void _toggleTarget(_ShareTarget t) {
    if (t.type == _ShareTargetType.conversation) {
      setState(() {
        if (_selectedConversationIds.contains(t.id)) {
          _selectedConversationIds.remove(t.id);
        } else {
          _selectedConversationIds.add(t.id);
        }
      });
      return;
    }
    setState(() {
      if (_selectedUserIds.contains(t.id)) {
        _selectedUserIds.remove(t.id);
      } else {
        _selectedUserIds.add(t.id);
      }
    });
  }

  Future<void> _send() async {
    if (_selectedTotal == 0 || _submitting) return;
    setState(() => _submitting = true);
    try {
      await _chatApi.shareContentToUsers(
        contentType: widget.contentType,
        contentId: widget.contentId,
        recipientIds: _selectedUserIds.toList(),
        conversationIds: _selectedConversationIds.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shared'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception: ', '').trim().isEmpty
                ? 'Failed to share content'
                : e.toString().replaceAll('Exception: ', ''),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = MediaQuery.sizeOf(context).width;
    final maxWidth = w < 700 ? w - 32 : 600.0;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;
    final targets = _displayTargets();

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1F2430),
              Color(0xFF1A1E28),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Share',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF252B36),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.search,
                        size: 18, color: Colors.white.withValues(alpha: 0.55)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                      ),
                    ),
                    if (_searchController.text.trim().isNotEmpty)
                      InkWell(
                        onTap: () => _searchController.clear(),
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(LucideIcons.x,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    if (_loadingUsers || _loadingConversations)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        child: Text(
                          'Loading...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (!_loadingUsers &&
                        !_loadingConversations &&
                        targets.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22),
                        child: Text(
                          'No results found.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (!_loadingUsers &&
                        !_loadingConversations &&
                        targets.isNotEmpty)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          int crossAxisCount = 3;
                          if (width >= 520) crossAxisCount = 4;
                          if (width >= 640) crossAxisCount = 5;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.86,
                            ),
                            itemCount: targets.length,
                            itemBuilder: (context, index) {
                              final t = targets[index];
                              final online = t.onlineUserId.isNotEmpty &&
                                  _onlineUserIds.contains(t.onlineUserId);
                              return InkWell(
                                onTap: () => _toggleTarget(t),
                                borderRadius: BorderRadius.circular(18),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: 64,
                                      height: 64,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned.fill(
                                            child: _TargetAvatar(
                                              label: t.label,
                                              avatarUrl: t.avatarUrl,
                                              conversation: t.conversation,
                                              type: t.type,
                                              currentUserId: _currentUserId,
                                            ),
                                          ),
                                          if (online)
                                            Positioned(
                                              right: 2,
                                              bottom: 2,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF38D430),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF1A1E28),
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (t.selected)
                                            Positioned(
                                              right: -6,
                                              bottom: -6,
                                              child: Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF2A2F9F),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF1A1E28),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    LucideIcons.check,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Text(
                                        t.label,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.95),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2A),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed:
                      (_selectedTotal == 0 || _submitting) ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F58FF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF3A3F5D),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  icon: Icon(
                    LucideIcons.send,
                    size: 16,
                    color: (_selectedTotal == 0 || _submitting)
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.white,
                  ),
                  label: Text(
                    _submitting
                        ? 'Sharing...'
                        : 'Share ($_selectedTotal)',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ShareTargetType { user, conversation }

class _ShareTarget {
  final String id;
  final _ShareTargetType type;
  final String label;
  final String avatarUrl;
  final String onlineUserId;
  final bool selected;
  final Map<String, dynamic>? conversation;
  final Map<String, dynamic>? user;

  const _ShareTarget._({
    required this.id,
    required this.type,
    required this.label,
    required this.avatarUrl,
    required this.onlineUserId,
    required this.selected,
    required this.conversation,
    required this.user,
  });

  factory _ShareTarget.user({
    required String id,
    required Map<String, dynamic> user,
    required String label,
    required String avatarUrl,
    required String onlineUserId,
    required bool selected,
  }) {
    return _ShareTarget._(
      id: id,
      type: _ShareTargetType.user,
      label: label,
      avatarUrl: avatarUrl,
      onlineUserId: onlineUserId,
      selected: selected,
      conversation: null,
      user: user,
    );
  }

  factory _ShareTarget.conversation({
    required String id,
    required Map<String, dynamic> conversation,
    required String label,
    required String avatarUrl,
    required String onlineUserId,
    required bool selected,
  }) {
    return _ShareTarget._(
      id: id,
      type: _ShareTargetType.conversation,
      label: label,
      avatarUrl: avatarUrl,
      onlineUserId: onlineUserId,
      selected: selected,
      conversation: conversation,
      user: null,
    );
  }
}

class _TargetAvatar extends StatelessWidget {
  final String label;
  final String avatarUrl;
  final _ShareTargetType type;
  final Map<String, dynamic>? conversation;
  final String currentUserId;

  const _TargetAvatar({
    required this.label,
    required this.avatarUrl,
    required this.type,
    required this.conversation,
    required this.currentUserId,
  });

  String _normalizeId(dynamic v) => (v ?? '').toString().trim();

  String _userId(Map<String, dynamic>? u) =>
      _normalizeId(u?['_id'] ?? u?['id'] ?? u?['user_id'] ?? u?['userId']);

  String _userAvatar(Map<String, dynamic>? u) => _normalizeId(
        u?['avatar_url'] ??
            u?['profile_picture'] ??
            u?['profilePicture'] ??
            u?['profile_pic'] ??
            u?['avatarUrl'],
      );

  List<Map<String, dynamic>> _participants(Map<String, dynamic> c) {
    final raw = c['participants'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic>? _otherParticipant(Map<String, dynamic> c) {
    final participants = _participants(c);
    if (currentUserId.trim().isEmpty) {
      return participants.isNotEmpty ? participants.first : null;
    }
    for (final p in participants) {
      final id = _userId(p);
      if (id.isNotEmpty && id != currentUserId) return p;
    }
    return participants.isNotEmpty ? participants.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final base = avatarUrl.trim();
    final initial = label.trim().isNotEmpty
        ? label.trim().characters.first.toUpperCase()
        : 'U';

    Widget circle({required String url, required String label, double? size}) {
      final s = size ?? 64;
      if (url.trim().isEmpty) {
        return Container(
          width: s,
          height: s,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label.trim().isNotEmpty
                ? label.trim().characters.first.toUpperCase()
                : 'U',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: s * 0.34,
            ),
          ),
        );
      }
      return ClipOval(
        child: SafeNetworkImage(
          url: url,
          width: s,
          height: s,
          fit: BoxFit.cover,
        ),
      );
    }

    if (type == _ShareTargetType.conversation &&
        (conversation?['isGroup'] == true || conversation?['is_group'] == true)) {
      final conv = conversation!;
      final members = _participants(conv)
          .where((p) => _userId(p) != currentUserId)
          .toList();
      final a = members.isNotEmpty ? members.first : null;
      final b = members.length > 1 ? members[1] : null;
      final primary = _normalizeId(conv['groupAvatar'] ?? conv['group_avatar']);
      final primaryUrl = primary.isNotEmpty ? primary : _userAvatar(a);
      final secondaryUrl = _userAvatar(b);

      return Stack(
        clipBehavior: Clip.none,
        children: [
          circle(url: primaryUrl, label: label),
          if (b != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1A1E28), width: 2),
                ),
                child: circle(url: secondaryUrl, label: _userId(b), size: 24),
              ),
            ),
        ],
      );
    }

    return circle(url: base, label: initial);
  }
}

