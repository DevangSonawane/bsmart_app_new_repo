import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class DraggableTextOverlay extends StatefulWidget {
  final Widget child;
  final Offset position;
  final double scale;
  final double rotation;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleStartCallback onScaleStart;
  final bool isDragging;
  final bool isNearTrash;
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  const DraggableTextOverlay({
    super.key,
    required this.child,
    required this.position,
    required this.scale,
    required this.rotation,
    required this.onScaleUpdate,
    required this.onScaleStart,
    required this.isDragging,
    required this.isNearTrash,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<DraggableTextOverlay> createState() => _DraggableTextOverlayState();
}

class _DraggableTextOverlayState extends State<DraggableTextOverlay> {
  late Offset _displayPosition;
  late double _displayScale;
  late double _displayRotation;
  bool _dragging = false;
  bool _gestureActive = false;
  double _scaleStart = 1.0;
  double _rotationStart = 0.0;

  @override
  void initState() {
    super.initState();
    _displayPosition = widget.position;
    _displayScale = widget.scale;
    _displayRotation = widget.rotation;
  }

  @override
  void didUpdateWidget(covariant DraggableTextOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_gestureActive || _dragging) return;
    _displayPosition = widget.position;
    _displayScale = widget.scale;
    _displayRotation = widget.rotation;
  }

  double _normalizeRotation(double radians) {
    final degrees = radians * 180 / math.pi;
    final normalized = ((degrees + 180) % 360) - 180;
    return normalized * math.pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    final isMoving = _gestureActive || _dragging || widget.isDragging;
    return AnimatedPositioned(
      duration: isMoving || widget.isNearTrash
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      left: _displayPosition.dx,
      top: _displayPosition.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onScaleStart: (details) {
          _gestureActive = true;
          _scaleStart = _displayScale;
          _rotationStart = _displayRotation;
          widget.onScaleStart(details);
        },
        onScaleUpdate: (details) {
          setState(() {
            _displayPosition += details.focalPointDelta;
            if (details.pointerCount > 1) {
              _displayScale = (_scaleStart * details.scale).clamp(0.5, 4.0);
              _displayRotation =
                  _normalizeRotation(_rotationStart + details.rotation);
            }
          });

          widget.onScaleUpdate(details);

          if (details.pointerCount == 1) {
            if (!_dragging) {
              _dragging = true;
              widget.onDragStart();
            }

            widget.onDragUpdate(
              DragUpdateDetails(
                globalPosition: details.focalPoint,
                localPosition: details.localFocalPoint,
                delta: details.focalPointDelta,
                sourceTimeStamp: details.sourceTimeStamp,
              ),
            );
          }
        },
        onScaleEnd: (_) {
          _gestureActive = false;
          _dragging = false;
          widget.onDragEnd();
        },
        child: AnimatedContainer(
          duration: widget.isNearTrash
              ? const Duration(milliseconds: 200)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.isNearTrash ? Colors.red.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: AnimatedScale(
            duration: widget.isNearTrash
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            scale: widget.isNearTrash ? 0.85 : 1.0,
            child: Transform.rotate(
              angle: _displayRotation,
              child: Transform.scale(
                scale: _displayScale,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
