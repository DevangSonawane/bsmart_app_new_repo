import 'package:flutter/material.dart';
import 'overlay_clippers.dart';
import 'overlay_sticker.dart';

class OverlayStickerWidget extends StatelessWidget {
  final OverlaySticker sticker;
  final bool isActive;
  final VoidCallback onDelete;

  const OverlayStickerWidget({
    super.key,
    required this.sticker,
    required this.isActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _StickerBody(
        sticker: sticker,
        isActive: isActive,
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
