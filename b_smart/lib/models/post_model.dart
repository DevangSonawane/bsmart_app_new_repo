class Post {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? imageUrl;
  final String? videoUrl;
  final String? caption;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final bool isLiked;
  final bool isTagged;
  final bool isShared;
  final String? sharedFrom;
  final bool isAd;
  final String? adTitle;

  Post({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.imageUrl,
    this.videoUrl,
    this.caption,
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.isLiked = false,
    this.isTagged = false,
    this.isShared = false,
    this.sharedFrom,
    this.isAd = false,
    this.adTitle,
  });
}

class Reel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String videoUrl;
  final String? caption;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final int views;
  final bool isLiked;
  final bool isPromotedProduct;

  Reel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.videoUrl,
    this.caption,
    required this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.views = 0,
    this.isLiked = false,
    this.isPromotedProduct = false,
  });
}
