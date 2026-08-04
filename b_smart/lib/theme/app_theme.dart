import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

class AppTheme {
  static const PageTransitionsTheme _noMotionTransitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: _NoMotionPageTransitionsBuilder(),
      TargetPlatform.iOS: _NoMotionPageTransitionsBuilder(),
      TargetPlatform.linux: _NoMotionPageTransitionsBuilder(),
      TargetPlatform.macOS: _NoMotionPageTransitionsBuilder(),
      TargetPlatform.windows: _NoMotionPageTransitionsBuilder(),
      TargetPlatform.fuchsia: _NoMotionPageTransitionsBuilder(),
    },
  );

  static const Color _darkScaffold = Color(0xFF000000);
  static const Color _darkSurface = Color(0xFF111111);
  static const Color _darkSurfaceAlt = Color(0xFF1A1A1A);
  static const Color _darkCard = Color(0xFF1E1E1E);
  static const Color _darkElevated = Color(0xFF262626);
  static const Color _darkBorder = Color(0xFF2A2A2A);
  static const Color _darkTextPrimary = Color(0xFFF5F5F5);
  static const Color _darkTextSecondary = Color(0xFFB3B3B3);
  static const Color _darkTextMuted = Color(0xFF7A7A7A);

  static ThemeData get theme => lightTheme();

  static ThemeData get darkTheme => themedDark();

  static ThemeData highContrastTheme() => lightTheme(highContrast: true);

  static ThemeData highContrastDarkTheme() => themedDark(highContrast: true);

  static ThemeData lightTheme({
    bool highContrast = false,
    bool reduceMotion = false,
  }) {
    final fontFamily = GoogleFonts.montserrat().fontFamily;
    final borderColor = highContrast ? Colors.black : const Color(0xFFE5E7EB);
    final onSurface = highContrast ? Colors.black : const Color(0xFF111827);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      primaryColor: highContrast ? Colors.black : DesignTokens.instaPurple,
      colorScheme: (highContrast
              ? const ColorScheme.light(
                  primary: Colors.black,
                  secondary: Colors.black,
                  surface: Colors.white,
                  onSurface: Colors.black,
                  onPrimary: Colors.white,
                  onSecondary: Colors.white,
                  outline: Colors.black,
                )
              : ColorScheme.fromSwatch().copyWith(
                  primary: DesignTokens.instaPurple,
                  secondary: DesignTokens.instaPink,
                ))
          .copyWith(error: const Color(0xFFE11D48)),
      scaffoldBackgroundColor: Colors.white,
      canvasColor: Colors.white,
      cardColor: Colors.white,
      dividerColor: borderColor,
      highlightColor: Colors.black.withValues(alpha: 0.03),
      splashColor: Colors.black.withValues(alpha: 0.04),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
      iconTheme: IconThemeData(color: onSurface),
      primaryIconTheme: IconThemeData(color: onSurface),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: highContrast ? Colors.black : DesignTokens.instaPink,
        selectionColor: (highContrast ? Colors.black : DesignTokens.instaPink)
            .withValues(alpha: 0.18),
        selectionHandleColor:
            highContrast ? Colors.black : DesignTokens.instaPink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: highContrast ? Colors.white : const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: highContrast ? Colors.black : DesignTokens.instaPink,
            width: 1.5,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFE11D48), width: 1),
        ),
        labelStyle: TextStyle(
            color: highContrast ? Colors.black : const Color(0xFF6B7280)),
        hintStyle: TextStyle(
            color: highContrast ? Colors.black54 : const Color(0xFF9CA3AF)),
        prefixIconColor: highContrast ? Colors.black : const Color(0xFF6B7280),
        suffixIconColor: highContrast ? Colors.black : const Color(0xFF6B7280),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              highContrast ? Colors.black : DesignTokens.instaPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: highContrast ? Colors.black : DesignTokens.instaPink,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
        contentTextStyle: TextStyle(
          color: highContrast ? Colors.black : const Color(0xFF6B7280),
          fontSize: 14,
          fontFamily: fontFamily,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: highContrast ? Colors.black : const Color(0xFF111827),
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: highContrast ? Colors.white : DesignTokens.instaPink,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: highContrast ? Colors.black : DesignTokens.instaPink,
        unselectedItemColor: const Color(0xFF6B7280),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: (highContrast ? Colors.black : DesignTokens.instaPink)
            .withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(
            color: highContrast ? Colors.black : const Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? (highContrast ? Colors.black : DesignTokens.instaPink)
                : const Color(0xFF6B7280),
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: highContrast ? Colors.black : DesignTokens.instaPink,
        unselectedLabelColor: const Color(0xFF6B7280),
        indicatorColor: highContrast ? Colors.black : DesignTokens.instaPink,
        dividerColor: borderColor,
      ),
      textTheme: GoogleFonts.montserratTextTheme(
        TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
          headlineMedium: TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          headlineSmall: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          titleMedium: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          titleSmall: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          bodyLarge: TextStyle(
            fontSize: 16.0,
            color: onSurface,
          ),
          bodyMedium: TextStyle(
            fontSize: 14.0,
            color: highContrast ? Colors.black : const Color(0xFF6B7280),
          ),
          bodySmall: TextStyle(
            fontSize: 12.0,
            color: highContrast ? Colors.black54 : const Color(0xFF7A7A7A),
          ),
          labelLarge: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          labelMedium: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: highContrast ? Colors.black : const Color(0xFF6B7280),
          ),
          labelSmall: TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
            color: highContrast ? Colors.black54 : const Color(0xFF7A7A7A),
          ),
        ),
      ),
      primaryTextTheme: GoogleFonts.montserratTextTheme(
        TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
          headlineMedium: TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          headlineSmall: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          titleLarge: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          titleMedium: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          titleSmall: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          bodyLarge: TextStyle(
            fontSize: 16.0,
            color: onSurface,
          ),
          bodyMedium: TextStyle(
            fontSize: 14.0,
            color: highContrast ? Colors.black : const Color(0xFF6B7280),
          ),
          bodySmall: TextStyle(
            fontSize: 12.0,
            color: highContrast ? Colors.black54 : const Color(0xFF7A7A7A),
          ),
          labelLarge: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          labelMedium: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: highContrast ? Colors.black : const Color(0xFF6B7280),
          ),
          labelSmall: TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
            color: highContrast ? Colors.black54 : const Color(0xFF7A7A7A),
          ),
        ),
      ),
      pageTransitionsTheme:
          reduceMotion ? _noMotionTransitions : const PageTransitionsTheme(),
      visualDensity: VisualDensity.standard,
    );
  }

  static ThemeData themedDark({
    bool highContrast = false,
    bool reduceMotion = false,
  }) {
    final fontFamily = GoogleFonts.montserrat().fontFamily;
    final borderColor = highContrast ? Colors.white : _darkBorder;
    final surfaceColor = highContrast ? Colors.black : _darkSurface;
    final cardColor = highContrast ? Colors.black : _darkCard;
    final elevatedColor = highContrast ? Colors.black : _darkElevated;
    final surfaceAltColor = highContrast ? Colors.black : _darkSurfaceAlt;
    final primaryColor = highContrast ? Colors.white : DesignTokens.instaPink;

    final colorScheme = const ColorScheme.dark().copyWith(
      primary: primaryColor,
      secondary: highContrast ? Colors.white : DesignTokens.instaPurple,
      surface: surfaceColor,
      onSurface: Colors.white,
      onPrimary: highContrast ? Colors.black : Colors.white,
      onSecondary: Colors.white,
      error: const Color(0xFFFF5C7A),
      onError: Colors.white,
      outline: borderColor,
      outlineVariant: borderColor,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: surfaceColor,
      surfaceContainer: surfaceAltColor,
      surfaceContainerHigh: cardColor,
      surfaceContainerHighest: elevatedColor,
      surfaceDim: Colors.black,
      surfaceBright: elevatedColor,
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
      fontFamily: fontFamily,
      primaryColor: primaryColor,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      cardColor: cardColor,
      dividerColor: borderColor,
      highlightColor: Colors.white.withValues(alpha: 0.04),
      splashColor: Colors.white.withValues(alpha: 0.06),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.black,
        foregroundColor: _darkTextPrimary,
        iconTheme: const IconThemeData(color: _darkTextPrimary),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: _darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
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
        fillColor: surfaceAltColor,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: highContrast ? Colors.white : DesignTokens.instaPink,
            width: 1.5,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFFF5C7A), width: 1),
        ),
        labelStyle: const TextStyle(color: _darkTextSecondary),
        hintStyle: const TextStyle(color: _darkTextMuted),
        prefixIconColor: _darkTextSecondary,
        suffixIconColor: _darkTextSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:
              highContrast ? Colors.white : DesignTokens.instaPurple,
          foregroundColor: highContrast ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _darkTextPrimary,
          side: BorderSide(color: borderColor, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: highContrast ? Colors.white : DesignTokens.instaPink,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceAltColor,
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surfaceColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceAltColor,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(color: _darkTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: _darkSurfaceAlt,
        contentTextStyle: TextStyle(color: _darkTextPrimary),
        actionTextColor: DesignTokens.instaPink,
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
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
          const TextStyle(
            color: _darkTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
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
      textTheme: GoogleFonts.montserratTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            color: _darkTextPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          headlineSmall: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          titleSmall: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          bodyLarge: TextStyle(fontSize: 16.0, color: _darkTextPrimary),
          bodyMedium: TextStyle(fontSize: 14.0, color: _darkTextSecondary),
          bodySmall: TextStyle(fontSize: 12.0, color: _darkTextMuted),
          labelLarge: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          labelMedium: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: _darkTextSecondary,
          ),
          labelSmall: TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
            color: _darkTextMuted,
          ),
        ),
      ),
      primaryTextTheme: GoogleFonts.montserratTextTheme(
        const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28.0,
            fontWeight: FontWeight.bold,
            color: _darkTextPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          headlineSmall: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          titleSmall: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          bodyLarge: TextStyle(fontSize: 16.0, color: _darkTextPrimary),
          bodyMedium: TextStyle(fontSize: 14.0, color: _darkTextSecondary),
          bodySmall: TextStyle(fontSize: 12.0, color: _darkTextMuted),
          labelLarge: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.w600,
            color: _darkTextPrimary,
          ),
          labelMedium: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: _darkTextSecondary,
          ),
          labelSmall: TextStyle(
            fontSize: 11.0,
            fontWeight: FontWeight.w600,
            color: _darkTextMuted,
          ),
        ),
      ),
      pageTransitionsTheme:
          reduceMotion ? _noMotionTransitions : const PageTransitionsTheme(),
    );
  }
}

class _NoMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoMotionPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
