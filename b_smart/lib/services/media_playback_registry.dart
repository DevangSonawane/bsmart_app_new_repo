import 'dart:async';

/// Global registry for "pause everything" playback boundaries.
///
/// Each long-lived media surface registers a small pause callback so the app
/// can enforce an Instagram-style invariant:
/// only the foreground media surface should remain audible.
class MediaPlaybackRegistry {
  MediaPlaybackRegistry._();

  static final MediaPlaybackRegistry instance = MediaPlaybackRegistry._();

  final Map<String, FutureOr<void> Function()> _pauseHandlers = {};

  void register(String id, FutureOr<void> Function() pauseHandler) {
    final key = id.trim();
    if (key.isEmpty) return;
    _pauseHandlers[key] = pauseHandler;
  }

  void unregister(String id) {
    _pauseHandlers.remove(id.trim());
  }

  Future<void> pauseAll({String? except}) async {
    final skip = except?.trim();
    for (final entry in _pauseHandlers.entries.toList()) {
      if (skip != null && skip.isNotEmpty && entry.key == skip) continue;
      try {
        await Future.sync(entry.value);
      } catch (_) {
        // Best-effort guard. Playback boundaries must never crash navigation.
      }
    }
  }
}
