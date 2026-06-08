import 'dart:io';
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../features/reel_timeline/reel_timeline_models.dart';
import '../../models/media_model.dart' as app_models;
import '../../services/create_service.dart';
import '../../instagram_text_editor/instagram_text_editor.dart';
import '../../instagram_text_editor/instagram_text_result.dart';
import '../../instagram_overlay/overlay_shape.dart';
import '../create_reel_details_screen.dart';
import 'reel_timeline_strip.dart';
import 'reel_overlay_duration_sheet.dart';
import 'reel_caption_screen.dart';
import 'reel_export_service.dart';
import 'reel_draft_service.dart';
import 'reel_audio_picker_screen.dart';
import 'reel_voice_recorder_sheet.dart';
import 'reel_volume_panel.dart';
import 'reel_clip_context_menu.dart';
import 'reel_transition_picker.dart';

enum ReelEditorMode {
  idle,
  addingText,
  addingSticker,
  audioPanel,
  voiceRecord,
  effectsPanel,
  volumePanel,
}

class ReelEditorScreen extends StatefulWidget {
  final List<app_models.MediaItem> initialMedia;

  const ReelEditorScreen({
    super.key,
    required this.initialMedia,
  });

  @override
  State<ReelEditorScreen> createState() => _ReelEditorScreenState();
}

class _ReelEditorScreenState extends State<ReelEditorScreen> {
  static const List<double> _identityMatrix = <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  late List<ReelClip> _clips;
  int _activeClipIndex = 0;
  double _playheadMs = 0.0;
  final ValueNotifier<double> _playheadMsNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> _clockNotifier =
      ValueNotifier<String>('0:00 / 0:00');
  bool _isPlaying = false;
  VideoPlayerController? _videoController;
  final LinkedHashMap<String, VideoPlayerController> _controllerCache =
      LinkedHashMap<String, VideoPlayerController>();
  static const int _controllerCacheMaxSize = 3;
  String? _initializingPath;
  Timer? _playheadTimer;
  ReelEditorMode _mode = ReelEditorMode.idle;
  final ReelEditHistory _history = ReelEditHistory();
  double _pxPerMs = 0.12;
  int? _selectedClipIndex;
  bool _isReorderMode = false;
  final Set<String> _selectedClipIds = {};
  final List<ReelEditorTextOverlay> _textOverlays = [];
  final List<ReelEditorStickerOverlay> _stickerOverlays = [];
  int? _activeTextIndex;
  int? _activeStickerIndex;
  final GlobalKey _previewKey = GlobalKey();
  bool _showDeleteZone = false;
  String? _audioPath;
  double _audioVolume = 1.0;
  String? _voicePath;
  double _voiceVolume = 1.0;
  double _originalVolume = 1.0;
  List<ReelCaption> _captions = [];
  int _idCounter = 0;
  final GlobalKey _timelineKey = GlobalKey();
  bool _showPlayheadTooltip = false;
  Timer? _hidePlayheadTimer;
  bool _isTrimMode = false;
  double _timelineScrollOffset = 0.0;
  double? _lastSeekedMs;
  bool _hasLoggedVideoGeometry = false;

  @override
  void initState() {
    super.initState();
    _clips = widget.initialMedia.map((m) {
      final isVideo = m.type == app_models.MediaType.video;
      return ReelClip(
        id: m.id,
        type: isVideo ? ReelClipType.video : ReelClipType.image,
        path: m.filePath ?? '',
        duration: isVideo
            ? (m.duration ?? const Duration(seconds: 1))
            : const Duration(seconds: 3),
      );
    }).toList();
    if (_clips.isNotEmpty) {
      _selectedClipIndex = 0;
    }
    _history.push(_clips);
    _initControllerForActiveClip();
  }

  @override
  void dispose() {
    _hidePlayheadTimer?.cancel();
    _playheadTimer?.cancel();
    final cachedControllers = _controllerCache.values.toList(growable: false);
    _controllerCache.clear();
    for (final c in cachedControllers) {
      unawaited(c.dispose());
    }
    if (_videoController != null &&
        !cachedControllers.any((c) => identical(c, _videoController))) {
      _videoController?.dispose();
    }
    _playheadMsNotifier.dispose();
    _clockNotifier.dispose();
    super.dispose();
  }

  VideoPlayerController? _getCachedController(String path) {
    final existing = _controllerCache.remove(path);
    if (existing != null) {
      // Reinsert to mark as most recently used (LRU).
      _controllerCache[path] = existing;
    }
    return existing;
  }

  void _putCachedController(String path, VideoPlayerController controller) {
    _controllerCache.remove(path);
    _controllerCache[path] = controller;
    _trimControllerCache(protectedPath: path);
  }

  void _trimControllerCache({String? protectedPath}) {
    while (_controllerCache.length > _controllerCacheMaxSize) {
      final oldestKey = _controllerCache.keys.first;
      if (protectedPath != null &&
          _controllerCache.length > 1 &&
          oldestKey == protectedPath) {
        // Avoid evicting the protected entry; move it to the end and try again.
        final protected = _controllerCache.remove(oldestKey);
        if (protected != null) _controllerCache[oldestKey] = protected;
        continue;
      }
      final controller = _controllerCache.remove(oldestKey);
      if (controller != null) {
        unawaited(controller.dispose());
      }
    }
  }

  void _evictStaleControllers() {
    final keepPaths =
        _clips.map((c) => c.path).where((p) => p.isNotEmpty).toSet();
    final staleKeys =
        _controllerCache.keys.where((k) => !keepPaths.contains(k)).toList();
    for (final key in staleKeys) {
      final controller = _controllerCache.remove(key);
      if (controller != null) {
        unawaited(controller.dispose());
      }
    }
  }

  double _clipLocalMsForTimelineMs(double timelineMs) {
    if (_clips.isEmpty) return 0.0;
    final activeStartMs = _clipStartMsForIndex(_activeClipIndex);
    final clip = _clips[_activeClipIndex];
    final localTimelineMs =
        (timelineMs - activeStartMs).clamp(0.0, double.infinity).toDouble();
    final maxLocalTimelineMs = _clipEffectiveDurationMs(clip);
    final clampedLocalTimelineMs =
        localTimelineMs.clamp(0.0, maxLocalTimelineMs).toDouble();

    final trimStartMs =
        (clip.trimStart ?? Duration.zero).inMilliseconds.toDouble();
    final trimEndMs = (clip.trimEnd ?? clip.duration).inMilliseconds.toDouble();
    final speed = clip.speed <= 0 ? 1.0 : clip.speed;
    final sourcePositionMs = trimStartMs + (clampedLocalTimelineMs * speed);
    return sourcePositionMs.clamp(trimStartMs, trimEndMs).toDouble();
  }

  void _setDeleteZoneVisible(bool visible) {
    if (_showDeleteZone == visible) return;
    setState(() => _showDeleteZone = visible);
  }

  void _updateClockNotifier() {
    final ctrl = _videoController;
    final position = ctrl?.value.position ?? Duration.zero;
    final duration = ctrl?.value.duration ?? Duration.zero;
    _clockNotifier.value =
        '${_formatClock(position)} / ${_formatClock(duration)}';
  }

  Future<void> _initControllerForActiveClip() async {
    _playheadTimer?.cancel();
    _initializingPath = null;
    final old = _videoController;

    if (_clips.isEmpty) {
      if (old != null) {
        try {
          await old.pause();
        } catch (_) {}
      }
      _videoController = null;
      if (mounted) setState(() {});
      return;
    }

    final clip = _clips[_activeClipIndex];
    if (clip.type != ReelClipType.video || clip.path.isEmpty) {
      if (old != null) {
        try {
          await old.pause();
        } catch (_) {}
      }
      _videoController = null;
      if (mounted) setState(() {});
      return;
    }

    final cached = _getCachedController(clip.path);
    if (cached != null) {
      bool isInitialized = false;
      try {
        isInitialized = cached.value.isInitialized;
      } catch (_) {
        isInitialized = false;
      }
      if (isInitialized) {
        if (old != null && !identical(old, cached)) {
          try {
            await old.pause();
          } catch (_) {}
        }
        _videoController = cached;
        _initializingPath = clip.path;
        try {
          await cached.setLooping(true);
          await cached.setVolume(_originalVolume.clamp(0.0, 1.0));
          await cached.seekTo(clip.trimStart ?? Duration.zero);
          _lastSeekedMs = null;
          _updateClockNotifier();
          if (_isPlaying) {
            await cached.play();
            _startPlayheadTimer();
          } else {
            await cached.pause();
          }
        } catch (_) {}
        if (mounted) setState(() {});
        return;
      }

      _controllerCache.remove(clip.path);
      unawaited(cached.dispose());
    }

    // Only dispose the old controller if it's not managed by the cache.
    if (old != null && !_controllerCache.values.any((c) => identical(c, old))) {
      await old.dispose();
    }

    if (old != null && _controllerCache.values.any((c) => identical(c, old))) {
      try {
        await old.pause();
      } catch (_) {}
    }

    final controller = VideoPlayerController.file(File(clip.path));
    _videoController = controller;
    _initializingPath = clip.path;
    try {
      await controller.initialize();
    } catch (_) {
      if (_videoController == controller) {
        _videoController = null;
      }
      await controller.dispose();
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    if (_initializingPath != clip.path) {
      await controller.dispose();
      return;
    }

    await controller.setLooping(true);
    await controller.setVolume(_originalVolume.clamp(0.0, 1.0));
    try {
      await controller.seekTo(clip.trimStart ?? Duration.zero);
    } catch (_) {}
    if (!_hasLoggedVideoGeometry) {
      _hasLoggedVideoGeometry = true;
      debugPrint(
        '[ReelEditor] video init path=${clip.path} '
        'size=${controller.value.size.width}x${controller.value.size.height} '
        'aspect=${controller.value.aspectRatio} '
        'durationMs=${controller.value.duration.inMilliseconds} '
        'trimStartMs=${(clip.trimStart ?? Duration.zero).inMilliseconds} '
        'trimEndMs=${(clip.trimEnd ?? clip.duration).inMilliseconds} '
        'speed=${clip.speed} '
        'isReversed=${clip.isReversed}',
      );
    }
    _putCachedController(clip.path, controller);
    _lastSeekedMs = null;
    _updateClockNotifier();
    if (_isPlaying) {
      await controller.play();
      _startPlayheadTimer();
    }
    setState(() {});
  }

  void _startPlayheadTimer() {
    _playheadTimer?.cancel();
    _playheadTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final ctrl = _videoController;
      if (ctrl == null || !ctrl.value.isInitialized) return;
      if (_activeClipIndex < 0 || _activeClipIndex >= _clips.length) return;
      final clip = _clips[_activeClipIndex];
      final positionMs = ctrl.value.position.inMilliseconds.toDouble();
      final trimStartMs =
          (clip.trimStart ?? Duration.zero).inMilliseconds.toDouble();
      final speed = clip.speed <= 0 ? 1.0 : clip.speed;
      final localTimelineMs = ((positionMs - trimStartMs) / speed)
          .clamp(0.0, _clipEffectiveDurationMs(clip))
          .toDouble();
      final timelineMs =
          (_clipStartMsForIndex(_activeClipIndex) + localTimelineMs)
              .clamp(0.0, _totalDurationMs)
              .toDouble();
      if (!mounted) return;
      _playheadMs = timelineMs;
      _playheadMsNotifier.value = timelineMs;
      _updateClockNotifier();
    });
  }

  void _stopPlayheadTimer() {
    _playheadTimer?.cancel();
    _playheadTimer = null;
  }

  Future<void> _togglePlayback() async {
    unawaited(HapticFeedback.lightImpact());
    final ctrl = _videoController;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isPlaying) {
      await ctrl.pause();
      _stopPlayheadTimer();
      if (!mounted) return;
      setState(() => _isPlaying = false);
    } else {
      await ctrl.play();
      _startPlayheadTimer();
      if (!mounted) return;
      setState(() => _isPlaying = true);
    }
  }

  void _setMode(ReelEditorMode mode) {
    setState(() {
      _mode = (_mode == mode) ? ReelEditorMode.idle : mode;
    });
  }

  String _newClipId(String base) {
    _idCounter += 1;
    return '${base}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  String _newGroupId() {
    _idCounter += 1;
    return 'group_${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  double _clipBaseDurationMs(ReelClip clip) {
    final start = clip.trimStart ?? Duration.zero;
    final end = clip.trimEnd ?? clip.duration;
    final baseMs = (end - start).inMilliseconds.toDouble();
    return baseMs < 0 ? 0 : baseMs;
  }

  double _clipEffectiveDurationMs(ReelClip clip) {
    final baseMs = _clipBaseDurationMs(clip);
    final speed = clip.speed <= 0 ? 1.0 : clip.speed;
    return baseMs / speed;
  }

  double _clipStartMsForIndex(int index) {
    double sum = 0;
    for (int i = 0; i < index; i++) {
      sum += _clipEffectiveDurationMs(_clips[i]);
    }
    return sum;
  }

  void _applyClips(List<ReelClip> next) {
    setState(() {
      _clips = next;
      if (_clips.isEmpty) {
        _activeClipIndex = 0;
        _selectedClipIndex = null;
        _playheadMs = 0.0;
      } else {
        if (_activeClipIndex >= _clips.length) {
          _activeClipIndex = _clips.length - 1;
        }
        if (_selectedClipIndex != null &&
            _selectedClipIndex! >= _clips.length) {
          _selectedClipIndex = null;
        }
      }
    });
    _playheadMsNotifier.value = _playheadMs;
    _history.push(next);
    _initControllerForActiveClip();
    _evictStaleControllers();
  }

  void _undo() {
    if (!_history.canUndo) return;
    unawaited(HapticFeedback.selectionClick());
    final next = _history.undo();
    if (next == null) return;
    setState(() {
      _clips = next;
      if (_activeClipIndex >= _clips.length) {
        _activeClipIndex = _clips.isEmpty ? 0 : _clips.length - 1;
      }
      if (_selectedClipIndex != null && _selectedClipIndex! >= _clips.length) {
        _selectedClipIndex = null;
      }
    });
    _initControllerForActiveClip();
  }

  void _redo() {
    if (!_history.canRedo) return;
    unawaited(HapticFeedback.selectionClick());
    final next = _history.redo();
    if (next == null) return;
    setState(() {
      _clips = next;
      if (_activeClipIndex >= _clips.length) {
        _activeClipIndex = _clips.isEmpty ? 0 : _clips.length - 1;
      }
      if (_selectedClipIndex != null && _selectedClipIndex! >= _clips.length) {
        _selectedClipIndex = null;
      }
    });
    _initControllerForActiveClip();
  }

  void _mutate(List<ReelClip> Function(List<ReelClip> clips) transform) {
    final next = transform(List<ReelClip>.from(_clips));
    _applyClips(next);
    unawaited(HapticFeedback.lightImpact());
  }

  int? _findClipIndexAtPlayhead() {
    double cursor = 0;
    for (int i = 0; i < _clips.length; i++) {
      final clipMs = _clipEffectiveDurationMs(_clips[i]);
      if (_playheadMs >= cursor && _playheadMs < cursor + clipMs) {
        return i;
      }
      cursor += clipMs;
    }
    return _clips.isEmpty ? null : _clips.length - 1;
  }

  void _splitAtPlayhead() {
    final index = _findClipIndexAtPlayhead();
    if (index == null) return;
    final clip = _clips[index];
    final clipStartMs = _clipStartMsForIndex(index);
    final localTimelineMs =
        (_playheadMs - clipStartMs).clamp(0.0, _clipEffectiveDurationMs(clip));
    final localSourceMs =
        localTimelineMs * (clip.speed <= 0 ? 1.0 : clip.speed);
    final startMs = (clip.trimStart ?? Duration.zero).inMilliseconds.toDouble();
    final endMs = (clip.trimEnd ?? clip.duration).inMilliseconds.toDouble();
    final splitMs = startMs + localSourceMs;
    if (splitMs <= startMs + 10 || splitMs >= endMs - 10) {
      return;
    }
    final splitPoint = Duration(milliseconds: splitMs.round());
    _mutate((clips) {
      final clipA = ReelClip(
        id: clip.id,
        type: clip.type,
        path: clip.path,
        duration: clip.duration,
        trimStart: clip.trimStart,
        trimEnd: splitPoint,
        colorMatrix: clip.colorMatrix,
        textOverlays: clip.textOverlays,
        stickerOverlays: clip.stickerOverlays,
        speed: clip.speed,
        isReversed: clip.isReversed,
        freezeAt: clip.freezeAt,
        freezeDuration: clip.freezeDuration,
        transitionIn: clip.transitionIn,
        transitionInDurationMs: clip.transitionInDurationMs,
        groupId: clip.groupId,
        audioPath: clip.audioPath,
        audioVolume: clip.audioVolume,
        originalVolume: clip.originalVolume,
        voicePath: clip.voicePath,
        voiceVolume: clip.voiceVolume,
      );
      final clipB = ReelClip(
        id: _newClipId(clip.id),
        type: clip.type,
        path: clip.path,
        duration: clip.duration,
        trimStart: splitPoint,
        trimEnd: clip.trimEnd,
        colorMatrix: clip.colorMatrix,
        textOverlays: clip.textOverlays,
        stickerOverlays: clip.stickerOverlays,
        speed: clip.speed,
        isReversed: clip.isReversed,
        freezeAt: clip.freezeAt,
        freezeDuration: clip.freezeDuration,
        transitionIn: clip.transitionIn,
        transitionInDurationMs: clip.transitionInDurationMs,
        groupId: clip.groupId,
        audioPath: clip.audioPath,
        audioVolume: clip.audioVolume,
        originalVolume: clip.originalVolume,
        voicePath: clip.voicePath,
        voiceVolume: clip.voiceVolume,
      );
      clips.removeAt(index);
      clips.insert(index, clipB);
      clips.insert(index, clipA);
      return clips;
    });
  }

  void _deleteClip(int index) {
    if (index < 0 || index >= _clips.length) return;
    final removedId = _clips[index].id;
    _mutate((clips) {
      clips.removeAt(index);
      return clips;
    });
    if (_selectedClipIndex == index) {
      setState(() => _selectedClipIndex = null);
    }
    if (_selectedClipIds.contains(removedId)) {
      setState(() => _selectedClipIds.remove(removedId));
    }
  }

  void _duplicateClip(int index) {
    if (index < 0 || index >= _clips.length) return;
    final clip = _clips[index];
    _mutate((clips) {
      clips.insert(
        index + 1,
        ReelClip(
          id: _newClipId(clip.id),
          type: clip.type,
          path: clip.path,
          duration: clip.duration,
          trimStart: clip.trimStart,
          trimEnd: clip.trimEnd,
          colorMatrix: clip.colorMatrix,
          textOverlays: clip.textOverlays,
          stickerOverlays: clip.stickerOverlays,
          speed: clip.speed,
          isReversed: clip.isReversed,
          freezeAt: clip.freezeAt,
          freezeDuration: clip.freezeDuration,
          transitionIn: clip.transitionIn,
          transitionInDurationMs: clip.transitionInDurationMs,
          groupId: clip.groupId,
          audioPath: clip.audioPath,
          audioVolume: clip.audioVolume,
          originalVolume: clip.originalVolume,
          voicePath: clip.voicePath,
          voiceVolume: clip.voiceVolume,
        ),
      );
      return clips;
    });
  }

  void _reverseClip(int index) {
    if (index < 0 || index >= _clips.length) return;
    _mutate((clips) {
      final clip = clips[index];
      clips[index] = ReelClip(
        id: clip.id,
        type: clip.type,
        path: clip.path,
        duration: clip.duration,
        trimStart: clip.trimStart,
        trimEnd: clip.trimEnd,
        colorMatrix: clip.colorMatrix,
        textOverlays: clip.textOverlays,
        stickerOverlays: clip.stickerOverlays,
        speed: clip.speed,
        isReversed: !clip.isReversed,
        freezeAt: clip.freezeAt,
        freezeDuration: clip.freezeDuration,
        transitionIn: clip.transitionIn,
        transitionInDurationMs: clip.transitionInDurationMs,
        groupId: clip.groupId,
        audioPath: clip.audioPath,
        audioVolume: clip.audioVolume,
        originalVolume: clip.originalVolume,
        voicePath: clip.voicePath,
        voiceVolume: clip.voiceVolume,
      );
      return clips;
    });
  }

  void _freezeFrameAtPlayhead() {
    final index = _findClipIndexAtPlayhead();
    if (index == null) return;
    final clip = _clips[index];
    final freezeClip = ReelClip(
      id: _newClipId(clip.id),
      type: ReelClipType.image,
      path: clip.path,
      duration: const Duration(seconds: 2),
      groupId: clip.groupId,
    );
    _mutate((clips) {
      clips.insert(index + 1, freezeClip);
      return clips;
    });
  }

  void _reorderClip(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= _clips.length) return;
    if (toIndex < 0 || toIndex >= _clips.length) return;
    if (fromIndex == toIndex) return;
    final moving = _clips[fromIndex];
    final groupId = moving.groupId;
    if (groupId == null) {
      _mutate((clips) {
        final clip = clips.removeAt(fromIndex);
        clips.insert(toIndex, clip);
        return clips;
      });
      return;
    }
    final groupIndices = <int>[];
    for (int i = 0; i < _clips.length; i++) {
      if (_clips[i].groupId == groupId) groupIndices.add(i);
    }
    if (groupIndices.length <= 1) {
      _mutate((clips) {
        final clip = clips.removeAt(fromIndex);
        clips.insert(toIndex, clip);
        return clips;
      });
      return;
    }
    final groupClips = groupIndices.map((i) => _clips[i]).toList();
    _mutate((clips) {
      for (int i = groupIndices.length - 1; i >= 0; i--) {
        clips.removeAt(groupIndices[i]);
      }
      int insertIndex = 0;
      for (int i = 0; i < _clips.length; i++) {
        if (_clips[i].groupId == groupId) continue;
        if (i == toIndex) break;
        insertIndex++;
      }
      if (toIndex > groupIndices.last) {
        insertIndex += 1;
      }
      if (insertIndex < 0) insertIndex = 0;
      if (insertIndex > clips.length) insertIndex = clips.length;
      clips.insertAll(insertIndex, groupClips);
      return clips;
    });
  }

  void _setClipTransition(int index, String type, double durationMs) {
    if (index < 0 || index >= _clips.length) return;
    _mutate((clips) {
      final clip = clips[index];
      clips[index] = ReelClip(
        id: clip.id,
        type: clip.type,
        path: clip.path,
        duration: clip.duration,
        trimStart: clip.trimStart,
        trimEnd: clip.trimEnd,
        colorMatrix: clip.colorMatrix,
        textOverlays: clip.textOverlays,
        stickerOverlays: clip.stickerOverlays,
        speed: clip.speed,
        isReversed: clip.isReversed,
        freezeAt: clip.freezeAt,
        freezeDuration: clip.freezeDuration,
        transitionIn: type,
        transitionInDurationMs: durationMs,
        groupId: clip.groupId,
        audioPath: clip.audioPath,
        audioVolume: clip.audioVolume,
        originalVolume: clip.originalVolume,
        voicePath: clip.voicePath,
        voiceVolume: clip.voiceVolume,
      );
      return clips;
    });
  }

  void _setClipSpeed(int index, double speed) {
    if (index < 0 || index >= _clips.length) return;
    _mutate((clips) {
      final clip = clips[index];
      clips[index] = ReelClip(
        id: clip.id,
        type: clip.type,
        path: clip.path,
        duration: clip.duration,
        trimStart: clip.trimStart,
        trimEnd: clip.trimEnd,
        colorMatrix: clip.colorMatrix,
        textOverlays: clip.textOverlays,
        stickerOverlays: clip.stickerOverlays,
        speed: speed,
        isReversed: clip.isReversed,
        freezeAt: clip.freezeAt,
        freezeDuration: clip.freezeDuration,
        transitionIn: clip.transitionIn,
        transitionInDurationMs: clip.transitionInDurationMs,
        groupId: clip.groupId,
        audioPath: clip.audioPath,
        audioVolume: clip.audioVolume,
        originalVolume: clip.originalVolume,
        voicePath: clip.voicePath,
        voiceVolume: clip.voiceVolume,
      );
      return clips;
    });
  }

  void _setClipDuration(int index, Duration duration) {
    if (index < 0 || index >= _clips.length) return;
    final clip = _clips[index];
    if (clip.type != ReelClipType.image) return;
    _mutate((clips) {
      final current = clips[index];
      clips[index] = ReelClip(
        id: current.id,
        type: current.type,
        path: current.path,
        duration: duration,
        trimStart: current.trimStart,
        trimEnd: current.trimEnd,
        colorMatrix: current.colorMatrix,
        textOverlays: current.textOverlays,
        stickerOverlays: current.stickerOverlays,
        speed: current.speed,
        isReversed: current.isReversed,
        freezeAt: current.freezeAt,
        freezeDuration: current.freezeDuration,
        transitionIn: current.transitionIn,
        transitionInDurationMs: current.transitionInDurationMs,
        groupId: current.groupId,
        audioPath: current.audioPath,
        audioVolume: current.audioVolume,
        originalVolume: current.originalVolume,
        voicePath: current.voicePath,
        voiceVolume: current.voiceVolume,
      );
      return clips;
    });
  }

  Offset _previewCenter() {
    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return const Offset(100, 200);
    final size = box.size;
    return Offset(size.width / 2, size.height / 2);
  }

  Offset _globalToPreview(Offset global) {
    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return global;
    return box.globalToLocal(global);
  }

  Offset _trashCenter() {
    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return const Offset(0, 0);
    final size = box.size;
    return Offset(size.width / 2, size.height - 24 - 28);
  }

  Future<void> _openTextEditor() async {
    final result = await InstagramTextEditor.open(
      context,
      backgroundImage: const AssetImage('assets/images/dashboard_sample.png'),
    );
    if (result == null || result.text.trim().isEmpty || !mounted) return;
    final center = _previewCenter();
    setState(() {
      _textOverlays.add(
        ReelEditorTextOverlay(
          text: result.text,
          style: result.style,
          alignment: result.alignment,
          textColor: result.textColor,
          backgroundStyle: result.backgroundStyle,
          position: center,
          scale: result.scale,
          rotation: result.rotation,
          fontSize: result.fontSize,
          startMs: 0,
          endMs: _totalDurationMs,
        ),
      );
      _activeTextIndex = _textOverlays.length - 1;
      _mode = ReelEditorMode.idle;
    });
  }

  Future<void> _openStickerPicker() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final center = _previewCenter();
    setState(() {
      _stickerOverlays.add(
        ReelEditorStickerOverlay(
          imagePath: picked.path,
          position: center,
          scale: 1.0,
          rotation: 0.0,
          startMs: 0,
          endMs: _totalDurationMs,
        ),
      );
      _activeStickerIndex = _stickerOverlays.length - 1;
      _mode = ReelEditorMode.idle;
    });
  }

  Future<void> _openFilterPicker() async {
    if (_clips.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _buildFilterPicker(),
    );
  }

  List<double> _buildFilterMatrixBase({
    required double brightness,
    required double contrast,
    required double saturation,
  }) {
    final b = brightness;
    final c = contrast;
    final s = saturation;
    final invSat = 1 - s;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final scale = c * b;
    return [
      (invSat * lr + s) * scale,
      invSat * lg * scale,
      invSat * lb * scale,
      0,
      0,
      invSat * lr * scale,
      (invSat * lg + s) * scale,
      invSat * lb * scale,
      0,
      0,
      invSat * lr * scale,
      invSat * lg * scale,
      (invSat * lb + s) * scale,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _buildGrayscaleMatrix({
    double contrast = 1.0,
    double brightness = 1.0,
  }) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final c = contrast * brightness;
    return [
      lr * c,
      lg * c,
      lb * c,
      0,
      0,
      lr * c,
      lg * c,
      lb * c,
      0,
      0,
      lr * c,
      lg * c,
      lb * c,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _buildSepiaMatrix({
    required double amount,
    required double brightness,
    required double contrast,
    required double saturation,
  }) {
    final t = (1 - amount).clamp(0.0, 1.0);
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final invSat = 1 - saturation;
    final c = contrast * brightness;
    return [
      (0.393 + 0.607 * t) * saturation * c + lr * invSat * c,
      (0.769 - 0.769 * t) * saturation * c + lg * invSat * c,
      (0.189 - 0.189 * t) * saturation * c + lb * invSat * c,
      0,
      0,
      (0.349 - 0.349 * t) * saturation * c + lr * invSat * c,
      (0.686 + 0.314 * t) * saturation * c + lg * invSat * c,
      (0.168 - 0.168 * t) * saturation * c + lb * invSat * c,
      0,
      0,
      (0.272 - 0.272 * t) * saturation * c + lr * invSat * c,
      (0.534 - 0.534 * t) * saturation * c + lg * invSat * c,
      (0.131 + 0.869 * t) * saturation * c + lb * invSat * c,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _reelFilterMatrixFor(String id) {
    switch (id) {
      case 'vintage':
        return _buildSepiaMatrix(
          amount: 0.35,
          brightness: 1.05,
          contrast: 0.95,
          saturation: 0.9,
        );
      case 'black_white':
        return _buildGrayscaleMatrix(contrast: 1.1, brightness: 1.0);
      case 'warm':
        return _buildSepiaMatrix(
          amount: 0.25,
          brightness: 1.05,
          contrast: 1.0,
          saturation: 1.1,
        );
      case 'cool':
        return _buildFilterMatrixBase(
          brightness: 1.0,
          contrast: 1.0,
          saturation: 0.85,
        );
      case 'dramatic':
        return _buildFilterMatrixBase(
          brightness: 1.0,
          contrast: 1.3,
          saturation: 1.2,
        );
      case 'beauty':
        return _buildSepiaMatrix(
          amount: 0.15,
          brightness: 1.1,
          contrast: 1.05,
          saturation: 1.05,
        );
      case 'ar_effect_1':
        return _buildFilterMatrixBase(
          brightness: 1.05,
          contrast: 1.05,
          saturation: 1.2,
        );
      case 'ar_effect_2':
        return _buildFilterMatrixBase(
          brightness: 0.95,
          contrast: 1.1,
          saturation: 0.9,
        );
      case 'none':
      default:
        return _buildFilterMatrixBase(
          brightness: 1.0,
          contrast: 1.0,
          saturation: 1.0,
        );
    }
  }

  Widget _buildFilterPicker() {
    final clip = _clips[_activeClipIndex];
    final filters = CreateService().getFilters();
    String selectedId = 'none';
    final current = clip.colorMatrix;
    if (current != null) {
      for (final f in filters) {
        if (f.id == 'none') continue;
        if (listEquals(current, _reelFilterMatrixFor(f.id))) {
          selectedId = f.id;
          break;
        }
      }
    }
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 140,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 92,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final f = filters[i];
                  final isSelected = f.id == selectedId;
                  final matrix =
                      f.id == 'none' ? null : _reelFilterMatrixFor(f.id);
                  return GestureDetector(
                    onTap: () {
                      _mutate((clips) {
                        clips[_activeClipIndex] =
                            clips[_activeClipIndex].copyWith(
                          colorMatrix: matrix,
                        );
                        return clips;
                      });
                      Navigator.of(context).pop();
                    },
                    child: SizedBox(
                      width: 72,
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected ? Colors.white : Colors.white12,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.matrix(
                                matrix ?? _identityMatrix,
                              ),
                              child: _FilterChipThumb(
                                clip: clip,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOverlayDurationSheet({
    required double startMs,
    required double endMs,
    required void Function(double, double) onApply,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelOverlayDurationSheet(
        totalDurationMs: _totalDurationMs,
        startMs: startMs,
        endMs: endMs,
        onApply: (value) {
          onApply(value.startMs, value.endMs);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  double get _totalDurationMs {
    return _clips.fold<double>(
      0.0,
      (sum, c) => sum + _clipEffectiveDurationMs(c),
    );
  }

  void _onScrub(double ms) {
    _playheadMs = ms.clamp(0.0, _totalDurationMs);
    _playheadMsNotifier.value = _playheadMs;

    final ctrl = _videoController;
    if (ctrl != null && ctrl.value.isInitialized) {
      final localMs = _clipLocalMsForTimelineMs(_playheadMs);
      final last = _lastSeekedMs;
      if (last == null || (localMs - last).abs() > 50) {
        _lastSeekedMs = localMs;
        unawaited(ctrl.seekTo(Duration(milliseconds: localMs.round())));
      }
      _clockNotifier.value =
          '${_formatClock(Duration(milliseconds: localMs.round()))} / ${_formatClock(ctrl.value.duration)}';
    }
  }

  void _onScrubStart() {
    _hidePlayheadTimer?.cancel();
    setState(() => _showPlayheadTooltip = true);
  }

  void _onScrubEnd() {
    _hidePlayheadTimer?.cancel();
    _hidePlayheadTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showPlayheadTooltip = false);
    });
  }

  void _onClipTap(int index) {
    if (index < 0 || index >= _clips.length) return;
    setState(() {
      _activeClipIndex = index;
      _selectedClipIndex = index;
      _playheadMs = _clips
          .take(index)
          .fold<double>(0.0, (sum, c) => sum + _clipEffectiveDurationMs(c));
    });
    _playheadMsNotifier.value = _playheadMs;
    _initControllerForActiveClip();
  }

  Future<void> _onAddClip() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultipleMedia();
    if (picked.isEmpty || !mounted) return;
    final newClips = <ReelClip>[];
    for (final f in picked) {
      final isVideo = f.mimeType?.startsWith('video') ??
          f.path.toLowerCase().endsWith('.mp4');
      Duration dur = const Duration(seconds: 3);
      if (isVideo) {
        final ctrl = VideoPlayerController.file(File(f.path));
        await ctrl.initialize();
        dur = ctrl.value.duration;
        await ctrl.dispose();
      }
      newClips.add(
        ReelClip(
          id: _newClipId('import'),
          type: isVideo ? ReelClipType.video : ReelClipType.image,
          path: f.path,
          duration: dur,
        ),
      );
    }
    _mutate((clips) => clips..addAll(newClips));
    unawaited(HapticFeedback.mediumImpact());
  }

  Future<void> _onNext() async {
    if (_clips.isEmpty) return;
    final activeClip = _clips.isNotEmpty ? _clips[_activeClipIndex] : null;
    debugPrint(
      '[ReelEditor] next tapped clipCount=${_clips.length} '
      'activeIndex=$_activeClipIndex '
      'activePath=${activeClip?.path ?? ''} '
      'activeType=${activeClip?.type.name ?? 'none'} '
      'previewSize=${_previewKey.currentContext?.size?.width ?? 0}x${_previewKey.currentContext?.size?.height ?? 0} '
      'playheadMs=$_playheadMs '
      'isPlaying=$_isPlaying',
    );
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ExportProgressDialog(),
    );
    try {
      final size = _previewKey.currentContext?.size ?? const Size(1080, 1920);
      final scaleFactor = 1080 / size.width;
      final clips = _clips.map((c) {
        final mediaText = _textOverlays.map((t) {
          return ReelTextOverlay(
            text: t.text,
            style: t.style,
            alignment: t.alignment,
            textColor: t.textColor,
            backgroundStyle: t.backgroundStyle,
            normalizedPosition: Offset(
              (t.position.dx / size.width).clamp(0.0, 1.0),
              (t.position.dy / size.height).clamp(0.0, 1.0),
            ),
            scale: t.scale,
            rotation: t.rotation,
            fontSize: t.fontSize * scaleFactor,
          );
        }).toList();
        final mediaStickers = _stickerOverlays.map((s) {
          return ReelStickerOverlay(
            imagePath: s.imagePath,
            shape: OverlayShape.none,
            normalizedPosition: Offset(
              (s.position.dx / size.width).clamp(0.0, 1.0),
              (s.position.dy / size.height).clamp(0.0, 1.0),
            ),
            scale: s.scale,
            rotation: s.rotation,
            baseSize: 120 * scaleFactor,
          );
        }).toList();
        return ReelClip(
          id: c.id,
          type: c.type,
          path: c.path,
          duration: c.duration,
          trimStart: c.trimStart,
          trimEnd: c.trimEnd,
          colorMatrix: c.colorMatrix,
          textOverlays: mediaText,
          stickerOverlays: mediaStickers,
          speed: c.speed,
          isReversed: c.isReversed,
          freezeAt: c.freezeAt,
          freezeDuration: c.freezeDuration,
          transitionIn: c.transitionIn,
          transitionInDurationMs: c.transitionInDurationMs,
          groupId: c.groupId,
          audioPath: _audioPath,
          audioVolume: _audioVolume,
          originalVolume: _originalVolume,
          voicePath: _voicePath,
          voiceVolume: _voiceVolume,
        );
      }).toList();
      final exportService = ReelExportService();
      final stitchedPath = await exportService.export(
        clips: clips,
        audioPath: _audioPath,
        audioVolume: _audioVolume,
        voicePath: _voicePath,
        voiceVolume: _voiceVolume,
        originalVolume: _originalVolume,
        captions: _captions,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // progress
      if (stitchedPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed, please try again')),
        );
        return;
      }
      debugPrint(
        '[ReelEditor] export complete stitchedPath=$stitchedPath '
        'fileExists=${File(stitchedPath).existsSync()}',
      );
      final media = app_models.MediaItem(
        id: 'reel_${DateTime.now().millisecondsSinceEpoch}',
        type: app_models.MediaType.video,
        filePath: stitchedPath,
        createdAt: DateTime.now(),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateReelDetailsScreen(media: media),
        ),
      );
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed, please try again')),
        );
      }
    }
  }

  Future<void> _saveDraft() async {
    final draft = ReelDraftData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      clipPaths: _clips.map((c) => c.path).toList(),
      audioPath: _audioPath,
      voicePath: _voicePath,
    );
    await ReelDraftService().saveDraft(draft);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeClip = _clips.isNotEmpty ? _clips[_activeClipIndex] : null;
    final size = MediaQuery.of(context).size;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final availableHeight = size.height - safeTop - safeBottom;
    final previewHeight = availableHeight * 0.70;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: previewHeight,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(child: _buildPreview(activeClip)),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: _buildTopBar(),
                  ),
                  Positioned(
                    right: 12,
                    top: 84,
                    child: _buildRightSidebar(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: const Color(0xFF1C1C1E),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 88,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: ValueListenableBuilder<double>(
                              valueListenable: _playheadMsNotifier,
                              builder: (context, ms, _) {
                                return ReelTimelineStrip(
                                  key: _timelineKey,
                                  clips: _clips,
                                  playheadMs: ms,
                                  totalDurationMs: _totalDurationMs,
                                  pxPerMs: _pxPerMs,
                                  selectedClipIndex: _selectedClipIndex,
                                  trimMode: _isTrimMode,
                                  onScrollOffsetChanged: (v) => setState(
                                    () => _timelineScrollOffset = v,
                                  ),
                                  onClipSelected: _onClipTap,
                                  onClipDoubleTap: _toggleClipSelection,
                                  onClipLongPress: (i) {
                                    setState(() {
                                      _selectedClipIndex = i;
                                      _isReorderMode = true;
                                    });
                                    _openClipContextMenu(i).whenComplete(() {
                                      if (mounted) {
                                        setState(() => _isReorderMode = false);
                                      }
                                    });
                                  },
                                  onClipReorder: (from, to) {
                                    setState(() => _isReorderMode = false);
                                    _reorderClip(from, to);
                                  },
                                  onClipTrimmed: (index, trimStart, trimEnd) {
                                    _mutate((clips) {
                                      final clip = clips[index];
                                      if (clip.type == ReelClipType.image) {
                                        clips[index] = clip.copyWith(
                                          duration: trimEnd,
                                          trimStart: Duration.zero,
                                          trimEnd: trimEnd,
                                        );
                                      } else {
                                        clips[index] = clip.copyWith(
                                          trimStart: trimStart,
                                          trimEnd: trimEnd,
                                        );
                                      }
                                      return clips;
                                    });
                                  },
                                  onPlayheadScrub: _onScrub,
                                  onScrubStart: _onScrubStart,
                                  onScrubEnd: _onScrubEnd,
                                  onZoomChanged: (v) =>
                                      setState(() => _pxPerMs = v),
                                  onAddClip: _onAddClip,
                                  overlaySpans: _overlaySpans(),
                                  onTransitionTap: _openTransitionPicker,
                                );
                              },
                            ),
                          ),
                          if (_showPlayheadTooltip)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable: _playheadMsNotifier,
                                      builder: (context, playheadMs, _) {
                                        final x = _playheadX(
                                          playheadMs,
                                          constraints.maxWidth,
                                        );
                                        return SizedBox.expand(
                                          child: Stack(
                                            children: [
                                              Positioned(
                                                left: x - 32,
                                                top: -18,
                                                child: Container(
                                                  width: 64,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xCC000000,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    _playheadLabel(playheadMs),
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          _buildTrackRow(
                            icon: Icons.music_note_outlined,
                            label: _audioPath == null
                                ? 'Tap to add audio'
                                : 'Audio added',
                            onTap: _openAudioPicker,
                            hasContent: _audioPath != null,
                            contentColor: Colors.amber,
                          ),
                          const SizedBox(height: 8),
                          _buildTrackRow(
                            icon: Icons.text_fields,
                            label: _textOverlays.isEmpty
                                ? 'Tap to add text'
                                : 'Text added',
                            onTap: _openTextEditor,
                            hasContent: _textOverlays.isNotEmpty,
                            contentColor: const Color(0xFF0095F6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFF2C2C2E)),
                    SizedBox(
                      height: 44,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildPlaybackRow(),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFF2C2C2E)),
                    SizedBox(
                      height: 68,
                      child: _buildBottomToolbar(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool hasContent = false,
    Color contentColor = const Color(0xFF2C2C2E),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (hasContent)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _miniWaveBar(color: contentColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        _bottomTool('Text', Icons.title, _openTextEditor),
        _bottomTool(
            'Sticker', Icons.emoji_emotions_outlined, _openStickerPicker),
        _bottomTool('Audio', Icons.music_note, _openAudioPicker),
        _bottomTool('Effects', Icons.auto_awesome, _openFilterPicker),
        _bottomTool('Photo', Icons.photo_outlined, _onAddClip),
        _bottomTool('Overlay', Icons.layers_outlined, () {}),
        _bottomTool('Caption', Icons.closed_caption_outlined, _openCaptions),
      ],
    );
  }

  Widget _bottomTool(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 76,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Material(
            color: const Color(0x99000000),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.chevron_left, color: Colors.white),
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          height: 36,
          child: Material(
            color: const Color(0xFF0095F6),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _onNext,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightSidebar() {
    return Column(
      children: [
        _rightTool(
          icon: _originalVolume <= 0.01 ? Icons.volume_off : Icons.volume_up,
          label: 'Mute',
          onTap: _toggleMute,
        ),
        const SizedBox(height: 16),
        _rightTool(
          icon: Icons.music_note,
          label: 'Music',
          onTap: _openAudioPicker,
        ),
        const SizedBox(height: 16),
        _rightTool(
          icon: Icons.speed,
          label: 'Speed',
          onTap: () {
            if (_clips.isEmpty) return;
            _openClipContextMenu(_activeClipIndex);
          },
        ),
        const SizedBox(height: 16),
        _rightTool(
          icon: Icons.auto_awesome,
          label: 'Effects',
          onTap: _openFilterPicker,
        ),
        const SizedBox(height: 16),
        _rightTool(
          icon: Icons.timer_outlined,
          label: 'Timer',
          onTap: () {},
        ),
      ],
    );
  }

  Widget _rightTool({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0x88000000),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackRow() {
    return Row(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Material(
            color: const Color(0xFF2C2C2E),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _togglePlayback,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: _clockNotifier,
              builder: (context, value, _) {
                return Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ),
        IconButton(
          onPressed: _history.canUndo ? _undo : null,
          icon: Icon(
            Icons.undo_rounded,
            color: _history.canUndo ? Colors.white : Colors.white24,
          ),
        ),
        IconButton(
          onPressed: _history.canRedo ? _redo : null,
          icon: Icon(
            Icons.redo_rounded,
            color: _history.canRedo ? Colors.white : Colors.white24,
          ),
        ),
      ],
    );
  }

  Widget _miniWaveBar({required Color color}) {
    return SizedBox(
      height: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          10,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 2,
              height: 4 + (i % 3) * 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleMute() {
    final next = _originalVolume <= 0.01 ? 1.0 : 0.0;
    setState(() => _originalVolume = next);
    _videoController?.setVolume(next.clamp(0.0, 1.0));
  }

  Future<void> _openAudioPicker() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReelAudioPickerScreen(
          initialAudioPath: _audioPath,
          initialVolume: _audioVolume,
          onSelect: (value) {
            setState(() {
              _audioPath = value.path;
              _audioVolume = value.volume;
            });
          },
        ),
      ),
    );
  }

  Widget _buildPreview(ReelClip? activeClip) {
    return Stack(
      key: _previewKey,
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.matrix(
            activeClip?.colorMatrix ?? _identityMatrix,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black),
              if (activeClip == null)
                const SizedBox.shrink()
              else if (activeClip.type == ReelClipType.video)
                (_videoController != null &&
                        _videoController!.value.isInitialized)
                    ? RepaintBoundary(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _videoController!.value.size.width,
                            height: _videoController!.value.size.height,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                      )
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
              else
                RepaintBoundary(
                  child: Image.file(
                    File(activeClip.path),
                    fit: BoxFit.cover,
                  ),
                ),
              ValueListenableBuilder<double>(
                valueListenable: _playheadMsNotifier,
                builder: (context, _, __) {
                  return SizedBox.expand(
                    child: Stack(
                      children: _buildOverlayWidgets(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: AnimatedOpacity(
            opacity: _showDeleteZone ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (_clips.isEmpty) return;
              setState(() {
                _isTrimMode = true;
                _selectedClipIndex = _activeClipIndex;
              });
              final ctrl = _videoController;
              if (ctrl != null && ctrl.value.isInitialized) {
                ctrl.pause();
                _stopPlayheadTimer();
                setState(() => _isPlaying = false);
              }
            },
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _toolPill(
    String label,
    IconData icon,
    ReelEditorMode mode, {
    VoidCallback? customOnTap,
  }) {
    final isActive = _mode == mode && mode != ReelEditorMode.idle;
    return GestureDetector(
      onTap: customOnTap ??
          () {
            if (mode == ReelEditorMode.addingText) {
              _openTextEditor();
              return;
            }
            if (mode == ReelEditorMode.addingSticker) {
              _openStickerPicker();
              return;
            }
            if (mode == ReelEditorMode.audioPanel) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReelAudioPickerScreen(
                    initialAudioPath: _audioPath,
                    initialVolume: _audioVolume,
                    onSelect: (value) {
                      setState(() {
                        _audioPath = value.path;
                        _audioVolume = value.volume;
                      });
                    },
                  ),
                ),
              );
              return;
            }
            if (mode == ReelEditorMode.voiceRecord) {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ReelVoiceRecorderSheet(
                  onConfirm: (value) {
                    setState(() => _voicePath = value.path);
                    Navigator.of(context).pop();
                  },
                ),
              );
              return;
            }
            if (mode == ReelEditorMode.volumePanel) {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => ReelVolumePanel(
                  musicVolume: _audioVolume,
                  voiceVolume: _voiceVolume,
                  originalVolume: _originalVolume,
                  onChanged: (v) {
                    setState(() {
                      _audioVolume = v.music;
                      _voiceVolume = v.voice;
                      _originalVolume = v.original;
                    });
                  },
                ),
              );
              return;
            }
            _setMode(mode);
          },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0095F6).withValues(alpha: 0.2)
              : Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: const Color(0xFF0095F6), width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF0095F6) : Colors.white,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF0095F6) : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolPillAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Future<void> _openCaptions() async {
    if (_clips.isEmpty) return;
    final clip = _clips[_activeClipIndex];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReelCaptionScreen(
          videoPath: clip.path,
          initialCaptions: _captions,
          onSave: (caps) => _captions = caps,
        ),
      ),
    );
  }

  Future<void> _openClipContextMenu(int index) async {
    if (index < 0 || index >= _clips.length) return;
    final groupId = _clips[index].groupId;
    if (groupId != null) {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _GroupedClipMenu(
          onUngroup: () {
            Navigator.of(context).pop();
            _ungroup(groupId);
          },
          onSplit: () {
            Navigator.of(context).pop();
            _splitAtPlayhead();
          },
          onDuplicate: () {
            Navigator.of(context).pop();
            _duplicateClip(index);
          },
          onReplace: (media) {
            Navigator.of(context).pop();
            _replaceClip(index, media);
          },
          onSpeedChanged: (speed) => _setClipSpeed(index, speed),
          onReverse: () {
            Navigator.of(context).pop();
            _reverseClip(index);
          },
          onFreeze: () {
            Navigator.of(context).pop();
            _freezeFrameAtPlayhead();
          },
          onDelete: () {
            Navigator.of(context).pop();
            _deleteClip(index);
          },
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelClipContextMenu(
        clip: _clips[index],
        onSplit: () {
          Navigator.of(context).pop();
          _splitAtPlayhead();
        },
        onDuplicate: () {
          Navigator.of(context).pop();
          _duplicateClip(index);
        },
        onReplace: (media) {
          Navigator.of(context).pop();
          _replaceClip(index, media);
        },
        onSpeedChanged: (speed) {
          _setClipSpeed(index, speed);
        },
        onReverse: () {
          Navigator.of(context).pop();
          _reverseClip(index);
        },
        onFreeze: () {
          Navigator.of(context).pop();
          _freezeFrameAtPlayhead();
        },
        onDelete: () {
          Navigator.of(context).pop();
          _deleteClip(index);
        },
      ),
    );
  }

  Future<void> _openTransitionPicker(int index) async {
    if (index < 0 || index >= _clips.length) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelTransitionPicker(
        initialType: _clips[index].transitionIn ?? 'none',
        initialDurationMs: _clips[index].transitionInDurationMs,
        onApply: (type, durationMs) {
          Navigator.of(context).pop();
          _setClipTransition(index, type, durationMs);
        },
      ),
    );
  }

  Future<void> _replaceClip(int index, app_models.MediaItem media) async {
    if (index < 0 || index >= _clips.length) return;
    final isVideo = media.type == app_models.MediaType.video;
    final duration = isVideo
        ? (media.duration ?? const Duration(seconds: 1))
        : const Duration(seconds: 3);
    _mutate((clips) {
      final existing = clips[index];
      clips[index] = ReelClip(
        id: _newClipId(existing.id),
        type: isVideo ? ReelClipType.video : ReelClipType.image,
        path: media.filePath ?? '',
        duration: duration,
        trimStart: null,
        trimEnd: null,
        colorMatrix: existing.colorMatrix,
        textOverlays: existing.textOverlays,
        stickerOverlays: existing.stickerOverlays,
        speed: existing.speed,
        isReversed: existing.isReversed,
        freezeAt: existing.freezeAt,
        freezeDuration: existing.freezeDuration,
        transitionIn: existing.transitionIn,
        transitionInDurationMs: existing.transitionInDurationMs,
        groupId: existing.groupId,
        audioPath: existing.audioPath,
        audioVolume: existing.audioVolume,
        originalVolume: existing.originalVolume,
        voicePath: existing.voicePath,
        voiceVolume: existing.voiceVolume,
      );
      return clips;
    });
  }

  List<Widget> _buildOverlayWidgets() {
    final widgets = <Widget>[];
    for (int i = 0; i < _textOverlays.length; i++) {
      final t = _textOverlays[i];
      if (_playheadMs < t.startMs || _playheadMs >= t.endMs) continue;
      widgets.add(_DraggableTextOverlay(
        key: ObjectKey(t),
        overlay: t,
        globalToPreview: _globalToPreview,
        trashCenter: _trashCenter,
        onDeleteZoneChanged: _setDeleteZoneVisible,
        onTap: () => setState(() => _activeTextIndex = i),
        onLongPress: () => _openOverlayDurationSheet(
          startMs: t.startMs,
          endMs: t.endMs,
          onApply: (s, e) {
            final idx = _textOverlays.indexOf(t);
            if (idx < 0) return;
            setState(
                () => _textOverlays[idx] = t.copyWith(startMs: s, endMs: e));
          },
        ),
        onMoved: (pos, scale, rotation) {
          final idx = _textOverlays.indexOf(t);
          if (idx < 0) return;
          setState(() {
            _textOverlays[idx] = t.copyWith(
              position: pos,
              scale: scale,
              rotation: rotation,
            );
          });
        },
        onDelete: () {
          final idx = _textOverlays.indexOf(t);
          if (idx < 0) return;
          setState(() => _textOverlays.removeAt(idx));
        },
        child: _buildTextVisual(t),
      ));
    }

    for (int i = 0; i < _stickerOverlays.length; i++) {
      final s = _stickerOverlays[i];
      if (_playheadMs < s.startMs || _playheadMs >= s.endMs) continue;
      widgets.add(_DraggableStickerOverlay(
        key: ObjectKey(s),
        overlay: s,
        globalToPreview: _globalToPreview,
        trashCenter: _trashCenter,
        onDeleteZoneChanged: _setDeleteZoneVisible,
        onTap: () => setState(() => _activeStickerIndex = i),
        onLongPress: () => _openOverlayDurationSheet(
          startMs: s.startMs,
          endMs: s.endMs,
          onApply: (st, en) {
            final idx = _stickerOverlays.indexOf(s);
            if (idx < 0) return;
            setState(() =>
                _stickerOverlays[idx] = s.copyWith(startMs: st, endMs: en));
          },
        ),
        onMoved: (pos, scale, rotation) {
          final idx = _stickerOverlays.indexOf(s);
          if (idx < 0) return;
          setState(() {
            _stickerOverlays[idx] = s.copyWith(
              position: pos,
              scale: scale,
              rotation: rotation,
            );
          });
        },
        onDelete: () {
          final idx = _stickerOverlays.indexOf(s);
          if (idx < 0) return;
          setState(() => _stickerOverlays.removeAt(idx));
        },
        child: Image.file(
          File(s.imagePath),
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      ));
    }
    return widgets;
  }

  Widget _buildTextVisual(ReelEditorTextOverlay overlay) {
    final baseStyle = overlay.style.copyWith(
      color: overlay.textColor,
      fontSize: overlay.fontSize,
    );
    Widget content = Text(
      overlay.text,
      textAlign: overlay.alignment,
      style: baseStyle,
    );
    if (overlay.backgroundStyle == BackgroundStyle.solid ||
        overlay.backgroundStyle == BackgroundStyle.transparent) {
      final bgColor = overlay.backgroundStyle == BackgroundStyle.solid
          ? overlay.textColor.withValues(alpha: 0.9)
          : overlay.textColor.withValues(alpha: 0.35);
      final fgColor = overlay.backgroundStyle == BackgroundStyle.solid
          ? Colors.black
          : overlay.textColor;
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: DefaultTextStyle.merge(
          style: baseStyle.copyWith(color: fgColor),
          child: content,
        ),
      );
    }
    return content;
  }

  List<({double startMs, double endMs, Color color})> _overlaySpans() {
    final spans = <({double startMs, double endMs, Color color})>[];
    for (final t in _textOverlays) {
      spans.add(
          (startMs: t.startMs, endMs: t.endMs, color: const Color(0xFF0095F6)));
    }
    for (final s in _stickerOverlays) {
      spans.add((startMs: s.startMs, endMs: s.endMs, color: Colors.white54));
    }
    if (_audioPath != null) {
      spans.add((startMs: 0, endMs: _totalDurationMs, color: Colors.amber));
    }
    if (_voicePath != null) {
      spans.add((
        startMs: 0,
        endMs: _totalDurationMs,
        color: const Color(0xFF0095F6)
      ));
    }
    return spans;
  }

  double _timelineTrackWidth() {
    const tileGap = 8.0;
    const dotSlot = 16.0;
    double width = 0;
    for (int i = 0; i < _clips.length; i++) {
      width += (_clipEffectiveDurationMs(_clips[i]) * _pxPerMs)
          .clamp(48.0, double.infinity);
      if (i != _clips.length - 1) {
        width += tileGap + dotSlot + tileGap;
      }
    }
    if (_clips.isNotEmpty) width += tileGap;
    return width;
  }

  double _playheadX(double playheadMs, double maxWidth) {
    const leftPad = 16.0;
    final totalMs = _totalDurationMs <= 0 ? 1.0 : _totalDurationMs;
    final trackWidth = _timelineTrackWidth();
    final raw =
        leftPad + (playheadMs / totalMs) * trackWidth - _timelineScrollOffset;
    final clamped = raw.clamp(12.0, maxWidth - 12.0);
    return clamped.toDouble();
  }

  String _playheadLabel(double playheadMs) {
    final totalSeconds = playheadMs / 1000.0;
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60);
    return '$minutes:${seconds.toStringAsFixed(1).padLeft(4, '0')}';
  }

  String _formatClock(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  void _toggleClipSelection(int index) {
    if (index < 0 || index >= _clips.length) return;
    final id = _clips[index].id;
    setState(() {
      if (_selectedClipIds.contains(id)) {
        _selectedClipIds.remove(id);
      } else {
        _selectedClipIds.add(id);
      }
    });
  }

  void _groupSelectedClips() {
    if (_selectedClipIds.length < 2) return;
    final groupId = _newGroupId();
    _mutate((clips) {
      for (int i = 0; i < clips.length; i++) {
        final clip = clips[i];
        if (_selectedClipIds.contains(clip.id)) {
          clips[i] = ReelClip(
            id: clip.id,
            type: clip.type,
            path: clip.path,
            duration: clip.duration,
            trimStart: clip.trimStart,
            trimEnd: clip.trimEnd,
            colorMatrix: clip.colorMatrix,
            textOverlays: clip.textOverlays,
            stickerOverlays: clip.stickerOverlays,
            speed: clip.speed,
            isReversed: clip.isReversed,
            freezeAt: clip.freezeAt,
            freezeDuration: clip.freezeDuration,
            transitionIn: clip.transitionIn,
            transitionInDurationMs: clip.transitionInDurationMs,
            groupId: groupId,
            audioPath: clip.audioPath,
            audioVolume: clip.audioVolume,
            originalVolume: clip.originalVolume,
            voicePath: clip.voicePath,
            voiceVolume: clip.voiceVolume,
          );
        }
      }
      return clips;
    });
    setState(() => _selectedClipIds.clear());
  }

  void _clearGroupSelection() {
    setState(() => _selectedClipIds.clear());
  }

  void _ungroup(String groupId) {
    _mutate((clips) {
      for (int i = 0; i < clips.length; i++) {
        final clip = clips[i];
        if (clip.groupId == groupId) {
          clips[i] = ReelClip(
            id: clip.id,
            type: clip.type,
            path: clip.path,
            duration: clip.duration,
            trimStart: clip.trimStart,
            trimEnd: clip.trimEnd,
            colorMatrix: clip.colorMatrix,
            textOverlays: clip.textOverlays,
            stickerOverlays: clip.stickerOverlays,
            speed: clip.speed,
            isReversed: clip.isReversed,
            freezeAt: clip.freezeAt,
            freezeDuration: clip.freezeDuration,
            transitionIn: clip.transitionIn,
            transitionInDurationMs: clip.transitionInDurationMs,
            groupId: null,
            audioPath: clip.audioPath,
            audioVolume: clip.audioVolume,
            originalVolume: clip.originalVolume,
            voicePath: clip.voicePath,
            voiceVolume: clip.voiceVolume,
          );
        }
      }
      return clips;
    });
  }
}

class _FilterChipThumb extends StatefulWidget {
  final ReelClip clip;

  const _FilterChipThumb({
    required this.clip,
  });

  @override
  State<_FilterChipThumb> createState() => _FilterChipThumbState();
}

class _FilterChipThumbState extends State<_FilterChipThumb> {
  Uint8List? _thumb;
  String? _forPath;

  Future<void> _load() async {
    if (widget.clip.type != ReelClipType.video) return;
    if (_forPath == widget.clip.path && _thumb != null) return;
    _forPath = widget.clip.path;
    _thumb = null;
    final data = await VideoThumbnail.thumbnailData(
      video: widget.clip.path,
      imageFormat: ImageFormat.JPEG,
      quality: 60,
      timeMs: 0,
    );
    if (!mounted) return;
    if (_forPath != widget.clip.path) return;
    setState(() => _thumb = data);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _FilterChipThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.path != widget.clip.path ||
        oldWidget.clip.type != widget.clip.type) {
      unawaited(_load());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clip.type == ReelClipType.image) {
      return Image.file(
        File(widget.clip.path),
        fit: BoxFit.cover,
      );
    }
    final data = _thumb;
    if (data == null) {
      return Container(color: Colors.grey[850]);
    }
    return Image.memory(
      data,
      fit: BoxFit.cover,
      gaplessPlayback: true,
    );
  }
}

class ReelEditorTextOverlay {
  final String text;
  final TextStyle style;
  final TextAlign alignment;
  final Color textColor;
  final BackgroundStyle backgroundStyle;
  final Offset position;
  final double scale;
  final double rotation;
  final double fontSize;
  final double startMs;
  final double endMs;

  const ReelEditorTextOverlay({
    required this.text,
    required this.style,
    required this.alignment,
    required this.textColor,
    required this.backgroundStyle,
    required this.position,
    required this.scale,
    required this.rotation,
    required this.fontSize,
    required this.startMs,
    required this.endMs,
  });

  ReelEditorTextOverlay copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    double? startMs,
    double? endMs,
  }) {
    return ReelEditorTextOverlay(
      text: text,
      style: style,
      alignment: alignment,
      textColor: textColor,
      backgroundStyle: backgroundStyle,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      fontSize: fontSize,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }
}

class _DraggableTextOverlay extends StatefulWidget {
  final ReelEditorTextOverlay overlay;
  final Widget child;
  final Offset Function(Offset global) globalToPreview;
  final Offset Function() trashCenter;
  final ValueChanged<bool> onDeleteZoneChanged;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(Offset pos, double scale, double rotation) onMoved;
  final VoidCallback onDelete;

  const _DraggableTextOverlay({
    super.key,
    required this.overlay,
    required this.child,
    required this.globalToPreview,
    required this.trashCenter,
    required this.onDeleteZoneChanged,
    required this.onTap,
    required this.onLongPress,
    required this.onMoved,
    required this.onDelete,
  });

  @override
  State<_DraggableTextOverlay> createState() => _DraggableTextOverlayState();
}

class _DraggableTextOverlayState extends State<_DraggableTextOverlay> {
  Offset _localPosition = Offset.zero;
  double _localScale = 1.0;
  double _localRotation = 0.0;

  Offset _basePosition = Offset.zero;
  double _baseScale = 1.0;
  double _baseRotation = 0.0;
  Offset _lastFocalPoint = Offset.zero;
  bool _gestureActive = false;

  @override
  void initState() {
    super.initState();
    _syncFromOverlay(widget.overlay);
  }

  @override
  void didUpdateWidget(covariant _DraggableTextOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_gestureActive) return;
    if (oldWidget.overlay != widget.overlay) {
      _syncFromOverlay(widget.overlay);
    }
  }

  void _syncFromOverlay(ReelEditorTextOverlay overlay) {
    _localPosition = overlay.position;
    _localScale = overlay.scale;
    _localRotation = overlay.rotation;
    _basePosition = _localPosition;
    _baseScale = _localScale;
    _baseRotation = _localRotation;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gestureActive = true;
    widget.onDeleteZoneChanged(true);
    _lastFocalPoint = widget.globalToPreview(d.focalPoint);
    _basePosition = _localPosition;
    _baseScale = _localScale;
    _baseRotation = _localRotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final local = widget.globalToPreview(d.focalPoint);
    final delta = local - _lastFocalPoint;
    setState(() {
      _localPosition = _basePosition + delta;
      _localScale = (_baseScale * d.scale).clamp(0.2, 6.0);
      _localRotation = _baseRotation + d.rotation;
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _gestureActive = false;
    final center = widget.trashCenter();
    final distance = (center - _localPosition).distance;
    if (distance <= 44) {
      widget.onDelete();
    } else {
      widget.onMoved(_localPosition, _localScale, _localRotation);
    }
    widget.onDeleteZoneChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _localPosition.dx,
      top: _localPosition.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Transform.rotate(
          angle: _localRotation,
          child: Transform.scale(
            scale: _localScale,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class ReelEditorStickerOverlay {
  final String imagePath;
  final Offset position;
  final double scale;
  final double rotation;
  final double startMs;
  final double endMs;

  const ReelEditorStickerOverlay({
    required this.imagePath,
    required this.position,
    required this.scale,
    required this.rotation,
    required this.startMs,
    required this.endMs,
  });

  ReelEditorStickerOverlay copyWith({
    Offset? position,
    double? scale,
    double? rotation,
    double? startMs,
    double? endMs,
  }) {
    return ReelEditorStickerOverlay(
      imagePath: imagePath,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }
}

class _DraggableStickerOverlay extends StatefulWidget {
  final ReelEditorStickerOverlay overlay;
  final Widget child;
  final Offset Function(Offset global) globalToPreview;
  final Offset Function() trashCenter;
  final ValueChanged<bool> onDeleteZoneChanged;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(Offset pos, double scale, double rotation) onMoved;
  final VoidCallback onDelete;

  const _DraggableStickerOverlay({
    super.key,
    required this.overlay,
    required this.child,
    required this.globalToPreview,
    required this.trashCenter,
    required this.onDeleteZoneChanged,
    required this.onTap,
    required this.onLongPress,
    required this.onMoved,
    required this.onDelete,
  });

  @override
  State<_DraggableStickerOverlay> createState() =>
      _DraggableStickerOverlayState();
}

class _DraggableStickerOverlayState extends State<_DraggableStickerOverlay> {
  Offset _localPosition = Offset.zero;
  double _localScale = 1.0;
  double _localRotation = 0.0;

  Offset _basePosition = Offset.zero;
  double _baseScale = 1.0;
  double _baseRotation = 0.0;
  Offset _lastFocalPoint = Offset.zero;
  bool _gestureActive = false;

  @override
  void initState() {
    super.initState();
    _syncFromOverlay(widget.overlay);
  }

  @override
  void didUpdateWidget(covariant _DraggableStickerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_gestureActive) return;
    if (oldWidget.overlay != widget.overlay) {
      _syncFromOverlay(widget.overlay);
    }
  }

  void _syncFromOverlay(ReelEditorStickerOverlay overlay) {
    _localPosition = overlay.position;
    _localScale = overlay.scale;
    _localRotation = overlay.rotation;
    _basePosition = _localPosition;
    _baseScale = _localScale;
    _baseRotation = _localRotation;
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gestureActive = true;
    widget.onDeleteZoneChanged(true);
    _lastFocalPoint = widget.globalToPreview(d.focalPoint);
    _basePosition = _localPosition;
    _baseScale = _localScale;
    _baseRotation = _localRotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final local = widget.globalToPreview(d.focalPoint);
    final delta = local - _lastFocalPoint;
    setState(() {
      _localPosition = _basePosition + delta;
      _localScale = (_baseScale * d.scale).clamp(0.2, 6.0);
      _localRotation = _baseRotation + d.rotation;
    });
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _gestureActive = false;
    final center = widget.trashCenter();
    final distance = (center - _localPosition).distance;
    if (distance <= 44) {
      widget.onDelete();
    } else {
      widget.onMoved(_localPosition, _localScale, _localRotation);
    }
    widget.onDeleteZoneChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _localPosition.dx,
      top: _localPosition.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Transform.rotate(
          angle: _localRotation,
          child: Transform.scale(
            scale: _localScale,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ExportProgressDialog extends StatelessWidget {
  const _ExportProgressDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: const [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Preparing your reel…',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupedClipMenu extends StatefulWidget {
  final VoidCallback onUngroup;
  final VoidCallback onSplit;
  final VoidCallback onDuplicate;
  final ValueChanged<app_models.MediaItem> onReplace;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onReverse;
  final VoidCallback onFreeze;
  final VoidCallback onDelete;

  const _GroupedClipMenu({
    required this.onUngroup,
    required this.onSplit,
    required this.onDuplicate,
    required this.onReplace,
    required this.onSpeedChanged,
    required this.onReverse,
    required this.onFreeze,
    required this.onDelete,
  });

  @override
  State<_GroupedClipMenu> createState() => _GroupedClipMenuState();
}

class _GroupedClipMenuState extends State<_GroupedClipMenu> {
  bool _showSpeed = false;
  bool _confirmDelete = false;
  double _speed = 1.0;

  Future<void> _pickReplacement() async {
    final picker = ImagePicker();
    final picked = await picker.pickMedia();
    if (picked == null) return;
    final isVideo = picked.mimeType?.startsWith('video') ??
        picked.path.toLowerCase().endsWith('.mp4');
    Duration? duration;
    if (isVideo) {
      final controller = VideoPlayerController.file(File(picked.path));
      await controller.initialize();
      duration = controller.value.duration;
      await controller.dispose();
    }
    final media = app_models.MediaItem(
      id: 'replace_${DateTime.now().millisecondsSinceEpoch}',
      type: isVideo ? app_models.MediaType.video : app_models.MediaType.image,
      filePath: picked.path,
      duration: duration,
      createdAt: DateTime.now(),
    );
    widget.onReplace(media);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 84,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _pill('Ungroup', Icons.link_off, onTap: widget.onUngroup),
                  const SizedBox(width: 8),
                  _pill('Split', Icons.call_split, onTap: widget.onSplit),
                  const SizedBox(width: 8),
                  _pill('Duplicate', Icons.copy, onTap: widget.onDuplicate),
                  const SizedBox(width: 8),
                  _pill('Replace', Icons.swap_horiz, onTap: _pickReplacement),
                  const SizedBox(width: 8),
                  _pill('Speed', Icons.speed,
                      onTap: () => setState(() => _showSpeed = !_showSpeed)),
                  const SizedBox(width: 8),
                  _pill('Reverse', Icons.replay, onTap: widget.onReverse),
                  const SizedBox(width: 8),
                  _pill('Freeze', Icons.pause_circle_outline,
                      onTap: widget.onFreeze),
                  const SizedBox(width: 8),
                  _pill(
                    'Delete',
                    Icons.delete_outline,
                    onTap: () => setState(() => _confirmDelete = true),
                    color: const Color(0xFFFF3B30),
                  ),
                ],
              ),
            ),
          ),
          if (_showSpeed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  const Text('0.1x',
                      style: TextStyle(color: Colors.white, fontSize: 11)),
                  Expanded(
                    child: Slider(
                      value: _speed.clamp(0.1, 4.0),
                      min: 0.1,
                      max: 4.0,
                      divisions: 39,
                      onChanged: (v) {
                        setState(() => _speed = v);
                        widget.onSpeedChanged(v);
                      },
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Text('${_speed.toStringAsFixed(1)}x',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          if (_confirmDelete)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: widget.onDelete,
                    child: const Text('Delete clip',
                        style: TextStyle(color: Color(0xFFFF3B30))),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _confirmDelete = false),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon,
      {required VoidCallback onTap, Color? color}) {
    final tint = color ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: tint, size: 14),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: tint, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
