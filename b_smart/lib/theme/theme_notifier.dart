import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeModeKey = 'theme_mode';
const String _kFontScaleKey = 'font_scale';
const String _kHighContrastKey = 'high_contrast_mode';
const String _kReduceMotionKey = 'reduce_motion';
const String _kDisableAutoPlayKey = 'disable_auto_play';

/// Holds appearance preferences and persists them.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({
    ThemeMode initialThemeMode = ThemeMode.system,
    double initialFontScale = 1.0,
    bool initialHighContrast = false,
    bool initialReduceMotion = false,
    bool initialDisableAutoPlay = false,
  })  : _themeMode = initialThemeMode,
        _fontScale = initialFontScale,
        _highContrastMode = initialHighContrast,
        _reduceMotion = initialReduceMotion,
        _disableAutoPlay = initialDisableAutoPlay;

  ThemeMode _themeMode;
  double _fontScale;
  bool _highContrastMode;
  bool _reduceMotion;
  bool _disableAutoPlay;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  double get fontScale => _fontScale;
  bool get highContrastMode => _highContrastMode;
  bool get reduceMotion => _reduceMotion;
  bool get disableAutoPlay => _disableAutoPlay;

  static Future<ThemeNotifier> create() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedThemeMode = prefs.getString(_kThemeModeKey);
      final storedFontScale = prefs.getDouble(_kFontScaleKey) ?? 1.0;
      final storedHighContrast = prefs.getBool(_kHighContrastKey) ?? false;
      final storedReduceMotion = prefs.getBool(_kReduceMotionKey) ?? false;
      final storedDisableAutoPlay = prefs.getBool(_kDisableAutoPlayKey) ?? false;
      final initialThemeMode = _parseThemeMode(storedThemeMode);
      return ThemeNotifier(
        initialThemeMode: initialThemeMode,
        initialFontScale: storedFontScale.clamp(0.85, 1.3),
        initialHighContrast: storedHighContrast,
        initialReduceMotion: storedReduceMotion,
        initialDisableAutoPlay: storedDisableAutoPlay,
      );
    } catch (e) {
      debugPrint('Error initializing ThemeNotifier: $e');
      return ThemeNotifier(initialThemeMode: ThemeMode.system);
    }
  }

  static ThemeMode _parseThemeMode(String? stored) {
    switch (stored) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeModeKey, value.name);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  Future<void> setDark(bool value) => setThemeMode(value ? ThemeMode.dark : ThemeMode.light);

  Future<void> setFontScale(double value) async {
    final clamped = value.clamp(0.85, 1.3);
    if (_fontScale == clamped) return;
    _fontScale = clamped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kFontScaleKey, clamped);
    } catch (e) {
      debugPrint('Error saving font scale preference: $e');
    }
  }

  Future<void> setHighContrastMode(bool value) async {
    if (_highContrastMode == value) return;
    _highContrastMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHighContrastKey, value);
    } catch (e) {
      debugPrint('Error saving high contrast preference: $e');
    }
  }

  Future<void> setReduceMotion(bool value) async {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kReduceMotionKey, value);
    } catch (e) {
      debugPrint('Error saving reduce motion preference: $e');
    }
  }

  Future<void> setDisableAutoPlay(bool value) async {
    if (_disableAutoPlay == value) return;
    _disableAutoPlay = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDisableAutoPlayKey, value);
    } catch (e) {
      debugPrint('Error saving autoplay preference: $e');
    }
  }

  Future<void> toggle() => setThemeMode(
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
      );
}
