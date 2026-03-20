import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'overlay_shape.dart';

CustomClipper<Path> overlayClipperFor(OverlayShape shape) {
  switch (shape) {
    case OverlayShape.circle:
      return CircleClipper();
    case OverlayShape.heart:
      return HeartClipper();
    case OverlayShape.star:
      return StarClipper();
    case OverlayShape.hexagon:
      return HexagonClipper();
    case OverlayShape.triangle:
      return TriangleClipper();
    case OverlayShape.diamond:
      return DiamondClipper();
    case OverlayShape.roundedRect:
      return RoundedRectClipper();
    case OverlayShape.none:
      return RoundedRectClipper(radius: 0);
  }
}

class CircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, size.height * 0.35);
    path.cubicTo(
      size.width * 0.85,
      0,
      size.width * 1.1,
      size.height * 0.45,
      size.width / 2,
      size.height * 0.95,
    );
    path.cubicTo(
      -size.width * 0.1,
      size.height * 0.45,
      size.width * 0.15,
      0,
      size.width / 2,
      size.height * 0.35,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class StarClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width * 0.5;
    final innerR = size.width * 0.22;
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 4 * math.pi / 5) - math.pi / 2;
      final innerAngle = outerAngle + 2 * math.pi / 10;
      final outer = Offset(
        center.dx + outerR * math.cos(outerAngle),
        center.dy + outerR * math.sin(outerAngle),
      );
      final inner = Offset(
        center.dx + innerR * math.cos(innerAngle),
        center.dy + innerR * math.sin(innerAngle),
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.25, 0);
    path.lineTo(w * 0.75, 0);
    path.lineTo(w, h * 0.5);
    path.lineTo(w * 0.75, h);
    path.lineTo(w * 0.25, h);
    path.lineTo(0, h * 0.5);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class DiamondClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width / 2, size.height);
    path.lineTo(0, size.height / 2);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class RoundedRectClipper extends CustomClipper<Path> {
  final double radius;
  RoundedRectClipper({this.radius = 20});

  @override
  Path getClip(Size size) {
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
