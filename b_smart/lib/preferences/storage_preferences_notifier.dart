import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kMobileDataSaverKey = 'storage_mobile_data_saver';
const String _kWifiOnlyDownloadsKey = 'storage_wifi_only_downloads';

class StoragePreferencesNotifier extends ChangeNotifier {
  StoragePreferencesNotifier({
    bool initialMobileDataSaver = false,
    bool initialWifiOnlyDownloads = false,
  })  : _mobileDataSaver = initialMobileDataSaver,
        _wifiOnlyDownloads = initialWifiOnlyDownloads;

  bool _mobileDataSaver;
  bool _wifiOnlyDownloads;

  bool get mobileDataSaver => _mobileDataSaver;
  bool get wifiOnlyDownloads => _wifiOnlyDownloads;

  static Future<StoragePreferencesNotifier> create() async {
    final notifier = StoragePreferencesNotifier();
    await notifier.hydrateFromPreferences();
    return notifier;
  }

  Future<void> hydrateFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mobileDataSaver = prefs.getBool(_kMobileDataSaverKey) ?? false;
      _wifiOnlyDownloads = prefs.getBool(_kWifiOnlyDownloadsKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing StoragePreferencesNotifier: $e');
    }
  }

  Future<void> setMobileDataSaver(bool value) async {
    if (_mobileDataSaver == value) return;
    _mobileDataSaver = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMobileDataSaverKey, value);
    } catch (e) {
      debugPrint('Error saving mobile data saver preference: $e');
    }
  }

  Future<void> setWifiOnlyDownloads(bool value) async {
    if (_wifiOnlyDownloads == value) return;
    _wifiOnlyDownloads = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kWifiOnlyDownloadsKey, value);
    } catch (e) {
      debugPrint('Error saving wifi only downloads preference: $e');
    }
  }
}
