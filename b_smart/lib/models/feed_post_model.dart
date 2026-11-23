import '../models/location_place.dart';
import '../utils/location_utils.dart';
import '../utils/url_helper.dart';

enum PostMediaType {
  image,
  video,
  carousel,
  reel,
}

class FeedPost {
  final String id;
  final String userId;
  final String userName;
  final String? fullName;
  final String? userAvatar;
  final bool isVerified;
  final bool isAuthorPrivate;
  final PostMediaType mediaType;
  final List<String> mediaUrls;
  final String? thumbnailUrl;
  final double? aspectRatio;
  final List<double?>? mediaAspectRatios;
  final List<String?>? mediaFilters;
  final List<Map<String, int>>? mediaAdjustments;
  final String? caption;
  final List<String> hashtags;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final int views;
  final int shares;
  final bool isLiked;
  final bool isSaved;
  final bool isFollowed;
  final bool isTagged;
  final bool isShared;
  final String? sharedFrom;
  final bool isAd;
  final bool isTweet;
  final String? adTitle;
  final String? adCompanyId;
  final String? adCompanyName;
  final String? adCategory;
  final int totalBudgetCoins;
  final List<String>? targetLocations;
  final List<String>? targetLanguages;
  final bool commentsDisabled;
  final String? location; // Added location field
  final LocationPlace? locationPlace;
  final String? latestCommentUser;
  final String? latestCommentText;
  final List<Map<String, dynamic>>? rawLikes;
  final List<Map<String, dynamic>>? peopleTags;
  final bool hideLikesCount;
  final List<Map<String, dynamic>> promotedProducts;

  /// When the author pinned this post to the top of their profile
  /// (`pinned_at` from the API). `null` when not pinned.
  final DateTime? pinnedAt;

  /// Convenience flag mirroring the API's `is_pinned`.
  final bool isPinned;

  /// Max pinned posts per user (enforced server-side; mirrored for UX).
  static const int maxPinnedPosts = 3;

  FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.fullName,
    this.userAvatar,
    this.isVerified = false,
    this.isAuthorPrivate = false,
    required this.mediaType,
    required this.mediaUrls,
    this.thumbnailUrl,
    this.aspectRatio,
    this.mediaAspectRatios,
    this.mediaFilters,
    this.mediaAdjustments,
    this.caption,
    this.hashtags = const [],
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    this.shares = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isFollowed = false,
    this.isTagged = false,
    this.isShared = false,
    this.sharedFrom,
    this.isAd = false,
    this.isTweet = false,
    this.adTitle,
    this.adCompanyId,
    this.adCompanyName,
    this.adCategory,
    this.totalBudgetCoins = 0,
    this.targetLocations = const [],
    this.targetLanguages = const [],
    this.commentsDisabled = false,
    this.location, // Added
    this.locationPlace,
    this.latestCommentUser,
    this.latestCommentText,
    this.rawLikes,
    this.peopleTags,
    this.hideLikesCount = false,
    this.promotedProducts = const <Map<String, dynamic>>[],
    this.pinnedAt,
    bool? isPinned,
  }) : isPinned = isPinned ?? (pinnedAt != null);

  /// Reads `pinned_at` / `pinnedAt` from a raw API post map.
  static DateTime? parsePinnedAt(Map<dynamic, dynamic> json) {
    final raw = json['pinned_at'] ?? json['pinnedAt'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return DateTime.tryParse(s);
  }

  /// Reads `is_pinned` / `isPinned` (falling back to `pinned_at`).
  static bool parseIsPinned(Map<dynamic, dynamic> json) {
    final raw = json['is_pinned'] ?? json['isPinned'];
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final v = raw.trim().toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return parsePinnedAt(json) != null;
  }

  /// Pinned posts first (most recently pinned first), then the rest in
  /// their original order. Used for the owner's profile grid.
  static List<FeedPost> sortPinnedFirst(List<FeedPost> posts) {
    final pinned = posts.where((p) => p.isPinned).toList()
      ..sort((a, b) {
        final ap = a.pinnedAt, bp = b.pinnedAt;
        if (ap == null && bp == null) return 0;
        if (ap == null) return 1;
        if (bp == null) return -1;
        return bp.compareTo(ap);
      });
    if (pinned.isEmpty) return posts;
    return [...pinned, ...posts.where((p) => !p.isPinned)];
  }

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    String? extractId(dynamic value) {
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return value.toString();
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final raw = map['_id'] ??
            map['id'] ??
            map['user_id'] ??
            map['userId'] ??
            map['vendorId'] ??
            map['vendor_id'];
        if (raw == null) return null;
        final s = raw.toString().trim();
        return s.isEmpty ? null : s;
      }
      final s = value?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    bool toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        return s == 'true' || s == '1' || s == 'yes';
      }
      return false;
    }

    // 1. Handle the Media URL extraction (The fix for your 404 error)
    List<String> extractedUrls = [];
    final mediaList = json['mediaUrls'] as List? ?? json['media'] as List?;
    if (mediaList != null) {
      for (var item in mediaList) {
        if (item is Map) {
          // If backend sends [{ "fileUrl": "...", "fileName": "..." }]
          final normalized = UrlHelper.normalizeUrl(
            item['fileUrl'] ??
                item['file_url'] ??
                item['url'] ??
                item['path'] ??
                item['image'] ??
                item['imageUrl'] ??
                item['videoUrl'],
          );
          if (normalized.isNotEmpty) extractedUrls.add(normalized);
        } else {
          // If backend sends ["url1", "url2"]
          final normalized = UrlHelper.normalizeUrl(item.toString());
          if (normalized.isNotEmpty) extractedUrls.add(normalized);
        }
      }
    }

    // 2. Map Media Type String to Enum
    PostMediaType type;
    switch (json['mediaType']?.toString().toLowerCase()) {
      case 'video':
        type = PostMediaType.video;
        break;
      case 'reel':
        type = PostMediaType.reel;
        break;
      case 'carousel':
        type = PostMediaType.carousel;
        break;
      default:
        type = PostMediaType.image;
    }

    String thumbUrl =
        UrlHelper.normalizeUrl(json['thumbnailUrl'] ?? json['thumbnail']);

    // Fallback: Check if first media item is a map and has a thumbnail
    if (thumbUrl.isEmpty &&
        json['mediaUrls'] != null &&
        (json['mediaUrls'] as List).isNotEmpty) {
      final first = (json['mediaUrls'] as List).first;
      if (first is Map) {
        final t = first['thumbnail'] ??
            first['thumbnailUrl'] ??
            first['thumb'] ??
            first['coverUrl'] ??
            first['uploadedCoverUrl'] ??
            first['cover_url'];
        if (t is String) {
          thumbUrl = UrlHelper.normalizeUrl(t);
        } else if (t is List && t.isNotEmpty && t.first is Map) {
          // Handle structured thumbnail object from reel payload
          thumbUrl = UrlHelper.normalizeUrl(
            (t.first as Map)['url'] ??
                (t.first as Map)['fileUrl'] ??
                (t.first as Map)['file_url'] ??
                (t.first as Map)['coverUrl'],
          );
        }
      }
    }

    if (thumbUrl.isEmpty &&
        json['media'] is List &&
        (json['media'] as List).isNotEmpty) {
      final first = (json['media'] as List).first;
      if (first is Map) {
        final t = first['thumbnail'] ??
            first['thumbnailUrl'] ??
            first['thumb'] ??
            first['coverUrl'] ??
            first['uploadedCoverUrl'] ??
            first['cover_url'];
        thumbUrl = UrlHelper.normalizeUrl(t);
      }
    }

    final mediaFilters = <String?>[];
    final mediaAdjustments = <Map<String, int>>[];
    final mediaAspectRatios = <double?>[];
    double? parseAspectRatio(dynamic raw) {
      if (raw == null) return null;
      if (raw is num) {
        final v = raw.toDouble();
        return v > 0 ? v : null;
      }
      if (raw is String) {
        final s = raw.trim();
        if (s.isEmpty) return null;
        if (s.contains(':') || s.contains('/')) {
          final parts = s.split(RegExp(r'[:/]'));
          if (parts.length >= 2) {
            final a = double.tryParse(parts[0].trim());
            final b = double.tryParse(parts[1].trim());
            if (a != null && b != null && a > 0 && b > 0) {
              return a / b;
            }
          }
        }
        final v = double.tryParse(s);
        return (v != null && v > 0) ? v : null;
      }
      return null;
    }

    final mediaListForFilters =
        json['media'] as List? ?? json['mediaUrls'] as List?;
    if (mediaListForFilters != null) {
      for (final item in mediaListForFilters) {
        if (item is Map) {
          final rawFilter = item['filter'];
          String? filterName;
          if (rawFilter is String) {
            filterName = rawFilter;
          } else if (rawFilter is Map) {
            final name =
                rawFilter['name'] ?? rawFilter['filter'] ?? rawFilter['id'];
            if (name != null) filterName = name.toString();
          }
          filterName ??= item['filterName']?.toString();
          if (filterName == null || filterName.isEmpty) {
            filterName = null;
          }
          mediaFilters.add(filterName);

          final rawAdj = item['adjustments'];
          if (rawAdj is Map) {
            final adj = Map<String, dynamic>.from(rawAdj);
            int toIntAdj(dynamic v) {
              if (v is int) return v;
              if (v is num) return v.round();
              return int.tryParse(v?.toString() ?? '') ?? 0;
            }

            final out = <String, int>{};
            if (adj.containsKey('brightness')) {
              out['brightness'] = toIntAdj(adj['brightness']);
            }
            if (adj.containsKey('contrast')) {
              out['contrast'] = toIntAdj(adj['contrast']);
            }
            if (adj.containsKey('saturation')) {
              out['saturate'] = toIntAdj(adj['saturation']);
            }
            if (adj.containsKey('temperature')) {
              out['sepia'] = toIntAdj(adj['temperature']);
            }
            if (adj.containsKey('fade')) {
              out['opacity'] = toIntAdj(adj['fade']);
            }
            if (adj.containsKey('opacity')) {
              out['opacity'] = toIntAdj(adj['opacity']);
            }
            if (adj.containsKey('vignette')) {
              out['vignette'] = toIntAdj(adj['vignette']);
            }
            mediaAdjustments.add(out);
          } else {
            mediaAdjustments.add(const {});
          }

          final rawAr = item['aspect_ratio'] ??
              item['aspectRatio'] ??
              (item['crop'] is Map
                  ? (item['crop'] as Map)['aspect_ratio']
                  : null) ??
              (item['crop'] is Map
                  ? (item['crop'] as Map)['aspectRatio']
                  : null) ??
              (item['crop_settings'] is Map
                  ? (item['crop_settings'] as Map)['aspect_ratio']
                  : null) ??
              (item['crop_settings'] is Map
                  ? (item['crop_settings'] as Map)['aspectRatio']
                  : null) ??
              item['width'] ??
              item['height'];
          if (rawAr is Map) {
            mediaAspectRatios.add(parseAspectRatio(
              rawAr['aspect_ratio'] ?? rawAr['aspectRatio'],
            ));
          } else if (item['width'] is num && item['height'] is num) {
            final w = (item['width'] as num).toDouble();
            final h = (item['height'] as num).toDouble();
            mediaAspectRatios.add(w > 0 && h > 0 ? w / h : null);
          } else {
            mediaAspectRatios.add(parseAspectRatio(rawAr));
          }
        } else {
          mediaFilters.add(null);
          mediaAdjustments.add(const {});
          mediaAspectRatios.add(null);
        }
      }
    }

    final likesCount = toInt(
      json['likesCount'] ??
          json['likes_count'] ??
          json['likeCount'] ??
          json['like_count'] ??
          json['likes'],
    );
    final commentsCount = toInt(
      json['commentsCount'] ??
          json['comments_count'] ??
          json['commentCount'] ??
          json['comment_count'] ??
          json['comments'],
    );
    final sharesCount = toInt(
      json['sharesCount'] ??
          json['shares_count'] ??
          json['shareCount'] ??
          json['share_count'] ??
          json['shares'],
    );
    final viewsCount =
        toInt(json['viewsCount'] ?? json['views_count'] ?? json['views']);

    return FeedPost(
      id: json['_id'] ?? json['id'] ?? '',
      userId:
          extractId(json['user_id'] ?? json['userId'] ?? json['user']) ?? '',
      userName: json['username'] ?? json['userName'] ?? 'User',
      fullName: json['fullName'],
      userAvatar:
          UrlHelper.normalizeUrl(json['userAvatar'] ?? json['avatar_url']),
      isVerified: json['isVerified'] ?? false,
      isAuthorPrivate: toBool(
        json['isAuthorPrivate'] ??
            json['author_is_private'] ??
            json['authorIsPrivate'] ??
            json['is_private'] ??
            json['isPrivate'],
      ),
      mediaType: type,
      mediaUrls: extractedUrls.where((url) => url.isNotEmpty).toList(),
      thumbnailUrl: thumbUrl,
      aspectRatio: json['aspectRatio'] != null
          ? double.tryParse(json['aspectRatio'].toString())
          : null,
      mediaAspectRatios: mediaAspectRatios.isEmpty ? null : mediaAspectRatios,
      mediaFilters: mediaFilters.isEmpty ? null : mediaFilters,
      mediaAdjustments: mediaAdjustments.isEmpty ? null : mediaAdjustments,
      caption: (json['caption'] ?? json['content']) as String?,
      hashtags: List<String>.from(json['hashtags'] ?? []),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      likes: likesCount,
      comments: commentsCount,
      views: viewsCount,
      shares: sharesCount,
      isLiked: json['isLiked'] ?? false,
      isSaved: json['isSaved'] ?? false,
      isFollowed: json['isFollowed'] ?? false,
      isTagged: json['isTagged'] ?? false,
      isShared: json['isShared'] ?? false,
      sharedFrom: json['sharedFrom'],
      isAd: json['isAd'] ?? false,
      isTweet: (json['item_type'] ?? json['itemType'] ?? '')
                  .toString()
                  .toLowerCase() ==
              'tweet' ||
          (json['isTweet'] ?? false) == true,
      adTitle: json['adTitle'],
      adCompanyId: json['adCompanyId'],
      adCompanyName: json['adCompanyName'],
      adCategory: json['adCategory'] ?? json['category'],
      totalBudgetCoins:
          json['total_budget_coins'] ?? json['totalBudgetCoins'] ?? 0,
      targetLocations:
          _asStringList(json['targetLocations'] ?? json['target_location']),
      targetLanguages:
          _asStringList(json['targetLanguages'] ?? json['target_language']),
      commentsDisabled: json['turn_off_commenting'] ??
          json['commentsDisabled'] ??
          json['comments_disabled'] ??
          false,
      location: locationLabelFromDynamic(
        json['location_place'] ??
            json['locationPlace'] ??
            json['location_data'] ??
            json['locationData'] ??
            json['location'],
      ),
      locationPlace: locationPlaceFromDynamic(
        json['location_place'] ??
            json['locationPlace'] ??
            json['location_data'] ??
            json['locationData'] ??
            json['location'],
      ),
      latestCommentUser: json['latestCommentUser'],
      latestCommentText: json['latestCommentText'],
      rawLikes: (json['likes_data'] as List?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      peopleTags: (json['people_tags'] as List?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      hideLikesCount: json['hide_likes_count'] ??
          json['hideLikesCount'] ??
          json['hide_likes'] ??
          false,
      promotedProducts: (json['promotedProducts'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[],
      pinnedAt: parsePinnedAt(json),
      isPinned: parseIsPinned(json),
    );
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

  FeedPost copyWith({
    String? id,
    String? userId,
    String? userName,
    String? fullName,
    String? userAvatar,
    bool? isVerified,
    bool? isAuthorPrivate,
    PostMediaType? mediaType,
    List<String>? mediaUrls,
    String? thumbnailUrl,
    double? aspectRatio,
    List<double?>? mediaAspectRatios,
    List<String?>? mediaFilters,
    List<Map<String, int>>? mediaAdjustments,
    String? caption,
    List<String>? hashtags,
    DateTime? createdAt,
    int? likes,
    int? comments,
    int? views,
    int? shares,
    bool? isLiked,
    bool? isSaved,
    bool? isFollowed,
    bool? isTagged,
    bool? isShared,
    String? sharedFrom,
    bool? isAd,
    bool? isTweet,
    String? adTitle,
    String? adCompanyId,
    String? adCompanyName,
    String? adCategory,
    int? totalBudgetCoins,
    List<String>? targetLocations,
    List<String>? targetLanguages,
    bool? commentsDisabled,
    LocationPlace? locationPlace,
    String? latestCommentUser,
    String? latestCommentText,
    List<Map<String, dynamic>>? rawLikes,
    List<Map<String, dynamic>>? peopleTags,
    bool? hideLikesCount,
    List<Map<String, dynamic>>? promotedProducts,
    DateTime? pinnedAt,
    bool? isPinned,
    bool clearPinnedAt = false,
  }) {
    return FeedPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      fullName: fullName ?? this.fullName,
      userAvatar: userAvatar ?? this.userAvatar,
      isVerified: isVerified ?? this.isVerified,
      isAuthorPrivate: isAuthorPrivate ?? this.isAuthorPrivate,
      mediaType: mediaType ?? this.mediaType,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      mediaAspectRatios: mediaAspectRatios ?? this.mediaAspectRatios,
      mediaFilters: mediaFilters ?? this.mediaFilters,
      mediaAdjustments: mediaAdjustments ?? this.mediaAdjustments,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      views: views ?? this.views,
      shares: shares ?? this.shares,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isFollowed: isFollowed ?? this.isFollowed,
      isTagged: isTagged ?? this.isTagged,
      isShared: isShared ?? this.isShared,
      sharedFrom: sharedFrom ?? this.sharedFrom,
      isAd: isAd ?? this.isAd,
      isTweet: isTweet ?? this.isTweet,
      adTitle: adTitle ?? this.adTitle,
      adCompanyId: adCompanyId ?? this.adCompanyId,
      adCompanyName: adCompanyName ?? this.adCompanyName,
      adCategory: adCategory ?? this.adCategory,
      totalBudgetCoins: totalBudgetCoins ?? this.totalBudgetCoins,
      targetLocations: targetLocations ?? this.targetLocations,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      locationPlace: locationPlace ?? this.locationPlace,
      latestCommentUser: latestCommentUser ?? this.latestCommentUser,
      latestCommentText: latestCommentText ?? this.latestCommentText,
      rawLikes: rawLikes ?? this.rawLikes,
      peopleTags: peopleTags ?? this.peopleTags,
      hideLikesCount: hideLikesCount ?? this.hideLikesCount,
      promotedProducts: promotedProducts ?? this.promotedProducts,
      pinnedAt: clearPinnedAt ? null : (pinnedAt ?? this.pinnedAt),
      isPinned: isPinned ?? (clearPinnedAt ? false : this.isPinned),
    );
  }

  bool get isPromote => id.startsWith('promote-');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'fullName': fullName,
      'userAvatar': userAvatar,
      'isVerified': isVerified,
      'isAuthorPrivate': isAuthorPrivate,
      'mediaType': mediaType.name,
      'mediaUrls': mediaUrls,
      'thumbnailUrl': thumbnailUrl,
      'aspectRatio': aspectRatio,
      'mediaAspectRatios': mediaAspectRatios,
      'mediaFilters': mediaFilters,
      'mediaAdjustments': mediaAdjustments,
      'caption': caption,
      'hashtags': hashtags,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      'comments': comments,
      'views': views,
      'shares': shares,
      'isLiked': isLiked,
      'isSaved': isSaved,
      'isFollowed': isFollowed,
      'isTagged': isTagged,
      'isShared': isShared,
      'sharedFrom': sharedFrom,
      'isAd': isAd,
      'isTweet': isTweet,
      'adTitle': adTitle,
      'adCompanyId': adCompanyId,
      'adCompanyName': adCompanyName,
      'adCategory': adCategory,
      'totalBudgetCoins': totalBudgetCoins,
      'targetLocations': targetLocations,
      'targetLanguages': targetLanguages,
      'commentsDisabled': commentsDisabled,
      'location': location,
      'locationPlace': locationPlace?.toJson(),
      'latestCommentUser': latestCommentUser,
      'latestCommentText': latestCommentText,
      'rawLikes': rawLikes,
      'peopleTags': peopleTags,
      'hideLikesCount': hideLikesCount,
      'promotedProducts': promotedProducts,
      'pinned_at': pinnedAt?.toIso8601String(),
      'is_pinned': isPinned,
    };
  }
}