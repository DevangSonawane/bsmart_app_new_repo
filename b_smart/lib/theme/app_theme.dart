import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppTheme {
  static const Color _darkScaffold = Color(0xFF000000);
  static const Color _darkSurface = Color(0xFF111111);
  static const Color _darkSurfaceAlt = Color(0xFF1A1A1A);
  static const Color _darkCard = Color(0xFF1E1E1E);
  static const Color _darkElevated = Color(0xFF262626);
  static const Color _darkBorder = Color(0xFF2A2A2A);
  static const Color _darkTextPrimary = Color(0xFFF5F5F5);
  static const Color _darkTextSecondary = Color(0xFFB3B3B3);
  static const Color _darkTextMuted = Color(0xFF7A7A7A);

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

  static ThemeData highContrastTheme() {
    return theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: Colors.black,
        secondary: Colors.black,
        surface: Colors.white,
        onSurface: Colors.black,
        onPrimary: Colors.white,
      ),
      appBarTheme: theme.appBarTheme.copyWith(
        foregroundColor: Colors.black,
      ),
      textTheme: theme.textTheme.apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
    );
  }

  /// Dark theme: softer dark greys, light text and icons.
  static ThemeData get darkTheme {
    final colorScheme = const ColorScheme.dark().copyWith(
      primary: DesignTokens.instaPink,
      secondary: DesignTokens.instaPurple,
      surface: _darkSurface,
      onSurface: _darkTextPrimary,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      error: const Color(0xFFFF5C7A),
      onError: Colors.white,
      outline: _darkBorder,
      outlineVariant: _darkBorder,
      surfaceContainerLowest: _darkScaffold,
      surfaceContainerLow: _darkSurface,
      surfaceContainer: _darkSurfaceAlt,
      surfaceContainerHigh: _darkCard,
      surfaceContainerHighest: _darkElevated,
      surfaceDim: _darkScaffold,
      surfaceBright: _darkElevated,
      inverseSurface: Colors.white,
      onInverseSurface: Colors.black,
      inversePrimary: DesignTokens.instaPink,
      shadow: Colors.black,
      scrim: Colors.black,
      tertiary: DesignTokens.instaOrange,
      onTertiary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: DesignTokens.instaPurple,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkScaffold,
      canvasColor: _darkScaffold,
      cardColor: _darkCard,
      dividerColor: _darkBorder,
      highlightColor: Colors.white.withValues(alpha: 0.04),
      splashColor: Colors.white.withValues(alpha: 0.06),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: _darkScaffold,
        foregroundColor: _darkTextPrimary,
        iconTheme: IconThemeData(color: _darkTextPrimary),
        titleTextStyle: TextStyle(color: _darkTextPrimary, fontSize: 20, fontWeight: FontWeight.w600),
      ),
      iconTheme: const IconThemeData(color: _darkTextPrimary),
      primaryIconTheme: const IconThemeData(color: _darkTextPrimary),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: DesignTokens.instaPink,
        selectionColor: DesignTokens.instaPink.withValues(alpha: 0.25),
        selectionHandleColor: DesignTokens.instaPink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkSurfaceAlt,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DesignTokens.instaPink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF5C7A), width: 1),
        ),
        labelStyle: const TextStyle(color: _darkTextSecondary),
        hintStyle: const TextStyle(color: _darkTextMuted),
        prefixIconColor: _darkTextSecondary,
        suffixIconColor: _darkTextSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignTokens.instaPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkTextPrimary,
          side: const BorderSide(color: _darkBorder, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DesignTokens.instaPink,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurfaceAlt,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
          color: _darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: _darkTextSecondary,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkSurface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: _darkSurfaceAlt,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(color: _darkTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _darkBorder, width: 1),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _darkSurfaceAlt,
        contentTextStyle: TextStyle(color: _darkTextPrimary),
        actionTextColor: DesignTokens.instaPink,
      ),
      dividerTheme: const DividerThemeData(
        color: _darkBorder,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _darkScaffold,
        selectedItemColor: DesignTokens.instaPink,
        unselectedItemColor: _darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkScaffold,
        indicatorColor: DesignTokens.instaPink.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: _darkTextSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? DesignTokens.instaPink : _darkTextSecondary,
          );
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: DesignTokens.instaPink,
        unselectedLabelColor: _darkTextSecondary,
        indicatorColor: DesignTokens.instaPink,
        dividerColor: _darkBorder,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28.0, fontWeight: FontWeight.bold, color: _darkTextPrimary),
        headlineMedium: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        headlineSmall: TextStyle(fontSize: 20.0, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        titleLarge: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        titleSmall: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        bodyLarge: TextStyle(fontSize: 16.0, color: _darkTextPrimary),
        bodyMedium: TextStyle(fontSize: 14.0, color: _darkTextSecondary),
        bodySmall: TextStyle(fontSize: 12.0, color: _darkTextMuted),
        labelLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600, color: _darkTextPrimary),
        labelMedium: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600, color: _darkTextSecondary),
        labelSmall: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w600, color: _darkTextMuted),
      ),
    );
  }

  static ThemeData highContrastDarkTheme() {
    return darkTheme.copyWith(
      colorScheme: darkTheme.colorScheme.copyWith(
        primary: Colors.white,
        secondary: Colors.white,
        surface: Colors.black,
        onSurface: Colors.white,
        onPrimary: Colors.black,
        outline: Colors.white,
        outlineVariant: Colors.white,
      ),
      appBarTheme: darkTheme.appBarTheme.copyWith(
        foregroundColor: Colors.white,
      ),
      dividerColor: Colors.white,
    );
  }
}
