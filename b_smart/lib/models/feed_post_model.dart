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
  final String? location; // Added location field
  final String? latestCommentUser;
  final String? latestCommentText;
  final List<Map<String, dynamic>>? rawLikes;
  final List<Map<String, dynamic>>? peopleTags;

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
    this.location, // Added
    this.latestCommentUser,
    this.latestCommentText,
    this.rawLikes,
    this.peopleTags,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    // 1. Handle the Media URL extraction (The fix for your 404 error)
    List<String> extractedUrls = [];
    if (json['mediaUrls'] != null) {
      for (var item in (json['mediaUrls'] as List)) {
        if (item is Map) {
          // If backend sends [{ "fileUrl": "...", "fileName": "..." }]
          extractedUrls.add(item['fileUrl']?.toString() ?? '');
        } else {
          // If backend sends ["url1", "url2"]
          extractedUrls.add(item.toString());
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

    String? thumbUrl = json['thumbnailUrl'];
    
    // Fallback: Check if first media item is a map and has a thumbnail
    if (thumbUrl == null && json['mediaUrls'] != null && (json['mediaUrls'] as List).isNotEmpty) {
      final first = (json['mediaUrls'] as List).first;
      if (first is Map) {
        final t = first['thumbnail'] ?? first['thumbnailUrl'] ?? first['thumb'];
        if (t is String) {
          thumbUrl = t;
        } else if (t is List && t.isNotEmpty && t.first is Map) {
           // Handle structured thumbnail object from reel payload
           thumbUrl = (t.first as Map)['url'] ?? (t.first as Map)['fileUrl'];
        }
      }
    }

    return FeedPost(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      userName: json['username'] ?? json['userName'] ?? 'User',
      fullName: json['fullName'],
      userAvatar: json['userAvatar'],
      isVerified: json['isVerified'] ?? false,
      mediaType: type,
      mediaUrls: extractedUrls.where((url) => url.isNotEmpty).toList(),
      thumbnailUrl: thumbUrl,
      aspectRatio: json['aspectRatio'] != null ? double.tryParse(json['aspectRatio'].toString()) : null,
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
      location: json['location'], // Map location
      latestCommentUser: json['latestCommentUser'],
      latestCommentText: json['latestCommentText'],
      rawLikes: (json['likes_data'] as List?)?.map((e) => e as Map<String, dynamic>).toList(),
      peopleTags: (json['people_tags'] as List?)?.map((e) => e as Map<String, dynamic>).toList(),
    );
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
    String? latestCommentUser,
    String? latestCommentText,
    List<Map<String, dynamic>>? rawLikes,
    List<Map<String, dynamic>>? peopleTags,
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
      latestCommentUser: latestCommentUser ?? this.latestCommentUser,
      latestCommentText: latestCommentText ?? this.latestCommentText,
      rawLikes: rawLikes ?? this.rawLikes,
      peopleTags: peopleTags ?? this.peopleTags,
    );
  }
}
