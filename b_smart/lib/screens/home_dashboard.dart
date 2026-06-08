import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/feed_service.dart';
import '../services/supabase_service.dart';
import '../services/wallet_service.dart';
import '../services/video_pool.dart';
import '../state/app_state.dart';
import '../state/profile_actions.dart';
import '../state/feed_actions.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_row.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/sidebar.dart';
import '../theme/design_tokens.dart';
import '../models/story_model.dart';
import '../models/feed_post_model.dart';
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
import '../utils/share_links.dart';
import '../api/auth_api.dart';
import '../api/api_exceptions.dart';
import '../api/api_client.dart';
import '../api/follows_api.dart';
import '../api/users_api.dart';
import '../api/suggestions_api.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/url_helper.dart';
import '../widgets/dynamic_media_widget.dart';
import '../widgets/floating_message_overlay.dart';
import '../widgets/suggestion_follow.dart';
import '../widgets/suggested_reels_card.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'profile_screen.dart';
import '../routes.dart';
import 'follow_list_screen.dart';
import 'messaging_screen.dart';

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
                              ? 'home_dashboard_detecting_location'.tr()
                                  : 'home_dashboard_tap_to_detect_location'.tr())
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

class _LocationCard extends StatelessWidget {
  final String name;
  final String line1;
  final String line2;
  final String city;
  final String tag;
  final bool highlight;

  const _LocationCard({
    required this.name,
    required this.line1,
    required this.line2,
    required this.city,
    required this.tag,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = highlight
        ? const Color(0xFFEA8A4A)
        : (isDark ? Colors.white24 : Colors.black12);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232323) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: highlight ? 1.5 : 1),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            line1,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            line2,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            city,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          if (tag.trim().isNotEmpty)
            Text(
              tag,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDashboardState extends State<HomeDashboard>
    with RouteAware, WidgetsBindingObserver {
  final FeedService _feedService = FeedService();
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
  bool _isFeedScrolling = false;
  Timer? _scrollIdleTimer;
  String? _pendingActivePostId;

  final List<Map<String, String>> _mockLocations = const [
    {
      'name': 'Devang',
      'line1': '701, I wing, Rashmi',
      'line2': 'Tanmay, Mira Road...',
      'city': 'MUMBAI 401107',
      'tag': 'Default address',
    },
    {
      'name': 'Aman Pandey',
      'line1': '502, 2B, Om',
      'line2': 'Shivaya, Near Cin...',
      'city': 'THANE 401107',
      'tag': '',
    },
    {
      'name': 'Madh',
      'line1': '21 Aarti Wada, D',
      'line2': 'Behind factory',
      'city': 'DHULE',
      'tag': '',
    },
  ];

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
      unawaited(primeMediaAuthHeaders());
      final store = StoreProvider.of<AppState>(context);
      // Force a clean, fresh feed on app open to avoid stale or partial data.
      store.dispatch(SetFeedPosts(const []));
      store.dispatch(SetFeedLoading(true));
      _loadData(store);
      _loadInitialFeed(forceNetwork: true);
      unawaited(_loadFollowSuggestions());
      unawaited(_loadVendorSuggestions());
      unawaited(_loadAdSuggestions());
      unawaited(_loadReelSuggestions(force: true));
      _fetchCurrentLocation();
    });
  }

  String _suggestionIdOf(Map<String, dynamic> u) {
    final embedded = u['user'];
    if (embedded is Map) {
      final e = Map<String, dynamic>.from(embedded);
      final raw = e['_id'] ?? e['id'] ?? e['userId'];
      return raw == null ? '' : raw.toString();
    }
    final raw = u['_id'] ?? u['id'] ?? u['userId'];
    return raw == null ? '' : raw.toString();
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
            .toList();
      }
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
    if (embedded is Map) {
      final e = Map<String, dynamic>.from(embedded);
      final raw = e['_id'] ?? e['id'] ?? e['vendorId'] ?? e['userId'];
      return raw == null ? '' : raw.toString();
    }
    final raw = v['_id'] ?? v['id'] ?? v['vendorId'] ?? v['userId'];
    return raw == null ? '' : raw.toString();
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

        final thumbField = media['thumbnails'] ??
            media['thumbnail'] ??
            media['thumbnailUrl'] ??
            media['thumb'];
        if (thumbField is String) {
          thumbnailUrl = str(thumbField);
        } else if (thumbField is Map) {
          final m = Map<String, dynamic>.from(thumbField);
          thumbnailUrl =
              str(m['fileUrl']) ?? str(m['url']) ?? str(m['file_url']);
        } else if (thumbField is List && thumbField.isNotEmpty) {
          final t0 = thumbField.first;
          if (t0 is String) {
            thumbnailUrl = str(t0);
          } else if (t0 is Map) {
            final m = Map<String, dynamic>.from(t0);
            thumbnailUrl =
                str(m['fileUrl']) ?? str(m['fileName']) ?? str(m['url']);
          }
        }

        final crop = media['crop'] is Map
            ? Map<String, dynamic>.from(media['crop'])
            : const <String, dynamic>{};
        aspectRatio = str(crop['aspect_ratio']) ?? str(media['aspect_ratio']);
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
      thumbnailUrl: normalizedThumb == null || normalizedThumb.isEmpty
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
    unawaited(VideoPool.instance.pauseActive());
    if (mounted) setState(() {});
  }

  @override
  void didPopNext() {
    if (_isRouteActive) return;
    _isRouteActive = true;
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
    _activeFeedDebounce?.cancel();
    _autoRefreshDebounce?.cancel();
    _scrollIdleTimer?.cancel();
    _activeFeedPostIdListenable.dispose();
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
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;
    if (_currentIndex != 0) return;
    unawaited(VideoPool.instance.disposeAll());
    // When app resumes, jump to top and refresh to show latest posts.
    if (_feedScrollController.hasClients) {
      _feedScrollController.jumpTo(0);
    }
    final store = StoreProvider.of<AppState>(context);
    unawaited(
        Future.wait([_loadData(store), _loadInitialFeed(forceNetwork: true)]));
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
      unawaited(Future.wait(
          [_loadData(store), _loadInitialFeed(forceNetwork: true)]));
    });
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
    await primeMediaAuthHeaders(); // ensure auth headers ready before any image loads
    unawaited(_loadReelSuggestions(force: forceNetwork));
    final store = StoreProvider.of<AppState>(context);
    final isFirstLoad = store.state.feedState.posts.isEmpty || forceNetwork;
    if (isFirstLoad) {
      _prewarmedFeedIds.clear();
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

    if (isFirstLoad || forceNetwork) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_feedScrollController.hasClients) {
          _feedScrollController.jumpTo(0);
        }
      });
    }

    if (isFirstLoad) store.dispatch(SetFeedLoading(false));

    // If list is too short to scroll, proactively load next page
    if (items.isNotEmpty) {
      _checkIfListNeedsMorePosts();
      // Ensure we have a full initial batch without requiring a scroll.
      unawaited(_prefetchUntil(minPosts: _pageSize, maxPages: 3));
    }
  }

  Future<void> _precacheFeedMedia(List<FeedPost> posts) async {
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
    final wasScrolling = _isFeedScrolling;
    _isFeedScrolling = true;
    if (!wasScrolling && _currentIndex == 0 && _isRouteActive) {
      unawaited(VideoPool.instance.pauseActive());
    }
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(const Duration(milliseconds: 120), () {
      _isFeedScrolling = false;
      final pending = _pendingActivePostId;
      if (pending != null && pending != _activeFeedPostId) {
        _activeFeedPostId = pending;
        _activeFeedPostIdListenable.value = pending;
      } else if (_activeFeedPostId != null &&
          _currentIndex == 0 &&
          _isRouteActive) {
        unawaited(VideoPool.instance.resumeActive());
      }
      _pendingActivePostId = null;
    });
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

  void _showLocationSheet() {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1B1B) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose your location',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _mockLocations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final item = _mockLocations[index];
                      return _LocationCard(
                        name: item['name'] ?? '',
                        line1: item['line1'] ?? '',
                        line2: item['line2'] ?? '',
                        city: item['city'] ?? '',
                        tag: item['tag'] ?? '',
                        highlight: index == 0,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _SheetAction(
                  icon: LucideIcons.mapPin,
                  label: 'Enter an Indian pincode',
                  onTap: () {
                    Navigator.of(ctx).pop();
                  },
                ),
                const SizedBox(height: 4),
                _SheetAction(
                  icon: LucideIcons.locateFixed,
                  label: 'Use my current location',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _fetchCurrentLocation();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      if (mounted) setState(() => _locationLoading = true);
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
          desiredAccuracy: LocationAccuracy.low);
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      String loc;
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if ((p.name ?? '').isNotEmpty) p.name!,
          if ((p.subLocality ?? '').isNotEmpty) p.subLocality!,
          if ((p.locality ?? '').isNotEmpty) p.locality!,
          if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea!,
          if ((p.country ?? '').isNotEmpty) p.country!,
        ];
        loc = parts.where((e) => e.trim().isNotEmpty).toList().join(', ');
      } else {
        loc =
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      }
      if (mounted) {
        setState(() {
          _currentLocation = loc;
          _locationLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  // Like toggle - same as React PostCard: update post.likes array on posts table
  void _onLikePost(FeedPost post) async {
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like posts')),
        );
      }
      return;
    }
    final desired = !post.isLiked;
    final optimisticLikes =
        desired ? post.likes + 1 : (post.likes > 0 ? post.likes - 1 : 0);
    final store = StoreProvider.of<AppState>(context);
    store.dispatch(UpdatePostLiked(post.id, desired));
    if (mounted)
      setState(() {}); // trigger rebuild to reflect optimistic change
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
          const SnackBar(content: Text('Please log in to save posts')),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted')),
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
                    post.isTweet ? 'Delete Tweet' : 'Delete Post',
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
                                                  : 'Deleting post...',
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
                                                  ? 'Delete Tweet?'
                                                  : 'Delete Post?',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Are you sure you want to delete this ${post.isTweet ? 'tweet' : 'post'}? This action cannot be undone.',
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

  Widget _buildLocationSelector({required bool isDark}) {
    return InkWell(
      onTap: () {
        _fetchCurrentLocation();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
          border: Border(
            bottom: BorderSide(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200),
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
                      text: _currentLocation == null
                          ? (_locationLoading
                              ? 'home_dashboard_detecting_location'.tr()
                              : 'home_dashboard_tap_to_detect_location'.tr())
                          : _currentLocation!,
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
    await Future.wait([_loadData(store), _loadInitialFeed(forceNetwork: true)]);
  }

  // Silent background refresh after story/route pop — preserve scroll
  Future<void> _onSilentRefresh() async {
    final store = StoreProvider.of<AppState>(context);
    await Future.wait([_loadData(store), _loadInitialFeed(forceNetwork: true)]);
  }

  Future<void> _openStoryCamera() async {
    await Navigator.of(context).pushNamed('/story-camera');
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
          } catch (_) {}
        }());
      }
      // Pause any in-feed video audio while switching away from Home.
      if (wasOnHome) {
        _activeFeedPostId = null;
        _activeFeedPostIdListenable.value = null;
        unawaited(VideoPool.instance.pauseActive());
      }
      setState(() {
        _currentIndex = idx;
      });
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
                title: Text(_isVendor ? 'home_dashboard_create_ads'.tr() : 'home_dashboard_create_post'.tr()),
                subtitle: Text(
                  _isVendor ? 'Upload ad campaign' : 'Photo or video',
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
                  title: const Text('Upload Reel'),
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
        title: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              DesignTokens.instaPurple,
              DesignTokens.instaPink,
              DesignTokens.instaOrange
            ],
          ).createShader(bounds),
          child: Text('b_smart',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  fontFamily: 'cursive')),
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
                  GestureDetector(
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
                  const SizedBox(width: 4),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/notifications'),
                          icon: Icon(LucideIcons.heart,
                              size: 24, color: appBarFg)),
                      Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: DesignTokens.instaPink,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: isDark
                                          ? const Color(0xFFE8E8E8)
                                          : Colors.white,
                                      width: 1.5)))),
                    ],
                  ),
                  GestureDetector(
                    onTap: _openProfile,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, right: 12),
                      child: Container(
                        width: 32,
                        height: 32,
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: DesignTokens.instaGradient,
                        ),
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: isDark ? Colors.black : Colors.white,
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: isDark
                                ? const Color(0xFF3D3D3D)
                                : Colors.grey.shade200,
                            backgroundImage: _currentUserProfile != null &&
                                    _currentUserProfile!['avatar_url'] !=
                                        null &&
                                    (_currentUserProfile!['avatar_url']
                                            as String)
                                        .isNotEmpty
                                ? NetworkImage(
                                    _currentUserProfile!['avatar_url']
                                        as String)
                                : null,
                            child: _currentUserProfile == null ||
                                    _currentUserProfile!['avatar_url'] ==
                                        null ||
                                    (_currentUserProfile!['avatar_url']
                                            as String)
                                        .isEmpty
                                ? Text(
                                    _currentUserProfile != null
                                        ? ((_currentUserProfile!['username'] ??
                                                    _currentUserProfile![
                                                        'full_name'] ??
                                                    'U') as String)
                                                .isNotEmpty
                                            ? ((_currentUserProfile![
                                                        'username'] ??
                                                    _currentUserProfile![
                                                        'full_name'] ??
                                                    'U') as String)
                                                .substring(0, 1)
                                                .toUpperCase()
                                            : 'U'
                                        : 'U',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: appBarFg),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
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
                        onLocationTap: _showLocationSheet,
                      ),
                    ),
                    if (posts.isEmpty)
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
                                'No posts yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Create your first post from the + button',
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
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
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
                                          'Suggested ad',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
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
                                } catch (e, st) {
                                  itemWidget = Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        const Icon(Icons.broken_image,
                                            size: 40),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Failed to load post',
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
              if (isLoading)
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
                  )
                : const SizedBox.shrink()),
      );
    }

    final content = Stack(
      children: [
        ScrollConfiguration(
          behavior: const _NoGlowScrollBehavior(),
          child: PageView.builder(
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
                                title: 'Mike liked your post',
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
                : Icon(
                    LucideIcons.badgeDollarSign,
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
                  'Suggested ads',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isLoading
                      ? 'Loading suggestions…'
                      : 'No ad suggestions right now.',
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
                  'Suggested reels',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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
