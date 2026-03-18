import 'package:meta/meta.dart';
import '../models/feed_post_model.dart';
import '../models/story_model.dart';

@immutable
class FeedPagingState {
  final List<FeedPost> posts;
  final List<StoryGroup> stories;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final bool isOffline;

  const FeedPagingState({
    this.posts = const [],
    this.stories = const [],
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.isOffline = false,
  });

  FeedPagingState copyWith({
    List<FeedPost>? posts,
    List<StoryGroup>? stories,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    bool? isOffline,
  }) {
    return FeedPagingState(
      posts: posts ?? this.posts,
      stories: stories ?? this.stories,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isOffline: isOffline ?? this.isOffline,
    );
  }
}
