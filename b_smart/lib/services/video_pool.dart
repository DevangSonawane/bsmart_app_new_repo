import 'dart:async';
import 'package:video_player/video_player.dart';
import '../utils/url_helper.dart';
import '../api/api_client.dart';

/// Keeps only one VideoPlayerController alive to avoid memory churn.
class VideoPool {
  VideoPool._();
  static final VideoPool instance = VideoPool._();

  VideoPlayerController? _active;
  String? _activeId;
  bool _muted = true;

  bool get isMuted => _muted;

  // Simple serialisation for attach operations to avoid concurrent
  // VideoPlayerController initializations which may overload native player
  // and cause ExoPlaybackExceptions on Android.
  Completer<void>? _attachCompleter;

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    final ctl = _active;
    if (ctl == null) return;
    try {
      await ctl.setVolume(_muted ? 0 : 1);
    } catch (_) {}
  }

  Future<void> toggleMuted() => setMuted(!_muted);

  Future<VideoPlayerController> attach(String id, String url) async {
    if (_activeId == id && _active != null) return _active!;
    await disposeActive();
    try {
      final headers = await _headersFor(url);
      final ctl = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: headers);
      // Initialize inside try so platform exceptions are caught here.
      await ctl.initialize();

      // Listen for controller-side errors and handle gracefully.
      ctl.addListener(() {
        try {
          if (ctl.value.hasError) {
            print('VideoPool: controller reported error for id=$id url=$url error=${ctl.value.errorDescription}');
            // Dispose the faulty controller asynchronously.
            (() async {
              try {
                await ctl.pause();
                await ctl.dispose();
              } catch (_) {}
            }());
            if (_activeId == id) {
              _active = null;
              _activeId = null;
            }
          }
        } catch (_) {}
      });

      await ctl.setLooping(true);
      await ctl.setVolume(_muted ? 0 : 1);
      _active = ctl;
      _activeId = id;
      return ctl;
    } catch (e) {
      try {
        print('VideoPool.attach failed for id=$id url=$url error=$e');
      } catch (_) {}
      _active = null;
      _activeId = null;
      rethrow;
    }
  }

  Future<Map<String, String>> _headersFor(String url) async {
    final token = await ApiClient().getToken();
    if (token == null || token.isEmpty) return const {};
    // Try with auth; higher layers can retry without if needed.
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> disposeActive() async {
    if (_active != null) {
      try {
        await _active!.pause();
      } catch (_) {}
      try {
        await _active!.dispose();
      } catch (_) {}
    }
    _active = null;
    _activeId = null;
  }

  Future<void> pauseIf(String id) async {
    if (_activeId == id && _active != null) {
      await _active!.pause();
    }
  }
}
