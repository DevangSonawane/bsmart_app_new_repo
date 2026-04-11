import 'package:video_player/video_player.dart';
import 'dart:async';
import '../api/api_client.dart';
import '../utils/url_helper.dart';

class VideoPool {
  VideoPool._();
  static final VideoPool instance = VideoPool._();

  // Keep up to 3 controllers: active + 2 neighbors
  final Map<String, VideoPlayerController> _pool = {};
  final Map<String, Completer<void>> _inFlight = <String, Completer<void>>{};
  final List<String> _warmOrder = <String>[];
  static const int _maxSlots = 3;
  String? _activeId;
  bool _muted = true;
  String? _cachedToken;
  DateTime? _tokenFetchedAt;

  bool get isMuted => _muted;
  bool contains(String id) =>
      _pool.containsKey(id) || _inFlight.containsKey(id);

  VideoPlayerController? peek(String id) {
    return _usableController(id);
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    for (final ctl in _pool.values) {
      try {
        await ctl.setVolume(_muted ? 0 : 1);
      } catch (_) {}
    }
  }

  Future<void> toggleMuted() => setMuted(!_muted);

  Future<String?> _getToken() async {
    final now = DateTime.now();
    if (_cachedToken != null &&
        _tokenFetchedAt != null &&
        now.difference(_tokenFetchedAt!) < const Duration(minutes: 55)) {
      return _cachedToken;
    }
    try {
      _cachedToken = await ApiClient().getToken();
      _tokenFetchedAt = now;
    } catch (_) {
      _cachedToken = null;
    }
    return _cachedToken;
  }

  Future<void> _awaitInFlightIfAny(String id) async {
    final completer = _inFlight[id];
    if (completer == null) return;
    try {
      await completer.future.timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  List<String> _urlCandidates(String raw) {
    final seen = <String>{};
    void add(String v) {
      final s = v.trim();
      if (s.isEmpty) return;
      seen.add(s);
    }

    add(raw);
    final canonical = UrlHelper.absoluteUrl(raw);
    add(canonical);
    if (canonical.startsWith('http://')) {
      add(canonical.replaceFirst('http://', 'https://'));
    }
    try {
      final uri = Uri.parse(canonical);
      if (uri.path.startsWith('/api/')) {
        add(uri.replace(path: uri.path.replaceFirst('/api', '')).toString());
      } else {
        add(uri.replace(path: '/api${uri.path}').toString());
      }
    } catch (_) {}

    return seen.toList();
  }

  Future<List<Map<String, String>>> _headerCandidates(String url) async {
    // Try without auth first (CDNs often reject Authorization), then with auth
    // if this host is expected to require it.
    final base = <String, String>{};
    final out = <Map<String, String>>[base];
    final token = await _getToken();
    if (token == null || token.isEmpty) return out;
    if (!UrlHelper.shouldAttachAuthHeader(url)) return out;
    out.add(<String, String>{'Authorization': 'Bearer $token'});
    return out;
  }

  Future<VideoPlayerController> _createControllerFor(
    String url, {
    required Map<String, String> headers,
  }) async {
    final ctl = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    await ctl.initialize().timeout(const Duration(seconds: 12));
    await ctl.setLooping(true);
    return ctl;
  }

  /// Pre-warm a video controller without playing it.
  /// Call this for the item JUST below the active one.
  Future<void> preWarm(String id, String url) async {
    if (contains(id)) return; // already warmed or in-flight
    final completer = Completer<void>();
    _inFlight[id] = completer;
    try {
      _evictIfNeeded(keep: _activeId);
      for (final candidateUrl in _urlCandidates(url)) {
        final headerCandidates = await _headerCandidates(candidateUrl);
        for (final headers in headerCandidates) {
          VideoPlayerController? ctl;
          try {
            ctl = await _createControllerFor(candidateUrl, headers: headers);
            await ctl.setVolume(0); // silent while pre-warming
            _pool[id] = ctl;
            _touchWarmOrder(id);
            _evictIfNeeded(keep: _activeId);
            return;
          } catch (_) {
            try {
              await ctl?.dispose();
            } catch (_) {}
          }
        }
      }
    } catch (_) {
      // Intentionally ignored: pre-warming is best-effort.
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _inFlight.remove(id);
    }
  }

  Future<VideoPlayerController> attach(String id, String url) async {
    final existingActive = _activeId == id ? _usableController(id) : null;
    if (existingActive != null) {
      final ctl = existingActive;
      await ctl.setVolume(_muted ? 0 : 1);
      if (!ctl.value.isPlaying) await ctl.play();
      return ctl;
    }

    // Pause old active
    if (_activeId != null && _pool.containsKey(_activeId)) {
      try {
        await _pool[_activeId]!.pause();
      } catch (_) {}
    }

    _activeId = id;

    // If a prewarm is still initializing for this id, wait briefly for it to
    // finish so we can reuse the warmed controller instead of creating a new one.
    await _awaitInFlightIfAny(id);

    // Reuse pre-warmed controller if we have it
    final prewarmed = _usableController(id);
    if (prewarmed != null) {
      final ctl = prewarmed;
      await ctl.setVolume(_muted ? 0 : 1);
      await ctl.play();
      _evictIfNeeded(keep: id);
      _touchWarmOrder(id);
      return ctl;
    }

    // Not pre-warmed — initialize fresh
    _evictIfNeeded(keep: id);
    Object? lastError;
    for (final candidateUrl in _urlCandidates(url)) {
      final headerCandidates = await _headerCandidates(candidateUrl);
      for (final headers in headerCandidates) {
        VideoPlayerController? ctl;
        try {
          ctl = await _createControllerFor(candidateUrl, headers: headers);
          await ctl.setVolume(_muted ? 0 : 1);
          await ctl.play();
          _pool[id] = ctl;
          _touchWarmOrder(id);
          _evictIfNeeded(keep: id);
          return ctl;
        } catch (e) {
          lastError = e;
          try {
            await ctl?.dispose();
          } catch (_) {}
        }
      }
    }
    throw lastError ?? Exception('VideoPool.attach failed for id=$id');
  }

  void _touchWarmOrder(String id) {
    _warmOrder.remove(id);
    _warmOrder.add(id);
    if (_warmOrder.length > 10) {
      _warmOrder.removeRange(0, _warmOrder.length - 10);
    }
  }

  bool _isControllerUsable(VideoPlayerController ctl) {
    try {
      // Accessing value will throw if disposed
      ctl.value;
      return true;
    } catch (_) {
      return false;
    }
  }

  VideoPlayerController? _usableController(String id) {
    final ctl = _pool[id];
    if (ctl == null) return null;
    if (!_isControllerUsable(ctl)) {
      _pool.remove(id);
      _warmOrder.remove(id);
      return null;
    }
    return ctl;
  }

  void _evictIfNeeded({String? keep}) {
    if (_pool.length <= _maxSlots) return;
    final protected = <String>{
      if (_activeId != null) _activeId!,
      if (keep != null) keep,
      ..._warmOrder.reversed.take(2),
    };
    final candidates = _warmOrder.where((id) => _pool.containsKey(id)).toList();
    for (final id in candidates) {
      if (_pool.length <= _maxSlots) break;
      if (protected.contains(id)) continue;
      final ctl = _pool.remove(id);
      if (ctl == null || !_isControllerUsable(ctl)) continue;
      ctl.pause().then((_) => ctl.dispose()).catchError((_) {});
    }
    if (_pool.length > _maxSlots) {
      final leftovers =
          _pool.keys.where((k) => !protected.contains(k)).toList();
      for (final id in leftovers) {
        if (_pool.length <= _maxSlots) break;
        final ctl = _pool.remove(id);
        if (ctl == null || !_isControllerUsable(ctl)) continue;
        ctl.pause().then((_) => ctl.dispose()).catchError((_) {});
      }
    }
  }

  Future<void> disposeActive() async {
    // Only pause the active controller — preserve pre-warmed ones
    if (_activeId != null && _pool.containsKey(_activeId)) {
      try {
        await _pool[_activeId]!.pause();
      } catch (_) {}
    }
    _activeId = null;
  }

  Future<void> disposeAll() async {
    for (final ctl in _pool.values) {
      try {
        await ctl.pause();
      } catch (_) {}
      try {
        await ctl.dispose();
      } catch (_) {}
    }
    _pool.clear();
    _inFlight.clear();
    _warmOrder.clear();
    _activeId = null;
  }

  Future<void> pauseActive() async {
    if (_activeId != null && _pool.containsKey(_activeId)) {
      try {
        await _pool[_activeId]!.pause();
      } catch (_) {}
    }
  }

  Future<void> pauseIf(String id) async {
    if (_pool.containsKey(id)) {
      try {
        await _pool[id]!.pause();
      } catch (_) {}
    }
  }
}
