import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'overlay_clippers.dart';
import 'overlay_sticker.dart';

class OverlayStickerWidget extends StatefulWidget {
  final OverlaySticker sticker;
  final bool isActive;
  final bool isDragging;
  final bool isNearTrash;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onDelete;

  const OverlayStickerWidget({
    super.key,
    required this.sticker,
    required this.isActive,
    required this.isDragging,
    required this.isNearTrash,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDelete,
  });

  @override
  State<OverlayStickerWidget> createState() => _OverlayStickerWidgetState();
}

class _OverlayStickerWidgetState extends State<OverlayStickerWidget> {
  late Offset _displayPosition;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _displayPosition = widget.sticker.position;
  }

  @override
  void didUpdateWidget(covariant OverlayStickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragging || widget.isDragging) return;
    _displayPosition = widget.sticker.position;
  }

  @override
  Widget build(BuildContext context) {
    final offset = _displayPosition - widget.sticker.position;
    final isMoving = _dragging || widget.isDragging;

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (details) {
          _dragging = true;
          _displayPosition = widget.sticker.position;
          widget.onDragStart(details);
        },
        onPanUpdate: (details) {
          setState(() {
            _displayPosition += details.delta;
          });
          widget.onDragUpdate(details);
        },
        onPanEnd: (details) {
          _dragging = false;
          widget.onDragEnd(details);
        },
        onPanCancel: () {
          _dragging = false;
          widget.onDragEnd(DragEndDetails());
        },
        child: Transform.translate(
          offset: offset,
          child: AnimatedScale(
            duration: widget.isNearTrash || isMoving
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            scale: widget.isNearTrash ? 0.82 : 1.0,
            child: AnimatedContainer(
              duration: widget.isNearTrash || isMoving
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isNearTrash
                      ? Colors.red.withValues(alpha: 0.55)
                      : Colors.transparent,
                  width: widget.isNearTrash ? 1.4 : 0,
                ),
              ),
              child: _StickerBody(
                sticker: widget.sticker,
                isActive: widget.isActive,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StickerBody extends StatelessWidget {
  final OverlaySticker sticker;
  final bool isActive;

  const _StickerBody({
    required this.sticker,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final clipper = overlayClipperFor(sticker.shape);
    return ClipPath(
      clipper: clipper,
      child: Container(
        decoration: BoxDecoration(
          border: isActive
              ? Border.all(color: Colors.white24, width: 1.2)
              : null,
        ),
        child: Image.file(
          sticker.imageFile,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
