import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

const String _kDarkModeKey = 'dark_mode';

/// Holds dark mode preference and persists it.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({bool initialDark = false}) : _isDark = initialDark;

  bool _isDark;
  bool get isDark => _isDark;

  static Future<ThemeNotifier> create() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_kDarkModeKey);
    bool initial;
    if (stored != null) {
      initial = stored;
    } else {
      final brightness = ui.PlatformDispatcher.instance.platformBrightness;
      initial = brightness == ui.Brightness.dark;
    }
    return ThemeNotifier(initialDark: initial);
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkModeKey, value);
  }

  Future<void> toggle() => setDark(!_isDark);
}
