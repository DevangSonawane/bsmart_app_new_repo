import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/follows_api.dart';
import '../api/chat_api.dart';
import '../state/app_state.dart';
import '../widgets/safe_network_image.dart';
import 'chat_conversation_screen.dart';
import 'messaging_screen.dart';

enum FollowListMode { followers, following, vendors }

enum FollowSortMode { defaultSort, dateLatest, dateEarliest }

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String username;
  final FollowListMode initialMode;
  final bool isOwnProfile;
  final int? initialFollowersCount;
  final int? initialFollowingCount;

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.initialMode,
    required this.isOwnProfile,
    this.initialFollowersCount,
    this.initialFollowingCount,
  });

  static Future<void> open(
    BuildContext context, {
    required String userId,
    required String username,
    required FollowListMode mode,
    required bool isOwnProfile,
    int? initialFollowersCount,
    int? initialFollowingCount,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => FollowListScreen(
          userId: userId,
          username: username,
          initialMode: mode,
          isOwnProfile: isOwnProfile,
          initialFollowersCount: initialFollowersCount,
          initialFollowingCount: initialFollowingCount,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final offsetAnimation = Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved);
          final fadeAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return SlideTransition(
            position: offsetAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          );
        },
      ),
    );
  }

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen>
    with TickerProviderStateMixin {
  static const int _pageLimit = 20;

  final FollowsApi _api = FollowsApi();
  final TextEditingController _searchController = TextEditingController();
  late final PageController _tabPageController;
  late final Map<FollowListMode, _FollowTabState> _tabs;
  late final AnimationController _sortSheetController;
  late final AnimationController _rowActionSheetController;

  Timer? _searchDebounce;
  FollowListMode _mode = FollowListMode.followers;
  String _search = '';
  int _followersCount = 0;
  int _followingCount = 0;
  int _vendorsCount = 0;
  bool _countsLoading = false;

  bool _showConnectContacts = true;

  FollowSortMode _sortMode = FollowSortMode.defaultSort;

  String _actionUserId = '';
  String _openingConversationForUserId = '';
  bool _initialLoadStarted = false;
  void Function(AnimationStatus status)? _routeStatusListener;
  // Per-tab paging state so swiping between tabs keeps scroll position and data.
  // Search input applies to the currently active tab only (like Instagram).
  // Each tab lazily loads on first view.

  @override
  void initState() {
    super.initState();
    _sortSheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
      reverseDuration: const Duration(milliseconds: 260),
    );
    _rowActionSheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _mode = widget.initialMode;
    _followersCount = widget.initialFollowersCount ?? 0;
    _followingCount = widget.initialFollowingCount ?? 0;
    _tabPageController = PageController(initialPage: _indexForMode(_mode));
    _tabs = <FollowListMode, _FollowTabState>{
      FollowListMode.followers: _FollowTabState(),
      FollowListMode.following: _FollowTabState(),
      FollowListMode.vendors: _FollowTabState(),
    };
    for (final entry in _tabs.entries) {
      entry.value.scrollController.addListener(() => _onScroll(entry.key));
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadStarted) return;
    _initialLoadStarted = true;

    final route = ModalRoute.of(context);
    final animation = route is PageRoute ? route.animation : null;
    if (animation == null || animation.status == AnimationStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_loadCounts());
        _loadPage(_mode, 1, replace: true);
      });
      return;
    }

    _routeStatusListener = (status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(_routeStatusListener!);
      _routeStatusListener = null;
      if (!mounted) return;
      unawaited(_loadCounts());
      _loadPage(_mode, 1, replace: true);
    };
    animation.addStatusListener(_routeStatusListener!);
  }

  @override
  void dispose() {
    final route = ModalRoute.of(context);
    final animation = route is PageRoute ? route.animation : null;
    final listener = _routeStatusListener;
    if (animation != null && listener != null) {
      animation.removeStatusListener(listener);
    }
    _searchDebounce?.cancel();
    _searchController.dispose();
    _tabPageController.dispose();
    for (final entry in _tabs.entries) {
      entry.value.scrollController.dispose();
    }
    _sortSheetController.dispose();
    _rowActionSheetController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text;
    if (next == _search) return;
    _search = next;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _loadPage(_mode, 1, replace: true);
    });
  }

  void _onScroll(FollowListMode mode) {
    final tab = _tabs[mode]!;
    if (mode == FollowListMode.vendors) return;
    if (!tab.hasMore || tab.loading || tab.loadingMore) return;
    if (!tab.scrollController.hasClients) return;
    final pos = tab.scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 120) {
      _loadPage(mode, tab.page + 1, replace: false);
    }
  }

  String _idOf(Map<String, dynamic> u) =>
      (u['_id'] as String?) ?? (u['id'] as String?) ?? '';

  String _usernameOf(Map<String, dynamic> u) =>
      (u['username'] as String?)?.trim().isNotEmpty == true
          ? (u['username'] as String).trim()
          : 'user';

  String _fullNameOf(Map<String, dynamic> u) =>
      (u['full_name'] as String?) ??
      (u['name'] as String?) ??
      (u['fullName'] as String?) ??
      '';

  String _avatarOf(Map<String, dynamic> u) =>
      (u['avatar_url'] as String?) ??
      (u['profilePicture'] as String?) ??
      (u['avatar'] as String?) ??
      '';

  bool _isFollowingOf(Map<String, dynamic> u) =>
      (u['isFollowing'] as bool?) ?? (u['is_followed_by_me'] as bool?) ?? false;

  int _indexForMode(FollowListMode mode) {
    return switch (mode) {
      FollowListMode.followers => 0,
      FollowListMode.following => 1,
      FollowListMode.vendors => 2,
    };
  }

  FollowListMode _modeForIndex(int index) {
    return switch (index) {
      0 => FollowListMode.followers,
      1 => FollowListMode.following,
      _ => FollowListMode.vendors,
    };
  }

  void _goToMode(FollowListMode next) {
    final idx = _indexForMode(next);
    if (_tabPageController.hasClients) {
      _tabPageController.animateToPage(
        idx,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    if (next != _mode) {
      setState(() => _mode = next);
    }
    final tab = _tabs[next]!;
    if (tab.users.isEmpty) {
      _loadPage(next, 1, replace: true);
    }
  }

  Future<void> _loadCounts() async {
    if (_countsLoading) return;
    setState(() => _countsLoading = true);
    try {
      final res = await _api.getFollowCounts(widget.userId);
      final followers = (res['followers_count'] ??
          res['followersCount'] ??
          res['followers'] ??
          res['followersCountTotal']);
      final following = (res['following_count'] ??
          res['followingCount'] ??
          res['following'] ??
          res['followingCountTotal']);
      final vendors = (res['vendors_count'] ??
          res['vendorsCount'] ??
          res['vendors'] ??
          res['vendorCount']);
      if (!mounted) return;
      setState(() {
        if (followers is num) _followersCount = followers.toInt();
        if (following is num) _followingCount = following.toInt();
        if (vendors is num) _vendorsCount = vendors.toInt();
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _countsLoading = false);
    }
  }

  Future<void> _loadPage(
    FollowListMode mode,
    int page, {
    required bool replace,
  }) async {
    if (widget.userId.isEmpty) return;
    final tab = _tabs[mode]!;
    if (tab.loading || tab.loadingMore) return;

    final currentUserId =
        StoreProvider.of<AppState>(context).state.authState.userId ?? '';
    setState(() {
      if (replace) {
        tab.loading = true;
      } else {
        tab.loadingMore = true;
      }
    });

    try {
      final trimmedSearch = _search.trim();

      if (mode == FollowListMode.vendors) {
        final res = await _api.getSuggestions(limit: 30);
        final raw = res['users'] ?? res['vendors'] ?? res['data'] ?? res;
        final list = raw is List
            ? raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        final filtered = trimmedSearch.isEmpty
            ? list
            : list.where((u) {
                final un = _usernameOf(u).toLowerCase();
                final fn = _fullNameOf(u).toLowerCase();
                final q = trimmedSearch.toLowerCase();
                return un.contains(q) || fn.contains(q);
              }).toList();
        final ids = filtered.map(_idOf).where((e) => e.isNotEmpty).toList();
        if (ids.isNotEmpty && currentUserId.isNotEmpty) {
          try {
            final statuses = await _api.bulkCheckFollowStatus(ids);
            final statusMap = <String, Map<String, dynamic>>{};
            for (final s in statuses) {
              final sid = (s['userId'] as String?) ??
                  (s['_id'] as String?) ??
                  (s['id'] as String?) ??
                  '';
              if (sid.isNotEmpty) statusMap[sid] = s;
            }
            for (var i = 0; i < filtered.length; i++) {
              final u = filtered[i];
              final uid = _idOf(u);
              final s = statusMap[uid];
              if (s == null) continue;
              filtered[i] = <String, dynamic>{
                ...u,
                ...s,
                'isFollowing': (s['isFollowing'] as bool?) ?? _isFollowingOf(u),
              };
            }
          } catch (_) {
            // ignore status failures
          }
        }
        if (!mounted) return;
        setState(() {
          tab.page = 1;
          tab.hasMore = false;
          tab.users = filtered;
          _vendorsCount = _vendorsCount == 0 ? filtered.length : _vendorsCount;
        });
        return;
      }

      final res = mode == FollowListMode.followers
          ? await _api.getFollowersPage(
              widget.userId,
              search: trimmedSearch,
              page: page,
              limit: _pageLimit,
            )
          : await _api.getFollowingPage(
              widget.userId,
              search: trimmedSearch,
              page: page,
              limit: _pageLimit,
            );

      final nextUsersRaw = res['users'];
      final nextTotalRaw = res['total'];
      final nextUsers = nextUsersRaw is List
          ? nextUsersRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      final nextTotal = nextTotalRaw is num ? nextTotalRaw.toInt() : 0;

      final ids = nextUsers.map(_idOf).where((e) => e.isNotEmpty).toList();
      if (ids.isNotEmpty && currentUserId.isNotEmpty) {
        try {
          final statuses = await _api.bulkCheckFollowStatus(ids);
          final statusMap = <String, Map<String, dynamic>>{};
          for (final s in statuses) {
            final sid = (s['userId'] as String?) ??
                (s['_id'] as String?) ??
                (s['id'] as String?) ??
                '';
            if (sid.isNotEmpty) statusMap[sid] = s;
          }
          for (var i = 0; i < nextUsers.length; i++) {
            final u = nextUsers[i];
            final uid = _idOf(u);
            final s = statusMap[uid];
            if (s == null) continue;
            nextUsers[i] = <String, dynamic>{
              ...u,
              ...s,
              'isFollowing': (s['isFollowing'] as bool?) ?? _isFollowingOf(u),
              'isFollowedBy': (s['isFollowedBy'] as bool?) ??
                  (u['isFollowedBy'] as bool?) ??
                  false,
            };
          }
        } catch (_) {
          // ignore status failures
        }
      }

      if (!mounted) return;
      setState(() {
        tab.page = page;
        tab.hasMore = nextTotal > 0
            ? page * _pageLimit < nextTotal
            : nextUsers.length == _pageLimit;
        tab.users = replace
            ? nextUsers
            : <Map<String, dynamic>>[...tab.users, ...nextUsers];
        if (mode == FollowListMode.followers && nextTotal > 0) {
          _followersCount = nextTotal;
        }
        if (mode == FollowListMode.following && nextTotal > 0) {
          _followingCount = nextTotal;
        }
      });
    } catch (_) {
      if (replace && mounted) {
        setState(() {
          tab.users = <Map<String, dynamic>>[];
          tab.hasMore = false;
          tab.page = 1;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          tab.loading = false;
          tab.loadingMore = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(String targetUserId, bool isFollowing) async {
    if (targetUserId.isEmpty) return;
    if (_actionUserId.isNotEmpty) return;
    setState(() => _actionUserId = targetUserId);
    try {
      if (isFollowing) {
        await _api.unfollow(targetUserId);
      } else {
        await _api.follow(targetUserId);
      }
      if (!mounted) return;
      setState(() {
        final tab = _tabs[_mode]!;
        tab.users = tab.users
            .map((u) => _idOf(u) == targetUserId
                ? <String, dynamic>{...u, 'isFollowing': !isFollowing}
                : u)
            .toList();
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _actionUserId = '');
    }
  }

  Future<void> _removeFollower(String followerId) async {
    if (followerId.isEmpty) return;
    if (_actionUserId.isNotEmpty) return;
    setState(() => _actionUserId = followerId);
    try {
      await _api.removeFollower(followerId);
      if (!mounted) return;
      setState(() {
        final tab = _tabs[_mode]!;
        tab.users = tab.users.where((u) => _idOf(u) != followerId).toList();
        _followersCount = (_followersCount - 1).clamp(0, 1 << 30);
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _actionUserId = '');
    }
  }

  Future<void> _openChatForUser({
    required String participantId,
  }) async {
    if (participantId.isEmpty) return;
    if (_openingConversationForUserId.isNotEmpty) return;
    setState(() => _openingConversationForUserId = participantId);
    try {
      final conversation =
          await ChatApi().createOrGetConversation(participantId: participantId);
      if (!mounted) return;
      final id = (conversation['_id'] ?? conversation['id'])?.toString();
      if (id == null || id.isEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MessagingScreen()),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            conversationId: id,
            initialConversation: conversation,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MessagingScreen()),
      );
    } finally {
      if (mounted) setState(() => _openingConversationForUserId = '');
    }
  }

  String get _sortLabel {
    switch (_sortMode) {
      case FollowSortMode.defaultSort:
        return 'Default';
      case FollowSortMode.dateLatest:
        return 'Date followed: latest';
      case FollowSortMode.dateEarliest:
        return 'Date followed: earliest';
    }
  }

  Future<void> _openSortSheet() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sheetBg = theme.bottomSheetTheme.backgroundColor ?? cs.surface;
    final onSheet = cs.onSurface;
    final selected = await showModalBottomSheet<FollowSortMode>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      transitionAnimationController: _sortSheetController,
      builder: (ctx) => SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _sortSheetController,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_sortSheetController.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 10),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: onSheet.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sort by',
                  style: TextStyle(
                    color: onSheet,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                _SortOptionRow(
                  label: 'Default',
                  selected: _sortMode == FollowSortMode.defaultSort,
                  onTap: () =>
                      Navigator.of(ctx).pop(FollowSortMode.defaultSort),
                ),
                _SortOptionRow(
                  label: 'Date followed: latest',
                  selected: _sortMode == FollowSortMode.dateLatest,
                  onTap: () => Navigator.of(ctx).pop(FollowSortMode.dateLatest),
                ),
                _SortOptionRow(
                  label: 'Date followed: earliest',
                  selected: _sortMode == FollowSortMode.dateEarliest,
                  onTap: () =>
                      Navigator.of(ctx).pop(FollowSortMode.dateEarliest),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == _sortMode) return;
    setState(() => _sortMode = selected);
    _loadPage(_mode, 1, replace: true);
  }

  String _emptyLabelForMode(FollowListMode mode) {
    final s = _search.trim();
    if (mode == FollowListMode.followers) {
      return s.isNotEmpty
          ? 'No followers found for that search.'
          : 'No followers yet.';
    }
    if (mode == FollowListMode.following) {
      return s.isNotEmpty
          ? 'No following users found for that search.'
          : 'Not following anyone yet.';
    }
    return s.isNotEmpty ? 'No vendors found for that search.' : 'No vendors.';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        StoreProvider.of<AppState>(context).state.authState.userId ?? '';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.username.trim().isEmpty ? 'user' : widget.username.trim(),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          _TopTabsBar(
            followers: _followersCount,
            following: _followingCount,
            vendors: _vendorsCount,
            mode: _mode,
            controller: _tabPageController,
            onMode: _goToMode,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: _SearchBar(controller: _searchController),
          ),
          if (_showConnectContacts)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: _ConnectContactsCard(
                onClose: () => setState(() => _showConnectContacts = false),
                onConnect: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connect contacts coming soon'),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: PageView(
              controller: _tabPageController,
              onPageChanged: (index) {
                final next = _modeForIndex(index);
                if (next != _mode) {
                  setState(() => _mode = next);
                }
                final tab = _tabs[next]!;
                if (tab.users.isEmpty) {
                  _loadPage(next, 1, replace: true);
                }
              },
              children: [
                _buildList(FollowListMode.followers, currentUserId),
                _buildList(FollowListMode.following, currentUserId),
                _buildList(FollowListMode.vendors, currentUserId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow({
    required FollowListMode mode,
    required String currentUserId,
    required Map<String, dynamic> user,
  }) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.60);
    final uid = _idOf(user);
    final username = _usernameOf(user);
    final fullName = _fullNameOf(user);
    final avatar = _avatarOf(user);
    final isFollowing = _isFollowingOf(user);
    final canAct = uid.isNotEmpty && uid != currentUserId;
    final verified = (user['verified'] as bool?) ??
        (user['isVerified'] as bool?) ??
        (user['validated'] as bool?) ??
        false;
    final newPosts = (user['new_posts'] as num?) ?? (user['newPosts'] as num?);

    return InkWell(
      onTap: uid.isNotEmpty
          ? () => Navigator.of(context).pushNamed('/profile/$uid')
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            _AvatarCircle(username: username, avatarUrl: avatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (verified) ...[
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.badgeCheck,
                          size: 16,
                          color: cs.primary,
                        ),
                      ],
                    ],
                  ),
                  if (fullName.trim().isNotEmpty)
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),
                  if (newPosts != null && newPosts.toInt() > 0)
                    Text(
                      '${newPosts.toInt()} new posts',
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (mode == FollowListMode.following && canAct)
              _ActionButton(
                label: _openingConversationForUserId == uid
                    ? 'Opening...'
                    : 'Message',
                kind: _ActionButtonKind.neutral,
                disabled: _actionUserId.isNotEmpty ||
                    _openingConversationForUserId.isNotEmpty,
                onPressed: () {
                  unawaited(_openChatForUser(participantId: uid));
                },
              )
            else if (mode == FollowListMode.followers &&
                widget.isOwnProfile &&
                canAct)
              _ActionButton(
                label: _actionUserId == uid ? 'Removing...' : 'Remove',
                kind: _ActionButtonKind.neutral,
                disabled: _actionUserId.isNotEmpty,
                onPressed: () => _removeFollower(uid),
              )
            else if ((mode == FollowListMode.followers ||
                    mode == FollowListMode.vendors) &&
                canAct)
              _ActionButton(
                label: _actionUserId == uid
                    ? 'Updating...'
                    : (isFollowing ? 'Following' : 'Follow'),
                kind: isFollowing
                    ? _ActionButtonKind.neutral
                    : _ActionButtonKind.primary,
                disabled: _actionUserId.isNotEmpty,
                onPressed: () => _toggleFollow(uid, isFollowing),
              ),
            const SizedBox(width: 4),
            if (mode == FollowListMode.followers)
              IconButton(
                onPressed: (widget.isOwnProfile && canAct)
                    ? () => _openRemoveFollowerConfirmSheet(
                          followerId: uid,
                          username: username,
                          avatarUrl: avatar,
                        )
                    : null,
                icon: Icon(
                  LucideIcons.x,
                  color: muted,
                  size: 18,
                ),
              )
            else
              IconButton(
                onPressed: canAct
                    ? () => _openRowActionsSheet(
                          targetUserId: uid,
                          username: username,
                          isFollowing: isFollowing,
                        )
                    : null,
                icon: Icon(
                  LucideIcons.ellipsis,
                  color: muted,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRemoveFollowerConfirmSheet({
    required String followerId,
    required String username,
    required String avatarUrl,
  }) async {
    if (followerId.isEmpty) return;
    assert(() {
      debugPrint('[FollowList] open remove sheet for=$followerId');
      return true;
    }());

    Future<void> dismiss(BuildContext ctx) async {
      final nav = Navigator.of(ctx);
      final canPop = nav.canPop();
      assert(() {
        debugPrint('[FollowList] dismiss: canPop=$canPop');
        return true;
      }());
      final popped = await nav.maybePop();
      assert(() {
        debugPrint('[FollowList] dismiss: popped=$popped');
        return true;
      }());
      if (!popped && mounted) {
        final popped2 = await Navigator.of(context).maybePop();
        assert(() {
          debugPrint('[FollowList] dismiss: fallback popped=$popped2');
          return true;
        }());
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final onSheet = cs.onSurface;
        final muted = onSheet.withValues(alpha: 0.60);
        final subtle = onSheet.withValues(alpha: 0.08);
        final animation = ModalRoute.of(ctx)?.animation;

        Widget content = Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: onSheet.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ClipOval(
                  child: SafeNetworkImage(
                    url: avatarUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      width: 72,
                      height: 72,
                      color: subtle,
                      alignment: Alignment.center,
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: onSheet,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    errorWidget: Container(
                      width: 72,
                      height: 72,
                      color: subtle,
                      alignment: Alignment.center,
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: onSheet,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Remove follower?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: onSheet,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We won’t tell $username that they were removed from your followers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _actionUserId.isNotEmpty
                      ? null
                      : () async {
                          assert(() {
                            debugPrint('[FollowList] remove pressed');
                            return true;
                          }());
                          await dismiss(ctx);
                          await _removeFollower(followerId);
                        },
                  style: TextButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _actionUserId == followerId ? 'Removing...' : 'Remove',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    assert(() {
                      debugPrint('[FollowList] cancel pressed');
                      return true;
                    }());
                    await dismiss(ctx);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: onSheet.withValues(alpha: 0.10),
                    foregroundColor: onSheet,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        if (animation != null) {
          content = AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              final t = Curves.easeOutCubic.transform(animation.value);
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 12),
                  child: child,
                ),
              );
            },
            child: content,
          );
        }

        return SafeArea(top: false, child: content);
      },
    );

    assert(() {
      debugPrint('[FollowList] remove sheet closed');
      return true;
    }());
  }

  Widget _followingHeaderSliver() {
    final followingTab = _tabs[FollowListMode.following]!;
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: _DividerLine(),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Categories',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              children: [
                _CategoryTile(
                  title: 'Least interacted with',
                  subtitle: followingTab.users.isNotEmpty
                      ? '${_usernameOf(followingTab.users.first)} and ${(followingTab.users.length - 1).clamp(0, 999)} others'
                      : '—',
                  avatarUrl: followingTab.users.isNotEmpty
                      ? _avatarOf(followingTab.users.first)
                      : '',
                  avatarLabel: followingTab.users.isNotEmpty
                      ? _usernameOf(followingTab.users.first)
                      : 'U',
                ),
                const SizedBox(height: 10),
                _CategoryTile(
                  title: 'Most shown in feed',
                  subtitle: followingTab.users.length >= 2
                      ? '${_usernameOf(followingTab.users[1])} and ${(followingTab.users.length - 2).clamp(0, 999)} others'
                      : (followingTab.users.isNotEmpty
                          ? '${_usernameOf(followingTab.users.first)} and 0 others'
                          : '—'),
                  avatarUrl: followingTab.users.length >= 2
                      ? _avatarOf(followingTab.users[1])
                      : (followingTab.users.isNotEmpty
                          ? _avatarOf(followingTab.users.first)
                          : ''),
                  avatarLabel: followingTab.users.length >= 2
                      ? _usernameOf(followingTab.users[1])
                      : (followingTab.users.isNotEmpty
                          ? _usernameOf(followingTab.users.first)
                          : 'U'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: _DividerLine(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: _SortRow(label: _sortLabel, onTap: _openSortSheet),
          ),
        ],
      ),
    );
  }

  Widget _buildList(FollowListMode mode, String currentUserId) {
    final tab = _tabs[mode]!;
    if (tab.loading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    if (tab.users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _emptyLabelForMode(mode),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.60),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    if (mode == FollowListMode.following) {
      return CustomScrollView(
        controller: tab.scrollController,
        slivers: [
          _followingHeaderSliver(),
          SliverPadding(
            padding: const EdgeInsets.only(top: 2, bottom: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= tab.users.length) return null;
                  return _buildUserRow(
                    mode: mode,
                    currentUserId: currentUserId,
                    user: tab.users[index],
                  );
                },
                childCount: tab.users.length,
              ),
            ),
          ),
          if (tab.loadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return ListView.builder(
      controller: tab.scrollController,
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      itemCount: tab.users.length + (tab.loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= tab.users.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        return _buildUserRow(
          mode: mode,
          currentUserId: currentUserId,
          user: tab.users[index],
        );
      },
    );
  }

  Future<void> _openRowActionsSheet({
    required String targetUserId,
    required String username,
    required bool isFollowing,
  }) async {
    if (targetUserId.isEmpty) return;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sheetBg = theme.bottomSheetTheme.backgroundColor ?? cs.surface;
    final onSheet = cs.onSurface;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      transitionAnimationController: _rowActionSheetController,
      builder: (ctx) => SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _rowActionSheetController,
          builder: (context, child) {
            final t =
                Curves.easeOutCubic.transform(_rowActionSheetController.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * 10),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: onSheet.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onSheet,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _ActionSheetItem(
                  icon: LucideIcons.userMinus,
                  label: 'Unfollow',
                  labelColor: cs.error,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _toggleFollow(targetUserId, isFollowing);
                  },
                ),
                _ActionSheetItem(
                  icon: LucideIcons.users,
                  label: 'See shared activity',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon')),
                    );
                  },
                ),
                _ActionSheetItem(
                  icon: LucideIcons.volumeX,
                  label: 'Mute',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopTabsBar extends StatelessWidget {
  final int followers;
  final int following;
  final int vendors;
  final FollowListMode mode;
  final PageController controller;
  final ValueChanged<FollowListMode> onMode;

  const _TopTabsBar({
    required this.followers,
    required this.following,
    required this.vendors,
    required this.mode,
    required this.controller,
    required this.onMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final divider = isLight ? Colors.black12 : Colors.white12;
    final indicator = isLight ? Colors.black87 : Colors.white;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tabWidth = width / 3;
        return SizedBox(
          height: 46,
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 1,
                    color: divider,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _tab(
                      context,
                      label: '$followers followers',
                      selected: mode == FollowListMode.followers,
                      onTap: () => onMode(FollowListMode.followers),
                    ),
                  ),
                  Expanded(
                    child: _tab(
                      context,
                      label: '$following following',
                      selected: mode == FollowListMode.following,
                      onTap: () => onMode(FollowListMode.following),
                    ),
                  ),
                  Expanded(
                    child: _tab(
                      context,
                      label: vendors > 0 ? '$vendors vendors' : 'Vendors',
                      selected: mode == FollowListMode.vendors,
                      onTap: () => onMode(FollowListMode.vendors),
                    ),
                  ),
                ],
              ),
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final page = controller.hasClients
                      ? (controller.page ?? controller.initialPage.toDouble())
                      : (switch (mode) {
                          FollowListMode.followers => 0.0,
                          FollowListMode.following => 1.0,
                          FollowListMode.vendors => 2.0,
                        });
                  final left = tabWidth * page + (tabWidth - 64) / 2;
                  return Positioned(
                    left: left,
                    bottom: 0,
                    child: Container(
                      height: 2,
                      width: 64,
                      decoration: BoxDecoration(
                        color: indicator,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tab(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final selectedLabel = isLight ? Colors.black87 : Colors.white;
    final unselectedLabel = isLight ? Colors.black54 : Colors.white70;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? selectedLabel : unselectedLabel,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.onSurface.withValues(alpha: 0.08);
    final muted = cs.onSurface.withValues(alpha: 0.60);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 16, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              cursorColor: muted,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Search',
                hintStyle: TextStyle(color: muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectContactsCard extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback onClose;

  const _ConnectContactsCard({
    required this.onConnect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.60);
    final iconBg = cs.onSurface.withValues(alpha: 0.08);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.contact,
              size: 17,
              color: cs.onSurface.withValues(alpha: 0.70),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect contacts',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Find people you know',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onConnect,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Connect',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              LucideIcons.x,
              color: cs.onSurface.withValues(alpha: 0.70),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String avatarUrl;
  final String avatarLabel;

  const _CategoryTile({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.avatarLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.60);
    final subtle = cs.onSurface.withValues(alpha: 0.08);
    return Row(
      children: [
        ClipOval(
          child: SafeNetworkImage(
            url: avatarUrl,
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            placeholder: Container(
              width: 42,
              height: 42,
              color: subtle,
              alignment: Alignment.center,
              child: Text(
                avatarLabel.isNotEmpty ? avatarLabel[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            errorWidget: Container(
              width: 42,
              height: 42,
              color: subtle,
              alignment: Alignment.center,
              child: Text(
                avatarLabel.isNotEmpty ? avatarLabel[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SortRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SortRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.65);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            'Sort by ',
            style: TextStyle(
              color: muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Icon(
            LucideIcons.arrowUpDown,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.70),
          ),
        ],
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 1,
      child: ColoredBox(
        color: cs.onSurface.withValues(alpha: 0.12),
      ),
    );
  }
}

class _SortOptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortOptionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _RadioCircle(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _RadioCircle extends StatelessWidget {
  final bool selected;
  const _RadioCircle({required this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = cs.onSurface.withValues(alpha: 0.35);
    return Container(
      height: 22,
      width: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: selected ? 10 : 0,
        width: selected ? 10 : 0,
        decoration: BoxDecoration(
          color: cs.onSurface,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String username;
  final String avatarUrl;

  const _AvatarCircle({
    required this.username,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final hasAvatar = avatarUrl.trim().isNotEmpty;
    if (!hasAvatar) {
      return Container(
        height: 44,
        width: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return ClipOval(
      child: SafeNetworkImage(
        url: avatarUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: Container(
          height: 44,
          width: 44,
          color: cs.onSurface.withValues(alpha: 0.08),
        ),
        errorWidget: Container(
          height: 44,
          width: 44,
          color: cs.onSurface.withValues(alpha: 0.08),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

enum _ActionButtonKind { primary, neutral }

class _ActionButton extends StatelessWidget {
  final String label;
  final _ActionButtonKind kind;
  final bool disabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.kind,
    required this.disabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPrimary = kind == _ActionButtonKind.primary;
    final bg = isPrimary ? cs.primary : cs.onSurface.withValues(alpha: 0.10);
    final fg = isPrimary ? cs.onPrimary : cs.onSurface;
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: disabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          side: BorderSide(color: Colors.transparent),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ActionSheetItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _ActionSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.70)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor ?? cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowTabState {
  final ScrollController scrollController = ScrollController();
  int page = 1;
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  List<Map<String, dynamic>> users = <Map<String, dynamic>>[];
}
