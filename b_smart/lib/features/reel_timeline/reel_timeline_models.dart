import 'package:flutter/material.dart';
import '../../instagram_text_editor/instagram_text_result.dart';
import '../../instagram_overlay/overlay_shape.dart';

enum ReelClipType { video, image }

class ReelTextOverlay {
  final String text;
  final TextStyle style;
  final TextAlign alignment;
  final Color textColor;
  final BackgroundStyle backgroundStyle;
  final Offset normalizedPosition;
  final double scale;
  final double rotation;
  final double fontSize;

  const ReelTextOverlay({
    required this.text,
    required this.style,
    required this.alignment,
    required this.textColor,
    required this.backgroundStyle,
    required this.normalizedPosition,
    required this.scale,
    required this.rotation,
    required this.fontSize,
  });
}

class ReelStickerOverlay {
  final String imagePath;
  final OverlayShape shape;
  final Offset normalizedPosition;
  final double scale;
  final double rotation;
  final double baseSize;

  const ReelStickerOverlay({
    required this.imagePath,
    required this.shape,
    required this.normalizedPosition,
    required this.scale,
    required this.rotation,
    required this.baseSize,
  });
}

class ReelClip {
  final String id;
  final ReelClipType type;
  final String path;
  final Duration duration;
  final Duration? trimStart;
  final Duration? trimEnd;
  final List<double>? colorMatrix;
  final List<ReelTextOverlay> textOverlays;
  final List<ReelStickerOverlay> stickerOverlays;
  final double speed;
  final bool isReversed;
  final Duration? freezeAt;
  final Duration freezeDuration;
  final String? transitionIn;
  final double transitionInDurationMs;
  final String? groupId;
  final String? audioPath;
  final double audioVolume;
  final double originalVolume;
  final String? voicePath;
  final double voiceVolume;

  const ReelClip({
    required this.id,
    required this.type,
    required this.path,
    required this.duration,
    this.trimStart,
    this.trimEnd,
    this.colorMatrix,
    this.textOverlays = const [],
    this.stickerOverlays = const [],
    this.speed = 1.0,
    this.isReversed = false,
    this.freezeAt,
    this.freezeDuration = Duration.zero,
    this.transitionIn = 'none',
    this.transitionInDurationMs = 300.0,
    this.groupId,
    this.audioPath,
    this.audioVolume = 1.0,
    this.originalVolume = 1.0,
    this.voicePath,
    this.voiceVolume = 1.0,
  });

  ReelClip copyWith({
    String? id,
    ReelClipType? type,
    String? path,
    Duration? duration,
    Duration? trimStart,
    Duration? trimEnd,
    List<double>? colorMatrix,
    List<ReelTextOverlay>? textOverlays,
    List<ReelStickerOverlay>? stickerOverlays,
    double? speed,
    bool? isReversed,
    Duration? freezeAt,
    Duration? freezeDuration,
    String? transitionIn,
    double? transitionInDurationMs,
    String? groupId,
    String? audioPath,
    double? audioVolume,
    double? originalVolume,
    String? voicePath,
    double? voiceVolume,
  }) {
    return ReelClip(
      id: id ?? this.id,
      type: type ?? this.type,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      trimStart: trimStart ?? this.trimStart,
      trimEnd: trimEnd ?? this.trimEnd,
      colorMatrix: colorMatrix ?? this.colorMatrix,
      textOverlays: textOverlays ?? this.textOverlays,
      stickerOverlays: stickerOverlays ?? this.stickerOverlays,
      speed: speed ?? this.speed,
      isReversed: isReversed ?? this.isReversed,
      freezeAt: freezeAt ?? this.freezeAt,
      freezeDuration: freezeDuration ?? this.freezeDuration,
      transitionIn: transitionIn ?? this.transitionIn,
      transitionInDurationMs: transitionInDurationMs ?? this.transitionInDurationMs,
      groupId: groupId ?? this.groupId,
      audioPath: audioPath ?? this.audioPath,
      audioVolume: audioVolume ?? this.audioVolume,
      originalVolume: originalVolume ?? this.originalVolume,
      voicePath: voicePath ?? this.voicePath,
      voiceVolume: voiceVolume ?? this.voiceVolume,
    );
  }
}

class ReelEditHistory {
  final List<List<ReelClip>> _stack = [];
  int _cursor = -1;
  static const int _maxSize = 30;

  void push(List<ReelClip> state) {
    if (_cursor < _stack.length - 1) {
      _stack.removeRange(_cursor + 1, _stack.length);
    }
    _stack.add(List.unmodifiable(state));
    if (_stack.length > _maxSize) _stack.removeAt(0);
    _cursor = _stack.length - 1;
  }

  List<ReelClip>? undo() {
    if (_cursor <= 0) return null;
    _cursor--;
    return List<ReelClip>.from(_stack[_cursor]);
  }

  List<ReelClip>? redo() {
    if (_cursor >= _stack.length - 1) return null;
    _cursor++;
    return List<ReelClip>.from(_stack[_cursor]);
  }

  bool get canUndo => _cursor > 0;
  bool get canRedo => _cursor < _stack.length - 1;
}
