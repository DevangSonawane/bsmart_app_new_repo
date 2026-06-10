import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/api_client.dart';
import '../theme/design_tokens.dart';
import '../services/promote_service.dart';
import 'package:b_smart/widgets/glass_action_button.dart';
import 'external_link_screen.dart';
import '../api/promote_reels_api.dart';
import '../widgets/promote_comments_sheet.dart';
import '../widgets/share_content_modal.dart';
import '../api/follows_api.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import '../services/supabase_service.dart';
import '../routes.dart';
import 'package:url_launcher/url_launcher.dart';

class PromoteScreen extends StatefulWidget {
  final bool isActive;

  const PromoteScreen({super.key, this.isActive = true});

  @override
  State<PromoteScreen> createState() => _PromoteScreenState();
}

class _PromoteScreenState extends State<PromoteScreen> with RouteAware {
  PageRoute<dynamic>? _subscribedRoute;
  bool _isRouteActive = true;

  final PageController _pageController = PageController();
  final PromoteService _promoteService = PromoteService();
  final PromoteReelsApi _promoteReelsApi = PromoteReelsApi();
  final FollowsApi _followsApi = FollowsApi();
  final SupabaseService _supabaseService = SupabaseService();
  Map<String, String>? _mediaHeaders;
  int _currentIndex = 0;
  bool _isMuted = true;
  bool _loading = true;
  List<Map<String, dynamic>> _promotes = [];
  final Map<int, VideoPlayerController> _controllers = {};
  final Map<String, bool> _followByUserId = {};
  final Set<String> _followLoadingUserIds = <String>{};
  final Map<int, bool> _productsOpenByIndex = <int, bool>{};
  String? _myUserId;
  double _cachedBottomInset = 0;
  String _searchInput = '';
  bool _searchOpen = false;
  bool _searchLoading = false;
  bool _searchLoadingMore = false;
  bool _searchDropdownVisible = false;
  List<Map<String, dynamic>> _searchResults = [];
  String _searchQuery = '';
  int _searchPage = 1;
  bool _searchHasMore = true;
  static const int _searchPageSize = 20;
  Timer? _searchDebounce;
  int _searchEpoch = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode =
      FocusNode(debugLabel: 'promote-search-focus');
  final ScrollController _searchScrollController = ScrollController();

  bool get _canPlay => widget.isActive && _isRouteActive;

  @override
  void initState() {
    super.initState();
    _searchScrollController.addListener(_onSearchScroll);
    unawaited(() async {
      _myUserId = await CurrentUser.id;
      if (mounted) setState(() {});
    }());
    _loadPromotes();
    _loadMediaHeaders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final view = View.of(context);
      final inset = view.padding.bottom / view.devicePixelRatio;
      if (inset > 0 && inset != _cachedBottomInset) {
        setState(() {
          _cachedBottomInset = inset;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  Future<void> _loadPromotes() async {
    final list = await _promoteService.fetchPromotes();
    if (mounted) {
      setState(() {
        _promotes = list
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
        _loading = false;
      });
      if (_promotes.isNotEmpty) _initControllerForIndex(0);
      unawaited(_loadFollowStatuses());
    }
  }

  Future<void> _loadFollowStatuses() async {
    try {
      final ids = <String>{};
      for (final p in _promotes) {
        final uid = _toId(p['userId'] ?? p['user_id'] ?? p['user_id']);
        if (uid.isEmpty) continue;
        if (_myUserId != null && _myUserId!.isNotEmpty && uid == _myUserId) {
          continue;
        }
        ids.add(uid);
      }
      if (ids.isEmpty) return;
      final statuses = await _followsApi.bulkCheckFollowStatus(ids.toList());
      final next = <String, bool>{..._followByUserId};
      for (final s in statuses) {
        final sid = _toId(s['userId'] ?? s['_id'] ?? s['id']);
        if (sid.isEmpty) continue;
        final v = s['isFollowing'];
        if (v is bool) next[sid] = v;
      }
      if (!mounted) return;
      setState(() {
        _followByUserId
          ..clear()
          ..addAll(next);
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadMediaHeaders() async {
    if (_mediaHeaders != null) return;
    final token = await ApiClient().getToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      setState(() {
        _mediaHeaders = {'Authorization': 'Bearer $token'};
      });
    }
  }

  Future<void> _initControllerForIndex(int index) async {
    if (index < 0 || index >= _promotes.length) return;
    if (_controllers.containsKey(index)) return;
    final url = _promotes[index]['videoUrl'] as String?;
    if (url == null || url.isEmpty) return;
    if (UrlHelper.shouldAttachAuthHeader(url) && _mediaHeaders == null) {
      await _loadMediaHeaders();
    }
    final headers = UrlHelper.shouldAttachAuthHeader(url)
        ? (_mediaHeaders ?? const <String, String>{})
        : const <String, String>{};
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
      formatHint: _videoFormatHintForUrl(url),
    );
    _controllers[index] = controller;
    await controller.initialize();
    controller.setLooping(true);
    if (mounted && _currentIndex == index && _canPlay) {
      if (!_isMuted) {
        await controller.setVolume(1.0);
      } else {
        await controller.setVolume(0.0);
      }
      await controller.play();
    } else {
      await controller.setVolume(0.0);
      await controller.pause();
    }
    setState(() {});
  }

  VideoFormat? _videoFormatHintForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return VideoFormat.hls;
    if (lower.contains('.mpd')) return VideoFormat.dash;
    return null;
  }

  void _disposeFarControllers(int keepIndex) {
    final keys = List<int>.from(_controllers.keys);
    for (final k in keys) {
      if ((k - keepIndex).abs() > 1) {
        try {
          _controllers[k]?.pause();
          _controllers[k]?.dispose();
        } catch (_) {}
        _controllers.remove(k);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchScrollController.dispose();
    for (final entry in _controllers.entries) {
      final idx = entry.key;
      final c = entry.value;
      try {
        c.pause();
        c.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
    super.dispose();
  }

  @override
  void didPushNext() {
    if (!_isRouteActive) return;
    _isRouteActive = false;
    _syncPlaybackState();
    if (mounted) setState(() {});
  }

  @override
  void didPopNext() {
    if (_isRouteActive) return;
    _isRouteActive = true;
    _syncPlaybackState();
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant PromoteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _syncPlaybackState();
    }
  }

  void _syncPlaybackState() {
    if (_controllers.isEmpty) return;
    if (!_canPlay) {
      for (final controller in _controllers.values) {
        unawaited(controller.pause());
        unawaited(controller.setVolume(0.0));
      }
      return;
    }
    final controller = _controllers[_currentIndex];
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    unawaited(controller.setVolume(_isMuted ? 0.0 : 1.0));
    unawaited(controller.play());
  }

  void _onPageChanged(int idx) {
    setState(() {
      _currentIndex = idx;
    });
    _initControllerForIndex(idx);
    _disposeFarControllers(idx);
    final c = _controllers[idx];
    if (c != null && _canPlay) {
      if (c.value.isInitialized) {
        if (!_isMuted) c.setVolume(1.0);
        c.play();
      }
    }
  }

  String _toId(dynamic v) => (v ?? '').toString().trim();

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  void _openSearch() {
    Navigator.of(context).pushNamed('/search');
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchDropdownVisible = false;
      _searchLoading = false;
      _searchLoadingMore = false;
      _searchInput = '';
      _searchResults = [];
      _searchQuery = '';
      _searchPage = 1;
      _searchHasMore = true;
      _searchEpoch++;
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
    try {
      if (_searchScrollController.hasClients) {
        _searchScrollController.jumpTo(0);
      }
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    final next = value;
    setState(() {
      _searchInput = next;
    });
    _searchDebounce?.cancel();

    if (next.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchDropdownVisible = false;
        _searchLoading = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(next));
    });
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchResults = [];
        _searchDropdownVisible = false;
      });
      return;
    }

    final epoch = ++_searchEpoch;
    setState(() {
      _searchLoading = true;
      _searchLoadingMore = false;
      _searchDropdownVisible = true;
      _searchQuery = q;
      _searchPage = 1;
      _searchHasMore = true;
    });

    try {
      final results = await _promoteService.searchPromotes(
          q: q, page: 1, limit: _searchPageSize);
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _searchResults =
            results.map((e) => Map<String, dynamic>.from(e)).toList();
        _searchLoading = false;
        _searchHasMore = results.length >= _searchPageSize;
        _searchDropdownVisible = true;
      });
    } catch (_) {
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _searchResults = [];
        _searchLoading = false;
        _searchLoadingMore = false;
        _searchHasMore = false;
        _searchDropdownVisible = true;
      });
    }
  }

  void _onSearchScroll() {
    if (!_searchOpen || !_searchDropdownVisible) return;
    if (_searchLoading || _searchLoadingMore) return;
    if (!_searchHasMore) return;
    if (!_searchScrollController.hasClients) return;

    final pos = _searchScrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    final remaining = pos.maxScrollExtent - pos.pixels;
    if (remaining > 160) return;
    unawaited(_loadMoreSearch());
  }

  Future<void> _loadMoreSearch() async {
    final q = _searchQuery.trim();
    if (q.isEmpty) return;
    if (_searchLoading || _searchLoadingMore) return;
    if (!_searchHasMore) return;

    final epoch = _searchEpoch;
    final nextPage = _searchPage + 1;
    setState(() => _searchLoadingMore = true);
    try {
      final next = await _promoteService.searchPromotes(
        q: q,
        page: nextPage,
        limit: _searchPageSize,
      );
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _searchPage = nextPage;
        _searchResults = [
          ..._searchResults,
          ...next.map((e) => Map<String, dynamic>.from(e)),
        ];
        _searchHasMore = next.length >= _searchPageSize;
        _searchLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _searchHasMore = false;
        _searchLoadingMore = false;
      });
    }
  }

  Future<void> _handleSearchPromoteTap(Map<String, dynamic> item) async {
    final id = _toId(item['id'] ?? item['_id'] ?? item['promote_reel_id']);
    _closeSearch();
    if (id.isEmpty) return;

    final idx = _promotes.indexWhere((p) {
      final pid = _toId(p['id'] ?? p['_id'] ?? p['promote_reel_id']);
      return pid == id;
    });
    if (idx >= 0) {
      await _pageController.animateToPage(
        idx,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    try {
      final raw = await _promoteReelsApi.getPromoteReelById(id);
      dynamic payload = raw;
      if (raw['data'] is Map) payload = raw['data'];
      final mapped = _promoteService.mapPromote(payload);
      if (!mounted) return;
      setState(() {
        _promotes = [..._promotes, Map<String, dynamic>.from(mapped)];
      });
      final nextIndex = _promotes.length - 1;
      await _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      unawaited(_initControllerForIndex(nextIndex));
      unawaited(_loadFollowStatuses());
    } catch (_) {
      // ignore
    }
  }

  Future<void> _toggleLike(int index) async {
    if (index < 0 || index >= _promotes.length) return;
    final item = Map<String, dynamic>.from(_promotes[index]);
    final id = _toId(item['id'] ?? item['_id'] ?? item['promote_reel_id']);
    if (id.isEmpty) return;

    final wasLiked =
        item['isLikedByMe'] == true || item['is_liked_by_me'] == true;
    final cur =
        _toInt(item['likesCount'] ?? item['likes_count'] ?? item['likes']);
    final nextLiked = !wasLiked;
    final nextCount =
        (cur + (nextLiked ? 1 : -1)) < 0 ? 0 : (cur + (nextLiked ? 1 : -1));

    setState(() {
      _promotes[index] = Map<String, dynamic>.from({
        ...item,
        'isLikedByMe': nextLiked,
        'likesCount': nextCount,
        'likes': nextCount.toString(),
      });
    });

    try {
      if (wasLiked) {
        await _promoteReelsApi.unlikePromoteReel(id);
      } else {
        await _promoteReelsApi.likePromoteReel(id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _promotes[index] = Map<String, dynamic>.from({
          ...item,
          'isLikedByMe': wasLiked,
          'likesCount': cur,
          'likes': cur.toString(),
        });
      });
    }
  }

  Future<void> _toggleSave(int index) async {
    if (index < 0 || index >= _promotes.length) return;
    final item = Map<String, dynamic>.from(_promotes[index]);
    final postId = _toId(item['postId'] ?? item['post_id']);
    final id = postId.isNotEmpty
        ? postId
        : _toId(item['id'] ?? item['_id'] ?? item['promote_reel_id']);
    if (id.isEmpty) return;

    final wasSaved =
        item['isSavedByMe'] == true || item['is_saved_by_me'] == true;
    final nextSaved = !wasSaved;

    setState(() {
      _promotes[index] = {
        ...item,
        'isSavedByMe': nextSaved,
      };
    });

    try {
      final persisted =
          await _supabaseService.setPostSaved(id, save: nextSaved);
      if (!mounted) return;
      setState(() {
        final it = Map<String, dynamic>.from(_promotes[index]);
        _promotes[index] = {
          ...it,
          'isSavedByMe': persisted,
        };
      });
    } catch (_) {
      // best-effort only
    }
  }

  Future<void> _openComments(int index) async {
    if (index < 0 || index >= _promotes.length) return;
    final item = Map<String, dynamic>.from(_promotes[index]);
    final id = _toId(item['id'] ?? item['_id'] ?? item['promote_reel_id']);
    if (id.isEmpty) return;
    final cur = _toInt(
        item['commentsCount'] ?? item['comments_count'] ?? item['comments']);
    await PromoteCommentsSheet.show(
      context,
      promoteReelId: id,
      initialCount: cur,
      onCountChanged: (next) {
        if (!mounted) return;
        setState(() {
          final it = Map<String, dynamic>.from(_promotes[index]);
          _promotes[index] = {
            ...it,
            'commentsCount': next,
            'comments': next.toString(),
          };
        });
      },
    );
  }

  Future<void> _openShare(int index) async {
    if (index < 0 || index >= _promotes.length) return;
    final item = Map<String, dynamic>.from(_promotes[index]);
    final id = _toId(item['id'] ?? item['_id'] ?? item['promote_reel_id']);
    if (id.isEmpty) return;
    await ShareContentModal.show(
      context,
      contentType: 'promote',
      contentId: id,
    );
  }

  Future<void> _toggleFollow(int index) async {
    if (index < 0 || index >= _promotes.length) return;
    final item = Map<String, dynamic>.from(_promotes[index]);
    final userId = _toId(item['userId'] ?? item['user_id']);
    if (userId.isEmpty) return;
    if (_myUserId != null && _myUserId!.isNotEmpty && userId == _myUserId) {
      return;
    }
    if (_followLoadingUserIds.contains(userId)) return;
    final was = _followByUserId[userId] == true;
    setState(() => _followLoadingUserIds.add(userId));
    setState(() {
      _followByUserId[userId] = !was;
    });
    try {
      if (was) {
        await _followsApi.unfollow(userId);
      } else {
        try {
          await _followsApi.follow(userId);
        } catch (_) {
          await _followsApi.followById(userId);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _followByUserId[userId] = was;
      });
    } finally {
      if (!mounted) return;
      setState(() => _followLoadingUserIds.remove(userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final viewPaddingBottom = view.padding.bottom / view.devicePixelRatio;
    final mqViewPaddingBottom = mq.viewPadding.bottom;
    final mqPaddingBottom = mq.padding.bottom;
    double bottomSystemInset = viewPaddingBottom;
    if (mqViewPaddingBottom > bottomSystemInset) {
      bottomSystemInset = mqViewPaddingBottom;
    }
    if (mqPaddingBottom > bottomSystemInset) {
      bottomSystemInset = mqPaddingBottom;
    }
    if (_cachedBottomInset > bottomSystemInset) {
      bottomSystemInset = _cachedBottomInset;
    }
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: DesignTokens.instaPink)),
      );
    }
    if (_promotes.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Text('No promoted content yet.',
                style: TextStyle(color: Colors.grey.shade400))),
      );
    }
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: _promotes.length,
            itemBuilder: (context, index) {
              final item = _promotes[index];
              final products = (item['products'] as List<dynamic>?) ?? [];
              final controller = _controllers[index];
              final thumbSrc = (item['thumbnailUrl'] ?? '').toString().trim();
              final actionsBottom = 96.0 + bottomSystemInset;
              final likesCount = _toInt(
                  item['likesCount'] ?? item['likes_count'] ?? item['likes']);
              final commentsCount = _toInt(item['commentsCount'] ??
                  item['comments_count'] ??
                  item['comments']);
              final isLiked =
                  item['isLikedByMe'] == true || item['is_liked_by_me'] == true;
              final uid = _toId(item['userId'] ?? item['user_id']);
              final caption = (item['caption'] ?? item['description'] ?? '')
                  .toString()
                  .trim();
              final tagsRaw = item['tags'];
              final tags = <String>[];
              if (tagsRaw is List) {
                for (final t in tagsRaw) {
                  final s = (t ?? '').toString().trim();
                  if (s.isEmpty) continue;
                  tags.add(s.startsWith('#') ? s : '#$s');
                }
              }
              final productsOpen = _productsOpenByIndex[index] ?? true;
              final productsToggleHeight = products.isNotEmpty ? 28.0 : 0.0;
              final productsListHeight =
                  (products.isNotEmpty && productsOpen) ? (10.0 + 82.0) : 0.0;
              final productsPanelHeight =
                  productsToggleHeight + productsListHeight;
              final infoBottomPadding =
                  bottomSystemInset + 12.0 + productsPanelHeight + 12.0;
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  // 0. Solid black for nav bar zone
                  if (bottomSystemInset > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: bottomSystemInset,
                      child: const ColoredBox(color: Colors.black),
                    ),
                  // Video
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: bottomSystemInset,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumbSrc.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: thumbSrc,
                            fit: BoxFit.cover,
                            httpHeaders:
                                UrlHelper.shouldAttachAuthHeader(thumbSrc)
                                    ? _mediaHeaders
                                    : null,
                            placeholder: (_, __) => const ColoredBox(
                              color: Colors.black,
                            ),
                            errorWidget: (_, __, ___) => const ColoredBox(
                              color: Colors.black,
                            ),
                          )
                        else
                          const ColoredBox(color: Colors.black),
                        if (controller != null &&
                            controller.value.isInitialized)
                          () {
                            final ar = controller.value.aspectRatio;
                            final target = 9 / 16;
                            final isNineSixteen = ar.isFinite &&
                                ar > 0 &&
                                (ar - target).abs() < 0.06;
                            if (isNineSixteen) {
                              return ClipRect(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: controller.value.size.width,
                                    height: controller.value.size.height,
                                    child: VideoPlayer(controller),
                                  ),
                                ),
                              );
                            }
                            return ColoredBox(
                              color: Colors.black,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: ar,
                                  child: VideoPlayer(controller),
                                ),
                              ),
                            );
                          }(),
                        if (controller == null ||
                            !controller.value.isInitialized)
                          const ColoredBox(
                            color: Colors.transparent,
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Gradient overlay
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: bottomSystemInset,
                    child: IgnorePointer(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right side actions (aligned with Ads layout)
                  Positioned(
                    right: 4,
                    bottom: actionsBottom,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GlassActionButton(
                            icon: LucideIcons.eye,
                            label: _fmt(_toInt(item['viewsCount'] ??
                                item['views_count'] ??
                                item['views'] ??
                                item['currentViews'] ??
                                item['current_views'])),
                            onTap: () {},
                          ),
                          const SizedBox(height: 16),
                          GlassActionButton(
                            icon: isLiked ? Icons.favorite : LucideIcons.heart,
                            label: _fmt(likesCount),
                            iconColor: isLiked ? Colors.red : Colors.white,
                            onTap: () => _toggleLike(index),
                          ),
                          const SizedBox(height: 16),
                          GlassActionButton(
                            icon: LucideIcons.messageCircle,
                            label: _fmt(commentsCount),
                            onTap: () => _openComments(index),
                          ),
                          const SizedBox(height: 16),
                          GlassActionButton(
                            icon: LucideIcons.send,
                            label: '',
                            rotate: -0.2,
                            onTap: () => _openShare(index),
                          ),
                          const SizedBox(height: 16),
                          GlassActionButton(
                            icon: (item['isSavedByMe'] == true ||
                                    item['is_saved_by_me'] == true)
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            label: '',
                            onTap: () => _toggleSave(index),
                          ),
                          const SizedBox(height: 16),
                          GlassActionButton(
                            icon: _isMuted
                                ? LucideIcons.volumeX
                                : LucideIcons.volume2,
                            label: '',
                            onTap: () {
                              setState(() {
                                _isMuted = !_isMuted;
                                final c = _controllers[_currentIndex];
                                if (c != null && _canPlay) {
                                  c.setVolume(_isMuted ? 0.0 : 1.0);
                                } else if (c != null) {
                                  c.setVolume(0.0);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom: user + caption + tags (bounded within the page height)
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 92,
                        bottom: infoBottomPadding,
                      ),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PromoteUsernamePill(
                                item: item,
                                isFollowing: _followByUserId[uid] == true,
                                isFollowLoading:
                                    _followLoadingUserIds.contains(uid),
                                showFollow: uid.isNotEmpty &&
                                    (_myUserId == null ||
                                        _myUserId!.isEmpty ||
                                        uid != _myUserId),
                                onFollowTap: () => _toggleFollow(index),
                              ),
                              if (caption.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  caption,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.25,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        offset: Offset(0, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (tags.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: tags.take(3).map((t) {
                                    return Text(
                                      t,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.70),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black45,
                                            offset: Offset(0, 1),
                                            blurRadius: 2,
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Progress bar (like Ads/Reels)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomSystemInset,
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 4,
                          color: Colors.white.withValues(alpha: 0.22),
                          child: (controller != null &&
                                  controller.value.isInitialized)
                              ? _SmoothVideoProgressBar(controller: controller)
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),

                  // Products cards (anchored at bottom like before).
                  if (products.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: bottomSystemInset + 12,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _productsOpenByIndex[index] = !productsOpen;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.30),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.20),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.shoppingBag,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      productsOpen
                                          ? 'Hide Products'
                                          : '${products.length} Product${products.length > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            opacity: productsOpen ? 1 : 0,
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              child: productsOpen
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: SizedBox(
                                        height: 82,
                                        child: ListView.separated(
                                          clipBehavior: Clip.none,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          scrollDirection: Axis.horizontal,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          itemCount:
                                              products.length.clamp(0, 8),
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 10),
                                          itemBuilder: (context, i) {
                                            final p = products[i] is Map
                                                ? Map<String, dynamic>.from(
                                                    products[i] as Map)
                                                : <String, dynamic>{};
                                            return _MiniProductCard(product: p);
                                          },
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: _searchOpen
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.20),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.search,
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      onChanged: _onSearchChanged,
                                      onSubmitted: (value) =>
                                          _runSearch(value.trim()),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13),
                                      cursorColor: Colors.white,
                                      textInputAction: TextInputAction.search,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        border: InputBorder.none,
                                        hintText: 'Search promote reels…',
                                        hintStyle: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.60),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_searchLoading)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white70),
                                      ),
                                    )
                                  else if (_searchInput.trim().isNotEmpty)
                                    IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                      },
                                      icon: Icon(LucideIcons.x,
                                          color: Colors.white
                                              .withValues(alpha: 0.70),
                                          size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                              width: 28, height: 28),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _closeSearch,
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      child: Row(
                        children: [
                          const Spacer(),
                          IconButton(
                            icon: const Icon(LucideIcons.search,
                                color: Colors.white, size: 24),
                            onPressed: _openSearch,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (_searchOpen && _searchDropdownVisible)
            Positioned(
              left: 12,
              right: 12,
              top: mq.padding.top + 60,
              child: _PromoteSearchDropdown(
                query: _searchInput.trim(),
                loading: _searchLoading,
                loadingMore: _searchLoadingMore,
                results: _searchResults,
                controller: _searchScrollController,
                onTapResult: _handleSearchPromoteTap,
              ),
            ),
        ],
      ),
    );
  }

  void _showFeaturedProductsSheet(
      BuildContext context, List<dynamic> products) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text('Featured Products',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final prod = products[i] as Map<String, dynamic>;
                  return Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: (prod['image'] as String?) ?? '',
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                                child: Icon(LucideIcons.image,
                                    color: Colors.white54)),
                            errorWidget: (_, __, ___) => const Center(
                                child: Icon(LucideIcons.imageOff,
                                    color: Colors.white54)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            (prod['title'] as String?) ?? 'Product',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).then((_) => setState(() {}));
  }
}

class _SmoothVideoProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _SmoothVideoProgressBar({required this.controller});

  @override
  State<_SmoothVideoProgressBar> createState() =>
      _SmoothVideoProgressBarState();
}

class _SmoothVideoProgressBarState extends State<_SmoothVideoProgressBar>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _duration = Duration.zero;
  Duration _basePosition = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isPlaying = false;
  int _baseEpochMs = 0;

  static const int _snapBackToleranceMs = 120;
  int _lastNotifiedDurationMs = 0;
  int _lastNotifiedBasePosMs = -1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller.addListener(_onControllerValueChanged);
    _syncFromController();
  }

  @override
  void didUpdateWidget(covariant _SmoothVideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerValueChanged);
    widget.controller.addListener(_onControllerValueChanged);
    _syncFromController();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerValueChanged);
    _ticker?.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    setState(() {});
  }

  int _predictedPositionMs(int nowMs) {
    var positionMs = _basePosition.inMilliseconds;
    if (_isPlaying) {
      final elapsedMs = (nowMs - _baseEpochMs).clamp(0, 1 << 30);
      positionMs += (elapsedMs * _playbackSpeed).round();
    }
    return positionMs;
  }

  void _syncFromController() {
    if (!mounted) return;
    try {
      final value = widget.controller.value;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final nextDuration = value.duration;
      final nextSpeed = value.playbackSpeed;
      final nextIsPlaying = value.isPlaying;
      final controllerPos = value.position;

      _duration = nextDuration;

      if (_isPlaying && nextIsPlaying && _playbackSpeed != nextSpeed) {
        _basePosition = Duration(milliseconds: _predictedPositionMs(nowMs));
        _baseEpochMs = nowMs;
      }
      _playbackSpeed = nextSpeed;
      _isPlaying = nextIsPlaying;

      if (!_isPlaying) {
        _basePosition = controllerPos;
        _baseEpochMs = nowMs;
      } else {
        final predictedMs = _predictedPositionMs(nowMs);
        final controllerMs = controllerPos.inMilliseconds;
        if (controllerMs > predictedMs) {
          _basePosition = controllerPos;
          _baseEpochMs = nowMs;
        } else if (controllerMs < predictedMs - _snapBackToleranceMs) {
          _basePosition = controllerPos;
          _baseEpochMs = nowMs;
        }
      }
      _updateTicker();
    } catch (_) {
      _isPlaying = false;
      _updateTicker();
    }
  }

  void _onControllerValueChanged() {
    final wasPlaying = _isPlaying;
    _syncFromController();
    if (!mounted) return;
    final durMs = _duration.inMilliseconds;
    final baseMs = _basePosition.inMilliseconds;
    final durationChanged = durMs != _lastNotifiedDurationMs;
    final baseChanged = baseMs != _lastNotifiedBasePosMs;
    if (durationChanged) _lastNotifiedDurationMs = durMs;
    if (baseChanged) _lastNotifiedBasePosMs = baseMs;

    if (wasPlaying != _isPlaying || durationChanged || baseChanged) {
      setState(() {});
    }
  }

  void _updateTicker() {
    final ticker = _ticker;
    if (ticker == null) return;
    if (_isPlaying) {
      if (!ticker.isActive) ticker.start();
    } else {
      if (ticker.isActive) ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = _duration.inMilliseconds;
    if (durationMs <= 0) {
      // Keep layout stable; show empty fill until duration resolves.
      return const SizedBox.expand(child: SizedBox.shrink());
    }

    var positionMs = _basePosition.inMilliseconds;
    if (_isPlaying) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final elapsedMs = (nowMs - _baseEpochMs).clamp(0, 1 << 30);
      positionMs += (elapsedMs * _playbackSpeed).round();
    }
    final progress = (positionMs / durationMs).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: SizedBox.expand(
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: const ColoredBox(color: Colors.white),
        ),
      ),
    );
  }
}

class _PromoteUsernamePill extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool showFollow;
  final bool isFollowing;
  final bool isFollowLoading;
  final VoidCallback? onFollowTap;

  const _PromoteUsernamePill({
    required this.item,
    this.showFollow = false,
    this.isFollowing = false,
    this.isFollowLoading = false,
    this.onFollowTap,
  });

  String _safeLabel(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? 'User' : s;
  }

  String _initial(String label) {
    final t = label.trim();
    if (t.isEmpty) return 'U';
    final first = String.fromCharCode(t.runes.first);
    return first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        (item['avatarUrl'] ?? item['avatar_url'] ?? '').toString().trim();
    final displayName = _safeLabel(item['username'] ?? item['brandName']);
    final initial = _initial(displayName);
    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: DesignTokens.instaPurple.withValues(alpha: 0.25),
                        alignment: Alignment.center,
                        child: const Icon(LucideIcons.user,
                            size: 18, color: Colors.white70),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: DesignTokens.instaPurple.withValues(alpha: 0.25),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: DesignTokens.instaPurple.withValues(alpha: 0.25),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (showFollow) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: isFollowing
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: isFollowing
                      ? Colors.green.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.4),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: GestureDetector(
                onTap: isFollowLoading ? null : onFollowTap,
                child: Text(
                  isFollowLoading
                      ? '...'
                      : (isFollowing ? 'Following' : 'Follow'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          ],
        ],
      ),
    );
  }
}

class _PromoteSearchDropdown extends StatelessWidget {
  final String query;
  final bool loading;
  final bool loadingMore;
  final List<Map<String, dynamic>> results;
  final ScrollController controller;
  final ValueChanged<Map<String, dynamic>> onTapResult;

  const _PromoteSearchDropdown({
    required this.query,
    required this.loading,
    required this.loadingMore,
    required this.results,
    required this.controller,
    required this.onTapResult,
  });

  String _toId(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) return const SizedBox.shrink();
    final hasResults = results.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 360),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: loading && !hasResults
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: Center(
                  child: SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white70,
                    ),
                  ),
                ),
              )
            : (!hasResults
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'No results',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: results.length + (loadingMore ? 1 : 0),
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (context, index) {
                      if (loadingMore && index == results.length) {
                        return const Padding(
                          padding: EdgeInsets.all(14),
                          child: Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        );
                      }
                      final item = results[index];
                      final id = _toId(
                          item['id'] ?? item['_id'] ?? item['promote_reel_id']);
                      final username =
                          (item['username'] ?? 'User').toString().trim();
                      final caption =
                          (item['caption'] ?? item['description'] ?? '')
                              .toString()
                              .trim();
                      final avatar =
                          (item['avatarUrl'] ?? item['avatar_url'] ?? '')
                              .toString()
                              .trim();

                      return InkWell(
                        onTap: id.isEmpty ? null : () => onTapResult(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              _SearchAvatar(url: avatar, fallback: username),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username.isEmpty ? 'User' : username,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (caption.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        caption,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.72),
                                          fontSize: 12,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )),
      ),
    );
  }
}

class _SearchAvatar extends StatelessWidget {
  final String? url;
  final String fallback;

  const _SearchAvatar({this.url, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final initials =
        (fallback.trim().isEmpty ? '?' : fallback.trim()[0]).toUpperCase();
    final trimmed = (url ?? '').trim();
    if (trimmed.isEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white.withValues(alpha: 0.12),
        child: Text(
          initials,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: trimmed,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 36,
          height: 36,
          color: Colors.white.withValues(alpha: 0.10),
        ),
        errorWidget: (_, __, ___) => CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          child: Text(
            initials,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _MiniProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _MiniProductCard({required this.product});

  int _seed() {
    final id = product['id'];
    if (id is int) return id;
    return (product['title']?.toString() ?? '').hashCode.abs();
  }

  @override
  Widget build(BuildContext context) {
    final seed = _seed();
    final title = (product['title'] as String?)?.trim().isNotEmpty == true
        ? (product['title'] as String).trim()
        : 'Product';
    final imageUrl = (product['image'] as String?)?.trim() ?? '';

    final price = (product['price'] as num?)?.toInt() ?? (599 + (seed % 400));
    final mrp = (product['mrp'] as num?)?.toInt() ?? (price + 900 + seed % 600);
    final off = mrp > 0 ? (((mrp - price) * 100) / mrp).round() : 0;
    final rating =
        (product['rating'] as num?)?.toDouble() ?? (4.0 + (seed % 3) * 0.1);
    final rawWebsite = (product['websiteUrl'] ??
            product['website_url'] ??
            product['url'] ??
            product['link'])
        ?.toString()
        .trim();
    final websiteUrl = (rawWebsite ?? '').isEmpty
        ? ''
        : (rawWebsite!.startsWith('http://') ||
                rawWebsite.startsWith('https://')
            ? rawWebsite
            : 'https://$rawWebsite');

    return Container(
      width: 260,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(
                      color: Color(0xFFF1F5F9),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFF1F5F9),
                      child:
                          Center(child: Icon(LucideIcons.imageOff, size: 18)),
                    ),
                  )
                else
                  const ColoredBox(
                    color: Color(0xFFF1F5F9),
                    child: Center(child: Icon(LucideIcons.image, size: 18)),
                  ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          LucideIcons.star,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹$price',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '₹$mrp',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${off.clamp(0, 99)}% off',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (websiteUrl.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Website not available'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        final uri = Uri.tryParse(websiteUrl);
                        if (uri == null) return;
                        final ok = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (ok) return;
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ExternalLinkScreen(
                              url: websiteUrl,
                              title: title,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Visit Website',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
