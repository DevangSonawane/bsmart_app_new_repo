import 'api_client.dart';

const Map<String, bool> kNotificationSettingsDefaults = <String, bool>{
  'push_notifications': true,
  'likes': true,
  'comments': true,
  'replies': true,
  'mentions': true,
  'tags': true,
  'shares': true,
  'new_followers': true,
  'follow_requests': true,
  'new_messages': true,
  'message_requests': true,
};

class NotificationSettingsData {
  final Map<String, bool> values;

  const NotificationSettingsData._(this.values);

  factory NotificationSettingsData.defaults() {
    return const NotificationSettingsData._(kNotificationSettingsDefaults);
  }

  factory NotificationSettingsData.fromApi(dynamic raw) {
    final source = _unwrapMap(raw);
    final merged = <String, bool>{...kNotificationSettingsDefaults};

    for (final entry in merged.keys.toList(growable: false)) {
      final value = source[entry] ?? source[_camelCase(entry)];
      if (value != null) {
        merged[entry] = _asBool(value);
      }
    }

    return NotificationSettingsData._(merged);
  }

  bool operator [](String key) => values[key] ?? false;

  bool value(String key) => this[key];

  NotificationSettingsData copyWithValue(String key, bool value) {
    return NotificationSettingsData._(<String, bool>{
      ...values,
      key: value,
    });
  }

  int get enabledCount => values.values.where((v) => v).length;

  int get totalCount => values.length;

  Map<String, dynamic> toJson() {
    return values.map((key, value) => MapEntry(key, value));
  }

  static Map<String, dynamic> _unwrapMap(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    if (map['settings'] is Map) {
      return Map<String, dynamic>.from(map['settings'] as Map);
    }
    if (map['data'] is Map) {
      final data = Map<String, dynamic>.from(map['data'] as Map);
      if (data['settings'] is Map) {
        return Map<String, dynamic>.from(data['settings'] as Map);
      }
      return data;
    }
    return map;
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'yes' || s == 'on';
    }
    return false;
  }

  static String _camelCase(String value) {
    final parts = value.split('_');
    if (parts.isEmpty) return value;
    return parts.first +
        parts.skip(1).map((part) {
          if (part.isEmpty) return '';
          return part[0].toUpperCase() + part.substring(1);
        }).join();
  }
}

class NotificationSettingsApi {
  static final NotificationSettingsApi _instance =
      NotificationSettingsApi._internal();
  factory NotificationSettingsApi() => _instance;
  NotificationSettingsApi._internal();

  final ApiClient _client = ApiClient();

  Future<NotificationSettingsData> getSettings() async {
    final res = await _client.get('/settings/notifications');
    return NotificationSettingsData.fromApi(res);
  }

  Future<NotificationSettingsData> updateSetting(
    String key,
    bool value,
  ) async {
    final res = await _client.patch(
      '/settings/notifications',
      body: <String, dynamic>{key: value},
    );
    return NotificationSettingsData.fromApi(res);
  }
}
