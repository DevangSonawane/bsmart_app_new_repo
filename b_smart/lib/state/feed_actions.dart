import '../models/feed_post_model.dart';

class SetFeedLoading {
  final bool isLoading;
  SetFeedLoading(this.isLoading);
}

class SetFeedPosts {
  final List<FeedPost> posts;
  SetFeedPosts(this.posts);
}

class UpdatePostLiked {
  final String postId;
  final bool liked;
  UpdatePostLiked(this.postId, this.liked);
}

class UpdatePostLikedWithCount {
  final String postId;
  final bool liked;
  final int likesCount;
  UpdatePostLikedWithCount(this.postId, this.liked, this.likesCount);
}

class UpdatePostSaved {
  final String postId;
  final bool saved;
  UpdatePostSaved(this.postId, this.saved);
}

class UpdatePostFollowed {
  final String postId;
  final bool followed;
  UpdatePostFollowed(this.postId, this.followed);
}

class RemovePost {
  final String postId;
  RemovePost(this.postId);
}
