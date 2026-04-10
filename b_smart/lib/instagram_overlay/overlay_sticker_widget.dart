import 'package:flutter/material.dart';
import 'overlay_clippers.dart';
import 'overlay_sticker.dart';

class OverlayStickerWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onPanStart: onDragStart,
        onPanUpdate: onDragUpdate,
        onPanEnd: onDragEnd,
        onPanCancel: () => onDragEnd(DragEndDetails()),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: isNearTrash ? 0.82 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isNearTrash
                    ? Colors.red.withValues(alpha: 0.55)
                    : Colors.transparent,
                width: isNearTrash ? 1.4 : 0,
              ),
            ),
            child: _StickerBody(
              sticker: sticker,
              isActive: isActive,
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
      child: Image.file(
        sticker.imageFile,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      ),
    );
  }
}
