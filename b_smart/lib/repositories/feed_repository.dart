import '../models/feed_page_model.dart';
import '../models/story_model.dart';
import '../services/feed_service.dart';

class FeedRepository {
  final FeedService _feedService;

  FeedRepository({FeedService? feedService})
      : _feedService = feedService ?? FeedService();

  Future<FeedPage> fetchFeedPage({
    required int page,
    required int limit,
    String? currentUserId,
    String? cursor,
    bool useBackendDefault = false,
  }) async {
    // Cursor not currently supported by backend; keep param for future use.
    return _feedService.fetchFeedPage(
      page: page,
      limit: limit,
      currentUserId: currentUserId,
      useBackendDefault: useBackendDefault,
    );
  }

  Future<List<StoryGroup>> fetchStories() {
    return _feedService.fetchStoriesFeed();
  }
}
