import '../state/ads_actions.dart';
import '../state/auth_actions.dart';
import '../state/feed_actions.dart';
import '../state/profile_actions.dart';
import '../state/reels_actions.dart';
import '../state/store.dart';
import '../utils/current_user.dart';
import '../widgets/dynamic_media_widget.dart';
import 'media_aspect_cache.dart';
import 'notification_service.dart';
import 'reels_service.dart';
import 'story_cache.dart';
import 'supabase_service.dart';
import 'video_pool.dart';
import '../screens/tweet_composer/tweet_composer_page.dart';

/// Clears user-scoped in-memory state when the authenticated account changes.
class SessionResetService {
  SessionResetService._();

  static final SessionResetService instance = SessionResetService._();

  Future<void> clearUserSessionState() async {
    CurrentUser.clearCache();
    resetMediaAuthHeaders();
    MediaAspectCache.instance.clear();
    StoryCache.clear();
    NotificationService().clearSessionCache();
    clearTweetComposerCache();
    SupabaseService().clearSessionCache();
    ReelsService().clearCache();
    await VideoPool.instance.clearSessionCache();

    globalStore.dispatch(ClearAuthentication());
    globalStore.dispatch(ClearProfile());
    globalStore.dispatch(ClearReels());
    globalStore.dispatch(ClearAds());
    globalStore.dispatch(ClearFeed());
  }
}
