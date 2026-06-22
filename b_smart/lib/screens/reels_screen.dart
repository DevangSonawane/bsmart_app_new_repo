import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';

import '../api/api_client.dart';
import '../config/api_config.dart';
import '../models/reel_model.dart';
import '../services/reels_service.dart';
import '../services/supabase_service.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/share_content_modal.dart';
import '../widgets/offline_retry_banner.dart';
import '../routes.dart';
import 'package:b_smart/widgets/glass_action_button.dart';

class ReelsScreen extends StatefulWidget {
  final bool isActive;
  final String? initialReelId;
  const ReelsScreen({super.key, this.isActive = true, this.initialReelId});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen>
    with AutomaticKeepAliveClientMixin, RouteAware {
  final ReelsService _reelsService = ReelsService();
  final SupabaseService _supabase = SupabaseService();
  final PageController _pageController = PageController();
  final FocusNode _keyboardFocusNode =
      FocusNode(debugLabel: 'reels-feed-focus');

  final Map<int, VideoPlayerController> _videoControllers =
      <int, VideoPlayerController>{};
  final Set<int> _controllerSetupInProgress = <int>{};
  final Set<int> _prewarmRequested = <int>{};
  int? _lastStartedIndex;
  final Set<int> _failedControllerIndexes = <int>{};
  final Map<int, int> _controllerRetryAttempts = <int, int>{};
  final Map<String, bool> _captionExpanded = {};

  List<Reel> _reels = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isMuted = true;
  bool _isFollowLoading = false;
  bool _isCommentsOpen = false;
  bool _isNavigating = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _currentUserId;
  bool _userPaused = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOffline = false;
  int _offlineRetryAttempts = 0;
  bool _isScrubbing = false;
  double _scrubFraction = 0.0;
  bool _resumeAfterScrub = false;
  double? _pendingScrubFraction;
  bool _scrubSeekScheduled = false;
  bool _progressPointerDown = false;
  Timer? _navigationUnlockTimer;
  String? _error;
  Map<String, String>? _mediaHeaders;
  Future<void> _poolOps = Future<void>.value();
  int _poolGeneration = 0;
  bool _autoplayKickScheduled = false;
  static const double _audioOnScreenThreshold = 0.10;
  bool _audioGateOpen = true;
  PageRoute<dynamic>? _subscribedRoute;
  bool _isRouteActive = true;

  bool get _playbackAllowed => widget.isActive && _isRouteActive;

  bool _isControllerUsable(VideoPlayerController? controller) {
    if (controller == null) return false;
    try {
      controller.value;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isControllerInitialized(VideoPlayerController? controller) {
    if (!_isControllerUsable(controller)) return false;
    try {
      return controller!.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  bool _isControllerPlaying(VideoPlayerController? controller) {
    if (!_isControllerUsable(controller)) return false;
    try {
      return controller!.value.isPlaying;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageScrollForAudioGate);
    _listenConnectivity();
    unawaited(_loadCurrentUserId());
    final cached = _reelsService.getReels();
    final initialId = widget.initialReelId?.trim();
    if (cached.isNotEmpty) {
      _reels = cached;
      _isLoading = false;
      if (initialId != null && initialId.isNotEmpty) {
        final idx = _reels.indexWhere((r) => r.id == initialId);
        if (idx >= 0) {
          _currentIndex = idx;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(idx);
            }
          });
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _reels.isEmpty || !_playbackAllowed) return;
        unawaited(_initializePoolAt(_currentIndex));
        _poolOps = _poolOps.then<void>((_) async {
          if (!mounted) return;
          await _activateCurrentReelPlayback();
          if (mounted) setState(() {});
        }).catchError((_) {});
      });
    }
    _loadReels();
  }

  void _listenConnectivity() {
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none);
      if (!mounted) return;
      if (_isOffline != offline) {
        setState(() {
          _isOffline = offline;
          if (!offline) {
            _offlineRetryAttempts = 0;
          }
        });
      } else if (!offline && _offlineRetryAttempts != 0) {
        setState(() {
          _offlineRetryAttempts = 0;
        });
      }
    });
  }

  Future<bool> _isCurrentlyOffline() async {
    final results = await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.none);
  }

  Future<void> _recordOfflineRetry() async {
    final offline = await _isCurrentlyOffline();
    if (!mounted) return;
    setState(() {
      _isOffline = offline;
      if (offline) {
        _offlineRetryAttempts++;
      } else {
        _offlineRetryAttempts = 0;
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

  Future<void> _loadCurrentUserId() async {
    try {
      final id = await CurrentUser.id;
      final trimmed = id?.trim() ?? '';
      if (!mounted) return;
      setState(() {
        _currentUserId = trimmed.isEmpty ? null : trimmed;
      });
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _navigationUnlockTimer?.cancel();
    _connectivitySub?.cancel();
    _keyboardFocusNode.dispose();
    _pageController.removeListener(_onPageScrollForAudioGate);
    _pageController.dispose();
    _disposeAllControllers();
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
    super.dispose();
  }

  bool _isCurrentReelFullyOnScreen() {
    if (!_pageController.hasClients) return true;
    final page = _pageController.page;
    if (page == null) return true;
    final nearest = page.round();
    if (nearest != _currentIndex) return false;
    return (page - nearest).abs() <= _audioOnScreenThreshold;
  }

  void _applyAudioGate() {
    if (!mounted) return;
    final open = _playbackAllowed && _isCurrentReelFullyOnScreen();
    if (open == _audioGateOpen) return;
    _audioGateOpen = open;
    final controller = _controllerForIndex(_currentIndex);
    if (controller == null) return;
    final vol = (_audioGateOpen && !_isMuted) ? 1.0 : 0.0;
    unawaited(_setControllerVolumeSafely(controller, vol));
  }

  void _onPageScrollForAudioGate() {
    // Only flip volume when we cross the threshold (prevents spam).
    _applyAudioGate();

    if (!_playbackAllowed) return;
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page == null) return;

    final diff = page - _currentIndex;
    if (diff > 0.3) {
      final target = _currentIndex + 1;
      if (target >= 0 &&
          target < _reels.length &&
          !_prewarmRequested.contains(target)) {
        _prewarmRequested.add(target);
        unawaited(
            _createControllerForIndex(target, generation: _poolGeneration));
      }
    } else if (diff < -0.3) {
      final target = _currentIndex - 1;
      if (target >= 0 &&
          target < _reels.length &&
          !_prewarmRequested.contains(target)) {
        _prewarmRequested.add(target);
        unawaited(
            _createControllerForIndex(target, generation: _poolGeneration));
      }
    }
  }

  @override
  void didUpdateWidget(covariant ReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive == widget.isActive) return;
    if (_reels.isEmpty || _currentIndex < 0 || _currentIndex >= _reels.length) {
      return;
    }
    if (_playbackAllowed) {
      if (_controllerForIndex(_currentIndex) == null) {
        unawaited(_initializePoolAt(_currentIndex));
      }
      _poolOps = _poolOps.then<void>((_) async {
        await _activateCurrentReelPlayback();
      }).catchError((_) {});
      _applyAudioGate();
    } else {
      for (final controller in _videoControllers.values) {
        unawaited(_setControllerVolumeSafely(controller, 0));
      }
      _audioGateOpen = false;
      _disposeAllControllers();
    }
  }

  @override
  void didPushNext() {
    if (!_isRouteActive) return;
    _isRouteActive = false;
    _audioGateOpen = false;
    for (final controller in _videoControllers.values) {
      unawaited(_setControllerVolumeSafely(controller, 0));
      unawaited(controller.pause());
    }
    if (mounted) setState(() {});
  }

  @override
  void didPopNext() {
    if (_isRouteActive) return;
    _isRouteActive = true;
    if (mounted) setState(() {});
    if (_playbackAllowed) {
      _applyAudioGate();
      _poolOps = _poolOps.then<void>((_) async {
        await _activateCurrentReelPlayback();
      }).catchError((_) {});
    }
  }

  Future<void> _loadReels() async {
    final hasCached = _reelsService.getReels().isNotEmpty;
    setState(() {
      _isLoading = !hasCached;
      _error = null;
    });

    try {
      final reels = await _reelsService.fetchReels(limit: 20, offset: 0);
      if (!mounted) return;

      int nextIndex = 0;
      final initialId = widget.initialReelId?.trim();
      if (initialId != null && initialId.isNotEmpty) {
        final idx = reels.indexWhere((r) => r.id == initialId);
        if (idx >= 0) nextIndex = idx;
      }
      setState(() {
        _reels = reels;
        _currentIndex = nextIndex;
        _isLoading = false;
        _hasMore = reels.length >= 20;
        _offlineRetryAttempts = 0;
      });
      if (_pageController.hasClients && nextIndex != 0) {
        _pageController.jumpToPage(nextIndex);
      }

      if (_reels.isNotEmpty) {
        unawaited(_reelsService.incrementViews(_reels[_currentIndex].id));
        if (!_playbackAllowed) return;
        unawaited(_initializePoolAt(_currentIndex));
        _poolOps = _poolOps.then<void>((_) async {
          if (!mounted) return;
          await _activateCurrentReelPlayback();
          if (mounted) setState(() {});
        }).catchError((_) {});
      }
    } catch (e) {
      if (!mounted) return;
      final offline = await _isCurrentlyOffline();
      setState(() {
        _isOffline = offline;
        _error = _reels.isEmpty ? e.toString() : null;
      });
    } finally {
      if (mounted && _reels.isEmpty) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _disposeController(VideoPlayerController? controller, int? index) {
    if (controller == null) return;
    try {
      unawaited(controller.dispose());
      debugPrint('[Reels] controller disposed index=$index');
    } catch (_) {}
  }

  void _disposeAllControllers() {
    _poolGeneration++;
    for (final entry in _videoControllers.entries) {
      _disposeController(entry.value, entry.key);
    }
    _videoControllers.clear();
    _controllerSetupInProgress.clear();
  }

  VideoPlayerController? _controllerForIndex(int index) =>
      _videoControllers[index];

  Future<VideoPlayerController?> _createControllerForIndex(
    int index, {
    required int generation,
  }) async {
    if (index < 0 || index >= _reels.length) return null;
    final existing = _videoControllers[index];
    if (existing != null) return existing;
    if (_controllerSetupInProgress.contains(index)) return null;
    _controllerSetupInProgress.add(index);
    _failedControllerIndexes.remove(index);
    final reel = _reels[index];
    final urlCandidates = _urlCandidates(reel.videoUrl);
    if (urlCandidates.isEmpty) {
      _controllerSetupInProgress.remove(index);
      return null;
    }

    try {
      await _ensureMediaHeaders();
      if (!mounted) return null;
      Object? lastError;
      for (final url in urlCandidates) {
        final headerCandidates = _playbackHeaderCandidates(url);
        for (final headers in headerCandidates) {
          VideoPlayerController? controller;
          try {
            debugPrint(
              '[Reels] preparing source index=$index id=${reel.id} url=$url authHeader=${headers.containsKey('Authorization')}',
            );
            controller = VideoPlayerController.networkUrl(
              Uri.parse(url),
              httpHeaders: headers,
              formatHint: _videoFormatHintForUrl(url),
            );
            await controller.initialize();
            if (!mounted || generation != _poolGeneration) {
              await controller.dispose();
              return null;
            }
            await controller.setLooping(true);
            await controller.setVolume(_isMuted ? 0 : 1);
            _videoControllers[index] = controller;
            debugPrint('[Reels] video initialized index=$index id=${reel.id}');
            if (mounted && index == _currentIndex) setState(() {});
            _failedControllerIndexes.remove(index);
            _controllerRetryAttempts.remove(index);
            debugPrint('[Reels] controller created index=$index id=${reel.id}');
            return controller;
          } catch (e) {
            lastError = e;
            debugPrint(
                '[Reels] load failed index=$index id=${reel.id} url=$url headersAuth=${headers.containsKey('Authorization')} error=$e');
            try {
              await controller?.dispose();
            } catch (_) {}
          }
        }
        debugPrint(
            '[Reels] tried url=$url for index=$index id=${reel.id} lastError=$lastError');
      }
      debugPrint(
        '[Reels] controller create failed index=$index id=${reel.id} lastUrl=${urlCandidates.isNotEmpty ? urlCandidates.last : ''} error=$lastError',
      );
      _scheduleControllerRetry(index);
      return null;
    } finally {
      _controllerSetupInProgress.remove(index);
    }
  }

  List<String> _urlCandidates(String raw) {
    final seen = <String>{};
    void add(String v) {
      if (v.isEmpty) return;
      if (seen.add(v)) {}
    }

    final canonical = UrlHelper.absoluteUrl(raw);
    add(canonical);
    debugPrint('[Reels] url candidates base=$raw canonical=$canonical');

    // Try HTTPS variant if original was HTTP (some CDNs block HTTP requests on devices).
    if (canonical.startsWith('http://')) {
      add(canonical.replaceFirst('http://', 'https://'));
    }

    // Try both with and without /api prefix to mirror web behavior.
    try {
      final uri = Uri.parse(canonical);
      if (uri.path.startsWith('/api/')) {
        add(uri.replace(path: uri.path.replaceFirst('/api', '')).toString());
      } else {
        add(uri.replace(path: '/api${uri.path}').toString());
      }
    } catch (_) {}

    final list = seen.toList();
    debugPrint('[Reels] url candidates resolved=$list');
    return list;
  }

  Future<void> _ensureMediaHeaders() async {
    if (_mediaHeaders != null) return;
    final token = await ApiClient().getToken();
    final headers = <String, String>{'User-Agent': 'ReelsScreen-App'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    _mediaHeaders = headers;
  }

  Map<String, String> _baseMediaHeaders() {
    final headers = Map<String, String>.from(_mediaHeaders ?? const {});
    headers.remove('Authorization');
    return headers;
  }

  Map<String, String> _headersForUrl(String url) {
    // Attach auth only when the media host matches the API host (CDNs often reject auth).
    final base = _baseMediaHeaders();
    if (_mediaHeaders != null && UrlHelper.shouldAttachAuthHeader(url)) {
      return _mediaHeaders!;
    }
    return base;
  }

  List<Map<String, String>> _playbackHeaderCandidates(String url) {
    // Try without auth first (but keep User-Agent), then with auth if allowed.
    final candidates = <Map<String, String>>[];
    final base = _baseMediaHeaders();
    candidates.add(base.isEmpty ? const <String, String>{} : base);
    final authHeaders = _mediaHeaders;
    if (authHeaders != null &&
        authHeaders.containsKey('Authorization') &&
        UrlHelper.shouldAttachAuthHeader(url)) {
      candidates.add(Map<String, String>.from(authHeaders));
    }
    return candidates;
  }

  VideoFormat? _videoFormatHintForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return VideoFormat.hls;
    if (lower.contains('.mpd')) return VideoFormat.dash;
    return null;
  }

  Future<void> _initializePoolAt(int index) async {
    if (index < 0 || index >= _reels.length) return;
    if (!_playbackAllowed) return;
    final generation = ++_poolGeneration;
    _currentIndex = index;
    _prewarmRequested
      ..clear()
      ..add(index);
    // Keep index-1, index, index+1, index+2 so we don't show black frames while
    // the user is mid-swipe and can quickly back-swipe without re-init.
    final keep = <int>{};
    for (final k in <int>[index - 1, index, index + 1, index + 2]) {
      if (k >= 0 && k < _reels.length) keep.add(k);
    }

    final remove =
        _videoControllers.keys.where((k) => !keep.contains(k)).toList();
    for (final k in remove) {
      _disposeController(_videoControllers.remove(k), k);
    }

    // Prioritize current reel startup first, then warm neighbors in background.
    await _createControllerForIndex(index, generation: generation);
    final next1 = index + 1;
    final next2 = index + 2;
    if (next1 >= 0 && next1 < _reels.length) {
      _prewarmRequested.add(next1);
      unawaited(_createControllerForIndex(next1, generation: generation));
    }
    if (next2 >= 0 && next2 < _reels.length) {
      _prewarmRequested.add(next2);
      unawaited(_createControllerForIndex(next2, generation: generation));
    }
    if (_controllerForIndex(index) == null) {
      _scheduleControllerRetry(index);
    }
  }

  Future<void> _rotatePoolToIndex(int newIndex) async {
    if (newIndex < 0 || newIndex >= _reels.length) return;
    if (!_playbackAllowed) return;
    await _initializePoolAt(newIndex);
    if (!mounted) return;
    await _activateCurrentReelPlayback();
    if (mounted) setState(() {});
  }

  Future<void> _pauseControllerForIndex(int index) async {
    final controller = _controllerForIndex(index);
    if (controller == null) return;
    try {
      await controller.pause();
      await controller.setVolume(0);
      // Mirror web/Instagram behavior: non-current reels reset to start so that
      // when you swipe back they restart from 0 with the poster behind.
      await controller.seekTo(Duration.zero);
    } catch (_) {}
  }

  Future<void> _setControllerVolumeSafely(
    VideoPlayerController? controller,
    double volume,
  ) async {
    if (controller == null) return;
    try {
      await controller.setVolume(volume);
    } catch (_) {}
  }

  Future<void> _playControllerForIndex(int index) async {
    final controller = _controllerForIndex(index);
    if (controller == null) return;
    try {
      // Mirror web/Instagram behavior: when a reel becomes current, start from 0,
      // but don't keep re-seeking to 0 during autoplay recovery kicks.
      if (_lastStartedIndex != index) {
        await controller.seekTo(Duration.zero);
      }
      await controller.setVolume(
        (_playbackAllowed && _audioGateOpen && !_isMuted) ? 1 : 0,
      );
      if (!mounted || _controllerForIndex(index) != controller) return;
      if (_playbackAllowed) {
        await controller.play();
        _lastStartedIndex = index;
        debugPrint(
          '[Reels] video started playing index=$index id=${_reels[index].id}',
        );
      }
    } catch (e) {
      debugPrint(
        '[Reels] play failed index=$index id=${_reels[index].id} error=$e',
      );
    }
  }

  Future<void> _activateCurrentReelPlayback() async {
    if (!_playbackAllowed) return;
    _applyAudioGate();
    final index = _currentIndex;
    if (_controllerForIndex(index) == null) {
      await _initializePoolAt(index);
    }
    if (!mounted || index != _currentIndex) return;
    final otherIndexes =
        _videoControllers.keys.where((k) => k != index).toList();
    for (final i in otherIndexes) {
      await _pauseControllerForIndex(i);
    }
    if (_userPaused) return;
    await _playControllerForIndex(index);
  }

  Future<void> _togglePlayPause() async {
    if (_reels.isEmpty) return;
    if (!_playbackAllowed) return;
    if (_isCommentsOpen) return;
    if (_isScrubbing) return;
    final index = _currentIndex;
    final controller = _controllerForIndex(index);
    if (controller == null) return;
    if (!_isControllerInitialized(controller)) return;
    try {
      if (controller.value.isPlaying) {
        _userPaused = true;
        await controller.pause();
      } else {
        _userPaused = false;
        await controller.setVolume(
          (_playbackAllowed && _audioGateOpen && !_isMuted) ? 1 : 0,
        );
        await controller.play();
        _lastStartedIndex = index;
      }
    } catch (_) {
      // ignore
    }
    if (!mounted) return;
    setState(() {});
  }

  void _onPageChanged(int index) {
    if (_reels.isEmpty || index < 0 || index >= _reels.length) return;
    setState(() {
      _currentIndex = index;
      _userPaused = false;
      _isScrubbing = false;
    });
    _prewarmRequested.clear();
    // The active index changed; reevaluate audio gate based on page settling.
    _applyAudioGate();
    unawaited(_reelsService.incrementViews(_reels[index].id));
    _poolOps = _poolOps
        .then<void>((_) => _rotatePoolToIndex(index))
        .catchError((_) {});
    if (index + 1 < _reels.length) {
      unawaited(
          _createControllerForIndex(index + 1, generation: _poolGeneration));
    }
    _maybeLoadMore(index);
  }

  void _maybeLoadMore(int index) {
    if (_isLoadingMore || !_hasMore) return;
    if (index >= _reels.length - 3) {
      unawaited(_loadMoreReels());
    }
  }

  Future<void> _loadMoreReels() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final next = await _reelsService.fetchReels(
        limit: 20,
        offset: _reels.length,
      );
      if (!mounted) return;
      setState(() {
        _reels.addAll(next);
        if (next.length < 20) _hasMore = false;
      });
    } catch (_) {
      // ignore fetch errors for background pagination
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _scheduleControllerRetry(int index) {
    final attempts = _controllerRetryAttempts[index] ?? 0;
    _controllerRetryAttempts[index] = attempts + 1;
    _failedControllerIndexes.remove(index);
    final delayMs =
        switch (attempts) { 0 => 800, 1 => 1500, 2 => 2500, _ => 3500 };
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      if (index != _currentIndex) return;
      if (_controllerForIndex(index) != null) return;
      if (_failedControllerIndexes.contains(index)) return;
      unawaited(() async {
        await _initializePoolAt(index);
        if (!mounted) return;
        await _activateCurrentReelPlayback();
        if (mounted && index == _currentIndex) setState(() {});
      }());
    });
  }

  Future<void> _retryCurrentReel() async {
    if (_reels.isEmpty) return;
    final idx = _currentIndex;
    await _recordOfflineRetry();
    _failedControllerIndexes.remove(idx);
    _controllerRetryAttempts.remove(idx);
    if (mounted && idx == _currentIndex) setState(() {});
    await _initializePoolAt(idx);
    if (!mounted) return;
    await _activateCurrentReelPlayback();
    if (mounted && idx == _currentIndex) setState(() {});
  }

  Future<void> _toggleLike() async {
    unawaited(HapticFeedback.lightImpact());
    if (_reels.isEmpty) return;
    final reelId = _reels[_currentIndex].id;
    try {
      await _reelsService.toggleLike(reelId);
      if (!mounted) return;
      setState(() {
        _reels = _reelsService.getReels();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reels = _reelsService.getReels();
      });
    }
  }

  Future<void> _toggleSave() async {
    if (_reels.isEmpty) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save posts')),
        );
      }
      return;
    }
    final reelId = _reels[_currentIndex].id;
    try {
      await _reelsService.toggleSave(reelId);
      if (!mounted) return;
      setState(() {
        _reels = _reelsService.getReels();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reels = _reelsService.getReels();
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_reels.isEmpty) return;
    if (_isFollowLoading) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to follow users')),
        );
      }
      return;
    }

    final reel = _reels[_currentIndex];
    final userId = reel.userId;
    if (userId.trim().isEmpty) return;
    if (_currentUserId != null && userId.trim() == _currentUserId) return;

    final wasFollowing = reel.isFollowing;
    setState(() {
      _isFollowLoading = true;
    });

    _reelsService.toggleFollow(userId);
    setState(() {
      _reels = _reelsService.getReels();
    });

    try {
      final ok = wasFollowing
          ? await _supabase.unfollowUser(userId)
          : await _supabase.followUser(userId);
      if (!ok) {
        throw Exception('follow_update_failed');
      }
    } catch (_) {
      _reelsService.toggleFollow(userId);
      if (mounted) {
        setState(() {
          _reels = _reelsService.getReels();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update follow status')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowLoading = false;
        });
      }
    }
  }

  Future<void> _openComments() async {
    if (_reels.isEmpty) return;
    setState(() {
      _isCommentsOpen = true;
    });
    try {
      final postId = _reels[_currentIndex].id;
      final isDesktop = MediaQuery.of(context).size.width >= 768;
      if (isDesktop) {
        await showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Comments',
          barrierColor: Colors.black.withValues(alpha: 0.50),
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (context, _, __) {
            final height = MediaQuery.of(context).size.height * 0.78;
            return SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 84),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 340,
                      height: height.clamp(0.0, 640.0),
                      child: CommentsSheet(postId: postId),
                    ),
                  ),
                ),
              ),
            );
          },
          transitionBuilder: (context, animation, _, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            );
          },
        );
      } else {
        await CommentsSheet.show(context, postId);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCommentsOpen = false;
        });
      }
    }
  }

  Future<void> _shareCurrent() async {
    if (_reels.isEmpty) return;
    unawaited(_reelsService.incrementShares(_reels[_currentIndex].id));
    await ShareContentModal.show(
      context,
      contentType: 'reel',
      contentId: _reels[_currentIndex].id,
    );
  }

  void _goToIndex(int index) {
    if (_isCommentsOpen) return;
    if (_isNavigating) return;
    if (index < 0 || index >= _reels.length) return;
    _isNavigating = true;
    _navigationUnlockTimer?.cancel();
    _navigationUnlockTimer = Timer(const Duration(milliseconds: 500), () {
      _isNavigating = false;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _scheduleAutoplayKick() {
    if (_autoplayKickScheduled) return;
    _autoplayKickScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoplayKickScheduled = false;
      if (!mounted || !_playbackAllowed || _reels.isEmpty) return;
      final controller = _controllerForIndex(_currentIndex);
      if (!_isControllerInitialized(controller)) {
        if (_controllerSetupInProgress.contains(_currentIndex)) return;
        unawaited(_initializePoolAt(_currentIndex));
        _poolOps = _poolOps
            .then<void>((_) => _activateCurrentReelPlayback())
            .catchError((_) {});
        return;
      }
      if (!_isControllerPlaying(controller)) {
        _poolOps = _poolOps
            .then<void>((_) => _activateCurrentReelPlayback())
            .catchError((_) {});
      }
    });
  }

  String _buildShareUrl(String reelId) {
    try {
      final apiUri = Uri.parse(ApiConfig.baseUrl);
      final scheme = apiUri.scheme.isEmpty ? 'https' : apiUri.scheme;
      final apiHost = apiUri.host;
      final appHost = apiHost.startsWith('api.')
          ? 'app.${apiHost.substring(4)}'
          : 'app.bebsmart.online';
      return '$scheme://$appHost/reels/$reelId';
    } catch (_) {
      return 'https://app.bebsmart.online/reels/$reelId';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _scheduleAutoplayKick();
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(height: 12),
              Text('Loading reels...',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_error != null && _reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Failed to load reels',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _loadReels,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_reels.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child:
              Text('No reels found', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final mq = MediaQuery.of(context);
    final bottomSystemInset = math.max(
      mq.viewPadding.bottom,
      mq.systemGestureInsets.bottom,
    );
    final topSystemInset = MediaQuery.of(context).viewPadding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is! KeyDownEvent || _isCommentsOpen) return;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _goToIndex(_currentIndex + 1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _goToIndex(_currentIndex - 1);
          }
        },
        child: Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent || _isCommentsOpen) return;
            if (event.scrollDelta.dy.abs() < 20) return;
            _goToIndex(
              event.scrollDelta.dy > 0 ? _currentIndex + 1 : _currentIndex - 1,
            );
          },
          onPointerDown: (_) {
            if (!_keyboardFocusNode.hasFocus) {
              _keyboardFocusNode.requestFocus();
            }
          },
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomSystemInset),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
              child: Stack(
                children: [
                  if (!isDesktop)
                    _buildVideoCard(isDesktop: false)
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: SizedBox(
                                width: 380,
                                child: _buildVideoCard(isDesktop: true),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 28, bottom: 26),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: _buildDesktopActions(),
                          ),
                        ),
                      ],
                    ),
                  Positioned(
                    right: 4,
                    top: topSystemInset + 8,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      icon: const Icon(
                        LucideIcons.search,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/search'),
                    ),
                  ),
                  if (_isOffline && _offlineRetryAttempts >= 2)
                    Positioned(
                      left: 12,
                      right: 12,
                      top: topSystemInset + 8,
                      child: SafeArea(
                        bottom: false,
                        child: OfflineRetryBanner(
                          message:
                              "You're offline, please check your internet connection",
                        ),
                      ),
                    ),
                  if (isDesktop) _buildDesktopArrows(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard({required bool isDesktop}) {
    final current = _reels[_currentIndex];
    const actionsBottomMobile = 40.0;
    const minimalBottomPadding = 28.0;
    final caption = (current.caption ?? '').trim();
    final hasBottomText = caption.isNotEmpty || current.hashtags.isNotEmpty;
    final infoBottomMobile = minimalBottomPadding;
    final infoBottomDesktop = minimalBottomPadding;
    const maxInfoHeightMobile = 220.0;
    const maxInfoHeightDesktop = 240.0;

    return ClipRRect(
      borderRadius: isDesktop ? BorderRadius.circular(20) : BorderRadius.zero,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: _isScrubbing
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              allowImplicitScrolling: false,
              itemCount: _reels.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return _buildReelPlayer(
                  index,
                  _reels[index],
                  isDesktop: isDesktop,
                );
              },
            ),
            if (_userPaused && _playbackAllowed)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.play,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 260,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(0, 0, 0, 0.0),
                        Color.fromRGBO(0, 0, 0, 0.62),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!isDesktop)
              Positioned(
                right: 4,
                // `bottomSystemInset` is already accounted for by the outer Padding
                // in `build()`, so don't add it again here.
                bottom: actionsBottomMobile,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: _buildMobileActions(current),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              left: 16,
              right: isDesktop ? 14 : 56,
              bottom: isDesktop ? infoBottomDesktop : infoBottomMobile,
              child: hasBottomText
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: isDesktop
                            ? maxInfoHeightDesktop
                            : maxInfoHeightMobile,
                      ),
                      child: _buildBottomInfo(current),
                    )
                  : _buildBottomInfo(current),
            ),
            // Progress Bar — keep as the top-most overlay so the bottom gradient/info
            // doesn't visually hide it. Matches Ads bar styling/behavior.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildScrubbableProgressBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelPlaybackProgress() {
    final controller = _controllerForIndex(_currentIndex);
    // Always show the track (already provided by parent Container). If controller
    // isn't ready, keep fill at 0 so the bar still looks consistent.
    if (!_isControllerUsable(controller)) {
      return const SizedBox.shrink();
    }
    return _SmoothReelProgressBar(controller: controller!);
  }

  String _formatScrubTime(Duration d) {
    final totalSeconds = d.inSeconds.clamp(0, 24 * 60 * 60);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString();
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  double _clamp01(double v) => v.clamp(0.0, 1.0);

  Duration _durationFor(VideoPlayerController controller) {
    try {
      final d = controller.value.duration;
      return d.isNegative ? Duration.zero : d;
    } catch (_) {
      return Duration.zero;
    }
  }

  Duration _positionFor(VideoPlayerController controller) {
    try {
      final p = controller.value.position;
      return p.isNegative ? Duration.zero : p;
    } catch (_) {
      return Duration.zero;
    }
  }

  bool _isPlaying(VideoPlayerController controller) {
    try {
      return controller.value.isPlaying;
    } catch (_) {
      return false;
    }
  }

  Future<void> _beginScrub(double dx, double width) async {
    if (!mounted) return;
    if (_reels.isEmpty) return;
    if (!_playbackAllowed) return;
    if (_isCommentsOpen) return;
    final controller = _controllerForIndex(_currentIndex);
    if (controller == null) return;
    if (!_isControllerInitialized(controller)) return;
    final duration = _durationFor(controller);
    if (duration <= Duration.zero) return;

    final wasPlaying = _isPlaying(controller);
    _resumeAfterScrub = wasPlaying && !_userPaused;
    _isScrubbing = true;
    _scrubFraction = _clamp01(width <= 0 ? 0.0 : dx / width);
    setState(() {});
    try {
      await controller.pause();
    } catch (_) {}
    await _seekToScrubFraction(controller, _scrubFraction);
  }

  Future<void> _seekToScrubFraction(
      VideoPlayerController controller, double fraction) async {
    final duration = _durationFor(controller);
    if (duration <= Duration.zero) return;
    final targetMs = (duration.inMilliseconds * _clamp01(fraction))
        .round()
        .clamp(0, duration.inMilliseconds);
    try {
      await controller.seekTo(Duration(milliseconds: targetMs));
    } catch (_) {}
  }

  void _updateScrub(double dx, double width) {
    if (!_isScrubbing) return;
    final controller = _controllerForIndex(_currentIndex);
    if (controller == null) return;
    final duration = _durationFor(controller);
    if (duration <= Duration.zero) return;
    final next = _clamp01(width <= 0 ? 0.0 : dx / width);
    if ((_scrubFraction - next).abs() < 0.0005) return;
    _scrubFraction = next;
    setState(() {});
    _pendingScrubFraction = next;
    _scheduleScrubSeek(controller);
  }

  void _scheduleScrubSeek(VideoPlayerController controller) {
    if (_scrubSeekScheduled) return;
    _scrubSeekScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scrubSeekScheduled = false;
      if (!_isScrubbing) return;
      final fraction = _pendingScrubFraction;
      if (fraction == null) return;
      _pendingScrubFraction = null;
      unawaited(_seekToScrubFraction(controller, fraction));
    });
  }

  Future<void> _endScrub() async {
    if (!_isScrubbing) return;
    final controller = _controllerForIndex(_currentIndex);
    _isScrubbing = false;
    _pendingScrubFraction = null;
    setState(() {});
    if (controller == null) return;
    if (!_isControllerInitialized(controller)) return;
    if (_resumeAfterScrub && _playbackAllowed) {
      try {
        await controller.setVolume(
          (_playbackAllowed && _audioGateOpen && !_isMuted) ? 1 : 0,
        );
        await controller.play();
        _lastStartedIndex = _currentIndex;
      } catch (_) {}
    }
    _resumeAfterScrub = false;
  }

  void _endProgressPointer() {
    if (!_progressPointerDown) return;
    _progressPointerDown = false;
    if (_isScrubbing) {
      unawaited(_endScrub());
      return;
    }
    if (mounted) setState(() {});
  }

  Widget _buildScrubbableProgressBar() {
    final controller = _controllerForIndex(_currentIndex);
    final canScrub = controller != null && _isControllerInitialized(controller);
    final duration = canScrub ? _durationFor(controller!) : Duration.zero;
    final pos = canScrub ? _positionFor(controller!) : Duration.zero;
    final baseFraction = duration.inMilliseconds > 0
        ? pos.inMilliseconds / duration.inMilliseconds
        : 0.0;
    final fraction = _isScrubbing ? _scrubFraction : _clamp01(baseFraction);
    final displayPos = duration.inMilliseconds > 0
        ? Duration(
            milliseconds:
                (duration.inMilliseconds * _clamp01(fraction)).round(),
          )
        : Duration.zero;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final knobLeft = (width * fraction).clamp(0.0, width);
        final barHeight = 4.0;
        final previewWidth = (width * 0.28).clamp(96.0, 140.0);
        final previewHeight = previewWidth * (16 / 9);
        final previewLeft = (knobLeft - (previewWidth / 2))
            .clamp(12.0, width - previewWidth - 12.0);

        final pillText = duration > Duration.zero
            ? '${_formatScrubTime(displayPos)} / ${_formatScrubTime(duration)}'
            : '';
        const pillStyle = TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          shadows: [
            Shadow(
              color: Colors.black45,
              offset: Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        );
        final pillPainter = TextPainter(
          text: TextSpan(text: pillText, style: pillStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: width - 24);
        final pillWidth = (pillPainter.width + 20).clamp(96.0, width - 24.0);
        final pillLeft =
            (knobLeft - (pillWidth / 2)).clamp(12.0, width - pillWidth - 12.0);

        return SizedBox(
          height: _isScrubbing ? (previewHeight + 58) : 40,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              if (_isScrubbing && canScrub)
                Positioned(
                  left: previewLeft,
                  bottom: 40,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: previewWidth,
                      height: previewHeight,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Builder(
                        builder: (context) {
                          Size? videoSize;
                          if (controller != null) {
                            try {
                              final v = controller.value;
                              if (v.isInitialized) videoSize = v.size;
                            } catch (_) {
                              videoSize = null;
                            }
                          }
                          if (controller == null ||
                              !_isControllerInitialized(controller) ||
                              videoSize == null ||
                              videoSize!.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final ar = videoSize!.width / videoSize!.height;
                          final target = 9 / 16;
                          final isNineSixteen = ar.isFinite &&
                              ar > 0 &&
                              (ar - target).abs() < 0.06;
                          if (isNineSixteen) {
                            return ClipRect(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: videoSize!.width,
                                  height: videoSize!.height,
                                  child: VideoPlayer(controller),
                                ),
                              ),
                            );
                          }
                          return ColoredBox(
                            color: Colors.black,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio:
                                    ar.isFinite && ar > 0 ? ar : target,
                                child: VideoPlayer(controller),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              if (_isScrubbing && duration > Duration.zero)
                Positioned(
                  left: pillLeft,
                  bottom: 18,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(pillText, style: pillStyle),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: barHeight,
                    color: Colors.white.withValues(alpha: 0.22),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: (_isScrubbing || !canScrub)
                          ? FractionallySizedBox(
                              widthFactor: _clamp01(fraction),
                              child: Container(color: Colors.white),
                            )
                          : _SmoothReelProgressBar(controller: controller!),
                    ),
                  ),
                ),
              ),
              if (_isScrubbing)
                Positioned(
                  left: knobLeft - 6,
                  bottom: -4,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned.fill(
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    EagerGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                            EagerGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                      (_) {},
                    ),
                  },
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) {
                      if (!_progressPointerDown) {
                        setState(() => _progressPointerDown = true);
                      }
                      if (!canScrub) return;
                      unawaited(_beginScrub(e.localPosition.dx, width));
                    },
                    onPointerMove: (e) {
                      if (!canScrub) return;
                      _updateScrub(e.localPosition.dx, width);
                    },
                    onPointerUp: (_) => _endProgressPointer(),
                    onPointerCancel: (_) => _endProgressPointer(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReelPlayer(int index, Reel reel, {required bool isDesktop}) {
    final controller = _controllerForIndex(index);
    final safeController = _isControllerUsable(controller) ? controller : null;
    final thumb = reel.thumbnailUrl == null
        ? null
        : UrlHelper.absoluteUrl(reel.thumbnailUrl!);
    final isActive = _playbackAllowed && index == _currentIndex;

    return RepaintBoundary(
      key: ValueKey('reel-rb-${reel.id}'),
      child: _ReelPlayerItem(
        key: ValueKey('reel-item-$index-${reel.id}'),
        controller: safeController,
        thumbnailUrl: thumb,
        headers:
            thumb == null || thumb.isEmpty ? const {} : _headersForUrl(thumb),
        isActive: isActive,
        isFailed: false,
        onRetry: null,
        onTap: isActive ? _togglePlayPause : null,
      ),
    );
  }

  Widget _buildMobileActions(Reel reel) {
    return Column(
      children: [
        GlassActionButton(
          icon: LucideIcons.eye,
          label: _formatCount(reel.views),
          onTap: () {},
        ),
        const SizedBox(height: 12),
        _LikeBump(
          isLiked: reel.isLiked,
          child: GlassActionButton(
            icon: reel.isLiked ? Icons.favorite : LucideIcons.heart,
            label: _formatCount(reel.likes),
            iconColor: reel.isLiked ? Colors.red : Colors.white,
            onTap: _toggleLike,
          ),
        ),
        const SizedBox(height: 12),
        GlassActionButton(
          icon: LucideIcons.messageCircle,
          label: _formatCount(reel.comments),
          onTap: () => unawaited(_openComments()),
        ),
        const SizedBox(height: 12),
        GlassActionButton(
          icon: LucideIcons.send,
          label: '',
          rotate: -0.2,
          onTap: () => unawaited(_shareCurrent()),
        ),
        const SizedBox(height: 12),
        GlassActionButton(
          icon: reel.isSaved ? Icons.bookmark : Icons.bookmark_border,
          label: '',
          onTap: _toggleSave,
        ),
        const SizedBox(height: 12),
        GlassActionButton(
          icon: _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
          label: '',
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            setState(() {
              _isMuted = !_isMuted;
            });
            final volume = _isMuted ? 0.0 : 1.0;
            for (final controller in _videoControllers.values) {
              unawaited(_setControllerVolumeSafely(controller, volume));
            }
          },
        ),
      ],
    );
  }

  Widget _buildDesktopActions() {
    final reel = _reels[_currentIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassActionButton(
          icon: LucideIcons.eye,
          label: _formatCount(reel.views),
          onTap: () {},
        ),
        const SizedBox(height: 12),
        GlassActionButton(
          icon: reel.isLiked ? Icons.favorite : LucideIcons.heart,
          label: _formatCount(reel.likes),
          iconColor: reel.isLiked ? Colors.red : Colors.white,
          onTap: _toggleLike,
        ),
        const SizedBox(height: 12),
        GlassActionButton(
          icon: LucideIcons.messageCircle,
          label: _formatCount(reel.comments),
          onTap: () => unawaited(_openComments()),
        ),
        const SizedBox(height: 12),
        GlassActionButton(
          icon: LucideIcons.send,
          label: '',
          rotate: -0.2,
          onTap: () => unawaited(_shareCurrent()),
        ),
        const SizedBox(height: 12),
        GlassActionButton(
          icon: reel.isSaved ? Icons.bookmark : Icons.bookmark_border,
          label: '',
          onTap: _toggleSave,
        ),
        const SizedBox(height: 12),
        GlassActionButton(
          icon: _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
          label: '',
          onTap: () {
            setState(() {
              _isMuted = !_isMuted;
            });
            final volume = _isMuted ? 0.0 : 1.0;
            for (final controller in _videoControllers.values) {
              unawaited(_setControllerVolumeSafely(controller, volume));
            }
          },
        ),
      ],
    );
  }

  Widget _buildAvatarThumb(Reel reel, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white54, width: 1.4),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: reel.userAvatarUrl != null && reel.userAvatarUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: UrlHelper.absoluteUrl(reel.userAvatarUrl!),
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _avatarFallback(reel),
            )
          : _avatarFallback(reel),
    );
  }

  Widget _avatarFallback(Reel reel) {
    final ch = reel.userName.isEmpty ? 'U' : reel.userName[0].toUpperCase();
    return Container(
      color: const Color(0xFFF97316),
      alignment: Alignment.center,
      child: Text(
        ch,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBottomInfo(Reel reel) {
    final isOwn =
        _currentUserId != null && reel.userId.trim() == _currentUserId;
    final canShowFollow =
        reel.userId.trim().isNotEmpty && reel.userId.trim() != _currentUserId;
    final isExpanded = _captionExpanded[reel.id] ?? false;
    final caption = (reel.caption ?? '').trim();
    final hasCaption = caption.isNotEmpty;
    final hasHashtags = reel.hashtags.isNotEmpty;
    Widget buildAudioLine() {
      final audioLabel = (reel.audioTitle?.trim().isNotEmpty ?? false)
          ? reel.audioTitle!.trim()
          : 'Original Audio';
      final audioArtist = (reel.audioArtist?.trim().isNotEmpty ?? false)
          ? reel.audioArtist!.trim()
          : reel.userName;
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(
              LucideIcons.music2,
              size: 11,
              color: Colors.white.withValues(alpha: 0.78),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '$audioLabel · $audioArtist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (!hasCaption && !hasHashtags) {
      const usernameStyle = TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gapAfterAvatar = 10.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => unawaited(_openUserProfile(reel.userId)),
                      borderRadius: BorderRadius.circular(999),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.grey[700],
                        backgroundImage: reel.userAvatarUrl != null &&
                                reel.userAvatarUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(
                                UrlHelper.absoluteUrl(reel.userAvatarUrl!),
                              )
                            : null,
                        child: reel.userAvatarUrl == null ||
                                reel.userAvatarUrl!.isEmpty
                            ? Text(
                                (reel.userName.isEmpty ? 'U' : reel.userName[0])
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: gapAfterAvatar),
                    Flexible(
                      fit: FlexFit.loose,
                      child: InkWell(
                        onTap: () => unawaited(_openUserProfile(reel.userId)),
                        child: Text(
                          reel.userName,
                          style: usernameStyle,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (canShowFollow) ...[
                      GestureDetector(
                        onTap: _isFollowLoading
                            ? null
                            : () => unawaited(_toggleFollow()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isFollowLoading)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  reel.isFollowing
                                      ? LucideIcons.userCheck
                                      : LucideIcons.userPlus,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              const SizedBox(width: 4),
                              Text(
                                _isFollowLoading
                                    ? '...'
                                    : (reel.isFollowing ? 'Following' : 'Follow'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          buildAudioLine(),
          // Keep layout height stable even when there's no caption, and align
          // the username row with the mute button on the action rail.
          const SizedBox(height: 26),
        ],
      );
    }
    final words = caption.trim().isEmpty
        ? <String>[]
        : caption.trim().split(RegExp(r'\s+'));
    final isLong = words.length > 5;
    final preview = isLong ? words.take(5).join(' ') : caption;

    const usernameStyle = TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w800,
      fontSize: 15,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 44,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gapAfterAvatar = 10.0;
                return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => unawaited(_openUserProfile(reel.userId)),
                    borderRadius: BorderRadius.circular(999),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey[700],
                      backgroundImage: reel.userAvatarUrl != null &&
                              reel.userAvatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(
                              UrlHelper.absoluteUrl(reel.userAvatarUrl!),
                            )
                          : null,
                      child: reel.userAvatarUrl == null ||
                              reel.userAvatarUrl!.isEmpty
                          ? Text(
                              (reel.userName.isEmpty ? 'U' : reel.userName[0])
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: gapAfterAvatar),
                  Flexible(
                    fit: FlexFit.loose,
                    child: InkWell(
                      onTap: () => unawaited(_openUserProfile(reel.userId)),
                      child: Text(
                        reel.userName,
                        style: usernameStyle,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (canShowFollow) ...[
                    GestureDetector(
                      onTap: _isFollowLoading
                          ? null
                          : () => unawaited(_toggleFollow()),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isFollowLoading)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                reel.isFollowing
                                    ? LucideIcons.userCheck
                                    : LucideIcons.userPlus,
                                size: 16,
                                color: Colors.white,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              _isFollowLoading
                                  ? '...'
                                  : (reel.isFollowing ? 'Following' : 'Follow'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
              },
            ),
          ),
        buildAudioLine(),
        const SizedBox(height: 8),
        if (caption.isNotEmpty)
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
              ),
              children: [
                TextSpan(text: isExpanded || !isLong ? caption : preview),
                if (isLong)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _captionExpanded[reel.id] = !isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          isExpanded ? 'less' : '... more',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            maxLines: isExpanded ? 3 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (reel.hashtags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            reel.hashtags.map((t) => '#$t').join(' '),
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Future<void> _openUserProfile(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    if (!mounted) return;
    if (_isCommentsOpen) return;
    if (_isNavigating) return;
    _isNavigating = true;
    try {
      await Navigator.of(context).pushNamed('/profile/$id');
    } finally {
      _isNavigating = false;
    }
  }

  Widget _buildDesktopArrows() {
    final canGoUp = _currentIndex > 0;
    final canGoDown = _currentIndex < _reels.length - 1;

    Widget arrowButton(
        {required bool enabled,
        required IconData icon,
        required VoidCallback onTap}) {
      return GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.25,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(icon, color: Colors.white),
          ),
        ),
      );
    }

    return Positioned(
      right: 20,
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            arrowButton(
              enabled: canGoUp,
              icon: Icons.keyboard_arrow_up,
              onTap: () => _goToIndex(_currentIndex - 1),
            ),
            const SizedBox(height: 10),
            arrowButton(
              enabled: canGoDown,
              icon: Icons.keyboard_arrow_down,
              onTap: () => _goToIndex(_currentIndex + 1),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}

class _SmoothReelProgressBar extends StatefulWidget {
  final VideoPlayerController controller;
  const _SmoothReelProgressBar({required this.controller});

  @override
  State<_SmoothReelProgressBar> createState() => _SmoothReelProgressBarState();
}

class _SmoothReelProgressBarState extends State<_SmoothReelProgressBar>
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
  void didUpdateWidget(covariant _SmoothReelProgressBar oldWidget) {
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
    // While playing, repaint each frame so the bar moves smoothly even if the
    // video controller only notifies at coarse intervals.
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

      // Keep duration in sync always.
      _duration = nextDuration;

      // If speed changes while playing, "lock in" the current predicted position
      // so we don't jump backwards/forwards unexpectedly.
      if (_isPlaying && nextIsPlaying && _playbackSpeed != nextSpeed) {
        _basePosition = Duration(milliseconds: _predictedPositionMs(nowMs));
        _baseEpochMs = nowMs;
      }
      _playbackSpeed = nextSpeed;
      _isPlaying = nextIsPlaying;

      if (!_isPlaying) {
        // When paused/buffering, trust controller position exactly.
        _basePosition = controllerPos;
        _baseEpochMs = nowMs;
      } else {
        // While playing, avoid snapping backwards to the controller's slightly
        // lagging position (prevents visible progress "restarts"/jitter).
        final predictedMs = _predictedPositionMs(nowMs);
        final controllerMs = controllerPos.inMilliseconds;
        if (controllerMs > predictedMs) {
          _basePosition = controllerPos;
          _baseEpochMs = nowMs;
        } else if (controllerMs < predictedMs - _snapBackToleranceMs) {
          // Large backward jump likely indicates a seek/loop; accept it.
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

    // Ensure we repaint when key values change (especially while paused, where
    // the ticker is not running).
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
      // Keep layout stable; just show an empty fill until duration resolves.
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

class _LikeBump extends StatefulWidget {
  final bool isLiked;
  final Widget child;

  const _LikeBump({
    required this.isLiked,
    required this.child,
  });

  @override
  State<_LikeBump> createState() => _LikeBumpState();
}

class _LikeBumpState extends State<_LikeBump> {
  static const _bumpScale = 1.2;
  static const _duration = Duration(milliseconds: 150);

  double _scale = 1.0;
  Timer? _resetTimer;

  @override
  void didUpdateWidget(covariant _LikeBump oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLiked == widget.isLiked) return;

    _resetTimer?.cancel();
    setState(() => _scale = _bumpScale);
    _resetTimer = Timer(_duration, () {
      if (!mounted) return;
      setState(() => _scale = 1.0);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _scale,
      duration: _duration,
      curve: Curves.easeOut,
      child: widget.child,
    );
  }
}

class _ReelPlayerItem extends StatefulWidget {
  final VideoPlayerController? controller;
  final String? thumbnailUrl;
  final Map<String, String> headers;
  final bool isActive;
  final bool isFailed;
  final VoidCallback? onRetry;
  final VoidCallback? onTap;

  const _ReelPlayerItem({
    super.key,
    required this.controller,
    required this.thumbnailUrl,
    required this.headers,
    required this.isActive,
    required this.isFailed,
    required this.onRetry,
    required this.onTap,
  });

  @override
  State<_ReelPlayerItem> createState() => _ReelPlayerItemState();
}

class _ReelPlayerItemState extends State<_ReelPlayerItem> {
  Widget _fallbackPlaceholder() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B1B1F),
            Color(0xFF2A2A2F),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = widget.thumbnailUrl;
    final controller = widget.controller;
    bool isInitialized = false;
    bool isBuffering = false;
    if (controller != null) {
      try {
        isInitialized = controller.value.isInitialized;
        isBuffering = controller.value.isBuffering;
      } catch (_) {
        isInitialized = false;
        isBuffering = false;
      }
    }
    Size? videoSize;
    if (isInitialized && controller != null) {
      try {
        videoSize = controller.value.size;
      } catch (_) {
        videoSize = null;
      }
    }

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      httpHeaders: widget.headers,
                      placeholder: (_, __) => _fallbackPlaceholder(),
                      errorWidget: (_, __, ___) => _fallbackPlaceholder(),
                    )
                  else
                    _fallbackPlaceholder(),
                  // Only render the video texture for the active reel.
                  // Non-active reels should show only the thumbnail/poster (no white/black flashes).
                  if (widget.isActive &&
                      controller != null &&
                      isInitialized &&
                      videoSize != null)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      opacity: 1,
                      child: () {
                        final vs = videoSize!;
                        final ar = controller.value.aspectRatio;
                        final target = 9 / 16;
                        final isNineSixteen =
                            ar.isFinite && ar > 0 && (ar - target).abs() < 0.06;
                        if (isNineSixteen) {
                          return ClipRect(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: vs.width,
                                height: vs.height,
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
                    ),
                  if (widget.isActive &&
                      controller != null &&
                      (!isInitialized || isBuffering))
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.isActive && widget.isFailed && widget.onRetry != null)
            Center(
              child: FilledButton.tonal(
                onPressed: widget.onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white12,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry'),
              ),
            ),
        ],
      ),
    );
  }
}
