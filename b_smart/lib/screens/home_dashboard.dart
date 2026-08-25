import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/feed_service.dart';
import '../services/notification_service.dart';
import '../services/media_playback_registry.dart';
import '../services/supabase_service.dart';
import '../services/ui_surface_memory_service.dart';
import '../services/wallet_service.dart';
import '../services/video_pool.dart';
import '../preferences/storage_preferences_scope.dart';
import '../services/network_status_scope.dart';
import '../state/app_state.dart';
import '../state/profile_actions.dart';
import '../state/feed_actions.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_row.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/sidebar.dart';
import '../widgets/content_report_sheet.dart';
import '../theme/design_tokens.dart';
import '../models/story_model.dart';
import '../models/feed_post_model.dart';
import '../models/notification_model.dart';
import '../models/reel_model.dart';
import '../models/media_model.dart';
import '../widgets/post_detail_modal.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/share_content_modal.dart';
import 'ads_page_screen.dart';
import 'promote_screen.dart';
import 'reels_screen.dart';
import '../services/reels_service.dart';
import 'story_viewer_screen.dart';
import 'own_story_viewer_screen.dart';
import 'create_upload_screen.dart';
import '../utils/current_user.dart';
import '../utils/id_extractor.dart';
import '../utils/share_links.dart';
import '../api/auth_api.dart';
import '../api/api_exceptions.dart';
import '../api/api_client.dart';
import '../api/follows_api.dart';
import '../api/privacy_api.dart';
import '../api/users_api.dart';
import '../api/suggestions_api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/url_helper.dart';
import '../widgets/dynamic_media_widget.dart';
import '../widgets/floating_message_overlay.dart';
import '../widgets/showcase_tooltip_actions.dart';
import '../widgets/suggestion_follow.dart';
import '../widgets/suggested_reels_card.dart';
import '../models/location_place.dart';
import 'location_search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'profile_screen.dart';
import '../routes.dart';
import 'follow_list_screen.dart';
import 'messaging_screen.dart';
import '../services/home_onboarding_service.dart';

class _FeedHeader extends StatelessWidget {
  final List<Map<String, dynamic>> storyUsers;
  final List<StoryGroup> storyGroups;
  final Map<String, Map<String, bool>> storyStatuses;
  final bool yourStoryHasActive;
  final String? yourAvatarUrl;
  final String? currentLocation;
  final bool locationLoading;
  final bool isDark;
  final VoidCallback onYourStoryTap;
  final VoidCallback onYourStoryAddTap;
  final Function(int)? onUserStoryTap;
  final VoidCallback onLocationTap;

  const _FeedHeader({
    required this.storyUsers,
    required this.storyGroups,
    required this.storyStatuses,
    required this.yourStoryHasActive,
    required this.yourAvatarUrl,
    required this.currentLocation,
    required this.locationLoading,
    required this.isDark,
    required this.onYourStoryTap,
    required this.onYourStoryAddTap,
    required this.onUserStoryTap,
    required this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onLocationTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(
                  color:
                      isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.house,
                  size: 16,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${'home_dashboard_home'.tr().toUpperCase()} ',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        TextSpan(
                          text: currentLocation == null
                              ? (locationLoading
                                  ? 'Restoring location...'
                                  : 'Tap to search location')
                              : currentLocation!,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        StoriesRow(
          users: storyUsers,
          onYourStoryTap: onYourStoryTap,
          onYourStoryAddTap: onYourStoryAddTap,
          onUserStoryTap: storyGroups.isEmpty ? null : onUserStoryTap,
          yourStoryHasActive: yourStoryHasActive,
          yourAvatarUrl: yourAvatarUrl,
          showYourStory: true,
          userStatuses: storyStatuses,
        ),
      ],
    );
  }
}

enum _FeedRenderRowType {
  post,
  suggestedReels,
  suggestedAds,
  suggestedPeople,
  suggestedVendors,
}

class _FeedRenderRow {
  final _FeedRenderRowType type;
  final FeedPost? post;
  final int suggestionBlockIndex;

  const _FeedRenderRow._({
    required this.type,
    required this.post,
    required this.suggestionBlockIndex,
  });

  factory _FeedRenderRow.post(FeedPost post) {
    return _FeedRenderRow._(
      type: _FeedRenderRowType.post,
      post: post,
      suggestionBlockIndex: -1,
    );
  }

  factory _FeedRenderRow.peopleSuggestions(int blockIndex) {
    return _FeedRenderRow._(
      type: _FeedRenderRowType.suggestedPeople,
      post: null,
      suggestionBlockIndex: blockIndex,
    );
  }

  factory _FeedRenderRow.vendorSuggestions(int blockIndex) {
    return _FeedRenderRow._(
      type: _FeedRenderRowType.suggestedVendors,
      post: null,
      suggestionBlockIndex: blockIndex,
    );
  }

  factory _FeedRenderRow.reelsSuggestions() {
    return const _FeedRenderRow._(
      type: _FeedRenderRowType.suggestedReels,
      post: null,
      suggestionBlockIndex: -1,
    );
  }

  factory _FeedRenderRow.adsSuggestion(FeedPost? post) {
    return _FeedRenderRow._(
      type: _FeedRenderRowType.suggestedAds,
      post: post,
      suggestionBlockIndex: -1,
    );
  }
}

class HomeDashboard extends StatefulWidget {
  final int? initialIndex;

  const HomeDashboard({super.key, this.initialIndex});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard>
    with RouteAware, WidgetsBindingObserver {
  // First-run onboarding only. Set this to true temporarily if you want to
  // replay the walkthrough on every app launch during testing.
  static const bool _showOnEveryLaunchForTesting = false;

  final HomeOnboardingStep _profileStep = HomeOnboardingStep(
    key: GlobalKey(),
    title: '👤 Your Profile',
    description:
        'View your profile, manage your account, update your information, and customize your BSmart experience.',
    tooltipPosition: TooltipPosition.bottom,
  );
  final HomeOnboardingStep _homeStep = HomeOnboardingStep(
    key: GlobalKey(),
    title: '🏠 Home Feed',
    description:
        'Discover the latest moments, updates, and activities from your community.',
    tooltipPosition: TooltipPosition.top,
  );
  final HomeOnboardingStep _adsStep = HomeOnboardingStep(
    key: GlobalKey(),
    title: '📢 Spotlights',
    description:
        'Explore sponsored offers, promotions, and featured opportunities from businesses.',
    tooltipPosition: TooltipPosition.top,
  );
  final HomeOnboardingStep _createStep = HomeOnboardingStep(
    key: GlobalKey(),
    title: '➕ Create',
    description:
        'Create a new moment, upload a bSpark, share photos, or express your ideas with the community.',
    isPrimaryAction: true,
    tooltipPosition: TooltipPosition.top,
  );
  final HomeOnboardingStep _rocketStep = HomeOnboardingStep(
    key: GlobalKey(),
    title: '🚀 Campaigns',
    description:
        'Find trending creators, popular content, and exciting communities waiting for you.',
    tooltipPosition: TooltipPosition.top,
  );
  final HomeOnboardingStep _reelsStep = HomeOnboardingStep(
    key: GlobalKey(),
    title: '🎬 B.Sparks',
    description:
        'Watch engaging short videos and discover entertaining content from creators.',
    tooltipPosition: TooltipPosition.top,
  );
  final HomeOnboardingStep _walletStep = HomeOnboardingStep(
    key: GlobalKey(),
    title: '💰 Vault',
    description:
        'Track your earnings, rewards, transactions, and redeem available benefits.',
    tooltipPosition: TooltipPosition.bottom,
  );

  final FeedService _feedService = FeedService();
  final NotificationService _notificationService = NotificationService();
  final SupabaseService _supabase = SupabaseService();
  final WalletService _walletService = WalletService();
  final ReelsService _reelsService = ReelsService();
  final FollowsApi _followsApi = FollowsApi();
  final UsersApi _usersApi = UsersApi();
  final SuggestionsApi _suggestionsApi = SuggestionsApi();
  String? _currentLocation;
  bool _locationLoading = false;

  List<Map<String, dynamic>> _storyUsers = [];
  List<StoryGroup> _storyGroups = [];
  List<Story> _myStories = [];
  String? _myStoryId;
  bool _yourStoryHasActive = false;
  Map<String, Map<String, bool>> _storyStatuses = {};
  int _currentIndex = 0;
  PageController? _tabPageController;
  static const List<int> _swipeTabs = [0, 1, 3, 4];
  int _balance = 0;
  bool _reelsPrefetched = false;
  String? _activeFeedPostId;
  final ValueNotifier<String?> _activeFeedPostIdListenable =
      ValueNotifier<String?>(null);
  Timer? _activeFeedDebounce;
  bool _isCommentsOpen = false;
  final Set<String> _prewarmedFeedIds = {};
  final Set<String> _prewarmedFeedAvatarUrls = {};
  bool _isFeedScrolling = false;
  Timer? _feedScrollSaveDebounce;
  String? _pendingActivePostId;
  ScrollPosition? _trackedFeedScrollPosition;
  int _feedSkeletonLoadCount = 0;
  int _unreadNotificationCount = 0;
  StreamSubscription<List<NotificationItem>>? _notificationSub;
  Timer? _notificationRefreshTimer;

  final ScrollController _feedScrollController = ScrollController();
  final int _pageSize = 25;
  int _visibleCount = 0;
  int _pageCursor = 2; // next server page to try after initial default feed
  bool _pagingInFlight = false;
  bool _noMorePages = false;

  bool _followSuggestionsLoading = false;
  List<SuggestionUser> _followSuggestions = <SuggestionUser>[];
  final Set<String> _dismissedSuggestionUserIds = <String>{};
  final Set<String> _suggestionFollowOpsInFlight = <String>{};
  Map<String, String> _suggestionImageHeaders = const <String, String>{};

  bool _vendorSuggestionsLoading = false;
  List<SuggestionUser> _vendorSuggestions = <SuggestionUser>[];
  final Set<String> _dismissedVendorSuggestionIds = <String>{};

  bool _adSuggestionsLoading = false;
  List<FeedPost> _adSuggestions = const <FeedPost>[];

  bool _reelSuggestionsLoading = false;
  List<Reel> _suggestedReels = const <Reel>[];

  /// Current user profile from `users` table (same source as React web app) for header avatar.
  Map<String, dynamic>? _currentUserProfile;
  String? _currentUserId;
  bool get _isVendor =>
      (_currentUserProfile?['role']?.toString().toLowerCase() ?? '') ==
      'vendor';

  PageRoute<dynamic>? _subscribedRoute;
  bool _isRouteActive = true;
  bool _pendingHomeRefreshAfterRoute = false;
  Timer? _autoRefreshDebounce;
  DateTime? _lastAutoRefreshAt;
  bool _onboardingStartQueued = false;
  bool _onboardingHasStarted = false;
  bool _onboardingDialogVisible = false;
  bool _onboardingPageScrollLocked = false;

  bool? _parseBoolLike(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return null;
  }

  String _extractAdId(String rawId) {
    var id = rawId.trim();
    if (id.startsWith('ad-')) {
      id = id.substring(3);
    }
    final slotIdx = id.indexOf('-slot-');
    if (slotIdx >= 0) {
      id = id.substring(0, slotIdx);
    }
    return id.trim();
  }

  bool? _extractLikedFlag(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final direct = _parseBoolLike(payload['is_liked_by_me']) ??
        _parseBoolLike(payload['liked_by_me']) ??
        _parseBoolLike(payload['is_liked']) ??
        _parseBoolLike(payload['liked']) ??
        _parseBoolLike(payload['isLiked']);
    if (direct != null) return direct;

    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return null;
    final rawLikes = payload['likes'];
    if (rawLikes is! List) return null;
    for (final e in rawLikes) {
      if (e is String && e == currentUserId) return true;
      if (e is Map) {
        final uid = (e['user_id'] ??
                e['id'] ??
                e['_id'] ??
                (e['user'] is Map ? (e['user'] as Map)['_id'] : null))
            ?.toString();
        if (uid != null && uid == currentUserId) return true;
      }
    }
    return false;
  }

  int? _extractLikesCount(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final value = payload['likes_count'] ?? payload['likesCount'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    final likes = payload['likes'];
    if (likes is List) return likes.length;
    return null;
  }

  Map<String, dynamic>? _normalizeProfile(Map<String, dynamic>? raw) {
    if (raw == null) return null;

    Map<String, dynamic> data = Map<String, dynamic>.from(raw);
    if (raw['user'] is Map) {
      data = Map<String, dynamic>.from(raw['user'] as Map);
    } else if (raw['data'] is Map) {
      final wrapped = Map<String, dynamic>.from(raw['data'] as Map);
      if (wrapped['user'] is Map) {
        data = Map<String, dynamic>.from(wrapped['user'] as Map);
      } else {
        data = wrapped;
      }
    }

    final normalized = Map<String, dynamic>.from(data);
    final avatar = data['avatar_url'] ??
        data['avatarUrl'] ??
        data['photo_url'] ??
        data['photoUrl'];
    final username = data['username'] ?? data['user_name'];
    final fullName = data['full_name'] ?? data['fullName'] ?? data['name'];
    final id = data['id'] ?? data['_id'] ?? data['user_id'];
    final role = data['role'];
    final isActive = data['is_active'] ?? data['isActive'];

    if (avatar != null) normalized['avatar_url'] = avatar.toString();
    if (username != null) normalized['username'] = username.toString();
    if (fullName != null) normalized['full_name'] = fullName.toString();
    if (role != null) normalized['role'] = role.toString();
    if (isActive != null) normalized['is_active'] = isActive == true;
    if (id != null) {
      normalized['id'] = id.toString();
      normalized['_id'] = id.toString();
    }

    return normalized;
  }

  void _openProfile() {
    final userId = _currentUserId?.trim() ??
        (_currentUserProfile?['id']?.toString().trim()) ??
        (_currentUserProfile?['_id']?.toString().trim());
    if (userId != null && userId.isNotEmpty) {
      Navigator.of(context).pushNamed('/profile/$userId');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeOnboardingService.instance.bindCallbacks(
      onFinished: _handleOnboardingFinished,
      onDismissed: _handleOnboardingDismissed,
    );
    MediaPlaybackRegistry.instance.register('home-dashboard', () async {
      _activeFeedPostId = null;
      _activeFeedPostIdListenable.value = null;
      await VideoPool.instance.pauseActive();
    });
    _notificationSub = _notificationService.getNotificationsStream().listen(
      (notifications) {
        if (!mounted) return;
        setState(() {
          _unreadNotificationCount = notifications
              .where((notification) => !notification.isRead)
              .length;
        });
      },
    );
    _loadUnreadNotificationCount();
    _notificationRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshUnreadNotificationCount();
    });
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 100);
    if (widget.initialIndex != null) {
      _currentIndex = widget.initialIndex!;
    }
    final initialPage = _swipeTabs.indexOf(_currentIndex);
    _tabPageController =
        PageController(initialPage: initialPage < 0 ? 0 : initialPage);
    _feedScrollController.addListener(_onFeedScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachFeedScrollActivityListener();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scheduleHomeOnboarding());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(primeMediaAuthHeaders());
      final store = StoreProvider.of<AppState>(context);
      // Force a clean, fresh feed on app open to avoid stale or partial data.
      store.dispatch(SetFeedPosts(const []));
      store.dispatch(SetFeedLoading(true));
      _beginFeedSkeletonLoading();
      _loadData(store);
      _loadInitialFeed(forceNetwork: true);
      unawaited(_loadFollowSuggestions());
      unawaited(_loadVendorSuggestions());
      unawaited(_loadAdSuggestions());
      unawaited(_loadReelSuggestions(force: true));
      unawaited(_restoreSavedLocation());
    });
  }

  static const String _savedLocationPrefsKey =
      'home_dashboard_selected_location';

  Future<void> _scheduleHomeOnboarding() async {
    if (!mounted || _onboardingStartQueued || _onboardingHasStarted) return;
    _onboardingStartQueued = true;

    try {
      if (MediaQuery.sizeOf(context).width >= 768) return;
      if (_showOnEveryLaunchForTesting) {
        if (!mounted || _currentIndex != 0) return;
      } else {
        final completed = await HomeOnboardingService.instance.isCompleted();
        if (!mounted || completed || _currentIndex != 0) return;
      }

      // Give the home view a moment to settle so the overlay lands on the
      // fully built layout rather than racing the first render.
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted || _onboardingHasStarted || _currentIndex != 0) return;

      final showcase = ShowcaseView.get();
      final keys = _homeOnboardingKeys;
      if (keys.isEmpty) return;

      _onboardingHasStarted = true;
      _onboardingPageScrollLocked = true;
      showcase.startShowCase(keys);
    } catch (e) {
      debugPrint('Home onboarding launch skipped: $e');
    } finally {
      _onboardingStartQueued = false;
    }
  }

  List<GlobalKey<State<StatefulWidget>>> get _homeOnboardingKeys => [
        _profileStep.key,
        _homeStep.key,
        _adsStep.key,
        _createStep.key,
        _rocketStep.key,
        _reelsStep.key,
        _walletStep.key,
      ];

  Future<void> _handleOnboardingFinished() async {
    if (!_showOnEveryLaunchForTesting) {
      await HomeOnboardingService.instance.markCompleted();
    }
    if (!mounted) return;
    if (_onboardingDialogVisible) return;
    _onboardingDialogVisible = true;
    await _showWelcomeDialog();
    if (mounted) {
      _onboardingHasStarted = false;
      _onboardingDialogVisible = false;
      _onboardingPageScrollLocked = false;
    }
  }

  Future<void> _handleOnboardingDismissed() async {
    if (!_showOnEveryLaunchForTesting) {
      await HomeOnboardingService.instance.markCompleted();
    }
    _onboardingHasStarted = false;
    _onboardingDialogVisible = false;
    _onboardingPageScrollLocked = false;
  }

  Future<void> _showWelcomeDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF17141C), Color(0xFF0F1117)]
                    : const [Color(0xFFFFFFFF), Color(0xFFFFF3F7)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: DesignTokens.instaGradient,
                      boxShadow: [
                        BoxShadow(
                          color: DesignTokens.instaPink.withValues(alpha: 0.24),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.sparkles,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '🎉 Welcome to BSmart!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "You're ready to explore BSmart! Start connecting with people, creating content, discovering new communities, and enjoying everything the platform has to offer.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: DesignTokens.instaPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text("Let's Go"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _restoreSavedLocation() async {
    try {
      if (mounted) {
        setState(() => _locationLoading = true);
      }
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedLocationPrefsKey);
      if (raw == null || raw.trim().isEmpty) {
        if (mounted) setState(() => _locationLoading = false);
        unawaited(_selectCurrentLocation());
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        if (mounted) setState(() => _locationLoading = false);
        unawaited(_selectCurrentLocation());
        return;
      }
      final place = LocationPlace.fromJson(Map<String, dynamic>.from(decoded));
      if (!mounted) return;
      setState(() {
        _currentLocation = place.fullText.isNotEmpty
            ? place.fullText
            : (place.displayText.isNotEmpty ? place.displayText : null);
        _locationLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _locationLoading = false);
        unawaited(_selectCurrentLocation());
      }
    }
  }

  Future<void> _saveSelectedLocation(LocationPlace place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedLocationPrefsKey, jsonEncode(place.toJson()));
    } catch (_) {
      // Non-fatal. The selection still updates immediately in memory.
    }
  }

  Future<void> _selectCurrentLocation() async {
    try {
      if (mounted) {
        setState(() => _locationLoading = true);
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationLoading = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);

      String name = '';
      String address = '';
      String fullText = '';

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.name ?? '').isNotEmpty) p.name!,
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
          if ((p.country ?? '').isNotEmpty) p.country!,
        ];
        fullText = parts.where((e) => e.trim().isNotEmpty).toList().join(', ');
        name = (p.locality ?? p.subLocality ?? p.name ?? '').trim();
        address = [
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality,
          if ((p.locality ?? '').isNotEmpty) p.locality,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea,
          if ((p.country ?? '').isNotEmpty) p.country,
        ].whereType<String>().where((e) => e.trim().isNotEmpty).join(', ');
      }

      fullText = fullText.isNotEmpty
          ? fullText
          : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      name = name.isNotEmpty ? name : fullText;
      address = address.isNotEmpty ? address : fullText;

      final place = LocationPlace(
        placeId: 'current-location',
        name: name,
        address: address,
        fullText: fullText,
      );

      if (!mounted) return;
      setState(() {
        _currentLocation = place.fullText;
        _locationLoading = false;
      });
      unawaited(_saveSelectedLocation(place));
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    final unreadCount = await _notificationService.getUnreadCount();
    if (!mounted) return;
    setState(() => _unreadNotificationCount = unreadCount);
  }

  Future<void> _refreshUnreadNotificationCount() async {
    if (!mounted) return;
    final unreadCount = await _notificationService.getUnreadCount();
    if (!mounted) return;
    if (unreadCount != _unreadNotificationCount) {
      setState(() => _unreadNotificationCount = unreadCount);
    }
  }

  String _suggestionIdOf(Map<String, dynamic> u) {
    final embedded = u['user'];
    return extractEntityId(embedded ?? u) ?? '';
  }

  String _suggestionTitleOf(Map<String, dynamic> u) {
    final embedded = u['user'];
    if (embedded is Map) {
      return _suggestionTitleOf(Map<String, dynamic>.from(embedded));
    }
    final rawUsername = u['username'] ?? u['userName'];
    final username = rawUsername == null ? '' : rawUsername.toString().trim();
    if (username.isNotEmpty) return username;
    final name =
        (u['full_name'] ?? u['name'] ?? u['fullName'])?.toString() ?? '';
    return name.trim().isNotEmpty ? name.trim() : 'user';
  }

  String _suggestionNameOf(Map<String, dynamic> u) {
    final embedded = u['user'];
    if (embedded is Map) {
      return _suggestionNameOf(Map<String, dynamic>.from(embedded));
    }
    final raw = u['full_name'] ??
        u['fullName'] ??
        u['display_name'] ??
        u['displayName'] ??
        u['name'];
    return raw == null ? '' : raw.toString().trim();
  }

  String _suggestionAvatarOf(Map<String, dynamic> u) {
    final embedded = u['user'];
    if (embedded is Map) {
      return _suggestionAvatarOf(Map<String, dynamic>.from(embedded));
    }
    final raw = u['avatar_url'] ??
        u['avatarUrl'] ??
        u['profile_picture'] ??
        u['profile_pic'] ??
        u['profilePic'] ??
        u['profilePicture'] ??
        u['avatar'];
    return raw == null ? '' : raw.toString();
  }

  bool _suggestionIsFollowingOf(Map<String, dynamic> u) =>
      _parseBoolLike(u['isFollowing']) ??
      _parseBoolLike(u['is_followed_by_me']) ??
      (u['user'] is Map
          ? _suggestionIsFollowingOf(Map<String, dynamic>.from(u['user']))
          : false);

  String? _suggestionReasonOf(Map<String, dynamic> u) {
    final embedded = u['user'];
    final source = embedded is Map ? Map<String, dynamic>.from(embedded) : u;
    final mutual = source['mutual_friends_count'] ?? source['mutualCount'];
    if (mutual is num && mutual.toInt() > 0) return '${mutual.toInt()} mutual';
    final followedBy =
        (source['followed_by'] ?? source['followedBy'])?.toString().trim();
    if (followedBy != null && followedBy.isNotEmpty) {
      return 'Followed by $followedBy';
    }
    final reason =
        (u['reason'] ?? u['message'] ?? u['subtitle'])?.toString().trim();
    if (reason != null && reason.isNotEmpty) return reason;
    return 'Suggested for you';
  }

  String _suggestionRoleOf(Map<String, dynamic> u) {
    final embedded = u['user'];
    if (embedded is Map) {
      return _suggestionRoleOf(Map<String, dynamic>.from(embedded));
    }
    final raw = u['role'] ??
        u['user_role'] ??
        u['userRole'] ??
        u['user_type'] ??
        u['userType'] ??
        u['type'] ??
        u['accountType'] ??
        u['account_type'];
    return raw == null ? '' : raw.toString().toLowerCase().trim();
  }

  bool _isUserSuggestionAccount(Map<String, dynamic> u) {
    final role = _suggestionRoleOf(u);
    if (role.isEmpty) return true;

    const nonUserRoles = <String>{
      'admin',
      'administrator',
      'business',
      'vendor',
      'advertiser',
      'ads',
      'company',
      'brand',
      'organization',
      'organisation',
      'org',
      'page',
      'team',
      'store',
      'shop',
      'agency',
      'official',
      'enterprise',
    };

    if (nonUserRoles.contains(role)) return false;

    const userRoles = <String>{
      'user',
      'member',
      'creator',
      'regular',
      'personal',
      'individual',
    };

    return userRoles.contains(role);
  }

  Future<void> _loadFollowSuggestions({bool force = false}) async {
    if (_followSuggestionsLoading) return;
    if (!force && _followSuggestions.isNotEmpty) return;
    setState(() => _followSuggestionsLoading = true);
    try {
      final token = await ApiClient().getToken();
      if (token != null &&
          token.isNotEmpty &&
          _suggestionImageHeaders.isEmpty &&
          mounted) {
        setState(() {
          _suggestionImageHeaders = <String, String>{
            'Authorization': 'Bearer $token',
          };
        });
      }

      List<Map<String, dynamic>> list = const <Map<String, dynamic>>[];
      try {
        // React parity: GET /api/suggestions/users?limit=...
        list = await _suggestionsApi.getUserSuggestions(limit: 80);
      } catch (_) {
        // Fallback to older behavior: fetch all users and shuffle client-side.
        final users = await _usersApi.search('');
        list = users
            .map((e) => Map<String, dynamic>.from(e))
            .where((u) => _suggestionIdOf(u).trim().isNotEmpty)
            .where(_isUserSuggestionAccount)
            .toList();
      }
      list = list
          .where((u) => _isUserSuggestionAccount(u))
          .where((u) => privacyAppearsInSuggestions(u))
          .toList();
      list.shuffle();
      if (list.length > 80) {
        list.removeRange(80, list.length);
      }

      final ids = list.map(_suggestionIdOf).where((e) => e.isNotEmpty).toList();
      if (ids.isNotEmpty && (_currentUserId?.isNotEmpty ?? false)) {
        try {
          final statuses = await _followsApi.bulkCheckFollowStatus(ids);
          final statusMap = <String, Map<String, dynamic>>{};
          for (final s in statuses) {
            final sid = (s['userId'] as String?) ??
                (s['_id'] as String?) ??
                (s['id'] as String?) ??
                '';
            if (sid.isNotEmpty) statusMap[sid] = s;
          }
          for (var i = 0; i < list.length; i++) {
            final u = list[i];
            final uid = _suggestionIdOf(u);
            final s = statusMap[uid];
            if (s == null) continue;
            list[i] = <String, dynamic>{
              ...u,
              ...s,
              'isFollowing':
                  (s['isFollowing'] as bool?) ?? _suggestionIsFollowingOf(u),
            };
          }
        } catch (_) {
          // ignore
        }
      }

      final parsed = <SuggestionUser>[];
      for (final u in list) {
        final id = _suggestionIdOf(u).trim();
        if (id.isEmpty) continue;
        if ((_currentUserId ?? '').isNotEmpty && id == _currentUserId) {
          continue;
        }
        final isFollowing = _suggestionIsFollowingOf(u);
        if (isFollowing) continue;
        final avatar = _suggestionAvatarOf(u).trim();
        final username = _suggestionTitleOf(u);
        final name = _suggestionNameOf(u);
        parsed.add(
          SuggestionUser(
            id: id,
            title: username,
            subtitle: (name.isNotEmpty && name != username)
                ? name
                : _suggestionReasonOf(u),
            avatarUrl: avatar.isEmpty ? null : UrlHelper.absoluteUrl(avatar),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _followSuggestions = parsed;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() {
          _followSuggestionsLoading = false;
        });
      }
    }
  }

  String _vendorSuggestionIdOf(Map<String, dynamic> v) {
    final embedded = v['vendor'] ?? v['business'] ?? v['company'];
    String? pickId(dynamic value) {
      if (value == null) return null;
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        for (final key in const [
          'user_id',
          'userId',
          'vendorUserId',
          'vendor_user_id',
          'owner_id',
          'ownerId',
          '_id',
          'id',
          'vendorId',
          'vendor_id',
        ]) {
          final candidate = pickId(map[key]);
          if (candidate != null && candidate.isNotEmpty) return candidate;
        }
        return extractEntityId(map);
      }
      return extractEntityId(value);
    }

    return pickId(embedded ?? v) ?? '';
  }

  String _vendorSuggestionTitleOf(Map<String, dynamic> v) {
    final embedded = v['vendor'] ?? v['business'] ?? v['company'];
    if (embedded is Map) {
      return _vendorSuggestionTitleOf(Map<String, dynamic>.from(embedded));
    }
    final raw = v['businessName'] ??
        v['vendorName'] ??
        v['shopName'] ??
        v['storeName'] ??
        v['brandName'] ??
        v['companyName'] ??
        v['displayName'] ??
        v['display_name'] ??
        v['name'] ??
        v['username'] ??
        v['userName'];
    final title = raw == null ? '' : raw.toString().trim();
    if (title.isNotEmpty) return title;
    // Fallback to user-style parsing if vendor payload is basically a user object.
    final maybeUserTitle = _suggestionTitleOf(v).trim();
    return maybeUserTitle.isNotEmpty ? maybeUserTitle : 'business';
  }

  String? _vendorSuggestionSubtitleOf(Map<String, dynamic> v) {
    final embedded = v['vendor'] ?? v['business'] ?? v['company'];
    if (embedded is Map) {
      return _vendorSuggestionSubtitleOf(Map<String, dynamic>.from(embedded));
    }
    final raw = v['category'] ??
        v['tagline'] ??
        v['subtitle'] ??
        v['location'] ??
        v['city'];
    final s = raw == null ? '' : raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  String _vendorSuggestionAvatarOf(Map<String, dynamic> v) {
    final embedded = v['vendor'] ?? v['business'] ?? v['company'];
    if (embedded is Map) {
      return _vendorSuggestionAvatarOf(Map<String, dynamic>.from(embedded));
    }
    final raw = v['logo'] ??
        v['logoUrl'] ??
        v['logo_url'] ??
        v['avatar_url'] ??
        v['avatarUrl'] ??
        v['profile_picture'] ??
        v['profilePic'] ??
        v['profilePicture'] ??
        v['avatar'];
    return raw == null ? '' : raw.toString();
  }

  Future<void> _loadVendorSuggestions({bool force = false}) async {
    if (_vendorSuggestionsLoading) return;
    if (!force && _vendorSuggestions.isNotEmpty) return;
    setState(() => _vendorSuggestionsLoading = true);
    try {
      final list = await _suggestionsApi.getVendorSuggestions(limit: 80);
      final parsed = <SuggestionUser>[];
      for (final v in list) {
        final role = (v['role'] ??
                (v['vendor'] is Map ? (v['vendor'] as Map)['role'] : null))
            ?.toString()
            .toLowerCase()
            .trim();
        final isVendor = (v['isVendor'] == true) ||
            (v['is_vendor'] == true) ||
            (role == 'vendor');
        if (!isVendor && (role != null && role.isNotEmpty)) {
          continue;
        }
        final id = _vendorSuggestionIdOf(v).trim();
        if (id.isEmpty) continue;
        final avatar = _vendorSuggestionAvatarOf(v).trim();
        parsed.add(
          SuggestionUser(
            id: id,
            title: _vendorSuggestionTitleOf(v),
            subtitle: _vendorSuggestionSubtitleOf(v),
            avatarUrl: avatar.isEmpty ? null : UrlHelper.absoluteUrl(avatar),
          ),
        );
      }
      if (!mounted) return;
      setState(() => _vendorSuggestions = parsed);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _vendorSuggestionsLoading = false);
    }
  }

  void _dismissVendorSuggestion(String vendorId) {
    final id = vendorId.trim();
    if (id.isEmpty) return;
    setState(() => _dismissedVendorSuggestionIds.add(id));
  }

  Future<void> _followVendorSuggestion(SuggestionUser vendor) async {
    if (_suggestionFollowOpsInFlight.contains(vendor.id)) return;
    _suggestionFollowOpsInFlight.add(vendor.id);
    _dismissVendorSuggestion(vendor.id);
    try {
      await _followsApi.follow(vendor.id);
      unawaited(_supabase.syncFollowStatus(vendor.id, true));
    } catch (_) {
      if (!mounted) return;
      setState(() => _dismissedVendorSuggestionIds.remove(vendor.id));
    } finally {
      _suggestionFollowOpsInFlight.remove(vendor.id);
    }
  }

  Future<void> _loadAdSuggestions({bool force = false}) async {
    if (_adSuggestionsLoading) return;
    if (!force && _adSuggestions.isNotEmpty) return;
    setState(() => _adSuggestionsLoading = true);
    try {
      final raw = await _suggestionsApi.getAdSuggestions(limit: 10);
      final parsed = <FeedPost>[];
      for (final e in raw) {
        try {
          final p = FeedPost.fromJson(e);
          if (p.id.trim().isEmpty) continue;
          parsed.add(p);
        } catch (_) {
          // ignore
        }
      }
      if (!mounted) return;
      setState(() => _adSuggestions = parsed);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _adSuggestionsLoading = false);
    }
  }

  Reel? _parseSuggestedReel(Map<String, dynamic> item) {
    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    bool toBool(dynamic v) {
      final parsed = _parseBoolLike(v);
      return parsed ?? false;
    }

    bool looksLikeVideoUrl(String url) {
      final lower = url.toLowerCase();
      return lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.mkv') ||
          lower.endsWith('.webm') ||
          lower.contains('.m3u8') ||
          lower.contains('.mpd');
    }

    String? normalizeThumb(dynamic raw) {
      final thumb = str(raw);
      if (thumb == null || thumb.isEmpty) return null;
      final normalized = UrlHelper.normalizeUrl(thumb);
      if (normalized.isEmpty || looksLikeVideoUrl(normalized)) return null;
      return UrlHelper.absoluteUrl(normalized);
    }

    String? bestThumbnailFromMediaMap(Map<String, dynamic> m) {
      final thumbs = m['thumbnails'];
      if (thumbs is List && thumbs.isNotEmpty) {
        for (final t in thumbs) {
          if (t is! Map) continue;
          final tm = Map<String, dynamic>.from(t);
          final candidate = normalizeThumb(
            tm['fileUrl'] ?? tm['file_url'] ?? tm['url'] ?? tm['path'],
          );
          if (candidate != null) return candidate;
        }
      }
      final direct = normalizeThumb(
        m['thumbnail_url'] ??
            m['thumbnailUrl'] ??
            m['thumbnail'] ??
            m['thumb'] ??
            m['image_url'] ??
            m['image'],
      );
      if (direct != null) return direct;
      return null;
    }

    final id = str(item['_id']) ?? str(item['id']) ?? str(item['post_id']);
    if (id == null || id.isEmpty) return null;

    final userField =
        item['user_id'] ?? item['userId'] ?? item['user'] ?? item['author'];
    final user = userField is Map
        ? Map<String, dynamic>.from(userField)
        : item['users'] is Map
            ? Map<String, dynamic>.from(item['users'])
            : <String, dynamic>{};

    final userId = str(user['_id']) ??
        str(user['id']) ??
        str(item['userId']) ??
        str(item['user_id']) ??
        ((userField is String || userField is num) ? str(userField) : null) ??
        '';
    final userName = str(user['username']) ?? str(user['full_name']) ?? 'reel';
    final userAvatar = UrlHelper.normalizeUrl(str(user['avatar_url']));

    final mediaList =
        item['media'] is List ? (item['media'] as List) : const [];
    String? videoUrl;
    String? thumbnailUrl;
    String? aspectRatio;
    if (mediaList.isNotEmpty) {
      final first = mediaList.first;
      if (first is String) {
        videoUrl = str(first);
      } else if (first is Map) {
        final media = Map<String, dynamic>.from(first);
        videoUrl = str(media['fileUrl']) ??
            str(media['url']) ??
            str(media['videoUrl']) ??
            str(media['file_url']);
        thumbnailUrl ??= bestThumbnailFromMediaMap(media);

        final crop = media['crop'] is Map
            ? Map<String, dynamic>.from(media['crop'])
            : const <String, dynamic>{};
        aspectRatio = str(crop['aspect_ratio']) ?? str(media['aspect_ratio']);
      }
    }

    thumbnailUrl ??= normalizeThumb(
          item['thumbnail_url'] ?? item['thumbnailUrl'] ?? item['thumbnail'],
        ) ??
        normalizeThumb(item['thumb']) ??
        normalizeThumb(item['image_url']) ??
        normalizeThumb(item['image']);

    if (thumbnailUrl == null) {
      final directThumbs = item['thumbnails'];
      if (directThumbs is List && directThumbs.isNotEmpty) {
        for (final t in directThumbs) {
          if (t is! Map) continue;
          final tm = Map<String, dynamic>.from(t);
          final candidate = normalizeThumb(
            tm['fileUrl'] ?? tm['file_url'] ?? tm['url'] ?? tm['path'],
          );
          if (candidate != null) {
            thumbnailUrl = candidate;
            break;
          }
        }
      }
    }

    final reelCrop = item['crop'] is Map
        ? Map<String, dynamic>.from(item['crop'])
        : const <String, dynamic>{};
    aspectRatio = aspectRatio ??
        str(reelCrop['aspect_ratio']) ??
        str(item['aspect_ratio']);

    final caption = str(item['caption']);
    final createdAtRaw = str(item['created_at']) ?? str(item['createdAt']);
    final createdAt = DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.now();

    final normalizedVideo = UrlHelper.normalizeUrl(videoUrl ?? '');
    if (normalizedVideo.isEmpty) return null;

    final normalizedThumb = UrlHelper.normalizeUrl(thumbnailUrl);
    final normalizedAvatar = UrlHelper.normalizeUrl(userAvatar);

    return Reel(
      id: id,
      userId: userId,
      userName: userName,
      userAvatarUrl: normalizedAvatar.isEmpty
          ? null
          : UrlHelper.absoluteUrl(normalizedAvatar),
      videoUrl: UrlHelper.absoluteUrl(normalizedVideo),
      thumbnailUrl: normalizedThumb.isEmpty
          ? null
          : UrlHelper.absoluteUrl(normalizedThumb),
      aspectRatio: aspectRatio,
      caption: caption,
      hashtags: const <String>[],
      likes: toInt(item['likes_count'] ?? item['likesCount']),
      comments: toInt(item['comments_count'] ?? item['commentsCount']),
      shares: toInt(item['shares_count'] ?? item['sharesCount']),
      views: toInt(item['views_count'] ?? item['viewsCount']),
      isLiked: toBool(item['is_liked_by_me'] ?? item['isLiked']),
      isSaved: toBool(item['is_saved_by_me'] ?? item['isSaved']),
      isFollowing: toBool(item['is_followed_by_me'] ?? item['isFollowing']),
      createdAt: createdAt,
      isSponsored: toBool(item['is_ad'] ?? item['isAd']),
      sponsorBrand: str(item['ad_company_name']),
      sponsorLogoUrl: null,
      productTags: null,
      remixEnabled: true,
      audioReuseEnabled: true,
      originalReelId: null,
      originalCreatorId: null,
      originalCreatorName: null,
      isRisingCreator: false,
      isTrending: false,
      duration: const Duration(seconds: 30),
    );
  }

  Future<void> _loadReelSuggestions({bool force = false}) async {
    if (_reelSuggestionsLoading) return;
    if (!force && _suggestedReels.isNotEmpty) return;
    setState(() => _reelSuggestionsLoading = true);
    try {
      final token = await ApiClient().getToken();
      if (token != null &&
          token.isNotEmpty &&
          _suggestionImageHeaders.isEmpty &&
          mounted) {
        setState(() {
          _suggestionImageHeaders = <String, String>{
            'Authorization': 'Bearer $token'
          };
        });
      }

      final raw = await _suggestionsApi.getReelSuggestions(limit: 10);
      final parsed = raw
          .map((e) => _parseSuggestedReel(e))
          .whereType<Reel>()
          .where((r) => r.id.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _suggestedReels = parsed;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _reelSuggestionsLoading = false);
    }
  }

  List<SuggestionUser> _suggestionsForBlock(int blockIndex, {int count = 10}) {
    final all = _followSuggestions
        .where((u) => !_dismissedSuggestionUserIds.contains(u.id))
        .toList();
    if (all.isEmpty) return const <SuggestionUser>[];
    final start = (blockIndex * count) % all.length;
    final out = <SuggestionUser>[];
    for (var i = 0; i < count && i < all.length; i++) {
      out.add(all[(start + i) % all.length]);
    }
    return out;
  }

  List<SuggestionUser> _vendorsForBlock(int blockIndex, {int count = 10}) {
    final all = _vendorSuggestions
        .where((u) => !_dismissedVendorSuggestionIds.contains(u.id))
        .toList();
    if (all.isEmpty) return const <SuggestionUser>[];
    final start = (blockIndex * count) % all.length;
    final out = <SuggestionUser>[];
    for (var i = 0; i < count && i < all.length; i++) {
      out.add(all[(start + i) % all.length]);
    }
    return out;
  }

  void _dismissSuggestionUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    setState(() => _dismissedSuggestionUserIds.add(id));
  }

  Future<void> _followSuggestionUser(SuggestionUser user) async {
    if (_suggestionFollowOpsInFlight.contains(user.id)) return;
    _suggestionFollowOpsInFlight.add(user.id);
    _dismissSuggestionUser(user.id);
    try {
      await _followsApi.follow(user.id);
      unawaited(_supabase.syncFollowStatus(user.id, true));
    } catch (_) {
      if (!mounted) return;
      setState(() => _dismissedSuggestionUserIds.remove(user.id));
    } finally {
      _suggestionFollowOpsInFlight.remove(user.id);
    }
  }

  Future<void> _openSuggestionsSeeAll() async {
    if (!mounted) return;
    final uid = _currentUserId ?? '';
    if (uid.isEmpty) return;
    final username = (_currentUserProfile?['username'] ??
            _currentUserProfile?['userName'] ??
            _currentUserProfile?['full_name'] ??
            _currentUserProfile?['fullName'] ??
            'You')
        .toString();
    await FollowListScreen.open(
      context,
      userId: uid,
      username: username,
      mode: FollowListMode.vendors,
      isOwnProfile: true,
    );
  }

  List<_FeedRenderRow> _buildFeedRows(List<FeedPost> posts) {
    final rows = <_FeedRenderRow>[];
    var postCount = 0;
    var peopleBlockIndex = 0;
    var vendorBlockIndex = 0;
    var insertCycleIndex = 0;

    FeedPost? nextAdForBlock(int idx) {
      final list = _adSuggestions;
      if (list.isEmpty) return null;
      return list[idx % list.length];
    }

    for (final p in posts) {
      rows.add(_FeedRenderRow.post(p));
      postCount++;
      if (postCount % 5 != 0) continue;

      // After every 5 posts, insert ONE block in a repeating cycle:
      // Reels → Ads → People → Vendors → (repeat)
      final cycle = insertCycleIndex % 4;
      insertCycleIndex++;

      switch (cycle) {
        case 0:
          if (_reelSuggestionsLoading || _suggestedReels.isNotEmpty) {
            rows.add(_FeedRenderRow.reelsSuggestions());
          }
          break;
        case 1:
          final ad = nextAdForBlock(postCount ~/ 5);
          if (_adSuggestionsLoading || _adSuggestions.isNotEmpty) {
            rows.add(_FeedRenderRow.adsSuggestion(ad));
          }
          break;
        case 2:
          final hasPeople = _followSuggestions.any(
            (u) => !_dismissedSuggestionUserIds.contains(u.id),
          );
          if (_followSuggestionsLoading || hasPeople) {
            rows.add(_FeedRenderRow.peopleSuggestions(peopleBlockIndex));
            peopleBlockIndex++;
          }
          break;
        case 3:
        default:
          final hasVendors = _vendorSuggestions.any(
            (u) => !_dismissedVendorSuggestionIds.contains(u.id),
          );
          if (_vendorSuggestionsLoading || hasVendors) {
            rows.add(_FeedRenderRow.vendorSuggestions(vendorBlockIndex));
            vendorBlockIndex++;
          }
          break;
      }
    }
    return rows;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    if (!_isRouteActive) return;
    _isRouteActive = false;
    _activeFeedPostId = null;
    _activeFeedPostIdListenable.value = null;
    unawaited(_persistFeedScrollPosition());
    unawaited(MediaPlaybackRegistry.instance.pauseAll());
    if (mounted) setState(() {});
  }

  @override
  void didPopNext() {
    if (_isRouteActive) return;
    _isRouteActive = true;
    unawaited(_refreshUnreadNotificationCount());
    unawaited(_restoreFeedScrollPosition());
    if (_pendingHomeRefreshAfterRoute && _currentIndex == 0) {
      _pendingHomeRefreshAfterRoute = false;
      _scheduleHomeRefresh();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 500);
    HomeOnboardingService.instance.clearCallbacks();
    MediaPlaybackRegistry.instance.unregister('home-dashboard');
    unawaited(_persistFeedScrollPosition());
    _notificationSub?.cancel();
    _notificationRefreshTimer?.cancel();
    _activeFeedDebounce?.cancel();
    _autoRefreshDebounce?.cancel();
    _feedScrollSaveDebounce?.cancel();
    _activeFeedPostIdListenable.dispose();
    _detachFeedScrollActivityListener();
    _feedScrollController.removeListener(_onFeedScroll);
    _feedScrollController.dispose();
    _tabPageController?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
      _subscribedRoute = null;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_persistFeedScrollPosition());
      unawaited(MediaPlaybackRegistry.instance.pauseAll());
      return;
    }
    if (!mounted) return;
    if (_currentIndex != 0) return;
    unawaited(_refreshUnreadNotificationCount());
    final store = StoreProvider.of<AppState>(context);
    _beginFeedSkeletonLoading();
    unawaited(
        Future.wait([_loadData(store), _loadInitialFeed(forceNetwork: true)]));
    unawaited(_restoreFeedScrollPosition());
  }

  void _scheduleHomeRefresh() {
    _autoRefreshDebounce?.cancel();
    _autoRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (_currentIndex != 0) return;
      final last = _lastAutoRefreshAt;
      final now = DateTime.now();
      // 30 second cooldown — prevents feed reset on every back navigation
      if (last != null && now.difference(last) < const Duration(seconds: 30)) {
        return;
      }
      _lastAutoRefreshAt = now;
      final store = StoreProvider.of<AppState>(context);
      _beginFeedSkeletonLoading();
      unawaited(Future.wait(
          [_loadData(store), _loadInitialFeed(forceNetwork: true)]));
    });
  }

  String? _notificationBadgeText(int unreadCount) {
    if (unreadCount <= 0) return null;
    if (unreadCount >= 9) return '9+';
    return unreadCount.toString();
  }

  Future<void> _loadData(Store<AppState> store) async {
    // Wrap the whole load sequence so we always clear loading and apply whatever data we could fetch.
    int bal = 0;
    List<StoryGroup> groups = const <StoryGroup>[];
    Map<String, dynamic>? meRaw;
    Map<String, dynamic>? currentProfileRaw;
    String? currentUserId;
    Map<String, dynamic> mergedProfile = {};

    try {
      // Use REST API-backed CurrentUser helper for the authenticated user ID.
      currentUserId = await CurrentUser.id;
      try {
        meRaw = await AuthApi().me();
      } catch (_) {
        meRaw = null;
      }
      final meProfile = _normalizeProfile(meRaw);
      try {
        currentProfileRaw = currentUserId != null
            ? await _supabase.getUserById(currentUserId)
            : null;
      } catch (_) {
        currentProfileRaw = null;
      }
      final currentProfile = _normalizeProfile(currentProfileRaw);
      mergedProfile = <String, dynamic>{
        ...?currentProfile,
        ...?meProfile,
      };
      final effectiveUserId = currentUserId ??
          (mergedProfile['id']?.toString()) ??
          (mergedProfile['_id']?.toString());

      try {
        bal = await _walletService.getCoinBalance();
      } catch (_) {
        bal = 0;
      }

      if (!_reelsPrefetched) {
        _reelsPrefetched = true;
        unawaited(() async {
          try {
            await _reelsService.fetchReels(limit: 20, offset: 0);
          } catch (_) {}
        }());
      }

      // Stories feed from backend
      try {
        groups = await _feedService.fetchStoriesFeed();
      } catch (_) {
        groups = const <StoryGroup>[];
      }

      final allGroups = List<StoryGroup>.from(groups);
      final myGroups = effectiveUserId != null
          ? allGroups.where((g) => g.userId == effectiveUserId).toList()
          : <StoryGroup>[];
      final otherGroups = effectiveUserId != null
          ? allGroups.where((g) => g.userId != effectiveUserId).toList()
          : allGroups;

      final baseStatuses = _computeStoryStatuses(otherGroups);
      final previousStatuses =
          Map<String, Map<String, bool>>.from(_storyStatuses);
      final mergedStatuses = <String, Map<String, bool>>{};
      for (final g in otherGroups) {
        final uid = g.userId;
        final current = baseStatuses[uid] ?? {};
        final prev = previousStatuses[uid];
        if (prev != null && prev['allViewed'] == true) {
          mergedStatuses[uid] = {
            ...current,
            'hasUnseen': false,
            'allViewed': true,
          };
        } else {
          mergedStatuses[uid] = current;
        }
      }

      otherGroups.sort((a, b) {
        final sa = mergedStatuses[a.userId] ?? const {};
        final sb = mergedStatuses[b.userId] ?? const {};
        final aHasUnseen = sa['hasUnseen'] == true;
        final bHasUnseen = sb['hasUnseen'] == true;
        if (aHasUnseen != bHasUnseen) {
          return aHasUnseen ? -1 : 1;
        }
        final ad = a.stories.isNotEmpty
            ? a.stories.first.createdAt
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.stories.isNotEmpty
            ? b.stories.first.createdAt
            : DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      final users = otherGroups.map((g) {
        return {
          'id': g.userId,
          'username': g.userName,
          'avatar_url': g.userAvatar,
        };
      }).toList();
      final my = effectiveUserId != null
          ? myGroups.expand((g) => g.stories).toList()
          : _buildMyStories(mergedProfile.isEmpty ? null : mergedProfile);

      // Apply to store and local state
      if (mounted) {
        setState(() {
          _currentUserProfile = mergedProfile.isEmpty ? null : mergedProfile;
          _currentUserId = effectiveUserId;
          _storyUsers = users;
          _storyGroups = otherGroups;
          _storyStatuses = mergedStatuses;
          _myStories = my;
          _myStoryId = myGroups.isNotEmpty ? myGroups.first.storyId : null;
          _yourStoryHasActive = _myStories.isNotEmpty;
          _balance = bal;
        });
        // Preload profile into Redux so ProfileScreen opens instantly
        if (effectiveUserId != null && mergedProfile.isNotEmpty) {
          store.dispatch(SetProfile(mergedProfile));
        }
      }
    } finally {}
  }

  Future<void> _loadInitialFeed({bool forceNetwork = false}) async {
    try {
      await primeMediaAuthHeaders(); // ensure auth headers ready before any image loads
      unawaited(_loadReelSuggestions(force: forceNetwork));
      final store = StoreProvider.of<AppState>(context);
      final isFirstLoad = store.state.feedState.posts.isEmpty || forceNetwork;
      if (isFirstLoad) {
        _prewarmedFeedIds.clear();
        _prewarmedFeedAvatarUrls.clear();
      }

      // Only show full-screen spinner on genuine first load
      if (isFirstLoad) {
        store.dispatch(SetFeedLoading(true));
        if (forceNetwork) {
          store.dispatch(SetFeedPosts(const []));
        }
      }

      final currentUserId = await CurrentUser.id;
      List<FeedPost> items = const <FeedPost>[];
      try {
        items = await _feedService.fetchFeedFromBackend(
          currentUserId: currentUserId,
          useBackendDefault: false,
          limit: _pageSize,
          cacheBuster: DateTime.now().millisecondsSinceEpoch.toString(),
        );
      } catch (_) {
        items = const <FeedPost>[];
      }
      // If backend returns too few posts, eagerly fetch next pages to fill the screen.
      var nextPageCursor = 2;
      var prefetchNoMore = false;
      if (items.isNotEmpty && items.length < _pageSize) {
        final seen = items.map((p) => p.id).toSet();
        var keepGoing = true;
        while (keepGoing && items.length < _pageSize) {
          List<FeedPost> pageItems = const <FeedPost>[];
          try {
            pageItems = await _feedService.fetchFeedFromBackend(
              limit: _pageSize,
              offset: (nextPageCursor - 1) * _pageSize,
              currentUserId: currentUserId,
              useBackendDefault: false,
              cacheBuster: DateTime.now().millisecondsSinceEpoch.toString(),
            );
          } catch (_) {
            pageItems = const <FeedPost>[];
          }
          if (pageItems.isEmpty) {
            keepGoing = false;
            prefetchNoMore = true;
            break;
          }
          final newOnes = pageItems.where((p) => !seen.contains(p.id)).toList();
          if (newOnes.isEmpty) {
            keepGoing = false;
            prefetchNoMore = true;
            break;
          }
          for (final p in newOnes) {
            seen.add(p.id);
          }
          items = [...items, ...newOnes];
          nextPageCursor += 1;
          // Safety: avoid unbounded prefetching on bad pagination.
          if (nextPageCursor > 4) {
            keepGoing = false;
          }
        }
      }
      if (!mounted) {
        if (isFirstLoad) store.dispatch(SetFeedLoading(false));
        return;
      }

      if (items.isNotEmpty) {
        await _precacheFeedMedia(items);
        if (!mounted) {
          if (isFirstLoad) store.dispatch(SetFeedLoading(false));
          return;
        }
      }

      store.dispatch(SetFeedPosts(items));

      setState(() {
        if (isFirstLoad || forceNetwork) {
          // First load only: start from top, reset everything
          _activeFeedPostId = items.isNotEmpty ? items.first.id : null;
          _activeFeedPostIdListenable.value = _activeFeedPostId;
          // Show ALL items from backend on first load, not just _pageSize
          _visibleCount = items.length;
        } else {
          // Background refresh: preserve current scroll depth
          // Just expand _visibleCount if new items arrived beyond current depth
          _visibleCount = math.max(
            _visibleCount,
            items.length,
          );
          // Do NOT reset _activeFeedPostId — user is mid-scroll
        }
        _pageCursor = nextPageCursor;
        _pagingInFlight = false;
        _noMorePages = items.isEmpty || prefetchNoMore;
      });

      if (isFirstLoad) store.dispatch(SetFeedLoading(false));

      // If list is too short to scroll, proactively load next page
      if (items.isNotEmpty) {
        _checkIfListNeedsMorePosts();
        // Ensure we have a full initial batch without requiring a scroll.
        unawaited(_prefetchUntil(minPosts: _pageSize, maxPages: 3));
      }
    } finally {
      _endFeedSkeletonLoading();
    }
  }

  Future<void> _precacheFeedMedia(List<FeedPost> posts) async {
    if (_shouldAvoidBackgroundMediaFetch()) return;
    final token = await ApiClient().getToken();
    final authHeaders = <String, String>{};
    if (token != null && token.isNotEmpty) {
      authHeaders['Authorization'] = 'Bearer $token';
    }
    final context = this.context;
    final futures = <Future<void>>[];
    final limit = posts.length < 6 ? posts.length : 6;
    // Ensure the first reel/video thumbnail is cached before rendering feed.
    FeedPost? firstVideoPost;
    for (var i = 0; i < limit; i++) {
      final post = posts[i];
      if (post.mediaType == PostMediaType.video ||
          post.mediaType == PostMediaType.reel) {
        firstVideoPost = post;
        break;
      }
    }
    if (firstVideoPost != null &&
        (firstVideoPost.thumbnailUrl ?? '').isNotEmpty) {
      final url = firstVideoPost.thumbnailUrl!;
      final Map<String, String> headers = UrlHelper.shouldAttachAuthHeader(url)
          ? authHeaders
          : const <String, String>{};
      try {
        await precacheImage(
          CachedNetworkImageProvider(url, headers: headers),
          context,
        ).timeout(const Duration(seconds: 2));
      } catch (_) {
        // Best-effort only.
      }
    }
    for (var i = 0; i < limit; i++) {
      final post = posts[i];
      unawaited(_precacheFeedAvatar(post));
      String? url;
      if (post.mediaType == PostMediaType.video ||
          post.mediaType == PostMediaType.reel) {
        url = post.thumbnailUrl;
        if ((url == null || url.isEmpty) && post.mediaUrls.isNotEmpty) {
          // Backend should provide thumbnailUrl for reels/videos.
        }
      } else if (post.mediaUrls.isNotEmpty) {
        url = post.mediaUrls.first;
      }
      if (url == null || url.isEmpty) continue;
      final Map<String, String> headers = UrlHelper.shouldAttachAuthHeader(url)
          ? authHeaders
          : const <String, String>{};
      futures.add(
        precacheImage(
          CachedNetworkImageProvider(url, headers: headers),
          context,
        ),
      );
    }
    try {
      await Future.wait(futures).timeout(const Duration(milliseconds: 1500));
    } catch (_) {
      // Best-effort prefetch only.
    }
  }

  Future<void> _precacheFeedAvatar(FeedPost post) async {
    if (_shouldAvoidBackgroundMediaFetch()) return;
    final rawUrl = post.userAvatar?.trim() ?? '';
    if (rawUrl.isEmpty) return;
    final url = UrlHelper.absoluteUrl(rawUrl);
    if (url.isEmpty || _prewarmedFeedAvatarUrls.contains(url)) return;
    _prewarmedFeedAvatarUrls.add(url);
    final token = await ApiClient().getToken();
    final authHeaders = <String, String>{};
    if (token != null && token.isNotEmpty) {
      authHeaders['Authorization'] = 'Bearer $token';
    }
    final headers = UrlHelper.shouldAttachAuthHeader(url)
        ? authHeaders
        : const <String, String>{};
    try {
      await precacheImage(
        CachedNetworkImageProvider(url, headers: headers),
        context,
      ).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Best-effort only.
    }
  }

  void _scheduleFeedScrollSave() {
    if (!_feedScrollController.hasClients) return;
    final pixels = _feedScrollController.position.pixels;
    _feedScrollSaveDebounce?.cancel();
    _feedScrollSaveDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(UiSurfaceMemoryService.instance.saveFeedScrollOffset(pixels));
    });
  }

  void _beginFeedSkeletonLoading() {
    _feedSkeletonLoadCount += 1;
    if (mounted) setState(() {});
  }

  void _endFeedSkeletonLoading() {
    if (_feedSkeletonLoadCount > 0) {
      _feedSkeletonLoadCount -= 1;
    }
    if (mounted) setState(() {});
  }

  Future<void> _persistFeedScrollPosition() async {
    if (!_feedScrollController.hasClients) return;
    await UiSurfaceMemoryService.instance
        .saveFeedScrollOffset(_feedScrollController.position.pixels);
  }

  Future<void> _restoreFeedScrollPosition({int attempts = 12}) async {
    if (!mounted || _currentIndex != 0) return;
    if (!_feedScrollController.hasClients) {
      if (attempts <= 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_restoreFeedScrollPosition(attempts: attempts - 1));
      });
      return;
    }

    final position = _feedScrollController.position;
    if (position.pixels > 1.0) return;

    final savedOffset =
        await UiSurfaceMemoryService.instance.loadFeedScrollOffset();
    if (savedOffset == null || savedOffset <= 0) return;
    if (!mounted || _currentIndex != 0 || !_feedScrollController.hasClients) {
      return;
    }

    final maxScrollExtent = _feedScrollController.position.maxScrollExtent;
    if (maxScrollExtent <= 0) {
      if (attempts <= 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_restoreFeedScrollPosition(attempts: attempts - 1));
      });
      return;
    }

    final target = savedOffset.clamp(0.0, maxScrollExtent).toDouble();
    if ((position.pixels - target).abs() < 1.0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_feedScrollController.hasClients) return;
      final position = _feedScrollController.position;
      final clampedTarget =
          target.clamp(0.0, position.maxScrollExtent).toDouble();
      if (position.pixels <= 1.0 &&
          (position.pixels - clampedTarget).abs() >= 1.0) {
        _feedScrollController.jumpTo(clampedTarget);
      }
    });
  }

  Future<void> _prefetchUntil({
    required int minPosts,
    int maxPages = 3,
  }) async {
    if (!mounted || _pagingInFlight || _noMorePages) return;
    final store = StoreProvider.of<AppState>(context);
    var remainingPages = maxPages;
    while (mounted &&
        remainingPages > 0 &&
        !_noMorePages &&
        store.state.feedState.posts.length < minPosts) {
      await _fetchNextPage();
      remainingPages -= 1;
    }
  }

  void _checkIfListNeedsMorePosts() {
    _waitForScrollAndFetch(attempts: 20);
  }

  void _waitForScrollAndFetch({required int attempts}) {
    if (attempts <= 0) {
      // Last resort: just fetch regardless
      if (mounted && !_pagingInFlight && !_noMorePages) {
        _fetchNextPage();
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ScrollController not attached yet — try next frame
      if (!_feedScrollController.hasClients) {
        _waitForScrollAndFetch(attempts: attempts - 1);
        return;
      }
      final position = _feedScrollController.position;
      // If content doesn't fill the screen, load more immediately
      if (position.maxScrollExtent < 400) {
        _fetchNextPage();
      }
    });
  }

  void _onFeedScroll() {
    if (!_feedScrollController.hasClients) return;
    _attachFeedScrollActivityListener();
    _scheduleFeedScrollSave();
    final store = StoreProvider.of<AppState>(context);
    final total = store.state.feedState.posts.length;
    final position = _feedScrollController.position;

    // Trigger if within 400px of bottom OR if list is short enough
    // that maxScrollExtent itself is under 400px
    final nearBottom = position.pixels >= position.maxScrollExtent - 400;
    final listIsShort = position.maxScrollExtent < 400 &&
        position.pixels >= position.maxScrollExtent - 50;

    if (nearBottom || listIsShort) {
      final newVisible = math.min(total, _visibleCount + _pageSize);
      if (newVisible != _visibleCount) {
        setState(() => _visibleCount = newVisible);
      }
      _maybeFetchNextPage(total);
    }
  }

  void _attachFeedScrollActivityListener() {
    if (!_feedScrollController.hasClients) return;
    final position = _feedScrollController.position;
    if (identical(_trackedFeedScrollPosition, position)) return;
    _trackedFeedScrollPosition?.isScrollingNotifier
        .removeListener(_onFeedScrollActivityChanged);
    _trackedFeedScrollPosition = position;
    position.isScrollingNotifier.addListener(_onFeedScrollActivityChanged);
  }

  void _detachFeedScrollActivityListener() {
    _trackedFeedScrollPosition?.isScrollingNotifier
        .removeListener(_onFeedScrollActivityChanged);
    _trackedFeedScrollPosition = null;
  }

  void _onFeedScrollActivityChanged() {
    final position = _trackedFeedScrollPosition;
    if (position == null) return;
    final scrolling = position.isScrollingNotifier.value;
    if (scrolling) {
      _isFeedScrolling = true;
      return;
    }

    _isFeedScrolling = false;
    final pending = _pendingActivePostId;
    if (pending != null && pending != _activeFeedPostId) {
      _activeFeedPostId = pending;
      _activeFeedPostIdListenable.value = pending;
    }
    _pendingActivePostId = null;
  }

  void _maybeFetchNextPage(int totalCount) {
    if (_pagingInFlight || _noMorePages) return;
    // If we are within one chunk of the end, try to fetch the next page
    final remaining = totalCount - _visibleCount;
    if (remaining > _pageSize ~/ 2) return;
    _fetchNextPage();
  }

  Future<void> _fetchNextPage() async {
    if (_pagingInFlight || _noMorePages) return;
    _pagingInFlight = true;
    final store = StoreProvider.of<AppState>(context);
    final currentUserId = await CurrentUser.id;
    final existingIds = store.state.feedState.posts.map((p) => p.id).toSet();
    List<FeedPost> pageItems = const <FeedPost>[];
    try {
      // Use classic pagination for deeper pages
      pageItems = await _feedService.fetchFeedFromBackend(
        limit: _pageSize,
        offset: (_pageCursor - 1) * _pageSize,
        currentUserId: currentUserId,
        useBackendDefault: false,
        cacheBuster: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } catch (_) {
      pageItems = const <FeedPost>[];
    }
    if (!mounted) {
      _pagingInFlight = false;
      return;
    }
    final newOnes =
        pageItems.where((p) => !existingIds.contains(p.id)).toList();
    if (newOnes.isEmpty) {
      _noMorePages = true;
      _pagingInFlight = false;
      return;
    }
    store.dispatch(AppendFeedPosts(newOnes));
    setState(() {
      _pageCursor += 1;
      final totalNow = store.state.feedState.posts.length;
      _visibleCount = math.min(totalNow, _visibleCount + _pageSize);
    });
    _pagingInFlight = false;

    // If screen still not filled after appending, keep fetching
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_feedScrollController.hasClients &&
          _feedScrollController.position.maxScrollExtent < 400 &&
          !_noMorePages) {
        _fetchNextPage();
      }
    });
  }

  void _onFeedItemVisibilityChanged(String postId, double visibleFraction) {
    if (_currentIndex != 0) return;
    final store = StoreProvider.of<AppState>(context);
    final allPosts = store.state.feedState.posts;
    final post = allPosts.cast<FeedPost?>().firstWhere(
          (p) => p?.id == postId,
          orElse: () => null,
        );
    if (visibleFraction >= 0.15) {
      _preWarmVisibleVideo(postId);
      if (post != null) {
        unawaited(_precacheFeedAvatar(post));
      }
    }
    // Only consider activating a post when at least half of it is visible.
    // This matches typical "Instagram-like" behavior and prevents audio/video
    // flipping while the user is mid-scroll.
    if (visibleFraction < 0.50) return;
    if (_activeFeedPostId == postId) return;
    if (_isFeedScrolling) {
      if (post != null) {
        final isVideo = post.mediaType == PostMediaType.video ||
            post.mediaType == PostMediaType.reel;
        final hasThumb = (post.thumbnailUrl ?? '').toString().trim().isNotEmpty;
        if (isVideo && !hasThumb && visibleFraction >= 0.35) {
          _activeFeedPostId = postId;
          _activeFeedPostIdListenable.value = postId;
          return;
        }
      }
      _pendingActivePostId = postId;
      return;
    }
    _activeFeedDebounce?.cancel();
    _activeFeedDebounce = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      if (_currentIndex != 0) return;
      if (_activeFeedPostId == postId) return;
      _activeFeedPostId = postId;
      _activeFeedPostIdListenable.value = postId;
      _preWarmNextVideo(postId);
    });
  }

  void _preWarmVisibleVideo(String postId) {
    if (_shouldAvoidBackgroundMediaFetch()) return;
    if (_prewarmedFeedIds.contains(postId)) return;
    final store = StoreProvider.of<AppState>(context);
    final allPosts = store.state.feedState.posts;
    final post = allPosts.cast<FeedPost?>().firstWhere(
          (p) => p?.id == postId,
          orElse: () => null,
        );
    if (post == null) return;
    final isVideo = post.mediaType == PostMediaType.video ||
        post.mediaType == PostMediaType.reel;
    if (!isVideo || post.mediaUrls.isEmpty) return;
    _prewarmedFeedIds.add(postId);
    VideoPool.instance.preWarm(post.id, post.mediaUrls.first);
  }

  void _preWarmNextVideo(String activePostId) {
    if (_shouldAvoidBackgroundMediaFetch()) return;
    final store = StoreProvider.of<AppState>(context);
    final allPosts = store.state.feedState.posts;
    final activeIdx = allPosts.indexWhere((p) => p.id == activePostId);
    if (activeIdx < 0) return;
    // Look ahead up to 3 posts for the next video
    for (var i = activeIdx + 1;
        i < math.min(activeIdx + 4, allPosts.length);
        i++) {
      final next = allPosts[i];
      if (next.mediaType == PostMediaType.video ||
          next.mediaType == PostMediaType.reel) {
        if (next.mediaUrls.isNotEmpty) {
          VideoPool.instance.preWarm(next.id, next.mediaUrls.first);
        }
        break;
      }
    }
  }

  bool _shouldAvoidBackgroundMediaFetch() {
    if (!mounted) return true;
    final storagePrefs = StoragePreferencesScope.of(context);
    final network = NetworkStatusScope.of(context);
    if (network.isOffline) return true;
    if (storagePrefs.wifiOnlyDownloads) return !network.isOnWifi;
    return storagePrefs.mobileDataSaver && network.isOnMobileData;
  }

  Future<void> _openLocationSearch() async {
    final selected = await Navigator.of(context).push<LocationPlace>(
      MaterialPageRoute(builder: (_) => const LocationSearchScreen()),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _currentLocation = selected.fullText.isNotEmpty
          ? selected.fullText
          : (selected.displayText.isNotEmpty ? selected.displayText : null);
      _locationLoading = false;
    });
    unawaited(_saveSelectedLocation(selected));
  }

  // Like toggle - same as React PostCard: update post.likes array on posts table
  void _onLikePost(FeedPost post) async {
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like moments')),
        );
      }
      return;
    }
    final desired = !post.isLiked;
    final optimisticLikes =
        desired ? post.likes + 1 : (post.likes > 0 ? post.likes - 1 : 0);
    final store = StoreProvider.of<AppState>(context);
    store.dispatch(UpdatePostLiked(post.id, desired));
    if (mounted) {
      setState(() {}); // trigger rebuild to reflect optimistic change
    }
    final liked = await _supabase.setPostLike(post.id,
        like: desired, isTweet: post.isTweet);
    if (!mounted) return;
    try {
      final p =
          await SupabaseService().getPostById(post.id, isTweet: post.isTweet);
      final serverLiked = _extractLikedFlag(p) ?? liked;
      final likesCount = _extractLikesCount(p) ?? optimisticLikes;
      store
          .dispatch(UpdatePostLikedWithCount(post.id, serverLiked, likesCount));
      if (mounted) setState(() {}); // reflect reconciled count/color
    } catch (_) {
      store.dispatch(UpdatePostLikedWithCount(post.id, liked, optimisticLikes));
      if (mounted) setState(() {}); // reflect reconciled state
    }
  }

  void _onDoubleTapLikePost(FeedPost post) {
    if (!post.isLiked) {
      _onLikePost(post);
    }
  }

  void _onCommentPost(FeedPost post) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final treatAsAd = post.isAd || (post.adTitle?.trim().isNotEmpty ?? false);
    if (treatAsAd) {
      final adId = _extractAdId(post.id);
      if (adId.isEmpty) return;
      if (isMobile) {
        setState(() => _isCommentsOpen = true);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          builder: (_) => SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: AdCommentsSheet(adId: adId),
          ),
        ).whenComplete(() {
          if (mounted) setState(() => _isCommentsOpen = false);
        });
      } else {
        setState(() => _isCommentsOpen = true);
        showGeneralDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Comments',
          barrierColor: Colors.black54,
          transitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (context, _, __) {
            return SafeArea(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 360,
                  height: MediaQuery.of(context).size.height * 0.78,
                  margin: const EdgeInsets.only(right: 18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.08),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AdCommentsSheet(adId: adId),
                ),
              ),
            );
          },
        ).whenComplete(() {
          if (mounted) setState(() => _isCommentsOpen = false);
        });
      }
      return;
    }
    if (isMobile) {
      setState(() => _isCommentsOpen = true);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.9,
          child: CommentsSheet(postId: post.id, isTweet: post.isTweet),
        ),
      ).whenComplete(() {
        if (mounted) setState(() => _isCommentsOpen = false);
      });
    } else {
      setState(() => _isCommentsOpen = true);
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) =>
              PostDetailModal(postId: post.id, isTweet: post.isTweet),
        ),
      )
          .whenComplete(() {
        if (mounted) setState(() => _isCommentsOpen = false);
      });
    }
  }

  void _onSharePost(FeedPost post) {
    final type = post.isTweet
        ? 'tweet'
        : post.isAd
            ? 'ad'
            : (post.mediaType == PostMediaType.reel ? 'reel' : 'post');
    ShareContentModal.show(
      context,
      contentType: type,
      contentId: post.id,
    );
  }

  void _onSavePost(FeedPost post) async {
    if (post.isTweet) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save moments')),
        );
      }
      return;
    }
    final desired = !post.isSaved;
    final store = StoreProvider.of<AppState>(context);
    store.dispatch(UpdatePostSaved(post.id, desired));
    if (mounted) setState(() {});
    final saved = await _supabase.setPostSaved(post.id,
        save: desired, isTweet: post.isTweet);
    if (!mounted) return;
    try {
      final p =
          await SupabaseService().getPostById(post.id, isTweet: post.isTweet);
      final serverSaved = (p?['is_saved_by_me'] as bool?) ?? saved;
      store.dispatch(UpdatePostSaved(post.id, serverSaved));
      if (mounted) setState(() {});
    } catch (_) {
      store.dispatch(UpdatePostSaved(post.id, saved));
      if (mounted) setState(() {});
    }
  }

  void _onFollowPost(FeedPost post) {
    final followed = !post.isFollowed;
    final store = StoreProvider.of<AppState>(context);

    // 1. Optimistic UI Update
    store.dispatch(UpdatePostFollowed(post.id, followed));
    if (mounted) setState(() {});

    // Snackbar notification removed for a cleaner experience

    // 2. Call Service & Handle Result
    () async {
      final success = followed
          ? await _supabase.followUser(post.userId)
          : await _supabase.unfollowUser(post.userId);

      if (!mounted) return;

      if (!success) {
        // Revert UI if API failed
        store.dispatch(UpdatePostFollowed(post.id, !followed));
        setState(() {});
      } else {
        // Success: Update "My Profile" following count in Redux
        final meId = await CurrentUser.id;
        if (meId == null || meId.isEmpty) return;

        final cachedProfile = store.state.profileState.profile;
        final cachedId = cachedProfile?['id']?.toString() ??
            cachedProfile?['_id']?.toString();

        // Only update if the cached profile belongs to the current user
        if (cachedId != null && cachedId == meId) {
          final delta = followed ? 1 : -1;
          store.dispatch(AdjustFollowingCount(delta));
        }
      }
    }();
  }

  void _onMorePost(BuildContext context, FeedPost post) {
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(ctx);
                ContentReportSheet.show(
                  context,
                  contentType: post.isTweet
                      ? 'tweet'
                      : post.isAd
                          ? 'ad'
                          : (post.mediaType == PostMediaType.reel
                              ? 'reel'
                              : 'post'),
                  contentId: post.id,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.not_interested_outlined),
              title: const Text('Not interested'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('We\'ll show you less like this')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(ctx);
                final type = post.isTweet
                    ? 'tweet'
                    : post.isAd
                        ? 'ad'
                        : (post.mediaType == PostMediaType.reel
                            ? 'reel'
                            : 'post');
                final url = ShareLinks.urlForContent(
                  contentType: type,
                  contentId: post.id,
                );
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Link copied'),
                      behavior: SnackBarBehavior.floating),
                );
              },
            ),
            FutureBuilder<String?>(
              future: CurrentUser.id,
              builder: (context, snapshot) {
                final isOwner =
                    snapshot.data != null && snapshot.data == post.userId;
                if (!isOwner) return const SizedBox.shrink();
                return ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(
                    post.isTweet ? 'Delete Buzz' : 'Delete Moment',
                    style: const TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    bool isDeleting = false;
                    await showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (dctx) {
                        return StatefulBuilder(
                          builder: (context, setState) {
                            return Center(
                              child: Material(
                                color: Colors.transparent,
                                child: Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.9,
                                  constraints:
                                      const BoxConstraints(maxWidth: 360),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Theme.of(context).dividerColor),
                                  ),
                                  child: isDeleting
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 8),
                                            const SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 4,
                                                color: Colors.red,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              post.isTweet
                                                  ? 'Deleting tweet...'
                                                  : 'Deleting moment...',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 4),
                                            Text(
                                              post.isTweet
                                                  ? 'Delete Buzz?'
                                                  : 'Delete Moment?',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Are you sure you want to delete this ${post.isTweet ? 'tweet' : 'moment'}? This action cannot be undone.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text('Cancel'),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.red,
                                                      foregroundColor:
                                                          Colors.white,
                                                    ),
                                                    onPressed: () async {
                                                      setState(() =>
                                                          isDeleting = true);
                                                      try {
                                                        final ok =
                                                            await SupabaseService()
                                                                .deletePost(
                                                          post.id,
                                                          isTweet: post.isTweet,
                                                        );
                                                        await Future.delayed(
                                                            const Duration(
                                                                milliseconds:
                                                                    1500));
                                                        if (ok) {
                                                          if (mounted) {
                                                            StoreProvider.of<
                                                                        AppState>(
                                                                    context)
                                                                .dispatch(
                                                                    RemovePost(
                                                                        post.id));
                                                            Navigator.pop(
                                                                context);
                                                            messenger.showSnackBar(
                                                                const SnackBar(
                                                                    content: Text(
                                                                        'Deleted')));
                                                          }
                                                        } else {
                                                          if (mounted) {
                                                            setState(() =>
                                                                isDeleting =
                                                                    false);
                                                            Navigator.pop(
                                                                context);
                                                            messenger.showSnackBar(
                                                                const SnackBar(
                                                                    content: Text(
                                                                        'Failed to delete')));
                                                          }
                                                        }
                                                      } on ApiException catch (e) {
                                                        if (mounted) {
                                                          setState(() =>
                                                              isDeleting =
                                                                  false);
                                                          Navigator.pop(
                                                              context);
                                                          messenger.showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      e.message)));
                                                        }
                                                      } catch (e) {
                                                        if (mounted) {
                                                          setState(() =>
                                                              isDeleting =
                                                                  false);
                                                          Navigator.pop(
                                                              context);
                                                          messenger.showSnackBar(
                                                              SnackBar(
                                                                  content: Text(
                                                                      e.toString())));
                                                        }
                                                      }
                                                    },
                                                    child: const Text('Delete'),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<StoryGroup> _buildStoryGroupsFromUsers(
      List<Map<String, dynamic>> users) {
    final now = DateTime.now();
    return users.asMap().entries.map((entry) {
      final idx = entry.key;
      final u = entry.value;
      final username = (u['username'] ?? u['full_name'] ?? 'User').toString();
      final userId = (u['id'] ?? '').toString();
      return StoryGroup(
        userId: userId,
        userName: username,
        userAvatar: u['avatar_url'] as String?,
        isOnline: true,
        isCloseFriend: idx < 2,
        isSubscribedCreator: idx == 1,
        stories: [
          Story(
            id: 'story-$userId',
            userId: userId,
            userName: username,
            userAvatar: u['avatar_url'] as String?,
            mediaUrl:
                'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400',
            mediaType: StoryMediaType.image,
            createdAt: now.subtract(const Duration(hours: 2)),
            views: 0,
            isViewed: idx % 3 == 0,
            productUrl:
                idx == 0 ? 'https://bsmart.asynk.store/product/123' : null,
            externalLink: idx == 3 ? 'https://example.com' : null,
            hasPollQuiz: idx == 4,
          ),
        ],
      );
    }).toList();
  }

  Map<String, Map<String, bool>> _computeStoryStatuses(
      List<StoryGroup> groups) {
    final map = <String, Map<String, bool>>{};
    for (final g in groups) {
      final hasUnseen = g.stories.any((s) => s.isViewed == false);
      final allViewed =
          g.stories.isNotEmpty && g.stories.every((s) => s.isViewed == true);
      map[g.userId] = {
        'isCloseFriend': g.isCloseFriend,
        'hasUnseen': hasUnseen,
        'allViewed': allViewed,
        'isSubscribedCreator': g.isSubscribedCreator,
        'segments': g.stories.length > 1,
      };
    }
    return map;
  }

  List<Story> _buildMyStories(Map<String, dynamic>? profile) {
    final now = DateTime.now();
    if (profile == null) return [];
    return [
      Story(
        id: 'my-story-1',
        userId: (profile['id'] ?? 'me').toString(),
        userName:
            (profile['username'] ?? profile['full_name'] ?? 'You').toString(),
        userAvatar: profile['avatar_url'] as String?,
        mediaUrl:
            'https://images.unsplash.com/photo-1606787366850-de6330128bfc?w=400',
        mediaType: StoryMediaType.image,
        createdAt: now.subtract(const Duration(minutes: 30)),
        views: 12,
        isViewed: false,
      ),
    ];
  }

  void _onStoryTap(int userIndex) async {
    // Stop any currently playing feed video audio before opening stories.
    await VideoPool.instance.disposeActive();
    if (userIndex < 0 || userIndex >= _storyGroups.length) return;
    final group = _storyGroups[userIndex];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoryViewerScreen(
          storyGroups: _storyGroups,
          initialIndex: userIndex,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      final existing = _storyStatuses[group.userId] ?? {};
      _storyStatuses[group.userId] = {
        ...existing,
        'hasUnseen': false,
        'allViewed': true,
      };
    });
    await _onSilentRefresh();
  }

  // Pull-to-refresh: user explicitly wants fresh content from top
  Future<void> _onRefresh() async {
    final store = StoreProvider.of<AppState>(context);
    if (_feedScrollController.hasClients) {
      _feedScrollController.jumpTo(0);
    }
    // Clear Redux posts so isFirstLoad = true in _loadInitialFeed
    store.dispatch(SetFeedPosts(const []));
    _beginFeedSkeletonLoading();
    await Future.wait([_loadData(store), _loadInitialFeed(forceNetwork: true)]);
  }

  // Silent background refresh after story/route pop — preserve scroll
  Future<void> _onSilentRefresh() async {
    final store = StoreProvider.of<AppState>(context);
    _beginFeedSkeletonLoading();
    await Future.wait([_loadData(store), _loadInitialFeed(forceNetwork: true)]);
  }

  Future<void> _openStoryCamera() async {
    _pendingHomeRefreshAfterRoute = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateUploadScreen(
          initialMode: UploadMode.story,
        ),
      ),
    );
    if (!mounted) return;
    await _onSilentRefresh();
  }

  void _openVendorAdComposer(String contentType) {
    final mode =
        contentType.toLowerCase() == 'reel' ? UploadMode.reel : UploadMode.post;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateUploadScreen(
          initialMode: mode,
          isAdFlow: true,
        ),
      ),
    );
  }

  void _setTabIndex(int idx,
      {required bool userInitiated, required bool fromSwipe}) {
    if (idx == 2 || idx == 5 || idx != _currentIndex) {
      unawaited(MediaPlaybackRegistry.instance.pauseAll());
    }
    if (idx == 2) {
      _pendingHomeRefreshAfterRoute = true;
      if (_isVendor) {
        _openVendorAdComposer('post');
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const CreateUploadScreen(
              initialMode: UploadMode.post,
            ),
          ),
        );
      }
      return;
    }
    // Profile from sidebar (desktop)
    if (idx == 5) {
      _openProfile();
      return;
    }

    final wasOnHome = _currentIndex == 0;
    final switchingToHome =
        idx == 0 && !wasOnHome; // ← only true when actually switching

    if (idx != _currentIndex) {
      if (idx == 4 && !_reelsPrefetched) {
        _reelsPrefetched = true;
        unawaited(() async {
          try {
            await _reelsService.fetchReels(limit: 20, offset: 0);
            if (!_shouldAvoidBackgroundMediaFetch()) {
              await _reelsService.preWarmReels(3);
            }
          } catch (_) {}
        }());
      }
      setState(() {
        _currentIndex = idx;
      });
      if (idx == 0) {
        unawaited(_restoreFeedScrollPosition());
      }
    }

    // Only schedule refresh when genuinely navigating TO home from another tab
    // NOT when tapping home while already on home (that would be Instagram's
    // scroll-to-top behavior which we handle separately)
    if (switchingToHome) {
      _scheduleHomeRefresh();
    } else if (idx == 0 && wasOnHome && userInitiated && !fromSwipe) {
      // Already on home — scroll to top like Instagram does
      if (_feedScrollController.hasClients) {
        _feedScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _onNavTap(int idx) {
    if (_swipeTabs.contains(idx)) {
      final page = _swipeTabs.indexOf(idx);
      final controller = _tabPageController;
      if (controller != null && controller.hasClients) {
        controller.animateToPage(
          page,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
    _setTabIndex(idx, userInitiated: true, fromSwipe: false);
  }

  void _showCreateModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Create',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      gradient: DesignTokens.instaGradient,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(LucideIcons.image,
                      color: Colors.white, size: 22),
                ),
                title: Text(_isVendor
                    ? 'home_dashboard_create_ads'.tr()
                    : 'home_dashboard_create_post'.tr()),
                subtitle: Text(
                  _isVendor ? 'Upload spotlight campaign' : 'Photo or video',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => _isVendor
                            ? const CreateUploadScreen(
                                initialMode: UploadMode.post,
                                isAdFlow: true,
                              )
                            : const CreateUploadScreen(
                                initialMode: UploadMode.post,
                              ),
                      ),
                    );
                  });
                },
              ),
              if (!_isVendor)
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        gradient: DesignTokens.instaGradient,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(LucideIcons.video,
                        color: Colors.white, size: 22),
                  ),
                  title: const Text('Upload bSpark'),
                  subtitle: Text('Short video',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CreateUploadScreen(
                              initialMode: UploadMode.reel,
                            ),
                          ),
                        );
                      }
                    });
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context, Color appBarFg) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatar = GestureDetector(
      onTap: _openProfile,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 12),
        child: Container(
          width: 32,
          height: 32,
          padding: EdgeInsets.all(_yourStoryHasActive ? 1.5 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _yourStoryHasActive ? DesignTokens.instaGradient : null,
            color: _yourStoryHasActive
                ? null
                : (isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade200),
            border: _yourStoryHasActive
                ? null
                : Border.all(
                    color:
                        isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade300,
                  ),
          ),
          child: CircleAvatar(
            radius: _yourStoryHasActive ? 14 : 16,
            backgroundColor: _yourStoryHasActive && isDark
                ? Colors.black
                : (_yourStoryHasActive ? Colors.white : Colors.transparent),
            child: CircleAvatar(
              radius: _yourStoryHasActive ? 13 : 15,
              backgroundColor:
                  isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade200,
              backgroundImage: _currentUserProfile != null &&
                      _currentUserProfile!['avatar_url'] != null &&
                      (_currentUserProfile!['avatar_url'] as String).isNotEmpty
                  ? NetworkImage(_currentUserProfile!['avatar_url'] as String)
                  : null,
              child: _currentUserProfile == null ||
                      _currentUserProfile!['avatar_url'] == null ||
                      (_currentUserProfile!['avatar_url'] as String).isEmpty
                  ? Text(
                      _currentUserProfile != null
                          ? ((_currentUserProfile!['username'] ??
                                      _currentUserProfile!['full_name'] ??
                                      'U') as String)
                                  .isNotEmpty
                              ? ((_currentUserProfile!['username'] ??
                                      _currentUserProfile!['full_name'] ??
                                      'U') as String)
                                  .substring(0, 1)
                                  .toUpperCase()
                              : 'U'
                          : 'U',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: appBarFg),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );

    return Showcase(
      key: _profileStep.key,
      title: _profileStep.title,
      description: _profileStep.description,
      tooltipActions: buildOnboardingTooltipActions(),
      showArrow: false,
      tooltipPosition: _profileStep.tooltipPosition,
      titleTextStyle: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: theme.colorScheme.onSurface,
      ),
      descTextStyle: GoogleFonts.montserrat(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      tooltipBackgroundColor: theme.colorScheme.surface,
      tooltipBorderRadius: BorderRadius.circular(24),
      overlayColor: Colors.black,
      overlayOpacity: 0.72,
      blurValue: 1.6,
      targetShapeBorder: const CircleBorder(),
      targetPadding: const EdgeInsets.all(8),
      targetTooltipGap: 14,
      toolTipMargin: 14,
      disableBarrierInteraction: true,
      enableAutoScroll: false,
      scrollAlignment: 0.45,
      child: avatar,
    );
  }

  @override
  Widget build(BuildContext context) {
    _tabPageController ??= PageController(
      initialPage: math.max(0, _swipeTabs.indexOf(_currentIndex)),
    );
    final store = StoreProvider.of<AppState>(context);
    final feedState = store.state.feedState;
    final totalCount = feedState.posts.length;
    final effectiveVisible = totalCount == 0
        ? 0
        : math.min(
            totalCount,
            (_visibleCount <= 0) ? _pageSize : _visibleCount,
          );
    final posts =
        feedState.posts.take(effectiveVisible).toList(growable: false);
    final hasMoreToShow = effectiveVisible < totalCount;
    final isLoading = feedState.isLoading;
    final showFeedSkeleton = isLoading || _feedSkeletonLoadCount > 0;
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarBg =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    PreferredSizeWidget? buildAppBar(int idx) {
      final isFullScreen = idx == 1 || idx == 3 || idx == 4;
      if (isFullScreen) return null;
      return AppBar(
        centerTitle: false,
        title: Align(
          alignment: Alignment.centerLeft,
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                DesignTokens.instaPurple,
                DesignTokens.instaPink,
                DesignTokens.instaOrange
              ],
            ).createShader(bounds),
            child: Text('b_smart', style: _brandTitleStyle()),
          ),
        ),
        elevation: 0,
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        iconTheme: IconThemeData(color: appBarFg),
        actions: [
          if (!isDesktop)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pushNamed('/search'),
                    icon: Icon(LucideIcons.search, size: 24, color: appBarFg),
                  ),
                  const SizedBox(width: 8),
                  Showcase(
                    key: _walletStep.key,
                    title: _walletStep.title,
                    description: _walletStep.description,
                    tooltipActions: buildOnboardingTooltipActions(),
                    showArrow: false,
                    tooltipPosition: _walletStep.tooltipPosition,
                    titleTextStyle: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: appBarFg,
                    ),
                    descTextStyle: GoogleFonts.montserrat(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltipBackgroundColor: theme.colorScheme.surface,
                    tooltipBorderRadius: BorderRadius.circular(24),
                    overlayColor: Colors.black,
                    overlayOpacity: 0.72,
                    blurValue: 1.6,
                    targetShapeBorder: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    targetPadding: const EdgeInsets.all(4),
                    targetTooltipGap: 14,
                    toolTipMargin: 14,
                    disableBarrierInteraction: true,
                    enableAutoScroll: false,
                    scrollAlignment: 0.45,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/wallet'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2D2D2D)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF3D3D3D)
                                  : Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                  gradient: DesignTokens.instaGradient,
                                  shape: BoxShape.circle),
                              child: const Icon(LucideIcons.wallet,
                                  size: 12, color: Colors.white),
                            ),
                            const SizedBox(width: 6),
                            Text('$_balance',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: appBarFg)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/notifications'),
                        icon:
                            Icon(LucideIcons.heart, size: 24, color: appBarFg),
                      ),
                      if (_notificationBadgeText(_unreadNotificationCount) !=
                          null)
                        Positioned(
                          right: 5,
                          top: 6,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: DesignTokens.instaPink,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFFE8E8E8)
                                    : Colors.white,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _notificationBadgeText(_unreadNotificationCount)!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  _buildProfileAvatar(context, appBarFg),
                ],
              ),
            ),
        ],
      );
    }

    Widget buildTabBody(int idx) {
      if (idx == 0) {
        return RefreshIndicator(
          onRefresh: _onRefresh,
          child: Stack(
            children: [
              Visibility(
                visible: !isLoading,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: CustomScrollView(
                  controller: _feedScrollController,
                  cacheExtent: 400,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _FeedHeader(
                        storyUsers: _storyUsers,
                        storyGroups: _storyGroups,
                        storyStatuses: _storyStatuses,
                        yourStoryHasActive: _yourStoryHasActive,
                        yourAvatarUrl: (_currentUserProfile?['avatar_url'] ??
                                _currentUserProfile?['avatar'] ??
                                _currentUserProfile?['profile_image'])
                            ?.toString(),
                        currentLocation: _currentLocation,
                        locationLoading: _locationLoading,
                        isDark: isDark,
                        onYourStoryTap: () {
                          if (_yourStoryHasActive) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OwnStoryViewerScreen(
                                  stories: _myStories,
                                  storyId: _myStoryId,
                                  userName: (_currentUserProfile?['username'] ??
                                          _currentUserProfile?['full_name'] ??
                                          'You')
                                      .toString(),
                                ),
                              ),
                            );
                          } else {
                            _openStoryCamera();
                          }
                        },
                        onYourStoryAddTap: _openStoryCamera,
                        onUserStoryTap:
                            _storyGroups.isEmpty ? null : _onStoryTap,
                        onLocationTap: _openLocationSearch,
                      ),
                    ),
                    if (posts.isEmpty && showFeedSkeleton)
                      ..._buildFeedSkeletonSlivers(context)
                    else if (posts.isEmpty)
                      SliverFillRemaining(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.image,
                                  size: 48,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color),
                              const SizedBox(height: 12),
                              Text(
                                'No moments yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Create your first moment from the + button',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Builder(
                        builder: (context) {
                          final rows = _buildFeedRows(posts);
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final row = rows[index];
                                if (row.type ==
                                    _FeedRenderRowType.suggestedReels) {
                                  if (_suggestedReels.isEmpty &&
                                      _reelSuggestionsLoading) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: _SuggestedReelsPlaceholder(
                                        isLoading: true,
                                      ),
                                    );
                                  }
                                  if (_suggestedReels.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return SuggestedReelsCard(
                                    reels: _suggestedReels,
                                    imageHeaders:
                                        _suggestionImageHeaders.isEmpty
                                            ? null
                                            : _suggestionImageHeaders,
                                    onOpenReel: (reel) {
                                      if (reel.id.isEmpty) return;
                                      Navigator.of(context).pushNamed(
                                        '/reels',
                                        arguments: {
                                          'initialReelId': reel.id,
                                        },
                                      );
                                    },
                                  );
                                }
                                if (row.type ==
                                    _FeedRenderRowType.suggestedPeople) {
                                  final isLoading = _followSuggestionsLoading;
                                  final users = isLoading
                                      ? const <SuggestionUser>[]
                                      : _suggestionsForBlock(
                                          row.suggestionBlockIndex,
                                          count: 10,
                                        );
                                  return SuggestionFollowBlock(
                                    key: ValueKey(
                                        'people-suggestions-${row.suggestionBlockIndex}'),
                                    isLoading: isLoading,
                                    imageHeaders:
                                        _suggestionImageHeaders.isEmpty
                                            ? null
                                            : _suggestionImageHeaders,
                                    sections: [
                                      SuggestionFollowSection(
                                        title: 'Follow people you might like',
                                        helperText:
                                            'Find and follow other people based on your interests.',
                                        users: users,
                                        onSeeAll: null,
                                        onOverflow: null,
                                      ),
                                    ],
                                    onDismissUser: _dismissSuggestionUser,
                                    onUserTap: (userId) {
                                      final id = userId.trim();
                                      if (id.isEmpty) return;
                                      Navigator.of(context)
                                          .pushNamed('/profile/$id');
                                    },
                                    onFollow: (user) =>
                                        unawaited(_followSuggestionUser(user)),
                                  );
                                }
                                if (row.type ==
                                    _FeedRenderRowType.suggestedVendors) {
                                  final isLoading = _vendorSuggestionsLoading;
                                  final vendors = isLoading
                                      ? const <SuggestionUser>[]
                                      : _vendorsForBlock(
                                          row.suggestionBlockIndex,
                                          count: 10,
                                        );
                                  return SuggestionFollowBlock(
                                    key: ValueKey(
                                        'vendor-suggestions-${row.suggestionBlockIndex}'),
                                    isLoading: isLoading,
                                    imageHeaders:
                                        _suggestionImageHeaders.isEmpty
                                            ? null
                                            : _suggestionImageHeaders,
                                    sections: [
                                      SuggestionFollowSection(
                                        title:
                                            'Follow businesses you’re interested in',
                                        helperText:
                                            'Discover vendors and follow businesses you care about.',
                                        users: vendors,
                                        onSeeAll: _openSuggestionsSeeAll,
                                        onOverflow: null,
                                      ),
                                    ],
                                    onDismissUser: _dismissVendorSuggestion,
                                    onUserTap: (vendorId) {
                                      final id = vendorId.trim();
                                      if (id.isEmpty) return;
                                      Navigator.of(context)
                                          .pushNamed('/vendor/$id/public');
                                    },
                                    onFollow: (vendor) => unawaited(
                                        _followVendorSuggestion(vendor)),
                                  );
                                }
                                if (row.type ==
                                    _FeedRenderRowType.suggestedAds) {
                                  final ad = row.post;
                                  if (ad == null) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 12),
                                      child: _SuggestedAdsPlaceholder(
                                        isLoading: _adSuggestionsLoading,
                                      ),
                                    );
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding:
                                            EdgeInsets.fromLTRB(14, 12, 14, 6),
                                        child: Text(
                                          'Suggested spotlight',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Builder(
                                        builder: (context) {
                                          final p = ad;
                                          final isOwnPost =
                                              _currentUserId != null &&
                                                  p.userId == _currentUserId;
                                          return VisibilityDetector(
                                            key: ValueKey('feed-vis-${p.id}'),
                                            onVisibilityChanged: (info) {
                                              _onFeedItemVisibilityChanged(
                                                p.id,
                                                info.visibleFraction,
                                              );
                                            },
                                            child: RepaintBoundary(
                                              child: PostCard(
                                                key: ValueKey('card-${p.id}'),
                                                post: p,
                                                isTabActive:
                                                    _currentIndex == 0 &&
                                                        _isRouteActive,
                                                isActive: false,
                                                activeIdListenable:
                                                    _activeFeedPostIdListenable,
                                                isOwnPost: isOwnPost,
                                                onUserTap: p.userId.isNotEmpty
                                                    ? () => Navigator.of(
                                                            context)
                                                        .pushNamed(
                                                            '/vendor/${p.userId}/public')
                                                    : null,
                                                onLike: () => _onLikePost(p),
                                                onDoubleTapLike: () =>
                                                    _onDoubleTapLikePost(p),
                                                onComment: () =>
                                                    _onCommentPost(p),
                                                onShare: () => _onSharePost(p),
                                                onSave: () => _onSavePost(p),
                                                onFollow: isOwnPost
                                                    ? null
                                                    : () => _onFollowPost(p),
                                                onMore: () =>
                                                    _onMorePost(context, p),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                }

                                final p = row.post!;
                                final isOwnPost = _currentUserId != null &&
                                    p.userId == _currentUserId;
                                Widget itemWidget;
                                try {
                                  itemWidget = VisibilityDetector(
                                    key: ValueKey('feed-vis-${p.id}'),
                                    onVisibilityChanged: (info) {
                                      _onFeedItemVisibilityChanged(
                                        p.id,
                                        info.visibleFraction,
                                      );
                                    },
                                    child: RepaintBoundary(
                                      child: PostCard(
                                        key: ValueKey(
                                            'card-${p.id}'), // Prevent unnecessary rebuilds
                                        post: p,
                                        isTabActive: _currentIndex == 0 &&
                                            _isRouteActive,
                                        isActive: false,
                                        activeIdListenable:
                                            _activeFeedPostIdListenable,
                                        isOwnPost: isOwnPost,
                                        onUserTap: p.userId.isNotEmpty
                                            ? () => Navigator.of(context)
                                                .pushNamed(p.isAd
                                                    ? '/vendor/${p.userId}/public'
                                                    : '/profile/${p.userId}')
                                            : null,
                                        onLike: () => _onLikePost(p),
                                        onDoubleTapLike: () =>
                                            _onDoubleTapLikePost(p),
                                        onComment: () => _onCommentPost(p),
                                        onShare: () => _onSharePost(p),
                                        onSave: () => _onSavePost(p),
                                        onFollow: isOwnPost
                                            ? null
                                            : () => _onFollowPost(p),
                                        onMore: () => _onMorePost(context, p),
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  itemWidget = Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        const Icon(Icons.broken_image,
                                            size: 40),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Failed to load moment',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return itemWidget;
                              },
                              childCount: rows.length,
                            ),
                          );
                        },
                      ),
                    if (hasMoreToShow)
                      const SliverToBoxAdapter(child: SizedBox(height: 28)),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              ),
              if (showFeedSkeleton && posts.isNotEmpty)
                const ColoredBox(
                  color: Colors.transparent,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: DesignTokens.instaPink),
                  ),
                ),
            ],
          ),
        );
      }
      if (idx == 1) {
        return AdsPageScreen(isTabActive: _currentIndex == 1 && _isRouteActive);
      }
      if (idx == 3) {
        return PromoteScreen(
          isActive: _currentIndex == 3 && _isRouteActive,
        );
      }
      if (idx == 4) {
        return Container(
          color: Colors.black,
          child: ReelsScreen(isActive: _currentIndex == 4 && _isRouteActive),
        );
      }
      return const SizedBox.shrink();
    }

    Widget buildTabScaffold(int idx) {
      final isFullScreen = idx == 1 || idx == 3 || idx == 4;
      return Scaffold(
        extendBody: idx != 4,
        backgroundColor: isFullScreen
            ? (isDark ? const Color(0xFF121212) : Colors.black)
            : theme.scaffoldBackgroundColor,
        appBar: buildAppBar(idx),
        body: ColoredBox(
          color: isFullScreen
              ? (isDark ? const Color(0xFF121212) : Colors.black)
              : theme.scaffoldBackgroundColor,
          child: buildTabBody(idx),
        ),
        bottomNavigationBar: isDesktop || idx == 4
            ? null
            : (idx == 0
                ? BottomNav(
                    currentIndex: _currentIndex,
                    onTap: _onNavTap,
                    homeStep: _homeStep,
                    adsStep: _adsStep,
                    createStep: _createStep,
                    rocketStep: _rocketStep,
                    reelsStep: _reelsStep,
                  )
                : const SizedBox.shrink()),
      );
    }

    final content = Stack(
      children: [
        ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: PageView.builder(
            physics: _onboardingPageScrollLocked
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            controller: _tabPageController,
            itemCount: _swipeTabs.length,
            onPageChanged: (page) {
              final idx = _swipeTabs[page];
              _setTabIndex(idx, userInitiated: false, fromSwipe: true);
            },
            itemBuilder: (context, page) {
              final idx = _swipeTabs[page];
              return buildTabScaffold(idx);
            },
          ),
        ),
        if (!isDesktop &&
            !_isCommentsOpen &&
            (_currentIndex == 0 ||
                _currentIndex == 1 ||
                _currentIndex == 3 ||
                _currentIndex == 4))
          Positioned.fill(
            child: FloatingMessageOverlay(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MessagingScreen(),
                  ),
                );
              },
            ),
          ),
      ],
    );

    Widget body;
    if (isDesktop) {
      final isFullScreen = _currentIndex == 1 ||
          _currentIndex == 3 ||
          _currentIndex == 4; // Ads, Promote, Reels
      body = Row(
        children: [
          Sidebar(
            currentIndex: _currentIndex,
            isVendor: _isVendor,
            onNavTap: _onNavTap,
            onCreatePost: () {
              if (_isVendor) {
                _openVendorAdComposer('post');
              } else {
                _pendingHomeRefreshAfterRoute = true;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateUploadScreen(
                      initialMode: UploadMode.post,
                    ),
                  ),
                );
              }
            },
            onUploadReel: () {
              if (_isVendor) return;
              _pendingHomeRefreshAfterRoute = true;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateUploadScreen(
                    initialMode: UploadMode.reel,
                  ),
                ),
              );
            },
            onCreateAd: () {
              _openVendorAdComposer('post');
            },
          ),
          Expanded(
            child: Stack(
              children: [
                content,
                if (!isFullScreen) ...[
                  Positioned(
                    top: 32,
                    right: 32,
                    child: _DesktopNotificationsButton(),
                  ),
                  Positioned(
                    bottom: 32,
                    right: 32,
                    child: _FloatingWallet(balance: _balance),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    } else {
      body = content;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentIndex != 0) {
          _onNavTap(0);
          return;
        }
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.fuchsia) {
          SystemNavigator.pop();
        }
      },
      child: body,
    );
  }

  TextStyle _brandTitleStyle() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return GoogleFonts.pacifico(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w400,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
          fontFamily: 'cursive',
        );
    }
  }

  List<Widget> _buildFeedSkeletonSlivers(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base =
        isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade300;
    final highlight =
        isDark ? Colors.white.withValues(alpha: 0.14) : Colors.grey.shade100;

    Widget box({
      double? width,
      double height = 12,
      double radius = 10,
      EdgeInsetsGeometry margin = EdgeInsets.zero,
    }) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    Widget shimmerCard() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: base,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          box(width: 120, height: 12, radius: 999),
                          const SizedBox(height: 8),
                          box(width: 80, height: 10, radius: 999),
                        ],
                      ),
                    ),
                    box(width: 54, height: 24, radius: 999),
                  ],
                ),
              ),
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  color: highlight,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    box(width: double.infinity, height: 12, radius: 999),
                    const SizedBox(height: 8),
                    box(
                        width: MediaQuery.sizeOf(context).width * 0.55,
                        height: 12,
                        radius: 999),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        box(width: 28, height: 28, radius: 999),
                        const SizedBox(width: 10),
                        box(width: 28, height: 28, radius: 999),
                        const SizedBox(width: 10),
                        box(width: 28, height: 28, radius: 999),
                        const Spacer(),
                        box(width: 70, height: 12, radius: 999),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return <Widget>[
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  box(width: 42, height: 42, radius: 999),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        box(width: 120, height: 12, radius: 999),
                        const SizedBox(height: 8),
                        box(width: 160, height: 10, radius: 999),
                      ],
                    ),
                  ),
                  box(width: 54, height: 28, radius: 999),
                ],
              ),
            ),
          ],
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                box(width: 62, height: 62, radius: 999),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      box(width: 180, height: 14, radius: 999),
                      const SizedBox(height: 10),
                      box(width: 120, height: 10, radius: 999),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => shimmerCard(),
          childCount: 4,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 28)),
    ];
  }
}

class _NoGlowScrollBehavior extends MaterialScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _DesktopNotificationsButton extends StatefulWidget {
  @override
  State<_DesktopNotificationsButton> createState() =>
      _DesktopNotificationsButtonState();
}

class _DesktopNotificationsButtonState
    extends State<_DesktopNotificationsButton> {
  bool _showDropdown = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardColor;
    final fgColor = theme.colorScheme.onSurface;
    return TapRegion(
      onTapOutside: (_) => setState(() => _showDropdown = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            elevation: 4,
            shadowColor: Colors.black26,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => setState(() => _showDropdown = !_showDropdown),
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _showDropdown ? DesignTokens.instaGradient : null,
                  color: _showDropdown ? null : surfaceColor,
                  border: Border.all(
                    color: _showDropdown
                        ? Colors.transparent
                        : (isDark
                            ? const Color(0xFF3D3D3D)
                            : Colors.grey.shade100),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                        child: Icon(LucideIcons.heart,
                            size: 20,
                            color: _showDropdown ? Colors.white : fgColor)),
                    Positioned(
                      right: 7,
                      top: 7,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: DesignTokens.instaPink,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? Colors.black : Colors.white,
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showDropdown)
            Positioned(
              top: 48,
              right: 0,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 320,
                  constraints: const BoxConstraints(maxHeight: 320),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Notifications',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: fgColor)),
                            GestureDetector(
                                onTap: () {},
                                child: const Text('Mark all read',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: DesignTokens.instaPink,
                                        fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: const [
                            _NotificationTile(
                                icon: LucideIcons.bell,
                                iconColor: Colors.blue,
                                title: 'New follower: Sarah',
                                time: '2 min ago'),
                            _NotificationTile(
                                icon: LucideIcons.heart,
                                iconColor: DesignTokens.instaPink,
                                title: 'Mike liked your moment',
                                time: '1 hour ago'),
                            _NotificationTile(
                                icon: LucideIcons.messageCircle,
                                iconColor: DesignTokens.instaPurple,
                                title: 'Anna commented: "Amazing!"',
                                time: '2 hours ago'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String time;

  const _NotificationTile(
      {required this.icon,
      required this.iconColor,
      required this.title,
      required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor =
        theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600;
    return InkWell(
      onTap: () {},
      hoverColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(35),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                        fontSize: 14, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(time, style: TextStyle(fontSize: 12, color: mutedColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingWallet extends StatelessWidget {
  final int balance;

  const _FloatingWallet({required this.balance});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardColor;
    final fgColor = theme.colorScheme.onSurface;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/wallet'),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    gradient: DesignTokens.instaGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: DesignTokens.instaPink.withAlpha(80),
                          blurRadius: 8)
                    ]),
                child: const Icon(LucideIcons.wallet,
                    size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Balance',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: theme.textTheme.bodyMedium?.color ??
                              Colors.grey.shade600)),
                  Text('$balance',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: fgColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedAdsPlaceholder extends StatelessWidget {
  final bool isLoading;
  const _SuggestedAdsPlaceholder({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;
    final titleColor = theme.colorScheme.onSurface;
    final subColor =
        theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Image.asset(
                    'assets/bsmart_icons/2.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                    color: titleColor.withValues(alpha: 0.75),
                    colorBlendMode: BlendMode.srcIn,
                    filterQuality: FilterQuality.high,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested spotlights',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading
                      ? 'Loading suggestions…'
                      : 'No spotlight suggestions right now.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedReelsPlaceholder extends StatelessWidget {
  final bool isLoading;
  const _SuggestedReelsPlaceholder({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1F1F1F) : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;
    final titleColor = theme.colorScheme.onSurface;
    final subColor =
        theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white10
                  : Colors.black.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    LucideIcons.clapperboard,
                    size: 18,
                    color: titleColor.withValues(alpha: 0.75),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested bSparks',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading
                      ? 'Loading suggestions…'
                      : 'No reel suggestions right now.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: subColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
