import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kAutoPlayVideosKey = 'content_autoplay_videos';
const String _kAutoPlayPulseKey = 'content_autoplay_pulse';

class ContentPreferencesNotifier extends ChangeNotifier {
  ContentPreferencesNotifier({
    bool initialAutoPlayVideos = true,
    bool initialAutoPlayPulse = true,
  })  : _autoPlayVideos = initialAutoPlayVideos,
        _autoPlayPulse = initialAutoPlayPulse;

  bool _autoPlayVideos;
  bool _autoPlayPulse;

  bool get autoPlayVideos => _autoPlayVideos;
  bool get autoPlayPulse => _autoPlayPulse;

  static Future<ContentPreferencesNotifier> create() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return ContentPreferencesNotifier(
        initialAutoPlayVideos: prefs.getBool(_kAutoPlayVideosKey) ?? true,
        initialAutoPlayPulse: prefs.getBool(_kAutoPlayPulseKey) ?? true,
      );
    } catch (e) {
      debugPrint('Error initializing ContentPreferencesNotifier: $e');
      return ContentPreferencesNotifier();
    }
  }

  Future<void> setAutoPlayVideos(bool value) async {
    if (_autoPlayVideos == value) return;
    _autoPlayVideos = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAutoPlayVideosKey, value);
    } catch (e) {
      debugPrint('Error saving content autoplay videos preference: $e');
    }
  }

  Future<void> setAutoPlayPulse(bool value) async {
    if (_autoPlayPulse == value) return;
    _autoPlayPulse = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAutoPlayPulseKey, value);
    } catch (e) {
      debugPrint('Error saving content autoplay pulse preference: $e');
    }
  }
}
