import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TimezoneSnapshot {
  final String name;
  final int offsetMinutes;
  final DateTime capturedAt;

  const TimezoneSnapshot({
    required this.name,
    required this.offsetMinutes,
    required this.capturedAt,
  });

  String get offsetLabel {
    final minutes = offsetMinutes;
    final sign = minutes >= 0 ? '+' : '-';
    final absMinutes = minutes.abs();
    final hours = absMinutes ~/ 60;
    final remainder = absMinutes % 60;
    return 'UTC$sign${hours.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
  }
}

class TimezoneService {
  TimezoneService._();

  static final TimezoneService instance = TimezoneService._();

  static const String _prefsNameKey = 'user_timezone_name';
  static const String _prefsOffsetKey = 'user_timezone_offset_minutes';
  static const String _prefsCapturedAtKey = 'user_timezone_captured_at';
  static const String _prefsUserIdKey = 'user_timezone_user_id';

  Future<TimezoneSnapshot> captureDeviceTimezone({String? userId}) async {
    final now = DateTime.now();
    final snapshot = TimezoneSnapshot(
      name: now.timeZoneName,
      offsetMinutes: now.timeZoneOffset.inMinutes,
      capturedAt: now,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsNameKey, snapshot.name);
      await prefs.setInt(_prefsOffsetKey, snapshot.offsetMinutes);
      await prefs.setString(
        _prefsCapturedAtKey,
        snapshot.capturedAt.toIso8601String(),
      );
      if (userId != null && userId.trim().isNotEmpty) {
        await prefs.setString(_prefsUserIdKey, userId.trim());
      }
    } catch (e) {
      debugPrint('TimezoneService.captureDeviceTimezone failed: $e');
    }

    return snapshot;
  }

  Future<TimezoneSnapshot?> readStoredTimezone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_prefsNameKey);
      final offset = prefs.getInt(_prefsOffsetKey);
      final capturedAt = prefs.getString(_prefsCapturedAtKey);
      if (name == null || offset == null || capturedAt == null) return null;
      return TimezoneSnapshot(
        name: name,
        offsetMinutes: offset,
        capturedAt: DateTime.tryParse(capturedAt) ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('TimezoneService.readStoredTimezone failed: $e');
      return null;
    }
  }

  DateTime? toLocalDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.isUtc ? raw.toLocal() : raw;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  String formatDateTime(
    dynamic raw, {
    String pattern = 'dd MMM yyyy, hh:mm a',
    String locale = 'en_IN',
  }) {
    final dt = toLocalDateTime(raw);
    if (dt == null) return '';
    return DateFormat(pattern, locale).format(dt);
  }

  String formatDate(
    dynamic raw, {
    String pattern = 'dd MMM yyyy',
    String locale = 'en_IN',
  }) {
    final dt = toLocalDateTime(raw);
    if (dt == null) return '';
    return DateFormat(pattern, locale).format(dt);
  }

  String formatTime(
    dynamic raw, {
    String pattern = 'h:mm a',
    String locale = 'en_IN',
  }) {
    final dt = toLocalDateTime(raw);
    if (dt == null) return '';
    return DateFormat(pattern, locale).format(dt);
  }

  String relativeTime(dynamic raw) {
    final dt = toLocalDateTime(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatDate(dt);
  }

  String relativeTimeShort(dynamic raw) {
    final dt = toLocalDateTime(raw);
    if (dt == null) return '';
    return formatPostTimestamp(dt);
  }

  String formatPostTimestamp(dynamic raw) {
    final dt = toLocalDateTime(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    }
    if (diff.inDays < 7) {
      final days = diff.inDays;
      return days == 1 ? '1 day ago' : '$days days ago';
    }
    if (diff.inDays < 14) return '1 week ago';

    if (dt.year == now.year) {
      return DateFormat('d MMM', 'en_IN').format(dt);
    }
    return DateFormat('d MMM yyyy', 'en_IN').format(dt);
  }
}
