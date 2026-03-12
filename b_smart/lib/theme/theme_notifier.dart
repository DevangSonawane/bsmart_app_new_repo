import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kDarkModeKey = 'dark_mode';

/// Holds dark mode preference and persists it.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({bool initialDark = false}) : _isDark = initialDark;

  bool _isDark;
  bool get isDark => _isDark;

  static Future<ThemeNotifier> create() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_kDarkModeKey);
      // Default app startup theme is always light unless user explicitly set it.
      final initial = stored ?? false;
      return ThemeNotifier(initialDark: initial);
    } catch (e) {
      debugPrint('Error initializing ThemeNotifier: $e');
      return ThemeNotifier(initialDark: false);
    }
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDarkModeKey, value);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  Future<void> toggle() => setDark(!_isDark);
}
