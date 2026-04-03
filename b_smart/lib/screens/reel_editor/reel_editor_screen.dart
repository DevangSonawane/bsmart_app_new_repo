import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/reel_timeline/reel_timeline_models.dart';
import '../../models/media_model.dart' as app_models;
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
  late List<ReelClip> _clips;
  int _activeClipIndex = 0;
  double _playheadMs = 0.0;
  bool _isPlaying = false;
  VideoPlayerController? _videoController;
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
  Offset _lastFocalPoint = Offset.zero;
  double _baseScale = 1.0;
  double _baseRotation = 0.0;
  Offset _basePosition = Offset.zero;
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

  @override
  void initState() {
    super.initState();
    _clips = widget.initialMedia.map((m) {
      final isVideo = m.type == app_models.MediaType.video;
        return ReelClip(
          id: m.id,
          type: isVideo ? ReelClipType.video : ReelClipType.image,
          path: m.filePath ?? '',
          duration: isVideo ? (m.duration ?? const Duration(seconds: 1)) : const Duration(seconds: 3),
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
    _videoController?.dispose();
    super.dispose();
  }

  void _initControllerForActiveClip() {
    _videoController?.dispose();
    _videoController = null;
    if (_clips.isEmpty) return;
    final clip = _clips[_activeClipIndex];
    if (clip.type != ReelClipType.video || clip.path.isEmpty) return;
    final controller = VideoPlayerController.file(File(clip.path));
    _videoController = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller.setLooping(true);
      if (_isPlaying) {
        controller.play();
      }
      setState(() {});
    });
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
        _playheadMs = 0;
      } else {
        if (_activeClipIndex >= _clips.length) {
          _activeClipIndex = _clips.length - 1;
        }
        if (_selectedClipIndex != null && _selectedClipIndex! >= _clips.length) {
          _selectedClipIndex = null;
        }
      }
    });
    _history.push(next);
    _initControllerForActiveClip();
  }

  void _undo() {
    if (!_history.canUndo) return;
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
    final localTimelineMs = (_playheadMs - clipStartMs).clamp(0.0, _clipEffectiveDurationMs(clip));
    final localSourceMs = localTimelineMs * (clip.speed <= 0 ? 1.0 : clip.speed);
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
    setState(() {
      _playheadMs = ms.clamp(0.0, _totalDurationMs);
    });
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
    _initControllerForActiveClip();
  }

  void _onAddClip() {
    // Hooked up in later phase.
  }

  Future<void> _onNext() async {
    if (_clips.isEmpty) return;
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final previewHeight = screenHeight * 0.52;
    final topBarHeight = 56.0;
    final timelineHeight = 100.0;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SizedBox(
            height: safeTop + topBarHeight,
            child: Padding(
              padding: EdgeInsets.only(top: safeTop, left: 12, right: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Material(
                      color: Colors.grey[800],
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).pop(),
                        child: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Material(
                      color: Colors.blue,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _onNext,
                        child: const Icon(Icons.arrow_forward, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  SizedBox(
                    width: screenWidth,
                    height: previewHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          key: _previewKey,
                          fit: StackFit.expand,
                          children: [
                            Container(color: Colors.black),
                            if (activeClip == null)
                              const SizedBox.shrink()
                            else if (activeClip.type == ReelClipType.video)
                              (_videoController != null &&
                                      _videoController!.value.isInitialized)
                                  ? FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: _videoController!.value.size.width,
                                        height: _videoController!.value.size.height,
                                        child: VideoPlayer(_videoController!),
                                      ),
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                            else
                              Image.file(
                                File(activeClip.path),
                                fit: BoxFit.cover,
                                width: screenWidth,
                                height: previewHeight,
                              ),
                            ..._buildOverlayWidgets(),
                            if (_showDeleteZone)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 24,
                                child: Center(
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
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
                            Positioned.fill(
                              child: GestureDetector(
                                onTap: () {
                                  if (_clips.isEmpty) return;
                                  setState(() {
                                    _isTrimMode = true;
                                    _selectedClipIndex = _activeClipIndex;
                                    final ctrl = _videoController;
                                    if (ctrl != null && ctrl.value.isInitialized) {
                                      ctrl.pause();
                                      _isPlaying = false;
                                    }
                                  });
                                },
                                behavior: HitTestBehavior.translucent,
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: Material(
                            color: Colors.grey[850],
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                final ctrl = _videoController;
                                if (ctrl == null || !ctrl.value.isInitialized) return;
                                setState(() {
                                  if (ctrl.value.isPlaying) {
                                    ctrl.pause();
                                    _isPlaying = false;
                                  } else {
                                    ctrl.play();
                                    _isPlaying = true;
                                  }
                                });
                              },
                              child: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _videoController ?? Listenable.merge(const []),
                              builder: (context, _) {
                                final ctrl = _videoController;
                                final position = ctrl?.value.position ?? Duration.zero;
                                final duration = ctrl?.value.duration ?? Duration.zero;
                                return Text(
                                  '${_formatClock(position)} / ${_formatClock(duration)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Material(
                            color: Colors.grey[850],
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _history.canUndo ? _undo : null,
                              child: Icon(Icons.undo_rounded,
                                  color: _history.canUndo
                                      ? Colors.white
                                      : Colors.white24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Material(
                            color: Colors.grey[850],
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _history.canRedo ? _redo : null,
                              child: Icon(Icons.redo_rounded,
                                  color: _history.canRedo
                                      ? Colors.white
                                      : Colors.white24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: timelineHeight,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final playheadX = _playheadX(constraints.maxWidth);
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: ReelTimelineStrip(
                                key: _timelineKey,
                                clips: _clips,
                                playheadMs: _playheadMs,
                                totalDurationMs: _totalDurationMs,
                                pxPerMs: _pxPerMs,
                                selectedClipIndex: _selectedClipIndex,
                                trimMode: _isTrimMode,
                                onScrollOffsetChanged: (v) =>
                                    setState(() => _timelineScrollOffset = v),
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
                                onZoomChanged: (v) => setState(() => _pxPerMs = v),
                                onAddClip: _onAddClip,
                                overlaySpans: _overlaySpans(),
                                onTransitionTap: _openTransitionPicker,
                              ),
                            ),
                            Positioned(
                              left: (playheadX - 28)
                                  .clamp(0.0, constraints.maxWidth - 56),
                              top: 2,
                              child: AnimatedOpacity(
                                opacity: _showPlayheadTooltip ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 150),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _playheadLabel(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  _buildTrackRow(
                    icon: Icons.music_note_outlined,
                    label: 'Tap to add audio',
                    onTap: () => _setMode(ReelEditorMode.audioPanel),
                  ),
                  _buildTrackRow(
                    icon: Icons.text_fields,
                    label: 'Tap to add text',
                    onTap: _openTextEditor,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Tap on a track to trim. Pinch to zoom.',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          SizedBox(
            height: 72 + safeBottom,
            child: Padding(
              padding: EdgeInsets.only(bottom: safeBottom),
              child: _buildBottomToolbar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _bottomTool('Text', Icons.title, _openTextEditor),
          _bottomTool('Sticker', Icons.emoji_emotions_outlined, _openStickerPicker),
          _bottomTool('Audio', Icons.music_note_outlined, () => _setMode(ReelEditorMode.audioPanel)),
          _bottomTool('Add clips', Icons.video_library_outlined, _onAddClip),
          _bottomTool('Overlay', Icons.layers_outlined, () {}),
          _bottomTool('Edit', Icons.edit_outlined, () {}),
          _bottomTool('Caption', Icons.closed_caption_outlined, _openCaptions),
        ],
      ),
    );
  }

  Widget _bottomTool(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 64,
      height: 56,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
          border: isActive ? Border.all(color: const Color(0xFF0095F6), width: 1.5) : null,
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
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
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
    final duration = isVideo ? (media.duration ?? const Duration(seconds: 1)) : const Duration(seconds: 3);
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
      widgets.add(
        Positioned(
          left: t.position.dx,
          top: t.position.dy,
          child: GestureDetector(
            onTap: () => setState(() => _activeTextIndex = i),
            onLongPress: () => _openOverlayDurationSheet(
              startMs: t.startMs,
              endMs: t.endMs,
              onApply: (s, e) => setState(() => _textOverlays[i] = t.copyWith(startMs: s, endMs: e)),
            ),
            onScaleStart: (d) {
              setState(() {
                _showDeleteZone = true;
                _activeTextIndex = i;
              });
              _lastFocalPoint = _globalToPreview(d.focalPoint);
              _baseScale = t.scale;
              _baseRotation = t.rotation;
              _basePosition = t.position;
            },
            onScaleUpdate: (d) {
              final local = _globalToPreview(d.focalPoint);
              final delta = local - _lastFocalPoint;
              setState(() {
                _textOverlays[i] = t.copyWith(
                  position: _basePosition + delta,
                  scale: (_baseScale * d.scale).clamp(0.2, 6.0),
                  rotation: _baseRotation + d.rotation,
                );
              });
            },
            onScaleEnd: (_) {
              final center = _trashCenter();
              final distance = (center - _textOverlays[i].position).distance;
              if (distance <= 44) {
                setState(() => _textOverlays.removeAt(i));
              }
              setState(() => _showDeleteZone = false);
            },
            child: Transform.rotate(
              angle: t.rotation,
              child: Transform.scale(
                scale: t.scale,
                child: _buildTextVisual(t),
              ),
            ),
          ),
        ),
      );
    }

    for (int i = 0; i < _stickerOverlays.length; i++) {
      final s = _stickerOverlays[i];
      if (_playheadMs < s.startMs || _playheadMs >= s.endMs) continue;
      widgets.add(
        Positioned(
          left: s.position.dx,
          top: s.position.dy,
          child: GestureDetector(
            onTap: () => setState(() => _activeStickerIndex = i),
            onLongPress: () => _openOverlayDurationSheet(
              startMs: s.startMs,
              endMs: s.endMs,
              onApply: (st, en) => setState(() => _stickerOverlays[i] = s.copyWith(startMs: st, endMs: en)),
            ),
            onScaleStart: (d) {
              setState(() {
                _showDeleteZone = true;
                _activeStickerIndex = i;
              });
              _lastFocalPoint = _globalToPreview(d.focalPoint);
              _baseScale = s.scale;
              _baseRotation = s.rotation;
              _basePosition = s.position;
            },
            onScaleUpdate: (d) {
              final local = _globalToPreview(d.focalPoint);
              final delta = local - _lastFocalPoint;
              setState(() {
                _stickerOverlays[i] = s.copyWith(
                  position: _basePosition + delta,
                  scale: (_baseScale * d.scale).clamp(0.2, 6.0),
                  rotation: _baseRotation + d.rotation,
                );
              });
            },
            onScaleEnd: (_) {
              final center = _trashCenter();
              final distance = (center - _stickerOverlays[i].position).distance;
              if (distance <= 44) {
                setState(() => _stickerOverlays.removeAt(i));
              }
              setState(() => _showDeleteZone = false);
            },
            child: Transform.rotate(
              angle: s.rotation,
              child: Transform.scale(
                scale: s.scale,
                child: Image.file(
                  File(s.imagePath),
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      );
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
      spans.add((startMs: t.startMs, endMs: t.endMs, color: const Color(0xFF0095F6)));
    }
    for (final s in _stickerOverlays) {
      spans.add((startMs: s.startMs, endMs: s.endMs, color: Colors.white54));
    }
    if (_audioPath != null) {
      spans.add((startMs: 0, endMs: _totalDurationMs, color: Colors.amber));
    }
    if (_voicePath != null) {
      spans.add((startMs: 0, endMs: _totalDurationMs, color: const Color(0xFF0095F6)));
    }
    return spans;
  }

  double _timelineTrackWidth() {
    const tileGap = 8.0;
    const dotSlot = 16.0;
    double width = 0;
    for (int i = 0; i < _clips.length; i++) {
      width += (_clipEffectiveDurationMs(_clips[i]) * _pxPerMs).clamp(48.0, double.infinity);
      if (i != _clips.length - 1) {
        width += tileGap + dotSlot + tileGap;
      }
    }
    if (_clips.isNotEmpty) width += tileGap;
    return width;
  }

  double _playheadX(double maxWidth) {
    const leftPad = 16.0;
    final totalMs = _totalDurationMs <= 0 ? 1.0 : _totalDurationMs;
    final trackWidth = _timelineTrackWidth();
    final raw = leftPad + (_playheadMs / totalMs) * trackWidth - _timelineScrollOffset;
    final clamped = raw.clamp(12.0, maxWidth - 12.0);
    return clamped.toDouble();
  }

  String _playheadLabel() {
    final totalSeconds = (_playheadMs / 1000.0);
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60);
    return '${minutes}:${seconds.toStringAsFixed(1).padLeft(4, '0')}';
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
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    final isVideo = picked.mimeType?.startsWith('video') ?? picked.path.toLowerCase().endsWith('.mp4');
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
                  _pill('Speed', Icons.speed, onTap: () => setState(() => _showSpeed = !_showSpeed)),
                  const SizedBox(width: 8),
                  _pill('Reverse', Icons.replay, onTap: widget.onReverse),
                  const SizedBox(width: 8),
                  _pill('Freeze', Icons.pause_circle_outline, onTap: widget.onFreeze),
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
                  const Text('0.1x', style: TextStyle(color: Colors.white, fontSize: 11)),
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
                  Text('${_speed.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white, fontSize: 11)),
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
                    child: const Text('Delete clip', style: TextStyle(color: Color(0xFFFF3B30))),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _confirmDelete = false),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon, {required VoidCallback onTap, Color? color}) {
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
