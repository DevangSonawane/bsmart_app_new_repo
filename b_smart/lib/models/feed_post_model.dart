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
  final PostMediaType mediaType;
  final List<String> mediaUrls; 
  final String? thumbnailUrl; 
  final double? aspectRatio;
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
  final String? adTitle;
  final String? adCompanyId;
  final String? adCompanyName;
  final String? adCategory;
  final int totalBudgetCoins;
  final List<String>? targetLocations;
  final List<String>? targetLanguages;
  final bool commentsDisabled;
  final String? location; // Added location field
  final String? latestCommentUser;
  final String? latestCommentText;
  final List<Map<String, dynamic>>? rawLikes;
  final List<Map<String, dynamic>>? peopleTags;
  final bool hideLikesCount;

  FeedPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.fullName,
    this.userAvatar,
    this.isVerified = false,
    required this.mediaType,
    required this.mediaUrls,
    this.thumbnailUrl,
    this.aspectRatio,
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
    this.adTitle,
    this.adCompanyId,
    this.adCompanyName,
    this.adCategory,
    this.totalBudgetCoins = 0,
    this.targetLocations = const [],
    this.targetLanguages = const [],
    this.commentsDisabled = false,
    this.location, // Added
    this.latestCommentUser,
    this.latestCommentText,
    this.rawLikes,
    this.peopleTags,
    this.hideLikesCount = false,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
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
      case 'video': type = PostMediaType.video; break;
      case 'reel': type = PostMediaType.reel; break;
      case 'carousel': type = PostMediaType.carousel; break;
      default: type = PostMediaType.image;
    }

    String thumbUrl = UrlHelper.normalizeUrl(json['thumbnailUrl'] ?? json['thumbnail']);
    
    // Fallback: Check if first media item is a map and has a thumbnail
    if (thumbUrl.isEmpty && json['mediaUrls'] != null && (json['mediaUrls'] as List).isNotEmpty) {
      final first = (json['mediaUrls'] as List).first;
      if (first is Map) {
        final t = first['thumbnail'] ?? first['thumbnailUrl'] ?? first['thumb'];
        if (t is String) {
          thumbUrl = UrlHelper.normalizeUrl(t);
        } else if (t is List && t.isNotEmpty && t.first is Map) {
           // Handle structured thumbnail object from reel payload
          thumbUrl = UrlHelper.normalizeUrl((t.first as Map)['url'] ?? (t.first as Map)['fileUrl']);
        }
      }
    }

    final mediaFilters = <String?>[];
    final mediaAdjustments = <Map<String, int>>[];
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
            final name = rawFilter['name'] ?? rawFilter['filter'] ?? rawFilter['id'];
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
            int _toInt(dynamic v) {
              if (v is int) return v;
              if (v is num) return v.round();
              return int.tryParse(v?.toString() ?? '') ?? 0;
            }

            final out = <String, int>{};
            if (adj.containsKey('brightness')) {
              out['brightness'] = _toInt(adj['brightness']);
            }
            if (adj.containsKey('contrast')) {
              out['contrast'] = _toInt(adj['contrast']);
            }
            if (adj.containsKey('saturation')) {
              out['saturate'] = _toInt(adj['saturation']);
            }
            if (adj.containsKey('temperature')) {
              out['sepia'] = _toInt(adj['temperature']);
            }
            if (adj.containsKey('fade')) {
              out['opacity'] = _toInt(adj['fade']);
            }
            if (adj.containsKey('opacity')) {
              out['opacity'] = _toInt(adj['opacity']);
            }
            if (adj.containsKey('vignette')) {
              out['vignette'] = _toInt(adj['vignette']);
            }
            mediaAdjustments.add(out);
          } else {
            mediaAdjustments.add(const {});
          }
        } else {
          mediaFilters.add(null);
          mediaAdjustments.add(const {});
        }
      }
    }

    return FeedPost(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      userName: json['username'] ?? json['userName'] ?? 'User',
      fullName: json['fullName'],
      userAvatar: UrlHelper.normalizeUrl(json['userAvatar'] ?? json['avatar_url']),
      isVerified: json['isVerified'] ?? false,
      mediaType: type,
      mediaUrls: extractedUrls.where((url) => url.isNotEmpty).toList(),
      thumbnailUrl: thumbUrl,
      aspectRatio: json['aspectRatio'] != null ? double.tryParse(json['aspectRatio'].toString()) : null,
      mediaFilters: mediaFilters.isEmpty ? null : mediaFilters,
      mediaAdjustments: mediaAdjustments.isEmpty ? null : mediaAdjustments,
      caption: json['caption'],
      hashtags: List<String>.from(json['hashtags'] ?? []),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      likes: json['likesCount'] ?? json['likes'] ?? 0,
      comments: json['commentsCount'] ?? json['comments'] ?? 0,
      views: json['views'] ?? 0,
      shares: json['shares'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isSaved: json['isSaved'] ?? false,
      isFollowed: json['isFollowed'] ?? false,
      isTagged: json['isTagged'] ?? false,
      isShared: json['isShared'] ?? false,
      sharedFrom: json['sharedFrom'],
      isAd: json['isAd'] ?? false,
      adTitle: json['adTitle'],
      adCompanyId: json['adCompanyId'],
      adCompanyName: json['adCompanyName'],
      adCategory: json['adCategory'] ?? json['category'],
      totalBudgetCoins:
          json['total_budget_coins'] ?? json['totalBudgetCoins'] ?? 0,
      targetLocations: _asStringList(
          json['targetLocations'] ?? json['target_location']),
      targetLanguages: _asStringList(
          json['targetLanguages'] ?? json['target_language']),
      commentsDisabled: json['turn_off_commenting'] ??
          json['commentsDisabled'] ??
          json['comments_disabled'] ??
          false,
      location: json['location'], // Map location
      latestCommentUser: json['latestCommentUser'],
      latestCommentText: json['latestCommentText'],
      rawLikes: (json['likes_data'] as List?)?.map((e) => e as Map<String, dynamic>).toList(),
      peopleTags: (json['people_tags'] as List?)?.map((e) => e as Map<String, dynamic>).toList(),
      hideLikesCount: json['hide_likes_count'] ??
          json['hideLikesCount'] ??
          json['hide_likes'] ??
          false,
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
    PostMediaType? mediaType,
    List<String>? mediaUrls,
    String? thumbnailUrl,
    double? aspectRatio,
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
    String? adTitle,
    String? adCompanyId,
    String? adCompanyName,
    String? adCategory,
    int? totalBudgetCoins,
    List<String>? targetLocations,
    List<String>? targetLanguages,
    bool? commentsDisabled,
    String? latestCommentUser,
    String? latestCommentText,
    List<Map<String, dynamic>>? rawLikes,
    List<Map<String, dynamic>>? peopleTags,
    bool? hideLikesCount,
  }) {
    return FeedPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      fullName: fullName ?? this.fullName,
      userAvatar: userAvatar ?? this.userAvatar,
      isVerified: isVerified ?? this.isVerified,
      mediaType: mediaType ?? this.mediaType,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
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
      adTitle: adTitle ?? this.adTitle,
      adCompanyId: adCompanyId ?? this.adCompanyId,
      adCompanyName: adCompanyName ?? this.adCompanyName,
      adCategory: adCategory ?? this.adCategory,
      totalBudgetCoins: totalBudgetCoins ?? this.totalBudgetCoins,
      targetLocations: targetLocations ?? this.targetLocations,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      latestCommentUser: latestCommentUser ?? this.latestCommentUser,
      latestCommentText: latestCommentText ?? this.latestCommentText,
      rawLikes: rawLikes ?? this.rawLikes,
      peopleTags: peopleTags ?? this.peopleTags,
      hideLikesCount: hideLikesCount ?? this.hideLikesCount,
    );
  }
}
