import 'package:flutter/foundation.dart';

import 'api_client.dart';

const Map<String, String> kPrivacyVisibilityLabels = {
  'everyone': 'Everyone',
  'followers_only': 'Followers Only',
  'nobody': 'Nobody',
};

const List<String> kPrivacyVisibilityValues = <String>[
  'everyone',
  'followers_only',
  'nobody',
];

const Map<String, dynamic> _defaultProfileVisibility = <String, dynamic>{
  'profile': 'everyone',
  'posts': 'everyone',
  'stories': 'everyone',
  'pulse': 'everyone',
  'followers_list': 'everyone',
  'following_list': 'everyone',
};

const Map<String, dynamic> _defaultActivityStatus = <String, dynamic>{
  'show_online_status': true,
  'show_last_seen': true,
  'show_read_receipts': true,
};

const Map<String, dynamic> _defaultFollowSettings = <String, dynamic>{
  'allow_follow_requests': true,
  'auto_approve_follow_requests': false,
};

const Map<String, dynamic> _defaultSearchDiscovery = <String, dynamic>{
  'allow_search_by_username': true,
  'allow_search_by_email': false,
  'allow_search_by_phone': false,
  'appear_in_suggestions': true,
};

class PrivacySettingsData {
  final Map<String, dynamic> profileVisibility;
  final Map<String, dynamic> activityStatus;
  final Map<String, dynamic> followSettings;
  final String messagingPrivacy;
  final Map<String, dynamic> searchDiscovery;

  const PrivacySettingsData({
    required this.profileVisibility,
    required this.activityStatus,
    required this.followSettings,
    required this.messagingPrivacy,
    required this.searchDiscovery,
  });

  factory PrivacySettingsData.defaults() {
    return const PrivacySettingsData(
      profileVisibility: _defaultProfileVisibility,
      activityStatus: _defaultActivityStatus,
      followSettings: _defaultFollowSettings,
      messagingPrivacy: 'everyone',
      searchDiscovery: _defaultSearchDiscovery,
    );
  }

  factory PrivacySettingsData.fromApi(dynamic raw) {
    final source = _unwrapMap(raw);
    final defaults = PrivacySettingsData.defaults();

    Map<String, dynamic> readMap(String key, Map<String, dynamic> fallback) {
      final value = source[key] ?? source[_camelCase(key)];
      if (value is Map) {
        return _mergeMap(fallback, Map<String, dynamic>.from(value));
      }
      return Map<String, dynamic>.from(fallback);
    }

    final messagingValue =
        source['messaging_privacy'] ?? source['messagingPrivacy'];
    final messagingPrivacy = messagingValue is String &&
            messagingValue.trim().isNotEmpty
        ? messagingValue.trim()
        : defaults.messagingPrivacy;

    return PrivacySettingsData(
      profileVisibility:
          readMap('profile_visibility', _defaultProfileVisibility),
      activityStatus: readMap('activity_status', _defaultActivityStatus),
      followSettings: readMap('follow_settings', _defaultFollowSettings),
      messagingPrivacy: messagingPrivacy,
      searchDiscovery: readMap('search_discovery', _defaultSearchDiscovery),
    );
  }

  PrivacySettingsData copyWith({
    Map<String, dynamic>? profileVisibility,
    Map<String, dynamic>? activityStatus,
    Map<String, dynamic>? followSettings,
    String? messagingPrivacy,
    Map<String, dynamic>? searchDiscovery,
  }) {
    return PrivacySettingsData(
      profileVisibility: Map<String, dynamic>.from(
        profileVisibility ?? this.profileVisibility,
      ),
      activityStatus: Map<String, dynamic>.from(
        activityStatus ?? this.activityStatus,
      ),
      followSettings: Map<String, dynamic>.from(
        followSettings ?? this.followSettings,
      ),
      messagingPrivacy: messagingPrivacy ?? this.messagingPrivacy,
      searchDiscovery: Map<String, dynamic>.from(
        searchDiscovery ?? this.searchDiscovery,
      ),
    );
  }

  bool equals(PrivacySettingsData other) {
    return mapEquals(profileVisibility, other.profileVisibility) &&
        mapEquals(activityStatus, other.activityStatus) &&
        mapEquals(followSettings, other.followSettings) &&
        messagingPrivacy == other.messagingPrivacy &&
        mapEquals(searchDiscovery, other.searchDiscovery);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'profile_visibility': Map<String, dynamic>.from(profileVisibility),
        'activity_status': Map<String, dynamic>.from(activityStatus),
        'follow_settings': Map<String, dynamic>.from(followSettings),
        'messaging_privacy': messagingPrivacy,
        'search_discovery': Map<String, dynamic>.from(searchDiscovery),
      };

  static Map<String, dynamic> _unwrapMap(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    if (map['data'] is Map) {
      return Map<String, dynamic>.from(map['data'] as Map);
    }
    return map;
  }

  static Map<String, dynamic> _mergeMap(
    Map<String, dynamic> base,
    Map<String, dynamic> overrides,
  ) {
    return <String, dynamic>{...base, ...overrides};
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

class PrivacyApi {
  static final PrivacyApi _instance = PrivacyApi._internal();
  factory PrivacyApi() => _instance;
  PrivacyApi._internal();

  final ApiClient _client = ApiClient();

  Future<PrivacySettingsData> getPrivacySettings() async {
    final res = await _client.get('/privacy');
    return PrivacySettingsData.fromApi(res);
  }

  Future<Map<String, dynamic>> updateProfileVisibility(
    Map<String, dynamic> visibility,
  ) async {
    final res = await _client.patch(
      '/privacy/profile-visibility',
      body: visibility,
    );
    return _asMap(res);
  }

  Future<Map<String, dynamic>> updateActivityStatus(
    Map<String, dynamic> activityStatus,
  ) async {
    final res = await _client.patch(
      '/privacy/activity-status',
      body: activityStatus,
    );
    return _asMap(res);
  }

  Future<Map<String, dynamic>> updateFollowSettings(
    Map<String, dynamic> followSettings,
  ) async {
    final res = await _client.patch(
      '/privacy/follow-settings',
      body: followSettings,
    );
    return _asMap(res);
  }

  Future<Map<String, dynamic>> updateMessagingPrivacy(
    String messagingPrivacy,
  ) async {
    final res = await _client.patch(
      '/privacy/messaging',
      body: <String, dynamic>{'messaging_privacy': messagingPrivacy},
    );
    return _asMap(res);
  }

  Future<Map<String, dynamic>> updateSearchDiscovery(
    Map<String, dynamic> searchDiscovery,
  ) async {
    final res = await _client.patch(
      '/privacy/search-discovery',
      body: searchDiscovery,
    );
    return _asMap(res);
  }

  Map<String, dynamic> _asMap(dynamic res) {
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return <String, dynamic>{};
  }
}
