import 'dart:async';

import 'package:video_player/video_player.dart';

class VideoAudioSession {
  VideoAudioSession._();

  static final VideoAudioSession instance = VideoAudioSession._();

  VideoPlayerController? _activeController;

  Future<void> activate(VideoPlayerController controller) async {
    final previous = _activeController;
    if (previous != null &&
        !identical(previous, controller) &&
        previous.value.isInitialized) {
      try {
        await previous.setVolume(0.0);
        await previous.pause();
      } catch (_) {}
    }
    _activeController = controller;
  }

  void release(VideoPlayerController controller) {
    if (identical(_activeController, controller)) {
      _activeController = null;
    }
  }
}
