import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'dart:async';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/reels_service.dart';
import '../models/reel_model.dart';
import '../services/supabase_service.dart';
import '../widgets/profile_header.dart';
import '../widgets/safe_network_image.dart';
import '../widgets/posts_grid.dart';
import '../widgets/post_detail_modal.dart';
import '../models/feed_post_model.dart';
import '../models/ad_model.dart';
import 'ad_detail_screen.dart';
import '../theme/design_tokens.dart';
import '../state/app_state.dart';
import '../state/profile_actions.dart';
import '../state/feed_actions.dart';
import '../state/store.dart';
import '../utils/current_user.dart';
import '../utils/value_parsers.dart';
import '../services/user_account_service.dart';
import '../services/wallet_service.dart';
import '../api/auth_api.dart';
import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../api/chat_api.dart';
import '../api/notification_preferences_api.dart';
import '../api/privacy_api.dart';
import '../api/follow_requests_api.dart';
import '../config/api_config.dart';
import '../services/feed_service.dart';
import '../services/auth/auth_service.dart';
import '../models/story_model.dart';
import 'story_viewer_screen.dart';
import '../api/stories_api.dart';
import '../models/media_model.dart';
import 'create_upload_screen.dart';
import 'chat_conversation_screen.dart';
import 'messaging_screen.dart';
import '../utils/url_helper.dart';
import '../widgets/profile_highlights_row.dart';
import '../services/ads_service.dart';
import 'follow_list_screen.dart';
import '../api/users_api.dart';
import '../api/follows_api.dart';
import '../api/promote_reels_api.dart';
import '../widgets/ad_interests_sheet.dart';
import '../widgets/suggestion_follow.dart';
import '../widgets/post_card.dart';
import 'promote_screen.dart';

/// Heroicons badge-check (same as React web app verified badge)
const String _verifiedBadgeSvg = r'''
<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M8.603 3.799A4.49 4.49 0 0112 2.25c1.357 0 2.573.6 3.397 1.549a4.49 4.49 0 013.498 1.307 4.491 4.491 0 011.307 3.497A4.49 4.49 0 0121.75 12a4.49 4.49 0 01-1.549 3.397 4.491 4.491 0 01-1.307 3.498 4.491 4.491 0 01-3.497 1.307A4.49 4.49 0 0112 21.75a4.49 4.49 0 01-3.397-1.549 4.49 4.49 0 01-3.498-1.306 4.491 4.491 0 01-1.307-3.498A4.49 4.49 0 012.25 12c0-1.357.6-2.573 1.549-3.397a4.49 4.49 0 011.307-3.497 4.49 4.49 0 013.497-1.307zm7.007 6.387a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z"/>
</svg>
''';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseService _svc = SupabaseService();
  final AdsService _adsService = AdsService();
  final UsersApi _usersApi = UsersApi();
  final FollowsApi _followsApi = FollowsApi();
  final FollowRequestsApi _followRequestsApi = FollowRequestsApi();
  final PromoteReelsApi _promoteReelsApi = PromoteReelsApi();
  Map<String, dynamic>? _profile;
  List<FeedPost> _posts = [];
  List<FeedPost> _saved = [];
  List<FeedPost> _tagged = [];
  List<FeedPost> _tweets = [];
  List<FeedPost> _promotes = [];
  List<Ad> _vendorAds = [];
  bool _loading = true;
  bool _usedCache = false;
  bool _hasError = false;
  bool _followLoading = false;
  bool _followRequested = false;
  final ReelsService _reelsService = ReelsService();
  final StoriesApi _storiesApi = StoriesApi();
  List<Reel> _userReels = [];
  static const int _initialPostsLimit = 20;
  final FeedService _feedService = FeedService();
  bool _hasStory = false;
  Map<String, String>? _reelImageHeaders;
  Map<String, String>? _adsMediaHeaders;
  bool _isOwnProfile = false;
  bool _isFavoriteProfile = false;
  bool _profileBlocked = false;
  bool _storiesBlocked = false;
  bool _postsRestricted = false;
  bool _pulseRestricted = false;
  Map<String, dynamic>? _privateProfilePreview;
  final Set<String> _selectedFavoriteBanners = <String>{};

  static const List<String> _favoriteBanners = <String>[
    'assets/banners/1.png',
    'assets/banners/2.png',
    'assets/banners/3.png',
    'assets/banners/4.png',
    'assets/banners/5.png',
    'assets/banners/6.png',
    'assets/banners/7.png',
    'assets/banners/8.png',
    'assets/banners/9.png',
    'assets/banners/10.png',
    'assets/banners/11.png',
    'assets/banners/12.png',
    'assets/banners/13.png',
    'assets/banners/14.png',
    'assets/banners/15.png',
    'assets/banners/16.png',
    'assets/banners/17.png',
    'assets/banners/18.png',
    'assets/banners/19.png',
  ];

  // Keep this list/order in sync with React web app `AD_CATEGORIES_FALLBACK`.
  static const List<String> _adCategoriesFallback = <String>[
    'Accessories',
    'Action Figures',
    'Art Supplies',
    'Baby Products',
    'Beauty & Personal Care',
    'Books',
    'Clothing & Apparel',
    'Electronics',
    'Food & Beverages',
    'Footwear',
    'Gaming',
    'Health & Wellness',
    'Home & Kitchen',
    'Jewellery',
    'Mobile & Tablets',
    'Pet Supplies',
    'Sports & Fitness',
    'Toys',
    'Travel',
  ];
  bool _avatarUploading = false;
  StreamSubscription<AppState>? _storeSub;
  bool _showFollowSuggestions = false;
  bool _followSuggestionsLoading = false;
  List<SuggestionUser> _followSuggestions = const <SuggestionUser>[];
  final Set<String> _dismissedFollowSuggestionUserIds = <String>{};
  final Set<String> _followSuggestionOpsInFlight = <String>{};
  Map<String, dynamic>? _vendorInfo;
  bool _tweetsLoading = false;
  String _tweetsLoadedForUserId = '';
  bool _tabListenerAttached = false;
  bool _interestsLoading = false;
  String _interestsLoadedForUserId = '';
  List<String> _adInterests = const <String>[];
  List<String> _availableInterestCategories = const <String>[];

  @override
  void initState() {
    super.initState();
    ApiClient().getToken().then((token) {
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        setState(() {
          _reelImageHeaders = {'Authorization': 'Bearer $token'};
          _adsMediaHeaders = {'Authorization': 'Bearer $token'};
        });
      }
    });
    _storeSub = globalStore.onChange.listen((_) {
      if (!mounted) return;
      _syncLocalListsWithFeedState();
    });
    _load();
  }

  void _applyBannersForInterests(List<String> interests) {
    final cleaned =
        interests.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final indexByName = <String, int>{};
    for (var i = 0; i < _adCategoriesFallback.length; i++) {
      indexByName[_adCategoriesFallback[i].toLowerCase()] = i;
    }

    final next = <String>{};
    for (final raw in cleaned) {
      final idx = indexByName[raw.toLowerCase()];
      if (idx == null) continue;
      if (idx < 0 || idx >= _favoriteBanners.length) continue;
      next.add(_favoriteBanners[idx]);
    }
    setState(() {
      _selectedFavoriteBanners
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _openInterestsSelector({
    required String profileUserId,
    required bool isMe,
  }) async {
    if (profileUserId.trim().isEmpty) return;
    await AdInterestsSheet.show(
      context,
      userId: profileUserId,
      initialInterests: _adInterests,
      editable: isMe,
      onSaved: isMe
          ? (next) {
              if (!mounted) return;
              setState(() {
                _adInterests = next;
                _isFavoriteProfile = true;
              });
              _applyBannersForInterests(next);
            }
          : null,
    );
    unawaited(_loadAdInterests(profileUserId, force: true));
  }

  @override
  void dispose() {
    _storeSub?.cancel();
    super.dispose();
  }

  String _absoluteReelUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin =
        '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }

  bool _isPrivacyBlockedError(Object error) {
    return error is ForbiddenException &&
        error.body?['privacy_blocked'] == true;
  }

  bool _isPrivateAccount(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final raw = profile['is_private'] ??
        profile['isPrivate'] ??
        profile['private'] ??
        profile['private_account'] ??
        profile['isPrivateAccount'];
    return _parseBoolLike(raw) ?? false;
  }

  bool _isFollowRequested(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final rawStatus = (profile['requestStatus'] ??
            profile['request_status'] ??
            profile['followRequestStatus'] ??
            profile['follow_request_status'] ??
            profile['status'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (rawStatus == 'pending' || rawStatus == 'requested') return true;
    final rawBool = profile['is_requested'] ??
        profile['requested'] ??
        profile['follow_request_pending'] ??
        profile['followRequestPending'];
    return _parseBoolLike(rawBool) ?? false;
  }

  bool _isFollowingViewer(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    final direct = profile['is_followed_by_me'] ??
        profile['isFollowing'] ??
        profile['is_following'];
    return privacyBoolOf(direct, defaultValue: false);
  }

  bool _canMessageProfile(Map<String, dynamic>? profile) {
    if (profile == null) return false;
    if (_isOwnProfile) return true;
    return privacyCanReceiveMessagesFrom(
      profile,
      isFollowing: _isFollowingViewer(profile),
    );
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'yes' || v == 'y';
    }
    return false;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  Map<String, bool> _parsePrivacyRestricted(dynamic value) {
    final map = _asMap(value);
    return <String, bool>{
      'posts': _parseBool(map?['posts']),
      'pulse': _parseBool(map?['pulse']),
    };
  }

  Map<String, dynamic> _privateProfileFallback(
    Map<String, dynamic>? body,
    String targetId,
  ) {
    final user = _asMap(body?['user']) ??
        _asMap(body?['profile']) ??
        _asMap(body?['data']) ??
        <String, dynamic>{};
    return <String, dynamic>{
      'id': user['_id'] ?? user['id'] ?? targetId,
      'username': user['username'] ?? 'user',
      'full_name': user['full_name'] ?? user['fullName'] ?? '',
      'avatar_url': user['avatar_url'] ?? user['avatarUrl'] ?? '',
      'is_private': true,
      'privacy_blocked': true,
    };
  }

  Future<void> _shareProfile(Map<String, dynamic>? profile) async {
    if (profile == null) return;
    final userId = (profile['id'] ?? profile['_id'])?.toString().trim();
    final username = (profile['username'] as String?)?.trim() ?? 'user';
    final url = _buildProfileShareUrl(userId, username);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile link copied')),
    );
  }

  String _buildProfileShareUrl(String? userId, String username) {
    final safeId = userId != null && userId.isNotEmpty ? userId : username;
    try {
      final apiUri = Uri.parse(ApiConfig.baseUrl);
      final scheme = apiUri.scheme.isEmpty ? 'https' : apiUri.scheme;
      final apiHost = apiUri.host;
      final appHost = apiHost.startsWith('api.')
          ? 'app.${apiHost.substring(4)}'
          : 'app.bebsmart.online';
      return '$scheme://$appHost/profile/$safeId';
    } catch (_) {
      return 'https://app.bebsmart.online/profile/$safeId';
    }
  }

  bool? _parseBoolLike(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1' || v == 'yes') return true;
      if (v == 'false' || v == '0' || v == 'no') return false;
    }
    return null;
  }

  String _suggestionIdOf(Map<String, dynamic> u) {
    final raw = u['_id'] ?? u['id'] ?? u['userId'] ?? u['user_id'];
    return raw == null ? '' : raw.toString().trim();
  }

  String _suggestionTitleOf(Map<String, dynamic> u) {
    final rawUsername = u['username'] ?? u['userName'];
    final username = rawUsername == null ? '' : rawUsername.toString().trim();
    if (username.isNotEmpty) return username;
    final name =
        (u['full_name'] ?? u['name'] ?? u['fullName'])?.toString() ?? '';
    return name.trim().isNotEmpty ? name.trim() : 'user';
  }

  String _suggestionNameOf(Map<String, dynamic> u) {
    final raw = u['full_name'] ??
        u['fullName'] ??
        u['display_name'] ??
        u['displayName'] ??
        u['name'];
    return raw == null ? '' : raw.toString().trim();
  }

  String _suggestionAvatarOf(Map<String, dynamic> u) {
    final raw = u['avatar_url'] ??
        u['avatarUrl'] ??
        u['profile_picture'] ??
        u['profile_pic'] ??
        u['profilePic'] ??
        u['profilePicture'] ??
        u['avatar'];
    return raw == null ? '' : raw.toString().trim();
  }

  bool _suggestionIsFollowingOf(Map<String, dynamic> u) =>
      _parseBoolLike(u['isFollowing']) ??
      _parseBoolLike(u['is_followed_by_me']) ??
      false;

  void _toggleFollowSuggestions() {
    final next = !_showFollowSuggestions;
    setState(() => _showFollowSuggestions = next);
    if (next && _followSuggestions.isEmpty) {
      unawaited(_loadFollowSuggestions());
    }
  }

  Future<void> _loadFollowSuggestions({bool force = false}) async {
    if (_followSuggestionsLoading) return;
    if (!force && _followSuggestions.isNotEmpty) return;
    setState(() => _followSuggestionsLoading = true);
    try {
      final meId = await CurrentUser.id;
      final users = await _usersApi.search('');
      final list = users
          .map((e) => Map<String, dynamic>.from(e))
          .where((u) => _suggestionIdOf(u).isNotEmpty)
          .where(privacyAppearsInSuggestions)
          .toList();
      list.shuffle();
      if (list.length > 80) {
        list.removeRange(80, list.length);
      }

      final ids = list.map(_suggestionIdOf).where((e) => e.isNotEmpty).toList();
      if (ids.isNotEmpty && meId != null && meId.isNotEmpty) {
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
        final id = _suggestionIdOf(u);
        if (id.isEmpty) continue;
        if (meId != null && meId.isNotEmpty && id == meId) continue;
        if (_suggestionIsFollowingOf(u)) continue;
        final avatar = _suggestionAvatarOf(u);
        final username = _suggestionTitleOf(u);
        final name = _suggestionNameOf(u);
        parsed.add(
          SuggestionUser(
            id: id,
            title: username,
            subtitle: (name.isNotEmpty && name != username) ? name : null,
            avatarUrl: avatar.isEmpty ? null : UrlHelper.absoluteUrl(avatar),
          ),
        );
      }

      if (!mounted) return;
      setState(() => _followSuggestions = parsed);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _followSuggestionsLoading = false);
      } else {
        _followSuggestionsLoading = false;
      }
    }
  }

  void _dismissFollowSuggestionUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    setState(() => _dismissedFollowSuggestionUserIds.add(id));
  }

  Future<void> _followSuggestionUser(SuggestionUser user) async {
    if (_followSuggestionOpsInFlight.contains(user.id)) return;
    _followSuggestionOpsInFlight.add(user.id);
    _dismissFollowSuggestionUser(user.id);
    final ok = await _svc.followUser(user.id);
    if (!ok && mounted) {
      setState(() => _dismissedFollowSuggestionUserIds.remove(user.id));
    }
    _followSuggestionOpsInFlight.remove(user.id);
  }

  Widget _buildFollowSuggestionsBlock(BuildContext context) {
    if (!_isOwnProfile) return const SizedBox.shrink();
    if (!_showFollowSuggestions) return const SizedBox.shrink();
    final isLoading = _followSuggestionsLoading || _followSuggestions.isEmpty;
    final visible = _followSuggestions
        .where((u) => !_dismissedFollowSuggestionUserIds.contains(u.id))
        .take(14)
        .toList();

    final section = SuggestionFollowSection(
      title: '',
      helperText: null,
      users: isLoading ? const <SuggestionUser>[] : visible,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: SuggestionFollowBlock(
        sections: [section],
        isLoading: isLoading,
        imageHeaders: _reelImageHeaders,
        onDismissUser: _dismissFollowSuggestionUser,
        onUserTap: (id) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
          );
        },
        onFollow: _followSuggestionUser,
      ),
    );
  }

  Widget _buildFavoriteCategoryStrip(
    BuildContext context, {
    required String profileUserId,
    required bool isMe,
  }) {
    if (!_isFavoriteProfile) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    const bannerAspect = 625 / 313; // Source banners are 625x313 (~2:1)
    final borderColor = theme.dividerColor.withValues(alpha: 0.35);
    final tileBorderColor = theme.dividerColor.withValues(alpha: 0.35);

    final banners = _selectedFavoriteBanners.toList();
    final showEditAction = isMe && profileUserId.isNotEmpty;
    if (banners.isEmpty && !showEditAction) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            top: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
            left: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Text(
                'Interests',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (banners.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showEditAction
                          ? 'Tap + to choose interests.'
                          : 'No interests yet.',
                      style: TextStyle(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (showEditAction) ...[
                      const SizedBox(height: 8),
                      IconButton(
                        onPressed: () => _openInterestsSelector(
                          profileUserId: profileUserId,
                          isMe: true,
                        ),
                        icon: const Icon(LucideIcons.plus),
                        tooltip: 'Add interests',
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              )
            else
              SizedBox(
                height: 56,
                width: double.infinity,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: banners.length + (showEditAction ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (showEditAction && index == banners.length) {
                      return InkWell(
                        onTap: () => _openInterestsSelector(
                          profileUserId: profileUserId,
                          isMe: true,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: tileBorderColor,
                              width: 1,
                            ),
                            color: theme.scaffoldBackgroundColor,
                          ),
                          child: const Icon(LucideIcons.plus),
                        ),
                      );
                    }

                    final asset = banners[index];
                    final w = 56 * bannerAspect;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: w,
                        height: 56,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: tileBorderColor, width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.asset(
                                asset,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyGridPlaceholder(
    BuildContext context, {
    required bool isReels,
    required bool isOwnProfile,
    IconData? emptyIcon,
    String? emptyTitle,
    VoidCallback? onCreatePressed,
    String createButtonLabel = 'Create now',
    bool showCreateButton = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = isDark
        ? Colors.white.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.22);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.black.withValues(alpha: 0.18);
    final titleColor = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.88);

    return ColoredBox(
      // React parity: the empty state is a full-width strip inside the grid area.
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2),
              ),
              child: Center(
                child: Icon(
                  emptyIcon ??
                      (isReels ? LucideIcons.video : LucideIcons.layoutGrid),
                  size: 30,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              emptyTitle ?? (isReels ? 'No Reels Yet' : 'No Posts Yet'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            if (showCreateButton &&
                isOwnProfile &&
                (onCreatePressed != null || !isReels)) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onCreatePressed ??
                    () => _openCreateUpload(mode: UploadMode.post),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: Text(createButtonLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openMessaging() {
    final participantId = widget.userId?.trim();
    if (participantId == null || participantId.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MessagingScreen()),
      );
      return;
    }

    unawaited(() async {
      try {
        bool toBool(dynamic v) {
          if (v is bool) return v;
          if (v is num) return v != 0;
          final s = v?.toString().trim().toLowerCase() ?? '';
          return s == 'true' || s == '1' || s == 'yes' || s == 'y';
        }

        final profile = _profile;
        final followingByMe = (profile?['is_followed_by_me'] as bool?) ??
            (profile?['isFollowing'] as bool?) ??
            (profile?['is_following'] as bool?) ??
            false;
        final isPrivate = toBool(
          profile?['is_private'] ??
              profile?['isPrivate'] ??
              profile?['private'] ??
              profile?['private_account'] ??
              profile?['isPrivateAccount'],
        );
        final canMessage = profile == null
            ? true
            : privacyCanReceiveMessagesFrom(
                profile,
                isFollowing: followingByMe,
              );
        if (!canMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                privacyMessagingValueOf(profile ?? const <String, dynamic>{}) ==
                        'nobody'
                    ? "This user doesn't accept direct messages."
                    : 'This user only accepts messages from followers.',
              ),
            ),
          );
          return;
        }

        final conversation = await ChatApi()
            .createOrGetConversation(participantId: participantId);
        if (!mounted) return;
        final mergedConversation = <String, dynamic>{
          ...Map<String, dynamic>.from(conversation),
          'other_is_private': isPrivate,
          'can_message': canMessage,
        };
        final id =
            (mergedConversation['_id'] ?? mergedConversation['id'])?.toString();
        if (id == null || id.isEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MessagingScreen()),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              conversationId: id,
              initialConversation: mergedConversation,
            ),
          ),
        );
      } catch (_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MessagingScreen()),
        );
      }
    }());
  }

  void _showProfileMoreActions(Map<String, dynamic>? profile) {
    if (profile == null) return;
    final username = (profile['username'] as String?)?.trim() ?? 'user';
    final targetUserId =
        (profile['id'] ?? profile['_id'])?.toString().trim() ?? '';
    final isVendorProfile =
        (profile['role'] as String?)?.toLowerCase() == 'vendor';
    final vendorId = isVendorProfile
        ? ((_vendorInfo?['_id'] ?? _vendorInfo?['id'])?.toString().trim() ?? '')
        : '';
    final canToggleNotifications = !_isOwnProfile && targetUserId.isNotEmpty;
    final prefsApi = NotificationPreferencesApi();

    bool started = false;
    bool loading = canToggleNotifications;
    bool toggling = false;
    bool? enabled;
    String? error;

    Future<void> loadStatus(StateSetter setSheetState) async {
      if (!canToggleNotifications) return;
      try {
        final v = isVendorProfile && vendorId.isNotEmpty
            ? await prefsApi.vendorStatus(vendorId)
            : await prefsApi.userStatus(targetUserId);
        enabled = v;
        error = null;
      } catch (_) {
        error = 'Could not load notification status';
      } finally {
        loading = false;
        if (mounted) setSheetState(() {});
      }
    }

    Future<void> toggle(
        BuildContext sheetCtx, StateSetter setSheetState) async {
      if (!canToggleNotifications || toggling) return;
      toggling = true;
      error = null;
      setSheetState(() {});
      try {
        final res = isVendorProfile && vendorId.isNotEmpty
            ? await prefsApi.toggleVendor(vendorId)
            : await prefsApi.toggleUser(targetUserId);
        enabled = (res['enabled'] as bool?) ?? enabled ?? false;
        final message = (res['message'] as String?)?.trim();
        if (message != null && message.isNotEmpty && mounted) {
          Navigator.of(sheetCtx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          return;
        }
      } catch (_) {
        error = 'Failed to update notification setting';
      } finally {
        toggling = false;
        if (mounted) setSheetState(() {});
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            if (!started) {
              started = true;
              unawaited(loadStatus(setSheetState));
            }

            final notifTitle = enabled == true
                ? 'Turn off notifications'
                : 'Turn on notifications';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canToggleNotifications)
                  ListTile(
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: Text(notifTitle),
                    subtitle: loading
                        ? const Text('Checking status…')
                        : (error != null ? Text(error!) : null),
                    trailing: toggling
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap:
                        loading ? null : () => toggle(sheetCtx, setSheetState),
                  ),
                ListTile(
                  leading: const Icon(Icons.report_outlined),
                  title:
                      Text(isVendorProfile ? 'Report vendor' : 'Report user'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.userX),
                  title: Text('Block @$username'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User blocked')),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLocalListsWithFeedState();
    if (_usedCache) return;
    final store = StoreProvider.of<AppState>(context);
    final cached = store.state.profileState.profile;
    if (cached == null) return;
    final cachedId = (cached['id'] ?? cached['_id'])?.toString().trim();
    final targetId = widget.userId?.trim();
    final isTargetingCachedUser =
        targetId == null || (cachedId != null && cachedId == targetId);
    if (!isTargetingCachedUser) return;
    _usedCache = true;
    setState(() {
      _profile = Map<String, dynamic>.from(cached);
      _loading = false;
    });
  }

  void _syncLocalListsWithFeedState() {
    if (!mounted) return;
    final store = StoreProvider.of<AppState>(context, listen: false);
    final feedById = <String, FeedPost>{
      for (final p in store.state.feedState.posts) p.id: p,
    };
    if (feedById.isEmpty) return;
    FeedPost syncPost(FeedPost p) {
      final fp = feedById[p.id];
      if (fp == null) return p;
      return p.copyWith(
        likes: fp.likes,
        comments: fp.comments,
        shares: fp.shares,
        views: fp.views,
        isLiked: fp.isLiked,
        isSaved: fp.isSaved,
        isFollowed: fp.isFollowed,
      );
    }

    final nextPosts = _posts.map(syncPost).toList();
    final nextTagged = _tagged.map(syncPost).toList();

    // Build saved list from all known posts so save/unsave updates appear instantly.
    final savedById = <String, FeedPost>{};
    void putIfSaved(FeedPost p) {
      if (!p.isSaved) return;
      savedById[p.id] = p;
    }

    for (final p in _saved) {
      putIfSaved(syncPost(p));
    }
    for (final p in nextPosts) {
      putIfSaved(p);
    }
    for (final p in nextTagged) {
      putIfSaved(p);
    }
    for (final p in feedById.values) {
      putIfSaved(p);
    }

    final nextSaved = savedById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final nextReels = _userReels.map((r) {
      final fp = feedById[r.id];
      if (fp == null) return r;
      return r.copyWith(
        likes: fp.likes,
        comments: fp.comments,
        shares: fp.shares,
        views: fp.views,
        isLiked: fp.isLiked,
        isSaved: fp.isSaved,
        isFollowing: fp.isFollowed,
      );
    }).toList();
    bool sameFeedPost(FeedPost a, FeedPost b) =>
        a.likes == b.likes &&
        a.comments == b.comments &&
        a.shares == b.shares &&
        a.views == b.views &&
        a.isLiked == b.isLiked &&
        a.isSaved == b.isSaved &&
        a.isFollowed == b.isFollowed;
    bool sameReel(Reel a, Reel b) =>
        a.likes == b.likes &&
        a.comments == b.comments &&
        a.shares == b.shares &&
        a.views == b.views &&
        a.isLiked == b.isLiked &&
        a.isSaved == b.isSaved &&
        a.isFollowing == b.isFollowing;
    bool unchanged = _posts.length == nextPosts.length &&
        _saved.length == nextSaved.length &&
        _tagged.length == nextTagged.length &&
        _userReels.length == nextReels.length;
    if (unchanged) {
      for (var i = 0; i < _posts.length; i++) {
        if (!sameFeedPost(_posts[i], nextPosts[i])) {
          unchanged = false;
          break;
        }
      }
    }
    if (unchanged) {
      for (var i = 0; i < _saved.length; i++) {
        if (!sameFeedPost(_saved[i], nextSaved[i])) {
          unchanged = false;
          break;
        }
      }
    }
    if (unchanged) {
      for (var i = 0; i < _tagged.length; i++) {
        if (!sameFeedPost(_tagged[i], nextTagged[i])) {
          unchanged = false;
          break;
        }
      }
    }
    if (unchanged) {
      for (var i = 0; i < _userReels.length; i++) {
        if (!sameReel(_userReels[i], nextReels[i])) {
          unchanged = false;
          break;
        }
      }
    }
    if (unchanged) return;
    setState(() {
      _posts = nextPosts;
      _saved = nextSaved;
      _tagged = nextTagged;
      _userReels = nextReels;
    });
  }

  Future<void> _load() async {
    final meId = await CurrentUser.id;
    final targetId = widget.userId ?? meId;
    final normalizedTargetId = targetId?.trim();
    final normalizedMeId = meId?.trim();
    final bool isMe = widget.userId == null ||
        (normalizedTargetId != null &&
            normalizedMeId != null &&
            normalizedTargetId == normalizedMeId);

    if (mounted && _isOwnProfile != isMe) {
      setState(() {
        _isOwnProfile = isMe;
      });
    }

    if (targetId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    final targetTrim = targetId.trim();
    if (mounted &&
        _interestsLoadedForUserId.isNotEmpty &&
        _interestsLoadedForUserId != targetTrim) {
      setState(() {
        _isFavoriteProfile = false;
        _selectedFavoriteBanners.clear();
      });
    }

    Map<String, dynamic>? profile;
    try {
      profile = isMe
          ? await AuthApi().me()
          : await _usersApi.getUserProfile(targetId);
    } on ForbiddenException catch (e) {
      if (_isPrivacyBlockedError(e)) {
        final preview = _privateProfileFallback(e.body, targetId);
        if (mounted) {
          setState(() {
            _profileBlocked = true;
            _privateProfilePreview = preview;
            _profile = preview;
            _storiesBlocked = true;
            _posts = const [];
            _saved = const [];
            _tagged = const [];
            _tweets = const [];
            _promotes = const [];
            _userReels = const [];
            _hasStory = false;
            _loading = false;
            _hasError = false;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
      return;
    }

    final postsFuture = _svc.getUserPosts(targetId, limit: _initialPostsLimit);
    final savedFuture = isMe
        ? _svc.getUserSavedPosts(targetId, limit: _initialPostsLimit)
        : Future.value(<Map<String, dynamic>>[]);
    final taggedFuture =
        _svc.getUserTaggedPosts(targetId, limit: _initialPostsLimit);
    final contentFuture = _usersApi.getUserProfileContent(targetId);
    final walletFuture = (widget.userId == null)
        ? WalletService().getCoinBalance()
        : Future.value(0);
    final userAccount = UserAccountService().getAccount(targetId);

    Map<String, dynamic>? content;
    List<Map<String, dynamic>> rawPosts = [];
    List<Map<String, dynamic>> rawSaved = [];
    List<Map<String, dynamic>> rawTagged = [];
    int walletBalance = 0;

    try {
      final results = await Future.wait([
        postsFuture,
        savedFuture,
        taggedFuture,
        contentFuture,
        walletFuture,
      ]);

      rawPosts = (results[0] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      rawSaved = (results[1] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      rawTagged = (results[2] as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      content = results[3] as Map<String, dynamic>?;
      walletBalance = results[4] as int;
    } catch (_) {
      // Keep whatever we already have cached; privacy gating still applies below.
    }

    final privacyRestricted =
        _parsePrivacyRestricted(content?['privacy_restricted']);
    final postsRestricted = privacyRestricted['posts'] == true;
    final pulseRestricted = privacyRestricted['pulse'] == true;
    if (mounted) {
      setState(() {
        _profileBlocked = false;
        _privateProfilePreview = null;
        _storiesBlocked = false;
        _postsRestricted = postsRestricted;
        _pulseRestricted = pulseRestricted;
      });
    }

    final isVendor = (profile?['role'] as String?)?.toLowerCase() == 'vendor';
    List<Ad> vendorAds = [];
    if (isVendor && targetId.isNotEmpty) {
      try {
        vendorAds = await _adsService.fetchUserAds(userId: targetId);
      } catch (_) {}
    }

    Map<String, dynamic>? vendorInfo;
    if (isVendor && targetId.isNotEmpty) {
      try {
        vendorInfo = await _svc.getVendorById(targetId);
      } catch (_) {}
    }

    List<FeedPost> promotes = const <FeedPost>[];
    if (targetId.isNotEmpty) {
      try {
        final raw = await _promoteReelsApi.listPromoteReels(page: 1, limit: 50);
        promotes = _mapPromoteReelsToFeedPosts(raw)
            .where((p) => p.userId.trim() == targetId.trim())
            .toList();
      } catch (_) {
        promotes = const <FeedPost>[];
      }
    }

    if (profile == null && _profile == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
      return;
    }

    List<FeedPost> map0(List<Map<String, dynamic>> source) {
      bool toBool(dynamic v) {
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final s = v.toLowerCase();
          return s == 'true' || s == '1';
        }
        return false;
      }

      return source.map((item) {
        final map = Map<String, dynamic>.from(item);
        final id = map['_id'] as String? ?? map['id'] as String? ?? '';
        // user_id may be a string or a populated object
        String userId = '';
        String userName = 'user';
        final uid = map['user_id'];
        if (uid is String) {
          userId = uid;
        } else if (uid is Map) {
          userId = uid['_id'] as String? ?? uid['id'] as String? ?? '';
          userName = uid['username'] as String? ?? userName;
        }
        // Fallback to joined 'users' key (Supabase style)
        final joinedUser = map['users'];
        if (joinedUser is Map) {
          userName = joinedUser['username'] as String? ?? userName;
          userId = joinedUser['id'] as String? ?? userId;
        }
        final media = (map['media'] as List<dynamic>? ??
            map['mediaUrls'] as List<dynamic>? ??
            map['media_urls'] as List<dynamic>? ??
            const <dynamic>[]);

        String _thumbFrom(dynamic raw) {
          if (raw == null) return '';
          if (raw is String) return UrlHelper.normalizeUrl(raw);
          if (raw is Map) {
            final m = Map<String, dynamic>.from(raw);
            final cand = (m['url'] ??
                    m['fileUrl'] ??
                    m['file_url'] ??
                    m['path'] ??
                    m['image'] ??
                    m['imageUrl'] ??
                    m['thumb'] ??
                    m['thumbnail'] ??
                    m['thumbnailUrl'] ??
                    m['thumbnail_url'])
                ?.toString();
            return cand == null ? '' : UrlHelper.normalizeUrl(cand);
          }
          if (raw is List) {
            for (final e in raw) {
              final v = _thumbFrom(e);
              if (v.isNotEmpty) return v;
            }
            return '';
          }
          return UrlHelper.normalizeUrl(raw.toString());
        }

        String _mediaFromMap(Map<String, dynamic> mm) {
          final cand = (mm['fileUrl'] ??
                  mm['file_url'] ??
                  mm['url'] ??
                  mm['path'] ??
                  mm['image'] ??
                  mm['imageUrl'] ??
                  mm['videoUrl'] ??
                  mm['video_url'])
              ?.toString();
          if (cand == null || cand.trim().isEmpty) return '';
          return UrlHelper.normalizeUrl(cand);
        }

        String? thumbnailUrl;
        final mediaUrls = <String>[];
        for (final m in media) {
          if (m is String) {
            final url = UrlHelper.normalizeUrl(m);
            if (url.isNotEmpty) mediaUrls.add(url);
            continue;
          }
          if (m is Map) {
            final mm = Map<String, dynamic>.from(m);
            final url = _mediaFromMap(mm);
            if (url.isNotEmpty) mediaUrls.add(url);

            if (thumbnailUrl == null || thumbnailUrl!.isEmpty) {
              final thumbField = mm['thumbnail'] ??
                  mm['thumbnailUrl'] ??
                  mm['thumbnail_url'] ??
                  mm['thumb'] ??
                  mm['thumbnails'] ??
                  mm['poster'];
              final thumb = _thumbFrom(thumbField);
              if (thumb.isNotEmpty) thumbnailUrl = thumb;
            }
          }
        }

        if (thumbnailUrl == null || thumbnailUrl!.isEmpty) {
          final postThumb = map['thumbnail'] ??
              map['thumbnailUrl'] ??
              map['thumb'] ??
              map['poster'];
          final thumb = _thumbFrom(postThumb);
          if (thumb.isNotEmpty) thumbnailUrl = thumb;
        }
        final typeStr = ((map['type'] as String?) ??
                (map['media_type'] as String?) ??
                'post')
            .toLowerCase();
        final isAdType = typeStr == 'ad' || toBool(map['is_ad']);
        final isTweetType = typeStr == 'tweet' ||
            ((map['item_type'] ?? map['itemType'] ?? '')
                    .toString()
                    .toLowerCase() ==
                'tweet') ||
            toBool(map['isTweet']) ||
            toBool(map['is_tweet']);
        bool hasVideo = false;
        for (final m in media) {
          if (m is Map) {
            final t = (m['type'] as String?)?.toLowerCase();
            if (t == 'video' || t == 'reel') {
              hasVideo = true;
              break;
            }
            final cand = (m['fileUrl'] ?? m['file_url'] ?? m['url'])
                ?.toString()
                .toLowerCase();
            if (cand != null &&
                (cand.endsWith('.mp4') ||
                    cand.endsWith('.mov') ||
                    cand.contains('.m3u8'))) {
              hasVideo = true;
              break;
            }
          } else if (m is String) {
            final s = m.toLowerCase();
            if (s.endsWith('.mp4') || s.endsWith('.mov')) {
              hasVideo = true;
              break;
            }
          }
        }
        PostMediaType mediaType = PostMediaType.image;
        if (typeStr == 'reel') {
          mediaType = PostMediaType.reel;
        } else if (hasVideo) {
          mediaType =
              mediaUrls.length == 1 ? PostMediaType.reel : PostMediaType.video;
        } else if (mediaUrls.length > 1) {
          mediaType = PostMediaType.carousel;
        }
        final caption = map['caption'] as String?;
        final hashtags = ((map['hashtags'] as List<dynamic>?) ??
                (map['tags'] as List<dynamic>?) ??
                [])
            .map((e) => e.toString())
            .toList();
        DateTime createdAt;
        final createdAtStr =
            map['created_at'] as String? ?? map['createdAt'] as String?;
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();
        } else {
          createdAt = DateTime.now();
        }
        return FeedPost(
          id: id,
          userId: userId,
          userName: userName,
          mediaType: mediaType,
          mediaUrls: mediaUrls,
          thumbnailUrl:
              (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty)
                  ? thumbnailUrl!.trim()
                  : null,
          caption: caption,
          hashtags: hashtags,
          createdAt: createdAt,
          isTagged: (map['people_tags'] as List?)?.isNotEmpty ?? false,
          peopleTags: (map['people_tags'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList(),
          likes: tryParseInt(
                map['likes_count'] ?? map['likesCount'] ?? map['likes'],
              ) ??
              ((map['likes'] is List) ? (map['likes'] as List).length : 0),
          comments: tryParseInt(
                map['comments_count'] ??
                    map['commentsCount'] ??
                    map['comments'] ??
                    map['commentCount'],
              ) ??
              ((map['comments'] is List)
                  ? (map['comments'] as List).length
                  : 0),
          isLiked: toBool(map['is_liked_by_me']) || toBool(map['liked_by_me']),
          isSaved: toBool(map['is_saved_by_me']) || toBool(map['saved_by_me']),
          isFollowed:
              toBool(map['is_followed_by_me']) || toBool(map['followed_by_me']),
          isAd: isAdType,
          isTweet: isTweetType,
          adCompanyId: map['ad_company_id']?.toString(),
          adCompanyName: map['ad_company_name']?.toString(),
        );
      }).toList();
    }

    final posts = map0(rawPosts);
    final saved = map0(rawSaved);
    final tagged = map0(rawTagged);
    final tweets =
        (_tweetsLoadedForUserId == targetId) ? _tweets : const <FeedPost>[];

    // Initialize counts from existing data to prevent resetting to 0 on API failure
    int? followersCount;
    int? followingCount;

    // 1. Try to get from current Redux state (for "Me") or local state
    if (widget.userId == null) {
      try {
        final store = StoreProvider.of<AppState>(context);
        final cached = store.state.profileState.profile;
        if (cached != null) {
          followersCount = tryReadInt(cached, const [
            'followers_count',
            'followersCount',
            'followers',
            'follower_count',
          ]);
          followingCount = tryReadInt(cached, const [
            'following_count',
            'followingCount',
            'following',
          ]);
        }
      } catch (_) {}
    }
    // 2. Fallback to local _profile
    if (followersCount == null && _profile != null) {
      followersCount = tryReadInt(_profile, const [
        'followers_count',
        'followersCount',
        'followers',
        'follower_count',
      ]);
    }
    if (followingCount == null && _profile != null) {
      followingCount = tryReadInt(_profile, const [
        'following_count',
        'followingCount',
        'following',
      ]);
    }
    // 3. Fallback to API profile response (if available)
    if (followersCount == null && profile != null) {
      followersCount = tryReadInt(profile, const [
        'followers_count',
        'followersCount',
        'followers',
        'follower_count',
      ]);
    }
    if (followingCount == null && profile != null) {
      followingCount = tryReadInt(profile, const [
        'following_count',
        'followingCount',
        'following',
      ]);
    }

    // 4. Update with fresh API data (only if successful and valid)
    // Fix: Check if API returns 0 but Redux has a non-zero value, prevent overwrite
    try {
      final count = await _svc.getFollowersCount(targetId);
      if (count > 0) {
        followersCount = count;
        // If the backend count is slightly off (duplicates/deleted accounts),
        // reconcile against the actual visible follower list for small totals.
        if (count <= 200) {
          try {
            final page = await _followsApi.getFollowersPage(
              targetId,
              page: 1,
              limit: 200,
            );
            final total = tryParseInt(page['total']) ?? 0;
            final usersRaw = page['users'];
            final users = usersRaw is List
                ? usersRaw
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
                : const <Map<String, dynamic>>[];
            if (total <= 200 || users.length < 200) {
              String idOf(Map<String, dynamic> u) {
                final v = u['_id'] ?? u['id'] ?? u['userId'] ?? u['uid'];
                return (v?.toString() ?? '').trim();
              }

              final uniqueIds =
                  users.map(idOf).where((e) => e.isNotEmpty).toSet();
              if (uniqueIds.isNotEmpty) {
                followersCount = uniqueIds.length;
              }
            }
          } catch (_) {}
        }
      } else {
        // API returned 0 (or failed silently). Check Redux state before accepting 0.
        if (widget.userId == null) {
          try {
            final store = StoreProvider.of<AppState>(context);
            final cached = store.state.profileState.profile;
            final cachedCount = tryReadInt(cached, const [
              'followers_count',
              'followersCount',
              'followers',
              'follower_count',
            ]);
            if (cachedCount != null && cachedCount > 0) {
              // Keep the cached non-zero value instead of overwriting with 0
              followersCount = cachedCount;
            } else {
              // If cache is also 0 or null, then accept 0
              followersCount = 0;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    try {
      final count = await _svc.getFollowingCount(targetId);
      if (count > 0) {
        followingCount = count;
        if (count <= 200) {
          try {
            final page = await _followsApi.getFollowingPage(
              targetId,
              page: 1,
              limit: 200,
            );
            final total = tryParseInt(page['total']) ?? 0;
            final usersRaw = page['users'];
            final users = usersRaw is List
                ? usersRaw
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList()
                : const <Map<String, dynamic>>[];
            if (total <= 200 || users.length < 200) {
              String idOf(Map<String, dynamic> u) {
                final v = u['_id'] ?? u['id'] ?? u['userId'] ?? u['uid'];
                return (v?.toString() ?? '').trim();
              }

              final uniqueIds =
                  users.map(idOf).where((e) => e.isNotEmpty).toSet();
              if (uniqueIds.isNotEmpty) {
                followingCount = uniqueIds.length;
              }
            }
          } catch (_) {}
        }
      } else {
        if (widget.userId == null) {
          try {
            final store = StoreProvider.of<AppState>(context);
            final cached = store.state.profileState.profile;
            final cachedCount = tryReadInt(cached, const [
              'following_count',
              'followingCount',
              'following',
            ]);
            if (cachedCount != null && cachedCount > 0) {
              followingCount = cachedCount;
            } else {
              followingCount = 0;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 5. Default to 0 if everything failed (and no fallback was found)
    final finalFollowers = followersCount ?? 0;
    final finalFollowing = followingCount ?? 0;

    bool isFollowedByMe = false;
    bool isFollowRequested = false;

    if (meId != null && meId.isNotEmpty) {
      // Prioritize server-provided follow status if available
      if (profile != null &&
          (profile.containsKey('is_followed_by_me') ||
              profile.containsKey('is_following'))) {
        isFollowedByMe =
            (profile['is_followed_by_me'] ?? profile['is_following']) == true;
        // Sync local cache with authoritative server state
        _svc.syncFollowStatus(targetId, isFollowedByMe);
      } else {
        try {
          isFollowedByMe = await _svc.isFollowing(meId, targetId);
        } catch (_) {}
      }
      if (!isMe && targetId.isNotEmpty) {
        try {
          final status = await _followsApi.checkFollowStatus(targetId);
          final statusFollowed = _parseBoolLike(status['is_following'] ??
                  status['isFollowing'] ??
                  status['followed'] ??
                  status['is_followed_by_me'] ??
                  status['followed_by_me']) ??
              false;
          final statusRequested = _isFollowRequested(status);
          if (statusFollowed) {
            isFollowedByMe = true;
            isFollowRequested = false;
          } else if (statusRequested) {
            isFollowedByMe = false;
            isFollowRequested = true;
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      final derivedFromPosts = posts.isNotEmpty
          ? {
              'id': targetId,
              'username': posts.first.userName,
              'full_name': posts.first.fullName,
              'avatar_url': posts.first.userAvatar,
            }
          : <String, dynamic>{};

      // Determine correct post count:
      // If we received fewer posts than the requested page limit, we know we have the complete list.
      // In that case, trust the actual list length over the potentially stale count from the server.
      int finalPostsCount = (profile?['posts_count'] as int?) ?? posts.length;
      if (posts.length < _initialPostsLimit) {
        finalPostsCount = posts.length;
      }

      final merged = {
        ...?_profile, // 1. Start with existing local state as fallback
        ...derivedFromPosts, // 2. Update with info derived from posts (if any)
        ...?profile, // 3. Override with fresh API profile data (if success)
        if (vendorInfo != null) 'vendor': vendorInfo,
        'is_followed_by_me': isFollowedByMe,
        'is_requested': isFollowRequested,
        'request_status': isFollowRequested ? 'pending' : null,
        'posts_count': finalPostsCount,
        'followers_count': finalFollowers,
        'following_count': finalFollowing,
        'wallet_balance': (profile?['wallet_balance'] as int?) ?? walletBalance,
        'account_type': userAccount?.accountType.toString().split('.').last,
        'engagement_score': userAccount?.engagementScore,
      };
      // React web app uses: profileUser.validated ?? vendorInfo.validated.
      // Fill validated from vendor object only when missing on the user profile.
      if (vendorInfo != null &&
          merged['validated'] == null &&
          vendorInfo!['validated'] != null) {
        merged['validated'] = vendorInfo!['validated'];
      }

      final reelsFromService =
          _reelsService.getReels().where((r) => r.userId == targetId).toList();
      final reelsFromPosts = posts
          .where((p) =>
              p.mediaType == PostMediaType.reel && p.mediaUrls.isNotEmpty)
          .map((p) {
        final firstUrl = p.mediaUrls.first;
        return Reel(
          id: p.id,
          userId: p.userId,
          userName: p.userName,
          userAvatarUrl: p.userAvatar,
          videoUrl: firstUrl,
          thumbnailUrl: null,
          caption: p.caption,
          hashtags: p.hashtags,
          audioTitle: null,
          audioArtist: null,
          audioId: null,
          likes: p.likes,
          comments: p.comments,
          shares: p.shares,
          views: p.views,
          isLiked: p.isLiked,
          isSaved: p.isSaved,
          isFollowing: p.isFollowed,
          createdAt: p.createdAt,
          isSponsored: p.isAd,
          sponsorBrand: p.adCompanyName,
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
          peopleTags: p.peopleTags,
        );
      }).toList();

      final combinedReels = <String, Reel>{};
      for (final r in reelsFromService) {
        combinedReels[r.id] = r;
      }
      for (final r in reelsFromPosts) {
        combinedReels[r.id] ??= r;
      }

      setState(() {
        _profile = merged;
        _followRequested = isFollowRequested;
        _posts = posts;
        _saved = saved;
        _tagged = tagged;
        _tweets = tweets;
        _promotes = promotes;
        _vendorAds = vendorAds;
        _vendorInfo = vendorInfo;
        _userReels = combinedReels.values.toList();
        _loading = false;
      });
      unawaited(_loadAdInterests(targetId, force: true));
      if (_adInterests.isNotEmpty) {
        _applyBannersForInterests(_adInterests);
      }
      _loadStoryStatus(targetId);
      // Cache own profile in Redux for instant load next time
      if (widget.userId == null) {
        // Only dispatch if we have valid data (e.g., a username or id) to prevent overwriting with empty state
        if (merged['username'] != null ||
            merged['id'] != null ||
            merged['_id'] != null) {
          StoreProvider.of<AppState>(context).dispatch(SetProfile(merged));
        }
      }
    }
  }

  Future<void> _loadAdInterests(
    String userId, {
    bool force = false,
  }) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    if (_interestsLoading) return;
    if (!force && _interestsLoadedForUserId == id) return;

    if (mounted) {
      setState(() {
        _interestsLoading = true;
        if (_interestsLoadedForUserId != id) {
          _adInterests = const <String>[];
          _availableInterestCategories = const <String>[];
        }
      });
    }

    List<String> parseStringList(dynamic raw) {
      if (raw is! List) return const <String>[];
      final out = <String>[];
      for (final v in raw) {
        final s = (v ?? '').toString().trim();
        if (s.isNotEmpty) out.add(s);
      }
      return out;
    }

    try {
      final res = await _usersApi.getAdInterests(id);
      final nextInterests = parseStringList(res['ad_interests']);
      final nextAvail = parseStringList(res['available_categories']);

      if (!mounted) return;
      setState(() {
        _adInterests = nextInterests;
        _availableInterestCategories =
            nextAvail.isNotEmpty ? nextAvail : nextInterests;
        _interestsLoadedForUserId = id;
        _interestsLoading = false;
      });
      if (_isFavoriteProfile && _interestsLoadedForUserId == id) {
        _applyBannersForInterests(_adInterests);
      }
    } catch (_) {
      final fallback = parseStringList(_profile?['ad_interests']);
      if (!mounted) return;
      setState(() {
        if (fallback.isNotEmpty) _adInterests = fallback;
        _availableInterestCategories = _availableInterestCategories.isNotEmpty
            ? _availableInterestCategories
            : _adInterests;
        _interestsLoadedForUserId = id;
        _interestsLoading = false;
      });
      if (_isFavoriteProfile && _interestsLoadedForUserId == id) {
        _applyBannersForInterests(_adInterests);
      }
    }
  }

  Future<void> _openStoriesFromProfile() async {
    if (_storiesBlocked) return;
    final profile = _profile;
    if (profile == null) return;
    final targetId =
        (profile['id'] as String?) ?? (profile['_id'] as String?) ?? '';
    if (targetId.isEmpty) return;
    try {
      final stories = await _storiesApi.userStories(targetId);
      final groups = await _feedService.fetchStoriesFeed();
      final userGroups = groups.where((g) => g.userId == targetId).toList();
      final resolvedGroups = userGroups.isNotEmpty
          ? userGroups
          : await Future.wait(
              stories.map((story) async {
                final storyId =
                    (story['_id'] ?? story['id'])?.toString().trim() ?? '';
                if (storyId.isEmpty) return null;
                final items = await _feedService.fetchStoryItems(
                  storyId,
                  ownerUserName:
                      (profile['username'] as String?)?.trim() ?? 'user',
                  ownerAvatar: profile['avatar_url'] as String?,
                );
                if (items.isEmpty) return null;
                return StoryGroup(
                  userId: targetId,
                  userName: (profile['username'] as String?)?.trim() ?? 'user',
                  userAvatar: profile['avatar_url'] as String?,
                  storyId: storyId,
                  stories: items,
                );
              }),
            ).then((value) => value.whereType<StoryGroup>().toList());
      if (resolvedGroups.isEmpty) return;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StoryViewerScreen(
            storyGroups: resolvedGroups,
            initialIndex: 0,
          ),
        ),
      );
    } on ForbiddenException catch (e) {
      if (_isPrivacyBlockedError(e) && mounted) {
        setState(() {
          _storiesBlocked = true;
          _hasStory = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _changeAvatarFromProfile() async {
    if (_avatarUploading) return;
    setState(() => _avatarUploading = true);
    final picker = ImagePicker();
    try {
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (!mounted || xfile == null) return;

      final bytes = await xfile.readAsBytes();
      if (bytes.isEmpty) {
        throw 'Selected image is empty.';
      }
      final res = await _svc.uploadAvatarBytes(bytes: bytes);
      final newUrl = _extractAvatarUrl(res);
      if (newUrl == null || newUrl.isEmpty) {
        throw 'Avatar upload succeeded but no URL was returned.';
      }
      await _refreshProfileAfterAvatarChange(newUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _avatarUploading = false);
      }
    }
  }

  void _showAvatarOptionsSheet() {
    if (_avatarUploading) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('New profile photo'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _changeAvatarFromProfile();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove profile photo'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _removeAvatarToGooglePhoto();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeAvatarToGooglePhoto() async {
    if (_avatarUploading) return;
    setState(() => _avatarUploading = true);
    try {
      final googleUrl = await _resolveGoogleAvatarUrl(_profile);
      if (googleUrl == null || googleUrl.isEmpty) {
        throw 'Google profile photo not available.';
      }
      final uid = (await CurrentUser.id) ?? '';
      if (uid.isEmpty) throw 'User not found.';
      await _svc.updateUserProfile(uid, {'avatar_url': googleUrl});
      await _refreshProfileAfterAvatarChange(googleUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remove failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<String?> _resolveGoogleAvatarUrl(Map<String, dynamic>? profile) async {
    final candidates = [
      profile?['google_avatar_url'],
      profile?['google_avatar'],
      profile?['photo_url'],
      profile?['photoUrl'],
      profile?['picture'],
      profile?['profile_picture'],
    ];
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c;
    }
    return AuthService().getGoogleProfilePhotoUrl();
  }

  String? _extractAvatarUrl(Map<String, dynamic> res) {
    dynamic url =
        res['avatar_url'] ?? res['url'] ?? res['fileUrl'] ?? res['file_url'];
    if (url is String && url.isNotEmpty) return url;
    final data = res['data'];
    if (data is Map) {
      url = data['avatar_url'] ??
          data['url'] ??
          data['fileUrl'] ??
          data['file_url'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  Future<void> _refreshProfileAfterAvatarChange(String fallbackUrl) async {
    final current = _profile;
    if (mounted) {
      setState(() {
        _profile = {
          ...?current,
          'avatar_url': fallbackUrl,
        };
      });
    }
    if (_isOwnProfile) {
      StoreProvider.of<AppState>(context).dispatch(
        SetProfile({
          ...?current,
          'avatar_url': fallbackUrl,
        }),
      );
    }

    final uid = (current?['id'] as String?) ??
        (current?['_id'] as String?) ??
        await CurrentUser.id;
    if (uid == null || uid.isEmpty) return;
    try {
      final profile = await _svc.getUserById(uid);
      if (!mounted || profile == null || profile.isEmpty) return;
      setState(() {
        _profile = profile;
      });
      if (_isOwnProfile) {
        StoreProvider.of<AppState>(context).dispatch(SetProfile(profile));
      }
    } catch (_) {}
  }

  Future<void> _loadStoryStatus(String userId) async {
    if (userId.isEmpty) return;
    try {
      final stories = await _storiesApi.userStories(userId);
      final hasStory = stories.isNotEmpty;
      if (!mounted) return;
      if (_hasStory != hasStory) {
        setState(() {
          _hasStory = hasStory;
          _storiesBlocked = false;
        });
      }
    } on ForbiddenException catch (e) {
      if (_isPrivacyBlockedError(e)) {
        if (!mounted) return;
        setState(() {
          _storiesBlocked = true;
          _hasStory = false;
        });
        return;
      }
      if (!mounted) return;
      if (_hasStory) {
        setState(() {
          _hasStory = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (_hasStory) {
        setState(() {
          _hasStory = false;
        });
      }
    }
  }

  void _onEdit() async {
    final targetId = widget.userId ?? await CurrentUser.id;
    if (!mounted || targetId == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) {
      return EditProfileScreen(userId: targetId);
    })).then((_) => _load());
  }

  void _onFollow() async {
    if (_followLoading) return;
    final meId = await CurrentUser.id;
    final targetId = widget.userId;
    if (meId == null || targetId == null) return;
    final currentProfile = _profile;
    final currentFollowing = (currentProfile?['is_followed_by_me'] as bool?) ??
        (currentProfile?['isFollowing'] as bool?) ??
        false;
    final currentRequested = _isFollowRequested(currentProfile);
    final isPrivate = _isPrivateAccount(currentProfile);
    if (currentRequested && !currentFollowing) {
      _followLoading = true;
      if (mounted) {
        setState(() {
          _followRequested = true;
        });
      }
      bool cancelled = false;
      try {
        await _followRequestsApi.cancelFollowRequest(targetId);
        cancelled = true;
      } catch (_) {
        cancelled = false;
      }
      if (mounted) {
        setState(() {
          _followRequested = !cancelled;
          _profile = {
            ...?_profile,
            'is_followed_by_me': false,
            'is_requested': !cancelled,
            'request_status': !cancelled ? 'pending' : null,
          };
        });
      }
      if (cancelled && mounted) {
        final store = StoreProvider.of<AppState>(context);
        store.dispatch(UpdateUserFollowed(targetId, false));
      }
      _followLoading = false;
      return;
    }
    _followLoading = true;
    final next = !currentFollowing;
    int followersCount = tryReadInt(_profile, const [
          'followers_count',
          'followersCount',
          'followers',
          'follower_count',
        ]) ??
        0;
    final delta = next ? 1 : -1;

    if (mounted) {
      setState(() {
        _followRequested = currentRequested;
        _profile = {
          ...?_profile,
          'is_followed_by_me': currentFollowing,
          'is_requested': currentRequested,
          'request_status': currentRequested ? 'pending' : null,
          'followers_count': followersCount,
        };
      });
    }

    Map<String, dynamic>? response;
    bool success = false;
    if (next) {
      try {
        response = await _followsApi.follow(targetId);
        success = true;
      } catch (_) {
        try {
          response = await _followsApi.followById(targetId);
          success = true;
        } catch (_) {
          success = false;
        }
      }
    } else {
      try {
        response = await _followsApi.unfollow(targetId);
        success = true;
      } catch (_) {
        success = false;
      }
    }

    bool? responseFollowed;
    bool responseRequested = false;
    if (response != null) {
      responseFollowed = _parseBoolLike(
        response['followed'] ??
            response['is_following'] ??
            response['isFollowing'] ??
            response['is_followed_by_me'] ??
            response['followed_by_me'],
      );
      final rawRequestStatus = (response['requestStatus'] ??
              response['request_status'] ??
              response['followRequestStatus'] ??
              response['follow_request_status'] ??
              response['status'])
          ?.toString()
          .trim()
          .toLowerCase();
      responseRequested = rawRequestStatus == 'pending' ||
          rawRequestStatus == 'requested' ||
          _parseBoolLike(response['is_requested'] ??
                  response['requested'] ??
                  response['follow_request_pending']) ==
              true;
    }

    bool nextFollowed = false;
    bool nextRequested = false;
    if (success) {
      nextFollowed = next
          ? (responseFollowed ??
              (!isPrivate && responseRequested == false ? true : false))
          : false;
      nextRequested = next && !nextFollowed && (responseRequested || isPrivate);
      final nextFollowers = nextRequested
          ? followersCount
          : (next
              ? followersCount + 1
              : (followersCount - 1 < 0 ? 0 : followersCount - 1));
      if (mounted) {
        if (nextRequested) {
          setState(() {
            _followRequested = true;
            _profile = {
              ...?_profile,
              'is_followed_by_me': false,
              'is_requested': true,
              'request_status': 'pending',
              'followers_count': followersCount,
            };
          });
        } else {
          // Update global "My Profile" state for following count
          final store = StoreProvider.of<AppState>(context);
          store.dispatch(AdjustFollowingCount(delta));
          setState(() {
            _followRequested = false;
            _profile = {
              ...?_profile,
              'is_followed_by_me': nextFollowed,
              'is_requested': false,
              'request_status': null,
              'followers_count': nextFollowers,
            };
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _followRequested = currentRequested;
          _profile = {
            ...?_profile,
            'is_followed_by_me': currentFollowing,
            'is_requested': currentRequested,
            'request_status': currentRequested ? 'pending' : null,
            'followers_count': followersCount,
          };
        });
      }
    }

    if (success && mounted && !nextRequested) {
      final store = StoreProvider.of<AppState>(context);
      store.dispatch(UpdateUserFollowed(targetId, nextFollowed));
      try {
        final serverFollowers = await _svc.getFollowersCount(targetId);
        if (mounted) {
          setState(() {
            _profile = {
              ...?_profile,
              'followers_count': serverFollowers,
            };
          });
        }
      } catch (_) {}
      // Snackbar notification removed for a cleaner experience
    }

    if (mounted) {
      setState(() {
        _followLoading = false;
      });
    } else {
      _followLoading = false;
    }
  }

  void _onPostTap(FeedPost p) {
    _showPostDetail(p.id, isTweet: p.isTweet);
  }

  void _showPostDetail(String postId, {bool isTweet = false}) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      final suffix = isTweet ? '?type=tweet' : '';
      Navigator.of(context).pushNamed('/post/$postId$suffix').then((_) {
        if (mounted) _load();
      });
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: PostDetailModal(
            postId: postId,
            isTweet: isTweet,
            onClose: () {
              Navigator.of(ctx).pop();
            },
          ),
        ),
      ).then((_) {
        if (mounted) _load();
      });
    }
  }

  List<FeedPost> _mapPromoteReelsToFeedPosts(dynamic raw) {
    List<dynamic> items = const [];
    if (raw is List) {
      items = raw;
    } else if (raw is Map) {
      final data = raw['data'];
      if (data is List) items = data;
    }
    if (items.isEmpty) return const <FeedPost>[];

    String str(dynamic v) => (v ?? '').toString().trim();

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(str(v)) ?? 0;
    }

    bool toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = str(v).toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    DateTime parseDate(dynamic v) {
      final dt = DateTime.tryParse(str(v));
      return dt ?? DateTime.now();
    }

    String? pickMediaUrl(Map<String, dynamic> item) {
      final media = item['media'];
      if (media is! List || media.isEmpty) return null;
      final first = media.first;
      if (first is String) return first;
      if (first is Map) {
        final m = Map<String, dynamic>.from(first);
        return (m['fileUrl'] ?? m['file_url'] ?? m['url'] ?? m['link'])
            ?.toString();
      }
      return null;
    }

    String? pickThumbnailUrl(Map<String, dynamic> item) {
      final media = item['media'];
      if (media is! List || media.isEmpty) return null;
      final first = media.first;
      if (first is! Map) return null;
      final m = Map<String, dynamic>.from(first);
      dynamic rawThumb = m['thumbnails'] ??
          m['thumbnail'] ??
          m['thumbnailUrl'] ??
          m['thumbnail_url'] ??
          m['thumb'];
      if (rawThumb is List && rawThumb.isNotEmpty) rawThumb = rawThumb.first;
      if (rawThumb is String) return rawThumb;
      if (rawThumb is Map) {
        final t = Map<String, dynamic>.from(rawThumb);
        return (t['fileUrl'] ?? t['file_url'] ?? t['url'] ?? t['path'])
            ?.toString();
      }
      return null;
    }

    final out = <FeedPost>[];
    for (final e in items) {
      if (e is! Map) continue;
      final item = Map<String, dynamic>.from(e);
      final id = str(item['_id'] ?? item['id'] ?? item['promote_reel_id']);
      if (id.isEmpty) continue;
      final user = item['user_id'] is Map
          ? Map<String, dynamic>.from(item['user_id'] as Map)
          : <String, dynamic>{};
      final userId = str(user['_id'] ?? user['id'] ?? item['user_id']);
      final userName = str(user['username'] ?? user['full_name'] ?? 'User');
      final avatar = UrlHelper.normalizeUrl(
        user['avatar_url'] ??
            user['profile_picture'] ??
            user['profilePicture'] ??
            user['profile_pic'] ??
            user['avatarUrl'],
      );

      final mediaUrl = UrlHelper.normalizeUrl(pickMediaUrl(item));
      if (mediaUrl.isEmpty) continue;
      final thumb = UrlHelper.normalizeUrl(pickThumbnailUrl(item) ?? '');

      out.add(
        FeedPost(
          id: 'promote-$id',
          userId: userId,
          userName: userName.isEmpty ? 'User' : userName,
          userAvatar: avatar.isEmpty ? null : avatar,
          mediaType: PostMediaType.reel,
          mediaUrls: [mediaUrl],
          thumbnailUrl: thumb.isEmpty ? null : thumb,
          caption: (item['caption'] ?? '').toString(),
          hashtags: ((item['tags'] as List?) ?? const [])
              .map((t) => t.toString())
              .toList(),
          createdAt: parseDate(item['created_at'] ?? item['createdAt']),
          likes: toInt(item['likes_count'] ?? item['likesCount']),
          comments: toInt(item['comments_count'] ?? item['commentsCount']),
          shares: 0,
          views: 0,
          isLiked: toBool(item['is_liked_by_me']),
          isSaved: toBool(item['is_saved_by_me']),
          isFollowed: toBool(item['is_followed_by_me']),
          isAd: false,
        ),
      );
    }
    return out;
  }

  Widget _buildReelsGrid({required bool isMe}) {
    if (_userReels.isEmpty) {
      return _emptyGridPlaceholder(
        context,
        isReels: true,
        isOwnProfile: isMe,
        emptyIcon: LucideIcons.video,
        emptyTitle: 'No Reels Yet',
        createButtonLabel: 'Create new reel',
        onCreatePressed: () => _openCreateUpload(mode: UploadMode.reel),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _userReels.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
      ),
      itemBuilder: (ctx, i) {
        final r = _userReels[i];
        final thumbRaw = r.thumbnailUrl?.trim();
        final thumb = (thumbRaw != null && thumbRaw.isNotEmpty)
            ? _absoluteReelUrl(thumbRaw)
            : null;
        return GestureDetector(
          onTap: () => Navigator.of(context).pushNamed(
            '/reels',
            arguments: <String, dynamic>{'initialReelId': r.id},
          ),
          child: Transform.scale(
            scale: 1.01,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black),
                if (thumb != null)
                  SafeNetworkImage(
                    url: thumb,
                    headers: _reelImageHeaders,
                    cacheKey:
                        '$thumb#${_reelImageHeaders?['Authorization'] ?? ''}',
                    fit: BoxFit.cover,
                    placeholder: Container(color: Colors.grey[900]),
                    errorWidget: Container(color: Colors.grey[900]),
                  ),
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    LucideIcons.video,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTweetsList(List<FeedPost> tweets, {required bool isMe}) {
    if (tweets.isEmpty) {
      if (_tweetsLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: CircularProgressIndicator(color: DesignTokens.instaPink),
          ),
        );
      }
      return _emptyGridPlaceholder(
        context,
        isReels: false,
        isOwnProfile: isMe,
        emptyIcon: LucideIcons.messageCircle,
        emptyTitle: 'No Tweets Yet',
        createButtonLabel: 'Create new tweet',
        onCreatePressed: () => Navigator.of(context).pushNamed('/tweet'),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tweets.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(context).dividerColor.withValues(alpha: 0.7),
      ),
      itemBuilder: (context, index) {
        final p = tweets[index];
        return PostCard(
          post: p,
          isOwnPost: isMe,
          onComment: () => _showPostDetail(p.id, isTweet: true),
          onUserTap: () {
            final id = p.userId.trim();
            if (id.isEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(userId: id)),
            );
          },
        );
      },
    );
  }

  Future<void> _ensureTweetsLoadedForUser(String userId) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    if (_tweetsLoading) return;
    if (_tweetsLoadedForUserId == id) return;

    setState(() {
      _tweetsLoading = true;
    });

    try {
      final meId = await CurrentUser.id;
      final feed = await _feedService.fetchFeedFromBackend(
        limit: 150,
        offset: 0,
        currentUserId: meId,
        swallowErrors: true,
      );
      final tweets =
          feed.where((p) => p.isTweet && p.userId.trim() == id).toList();
      if (!mounted) return;
      setState(() {
        _tweets = tweets;
        _tweetsLoadedForUserId = id;
        _tweetsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tweets = const <FeedPost>[];
        _tweetsLoadedForUserId = id;
        _tweetsLoading = false;
      });
    }
  }

  void _showAdDetail(String adId) {
    if (adId.isEmpty) return;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      Navigator.of(context).pushNamed('/ad/$adId');
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: AdDetailScreen(adId: adId),
        ),
      );
    }
  }

  Future<void> _openCreateUpload({
    UploadMode mode = UploadMode.post,
    bool isAdFlow = false,
  }) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            CreateUploadScreen(initialMode: mode, isAdFlow: isAdFlow),
      ),
    );
    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _openCreatePostFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateUploadScreen(
          initialMode: UploadMode.post,
        ),
      ),
    );
  }

  Widget _buildAdsGrid() {
    if (_vendorAds.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _vendorAds.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemBuilder: (context, index) {
        final ad = _vendorAds[index];
        final thumb = (ad.imageUrl ?? '').trim();
        final isVideo = (ad.videoUrl ?? '').trim().isNotEmpty;
        final url = thumb.isNotEmpty ? thumb : (ad.videoUrl ?? '').trim();
        if (url.isEmpty) {
          return Container(color: Colors.grey[300]);
        }
        return GestureDetector(
          onTap: () => _showAdDetail(ad.id),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                httpHeaders: UrlHelper.shouldAttachAuthHeader(url)
                    ? (_adsMediaHeaders ?? const {})
                    : null,
                fit: BoxFit.cover,
                placeholder: (ctx, _) => Container(color: Colors.grey[300]),
                errorWidget: (ctx, _, __) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image),
                ),
              ),
              if (isVideo)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    LucideIcons.video,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap with StoreConnector to listen to profile changes for "My Profile"
    return StoreConnector<AppState, Map<String, dynamic>?>(
      converter: (store) =>
          _isOwnProfile ? store.state.profileState.profile : null,
      builder: (context, myProfileFromRedux) {
        // CRITICAL FIX: If viewing own profile, use the Redux state directly.
        // This ensures that AdjustFollowingCount from the Dashboard reflects here instantly.
        final bool isMe = _isOwnProfile || widget.userId == null;
        final displayProfile =
            isMe ? (myProfileFromRedux ?? _profile) : _profile;

        if (_profileBlocked && !isMe) {
          final privateUser = _privateProfilePreview ?? displayProfile;
          final username =
              (privateUser?['username'] as String?)?.trim() ?? 'user';
          final fullName = (privateUser?['full_name'] as String?)?.trim();
          final avatar = (privateUser?['avatar_url'] as String?)?.trim();
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              title: Text(username),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      backgroundImage: (avatar != null && avatar.isNotEmpty)
                          ? NetworkImage(avatar)
                          : null,
                      child: (avatar == null || avatar.isEmpty)
                          ? Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'This account is private',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fullName != null && fullName.isNotEmpty
                          ? '@$username · $fullName'
                          : '@$username',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Follow them to see their posts, stories, and profile content.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.60),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (_loading && displayProfile == null) {
          return const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(
                      color: DesignTokens.instaPink)));
        }

        if (!_loading && displayProfile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.userX, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('User not found',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }

        // Use displayProfile for all variables below
        final username = displayProfile?['username'] as String? ?? 'user';
        final fullName = displayProfile?['full_name'] as String?;
        final bio = displayProfile?['bio'] as String?;
        final avatar = displayProfile?['avatar_url'] as String?;
        String _asId(dynamic v) {
          if (v == null) return '';
          final s = v.toString().trim();
          return s;
        }

        final profileUserId = [
          displayProfile?['_id'],
          displayProfile?['id'],
          displayProfile?['user_id'],
          displayProfile?['userId'],
          displayProfile?['uid'],
        ].map(_asId).firstWhere((s) => s.isNotEmpty, orElse: () => '');
        final postsCount =
            (displayProfile?['posts_count'] as int?) ?? _posts.length;
        final followers = tryReadInt(displayProfile, const [
              'followers_count',
              'followersCount',
              'followers',
              'follower_count',
            ]) ??
            0;
        final following = tryReadInt(displayProfile, const [
              'following_count',
              'followingCount',
              'following',
            ]) ??
            0;
        final isVendor =
            (displayProfile?['role'] as String?)?.toLowerCase() == 'vendor';
        final vendorMap = displayProfile?['vendor'];
        final vendorValidatedFromVendor =
            vendorMap is Map ? (vendorMap['validated'] as bool?) : null;
        final isValidated = (displayProfile?['vendor_validated'] as bool?) ??
            (displayProfile?['vendorValidated'] as bool?) ??
            (displayProfile?['validated'] as bool?) ??
            vendorValidatedFromVendor ??
            (displayProfile?['isValidated'] as bool?) ??
            (displayProfile?['verified'] as bool?) ??
            (displayProfile?['isVerified'] as bool?) ??
            (displayProfile?['is_verified'] as bool?) ??
            false;

        final theme = Theme.of(context);
        final fgColor = theme.colorScheme.onSurface;

        bool hasRenderableGridMedia(FeedPost p) {
          final thumb = UrlHelper.normalizeUrl((p.thumbnailUrl ?? '').trim());
          if (thumb.isNotEmpty) return true;
          for (final u in p.mediaUrls) {
            final normalized = UrlHelper.normalizeUrl(u.trim());
            if (normalized.isNotEmpty) return true;
          }
          return false;
        }

        final mediaPosts = _posts.where((p) {
          final ok = !p.isTweet &&
              p.mediaType != PostMediaType.reel &&
              !p.isAd &&
              hasRenderableGridMedia(p);
          assert(() {
            if (!ok) {
              final thumb = (p.thumbnailUrl ?? '').trim();
              final first = p.mediaUrls.isNotEmpty ? p.mediaUrls.first : '';
              debugPrint(
                '[ProfileScreen] Filtered from Posts grid: id=${p.id} mediaType=${p.mediaType} isAd=${p.isAd} isTweet=${p.isTweet} thumb="$thumb" first="$first"',
              );
            }
            return true;
          }());
          return ok;
        }).toList();
        final reelPosts = _posts.where((p) {
          final ok = !p.isTweet &&
              p.mediaType == PostMediaType.reel &&
              !p.isAd &&
              hasRenderableGridMedia(p);
          return ok;
        }).toList();

        final reelFromService = _userReels
            .map((r) {
              final mediaUrl = r.videoUrl.trim();
              final thumb = (r.thumbnailUrl ?? '').trim();
              return FeedPost(
                id: r.id,
                userId: r.userId,
                userName: r.userName,
                userAvatar: r.userAvatarUrl,
                mediaType: PostMediaType.reel,
                mediaUrls: mediaUrl.isNotEmpty ? [mediaUrl] : const [],
                thumbnailUrl: thumb.isNotEmpty ? thumb : null,
                caption: r.caption,
                hashtags: r.hashtags,
                createdAt: r.createdAt,
                likes: r.likes,
                comments: r.comments,
                shares: r.shares,
                views: r.views,
                isLiked: r.isLiked,
                isSaved: r.isSaved,
                isFollowed: r.isFollowing,
                isAd: r.isSponsored,
              );
            })
            .where(hasRenderableGridMedia)
            .toList();
        final tweetPosts = _tweets;
        final promotePosts = _promotes;
        final storyTap = _storiesBlocked ? null : _openStoriesFromProfile;

        final allById = <String, FeedPost>{};
        for (final p in [...mediaPosts, ...reelPosts, ...reelFromService]) {
          if (p.id.trim().isEmpty) continue;
          allById[p.id] = p;
        }
        final allFeedItems = allById.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final allCount = allFeedItems.length;

        final tabs = <Tab>[
          const Tab(icon: Icon(LucideIcons.layoutGrid)),
          const Tab(icon: Icon(LucideIcons.image)),
          const Tab(icon: Icon(LucideIcons.video)),
          const Tab(icon: Icon(LucideIcons.messageCircle)),
          const Tab(icon: Icon(LucideIcons.megaphone)),
        ];

        Widget privacyPlaceholder({
          required String title,
          required String subtitle,
          IconData icon = LucideIcons.lock,
        }) {
          final muted = theme.colorScheme.onSurface.withValues(alpha: 0.60);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(icon, size: 30, color: muted),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final allTab = (allCount == 0)
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: _emptyGridPlaceholder(
                  context,
                  isReels: false,
                  isOwnProfile: isMe,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PostsGrid(posts: allFeedItems, onTap: (p) => _onPostTap(p)),
                  const SizedBox(height: 12),
                ],
              );

        final tabViews = <Widget>[
          ListView(
            padding: EdgeInsets.zero,
            children: [allTab],
          ),
          _postsRestricted
              ? privacyPlaceholder(
                  title: 'Posts are private',
                  subtitle: 'Only approved followers can see these posts.',
                )
              : (mediaPosts.isEmpty
                  ? _emptyGridPlaceholder(
                      context,
                      isReels: false,
                      isOwnProfile: isMe,
                    )
                  : PostsGrid(posts: mediaPosts, onTap: (p) => _onPostTap(p))),
          _pulseRestricted
              ? privacyPlaceholder(
                  title: 'Pulse is private',
                  subtitle: 'Only approved followers can see these reels.',
                  icon: LucideIcons.video,
                )
              : _buildReelsGrid(isMe: isMe),
          ListView(
            padding: EdgeInsets.zero,
            children: [
              _postsRestricted
                  ? privacyPlaceholder(
                      title: 'Posts are private',
                      subtitle: 'Only approved followers can see this content.',
                    )
                  : _buildTweetsList(tweetPosts, isMe: isMe),
            ],
          ),
          _pulseRestricted
              ? privacyPlaceholder(
                  title: 'Pulse is private',
                  subtitle: 'Only approved followers can see this content.',
                  icon: LucideIcons.megaphone,
                )
              : (isVendor
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildAdsGrid(),
                    )
                  : (promotePosts.isEmpty
                      ? _emptyGridPlaceholder(
                          context,
                          isReels: false,
                          isOwnProfile: isMe,
                          emptyIcon: LucideIcons.megaphone,
                          emptyTitle: 'No Promote Yet',
                          showCreateButton: false,
                        )
                      : PostsGrid(
                          posts: promotePosts,
                          onTap: (_) => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PromoteScreen()),
                          ),
                        ))),
        ];

        return DefaultTabController(
          key: ValueKey('profile-tabs-${tabs.length}'),
          length: tabViews.length,
          child: Builder(
            builder: (tabCtx) {
              final controller = DefaultTabController.of(tabCtx);
              if (!_tabListenerAttached) {
                _tabListenerAttached = true;
                controller.addListener(() {
                  if (!mounted) return;
                  if (controller.indexIsChanging) return;
                  if (controller.index == 3) {
                    _ensureTweetsLoadedForUser(profileUserId);
                  }
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (controller.index == 3) {
                    _ensureTweetsLoadedForUser(profileUserId);
                  }
                });
              }

              return Scaffold(
                backgroundColor: theme.scaffoldBackgroundColor,
                appBar: AppBar(
                  automaticallyImplyLeading: !isMe,
                  backgroundColor: theme.appBarTheme.backgroundColor,
                  foregroundColor: theme.appBarTheme.foregroundColor,
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          style: TextStyle(color: fgColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      const SizedBox(width: 4),
                      SvgPicture.string(
                        _verifiedBadgeSvg,
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                            Color(0xFF3B82F6), BlendMode.srcIn),
                      ),
                    ],
                  ),
                  actions: [
                    if (isMe) ...[
                      IconButton(
                        icon: Icon(LucideIcons.squarePlus, color: fgColor),
                        onPressed: _openCreatePostFlow,
                      ),
                      IconButton(
                        icon: Icon(LucideIcons.menu, color: fgColor),
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/settings'),
                      ),
                    ],
                  ],
                ),
                body: RefreshIndicator(
                  onRefresh: _load,
                  notificationPredicate: (notification) => true,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverToBoxAdapter(
                        child: (() {
                          final canMessage = _canMessageProfile(displayProfile);
                          final isRequested = _followRequested ||
                              _isFollowRequested(displayProfile);

                          return ProfileHeader(
                            username: username,
                            fullName: fullName,
                            bio: bio,
                            avatarUrl: avatar,
                            avatarHeaders: _reelImageHeaders,
                            posts: postsCount,
                            followers: followers,
                            following: following,
                            ads: _vendorAds.length,
                            isMe: isMe,
                            isVendor: isVendor,
                            isValidated: isValidated,
                            isFollowing: _isFollowingViewer(displayProfile),
                            isRequested: isRequested,
                            canMessage: canMessage,
                            isFavorite: _isFavoriteProfile,
                            isSuggestionsOpen:
                                isMe ? _showFollowSuggestions : false,
                            hasStory: _hasStory && !_storiesBlocked,
                            onEdit: isMe ? _onEdit : null,
                            onFollow: isMe ? null : _onFollow,
                            onShare: () => _shareProfile(displayProfile),
                            onFavorite: profileUserId.isEmpty
                                ? null
                                : () {
                                    final next = !_isFavoriteProfile;
                                    setState(() => _isFavoriteProfile = next);
                                    if (!next) return;
                                    unawaited(() async {
                                      await _loadAdInterests(
                                        profileUserId,
                                        force: true,
                                      );
                                      if (!mounted) return;
                                      if (!_isFavoriteProfile) return;
                                      if (_interestsLoadedForUserId !=
                                          profileUserId.trim()) {
                                        return;
                                      }
                                      _applyBannersForInterests(_adInterests);
                                    }());
                                  },
                            onMore: () =>
                                _showProfileMoreActions(displayProfile),
                            onMessage: isMe
                                ? _openMessaging
                                : (canMessage ? _openMessaging : null),
                            onUser: isMe ? _toggleFollowSuggestions : null,
                            onAvatarTap: storyTap,
                            onAvatarEdit: isMe && !_avatarUploading
                                ? _showAvatarOptionsSheet
                                : null,
                            onFollowersTap: profileUserId.isNotEmpty
                                ? () => FollowListScreen.open(
                                      context,
                                      userId: profileUserId,
                                      username: username,
                                      mode: FollowListMode.followers,
                                      isOwnProfile: isMe,
                                      initialFollowersCount: followers,
                                      initialFollowingCount: following,
                                    )
                                : null,
                            onFollowingTap: profileUserId.isNotEmpty
                                ? () => FollowListScreen.open(
                                      context,
                                      userId: profileUserId,
                                      username: username,
                                      mode: FollowListMode.following,
                                      isOwnProfile: isMe,
                                      initialFollowersCount: followers,
                                      initialFollowingCount: following,
                                    )
                                : null,
                          );
                        })(),
                      ),
                      SliverToBoxAdapter(
                        child: _buildFavoriteCategoryStrip(
                          context,
                          profileUserId: profileUserId,
                          isMe: isMe,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _buildFollowSuggestionsBlock(context),
                      ),
                      SliverToBoxAdapter(
                        child: profileUserId.isEmpty || isVendor
                            ? const SizedBox.shrink()
                            : ProfileHighlightsRow(
                                userId: profileUserId,
                                userName: username,
                                userAvatar: avatar,
                              ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverTabBarDelegate(
                          TabBar(
                            tabs: tabs,
                            isScrollable: false,
                            indicator: const UnderlineTabIndicator(
                                borderSide: BorderSide(
                                    width: 1.5, color: DesignTokens.instaPink)),
                            labelColor: DesignTokens.instaPink,
                            unselectedLabelColor: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      children: tabViews,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    if (oldDelegate is! _SliverTabBarDelegate) return true;
    return oldDelegate.tabBar.tabs.length != tabBar.tabs.length;
  }
}

class EditProfileScreen extends StatefulWidget {
  final String? userId;
  const EditProfileScreen({super.key, this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final SupabaseService _svc = SupabaseService();
  final _usernameCtl = TextEditingController();
  final _fullNameCtl = TextEditingController();
  final _bioCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  Map<String, String>? _mediaHeaders;
  bool _loading = true;
  bool _uploading = false;
  String? _avatarUrl;
  Map<String, dynamic>? _profile;
  String? _effectiveUserId;

  @override
  void initState() {
    super.initState();
    ApiClient().getToken().then((token) {
      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        setState(() => _mediaHeaders = {'Authorization': 'Bearer $token'});
      } else {
        _mediaHeaders = const <String, String>{};
      }
    });
    _load();
  }

  Future<void> _load() async {
    final uid = widget.userId != null && widget.userId!.isNotEmpty
        ? widget.userId
        : await CurrentUser.id;

    if (uid == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _effectiveUserId = uid;

    final profile = await _svc.getUserById(uid);
    if (mounted) {
      setState(() {
        _profile = profile;
        _usernameCtl.text = profile?['username'] ?? '';
        _fullNameCtl.text = profile?['full_name'] ?? '';
        _bioCtl.text = profile?['bio'] ?? '';
        _phoneCtl.text = profile?['phone'] ?? '';
        _avatarUrl = profile?['avatar_url'] as String?;
        _loading = false;
      });
    }
  }

  Future<void> _uploadAvatar() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    final picker = ImagePicker();
    try {
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (!mounted || xfile == null) return;

      final bytes = await xfile.readAsBytes();
      if (bytes.isEmpty) {
        throw 'Selected image is empty.';
      }
      final res = await _svc.uploadAvatarBytes(bytes: bytes);
      final newUrl = _extractAvatarUrl(res);
      if (newUrl == null || newUrl.isEmpty) {
        throw 'Avatar upload succeeded but no URL was returned.';
      }
      if (mounted) {
        setState(() {
          _avatarUrl = newUrl;
        });
      }
      await _refreshProfileAfterAvatarChange(newUrl);
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
      return;
    }

    if (mounted) {
      setState(() => _uploading = false);
    }
  }

  void _showAvatarOptionsSheet() {
    if (_uploading) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('New profile photo'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _uploadAvatar();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove profile photo'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _removeAvatarToGooglePhoto();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeAvatarToGooglePhoto() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final googleUrl = await _resolveGoogleAvatarUrl(_profile);
      if (googleUrl == null || googleUrl.isEmpty) {
        throw 'Google profile photo not available.';
      }
      if (_effectiveUserId == null || _effectiveUserId!.isEmpty) {
        throw 'User not found.';
      }
      await _svc
          .updateUserProfile(_effectiveUserId!, {'avatar_url': googleUrl});
      await _refreshProfileAfterAvatarChange(googleUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remove failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String?> _resolveGoogleAvatarUrl(Map<String, dynamic>? profile) async {
    final candidates = [
      profile?['google_avatar_url'],
      profile?['google_avatar'],
      profile?['photo_url'],
      profile?['photoUrl'],
      profile?['picture'],
      profile?['profile_picture'],
    ];
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c;
    }
    return AuthService().getGoogleProfilePhotoUrl();
  }

  String? _extractAvatarUrl(Map<String, dynamic> res) {
    dynamic url =
        res['avatar_url'] ?? res['url'] ?? res['fileUrl'] ?? res['file_url'];
    if (url is String && url.isNotEmpty) return url;
    final data = res['data'];
    if (data is Map) {
      url = data['avatar_url'] ??
          data['url'] ??
          data['fileUrl'] ??
          data['file_url'];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  Future<void> _refreshProfileAfterAvatarChange(String fallbackUrl) async {
    final uid = _effectiveUserId;
    if (uid == null || uid.isEmpty) return;
    try {
      final profile = await _svc.getUserById(uid);
      if (!mounted) return;
      if (profile != null && profile.isNotEmpty) {
        setState(() {
          _profile = profile;
          _avatarUrl = profile['avatar_url'] as String? ?? fallbackUrl;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _avatarUrl = fallbackUrl;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final updates = {
      'username': _usernameCtl.text.trim(),
      'full_name': _fullNameCtl.text.trim(),
      'bio': _bioCtl.text.trim(),
      'phone': _phoneCtl.text.trim(),
      if (_avatarUrl != null) 'avatar_url': _avatarUrl,
    };
    try {
      if (_effectiveUserId == null) throw 'User ID not found';
      await _svc.updateUserProfile(_effectiveUserId!, updates);
      if (mounted) {
        setState(() => _loading = false);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fgColor = theme.colorScheme.onSurface;
    if (_loading && _profile == null) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: DesignTokens.instaPink)));
    }
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: fgColor),
            onPressed: () => Navigator.of(context).pop()),
        title: Text('Edit Profile',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: fgColor)),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: fgColor,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(_loading ? 'Saving...' : 'Save',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _loading ? Colors.grey : DesignTokens.instaPink)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _uploading ? null : _showAvatarOptionsSheet,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: DesignTokens.instaGradient,
                      boxShadow: [
                        BoxShadow(
                            color: DesignTokens.instaPink.withAlpha(80),
                            blurRadius: 8)
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: theme.cardColor),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: _avatarUrl != null
                            ? SafeNetworkImage(
                                url: _avatarUrl!,
                                headers: UrlHelper.shouldAttachAuthHeader(
                                        _avatarUrl!)
                                    ? _mediaHeaders
                                    : null,
                                width: 86,
                                height: 86,
                                fit: BoxFit.cover,
                                placeholder: _placeholderAvatar(),
                                errorWidget: _placeholderAvatar(),
                              )
                            : _placeholderAvatar(),
                      ),
                    ),
                  ),
                  if (_uploading)
                    Positioned.fill(
                        child: Container(
                            color: Colors.black38,
                            child: const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white)))),
                  if (!_uploading)
                    Positioned(
                        bottom: 0,
                        right: 0,
                        child:
                            Icon(LucideIcons.camera, size: 20, color: fgColor)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _uploading ? null : _showAvatarOptionsSheet,
              child: Text(_uploading ? 'Uploading...' : 'Change Profile Photo',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.instaPink)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _fullNameCtl,
              style: TextStyle(color: fgColor),
              decoration: InputDecoration(
                  labelText: 'Name',
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameCtl,
              style: TextStyle(color: fgColor),
              decoration: InputDecoration(
                  labelText: 'Username',
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bioCtl,
              maxLines: 3,
              style: TextStyle(color: fgColor),
              decoration: InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Write something about yourself...',
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor))),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: fgColor),
              decoration: InputDecoration(
                  labelText: 'Phone',
                  filled: true,
                  fillColor: theme.cardColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderAvatar() {
    final theme = Theme.of(context);
    final name = _fullNameCtl.text.trim().isNotEmpty
        ? _fullNameCtl.text.trim()
        : _usernameCtl.text.trim();
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
    return Container(
        color: theme.cardColor,
        child: Center(
            child: Text(initial,
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface))));
  }
}
