import 'package:meta/meta.dart';
import '../models/feed_post_model.dart';

@immutable
class FeedState {
  final List<FeedPost> posts;
  final bool isLoading;

  const FeedState({
    this.posts = const [],
    this.isLoading = false,
  });

  factory FeedState.initial() => const FeedState();
  // Set initial loading to true to avoid "No posts yet" flash before first fetch.
  // This matches the React Home.jsx behavior which shows a spinner until the feed loads.
  // ignore: dead_code
  // The below line overrides the factory if used directly.
  // Keeping both for clarity: most code uses `FeedState.initial()`.
  const FeedState.initialLoading()
      : posts = const [],
        isLoading = true;

  FeedState copyWith({
    List<FeedPost>? posts,
    bool? isLoading,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
