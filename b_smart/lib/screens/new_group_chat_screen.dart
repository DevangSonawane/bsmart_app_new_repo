import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/follows_api.dart';
import '../api/chat_api.dart';
import '../api/users_api.dart';
import '../theme/design_tokens.dart';
import '../theme/instagram_theme.dart';
import '../utils/app_error_handler.dart';
import '../utils/current_user.dart';
import '../widgets/safe_network_image.dart';

class NewGroupChatScreen extends StatefulWidget {
  final List<Map<String, dynamic>> suggestedUsers;

  const NewGroupChatScreen({
    super.key,
    this.suggestedUsers = const [],
  });

  @override
  State<NewGroupChatScreen> createState() => _NewGroupChatScreenState();
}

class _NewGroupChatScreenState extends State<NewGroupChatScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final ChatApi _chatApi = ChatApi();
  final FollowsApi _followsApi = FollowsApi();
  final UsersApi _usersApi = UsersApi();

  bool _followersLoading = true;
  String? _followersError;
  List<Map<String, dynamic>> _followers = const [];

  bool _creating = false;
  String? _createError;

  String? _currentUserId;
  String _searchQuery = '';
  final LinkedHashMap<String, Map<String, dynamic>> _selectedUsers =
      LinkedHashMap<String, Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    () async {
      final uid = await CurrentUser.id;
      if (!mounted) return;
      setState(() => _currentUserId = uid);
      await _loadFollowers();
    }();

    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q == _searchQuery) return;
      setState(() => _searchQuery = q);
    });
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers() async {
    final uid = _currentUserId?.trim();
    if (uid == null || uid.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _followersLoading = true;
      _followersError = null;
    });
    try {
      final raw = await _followsApi.getFollowers(uid);
      if (!mounted) return;

      final unique = <String, Map<String, dynamic>>{};
      final missingIds = <String>{};
      for (final item in raw) {
        final user = _extractUser(item);
        if (user != null) {
          final id = _userId(user);
          if (id == null || id.isEmpty) continue;
          if (id == uid) continue;
          unique[id] = user;
        } else {
          final id = _extractFollowerId(item);
          if (id == null || id.isEmpty) continue;
          if (id == uid) continue;
          missingIds.add(id);
        }
      }

      if (missingIds.isNotEmpty) {
        final fetched = await Future.wait(
          missingIds.map(_fetchUserById),
        );
        for (final user in fetched) {
          if (user == null) continue;
          final id = _userId(user);
          if (id == null || id.isEmpty) continue;
          if (id == uid) continue;
          unique[id] = user;
        }
      }

      setState(() {
        _followersLoading = false;
        _followers = unique.values.toList(growable: false);
      });
    } catch (e, st) {
      AppErrorHandler.logError('new-group-chat-followers', e, st);
      if (!mounted) return;
      setState(() {
        _followersLoading = false;
        _followersError = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to load followers right now.',
        );
        _followers = const [];
      });
    }
  }

  String? _extractFollowerId(Map<String, dynamic> item) {
    final direct =
        (item['followerId'] ?? item['follower_id'] ?? item['follower_user_id'])
            ?.toString()
            .trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final follower = item['follower'] ?? item['fromUser'] ?? item['from_user'];
    if (follower is String) {
      final v = follower.trim();
      if (v.isNotEmpty) return v;
    }
    if (follower is Map) {
      final id = _userId(Map<String, dynamic>.from(follower));
      if (id != null && id.trim().isNotEmpty) return id.trim();
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchUserById(String userId) async {
    try {
      final res = await _usersApi.getUserProfile(userId);
      if (res['user'] is Map) {
        return Map<String, dynamic>.from(res['user'] as Map);
      }
      if (res['data'] is Map) {
        final data = Map<String, dynamic>.from(res['data'] as Map);
        if (data['user'] is Map) {
          return Map<String, dynamic>.from(data['user'] as Map);
        }
        return data;
      }
      return res;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _extractUser(Map<String, dynamic> item) {
    final embeddedUser = item['user'];
    if (embeddedUser is Map) return Map<String, dynamic>.from(embeddedUser);
    final follower = item['follower'] ?? item['follower_user'];
    if (follower is Map) return Map<String, dynamic>.from(follower);
    final followerUser2 = item['followerUser'] ?? item['follower_user'];
    if (followerUser2 is Map) return Map<String, dynamic>.from(followerUser2);
    final followerUser = item['followerUser'] ?? item['followerUserData'];
    if (followerUser is Map) return Map<String, dynamic>.from(followerUser);
    final fromUser = item['fromUser'] ?? item['from_user'];
    if (fromUser is Map) return Map<String, dynamic>.from(fromUser);
    final looksLikeUser = item['username'] != null ||
        item['full_name'] != null ||
        item['fullName'] != null ||
        item['avatar_url'] != null ||
        item['_id'] != null ||
        item['id'] != null;
    if (looksLikeUser) return Map<String, dynamic>.from(item);
    return null;
  }

  String? _userId(Map<String, dynamic> user) =>
      (user['_id'] ?? user['id'] ?? user['user_id'] ?? user['userId'])
          ?.toString();

  String _displayName(Map<String, dynamic> user) {
    final v = (user['full_name'] ??
            user['fullName'] ??
            user['name'] ??
            user['username'])
        ?.toString()
        .trim();
    return (v == null || v.isEmpty) ? 'Unknown' : v;
  }

  String _username(Map<String, dynamic> user) {
    final v = (user['username'] ?? user['handle'] ?? user['user_name'])
        ?.toString()
        .trim();
    if (v == null || v.isEmpty) return '';
    return v.startsWith('@') ? v : '@$v';
  }

  String? _avatarUrl(Map<String, dynamic> user) {
    final raw = (user['avatar_url'] ??
            user['avatarUrl'] ??
            user['avatar'] ??
            user['profile_pic'] ??
            user['profilePic'])
        ?.toString()
        .trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  List<Map<String, dynamic>> _suggestedUsers() {
    if (_followers.isNotEmpty) return _followers;
    final uid = _currentUserId?.trim();
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final u in widget.suggestedUsers) {
      final id = _userId(u);
      if (id == null || id.isEmpty) continue;
      if (uid != null && uid.isNotEmpty && id == uid) continue;
      if (seen.add(id)) out.add(u);
    }
    return out;
  }

  void _toggleSelected(Map<String, dynamic> user) {
    final id = _userId(user);
    if (id == null || id.isEmpty) return;
    setState(() {
      if (_selectedUsers.containsKey(id)) {
        _selectedUsers.remove(id);
      } else {
        _selectedUsers[id] = Map<String, dynamic>.from(user);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_creating) return;
    final participantIds = _selectedUsers.keys.toList(growable: false);
    if (participantIds.length < 2) return;
    setState(() {
      _creating = true;
      _createError = null;
    });
    try {
      final conversation = await _chatApi.createGroup(
        participantIds: participantIds,
        groupName: _groupNameController.text.trim(),
      );
      if (!mounted) return;
      final id = (conversation['_id'] ?? conversation['id'])?.toString().trim();
      if (id == null || id.isEmpty) {
        setState(() {
          _creating = false;
          _createError = 'Failed to create group';
        });
        return;
      }
      Navigator.of(context).pop(conversation);
    } catch (e, st) {
      AppErrorHandler.logError('new-group-chat-create', e, st);
      if (!mounted) return;
      setState(() {
        _creating = false;
        _createError = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to create the group right now.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.70) ??
        (isDark ? Colors.white70 : Colors.black54);

    final query = _searchQuery.trim().toLowerCase();
    final suggested = _suggestedUsers();
    final users = query.isEmpty
        ? suggested
        : suggested.where((u) {
            final name = _displayName(u).toLowerCase();
            final handle = _username(u).toLowerCase();
            return name.contains(query) || handle.contains(query);
          }).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New group chat'),
        centerTitle: true,
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _selectedUsers.length > 1
            ? SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _creating ? null : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: InstagramTheme.accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create group',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (_createError != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _createError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
          TextField(
            controller: _groupNameController,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: 'Group name (optional)',
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search users',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: _searchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      onPressed: () => _searchController.clear(),
                      enableFeedback: false,
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          if (_selectedUsers.isNotEmpty) ...[
            SizedBox(
              height: 98,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedUsers.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final user = _selectedUsers.values.elementAt(index);
                  return _selectedChip(user);
                },
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_selectedUsers.isEmpty) ...[
            InkWell(
              enableFeedback: false,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                );
              },
              borderRadius: BorderRadius.circular(16),
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: DesignTokens.instaPink.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.link, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create group with a link',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Anyone with the link can join the group',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          const Text(
            'Suggested',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_followersLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Loading followers...',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
          if (_followersError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _followersError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          if (!_followersLoading && _followersError == null && users.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _searchQuery.trim().isNotEmpty
                    ? 'No users found'
                    : 'No followers yet',
                style: TextStyle(color: muted),
              ),
            ),
          ...users.map((u) => _userRow(context, u)),
        ],
      ),
    );
  }

  Widget _selectedChip(Map<String, dynamic> user) {
    final theme = Theme.of(context);
    final name = _displayName(user);
    final avatarUrl = _avatarUrl(user);
    final id = _userId(user);

    return SizedBox(
      width: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(
                child: avatarUrl == null
                    ? Container(
                        width: 64,
                        height: 64,
                        color: DesignTokens.instaPink.withValues(alpha: 0.16),
                        alignment: Alignment.center,
                        child: Text(
                          (name.trim().isEmpty
                                  ? '?'
                                  : name.trim().characters.first)
                              .toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      )
                    : SafeNetworkImage(
                        url: avatarUrl,
                        width: 64,
                        height: 64,
                        placeholder: Container(
                          width: 64,
                          height: 64,
                          color: DesignTokens.instaPink.withValues(alpha: 0.12),
                        ),
                        errorWidget: Container(
                          width: 64,
                          height: 64,
                          color: DesignTokens.instaPink.withValues(alpha: 0.12),
                        ),
                      ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: InkWell(
                  enableFeedback: false,
                  onTap: () {
                    if (id == null || id.isEmpty) return;
                    setState(() => _selectedUsers.remove(id));
                  },
                  borderRadius: BorderRadius.circular(999),
                  splashFactory: NoSplash.splashFactory,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  overlayColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.9),
                      ),
                    ),
                    child: const Icon(LucideIcons.x, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _userRow(BuildContext context, Map<String, dynamic> user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.70) ??
        (isDark ? Colors.white70 : Colors.black54);

    final id = _userId(user) ?? '';
    final selected = id.isNotEmpty && _selectedUsers.containsKey(id);
    final name = _displayName(user);
    final username = _username(user);
    final avatarUrl = _avatarUrl(user);

    final unselectedBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final unselectedBorder = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.25);

    return InkWell(
      enableFeedback: false,
      onTap: () => _toggleSelected(user),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            _avatar(avatarUrl, name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              enableFeedback: false,
              onTap: () => _toggleSelected(user),
              borderRadius: BorderRadius.circular(999),
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? DesignTokens.instaPink : unselectedBg,
                  border: Border.all(
                    color: selected ? DesignTokens.instaPink : unselectedBorder,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? const Icon(Icons.check, size: 20, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String? avatarUrl, String name) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: DesignTokens.instaPink.withValues(alpha: 0.16),
        child: Text(
          initial.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
    }
    return ClipOval(
      child: SafeNetworkImage(
        url: avatarUrl,
        width: 44,
        height: 44,
        placeholder: CircleAvatar(
          radius: 22,
          backgroundColor: DesignTokens.instaPink.withValues(alpha: 0.12),
          child: Text(
            initial.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        errorWidget: CircleAvatar(
          radius: 22,
          backgroundColor: DesignTokens.instaPink.withValues(alpha: 0.12),
          child: Text(
            initial.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
