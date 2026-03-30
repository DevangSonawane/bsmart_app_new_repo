import 'package:redux/redux.dart';
import 'feed_state.dart';
import 'feed_actions.dart';
import '../models/feed_post_model.dart';

final feedReducer = combineReducers<FeedState>([
  TypedReducer<FeedState, SetFeedLoading>(_setLoading).call,
  TypedReducer<FeedState, SetFeedPosts>(_setPosts).call,
  TypedReducer<FeedState, UpdatePostLiked>(_updatePostLiked).call,
  TypedReducer<FeedState, UpdatePostLikedWithCount>(_updatePostLikedWithCount).call,
  TypedReducer<FeedState, UpdatePostSaved>(_updatePostSaved).call,
  TypedReducer<FeedState, UpdatePostFollowed>(_updatePostFollowed).call,
  TypedReducer<FeedState, UpdateUserFollowed>(_updateUserFollowed).call,
  TypedReducer<FeedState, UpdatePostCommentsCount>(_updatePostCommentsCount).call,
  TypedReducer<FeedState, RemovePost>(_removePost).call,
  TypedReducer<FeedState, AppendFeedPosts>(_appendPosts).call,
  TypedReducer<FeedState, PrependFeedPost>(_prependPost).call,
]);



FeedState _appendPosts(FeedState state, AppendFeedPosts action) {
  if (action.posts.isEmpty) return state;
  final existingIds = state.posts.map((p) => p.id).toSet();
  final next = List<FeedPost>.from(state.posts);
  for (final p in action.posts) {
    if (!existingIds.contains(p.id)) {
      next.add(p);
      existingIds.add(p.id);
    }
  }
  return state.copyWith(posts: next, isLoading: false);
}

FeedState _prependPost(FeedState state, PrependFeedPost action) {
  final p = action.post;
  if (p.id.isEmpty) return state;
  final existingIds = state.posts.map((e) => e.id).toSet();
  if (existingIds.contains(p.id)) return state;
  final next = [p, ...state.posts];
  return state.copyWith(posts: next);
}

FeedState _setLoading(FeedState state, SetFeedLoading action) {
  return state.copyWith(isLoading: action.isLoading);
}

FeedState _setPosts(FeedState state, SetFeedPosts action) {
  return state.copyWith(
    posts: List<FeedPost>.from(action.posts),
    isLoading: false,
  );
}

FeedState _updatePostLiked(FeedState state, UpdatePostLiked action) {
  final idx = state.posts.indexWhere((p) => p.id == action.postId);
  if (idx == -1) return state;
  final prev = state.posts[idx];
  if (prev.isLiked == action.liked) return state;
  final updated = prev.copyWith(
    isLiked: action.liked,
    likes: action.liked ? prev.likes + 1 : prev.likes - 1,
  );
  final next = List<FeedPost>.from(state.posts);
  next[idx] = updated;
  return state.copyWith(posts: next);
}

FeedState _updatePostSaved(FeedState state, UpdatePostSaved action) {
  final idx = state.posts.indexWhere((p) => p.id == action.postId);
  if (idx == -1) return state;
  final prev = state.posts[idx];
  if (prev.isSaved == action.saved) return state;
  final updated = prev.copyWith(isSaved: action.saved);
  final next = List<FeedPost>.from(state.posts);
  next[idx] = updated;
  return state.copyWith(posts: next);
}

FeedState _updatePostLikedWithCount(FeedState state, UpdatePostLikedWithCount action) {
  final idx = state.posts.indexWhere((p) => p.id == action.postId);
  if (idx == -1) return state;
  final prev = state.posts[idx];
  final updated = prev.copyWith(
    isLiked: action.liked,
    likes: action.likesCount,
  );
  final next = List<FeedPost>.from(state.posts);
  next[idx] = updated;
  return state.copyWith(posts: next);
}

FeedState _updatePostFollowed(FeedState state, UpdatePostFollowed action) {
  final idx = state.posts.indexWhere((p) => p.id == action.postId);
  if (idx == -1) return state;
  final targetUserId = state.posts[idx].userId;
  var changed = false;
  final next = state.posts.map((post) {
    final matchesUser = targetUserId.isNotEmpty && post.userId == targetUserId;
    final matchesPost = post.id == action.postId;
    if (!matchesUser && !matchesPost) return post;
    if (post.isFollowed == action.followed) return post;
    changed = true;
    return post.copyWith(isFollowed: action.followed);
  }).toList(growable: false);
  if (!changed) return state;
  return state.copyWith(posts: next);
}

FeedState _updateUserFollowed(FeedState state, UpdateUserFollowed action) {
  if (action.userId.isEmpty) return state;
  var changed = false;
  final next = state.posts.map((post) {
    if (post.userId != action.userId) return post;
    if (post.isFollowed == action.followed) return post;
    changed = true;
    return post.copyWith(isFollowed: action.followed);
  }).toList(growable: false);
  if (!changed) return state;
  return state.copyWith(posts: next);
}

FeedState _updatePostCommentsCount(FeedState state, UpdatePostCommentsCount action) {
  final idx = state.posts.indexWhere((p) => p.id == action.postId);
  if (idx == -1) return state;
  final prev = state.posts[idx];
  if (prev.comments == action.commentsCount) return state;
  final updated = prev.copyWith(comments: action.commentsCount);
  final next = List<FeedPost>.from(state.posts);
  next[idx] = updated;
  return state.copyWith(posts: next);
}

FeedState _removePost(FeedState state, RemovePost action) {
  final next = state.posts.where((p) => p.id != action.postId).toList();
  return state.copyWith(posts: next);
}
