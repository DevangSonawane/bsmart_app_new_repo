import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/app_error_handler.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/chat_api.dart';
import '../api/follows_api.dart';
import '../models/media_model.dart';
import '../screens/create_upload_screen.dart';
import '../screens/new_group_chat_screen.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../utils/share_links.dart';
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => ShareContentModal(
        contentType: contentType,
        contentId: contentId,
      ),
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

  String get _shareUrl => ShareLinks.urlForContent(
        contentType: widget.contentType,
        contentId: widget.contentId,
      );

  Future<void> _copyLink() async {
    final url = _shareUrl.trim();
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _shareToSystem() async {
    final url = _shareUrl.trim();
    if (url.isEmpty) return;
    await Share.share(url);
  }

  Future<void> _shareToWhatsApp() async {
    final url = _shareUrl.trim();
    if (url.isEmpty) return;
    final wa = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(url)}');
    final ok = await launchUrl(wa, mode: LaunchMode.externalApplication);
    if (!ok) await Share.share(url);
  }

  Future<void> _addToStory() async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    rootNav.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootNav.push(
        MaterialPageRoute(
          builder: (_) => const CreateUploadScreen(
            initialMode: UploadMode.story,
          ),
        ),
      );
    });
  }

  Future<void> _openNewGroup() async {
    if (_submitting) return;
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewGroupChatScreen(suggestedUsers: _followingUsers),
      ),
    );
    if (!mounted) return;
    if (res is! Map) return;
    final conversation = Map<String, dynamic>.from(res);
    final id = _conversationId(conversation);
    if (id.isEmpty) return;

    setState(() {
      _conversations = [
        conversation,
        ..._conversations.where((c) => _conversationId(c) != id),
      ];
      _selectedConversationIds.add(id);
      _loadingConversations = false;
    });
    unawaited(_refreshOnlineUsers());
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
    final status =
        _normalizeId(c['requestStatus'] ?? c['request_status']).toLowerCase();
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
    } catch (e, st) {
      AppErrorHandler.logError('share-content', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorHandler.userMessage(
              e,
              fallback: 'Failed to share content',
            ),
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
    final targets = _displayTargets();

    final size = MediaQuery.sizeOf(context);
    final sheetHeight = (size.height * 0.62).clamp(420.0, size.height * 0.82);
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final footerBottomPadding = 12.0 + safeBottom;
    const footerContentHeight = 96.0;
    const footerTopPadding = 12.0;
    final footerTotalHeight =
        footerContentHeight + footerTopPadding + footerBottomPadding;

    return Material(
      color: Colors.transparent,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: viewInsetsBottom),
        child: Container(
          height: sheetHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1E28),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252B36),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.search,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Search',
                                      hintStyle: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.50),
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
                                      child: Icon(
                                        LucideIcons.x,
                                        size: 16,
                                        color: Colors.white
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: _openNewGroup,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF252B36),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.userPlus,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Builder(
                        builder: (context) {
                          if (_loadingUsers || _loadingConversations) {
                            return Center(
                              child: Text(
                                'Loading...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          if (targets.isEmpty) {
                            return Center(
                              child: Text(
                                'No results found.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              int crossAxisCount = 3;
                              if (width >= 520) crossAxisCount = 4;
                              if (width >= 640) crossAxisCount = 5;
                              return GridView.builder(
                                padding: EdgeInsets.only(
                                  bottom: _selectedTotal == 0 ? 8 : (8 + 56),
                                ),
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
                                                      color: const Color(
                                                          0xFF38D430),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: const Color(
                                                            0xFF1A1E28),
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
                                                      color: const Color(
                                                          0xFF2A2F9F),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: const Color(
                                                            0xFF1A1E28),
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: const Icon(
                                                      LucideIcons.check,
                                                      size: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          t.label,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      footerTopPadding,
                      12,
                      footerBottomPadding,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151922),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      height: footerContentHeight,
                      child: Row(
                        children: [
                          Expanded(
                            child: _FooterAction(
                              label: 'Share to...',
                              icon: LucideIcons.share2,
                              onTap: _shareToSystem,
                            ),
                          ),
                          Expanded(
                            child: _FooterAction(
                              label: 'Add to Glimpse',
                              icon: LucideIcons.plus,
                              onTap: _addToStory,
                            ),
                          ),
                          Expanded(
                            child: _FooterAction(
                              label: 'Copy link',
                              icon: LucideIcons.link,
                              onTap: _copyLink,
                            ),
                          ),
                          Expanded(
                            child: _FooterAction(
                              label: 'WhatsApp',
                              faIcon: FontAwesomeIcons.whatsapp,
                              color: const Color(0xFF25D366),
                              onTap: _shareToWhatsApp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedTotal > 0)
                Positioned(
                  right: 16,
                  bottom: footerTotalHeight + 12,
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _send,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.instaPink,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.white.withValues(alpha: 0.12),
                      disabledForegroundColor:
                          Colors.white.withValues(alpha: 0.60),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.35),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.send, size: 16),
                    label: Text(
                        _submitting ? 'Sending...' : 'Send ($_selectedTotal)'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ShareTargetType { user, conversation }

class _FooterAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? faIcon;
  final Color? color;
  final VoidCallback onTap;

  const _FooterAction({
    required this.label,
    required this.onTap,
    this.icon,
    this.faIcon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF252B36),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(
              child: faIcon != null
                  ? FaIcon(faIcon, color: iconColor, size: 22)
                  : Icon(icon, color: iconColor, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        (conversation?['isGroup'] == true ||
            conversation?['is_group'] == true)) {
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
