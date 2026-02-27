import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../models/auth/device_session_model.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;

  DeviceService._internal();

  DeviceInfo? _cachedDeviceInfo;
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  String get _platformLabel {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
    // ignore: dead_code - fallback for any future platform value
    return 'unknown';
  }

  // Get device information (works on all platforms including web)
  Future<DeviceInfo> getDeviceInfo() async {
    if (_cachedDeviceInfo != null) {
      return _cachedDeviceInfo!;
    }

    try {
      String deviceId;
      String deviceName;
      String deviceType;
      String? deviceFingerprint;

      if (kIsWeb) {
        deviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
        deviceName = 'Web Browser';
        deviceType = 'web';
        deviceFingerprint = _generateFingerprint({'platform': 'web', 'id': deviceId});
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.id;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        deviceType = 'Android';
        deviceFingerprint = _generateFingerprint({
          'id': androidInfo.id,
          'brand': androidInfo.brand,
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
        });
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
        deviceName = '${iosInfo.name} (${iosInfo.model})';
        deviceType = 'iOS';
        deviceFingerprint = _generateFingerprint({
          'id': iosInfo.identifierForVendor ?? 'unknown',
          'name': iosInfo.name,
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
        });
      } else {
        deviceId = '${_platformLabel}_${DateTime.now().millisecondsSinceEpoch}';
        deviceName = 'Unknown Device';
        deviceType = _platformLabel;
        deviceFingerprint = _generateFingerprint({'os': _platformLabel, 'id': deviceId});
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final userAgent =
          '${packageInfo.appName}/${packageInfo.version} ($deviceType)';

      _cachedDeviceInfo = DeviceInfo(
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        deviceFingerprint: deviceFingerprint,
        ipAddress: null,
        userAgent: userAgent,
      );

      return _cachedDeviceInfo!;
    } catch (e) {
      return DeviceInfo(
        deviceId: '${_platformLabel}_fallback',
        deviceName: 'Unknown Device',
        deviceType: _platformLabel,
        deviceFingerprint: null,
        ipAddress: null,
        userAgent: 'b_smart/1.0.0',
      );
    }
  }

  // Generate device fingerprint hash
  String _generateFingerprint(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Get or create device session
  Future<DeviceSession?> getOrCreateDeviceSession(String userId) async {
    try {
      final deviceInfo = await getDeviceInfo();
      // TODO: Replace with REST API call when available
      // For now, return a mock session
      return DeviceSession(
        id: 'mock-session-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        deviceId: deviceInfo.deviceId,
        deviceName: deviceInfo.deviceName,
        deviceType: deviceInfo.deviceType,
        lastActiveAt: DateTime.now(),
        isTrusted: true,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  // Mark device as trusted
  Future<void> markDeviceAsTrusted(String deviceId) async {
    // TODO: Replace with REST API call
  }

  // Check if device is trusted
  Future<bool> isDeviceTrusted(String deviceId) async {
    // TODO: Replace with REST API call
    return true; // Default to trusted for now to avoid blocking users
  }

  // Detect suspicious login (different device, IP, etc.)
  Future<bool> isSuspiciousLogin(String userId, String deviceId) async {
    // TODO: Replace with REST API call
    return false; // Default to safe
  }
}
