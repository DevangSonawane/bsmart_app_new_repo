import '../config/api_config.dart';

class Ad {
  final String id;
  final String companyId;
  final String companyName;
  final String? companyLogo;
  final String title;
  final String description;
  final String? caption;
  final String? category;
  final List<String> hashtags;
  final String? videoUrl;
  final String? imageUrl;
  final int coinReward; // Ad-specific reward
  final int watchDurationSeconds; // Required watch duration
  final int maxRewardableViews;
  final int currentViews;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final bool isLikedByMe;
  final bool isDislikedByMe;
  final bool isSavedByMe;
  final String? userId;
  final String? userName;
  final String? userAvatarUrl;
  final String? vendorBusinessName;
  final int totalBudgetCoins;
  final List<String> targetLocations;
  final List<String> targetLanguages;
  final List<String> targetCategories;
  final String? targetLocation;
  final bool isVerified;
  final String? websiteUrl;
  final DateTime createdAt;
  final bool isActive;

  Ad({
    required this.id,
    required this.companyId,
    required this.companyName,
    this.companyLogo,
    required this.title,
    required this.description,
    this.caption,
    this.category,
    this.hashtags = const [],
    this.videoUrl,
    this.imageUrl,
    required this.coinReward,
    required this.watchDurationSeconds,
    required this.maxRewardableViews,
    this.currentViews = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.isLikedByMe = false,
    this.isDislikedByMe = false,
    this.isSavedByMe = false,
    this.userId,
    this.userName,
    this.userAvatarUrl,
    this.vendorBusinessName,
    this.totalBudgetCoins = 0,
    this.targetLocations = const [],
    this.targetLanguages = const [],
    this.targetCategories = const [],
    this.targetLocation,
    this.isVerified = false,
    this.websiteUrl,
    required this.createdAt,
    this.isActive = true,
  });

  factory Ad.fromApi(Map<String, dynamic> raw) {
    final vendor =
        raw['vendor_id'] is Map ? Map<String, dynamic>.from(raw['vendor_id'] as Map) : <String, dynamic>{};
    final user =
        raw['user_id'] is Map ? Map<String, dynamic>.from(raw['user_id'] as Map) : <String, dynamic>{};
    final userStatus = raw['user_status'] is Map
        ? Map<String, dynamic>.from(raw['user_status'] as Map)
        : <String, dynamic>{};
    final stats = raw['stats'] is Map ? Map<String, dynamic>.from(raw['stats'] as Map) : <String, dynamic>{};

    final media = _asList(raw['media']);
    String? videoUrl;
    String? imageUrl;
    for (final item in media) {
      final m = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
      final type = (m['media_type'] ?? m['type'] ?? '').toString().toLowerCase();
      final url = _resolveMediaUrl(m);
      if (url == null || url.isEmpty) continue;
      if (type == 'video' || url.toLowerCase().endsWith('.mp4') || url.toLowerCase().endsWith('.mov')) {
        videoUrl ??= url;
      } else {
        imageUrl ??= url;
      }
    }

    imageUrl ??= _normalizeUrl(
      raw['image'] ?? raw['imageUrl'] ?? raw['image_url'] ?? raw['thumbnail'] ?? raw['thumbnailUrl'],
    );
    videoUrl ??= _normalizeUrl(raw['video'] ?? raw['videoUrl'] ?? raw['video_url']);

    final companyName = (vendor['business_name'] ??
            vendor['name'] ??
            raw['business_name'] ??
            raw['vendor_name'] ??
            raw['advertiser_name'] ??
            raw['company_name'] ??
            raw['companyName'] ??
            user['username'] ??
            raw['username'] ??
            user['full_name'] ??
            'Advertiser')
        .toString();

    final category = raw['category'];
    final categories = <String>[
      ..._asStringList(raw['categories']),
      ..._asStringList(raw['targetCategories']),
      ..._asStringList(raw['target_categories']),
      if (category != null && category.toString().trim().isNotEmpty) category.toString().trim(),
    ];

    return Ad(
      id: (raw['_id'] ?? raw['id'] ?? '').toString(),
      companyId: (vendor['_id'] ?? vendor['id'] ?? raw['company_id'] ?? raw['companyId'] ?? '').toString(),
      companyName: companyName,
      companyLogo: _normalizeUrl(vendor['logo'] ?? vendor['logo_url'] ?? user['avatar_url'] ?? raw['company_logo']),
      title: (raw['title'] ?? raw['headline'] ?? raw['name'] ?? companyName).toString(),
      description: (raw['description'] ?? raw['caption'] ?? '').toString(),
      caption: _asNullableString(raw['caption']),
      category: _asNullableString(raw['category']),
      hashtags: _asStringList(raw['hashtags']),
      videoUrl: videoUrl,
      imageUrl: imageUrl,
      coinReward:
          _toInt(raw['coins_reward'] ?? raw['coin_reward'] ?? raw['coinReward'] ?? raw['reward_coins'] ?? raw['reward']) ??
              0,
      watchDurationSeconds:
          _toInt(raw['watch_duration_seconds'] ?? raw['watchDurationSeconds'] ?? raw['duration']) ?? 15,
      maxRewardableViews:
          _toInt(raw['max_rewardable_views'] ?? raw['maxRewardableViews'] ?? raw['max_views']) ?? 0,
      currentViews: _toInt(raw['likes_count'] ?? raw['views_count'] ?? raw['currentViews']) ?? 0,
      likesCount: _toInt(raw['likes_count'] ?? raw['likesCount'] ?? stats['likes']) ?? 0,
      commentsCount: _toInt(raw['comments_count'] ?? raw['commentsCount'] ?? stats['comments']) ??
          (_asList(raw['comments']).length),
      sharesCount: _toInt(raw['shares_count'] ?? raw['sharesCount'] ?? stats['shares']) ?? 0,
      isLikedByMe:
          (raw['is_liked_by_me'] ?? raw['isLikedByMe'] ?? userStatus['is_liked'] ?? userStatus['liked'] ?? false) ==
              true,
      isDislikedByMe: (raw['is_disliked_by_me'] ??
              raw['isDislikedByMe'] ??
              userStatus['is_disliked'] ??
              userStatus['disliked'] ??
              false) ==
          true,
      isSavedByMe:
          (raw['is_saved_by_me'] ?? raw['isSavedByMe'] ?? userStatus['is_saved'] ?? userStatus['saved'] ?? false) ==
              true,
      userId: (user['_id'] ??
              user['id'] ??
              ((raw['user_id'] is String || raw['user_id'] is num) ? raw['user_id'] : null) ??
              raw['userId'])
          ?.toString(),
      userName: _asNullableString(user['username'] ?? user['full_name']),
      userAvatarUrl: _normalizeUrl(user['avatar_url'] ?? user['avatarUrl'] ?? raw['avatar_url'] ?? raw['avatar']),
      vendorBusinessName: _asNullableString(
        vendor['business_name'] ?? vendor['name'] ?? raw['business_name'] ?? raw['vendor_name'] ?? raw['advertiser_name'],
      ),
      totalBudgetCoins: _toInt(raw['total_budget_coins'] ?? raw['totalBudgetCoins']) ?? 0,
      targetLocations: [
        ..._asStringList(raw['target_location']),
        ..._asStringList(raw['targetLocation']),
      ],
      targetLanguages: [
        ..._asStringList(raw['target_language']),
        ..._asStringList(raw['target_languages']),
        ..._asStringList(raw['targetLanguages']),
      ],
      targetCategories: categories.toSet().toList(),
      targetLocation: (raw['target_location'] ?? raw['targetLocation'] ?? '').toString().trim().isEmpty
          ? null
          : (raw['target_location'] ?? raw['targetLocation']).toString(),
      isVerified: (vendor['is_verified'] ?? vendor['verified'] ?? false) == true,
      websiteUrl: (raw['website_url'] ?? raw['websiteUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (raw['website_url'] ?? raw['websiteUrl']).toString(),
      createdAt: _parseDate(raw['createdAt'] ?? raw['created_at']) ?? DateTime.now(),
      isActive: (raw['is_active'] ?? raw['isActive'] ?? true) == true,
    );
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return [value];
    return const [];
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }
    return const [];
  }

  static String? _resolveMediaUrl(Map<String, dynamic> media) {
    final file = media['file'];
    if (file is Map) {
      final nested = _normalizeUrl(file['fileUrl'] ?? file['file_url'] ?? file['url'] ?? file['path']);
      if (nested != null && nested.isNotEmpty) return nested;
    } else if (file is String) {
      final nested = _normalizeUrl(file);
      if (nested != null && nested.isNotEmpty) return nested;
    }

    final direct = _normalizeUrl(
      media['fileUrl'] ?? media['file_url'] ?? media['url'] ?? media['image'] ?? media['imageUrl'] ?? media['path'],
    );
    if (direct != null && direct.isNotEmpty) return direct;

    final name = media['fileName']?.toString().trim();
    if (name != null && name.isNotEmpty && !_isPlaceholderToken(name)) {
      return '${_apiOrigin()}/uploads/$name';
    }
    return null;
  }

  static String? _normalizeUrl(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    if (_isPlaceholderToken(raw)) {
      return null;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/uploads/')) return '${_apiOrigin()}$raw';
    if (raw.startsWith('uploads/')) return '${_apiOrigin()}/$raw';
    if (raw.startsWith('/')) return '${_apiOrigin()}$raw';
    return '${_apiOrigin()}/uploads/$raw';
  }

  static bool _isPlaceholderToken(String value) {
    final lowered = value.trim().toLowerCase();
    return lowered == 'null' ||
        lowered == 'string' ||
        lowered == 'undefined' ||
        lowered == 'none' ||
        lowered == 'n/a' ||
        lowered == 'na';
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _asNullableString(dynamic value) {
    final s = value?.toString().trim();
    if (s == null || s.isEmpty || s == 'null') return null;
    return s;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _apiOrigin() {
    var base = ApiConfig.baseUrl.trim().replaceAll(RegExp(r'\/+$'), '');
    if (base.toLowerCase().endsWith('/api')) {
      base = base.substring(0, base.length - 4);
    }
    return base;
  }
}

class AdCompany {
  final String id;
  final String name;
  final String? logo;
  final String description;
  final String? websiteUrl;
  final bool isVerified;
  final List<Ad> activeAds;

  AdCompany({
    required this.id,
    required this.name,
    this.logo,
    required this.description,
    this.websiteUrl,
    this.isVerified = false,
    this.activeAds = const [],
  });
}

class AdWatchSession {
  final String adId;
  final DateTime startTime;
  final int totalDuration;
  final int watchedDuration;
  final bool isMuted;
  final int pauseCount;
  final int totalPauseDuration;
  final bool isInForeground;
  final double watchPercentage;

  AdWatchSession({
    required this.adId,
    required this.startTime,
    required this.totalDuration,
    this.watchedDuration = 0,
    this.isMuted = false,
    this.pauseCount = 0,
    this.totalPauseDuration = 0,
    this.isInForeground = true,
    this.watchPercentage = 0.0,
  });

  AdWatchSession copyWith({
    String? adId,
    DateTime? startTime,
    int? totalDuration,
    int? watchedDuration,
    bool? isMuted,
    int? pauseCount,
    int? totalPauseDuration,
    bool? isInForeground,
    double? watchPercentage,
  }) {
    return AdWatchSession(
      adId: adId ?? this.adId,
      startTime: startTime ?? this.startTime,
      totalDuration: totalDuration ?? this.totalDuration,
      watchedDuration: watchedDuration ?? this.watchedDuration,
      isMuted: isMuted ?? this.isMuted,
      pauseCount: pauseCount ?? this.pauseCount,
      totalPauseDuration: totalPauseDuration ?? this.totalPauseDuration,
      isInForeground: isInForeground ?? this.isInForeground,
      watchPercentage: watchPercentage ?? this.watchPercentage,
    );
  }
}
