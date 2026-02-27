import 'package:flutter/material.dart';

class InstagramTheme {
  // Instagram-inspired Color Palette
  static const Color primaryPink = Color(0xFFE4405F); // Instagram pink
  static const Color primaryPurple = Color(0xFF833AB4); // Instagram purple
  static const Color primaryOrange = Color(0xFFFCAF45); // Instagram orange
  static const Color primaryYellow = Color(0xFFFFDC80); // Instagram yellow
  
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundGrey = Color(0xFFFAFAFA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color borderGrey = Color(0xFFDBDBDB);
  static const Color dividerGrey = Color(0xFFEFEFEF);
  
  static const Color textBlack = Color(0xFF262626);
  static const Color textGrey = Color(0xFF8E8E8E);
  static const Color textLightGrey = Color(0xFFC7C7C7);
  static const Color textWhite = Color(0xFFFFFFFF);
  
  static const Color accentBlue = Color(0xFF0095F6);
  static const Color accentBlueDark = Color(0xFF00376B);
  static const Color errorRed = Color(0xFFED4956);
  static const Color successGreen = Color(0xFF00C853);
  
  // Instagram gradient
  static const LinearGradient instagramGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryPurple,
      primaryPink,
      primaryOrange,
      primaryYellow,
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  static const LinearGradient instagramGradientVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      primaryPurple,
      primaryPink,
      primaryOrange,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Theme Data
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundGrey,
      primaryColor: primaryPink,
      
      colorScheme: const ColorScheme.light(
        primary: primaryPink,
        secondary: accentBlue,
        surface: surfaceWhite,
        error: errorRed,
        onPrimary: textWhite,
        onSecondary: textWhite,
        onSurface: textBlack,
        onError: textWhite,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundWhite,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textBlack),
        titleTextStyle: TextStyle(
          color: textBlack,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderGrey, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundGrey,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderGrey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderGrey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        labelStyle: const TextStyle(color: textGrey),
        hintStyle: TextStyle(color: textGrey.withValues(alpha: 0.7)),
        prefixIconColor: textGrey,
        suffixIconColor: textGrey,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: textWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentBlue,
          side: const BorderSide(color: accentBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentBlue,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textBlack,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: textBlack,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          color: textBlack,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: textBlack,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: textBlack,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textBlack,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textGrey,
          fontSize: 14,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          color: textWhite,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: dividerGrey,
        thickness: 0.5,
        space: 24,
      ),
      
      iconTheme: const IconThemeData(
        color: textBlack,
        size: 24,
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundWhite,
        selectedItemColor: textBlack,
        unselectedItemColor: textGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
    );
  }

  // Helper method to get responsive padding
  static EdgeInsets responsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 600) {
      return const EdgeInsets.symmetric(horizontal: 64, vertical: 32);
    } else if (width > 400) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(16);
    }
  }

  // Helper method for gradient decoration
  static BoxDecoration gradientDecoration({
    double borderRadius = 12,
    bool isVertical = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: isVertical ? instagramGradientVertical : instagramGradient,
    );
  }

  // Helper method for card decoration
  static BoxDecoration cardDecoration({
    Color color = surfaceWhite,
    double borderRadius = 12,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder ? Border.all(color: borderGrey, width: 1) : null,
    );
  }
}
