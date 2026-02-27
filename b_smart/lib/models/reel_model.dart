import 'feed_post_model.dart';

class Reel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String videoUrl;
  final String? thumbnailUrl;
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
