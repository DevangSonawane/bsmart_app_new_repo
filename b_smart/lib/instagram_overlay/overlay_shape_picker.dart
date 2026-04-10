import 'dart:io';
import 'package:flutter/material.dart';
import 'overlay_clippers.dart';
import 'overlay_shape.dart';

Future<OverlayShape?> openOverlayShapePicker(
  BuildContext context,
  File imageFile,
) {
  return showModalBottomSheet<OverlayShape>(
    context: context,
    backgroundColor: const Color(0xFF1C1C1E),
    isScrollControlled: true,
    builder: (context) => _OverlayShapePickerSheet(imageFile: imageFile),
  );
}

class _OverlayShapePickerSheet extends StatefulWidget {
  final File imageFile;

  const _OverlayShapePickerSheet({required this.imageFile});

  @override
  State<_OverlayShapePickerSheet> createState() =>
      _OverlayShapePickerSheetState();
}

class _OverlayShapePickerSheetState extends State<_OverlayShapePickerSheet> {
  OverlayShape _selected = OverlayShape.none;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.35,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Choose Shape',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text(
                      'Done',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: OverlayShape.values.map((shape) {
                    final isSelected = shape == _selected;
                    return _ShapeThumb(
                      imageFile: widget.imageFile,
                      shape: shape,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selected = shape),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ShapeThumb extends StatelessWidget {
  final File imageFile;
  final OverlayShape shape;
  final bool isSelected;
  final VoidCallback onTap;

  const _ShapeThumb({
    required this.imageFile,
    required this.shape,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final clipper = overlayClipperFor(shape);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white24,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Transform.scale(
                scale: isSelected ? 1.08 : 1.0,
                child: ClipPath(
                  clipper: clipper,
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _labelFor(shape),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(OverlayShape shape) {
    switch (shape) {
      case OverlayShape.none:
        return 'Original';
      case OverlayShape.circle:
        return 'Circle';
      case OverlayShape.heart:
        return 'Heart';
      case OverlayShape.star:
        return 'Star';
      case OverlayShape.hexagon:
        return 'Hexagon';
      case OverlayShape.triangle:
        return 'Triangle';
      case OverlayShape.diamond:
        return 'Diamond';
      case OverlayShape.roundedRect:
        return 'Rounded';
    }
  }
}
