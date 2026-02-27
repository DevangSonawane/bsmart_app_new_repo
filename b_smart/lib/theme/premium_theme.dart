import 'package:flutter/material.dart';

class PremiumTheme {
  // Premium Color Palette
  static const Color primaryBlack = Color(0xFF000000);
  static const Color darkCharcoal = Color(0xFF121212);
  static const Color deepGrey = Color(0xFF1E1E1E);
  static const Color softGrey = Color(0xFF2C2C2C);
  
  static const Color goldAccent = Color(0xFFD4AF37); // Classic Gold
  static const Color champagneGold = Color(0xFFF7E7CE);
  static const Color mutedGold = Color(0xFFC5A059);
  
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGrey = Color(0xFFB0B0B0);
  static const Color errorRed = Color(0xFFCF6679);

  // Gradients
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      goldAccent,
      mutedGold,
    ],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      primaryBlack,
      darkCharcoal,
    ],
  );

  // Theme Data
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryBlack,
      primaryColor: goldAccent,
      
      colorScheme: const ColorScheme.dark(
        primary: goldAccent,
        secondary: mutedGold,
        surface: deepGrey,
        // background: primaryBlack, // Deprecated
        error: errorRed,
        onPrimary: primaryBlack, // Text on gold should be black
        onSecondary: primaryBlack,
        onSurface: textWhite,
        // onBackground: textWhite, // Deprecated
        onError: primaryBlack,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textWhite),
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontFamily: 'Poppins', // Assuming standard font or system font for now
        ),
      ),

      cardTheme: CardThemeData(
        color: deepGrey,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: softGrey.withValues(alpha: 0.5), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: deepGrey,
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: softGrey, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: goldAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed, width: 1),
        ),
        labelStyle: const TextStyle(color: textGrey),
        hintStyle: TextStyle(color: textGrey.withValues(alpha: 0.5)),
        prefixIconColor: textGrey,
        suffixIconColor: goldAccent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldAccent,
          foregroundColor: primaryBlack,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldAccent,
          side: const BorderSide(color: goldAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: goldAccent,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textWhite,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: textWhite,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          color: textWhite,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        headlineMedium: TextStyle(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle( // For app bar titles, etc.
          color: textWhite,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textWhite,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textGrey,
          fontSize: 14,
          height: 1.5,
        ),
        labelLarge: TextStyle( // For buttons
          color: primaryBlack,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      dividerTheme: const DividerThemeData(
        color: softGrey,
        thickness: 1,
        space: 24,
      ),
      
      iconTheme: const IconThemeData(
        color: textWhite,
        size: 24,
      ),
      
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: deepGrey,
        selectedItemColor: goldAccent,
        unselectedItemColor: textGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  // Helper method to get responsive padding
  static EdgeInsets responsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 600) {
      return const EdgeInsets.symmetric(horizontal: 64, vertical: 32);
    } else if (width > 400) {
      return const EdgeInsets.all(32);
    } else {
      return const EdgeInsets.all(24); // More breathing room
    }
  }

  // Helper method for Clay Decoration
  static BoxDecoration clayDecoration({
    Color color = deepGrey,
    double borderRadius = 24,
    bool isPressed = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(Colors.white.withValues(alpha: 0.1), color),
          color,
          color,
          Color.alphaBlend(Colors.black.withValues(alpha: 0.2), color),
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ),
      boxShadow: isPressed
          ? [] // No shadow when pressed (or inner shadow if we could)
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(6, 6),
                blurRadius: 16,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05),
                offset: const Offset(-6, -6),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
    );
  }
}
