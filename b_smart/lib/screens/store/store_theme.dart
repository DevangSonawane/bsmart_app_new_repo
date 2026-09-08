import 'package:flutter/material.dart';

class BStoreTheme {
  BStoreTheme._();

  static ThemeData data(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: BStoreColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: BStoreColors.primary,
        secondary: BStoreColors.accentPurple,
        surface: BStoreColors.surface,
        onPrimary: Colors.white,
        onSurface: BStoreColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: BStoreTypography.fontFamily,
        bodyColor: BStoreColors.textPrimary,
        displayColor: BStoreColors.textPrimary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: BStoreButtons.filled(),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: BStoreButtons.outlined(),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (_) => Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BStoreColors.primary
              : BStoreColors.border,
        ),
      ),
    );
  }
}

class BStoreColors {
  BStoreColors._();

  static const background = Color(0xFFFFFCF8);
  static const backgroundAlt = Color(0xFFFFFEFC);
  static const surface = Colors.white;
  static const surfaceTint = Color(0xFFEAF7F6);
  static const primary = Color(0xFF078D92);
  static const primarySoft = Color(0xFFE9F6F5);
  static const accentPurple = Color(0xFF684AC8);
  static const accentPurpleSoft = Color(0xFFF1ECFA);
  static const textPrimary = Color(0xFF060D35);
  static const textStrong = Color(0xFF071238);
  static const textSecondary = Color(0xFF29304D);
  static const textMuted = Color(0xFF596174);
  static const textSoft = Color(0xFF55607A);
  static const border = Color(0xFFE3E7ED);
  static const borderSoft = Color(0xFFE9ECEF);
  static const divider = Color(0xFFE1E5EA);
  static const blue = Color(0xFF2196F3);
  static const paleBlue = Color(0xFFEAF5FF);
  static const cardWarm = Color(0xFFEAD8CC);
  static const visaBlue = Color(0xFF2442B5);
}

class BStoreTypography {
  BStoreTypography._();

  static const fontFamily = 'Montserrat';

  static const wordmark = TextStyle(
    fontSize: 25,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
  );

  static const screenTitle = TextStyle(
    color: BStoreColors.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w900,
  );

  static const sectionTitle = TextStyle(
    color: BStoreColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w900,
  );

  static const body = TextStyle(
    color: BStoreColors.textSecondary,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  static const label = TextStyle(
    color: BStoreColors.textMuted,
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
  );

  static const button = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w900,
  );
}

class BStoreRadii {
  BStoreRadii._();

  static const button = 10.0;
  static const card = 12.0;
  static const cardLarge = 16.0;
  static const pill = 7.0;
}

class BStoreSpacing {
  BStoreSpacing._();

  static const screenX = 16.0;
  static const gapXs = 4.0;
  static const gapSm = 8.0;
  static const gapMd = 12.0;
  static const gapLg = 16.0;
  static const gapXl = 18.0;
}

class BStoreDecorations {
  BStoreDecorations._();

  static BoxDecoration card({double radius = BStoreRadii.card}) {
    return BoxDecoration(
      color: BStoreColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: BStoreColors.borderSoft),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.055),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static BoxDecoration topPanel() {
    return BoxDecoration(
      color: BStoreColors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, -8),
        ),
      ],
    );
  }
}

class BStoreButtons {
  BStoreButtons._();

  static ButtonStyle filled({
    Color background = BStoreColors.primary,
    double radius = BStoreRadii.button,
    EdgeInsetsGeometry? padding,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: background,
      foregroundColor: Colors.white,
      padding: padding,
      textStyle: BStoreTypography.button,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  static ButtonStyle outlined({
    Color foreground = BStoreColors.textPrimary,
    Color border = BStoreColors.divider,
    double radius = BStoreRadii.button,
    EdgeInsetsGeometry? padding,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foreground,
      side: BorderSide(color: border),
      padding: padding,
      textStyle: BStoreTypography.button,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class StorePalette {
  StorePalette._();

  static const blue = BStoreColors.blue;
  static const paleBlue = BStoreColors.paleBlue;
  static const background = BStoreColors.background;
  static const primary = BStoreColors.primary;
  static const purple = BStoreColors.accentPurple;
  static const text = BStoreColors.textPrimary;
  static const mutedText = BStoreColors.textMuted;
  static const border = BStoreColors.border;
}
