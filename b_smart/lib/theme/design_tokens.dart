import 'package:flutter/material.dart';

/// Design tokens ported from Tailwind config (b-smart-main-2/tailwind.config.js)
class DesignTokens {
  // Brand colors
  static const Color instaPink = Color(0xFFD62976);
  static const Color instaOrange = Color(0xFFFA7E1E);
  static const Color instaPurple = Color(0xFF962FBF);
  static const Color instaYellow = Color(0xFFFEDA75);

  // Gradient used in the web app
  static const LinearGradient instaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF09433),
      Color(0xFFE6683C),
      Color(0xFFDC2743),
      Color(0xFFCC2366),
      Color(0xFFBC1888),
    ],
    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
  );

  // Common spacing tokens (examples)
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // Border radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
}

