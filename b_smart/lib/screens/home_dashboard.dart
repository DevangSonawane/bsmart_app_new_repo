import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/feed_service.dart';
import '../services/supabase_service.dart';
import '../services/wallet_service.dart';
import '../services/video_pool.dart';
import '../state/app_state.dart';
import '../state/profile_actions.dart';
import '../state/feed_actions.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_row.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/sidebar.dart';
import '../theme/design_tokens.dart';
import '../models/story_model.dart';
import '../models/feed_post_model.dart';
import '../models/media_model.dart';
import '../widgets/post_detail_modal.dart';
import '../widgets/comments_sheet.dart';
import 'ads_page_screen.dart';
import 'promote_screen.dart';
import 'reels_screen.dart';
import '../services/reels_service.dart';
import 'story_viewer_screen.dart';
import 'own_story_viewer_screen.dart';
import 'create_upload_screen.dart';
import '../utils/current_user.dart';
import '../api/auth_api.dart';
import '../api/api_exceptions.dart';
import '../api/api_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/url_helper.dart';
import '../widgets/dynamic_media_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'profile_screen.dart';
import '../routes.dart';

class HomeDashboard extends StatefulWidget {
  final int? initialIndex;

  const HomeDashboard({super.key, this.initialIndex});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with RouteAware, WidgetsBindingObserver {
  final FeedService _feedService = FeedService();
  final SupabaseService _supabase = SupabaseService();
  final WalletService _walletService = WalletService();
  final ReelsService _reelsService = ReelsService();
  String? _currentLocation;
  bool _locationLoading = false;

  List<Map<String, dynamic>> _storyUsers = [];
  List<StoryGroup> _storyGroups = [];
  List<Story> _myStories = [];
  String? _myStoryId;
  bool _yourStoryHasActive = false;
  Map<String, Map<String, bool>> _storyStatuses = {};
  int _currentIndex = 0;
  int _balance = 0;
  bool _reelsPrefetched = false;
  String? _activeFeedPostId;
  Timer? _activeFeedDebounce;

  final ScrollController _feedScrollController = ScrollController();
  final int _pageSize = 25;
  int _visibleCount = 0;
  int _pageCursor = 2; // next server page to try after initial default feed
  bool _pagingInFlight = false;
  bool _noMorePages = false;

  /// Current user profile from `users` table (same source as React web app) for header avatar.
  Map<String, dynamic>? _currentUserProfile;
  String? _currentUserId;
  bool get _isVendor =>
      (_currentUserProfile?['role']?.toString().toLowerCase() ?? '') ==
      'vendor';

  PageRoute<dynamic>? _subscribedRoute;
  bool _isRouteActive = true;
  bool _pendingHomeRefreshAfterRoute = false;
  Timer? _autoRefreshDebounce;
  DateTime? _lastAutoRefreshAt;

  bool? _parseBoolLike(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  String _extractAdId(String rawId) {
    var id = rawId.trim();
    if (id.startsWith('ad-')) {
      id = id.substring(3);
    }
    final slotIdx = id.indexOf('-slot-');
    if (slotIdx >= 0) {
      id = id.substring(0, slotIdx);
    }
    return id.trim();
  }

  bool? _extractLikedFlag(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final direct = _parseBoolLike(payload['is_liked_by_me']) ??
        _parseBoolLike(payload['liked_by_me']) ??
        _parseBoolLike(payload['is_liked']) ??
        _parseBoolLike(payload['liked']) ??
        _parseBoolLike(payload['isLiked']);
    if (direct != null) return direct;

    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return null;
    final rawLikes = payload['likes'];
    if (rawLikes is! List) return null;
    for (final e in rawLikes) {
      if (e is String && e == currentUserId) return true;
      if (e is Map) {
        final uid = (e['user_id'] ??
                e['id'] ??
                e['_id'] ??
                (e['user'] is Map ? (e['user'] as Map)['_id'] : null))
            ?.toString();
        if (uid != null && uid == currentUserId) return true;
      }
    }
    return false;
  }

  int? _extractLikesCount(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final value = payload['likes_count'] ?? payload['likesCount'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    final likes = payload['likes'];
    if (likes is List) return likes.length;
    return null;
  }

  Map<String, dynamic>? _normalizeProfile(Map<String, dynamic>? raw) {
    if (raw == null) return null;

    Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    if (raw['user'] is Map) {
      data = Map<String, dynamic>.from(raw['user'] as Map);
    } else if (raw['data'] is Map) {
      final wrapped = Map<String, dynamic>.from(raw['data'] as Map);
      if (wrapped['user'] is Map) {
        data = Map<String, dynamic>.from(wrapped['user'] as Map);
      } else {
        data = wrapped;
      }
    }

    final normalized = Map<String, dynamic>.from(data);
    final avatar = data['avatar_url'] ??
        data['avatarUrl'] ??
        data['photo_url'] ??
        data['photoUrl'];
    final username = data['username'] ?? data['user_name'];
    final fullName = data['full_name'] ?? data['fullName'] ?? data['name'];
    final id = data['id'] ?? data['_id'] ?? data['user_id'];
    final role = data['role'];
    final isActive = data['is_active'] ?? data['isActive'];

    if (avatar != null) normalized['avatar_url'] = avatar.toString();
    if (username != null) normalized['username'] = username.toString();
    if (fullName != null) normalized['full_name'] = fullName.toString();
    if (role != null) normalized['role'] = role.toString();
    if (isActive != null) normalized['is_active'] = isActive == true;
    if (id != null) {
      normalized['id'] = id.toString();
      normalized['_id'] = id.toString();
    }

    return normalized;
  }

  void _openProfile() {
    final userId = _currentUserId?.trim() ??
        (_currentUserProfile?['id']?.toString().trim()) ??
        (_currentUserProfile?['_id']?.toString().trim());
    if (userId != null && userId.isNotEmpty) {
      Navigator.of(context).pushNamed('/profile/$userId');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialIndex != null) {
      _currentIndex = widget.initialIndex!;
    }
    _feedScrollController.addListener(_onFeedScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(primeMediaAuthHeaders());
      final store = StoreProvider.of<AppState>(context);
      // Force a clean, fresh feed on app open to avoid stale or partial data.
      store.dispatch(SetFeedPosts(const []));
      store.dispatch(SetFeedLoading(true));
      _loadData(store);
      _loadInitialFeed(forceNetwork: true);
      _fetchCurrentLocation();
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

  @override
  void didPushNext() {
    if (!_isRouteActive) return;
    _isRouteActive = false;
    unawaited(VideoPool.instance.disposeActive());
    if (mounted) setState(() {});
  }

  @override
  void didPopNext() {
    if (_isRouteActive) return;
    _isRouteActive = true;
    if (_pendingHomeRefreshAfterRoute && _currentIndex == 0) {
      _pendingHomeRefreshAfterRoute = false;
      _scheduleHomeRefresh();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _activeFeedDebounce?.cancel();
    _autoRefreshDebounce?.cancel();
    _feedScrollController.removeListener(_onFeedScroll);
    _feedScrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;
    if (_currentIndex != 0) return;
    // When app resumes, jump to top and refresh to show latest posts.
    if (_feedScrollController.hasClients) {
      _feedScrollController.jumpTo(0);
    }
    final store = StoreProvider.of<AppState>(context);
    unawaited(Future.wait([_loadData(store), _loadInitialFeed(forceNetwork: true)]));
  }

  void _scheduleHomeRefresh() {
    _autoRefreshDebounce?.cancel();
    _autoRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (_currentIndex != 0) return;
      final last = _lastAutoRefreshAt;
      final now = DateTime.now();
      // 30 second cooldown — prevents feed reset on every back navigation
      if (last != null && now.difference(last) < const Duration(seconds: 30)) {
        return;
      }
      _lastAutoRefreshAt = now;
      final store = StoreProvider.of<AppState>(context);
      unawaited(Future.wait([_loadData(store), _loadInitialFeed(forceNetwork: true)]));
    });
  }

  Future<void> _loadData(Store<AppState> store) async {
    // Wrap the whole load sequence so we always clear loading and apply whatever data we could fetch.
    int bal = 0;
    List<StoryGroup> groups = const <StoryGroup>[];
    Map<String, dynamic>? meRaw;
    Map<String, dynamic>? currentProfileRaw;
    String? currentUserId;
    Map<String, dynamic> mergedProfile = {};

    try {
      // Use REST API-backed CurrentUser helper for the authenticated user ID.
      currentUserId = await CurrentUser.id;
      try {
        meRaw = await AuthApi().me();
      } catch (_) {
        meRaw = null;
      }
      final meProfile = _normalizeProfile(meRaw);
      try {
        currentProfileRaw = currentUserId != null
            ? await _supabase.getUserById(currentUserId)
            : null;
      } catch (_) {
        currentProfileRaw = null;
      }
      final currentProfile = _normalizeProfile(currentProfileRaw);
      mergedProfile = <String, dynamic>{
        ...?currentProfile,
        ...?meProfile,
      };
      final effectiveUserId = currentUserId ??
          (mergedProfile['id']?.toString()) ??
          (mergedProfile['_id']?.toString());

      try {
        bal = await _walletService.getCoinBalance();
      } catch (_) {
        bal = 0;
      }

      if (!_reelsPrefetched) {
        _reelsPrefetched = true;
        unawaited(() async {
          try {
            await _reelsService.fetchReels(limit: 20, offset: 0);
          } catch (_) {}
        }());
      }

      // Stories feed from backend
      try {
        groups = await _feedService.fetchStoriesFeed();
      } catch (_) {
        groups = const <StoryGroup>[];
      }

      final allGroups = List<StoryGroup>.from(groups);
      final myGroups = effectiveUserId != null
          ? allGroups.where((g) => g.userId == effectiveUserId).toList()
          : <StoryGroup>[];
      final otherGroups = effectiveUserId != null
          ? allGroups.where((g) => g.userId != effectiveUserId).toList()
          : allGroups;

      final baseStatuses = _computeStoryStatuses(otherGroups);
      final previousStatuses =
          Map<String, Map<String, bool>>.from(_storyStatuses);
      final mergedStatuses = <String, Map<String, bool>>{};
      for (final g in otherGroups) {
        final uid = g.userId;
        final current = baseStatuses[uid] ?? {};
        final prev = previousStatuses[uid];
        if (prev != null && prev['allViewed'] == true) {
          mergedStatuses[uid] = {
            ...current,
            'hasUnseen': false,
            'allViewed': true,
          };
        } else {
          mergedStatuses[uid] = current;
        }
      }

      otherGroups.sort((a, b) {
        final sa = mergedStatuses[a.userId] ?? const {};
        final sb = mergedStatuses[b.userId] ?? const {};
        final aHasUnseen = sa['hasUnseen'] == true;
        final bHasUnseen = sb['hasUnseen'] == true;
        if (aHasUnseen != bHasUnseen) {
          return aHasUnseen ? -1 : 1;
        }
        final ad = a.stories.isNotEmpty
            ? a.stories.first.createdAt
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.stories.isNotEmpty
            ? b.stories.first.createdAt
            : DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      final users = otherGroups.map((g) {
        return {
          'id': g.userId,
          'username': g.userName,
          'avatar_url': g.userAvatar,
        };
      }).toList();
      final my = effectiveUserId != null
          ? myGroups.expand((g) => g.stories).toList()
          : _buildMyStories(mergedProfile.isEmpty ? null : mergedProfile);

      // Apply to store and local state
      if (mounted) {
        setState(() {
          _currentUserProfile = mergedProfile.isEmpty ? null : mergedProfile;
          _currentUserId = effectiveUserId;
          _storyUsers = users;
          _storyGroups = otherGroups;
          _storyStatuses = mergedStatuses;
          _myStories = my;
          _myStoryId = myGroups.isNotEmpty ? myGroups.first.storyId : null;
          _yourStoryHasActive = _myStories.isNotEmpty;
          _balance = bal;
        });
        // Preload profile into Redux so ProfileScreen opens instantly
        if (effectiveUserId != null && mergedProfile.isNotEmpty) {
          store.dispatch(SetProfile(mergedProfile));
        }
      }
    } finally {
    }
  }

  Future<void> _loadInitialFeed({bool forceNetwork = false}) async {
    await primeMediaAuthHeaders(); // ensure auth headers ready before any image loads
    final store = StoreProvider.of<AppState>(context);
    final isFirstLoad = store.state.feedState.posts.isEmpty || forceNetwork;

    // Only show full-screen spinner on genuine first load
    if (isFirstLoad) {
      store.dispatch(SetFeedLoading(true));
      if (forceNetwork) {
        store.dispatch(SetFeedPosts(const []));
      }
    }

    final currentUserId = await CurrentUser.id;
    List<FeedPost> items = const <FeedPost>[];
    try {
      items = await _feedService.fetchFeedFromBackend(
        currentUserId: currentUserId,
        useBackendDefault: false,
        limit: _pageSize,
        cacheBuster: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      items = const <FeedPost>[];
    }
    // If backend returns too few posts, eagerly fetch next pages to fill the screen.
    var nextPageCursor = 2;
    var prefetchNoMore = false;
    if (items.isNotEmpty && items.length < _pageSize) {
      final seen = items.map((p) => p.id).toSet();
      var keepGoing = true;
      while (keepGoing && items.length < _pageSize) {
        List<FeedPost> pageItems = const <FeedPost>[];
        try {
          pageItems = await _feedService.fetchFeedFromBackend(
            limit: _pageSize,
            offset: (nextPageCursor - 1) * _pageSize,
            currentUserId: currentUserId,
            useBackendDefault: false,
            cacheBuster: DateTime.now().millisecondsSinceEpoch.toString(),
          );
        } catch (_) {
          pageItems = const <FeedPost>[];
        }
        if (pageItems.isEmpty) {
          keepGoing = false;
          prefetchNoMore = true;
          break;
        }
        final newOnes = pageItems.where((p) => !seen.contains(p.id)).toList();
        if (newOnes.isEmpty) {
          keepGoing = false;
          prefetchNoMore = true;
          break;
        }
        for (final p in newOnes) {
          seen.add(p.id);
        }
        items = [...items, ...newOnes];
        nextPageCursor += 1;
        // Safety: avoid unbounded prefetching on bad pagination.
        if (nextPageCursor > 4) {
          keepGoing = false;
        }
      }
    }
    if (!mounted) {
      if (isFirstLoad) store.dispatch(SetFeedLoading(false));
      return;
    }

    if (items.isNotEmpty) {
      await _precacheFeedMedia(items);
      if (!mounted) {
        if (isFirstLoad) store.dispatch(SetFeedLoading(false));
        return;
      }
    }

    store.dispatch(SetFeedPosts(items));

    setState(() {
      if (isFirstLoad || forceNetwork) {
        // First load only: start from top, reset everything
        _activeFeedPostId = items.isNotEmpty ? items.first.id : null;
        // Show ALL items from backend on first load, not just _pageSize
        _visibleCount = items.length;
      } else {
        // Background refresh: preserve current scroll depth
        // Just expand _visibleCount if new items arrived beyond current depth
        _visibleCount = math.max(
          _visibleCount,
          items.length,
        );
        // Do NOT reset _activeFeedPostId — user is mid-scroll
      }
      _pageCursor = nextPageCursor;
      _pagingInFlight = false;
      _noMorePages = items.isEmpty || prefetchNoMore;
    });

    if (isFirstLoad || forceNetwork) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_feedScrollController.hasClients) {
          _feedScrollController.jumpTo(0);
        }
      });
    }

    if (isFirstLoad) store.dispatch(SetFeedLoading(false));

    // If list is too short to scroll, proactively load next page
    if (items.isNotEmpty) {
      _checkIfListNeedsMorePosts();
      // Ensure we have a full initial batch without requiring a scroll.
      unawaited(_prefetchUntil(minPosts: _pageSize, maxPages: 3));
    }
  }

  Future<void> _precacheFeedMedia(List<FeedPost> posts) async {
    final token = await ApiClient().getToken();
    final authHeaders = <String, String>{};
    if (token != null && token.isNotEmpty) {
      authHeaders['Authorization'] = 'Bearer $token';
    }
    final context = this.context;
    final futures = <Future<void>>[];
    final limit = posts.length < 6 ? posts.length : 6;
    // Ensure the first reel/video thumbnail is cached before rendering feed.
    FeedPost? firstVideoPost;
    for (var i = 0; i < limit; i++) {
      final post = posts[i];
      if (post.mediaType == PostMediaType.video ||
          post.mediaType == PostMediaType.reel) {
        firstVideoPost = post;
        break;
      }
    }
    if (firstVideoPost != null &&
        (firstVideoPost.thumbnailUrl ?? '').isNotEmpty) {
      final url = firstVideoPost.thumbnailUrl!;
      final Map<String, String> headers =
          UrlHelper.shouldAttachAuthHeader(url)
              ? authHeaders
              : const <String, String>{};
      try {
        await precacheImage(
          CachedNetworkImageProvider(url, headers: headers),
          context,
        ).timeout(const Duration(seconds: 2));
      } catch (_) {
        // Best-effort only.
      }
    }
    for (var i = 0; i < limit; i++) {
      final post = posts[i];
      String? url;
      if (post.mediaType == PostMediaType.video ||
          post.mediaType == PostMediaType.reel) {
        url = post.thumbnailUrl;
        if ((url == null || url.isEmpty) && post.mediaUrls.isNotEmpty) {
          // Backend should provide thumbnailUrl for reels/videos.
        }
      } else if (post.mediaUrls.isNotEmpty) {
        url = post.mediaUrls.first;
      }
      if (url == null || url.isEmpty) continue;
      final Map<String, String> headers =
          UrlHelper.shouldAttachAuthHeader(url)
              ? authHeaders
              : const <String, String>{};
      futures.add(
        precacheImage(
          CachedNetworkImageProvider(url, headers: headers),
          context,
        ),
      );
    }
    try {
      await Future.wait(futures)
          .timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      // Best-effort prefetch only.
    }
  }

  Future<void> _prefetchUntil({
    required int minPosts,
    int maxPages = 3,
  }) async {
    if (!mounted || _pagingInFlight || _noMorePages) return;
    final store = StoreProvider.of<AppState>(context);
    var remainingPages = maxPages;
    while (mounted &&
        remainingPages > 0 &&
        !_noMorePages &&
        store.state.feedState.posts.length < minPosts) {
      await _fetchNextPage();
      remainingPages -= 1;
    }
  }

  void _checkIfListNeedsMorePosts() {
    _waitForScrollAndFetch(attempts: 20);
  }

  void _waitForScrollAndFetch({required int attempts}) {
    if (attempts <= 0) {
      // Last resort: just fetch regardless
      if (mounted && !_pagingInFlight && !_noMorePages) {
        _fetchNextPage();
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ScrollController not attached yet — try next frame
      if (!_feedScrollController.hasClients) {
        _waitForScrollAndFetch(attempts: attempts - 1);
        return;
      }
      final position = _feedScrollController.position;
      // If content doesn't fill the screen, load more immediately
      if (position.maxScrollExtent < 400) {
        _fetchNextPage();
      }
    });
  }

  void _onFeedScroll() {
    if (!_feedScrollController.hasClients) return;
    final store = StoreProvider.of<AppState>(context);
    final total = store.state.feedState.posts.length;
    final position = _feedScrollController.position;

    // Trigger if within 400px of bottom OR if list is short enough
    // that maxScrollExtent itself is under 400px
    final nearBottom = position.pixels >= position.maxScrollExtent - 400;
    final listIsShort = position.maxScrollExtent < 400 &&
        position.pixels >= position.maxScrollExtent - 50;

    if (nearBottom || listIsShort) {
      setState(() {
        _visibleCount = math.min(total, _visibleCount + _pageSize);
      });
      _maybeFetchNextPage(total);
    }
  }

  void _maybeFetchNextPage(int totalCount) {
    if (_pagingInFlight || _noMorePages) return;
    // If we are within one chunk of the end, try to fetch the next page
    final remaining = totalCount - _visibleCount;
    if (remaining > _pageSize ~/ 2) return;
    _fetchNextPage();
  }

  Future<void> _fetchNextPage() async {
    if (_pagingInFlight || _noMorePages) return;
    _pagingInFlight = true;
    final store = StoreProvider.of<AppState>(context);
    final currentUserId = await CurrentUser.id;
    final existingIds = store.state.feedState.posts.map((p) => p.id).toSet();
    List<FeedPost> pageItems = const <FeedPost>[];
    try {
      // Use classic pagination for deeper pages
      pageItems = await _feedService.fetchFeedFromBackend(
        limit: _pageSize,
        offset: (_pageCursor - 1) * _pageSize,
        currentUserId: currentUserId,
        useBackendDefault: false,
        cacheBuster: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      pageItems = const <FeedPost>[];
    }
    if (!mounted) {
      _pagingInFlight = false;
      return;
    }
    final newOnes = pageItems.where((p) => !existingIds.contains(p.id)).toList();
    if (newOnes.isEmpty) {
      _noMorePages = true;
      _pagingInFlight = false;
      return;
    }
    store.dispatch(AppendFeedPosts(newOnes));
    setState(() {
      _pageCursor += 1;
      final totalNow = store.state.feedState.posts.length;
      _visibleCount = math.min(totalNow, _visibleCount + _pageSize);
    });
    _pagingInFlight = false;

    // If screen still not filled after appending, keep fetching
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_feedScrollController.hasClients &&
          _feedScrollController.position.maxScrollExtent < 400 &&
          !_noMorePages) {
        _fetchNextPage();
      }
    });
  }

  void _onFeedItemVisibilityChanged(String postId, double visibleFraction) {
    if (_currentIndex != 0) return;
    if (visibleFraction < 0.65) return;
    if (_activeFeedPostId == postId) return;
    _activeFeedDebounce?.cancel();
    _activeFeedDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (_currentIndex != 0) return;
      if (_activeFeedPostId == postId) return;
      setState(() => _activeFeedPostId = postId);
    });
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      if (mounted) setState(() => _locationLoading = true);
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationLoading = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String loc;
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.name ?? '').isNotEmpty) p.name!,
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
          if ((p.country ?? '').isNotEmpty) p.country!,
        ];
        loc = parts.where((e) => e.trim().isNotEmpty).toList().join(', ');
      } else {
        loc =
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      }
      if (mounted) {
        setState(() {
          _currentLocation = loc;
          _locationLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  // Like toggle - same as React PostCard: update post.likes array on posts table
  void _onLikePost(FeedPost post) async {
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like posts')),
        );
      }
      return;
    }
    final desired = !post.isLiked;
    final optimisticLikes =
        desired ? post.likes + 1 : (post.likes > 0 ? post.likes - 1 : 0);
    final store = StoreProvider.of<AppState>(context);
    store.dispatch(UpdatePostLiked(post.id, desired));
    if (mounted)
      setState(() {}); // trigger rebuild to reflect optimistic change
    final liked = await _supabase.setPostLike(post.id, like: desired);
    if (!mounted) return;
    try {
      final p = await SupabaseService().getPostById(post.id);
      final serverLiked = _extractLikedFlag(p) ?? liked;
      final likesCount = _extractLikesCount(p) ?? optimisticLikes;
      store
          .dispatch(UpdatePostLikedWithCount(post.id, serverLiked, likesCount));
      if (mounted) setState(() {}); // reflect reconciled count/color
    } catch (_) {
      store.dispatch(UpdatePostLikedWithCount(post.id, liked, optimisticLikes));
      if (mounted) setState(() {}); // reflect reconciled state
    }
  }

  void _onDoubleTapLikePost(FeedPost post) {
    if (!post.isLiked) {
      _onLikePost(post);
    }
  }

  void _onCommentPost(FeedPost post) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final treatAsAd = post.isAd || (post.adTitle?.trim().isNotEmpty ?? false);
    if (treatAsAd) {
      final adId = _extractAdId(post.id);
      if (adId.isEmpty) return;
      if (isMobile) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          builder: (_) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: AdCommentsSheet(adId: adId),
          ),
        );
      } else {
        showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Comments',
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (context, _, __) {
            return SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 360,
                  height: MediaQuery.of(context).size.height * 0.78,
                  margin: const EdgeInsets.only(right: 18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.08),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AdCommentsSheet(adId: adId),
                ),
              ),
            );
          },
        );
      }
      return;
    }
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.9,
          child: CommentsSheet(postId: post.id),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PostDetailModal(postId: post.id),
        ),
      );
    }
  }

  void _onSharePost(FeedPost post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share link copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onSavePost(FeedPost post) async {
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save posts')),
        );
      }
      return;
    }
    final desired = !post.isSaved;
    final store = StoreProvider.of<AppState>(context);
    store.dispatch(UpdatePostSaved(post.id, desired));
    if (mounted) setState(() {});
    final saved = await _supabase.setPostSaved(post.id, save: desired);
    if (!mounted) return;
    try {
      final p = await SupabaseService().getPostById(post.id);
      final serverSaved = (p?['is_saved_by_me'] as bool?) ?? saved;
      store.dispatch(UpdatePostSaved(post.id, serverSaved));
      if (mounted) setState(() {});
    } catch (_) {
      store.dispatch(UpdatePostSaved(post.id, saved));
      if (mounted) setState(() {});
    }
  }

  void _onFollowPost(FeedPost post) {
    final followed = !post.isFollowed;
    final store = StoreProvider.of<AppState>(context);

    // 1. Optimistic UI Update
    store.dispatch(UpdatePostFollowed(post.id, followed));
    if (mounted) setState(() {});

    // Snackbar notification removed for a cleaner experience

    // 2. Call Service & Handle Result
    () async {
      final success = followed
          ? await _supabase.followUser(post.userId)
          : await _supabase.unfollowUser(post.userId);

      if (!mounted) return;

      if (!success) {
        // Revert UI if API failed
        store.dispatch(UpdatePostFollowed(post.id, !followed));
        setState(() {});
      } else {
        // Success: Update "My Profile" following count in Redux
        final meId = await CurrentUser.id;
        if (meId == null || meId.isEmpty) return;

        final cachedProfile = store.state.profileState.profile;
        final cachedId = cachedProfile?['id']?.toString() ??
            cachedProfile?['_id']?.toString();

        // Only update if the cached profile belongs to the current user
        if (cachedId != null && cachedId == meId) {
          final delta = followed ? 1 : -1;
          store.dispatch(AdjustFollowingCount(delta));
        }
      }
    }();
  }

  void _onMorePost(BuildContext context, FeedPost post) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.not_interested_outlined),
              title: const Text('Not interested'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('We\'ll show you less like this')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Link copied'),
                      behavior: SnackBarBehavior.floating),
                );
              },
            ),
            FutureBuilder<String?>(
              future: CurrentUser.id,
              builder: (context, snapshot) {
                final isOwner =
                    snapshot.data != null && snapshot.data == post.userId;
                if (!isOwner) return const SizedBox.shrink();
                return ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Post',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    bool isDeleting = false;
                    await showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (dctx) {
                        return StatefulBuilder(
                          builder: (context, setState) {
                            return Center(
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.9,
                                  constraints:
                                      const BoxConstraints(maxWidth: 360),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Theme.of(context).dividerColor),
                                  ),
                                  child: isDeleting
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 8),
                                            const SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 4,
                                                color: Colors.red,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Deleting post...',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 4),
                                            const Text(
                                              'Delete Post?',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Are you sure you want to delete this post? This action cannot be undone.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text('Cancel'),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.red,
                                                      foregroundColor:
                                                          Colors.white,
                                                    ),
                                                    onPressed: () async {
                                                      setState(() =>
                                                          isDeleting = true);
                                                      try {
                                                        final ok =
                                                            await SupabaseService()
                                                                .deletePost(
                                                                    post.id);
                                                        await Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                    1500));
                                                        if (ok) {
                                                          if (mounted) {
                                                            StoreProvider.of<
                                                                        AppState>(
                                                                    context)
                                                                .dispatch(
                                                                    RemovePost(
                                                                        post.id));
                                                            Navigator.pop(
                                                                context);
                                                            messenger.showSnackBar(
                                                                const SnackBar(
                                                                    content: Text(
                                                                        'Post deleted')));
                                                          }
                                                        } else {
                                                          if (mounted) {
                                                            setState(() =>
                                                                isDeleting =
                                                                    false);
                                                            Navigator.pop(
                                                                context);
                                                            messenger.showSnackBar(
                                                                const SnackBar(
                                                                    content: Text(
                                                                        'Failed to delete post')));
                                                          }
                                                        }
                                                      } on ApiException catch (e) {
                                                        if (mounted) {
                                                          setState(() =>
                                                              isDeleting =
                                                                  false);
                                                          Navigator.pop(
                                                              context);
                                                          messenger.showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      e.message)));
                                                        }
                                                      } catch (e) {
                                                        if (mounted) {
                                                          setState(() =>
                                                              isDeleting =
                                                                  false);
                                                          Navigator.pop(
                                                              context);
                                                          messenger.showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      e.toString())));
                                                        }
                                                      }
                                                    },
                                                    child: const Text('Delete'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector({required bool isDark}) {
    return InkWell(
      onTap: () {
        _fetchCurrentLocation();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
          border: Border(
            bottom: BorderSide(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.house,
              size: 16,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'HOME ',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: _currentLocation == null
                          ? (_locationLoading
                              ? 'Detecting current location...'
                              : 'Tap to detect location')
                          : _currentLocation!,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  List<StoryGroup> _buildStoryGroupsFromUsers(
      List<Map<String, dynamic>> users) {
    final now = DateTime.now();
    return users.asMap().entries.map((entry) {
      final idx = entry.key;
      final u = entry.value;
      final username = (u['username'] ?? u['full_name'] ?? 'User').toString();
      final userId = (u['id'] ?? '').toString();
      return StoryGroup(
        userId: userId,
        userName: username,
        userAvatar: u['avatar_url'] as String?,
        isOnline: true,
        isCloseFriend: idx < 2,
        isSubscribedCreator: idx == 1,
        stories: [
          Story(
            id: 'story-$userId',
            userId: userId,
            userName: username,
            userAvatar: u['avatar_url'] as String?,
            mediaUrl:
                'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400',
            mediaType: StoryMediaType.image,
            createdAt: now.subtract(const Duration(hours: 2)),
            views: 0,
            isViewed: idx % 3 == 0,
            productUrl:
                idx == 0 ? 'https://bsmart.asynk.store/product/123' : null,
            externalLink: idx == 3 ? 'https://example.com' : null,
            hasPollQuiz: idx == 4,
          ),
        ],
      );
    }).toList();
  }

  Map<String, Map<String, bool>> _computeStoryStatuses(
      List<StoryGroup> groups) {
    final map = <String, Map<String, bool>>{};
    for (final g in groups) {
      final hasUnseen = g.stories.any((s) => s.isViewed == false);
      final allViewed =
          g.stories.isNotEmpty && g.stories.every((s) => s.isViewed == true);
      map[g.userId] = {
        'isCloseFriend': g.isCloseFriend,
        'hasUnseen': hasUnseen,
        'allViewed': allViewed,
        'isSubscribedCreator': g.isSubscribedCreator,
        'segments': g.stories.length > 1,
      };
    }
    return map;
  }

  List<Story> _buildMyStories(Map<String, dynamic>? profile) {
    final now = DateTime.now();
    if (profile == null) return [];
    return [
      Story(
        id: 'my-story-1',
        userId: (profile['id'] ?? 'me').toString(),
        userName:
            (profile['username'] ?? profile['full_name'] ?? 'You').toString(),
        userAvatar: profile['avatar_url'] as String?,
        mediaUrl:
            'https://images.unsplash.com/photo-1606787366850-de6330128bfc?w=400',
        mediaType: StoryMediaType.image,
        createdAt: now.subtract(const Duration(minutes: 30)),
        views: 12,
        isViewed: false,
      ),
    ];
  }

  void _onStoryTap(int userIndex) async {
    // Stop any currently playing feed video audio before opening stories.
    await VideoPool.instance.disposeActive();
    if (userIndex < 0 || userIndex >= _storyGroups.length) return;
    final group = _storyGroups[userIndex];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoryViewerScreen(
          storyGroups: _storyGroups,
          initialIndex: userIndex,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      final existing = _storyStatuses[group.userId] ?? {};
      _storyStatuses[group.userId] = {
        ...existing,
        'hasUnseen': false,
        'allViewed': true,
      };
    });
    await _onSilentRefresh();
  }

  // Pull-to-refresh: user explicitly wants fresh content from top
  Future<void> _onRefresh() async {
    final store = StoreProvider.of<AppState>(context);
    if (_feedScrollController.hasClients) {
      _feedScrollController.jumpTo(0);
    }
    // Clear Redux posts so isFirstLoad = true in _loadInitialFeed
    store.dispatch(SetFeedPosts(const []));
    await Future.wait([_loadData(store), _loadInitialFeed(forceNetwork: true)]);
  }

  // Silent background refresh after story/route pop — preserve scroll
  Future<void> _onSilentRefresh() async {
    final store = StoreProvider.of<AppState>(context);
    await Future.wait([_loadData(store), _loadInitialFeed(forceNetwork: true)]);
  }

  Future<void> _openStoryCamera() async {
    await Navigator.of(context).pushNamed('/story-camera');
    if (!mounted) return;
    await _onSilentRefresh();
  }

  void _openVendorAdComposer(String contentType) {
    final mode =
        contentType.toLowerCase() == 'reel' ? UploadMode.reel : UploadMode.post;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateUploadScreen(
          initialMode: mode,
          isAdFlow: true,
        ),
      ),
    );
  }

  void _onNavTap(int idx) {
    if (idx == 2) {
      _pendingHomeRefreshAfterRoute = true;
      if (_isVendor) {
        _openVendorAdComposer('post');
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CreateUploadScreen(
              initialMode: UploadMode.post,
            ),
          ),
        );
      }
      return;
    }
    // Profile from sidebar (desktop)
    if (idx == 5) {
      _openProfile();
      return;
    }

    final wasOnHome = _currentIndex == 0;
    final switchingToHome = idx == 0 && !wasOnHome; // ← only true when actually switching

    if (idx != _currentIndex) {
      if (idx == 4 && !_reelsPrefetched) {
        _reelsPrefetched = true;
        unawaited(() async {
          try {
            await _reelsService.fetchReels(limit: 20, offset: 0);
          } catch (_) {}
        }());
      }
      // Pause any in-feed video audio while switching away from Home.
      if (wasOnHome) {
        unawaited(VideoPool.instance.disposeActive());
      }
      setState(() {
        _currentIndex = idx;
      });
    }

    // Only schedule refresh when genuinely navigating TO home from another tab
    // NOT when tapping home while already on home (that would be Instagram's
    // scroll-to-top behavior which we handle separately)
    if (switchingToHome) {
      _scheduleHomeRefresh();
    } else if (idx == 0 && wasOnHome) {
      // Already on home — scroll to top like Instagram does
      if (_feedScrollController.hasClients) {
        _feedScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _showCreateModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Create',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      gradient: DesignTokens.instaGradient,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(LucideIcons.image,
                      color: Colors.white, size: 22),
                ),
                title: Text(_isVendor ? 'Create Ads' : 'Create Post'),
                subtitle: Text(
                  _isVendor ? 'Upload ad campaign' : 'Photo or video',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => _isVendor
                            ? const CreateUploadScreen(
                                initialMode: UploadMode.post,
                                isAdFlow: true,
                              )
                            : const CreateUploadScreen(
                                initialMode: UploadMode.post,
                              ),
                      ),
                    );
                  });
                },
              ),
              if (!_isVendor)
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        gradient: DesignTokens.instaGradient,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.video,
                        color: Colors.white, size: 22),
                  ),
                  title: const Text('Upload Reel'),
                  subtitle: Text('Short video',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CreateUploadScreen(
                              initialMode: UploadMode.reel,
                            ),
                          ),
                        );
                      }
                    });
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreProvider.of<AppState>(context);
    final feedState = store.state.feedState;
    final totalCount = feedState.posts.length;
    final effectiveVisible = totalCount == 0
        ? 0
        : math.min(
            totalCount,
            (_visibleCount <= 0) ? _pageSize : _visibleCount,
          );
    final posts = feedState.posts.take(effectiveVisible).toList(growable: false);
    final hasMoreToShow = effectiveVisible < totalCount;
    final isLoading = feedState.isLoading;
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final isFullScreen = _currentIndex == 1 ||
        _currentIndex == 3 ||
        _currentIndex == 4; // Ads, Promote, Reels

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarBg =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final content = Scaffold(
      extendBody: _currentIndex != 4,
      backgroundColor: isFullScreen
          ? (isDark ? const Color(0xFF121212) : Colors.black)
          : theme.scaffoldBackgroundColor,
      appBar: isFullScreen
          ? null
          : AppBar(
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    DesignTokens.instaPurple,
                    DesignTokens.instaPink,
                    DesignTokens.instaOrange
                  ],
                ).createShader(bounds),
                child: Text('b_smart',
                    style: TextStyle(
                        color: appBarFg,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        fontFamily: 'cursive')),
              ),
              elevation: 0,
              backgroundColor: appBarBg,
              foregroundColor: appBarFg,
              iconTheme: IconThemeData(color: appBarFg),
              actions: [
                if (!isDesktop)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/search'),
                          icon: Icon(LucideIcons.search,
                              size: 24, color: appBarFg),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              Navigator.of(context).pushNamed('/wallet'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2D2D2D)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF3D3D3D)
                                      : Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                      gradient: DesignTokens.instaGradient,
                                      shape: BoxShape.circle),
                                  child: const Icon(LucideIcons.wallet,
                                      size: 12, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                Text('$_balance',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: appBarFg)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                                onPressed: () => Navigator.of(context)
                                    .pushNamed('/notifications'),
                                icon: Icon(LucideIcons.heart,
                                    size: 24, color: appBarFg)),
                            Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: DesignTokens.instaPink,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: isDark
                                                ? const Color(0xFFE8E8E8)
                                                : Colors.white,
                                            width: 1.5)))),
                          ],
                        ),
                        GestureDetector(
                          onTap: _openProfile,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, right: 12),
                            child: Container(
                              width: 32,
                              height: 32,
                              padding: const EdgeInsets.all(1.5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: DesignTokens.instaGradient,
                              ),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    isDark ? Colors.black : Colors.white,
                                child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: isDark
                                      ? const Color(0xFF3D3D3D)
                                      : Colors.grey.shade200,
                                  backgroundImage: _currentUserProfile !=
                                              null &&
                                          _currentUserProfile!['avatar_url'] !=
                                              null &&
                                          (_currentUserProfile!['avatar_url']
                                                  as String)
                                              .isNotEmpty
                                      ? NetworkImage(
                                          _currentUserProfile!['avatar_url']
                                              as String)
                                      : null,
                                  child: _currentUserProfile == null ||
                                          _currentUserProfile!['avatar_url'] ==
                                              null ||
                                          (_currentUserProfile!['avatar_url']
                                                  as String)
                                              .isEmpty
                                      ? Text(
                                          _currentUserProfile != null
                                              ? ((_currentUserProfile![
                                                              'username'] ??
                                                          _currentUserProfile![
                                                              'full_name'] ??
                                                          'U') as String)
                                                      .isNotEmpty
                                                  ? ((_currentUserProfile![
                                                              'username'] ??
                                                          _currentUserProfile![
                                                              'full_name'] ??
                                                          'U') as String)
                                                      .substring(0, 1)
                                                      .toUpperCase()
                                                  : 'U'
                                              : 'U',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: appBarFg),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      body: ColoredBox(
        color: isFullScreen
            ? (isDark ? const Color(0xFF121212) : Colors.black)
            : theme.scaffoldBackgroundColor,
        child: ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: IndexedStack(
            index: _currentIndex,
            children: [
          // Home tab
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: Stack(
              children: [
                Visibility(
                  visible: !isLoading,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: CustomScrollView(
                    controller: _feedScrollController,
                    cacheExtent: 180,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLocationSelector(isDark: isDark),
                            StoriesRow(
                              users: _storyUsers,
                              onYourStoryTap: () {
                                if (_yourStoryHasActive) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => OwnStoryViewerScreen(
                                        stories: _myStories,
                                        storyId: _myStoryId,
                                        userName:
                                            (_currentUserProfile?['username'] ??
                                                    _currentUserProfile?[
                                                        'full_name'] ??
                                                    'You')
                                                .toString(),
                                      ),
                                    ),
                                  );
                                } else {
                                  _openStoryCamera();
                                }
                              },
                              onYourStoryAddTap: _openStoryCamera,
                              onUserStoryTap:
                                  _storyGroups.isEmpty ? null : _onStoryTap,
                              yourStoryHasActive: _yourStoryHasActive,
                              showYourStory: true,
                              userStatuses: _storyStatuses,
                            ),
                          ],
                        ),
                      ),
                      if (posts.isEmpty)
                        SliverFillRemaining(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.image,
                                    size: 48,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color),
                                const SizedBox(height: 12),
                                Text(
                                  'No posts yet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create your first post from the + button',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final p = posts[index];
                              final isOwnPost = _currentUserId != null &&
                                  p.userId == _currentUserId;
                              Widget itemWidget;
                              try {
                                itemWidget = VisibilityDetector(
                                  key: ValueKey('feed-vis-${p.id}'),
                                  onVisibilityChanged: (info) {
                                    _onFeedItemVisibilityChanged(
                                      p.id,
                                      info.visibleFraction,
                                    );
                                  },
                                  child: RepaintBoundary(
                                      child: PostCard(
                                      key: ValueKey(
                                          'card-${p.id}'), // Prevent unnecessary rebuilds
                                      post: p,
                                      isTabActive:
                                          _currentIndex == 0 && _isRouteActive,
                                      isActive: _activeFeedPostId == p.id,
                                      isOwnPost: isOwnPost,
                                      onUserTap: p.userId.isNotEmpty
                                          ? () => Navigator.of(context)
                                              .pushNamed('/profile/${p.userId}')
                                          : null,
                                      onLike: () => _onLikePost(p),
                                      onDoubleTapLike: () =>
                                          _onDoubleTapLikePost(p),
                                      onComment: () => _onCommentPost(p),
                                      onShare: () => _onSharePost(p),
                                      onSave: () => _onSavePost(p),
                                      onFollow: isOwnPost ? null : () => _onFollowPost(p),
                                      onMore: () => _onMorePost(context, p),
                                    ),
                                  ),
                                );
                              } catch (e, st) {
                                itemWidget = Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.broken_image, size: 40),
                                      const SizedBox(height: 8),
                                      Text('Failed to load post', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                                    ],
                                  ),
                                );
                              }
                              return itemWidget;
                            },
                            childCount: posts.length,
                          ),
                        ),
                      if (hasMoreToShow)
                        const SliverToBoxAdapter(child: SizedBox(height: 28)),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ),
                ),
                if (isLoading)
                  const ColoredBox(
                    color: Colors.transparent,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: DesignTokens.instaPink),
                    ),
                  ),
              ],
            ),
          ),
          // Ads tab
          AdsPageScreen(isTabActive: _currentIndex == 1 && _isRouteActive),
          // Placeholder for create (kept empty since create opens modal/route)
          Container(),
          // Promote tab
          const PromoteScreen(),
          // Reels tab
          Container(
            color: Colors.black,
            child: ReelsScreen(isActive: _currentIndex == 4 && _isRouteActive),
          ),
          ],
          ),
        ),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNav(currentIndex: _currentIndex, onTap: _onNavTap),
    );

    if (isDesktop) {
      return Row(
        children: [
          Sidebar(
            currentIndex: _currentIndex,
            isVendor: _isVendor,
            onNavTap: _onNavTap,
            onCreatePost: () {
              if (_isVendor) {
                _openVendorAdComposer('post');
              } else {
                _pendingHomeRefreshAfterRoute = true;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateUploadScreen(
                      initialMode: UploadMode.post,
                    ),
                  ),
                );
              }
            },
            onUploadReel: () {
              if (_isVendor) return;
              _pendingHomeRefreshAfterRoute = true;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateUploadScreen(
                    initialMode: UploadMode.reel,
                  ),
                ),
              );
            },
            onCreateAd: () {
              _openVendorAdComposer('post');
            },
          ),
          Expanded(
            child: Stack(
              children: [
                content,
                if (!isFullScreen) ...[
                  Positioned(
                    top: 32,
                    right: 32,
                    child: _DesktopNotificationsButton(),
                  ),
                  Positioned(
                    bottom: 32,
                    right: 32,
                    child: _FloatingWallet(balance: _balance),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return content;
  }
}

class _NoGlowScrollBehavior extends MaterialScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _DesktopNotificationsButton extends StatefulWidget {
  @override
  State<_DesktopNotificationsButton> createState() =>
      _DesktopNotificationsButtonState();
}

class _DesktopNotificationsButtonState
    extends State<_DesktopNotificationsButton> {
  bool _showDropdown = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardColor;
    final fgColor = theme.colorScheme.onSurface;
    return TapRegion(
      onTapOutside: (_) => setState(() => _showDropdown = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            elevation: 4,
            shadowColor: Colors.black26,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => setState(() => _showDropdown = !_showDropdown),
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _showDropdown ? DesignTokens.instaGradient : null,
                  color: _showDropdown ? null : surfaceColor,
                  border: Border.all(
                    color: _showDropdown
                        ? Colors.transparent
                        : (isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade100),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(child: Icon(LucideIcons.heart, size: 20, color: _showDropdown ? Colors.white : fgColor)),
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: DesignTokens.instaPink,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.black : Colors.white,
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showDropdown)
            Positioned(
              top: 48,
              right: 0,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 320,
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Notifications',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: fgColor)),
                            GestureDetector(
                                onTap: () {},
                                child: const Text('Mark all read',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: DesignTokens.instaPink,
                                        fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: const [
                            _NotificationTile(
                                icon: LucideIcons.bell,
                                iconColor: Colors.blue,
                                title: 'New follower: Sarah',
                                time: '2 min ago'),
                            _NotificationTile(
                                icon: LucideIcons.heart,
                                iconColor: DesignTokens.instaPink,
                                title: 'Mike liked your post',
                                time: '1 hour ago'),
                            _NotificationTile(
                                icon: LucideIcons.messageCircle,
                                iconColor: DesignTokens.instaPurple,
                                title: 'Anna commented: "Amazing!"',
                                time: '2 hours ago'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String time;

  const _NotificationTile(
      {required this.icon,
      required this.iconColor,
      required this.title,
      required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor =
        theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600;
    return InkWell(
      onTap: () {},
      hoverColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(35),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(time, style: TextStyle(fontSize: 12, color: mutedColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingWallet extends StatelessWidget {
  final int balance;

  const _FloatingWallet({required this.balance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardColor;
    final fgColor = theme.colorScheme.onSurface;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/wallet'),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    gradient: DesignTokens.instaGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: DesignTokens.instaPink.withAlpha(80),
                          blurRadius: 8)
                    ]),
                child: const Icon(LucideIcons.wallet,
                    size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Balance',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyMedium?.color ??
                              Colors.grey.shade600)),
                  Text('$balance',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: fgColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
