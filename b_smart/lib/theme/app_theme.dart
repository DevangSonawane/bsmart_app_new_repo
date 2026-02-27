import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      primaryColor: DesignTokens.instaPurple,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        primary: DesignTokens.instaPurple,
        secondary: DesignTokens.instaPink,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.instaPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16.0),
        bodyMedium: TextStyle(fontSize: 14.0, color: Colors.black54),
      ),
    );
  }

  /// Dark theme: softer dark greys, light text and icons.
  static ThemeData get darkTheme {
    const surfaceDark = Color(0xFF1E1E1E);
    const scaffoldDark = Color(0xFF121212);
    const cardDark = Color(0xFF2D2D2D);
    const textLight = Color(0xFFE8E8E8);
    const textMuted = Color(0xFFB0B0B0);
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: DesignTokens.instaPurple,
      colorScheme: ColorScheme.dark().copyWith(
        primary: DesignTokens.instaPurple,
        secondary: DesignTokens.instaPink,
        surface: surfaceDark,
        onSurface: textLight,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: scaffoldDark,
      cardColor: cardDark,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: surfaceDark,
        foregroundColor: textLight,
        iconTheme: IconThemeData(color: textLight),
        titleTextStyle: TextStyle(color: textLight, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(color: textLight),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.instaPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: textLight),
        headlineMedium: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600, color: textLight),
        bodyLarge: TextStyle(fontSize: 16.0, color: textLight),
        bodyMedium: TextStyle(fontSize: 14.0, color: textMuted),
      ),
    );
  }
}

