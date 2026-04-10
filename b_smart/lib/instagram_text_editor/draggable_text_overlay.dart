import 'package:flutter/material.dart';

class DraggableTextOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: isNearTrash ? const Duration(milliseconds: 200) : Duration.zero,
      curve: Curves.easeOutCubic,
      left: position.dx,
      top: position.dy,
      child: _OverlayGestureSurface(
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        isDragging: isDragging,
        onDragStart: onDragStart,
        onDragUpdate: onDragUpdate,
        onDragEnd: onDragEnd,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isNearTrash ? Colors.red.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            scale: isNearTrash ? 0.85 : 1.0,
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayGestureSurface extends StatefulWidget {
  final Widget child;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleStartCallback onScaleStart;
  final bool isDragging;
  final VoidCallback onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final VoidCallback onDragEnd;

  const _OverlayGestureSurface({
    required this.child,
    required this.onScaleUpdate,
    required this.onScaleStart,
    required this.isDragging,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<_OverlayGestureSurface> createState() => _OverlayGestureSurfaceState();
}

class _OverlayGestureSurfaceState extends State<_OverlayGestureSurface> {
  bool _draggingFromScale = false;

  void _endDragIfNeeded() {
    if (!_draggingFromScale) return;
    _draggingFromScale = false;
    widget.onDragEnd();
  }

  @override
  void didUpdateWidget(covariant _OverlayGestureSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isDragging && _draggingFromScale) {
      _draggingFromScale = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        widget.onScaleStart(details);
      },
      onScaleUpdate: (details) {
        widget.onScaleUpdate(details);

        if (details.pointerCount != 1) {
          if (_draggingFromScale) {
            _endDragIfNeeded();
          }
          return;
        }

        if (!_draggingFromScale && !widget.isDragging) {
          _draggingFromScale = true;
          widget.onDragStart();
        }

        if (_draggingFromScale || widget.isDragging) {
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
      onScaleEnd: (_) => _endDragIfNeeded(),
      child: widget.child,
    );
  }
}
