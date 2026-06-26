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
  final List<String> imageUrls;
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
    this.imageUrls = const [],
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

  Ad copyWith({
    int? likesCount,
    bool? isLikedByMe,
    bool? isDislikedByMe,
    bool? isSavedByMe,
    int? currentViews,
    int? commentsCount,
    int? sharesCount,
  }) {
    return Ad(
      id: id,
      companyId: companyId,
      companyName: companyName,
      companyLogo: companyLogo,
      title: title,
      description: description,
      caption: caption,
      category: category,
      hashtags: hashtags,
      videoUrl: videoUrl,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      coinReward: coinReward,
      watchDurationSeconds: watchDurationSeconds,
      maxRewardableViews: maxRewardableViews,
      currentViews: currentViews ?? this.currentViews,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isDislikedByMe: isDislikedByMe ?? this.isDislikedByMe,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      userId: userId,
      userName: userName,
      userAvatarUrl: userAvatarUrl,
      vendorBusinessName: vendorBusinessName,
      totalBudgetCoins: totalBudgetCoins,
      targetLocations: targetLocations,
      targetLanguages: targetLanguages,
      targetCategories: targetCategories,
      targetLocation: targetLocation,
      isVerified: isVerified,
      websiteUrl: websiteUrl,
      createdAt: createdAt,
      isActive: isActive,
    );
  }

  factory Ad.fromApi(Map<String, dynamic> raw) {
    final vendor = raw['vendor_id'] is Map
        ? Map<String, dynamic>.from(raw['vendor_id'] as Map)
        : <String, dynamic>{};
    final user = raw['user_id'] is Map
        ? Map<String, dynamic>.from(raw['user_id'] as Map)
        : <String, dynamic>{};
    final cta = raw['cta'] is Map
        ? Map<String, dynamic>.from(raw['cta'] as Map)
        : <String, dynamic>{};
    final userStatus = raw['user_status'] is Map
        ? Map<String, dynamic>.from(raw['user_status'] as Map)
        : <String, dynamic>{};
    final stats = raw['stats'] is Map
        ? Map<String, dynamic>.from(raw['stats'] as Map)
        : <String, dynamic>{};

    final media = _asList(raw['media']);
    final imageUrls = <String>[];
    String? videoUrl;
    String? imageUrl;
    for (final item in media) {
      final m =
          item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
      final type =
          (m['media_type'] ?? m['type'] ?? '').toString().toLowerCase();
      final url = _resolveMediaUrl(m);
      if (url == null || url.isEmpty) continue;
      if (type == 'video' ||
          url.toLowerCase().endsWith('.mp4') ||
          url.toLowerCase().endsWith('.mov')) {
        videoUrl ??= url;
      } else {
        imageUrl ??= url;
        imageUrls.add(url);
      }
    }

    imageUrl ??= _resolveThumbnailFromMedia(media);

    imageUrl ??= _normalizeUrl(
      raw['image'] ??
          raw['imageUrl'] ??
          raw['image_url'] ??
          raw['thumbnail'] ??
          raw['thumbnailUrl'],
    );
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      imageUrls.add(imageUrl);
    }

    // Some APIs return dedicated image arrays separate from `media`.
    imageUrls.addAll(_extractImageUrls(raw['images']));
    imageUrls.addAll(_extractImageUrls(raw['image_urls']));
    imageUrls.addAll(_extractImageUrls(raw['imageUrls']));
    imageUrls.addAll(_extractImageUrls(raw['gallery']));
    imageUrls.addAll(_extractImageUrls(raw['photos']));

    final normalizedImageUrls = _dedupePreserveOrder(imageUrls);
    videoUrl ??=
        _normalizeUrl(raw['video'] ?? raw['videoUrl'] ?? raw['video_url']);

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
      if (category != null && category.toString().trim().isNotEmpty)
        category.toString().trim(),
    ];

    final websiteUrlRaw =
        (raw['website_url'] ?? raw['websiteUrl'] ?? '').toString().trim();
    final ctaWebsiteUrlRaw =
        (cta['url'] ?? cta['deep_link'] ?? '').toString().trim();
    final websiteUrlResolved =
        websiteUrlRaw.isNotEmpty ? websiteUrlRaw : ctaWebsiteUrlRaw;

    return Ad(
      id: (raw['_id'] ?? raw['id'] ?? '').toString(),
      companyId: (vendor['_id'] ??
              vendor['id'] ??
              raw['company_id'] ??
              raw['companyId'] ??
              '')
          .toString(),
      companyName: companyName,
      companyLogo: _normalizeUrl(vendor['logo'] ??
          vendor['logo_url'] ??
          user['avatar_url'] ??
          raw['company_logo']),
      title: (raw['ad_title'] ??
              raw['adTitle'] ??
              raw['title'] ??
              raw['headline'] ??
              raw['name'] ??
              companyName)
          .toString(),
      description: (raw['ad_description'] ??
              raw['adDescription'] ??
              raw['description'] ??
              raw['caption'] ??
              '')
          .toString(),
      caption: _asNullableString(raw['caption']),
      category: _asNullableString(raw['category']),
      hashtags: _asStringList(raw['hashtags']),
      videoUrl: videoUrl,
      imageUrl: imageUrl,
      imageUrls: normalizedImageUrls,
      coinReward: _toInt(raw['coins_reward'] ??
              raw['coin_reward'] ??
              raw['coinReward'] ??
              raw['reward_coins'] ??
              raw['reward']) ??
          0,
      watchDurationSeconds: _toInt(raw['watch_duration_seconds'] ??
              raw['watchDurationSeconds'] ??
              raw['duration']) ??
          15,
      maxRewardableViews: _toInt(raw['max_rewardable_views'] ??
              raw['maxRewardableViews'] ??
              raw['max_views']) ??
          0,
      currentViews: _toInt(raw['views_count'] ??
              raw['viewsCount'] ??
              raw['currentViews'] ??
              stats['views']) ??
          0,
      likesCount:
          _toInt(raw['likes_count'] ?? raw['likesCount'] ?? stats['likes']) ??
              0,
      commentsCount: _toInt(raw['comments_count'] ??
              raw['commentsCount'] ??
              stats['comments']) ??
          (_asList(raw['comments']).length),
      sharesCount: _toInt(
              raw['shares_count'] ?? raw['sharesCount'] ?? stats['shares']) ??
          0,
      isLikedByMe: (raw['is_liked_by_me'] ??
              raw['isLikedByMe'] ??
              userStatus['is_liked'] ??
              userStatus['liked'] ??
              false) ==
          true,
      isDislikedByMe: (raw['is_disliked_by_me'] ??
              raw['isDislikedByMe'] ??
              userStatus['is_disliked'] ??
              userStatus['disliked'] ??
              false) ==
          true,
      isSavedByMe: (raw['is_saved_by_me'] ??
              raw['isSavedByMe'] ??
              userStatus['is_saved'] ??
              userStatus['saved'] ??
              false) ==
          true,
      userId: (user['_id'] ??
              user['id'] ??
              ((raw['user_id'] is String || raw['user_id'] is num)
                  ? raw['user_id']
                  : null) ??
              raw['userId'])
          ?.toString(),
      userName: _asNullableString(user['username'] ?? user['full_name']),
      userAvatarUrl: _normalizeUrl(user['avatar_url'] ??
          user['avatarUrl'] ??
          raw['avatar_url'] ??
          raw['avatar']),
      vendorBusinessName: _asNullableString(
        vendor['business_name'] ??
            vendor['name'] ??
            raw['business_name'] ??
            raw['vendor_name'] ??
            raw['advertiser_name'],
      ),
      totalBudgetCoins:
          _toInt(raw['total_budget_coins'] ?? raw['totalBudgetCoins']) ?? 0,
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
      targetLocation: (raw['target_location'] ?? raw['targetLocation'] ?? '')
              .toString()
              .trim()
              .isEmpty
          ? null
          : (raw['target_location'] ?? raw['targetLocation']).toString(),
      isVerified: (vendor['validated'] ??
              vendor['is_verified'] ??
              vendor['verified'] ??
              raw['validated'] ??
              false) ==
          true,
      websiteUrl: websiteUrlResolved.isEmpty ? null : websiteUrlResolved,
      createdAt:
          _parseDate(raw['createdAt'] ?? raw['created_at']) ?? DateTime.now(),
      isActive: ((raw['status'] ?? '').toString().trim().isEmpty
              ? (raw['is_active'] ?? raw['isActive'] ?? true)
              : (raw['status'] ?? '').toString().trim().toLowerCase() ==
                  'active') ==
          true,
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

  static List<String> _dedupePreserveOrder(List<String> values) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      if (seen.add(value)) out.add(value);
    }
    return out;
  }

  static List<String> _extractImageUrls(dynamic raw) {
    final out = <String>[];
    for (final item in _asList(raw)) {
      if (item is String) {
        final url = _normalizeUrl(item);
        if (url != null && url.isNotEmpty) out.add(url);
        continue;
      }
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final file = map['file'];
        if (file is Map) {
          final nested = _normalizeUrl(
            file['fileUrl'] ??
                file['file_url'] ??
                file['url'] ??
                file['path'] ??
                file['image'] ??
                file['imageUrl'],
          );
          if (nested != null && nested.isNotEmpty) {
            out.add(nested);
            continue;
          }
        } else if (file is String) {
          final nested = _normalizeUrl(file);
          if (nested != null && nested.isNotEmpty) {
            out.add(nested);
            continue;
          }
        }
        final url = _normalizeUrl(
          map['link'] ??
              map['url'] ??
              map['fileUrl'] ??
              map['file_url'] ??
              map['fileName'] ??
              map['filename'] ??
              map['filname'] ??
              map['path'] ??
              map['image'] ??
              map['imageUrl'] ??
              map['thumbnail'] ??
              map['thumbnailUrl'] ??
              (map['file'] is String ? map['file'] : null),
        );
        if (url != null && url.isNotEmpty) out.add(url);
        continue;
      }
    }
    return out;
  }

  static String? _resolveMediaUrl(Map<String, dynamic> media) {
    final file = media['file'];
    if (file is Map) {
      final nested = _normalizeUrl(
          file['fileUrl'] ?? file['file_url'] ?? file['url'] ?? file['path']);
      if (nested != null && nested.isNotEmpty) return nested;
    } else if (file is String) {
      final nested = _normalizeUrl(file);
      if (nested != null && nested.isNotEmpty) return nested;
    }

    final direct = _normalizeUrl(
      media['link'] ??
      media['fileUrl'] ??
      media['file_url'] ??
      media['url'] ??
      media['image'] ??
      media['imageUrl'] ??
          media['path'],
    );
    if (direct != null && direct.isNotEmpty) return direct;

    final name = media['fileName']?.toString().trim();
    if (name != null && name.isNotEmpty && !_isPlaceholderToken(name)) {
      final cleaned = name
          .replaceFirst(RegExp(r'^/?uploads/+'), '')
          .replaceFirst(RegExp(r'^/+'), '');
      return '${_apiOrigin()}/uploads/$cleaned';
    }
    return null;
  }

  static String? _resolveThumbnailFromMedia(List<dynamic> media) {
    String? pickFromMap(Map<String, dynamic> m) {
      final thumb = _normalizeUrl(
        m['thumbnail'] ?? m['thumbnail_url'] ?? m['thumbnailUrl'],
      );
      if (thumb != null && thumb.isNotEmpty) return thumb;
      final thumbs = m['thumbnails'];
      if (thumbs is List) {
        for (final t in thumbs) {
          final tm =
              t is Map ? Map<String, dynamic>.from(t) : <String, dynamic>{};
          final url = _normalizeUrl(
            tm['fileUrl'] ?? tm['file_url'] ?? tm['url'] ?? tm['path'],
          );
          if (url != null && url.isNotEmpty) return url;
        }
      }
      return null;
    }

    for (final item in media) {
      final m =
          item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
      final url = pickFromMap(m);
      if (url != null && url.isNotEmpty) return url;
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
    return ApiConfig.baseUrl.trim().replaceAll(RegExp(r'\/+$'), '');
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
