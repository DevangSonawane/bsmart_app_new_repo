import '../models/feed_post_model.dart';

class SetFeedLoading {
  final bool isLoading;
  SetFeedLoading(this.isLoading);
}

class SetFeedPosts {
  final List<FeedPost> posts;
  SetFeedPosts(this.posts);
}

class AppendFeedPosts {
  final List<FeedPost> posts;
  AppendFeedPosts(this.posts);
}

class PrependFeedPost {
  final FeedPost post;
  PrependFeedPost(this.post);
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

class UpdateUserFollowed {
  final String userId;
  final bool followed;
  UpdateUserFollowed(this.userId, this.followed);
}

class UpdatePostCommentsCount {
  final String postId;
  final int commentsCount;
  UpdatePostCommentsCount(this.postId, this.commentsCount);
}

class RemovePost {
  final String postId;
  RemovePost(this.postId);
}
