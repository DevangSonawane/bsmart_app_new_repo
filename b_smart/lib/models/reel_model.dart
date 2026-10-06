import 'feed_post_model.dart';

class Reel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? aspectRatio;
  final String? caption;
  final List<String> hashtags;
  final String? audioTitle;
  final String? audioArtist;
  final String? audioId;
  final int likes;
  final int comments;
  final int shares;
  final int views;
  final bool isLiked;
  final bool isSaved;
  final bool isFollowing;
  final DateTime createdAt;
  final bool isSponsored;
  final String? sponsorBrand;
  final String? sponsorLogoUrl;
  final List<ProductTag>? productTags;
  final bool remixEnabled;
  final bool audioReuseEnabled;
  final String? originalReelId; // For remixed reels
  final String? originalCreatorId;
  final String? originalCreatorName;
  final bool isRisingCreator;
  final bool isTrending;
  final Duration duration;
  final List<Map<String, dynamic>>? peopleTags;

  Reel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.videoUrl,
    this.thumbnailUrl,
    this.aspectRatio,
    this.caption,
    this.hashtags = const [],
    this.audioTitle,
    this.audioArtist,
    this.audioId,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.views = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isFollowing = false,
    required this.createdAt,
    this.isSponsored = false,
    this.sponsorBrand,
    this.sponsorLogoUrl,
    this.productTags,
    this.remixEnabled = true,
    this.audioReuseEnabled = true,
    this.originalReelId,
    this.originalCreatorId,
    this.originalCreatorName,
    this.isRisingCreator = false,
    this.isTrending = false,
    required this.duration,
    this.peopleTags,
  });

  Reel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    String? videoUrl,
    String? thumbnailUrl,
    String? aspectRatio,
    String? caption,
    List<String>? hashtags,
    String? audioTitle,
    String? audioArtist,
    String? audioId,
    int? likes,
    int? comments,
    int? shares,
    int? views,
    bool? isLiked,
    bool? isSaved,
    bool? isFollowing,
    DateTime? createdAt,
    bool? isSponsored,
    String? sponsorBrand,
    String? sponsorLogoUrl,
    List<ProductTag>? productTags,
    bool? remixEnabled,
    bool? audioReuseEnabled,
    String? originalReelId,
    String? originalCreatorId,
    String? originalCreatorName,
    bool? isRisingCreator,
    bool? isTrending,
    Duration? duration,
    List<Map<String, dynamic>>? peopleTags,
  }) {
    return Reel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      caption: caption ?? this.caption,
      hashtags: hashtags ?? this.hashtags,
      audioTitle: audioTitle ?? this.audioTitle,
      audioArtist: audioArtist ?? this.audioArtist,
      audioId: audioId ?? this.audioId,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      views: views ?? this.views,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isFollowing: isFollowing ?? this.isFollowing,
      createdAt: createdAt ?? this.createdAt,
      isSponsored: isSponsored ?? this.isSponsored,
      sponsorBrand: sponsorBrand ?? this.sponsorBrand,
      sponsorLogoUrl: sponsorLogoUrl ?? this.sponsorLogoUrl,
      productTags: productTags ?? this.productTags,
      remixEnabled: remixEnabled ?? this.remixEnabled,
      audioReuseEnabled: audioReuseEnabled ?? this.audioReuseEnabled,
      originalReelId: originalReelId ?? this.originalReelId,
      originalCreatorId: originalCreatorId ?? this.originalCreatorId,
      originalCreatorName: originalCreatorName ?? this.originalCreatorName,
      isRisingCreator: isRisingCreator ?? this.isRisingCreator,
      isTrending: isTrending ?? this.isTrending,
      duration: duration ?? this.duration,
      peopleTags: peopleTags ?? this.peopleTags,
    );
  }
  FeedPost toFeedPost() {
    return FeedPost(
      id: id,
      userId: userId,
      userName: userName,
      userAvatar: userAvatarUrl,
      mediaType: PostMediaType.reel,
      mediaUrls: [videoUrl],
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      hashtags: hashtags,
      createdAt: createdAt,
      likes: likes,
      comments: comments,
      views: views,
      shares: shares,
      isLiked: isLiked,
      isSaved: isSaved,
      isFollowed: isFollowing,
      isTagged: peopleTags?.isNotEmpty ?? false,
      peopleTags: peopleTags,
    );
  }

  factory Reel.fromFeedPost(FeedPost post) {
    return Reel(
      id: post.id,
      userId: post.userId,
      userName: post.userName,
      userAvatarUrl: post.userAvatar,
      videoUrl: post.mediaUrls.first,
      thumbnailUrl: post.thumbnailUrl,
      aspectRatio: null,
      caption: post.caption,
      hashtags: post.hashtags,
      createdAt: post.createdAt,
      likes: post.likes,
      comments: post.comments,
      views: post.views,
      shares: post.shares,
      isLiked: post.isLiked,
      isSaved: post.isSaved,
      isFollowing: post.isFollowed,
      duration: const Duration(seconds: 30),
      peopleTags: post.peopleTags,
    );
  }

  factory Reel.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt']?.toString() ?? '';
    final createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    final durationMs = json['duration'] is int
        ? json['duration'] as int
        : int.tryParse(json['duration']?.toString() ?? '') ?? 30000;
    return Reel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      userName: (json['userName'] ?? json['user_name'] ?? '').toString(),
      userAvatarUrl: json['userAvatarUrl']?.toString(),
      videoUrl: (json['videoUrl'] ?? json['video_url'] ?? '').toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      aspectRatio: json['aspectRatio']?.toString(),
      caption: json['caption']?.toString(),
      hashtags: json['hashtags'] is List
          ? (json['hashtags'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      audioTitle: json['audioTitle']?.toString(),
      audioArtist: json['audioArtist']?.toString(),
      audioId: json['audioId']?.toString(),
      likes: json['likes'] is int
          ? json['likes'] as int
          : int.tryParse(json['likes']?.toString() ?? '') ?? 0,
      comments: json['comments'] is int
          ? json['comments'] as int
          : int.tryParse(json['comments']?.toString() ?? '') ?? 0,
      shares: json['shares'] is int
          ? json['shares'] as int
          : int.tryParse(json['shares']?.toString() ?? '') ?? 0,
      views: json['views'] is int
          ? json['views'] as int
          : int.tryParse(json['views']?.toString() ?? '') ?? 0,
      isLiked: json['isLiked'] is bool
          ? json['isLiked'] as bool
          : (json['isLiked']?.toString().toLowerCase() == 'true'),
      isSaved: json['isSaved'] is bool
          ? json['isSaved'] as bool
          : (json['isSaved']?.toString().toLowerCase() == 'true'),
      isFollowing: json['isFollowing'] is bool
          ? json['isFollowing'] as bool
          : (json['isFollowing']?.toString().toLowerCase() == 'true'),
      createdAt: createdAt,
      isSponsored: json['isSponsored'] is bool
          ? json['isSponsored'] as bool
          : (json['isSponsored']?.toString().toLowerCase() == 'true'),
      sponsorBrand: json['sponsorBrand']?.toString(),
      sponsorLogoUrl: json['sponsorLogoUrl']?.toString(),
      productTags: json['productTags'] is List
          ? (json['productTags'] as List)
              .whereType<Map<String, dynamic>>()
              .map((e) => ProductTag.fromJson(e))
              .toList()
          : null,
      remixEnabled: json['remixEnabled'] is bool
          ? json['remixEnabled'] as bool
          : (json['remixEnabled']?.toString().toLowerCase() != 'false'),
      audioReuseEnabled: json['audioReuseEnabled'] is bool
          ? json['audioReuseEnabled'] as bool
          : (json['audioReuseEnabled']?.toString().toLowerCase() != 'false'),
      originalReelId: json['originalReelId']?.toString(),
      originalCreatorId: json['originalCreatorId']?.toString(),
      originalCreatorName: json['originalCreatorName']?.toString(),
      isRisingCreator: json['isRisingCreator'] is bool
          ? json['isRisingCreator'] as bool
          : (json['isRisingCreator']?.toString().toLowerCase() == 'true'),
      isTrending: json['isTrending'] is bool
          ? json['isTrending'] as bool
          : (json['isTrending']?.toString().toLowerCase() == 'true'),
      duration: Duration(milliseconds: durationMs),
      peopleTags: json['peopleTags'] is List
          ? (json['peopleTags'] as List)
              .whereType<Map<String, dynamic>>()
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'aspectRatio': aspectRatio,
      'caption': caption,
      'hashtags': hashtags,
      'audioTitle': audioTitle,
      'audioArtist': audioArtist,
      'audioId': audioId,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'views': views,
      'isLiked': isLiked,
      'isSaved': isSaved,
      'isFollowing': isFollowing,
      'createdAt': createdAt.toIso8601String(),
      'isSponsored': isSponsored,
      'sponsorBrand': sponsorBrand,
      'sponsorLogoUrl': sponsorLogoUrl,
      'productTags': productTags?.map((e) => e.toJson()).toList(),
      'remixEnabled': remixEnabled,
      'audioReuseEnabled': audioReuseEnabled,
      'originalReelId': originalReelId,
      'originalCreatorId': originalCreatorId,
      'originalCreatorName': originalCreatorName,
      'isRisingCreator': isRisingCreator,
      'isTrending': isTrending,
      'duration': duration.inMilliseconds,
      'peopleTags': peopleTags,
    };
  }
}

class ProductTag {
  final String id;
  final String name;
  final String? imageUrl;
  final double? price;
  final String? currency;
  final String externalUrl;

  ProductTag({
    required this.id,
    required this.name,
    this.imageUrl,
    this.price,
    this.currency,
    required this.externalUrl,
  });

  factory ProductTag.fromJson(Map<String, dynamic> json) {
    return ProductTag(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString(),
      price: json['price'] is double
          ? json['price'] as double
          : (json['price'] is int
              ? (json['price'] as int).toDouble()
              : double.tryParse(json['price']?.toString() ?? '')),
      currency: json['currency']?.toString() ?? json['currencyCode']?.toString(),
      externalUrl: (json['externalUrl'] ?? json['external_url'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'price': price,
      'currency': currency,
      'externalUrl': externalUrl,
    };
  }
}

class ReelComment {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String text;
  final int likes;
  final bool isLiked;
  final DateTime createdAt;
  final String? parentCommentId; // For replies
  final List<ReelComment> replies;
  final bool isPinned;
  final bool isCreator;

  ReelComment({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.text,
    this.likes = 0,
    this.isLiked = false,
    required this.createdAt,
    this.parentCommentId,
    this.replies = const [],
    this.isPinned = false,
    this.isCreator = false,
  });

  ReelComment copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    String? text,
    int? likes,
    bool? isLiked,
    DateTime? createdAt,
    String? parentCommentId,
    List<ReelComment>? replies,
    bool? isPinned,
    bool? isCreator,
  }) {
    return ReelComment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      text: text ?? this.text,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
      createdAt: createdAt ?? this.createdAt,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replies: replies ?? this.replies,
      isPinned: isPinned ?? this.isPinned,
      isCreator: isCreator ?? this.isCreator,
    );
  }
}
