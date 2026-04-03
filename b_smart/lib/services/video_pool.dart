import 'package:video_player/video_player.dart';
import '../api/api_client.dart';

class VideoPool {
  VideoPool._();
  static final VideoPool instance = VideoPool._();

  // Keep up to 3 controllers: active + 2 neighbors
  final Map<String, VideoPlayerController> _pool = {};
  final Set<String> _inFlight = {};
  final List<String> _warmOrder = <String>[];
  static const int _maxSlots = 3;
  String? _activeId;
  bool _muted = true;
  String? _cachedToken;
  DateTime? _tokenFetchedAt;

  bool get isMuted => _muted;
  bool contains(String id) => _pool.containsKey(id) || _inFlight.contains(id);

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

  /// Pre-warm a video controller without playing it.
  /// Call this for the item JUST below the active one.
  Future<void> preWarm(String id, String url) async {
    if (contains(id)) return; // already warmed or in-flight
    _inFlight.add(id);
    _evictIfNeeded(keep: _activeId);
    try {
      final headers = await _headersFor(url);
      final ctl = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: headers);
      await ctl.initialize();
      await ctl.setLooping(true);
      await ctl.setVolume(0); // silent while pre-warming
      _pool[id] = ctl;
      _touchWarmOrder(id);
    } catch (_) {}
    finally {
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
    final headers = await _headersFor(url);
    final ctl = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: headers);
    _pool[id] = ctl;
    await ctl.initialize();
    await ctl.setLooping(true);
    await ctl.setVolume(_muted ? 0 : 1);
    await ctl.play();
    _touchWarmOrder(id);
    return ctl;
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
      final leftovers = _pool.keys.where((k) => !protected.contains(k)).toList();
      for (final id in leftovers) {
        if (_pool.length <= _maxSlots) break;
        final ctl = _pool.remove(id);
        if (ctl == null || !_isControllerUsable(ctl)) continue;
        ctl.pause().then((_) => ctl.dispose()).catchError((_) {});
      }
    }
  }

  Future<Map<String, String>> _headersFor(String url) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) return const {};
    return {'Authorization': 'Bearer $token'};
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
