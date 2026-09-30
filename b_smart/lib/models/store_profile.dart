/// Storefront profile from `GET /api/users/:id/store-profile`.
///
/// Every field is optional: the endpoint is public and a seller may not have
/// filled the profile in yet.
class StoreProfile {
  final String storeName;
  final String storeType;
  final String about;
  final List<String> serviceAreas;
  final List<String> languages;
  final List<String> trustBadges;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final int productCount;
  final int serviceCount;
  final String memberSince;

  const StoreProfile({
    this.storeName = '',
    this.storeType = '',
    this.about = '',
    this.serviceAreas = const [],
    this.languages = const [],
    this.trustBadges = const [],
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.productCount = 0,
    this.serviceCount = 0,
    this.memberSince = '',
  });

  bool get isEmpty =>
      storeName.trim().isEmpty &&
      storeType.trim().isEmpty &&
      about.trim().isEmpty &&
      serviceAreas.isEmpty &&
      languages.isEmpty &&
      trustBadges.isEmpty;

  /// `PATCH /api/users/me/store-profile` accepts any subset of the fields, so
  /// only the ones that were actually edited are sent.
  Map<String, dynamic> toUpdateJson({
    List<String>? serviceAreas,
    List<String>? languages,
    List<String>? trustBadges,
    String? storeType,
  }) {
    return {
      if (serviceAreas != null) 'service_areas': serviceAreas,
      if (languages != null) 'languages': languages,
      if (trustBadges != null) 'trust_badges': trustBadges,
      if (storeType != null && storeType.trim().isNotEmpty)
        'store_type': storeType.trim(),
    };
  }

  /// Accepts either the bare store object or the full `{store: {...}}`
  /// envelope, so callers can pass a raw API response either way.
  factory StoreProfile.fromApiJson(Map<String, dynamic> json) {
    final map = json['store'] is Map
        ? (json['store'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : json;
    return StoreProfile(
      storeName: _text(map, const ['store_name', 'storeName']) ?? '',
      storeType: _text(map, const ['store_type', 'storeType']) ?? '',
      about: _text(map, const ['about', 'store_description', 'description']) ??
          '',
      serviceAreas: _stringList(
        map,
        const ['service_areas', 'serviceAreas'],
      ),
      languages: _stringList(map, const ['languages']),
      trustBadges: _stringList(map, const ['trust_badges', 'trustBadges']),
      followersCount:
          _int(map, const ['followers_count', 'followersCount']) ?? 0,
      followingCount:
          _int(map, const ['following_count', 'followingCount']) ?? 0,
      isFollowing:
          map['is_following'] == true || map['isFollowing'] == true,
      productCount: _int(map, const ['product_count', 'productCount']) ?? 0,
      serviceCount: _int(map, const ['service_count', 'serviceCount']) ?? 0,
      memberSince: _text(map, const ['member_since', 'memberSince']) ?? '',
    );
  }

  static String? _text(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return null;
  }

  static int? _int(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static List<String> _stringList(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is List) {
        final items = value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty && e != 'null')
            .toList();
        if (items.isNotEmpty) return items;
      }
      if (value is String && value.trim().isNotEmpty) {
        // Tolerate a comma-separated string.
        final items = value
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (items.isNotEmpty) return items;
      }
    }
    return const [];
  }
}
