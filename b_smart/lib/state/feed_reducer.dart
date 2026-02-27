import 'package:redux/redux.dart';
import 'feed_state.dart';
import 'feed_actions.dart';
import '../models/feed_post_model.dart';

final feedReducer = combineReducers<FeedState>([
  TypedReducer<FeedState, SetFeedLoading>(_setLoading),
  TypedReducer<FeedState, SetFeedPosts>(_setPosts),
  TypedReducer<FeedState, UpdatePostLiked>(_updatePostLiked),
  TypedReducer<FeedState, UpdatePostLikedWithCount>(_updatePostLikedWithCount),
  TypedReducer<FeedState, UpdatePostSaved>(_updatePostSaved),
  TypedReducer<FeedState, UpdatePostFollowed>(_updatePostFollowed),
  TypedReducer<FeedState, RemovePost>(_removePost),
]);

FeedState _setLoading(FeedState state, SetFeedLoading action) {
  return state.copyWith(isLoading: action.isLoading);
}

FeedState _setPosts(FeedState state, SetFeedPosts action) {
  return state.copyWith(posts: action.posts, isLoading: false);
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
  final prev = state.posts[idx];
  if (prev.isFollowed == action.followed) return state;
  final updated = prev.copyWith(isFollowed: action.followed);
  final next = List<FeedPost>.from(state.posts);
  next[idx] = updated;
  return state.copyWith(posts: next);
}

FeedState _removePost(FeedState state, RemovePost action) {
  final next = state.posts.where((p) => p.id != action.postId).toList();
  return state.copyWith(posts: next);
}
