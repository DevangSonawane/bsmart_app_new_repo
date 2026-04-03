import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../features/reel_timeline/reel_timeline_models.dart';

enum _TimelineMode { scroll, trim, scrub }

class ReelTimelineStrip extends StatefulWidget {
  final List<ReelClip> clips;
  final double playheadMs;
  final double totalDurationMs;
  final double pxPerMs;
  final int? selectedClipIndex;
  final bool trimMode;
  final ValueChanged<double>? onScrollOffsetChanged;
  final ValueChanged<int> onClipSelected;
  final ValueChanged<int> onClipDoubleTap;
  final ValueChanged<int> onClipLongPress;
  final void Function(int from, int to) onClipReorder;
  final void Function(int index, Duration trimStart, Duration trimEnd) onClipTrimmed;
  final ValueChanged<double> onPlayheadScrub;
  final VoidCallback onScrubStart;
  final VoidCallback onScrubEnd;
  final ValueChanged<double> onZoomChanged;
  final VoidCallback onAddClip;
  final List<({double startMs, double endMs, Color color})> overlaySpans;
  final ValueChanged<int> onTransitionTap;

  const ReelTimelineStrip({
    super.key,
    required this.clips,
    required this.playheadMs,
    required this.totalDurationMs,
    required this.pxPerMs,
    required this.selectedClipIndex,
    required this.trimMode,
    this.onScrollOffsetChanged,
    required this.onClipSelected,
    required this.onClipDoubleTap,
    required this.onClipLongPress,
    required this.onClipReorder,
    required this.onClipTrimmed,
    required this.onPlayheadScrub,
    required this.onScrubStart,
    required this.onScrubEnd,
    required this.onZoomChanged,
    required this.onAddClip,
    required this.overlaySpans,
    required this.onTransitionTap,
  });

  @override
  State<ReelTimelineStrip> createState() => _ReelTimelineStripState();
}

class _ReelTimelineStripState extends State<ReelTimelineStrip> {
  static const double _tileGap = 8;
  static const double _dotSlot = 16;
  static const double _leftPad = 16;
  static const double _rightPad = 16;
  static const double _handleWidth = 10;
  static const double _rulerHeight = 20;
  static const double _tileHeight = 60;
  static const double _overlayHeight = 20;

  final GlobalKey _stripKey = GlobalKey();
  double _trackWidth = 0;
  double _scrollOffset = 0;
  double _scaleStart = 0.12;
  bool _isDragging = false;
  bool _didMove = false;
  int? _dragIndex;
  int? _dragTargetIndex;
  int? _trimmingIndex;
  double? _draftTrimStartMs;
  double? _draftTrimEndMs;
  bool _showZoomIndicator = false;
  Timer? _hideZoomTimer;
  _TimelineMode _mode = _TimelineMode.scroll;

  double _clipBaseDurationMs(ReelClip clip) {
    final start = clip.trimStart ?? Duration.zero;
    final end = clip.trimEnd ?? clip.duration;
    final baseMs = (end - start).inMilliseconds.toDouble();
    return baseMs < 0 ? 0 : baseMs;
  }

  double _displayDurationMs(ReelClip clip) {
    if (clip.type == ReelClipType.image &&
        _trimmingIndex != null &&
        _trimmingIndex! >= 0 &&
        _trimmingIndex! < widget.clips.length &&
        clip == widget.clips[_trimmingIndex!] &&
        _draftTrimEndMs != null) {
      return _draftTrimEndMs!.clamp(500.0, 10000.0);
    }
    return _clipBaseDurationMs(clip);
  }

  double _clipEffectiveDurationMs(ReelClip clip) {
    final baseMs = _displayDurationMs(clip);
    final speed = clip.speed <= 0 ? 1.0 : clip.speed;
    return baseMs / speed;
  }

  double _clipWidth(ReelClip clip) {
    final ms = _clipEffectiveDurationMs(clip);
    final width = ms * widget.pxPerMs;
    return width < 48 ? 48 : width;
  }

  void _updateTrackWidth() {
    double w = 0;
    for (int i = 0; i < widget.clips.length; i++) {
      w += _clipWidth(widget.clips[i]);
      if (i != widget.clips.length - 1) {
        w += _tileGap + _dotSlot + _tileGap;
      }
    }
    if (widget.clips.isNotEmpty) w += _tileGap;
    w += 36;
    setState(() {
      _trackWidth = w;
      _scrollOffset = _scrollOffset.clamp(0.0, _maxScroll);
    });
    widget.onScrollOffsetChanged?.call(_scrollOffset);
  }

  double get _maxScroll {
    final box = _stripKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 0;
    final content = _trackWidth + _leftPad + _rightPad;
    return (content - width).clamp(0.0, double.infinity).toDouble();
  }

  @override
  void didUpdateWidget(covariant ReelTimelineStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clips != widget.clips || oldWidget.pxPerMs != widget.pxPerMs) {
      _updateTrackWidth();
    }
  }

  @override
  void initState() {
    super.initState();
    _updateTrackWidth();
  }

  @override
  void dispose() {
    _hideZoomTimer?.cancel();
    super.dispose();
  }

  double _localDx(Offset global) {
    final box = _stripKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    return box.globalToLocal(global).dx;
  }

  int _indexFromDx(double dx) {
    double cursor = _leftPad - _scrollOffset;
    for (int i = 0; i < widget.clips.length; i++) {
      final w = _clipWidth(widget.clips[i]);
      final start = cursor;
      final end = cursor + w;
      if (dx >= start && dx <= end) return i;
      cursor = end;
      if (i != widget.clips.length - 1) {
        cursor += _tileGap + _dotSlot + _tileGap;
      }
    }
    return widget.clips.isEmpty ? 0 : widget.clips.length - 1;
  }

  double _clipStartDx(int index) {
    double cursor = _leftPad - _scrollOffset;
    for (int i = 0; i < index; i++) {
      cursor += _clipWidth(widget.clips[i]);
      if (i != widget.clips.length - 1) {
        cursor += _tileGap + _dotSlot + _tileGap;
      }
    }
    return cursor;
  }

  void _beginTrim(int index) {
    final clip = widget.clips[index];
    _trimmingIndex = index;
    _draftTrimStartMs = (clip.trimStart ?? Duration.zero).inMilliseconds.toDouble();
    _draftTrimEndMs = (clip.trimEnd ?? clip.duration).inMilliseconds.toDouble();
  }

  void _commitTrim(int index) {
    if (_draftTrimStartMs == null || _draftTrimEndMs == null) return;
    final clip = widget.clips[index];
    if (clip.type == ReelClipType.image) {
      final endMs = _draftTrimEndMs!.clamp(500.0, 10000.0);
      widget.onClipTrimmed(index, Duration.zero, Duration(milliseconds: endMs.round()));
    } else {
      final start = Duration(milliseconds: _draftTrimStartMs!.round());
      final end = Duration(milliseconds: _draftTrimEndMs!.round());
      widget.onClipTrimmed(index, start, end);
    }
    _trimmingIndex = null;
  }

  void _setMode(_TimelineMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  void _handlePanStart(DragStartDetails details) {
    final localDx = _localDx(details.globalPosition);
    final totalMs = widget.totalDurationMs <= 0 ? 1.0 : widget.totalDurationMs;
    final playheadLeft = _leftPad + (widget.playheadMs / totalMs) * _trackWidth - _scrollOffset;
    if ((localDx - playheadLeft).abs() <= 16) {
      _setMode(_TimelineMode.scrub);
      widget.onScrubStart();
      return;
    }
    if (widget.trimMode) {
      final idx = widget.selectedClipIndex;
      if (idx != null && idx >= 0 && idx < widget.clips.length) {
        final clip = widget.clips[idx];
        final clipStart = _clipStartDx(idx);
        final clipEnd = clipStart + _clipWidth(clip);
        if ((localDx - clipStart).abs() <= _handleWidth && clip.type == ReelClipType.video) {
          _setMode(_TimelineMode.trim);
          _beginTrim(idx);
          return;
        }
        if ((localDx - clipEnd).abs() <= _handleWidth) {
          _setMode(_TimelineMode.trim);
          _beginTrim(idx);
          return;
        }
      }
    }
    _setMode(_TimelineMode.scroll);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_mode == _TimelineMode.scroll) {
      _scrollOffset = (_scrollOffset - details.delta.dx).clamp(0.0, _maxScroll);
      widget.onScrollOffsetChanged?.call(_scrollOffset);
      setState(() {});
      return;
    }
    if (_mode == _TimelineMode.scrub) {
      if (_trackWidth <= 0) return;
      final local = _localDx(details.globalPosition);
      final ms = ((local + _scrollOffset - _leftPad) / _trackWidth) * (widget.totalDurationMs <= 0 ? 1.0 : widget.totalDurationMs);
      widget.onPlayheadScrub(ms.clamp(0.0, widget.totalDurationMs));
      return;
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_mode == _TimelineMode.scrub) {
      widget.onScrubEnd();
    }
    _setMode(_TimelineMode.scroll);
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.totalDurationMs <= 0 ? 1.0 : widget.totalDurationMs;
    final playheadLeft = _leftPad + (widget.playheadMs / totalMs) * _trackWidth - _scrollOffset;

    return Container(
      key: _stripKey,
      height: _rulerHeight + _tileHeight + _overlayHeight,
      color: Colors.black,
      child: RawGestureDetector(
        gestures: <Type, GestureRecognizerFactory>{
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
            () => HorizontalDragGestureRecognizer(),
            (recognizer) {
              recognizer.onStart = _handlePanStart;
              recognizer.onUpdate = _handlePanUpdate;
              recognizer.onEnd = _handlePanEnd;
            },
          ),
          ScaleGestureRecognizer: GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
            () => ScaleGestureRecognizer(),
            (recognizer) {
              recognizer.onStart = (d) {
                if (d.pointerCount > 1) {
                  _scaleStart = widget.pxPerMs;
                  _hideZoomTimer?.cancel();
                  setState(() => _showZoomIndicator = true);
                }
              };
              recognizer.onUpdate = (d) {
                if (d.pointerCount > 1) {
                  final next = (_scaleStart * d.scale).clamp(0.04, 2.0);
                  widget.onZoomChanged(next);
                  _hideZoomTimer?.cancel();
                  _hideZoomTimer = Timer(const Duration(milliseconds: 1500), () {
                    if (mounted) setState(() => _showZoomIndicator = false);
                  });
                }
              };
            },
          ),
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _mode != _TimelineMode.scroll,
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(
                    height: _rulerHeight,
                    child: Stack(
                      children: [
                        if (_trackWidth > 0) ..._buildRulerTicks(totalMs),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: _tileHeight,
                    child: Stack(
                      children: [
                        Transform.translate(
                          offset: Offset(-_scrollOffset, 0),
                          child: SizedBox(
                            height: _tileHeight,
                            width: _trackWidth + _leftPad + _rightPad,
                            child: Stack(
                              children: _buildTiles(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: _overlayHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _leftPad),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: double.infinity,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[700],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          if (_trackWidth > 0)
                            ...widget.overlaySpans.map((span) {
                              final left = _leftPad + (span.startMs / totalMs) * _trackWidth - _scrollOffset;
                              final width = ((span.endMs - span.startMs) / totalMs) * _trackWidth;
                              return Positioned(
                                left: left,
                                top: 6,
                                child: Container(
                                  width: width.clamp(4.0, _trackWidth),
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: span.color,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                bottom: 0,
                left: playheadLeft,
                child: Column(
                  children: [
                    CustomPaint(
                      size: const Size(8, 6),
                      painter: _TrianglePainter(color: const Color(0xFFFF3B30)),
                    ),
                    Container(
                      width: 1.5,
                      height: _rulerHeight + _tileHeight + _overlayHeight - 6,
                      color: const Color(0xFFFF3B30),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 8,
                bottom: 6,
                child: AnimatedOpacity(
                  opacity: _showZoomIndicator ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${(widget.pxPerMs / 0.12).toStringAsFixed(1)}×',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTiles() {
    final tiles = <Widget>[];
    double cursor = _leftPad;
    for (int i = 0; i < widget.clips.length; i++) {
      final clip = widget.clips[i];
      final width = _clipWidth(clip);
      tiles.add(Positioned(
        left: cursor,
        top: 0,
        width: width,
        height: _tileHeight,
        child: _buildClipTile(i, clip),
      ));
      cursor += width;
      if (i != widget.clips.length - 1) {
        cursor += _tileGap;
        tiles.add(Positioned(
          left: cursor,
          top: 0,
          width: _dotSlot,
          height: _tileHeight,
          child: _buildTransitionDot(i + 1),
        ));
        cursor += _dotSlot + _tileGap;
      } else {
        cursor += _tileGap;
      }
    }
    tiles.add(
      Positioned(
        left: cursor,
        top: 12,
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: widget.onAddClip,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.black, size: 18),
          ),
        ),
      ),
    );
    return tiles;
  }

  Widget _buildTransitionDot(int clipIndex) {
    final clip = widget.clips[clipIndex];
    final hasTransition = clip.transitionIn != null && clip.transitionIn != 'none';
    return GestureDetector(
      onTap: () => widget.onTransitionTap(clipIndex),
      child: Container(
        alignment: Alignment.center,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasTransition ? const Color(0xFF0095F6) : Colors.white24,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRulerTicks(double totalMs) {
    final widgets = <Widget>[];
    final totalSeconds = (totalMs / 1000).ceil();
    for (int s = 1; s <= totalSeconds; s += 2) {
      final left = _leftPad + (s * 1000 * widget.pxPerMs) - _scrollOffset;
      widgets.add(Positioned(
        left: left,
        top: 2,
        child: Row(
          children: [
            Text(
              '${s}s',
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const SizedBox(width: 6),
            const Text('•', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ));
    }
    return widgets;
  }

  Widget _buildClipTile(int index, ReelClip clip) {
    final isSelected = widget.selectedClipIndex == index;
    final showTrimHandles = widget.trimMode && isSelected;
    final isGrouped = clip.groupId != null;
    final isFirstInGroup = isGrouped && (index == 0 || widget.clips[index - 1].groupId != clip.groupId);
    final opacity = _isDragging && _dragIndex != index ? 0.85 : 1.0;
    return Opacity(
      opacity: opacity,
      child: GestureDetector(
        onTap: () => widget.onClipSelected(index),
        onDoubleTap: () => widget.onClipDoubleTap(index),
        onLongPressStart: (d) {
          _dragIndex = index;
          _dragTargetIndex = index;
          _didMove = false;
          _isDragging = true;
          setState(() {});
        },
        onLongPressMoveUpdate: (d) {
          if (!_isDragging) return;
          final localDx = _localDx(d.globalPosition);
          final target = _indexFromDx(localDx);
          if (target != _dragTargetIndex) {
            _dragTargetIndex = target;
            _didMove = true;
            setState(() {});
          }
        },
        onLongPressEnd: (_) {
          if (!_isDragging) return;
          final from = _dragIndex ?? index;
          final to = _dragTargetIndex ?? from;
          setState(() {
            _isDragging = false;
            _dragIndex = null;
            _dragTargetIndex = null;
          });
          if (_didMove && from != to) {
            widget.onClipReorder(from, to);
          } else {
            widget.onClipLongPress(from);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: showTrimHandles ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _ClipThumb(clip: clip, width: _clipWidth(clip), height: _tileHeight),
              if (isGrouped)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(height: 2, color: const Color(0xFFFFCC00)),
                ),
              if (isFirstInGroup)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCC00),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('G', style: TextStyle(color: Colors.black, fontSize: 9)),
                  ),
                ),
              if (clip.type == ReelClipType.image)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(_displayDurationMs(clip) / 1000).toStringAsFixed(1)}s',
                      style: const TextStyle(color: Colors.black, fontSize: 10),
                    ),
                  ),
                ),
              if (showTrimHandles && clip.type == ReelClipType.video)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _handleWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _beginTrim(index),
                    onHorizontalDragUpdate: (d) {
                      if (_trimmingIndex != index) return;
                      final clipStart = (clip.trimStart ?? Duration.zero).inMilliseconds.toDouble();
                      final clipEnd = (clip.trimEnd ?? clip.duration).inMilliseconds.toDouble();
                      final deltaMs = d.delta.dx / widget.pxPerMs;
                      final next = (_draftTrimStartMs ?? clipStart) + deltaMs;
                      _draftTrimStartMs = next.clamp(0.0, clipEnd - 500.0);
                      setState(() {});
                    },
                    onHorizontalDragEnd: (_) => _commitTrim(index),
                    child: Container(
                      color: Colors.white,
                      child: Center(
                        child: Container(width: 2, height: 24, color: Colors.black),
                      ),
                    ),
                  ),
                ),
              if (showTrimHandles)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: _handleWidth,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _beginTrim(index),
                    onHorizontalDragUpdate: (d) {
                      if (_trimmingIndex != index) return;
                      final deltaMs = d.delta.dx / widget.pxPerMs;
                      if (clip.type == ReelClipType.image) {
                        final current = _draftTrimEndMs ?? clip.duration.inMilliseconds.toDouble();
                        final next = current + deltaMs;
                        _draftTrimEndMs = next.clamp(500.0, 10000.0);
                      } else {
                        final clipStart = (clip.trimStart ?? Duration.zero).inMilliseconds.toDouble();
                        final clipEnd = (clip.trimEnd ?? clip.duration).inMilliseconds.toDouble();
                        final next = (_draftTrimEndMs ?? clipEnd) + deltaMs;
                        _draftTrimEndMs = next.clamp(clipStart + 500.0, clip.duration.inMilliseconds.toDouble());
                      }
                      setState(() {});
                    },
                    onHorizontalDragEnd: (_) => _commitTrim(index),
                    child: Container(
                      color: Colors.white,
                      child: Center(
                        child: Container(width: 2, height: 24, color: Colors.black),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClipThumb extends StatelessWidget {
  final ReelClip clip;
  final double width;
  final double height;

  const _ClipThumb({
    required this.clip,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return clip.type == ReelClipType.video
        ? FutureBuilder<Uint8List?>(
            future: VideoThumbnail.thumbnailData(
              video: clip.path,
              imageFormat: ImageFormat.JPEG,
              quality: 60,
            ),
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done || snap.data == null) {
                return Container(color: Colors.grey[850]);
              }
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: MemoryImage(snap.data!),
                    fit: BoxFit.cover,
                    repeat: ImageRepeat.repeatX,
                  ),
                ),
              );
            },
          )
        : Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: FileImage(File(clip.path)),
                fit: BoxFit.cover,
                repeat: ImageRepeat.repeatX,
              ),
            ),
          );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
