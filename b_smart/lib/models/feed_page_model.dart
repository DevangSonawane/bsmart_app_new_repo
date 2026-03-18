import 'feed_post_model.dart';

class FeedPage {
  final List<FeedPost> posts;
  final int page;
  final int limit;
  final bool hasMore;
  final String? nextCursor;
  final int? total;

  const FeedPage({
    required this.posts,
    required this.page,
    required this.limit,
    required this.hasMore,
    this.nextCursor,
    this.total,
  });

  FeedPage copyWith({
    List<FeedPost>? posts,
    int? page,
    int? limit,
    bool? hasMore,
    String? nextCursor,
    int? total,
  }) {
    return FeedPage(
      posts: posts ?? this.posts,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      total: total ?? this.total,
    );
  }
}
