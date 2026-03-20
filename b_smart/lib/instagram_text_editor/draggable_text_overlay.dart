import 'package:flutter/material.dart';
class DraggableTextOverlay extends StatelessWidget {
  final Widget child;
  final Offset position;
  final double scale;
  final double rotation;
  final GestureScaleUpdateCallback onScaleUpdate;
  final GestureScaleStartCallback onScaleStart;

  const DraggableTextOverlay({
    super.key,
    required this.child,
    required this.position,
    required this.scale,
    required this.rotation,
    required this.onScaleUpdate,
    required this.onScaleStart,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onScaleStart: onScaleStart,
        onScaleUpdate: onScaleUpdate,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(rotation)
            ..scale(scale),
          child: child,
        ),
      ),
    );
  }
}
