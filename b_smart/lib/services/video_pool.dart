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
    final headers = await _headersFor(url);
    final ctl = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: headers);
    await ctl.initialize();
    await ctl.setLooping(true);
    await ctl.setVolume(_muted ? 0 : 1);
    _active = ctl;
    _activeId = id;
    return ctl;
  }

  Future<Map<String, String>> _headersFor(String url) async {
    final token = await ApiClient().getToken();
    if (token == null || token.isEmpty) return const {};
    // Try with auth; higher layers can retry without if needed.
    return {'Authorization': 'Bearer $token'};
  }

  Future<void> disposeActive() async {
    if (_active != null) {
      await _active!.pause();
      await _active!.dispose();
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
