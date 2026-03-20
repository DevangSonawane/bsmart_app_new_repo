import 'package:flutter/material.dart';

enum BackgroundStyle {
  none,
  solid,
  transparent,
  perChar,
}

class InstagramTextResult {
  final String text;
  final TextStyle style;
  final Offset position;
  final double scale;
  final double rotation;
  final TextAlign alignment;
  final Color textColor;
  final BackgroundStyle backgroundStyle;
  final String fontName;
  final double fontSize;

  const InstagramTextResult({
    required this.text,
    required this.style,
    required this.position,
    required this.scale,
    required this.rotation,
    required this.alignment,
    required this.textColor,
    required this.backgroundStyle,
    this.fontName = 'Modern',
    this.fontSize = 32.0,
  });
}
