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
import '../services/user_account_service.dart';
import '../services/wallet_service.dart';
import '../api/auth_api.dart';
import '../api/api_client.dart';
import '../config/api_config.dart';
import '../services/feed_service.dart';
import '../models/story_model.dart';
import 'story_viewer_screen.dart';
import '../models/media_model.dart';
import 'create_upload_screen.dart';
import 'messaging_screen.dart';
import '../api/highlights_api.dart';
import '../services/highlight_service.dart';
import '../utils/url_helper.dart';
import 'highlight_story_picker_screen.dart';
import '../services/ads_service.dart';

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
  Map<String, dynamic>? _profile;
  List<FeedPost> _posts = [];
  List<FeedPost> _saved = [];
  List<FeedPost> _tagged = [];
  List<Ad> _vendorAds = [];
  bool _loading = true;
  bool _usedCache = false;
  bool _hasError = false;
  bool _followLoading = false;
  final ReelsService _reelsService = ReelsService();
  List<Reel> _userReels = [];
  static const int _initialPostsLimit = 20;
  final FeedService _feedService = FeedService();
  List<StoryGroup> _storyGroups = const [];
  bool _hasStory = false;
  final HighlightService _highlightService = HighlightService();
  List<Map<String, dynamic>> _highlights = const [];
  final Map<String, List<Map<String, dynamic>>> _highlightItemsById = {};
  bool _highlightsLoading = false;
  bool _highlightsError = false;
  Map<String, String>? _reelImageHeaders;
  Map<String, String>? _adsMediaHeaders;
  bool _isOwnProfile = false;
  bool _isFavoriteProfile = false;
  StreamSubscription<AppState>? _storeSub;

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

  void _toggleFavoriteProfile(String username) {
    setState(() => _isFavoriteProfile = !_isFavoriteProfile);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFavoriteProfile
              ? 'Added @$username to favorites'
              : 'Removed @$username from favorites',
        ),
      ),
    );
  }

  void _openMessaging() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const MessagingScreen()),
    );
  }

  void _showProfileMoreActions(Map<String, dynamic>? profile) {
    if (profile == null) return;
    final username = (profile['username'] as String?)?.trim() ?? 'user';
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report user'),
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

    final profileFuture = isMe ? AuthApi().me() : _svc.getUserById(targetId);
    final postsFuture = _svc.getUserPosts(targetId, limit: _initialPostsLimit);
    final savedFuture = isMe
        ? _svc.getUserSavedPosts(targetId, limit: _initialPostsLimit)
        : Future.value(<Map<String, dynamic>>[]);
    final taggedFuture =
        _svc.getUserTaggedPosts(targetId, limit: _initialPostsLimit);
    final walletFuture = (widget.userId == null)
        ? WalletService().getCoinBalance()
        : Future.value(0);
    final userAccount = UserAccountService().getAccount(targetId);

    Map<String, dynamic>? profile;
    List<Map<String, dynamic>> rawPosts = [];
    List<Map<String, dynamic>> rawSaved = [];
    List<Map<String, dynamic>> rawTagged = [];
    int walletBalance = 0;

    try {
      final results = await Future.wait([
        profileFuture,
        postsFuture,
        savedFuture,
        taggedFuture,
        walletFuture,
      ]);

      profile = results[0] as Map<String, dynamic>?;
      rawPosts = results[1] as List<Map<String, dynamic>>;
      rawSaved = results[2] as List<Map<String, dynamic>>;
      rawTagged = results[3] as List<Map<String, dynamic>>;
      walletBalance = results[4] as int;
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
      return;
    }

    final isVendor =
        (profile?['role'] as String?)?.toLowerCase() == 'vendor';
    List<Ad> vendorAds = [];
    if (isVendor && targetId.isNotEmpty) {
      try {
        vendorAds = await _adsService.fetchUserAds(userId: targetId);
      } catch (_) {}
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
        final media = (map['media'] as List<dynamic>? ?? []);
        final mediaUrls = media
            .map((m) {
              if (m is String) return m;
              if (m is Map) {
                final mm = Map<String, dynamic>.from(m);
                String? thumb;
                final thumbField =
                    mm['thumbnail'] ?? mm['thumbnailUrl'] ?? mm['thumb'];
                if (thumbField is List && thumbField.isNotEmpty) {
                  thumb = thumbField.first.toString();
                } else if (thumbField is String) {
                  thumb = thumbField;
                }
                final url = thumb ??
                    (mm['fileUrl'] ?? mm['image'] ?? mm['url'])?.toString();
                if (url != null && url.isNotEmpty) return url;
              }
              return m.toString();
            })
            .cast<String>()
            .toList();
        final typeStr = ((map['type'] as String?) ??
                (map['media_type'] as String?) ??
                'post')
            .toLowerCase();
        final isAdType = typeStr == 'ad' || toBool(map['is_ad']);
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
          caption: caption,
          hashtags: hashtags,
          createdAt: createdAt,
          isTagged: (map['people_tags'] as List?)?.isNotEmpty ?? false,
          peopleTags: (map['people_tags'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList(),
          likes: (map['likes_count'] as int?) ??
              (map['likes'] is int ? map['likes'] as int : 0),
          comments: (map['comments_count'] as int?) ??
              (map['comments'] is int ? map['comments'] as int : 0),
          isLiked: toBool(map['is_liked_by_me']) || toBool(map['liked_by_me']),
          isSaved: toBool(map['is_saved_by_me']) || toBool(map['saved_by_me']),
          isFollowed: toBool(map['is_followed_by_me']) || toBool(map['followed_by_me']),
          isAd: isAdType,
          adCompanyId: map['ad_company_id']?.toString(),
          adCompanyName: map['ad_company_name']?.toString(),
        );
      }).toList();
    }

    final posts = map0(rawPosts);
    final saved = map0(rawSaved);
    final tagged = map0(rawTagged);

    // Initialize counts from existing data to prevent resetting to 0 on API failure
    int? followersCount;
    int? followingCount;

    // 1. Try to get from current Redux state (for "Me") or local state
    if (widget.userId == null) {
      try {
        final store = StoreProvider.of<AppState>(context);
        final cached = store.state.profileState.profile;
        if (cached != null) {
          followersCount = cached['followers_count'] as int?;
          followingCount = cached['following_count'] as int?;
        }
      } catch (_) {}
    }
    // 2. Fallback to local _profile
    if (followersCount == null && _profile != null) {
      followersCount = _profile!['followers_count'] as int?;
    }
    if (followingCount == null && _profile != null) {
      followingCount = _profile!['following_count'] as int?;
    }
    // 3. Fallback to API profile response (if available)
    if (followersCount == null && profile != null) {
      followersCount = profile['followers_count'] as int?;
    }
    if (followingCount == null && profile != null) {
      followingCount = profile['following_count'] as int?;
    }

    // 4. Update with fresh API data (only if successful and valid)
    // Fix: Check if API returns 0 but Redux has a non-zero value, prevent overwrite
    try {
      final count = await _svc.getFollowersCount(targetId);
      if (count > 0) {
        followersCount = count;
      } else {
        // API returned 0 (or failed silently). Check Redux state before accepting 0.
        if (widget.userId == null) {
          try {
            final store = StoreProvider.of<AppState>(context);
            final cached = store.state.profileState.profile;
            final cachedCount = cached?['followers_count'] as int?;
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
      } else {
        if (widget.userId == null) {
          try {
            final store = StoreProvider.of<AppState>(context);
            final cached = store.state.profileState.profile;
            final cachedCount = cached?['following_count'] as int?;
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
        'is_followed_by_me': isFollowedByMe,
        'posts_count': finalPostsCount,
        'followers_count': finalFollowers,
        'following_count': finalFollowing,
        'wallet_balance': (profile?['wallet_balance'] as int?) ?? walletBalance,
        'account_type': userAccount?.accountType.toString().split('.').last,
        'engagement_score': userAccount?.engagementScore,
      };

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
        _posts = posts;
        _saved = saved;
        _tagged = tagged;
        _vendorAds = vendorAds;
        _userReels = combinedReels.values.toList();
        _storyGroups = const [];
        _loading = false;
      });
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

  Future<void> _openStoriesFromProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final targetId =
        (profile['id'] as String?) ?? (profile['_id'] as String?) ?? '';
    if (targetId.isEmpty) return;
    final groups = await _feedService.fetchStoriesFeed();
    final userGroups = groups.where((g) => g.userId == targetId).toList();
    if (userGroups.isEmpty) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoryViewerScreen(
          storyGroups: userGroups,
          initialIndex: 0,
        ),
      ),
    );
  }

  Future<void> _loadStoryStatus(String userId) async {
    if (userId.isEmpty) return;
    try {
      final groups = await _feedService.fetchStoriesFeed();
      final hasStory = groups.any(
        (g) => g.userId == userId && g.stories.isNotEmpty,
      );
      if (!mounted) return;
      if (_hasStory != hasStory) {
        setState(() {
          _hasStory = hasStory;
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

  Future<void> _loadHighlightsForUser(String userId) async {
    if (userId.isEmpty) return;
    if (mounted) {
      setState(() {
        _highlightsLoading = true;
        _highlightsError = false;
      });
    }
    try {
      final res = await HighlightsApi().userHighlightsWithStories(userId);
      final highlights =
          List<Map<String, dynamic>>.from((res['highlights'] as List?) ?? const []);
      highlights.sort((a, b) {
        final ao = (a['order'] as num?)?.toInt() ?? 0;
        final bo = (b['order'] as num?)?.toInt() ?? 0;
        return ao.compareTo(bo);
      });
      _highlightItemsById.clear();
      for (final h in highlights) {
        final id = (h['_id'] as String?) ?? (h['id'] as String?) ?? '';
        if (id.isEmpty) continue;
        final rawItems = h['items'];
        if (rawItems is List && rawItems.isNotEmpty) {
          _highlightItemsById[id] = rawItems
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } else {
          _highlightItemsById[id] = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _highlights = highlights;
        _highlightsLoading = false;
        _highlightsError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _highlightsLoading = false;
        _highlightsError = true;
      });
    }
  }

  Future<void> _createHighlight() async {
    final profile = _profile;
    if (profile == null) return;
    final userId = (profile['id'] as String?) ?? (profile['_id'] as String?) ?? '';
    if (userId.isEmpty) return;
    final userName =
        (profile['username'] as String?) ?? (profile['full_name'] as String?) ?? 'You';
    final userAvatar = (profile['avatar_url'] as String?) ?? (profile['avatar'] as String?);
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HighlightStoryPickerScreen(
          userId: userId,
          userName: userName,
          userAvatar: userAvatar,
        ),
      ),
    );
    if (!mounted) return;
    if (updated == true) {
      await _loadHighlightsForUser(userId);
    }
  }

  Future<void> _openHighlight(Map<String, dynamic> highlight) async {
    final id = (highlight['_id'] as String?) ?? (highlight['id'] as String?) ?? '';
    if (id.isEmpty) return;
    final profile = _profile;
    final ownerName =
        (profile?['username'] as String?) ?? (profile?['full_name'] as String?) ?? '';
    final ownerAvatar =
        (profile?['avatar_url'] as String?) ?? (profile?['avatar'] as String?);
    try {
      final cachedItems = _highlightItemsById[id];
      final itemsCount = (highlight['items_count'] as num?)?.toInt() ?? 0;
      final items = (cachedItems != null && cachedItems.isNotEmpty)
          ? _highlightService.mapHighlightItems(
              cachedItems,
              ownerUserName: ownerName,
              ownerAvatar: ownerAvatar,
            )
          : (itemsCount == 0)
              ? const <Story>[]
              : await _highlightService.fetchHighlightItems(
                  id,
                  ownerUserName: ownerName,
                  ownerAvatar: ownerAvatar,
                );
      if (!mounted) return;
      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items in this highlight')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StoryViewerScreen(
            storyGroups: [
              StoryGroup(
                userId: (profile?['id'] as String?) ?? (profile?['_id'] as String?) ?? '',
                userName: ownerName,
                userAvatar: ownerAvatar,
                storyId: null,
                stories: items,
              ),
            ],
            initialIndex: 0,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open highlight')),
      );
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
    _followLoading = true;
    final current = (_profile?['is_followed_by_me'] as bool?) ?? false;
    final next = !current;
    int followersCount = (_profile?['followers_count'] as int?) ?? 0;
    final delta = next ? 1 : -1;
    final nextFollowers =
        ((followersCount + delta).toDouble().clamp(0, double.maxFinite))
            .toInt();

    if (mounted) {
      setState(() {
        _profile = {
          ...?_profile,
          'is_followed_by_me': next,
          'followers_count': nextFollowers,
        };
      });
    }

    final success = next
        ? await _svc.followUser(targetId)
        : await _svc.unfollowUser(targetId);

    if (success) {
      if (mounted) {
        // Update global "My Profile" state for following count
        final store = StoreProvider.of<AppState>(context);
        store.dispatch(AdjustFollowingCount(delta));
      }
    } else {
      if (mounted) {
        setState(() {
          _profile = {
            ...?_profile,
            'is_followed_by_me': current,
            'followers_count': followersCount,
          };
        });
      }
    }

    if (success && mounted) {
      final store = StoreProvider.of<AppState>(context);
      store.dispatch(UpdateUserFollowed(targetId, next));
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
    _showPostDetail(p.id);
  }

  void _showPostDetail(String postId) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      Navigator.of(context).pushNamed('/post/$postId').then((_) {
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
                title: const Text('Create Post'),
                subtitle: Text('Photo or video',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _openCreateUpload(mode: UploadMode.post);
                  });
                },
              ),
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
                      _openCreateUpload(mode: UploadMode.reel);
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

  Widget _buildHighlights() {
    final showNew = _isOwnProfile || widget.userId == null;
    if (_highlightsLoading && _highlights.isEmpty) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_highlights.isEmpty && !showNew) {
      return const SizedBox(
        height: 110,
        child: Center(child: Text('No highlights yet')),
      );
    }
    final items = List<Map<String, dynamic>>.from(_highlights);
    final itemCount = items.length + (showNew ? 1 : 0);
    bool isImageUrl(String url) {
      final u = url.toLowerCase();
      return u.endsWith('.jpg') ||
          u.endsWith('.jpeg') ||
          u.endsWith('.png') ||
          u.endsWith('.webp') ||
          u.endsWith('.gif');
    }
    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          if (showNew && i == items.length) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _createHighlight,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.white,
                    ),
                    child: Icon(LucideIcons.plus, color: Colors.grey.shade800),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('New', style: TextStyle(fontSize: 12)),
              ],
            );
          }
          final h = items[i];
          final title = (h['title'] as String?) ?? '';
          final cover =
              UrlHelper.absoluteUrl((h['cover_url'] as String?) ?? '');
          final fallbackAvatar = UrlHelper.absoluteUrl(
              (_profile?['avatar_url'] as String?) ?? '');
          final showImage = (cover.isNotEmpty && isImageUrl(cover)) ||
              (fallbackAvatar.isNotEmpty && isImageUrl(fallbackAvatar));
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _openHighlight(h),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    color: Theme.of(context).cardColor,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: showImage
                        ? Image.network(
                            cover.isNotEmpty ? cover : fallbackAvatar,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.black12),
                          )
                        : Container(color: Colors.black12),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                  width: 72,
                  child: Text(title,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface))),
            ],
          );
        },
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
        final postsCount =
            (displayProfile?['posts_count'] as int?) ?? _posts.length;
        final followers = (displayProfile?['followers_count'] as int?) ?? 0;
        final following = (displayProfile?['following_count'] as int?) ?? 0;
        final isVendor =
            (displayProfile?['role'] as String?)?.toLowerCase() == 'vendor';

        final theme = Theme.of(context);
        final fgColor = theme.colorScheme.onSurface;

        final tabs = isVendor
            ? <Tab>[
                const Tab(icon: Icon(LucideIcons.megaphone)),
              ]
            : <Tab>[
                const Tab(icon: Icon(LucideIcons.layoutGrid)),
                const Tab(icon: Icon(LucideIcons.video)),
                if (isMe) const Tab(icon: Icon(LucideIcons.bookmark)),
                const Tab(icon: Icon(LucideIcons.tag)),
              ];

        final tabViews = isVendor
            ? <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildAdsGrid(),
                ),
              ]
            : <Widget>[
                _posts.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child:
                            PostsGrid(posts: _posts, onTap: (p) => _onPostTap(p)),
                      ),
                _userReels.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _userReels.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 1,
                            mainAxisSpacing: 1,
                          ),
                          itemBuilder: (ctx, i) {
                            final r = _userReels[i];
                            final thumbRaw = r.thumbnailUrl?.trim();
                            final thumb =
                                (thumbRaw != null && thumbRaw.isNotEmpty)
                                    ? _absoluteReelUrl(thumbRaw)
                                    : null;
                            return GestureDetector(
                              onTap: () => _showPostDetail(r.id),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(color: Colors.black),
                                  if (thumb != null)
                                    CachedNetworkImage(
                                      imageUrl: thumb,
                                      httpHeaders: _reelImageHeaders,
                                      cacheKey:
                                          '$thumb#${_reelImageHeaders?['Authorization'] ?? ''}',
                                      fit: BoxFit.cover,
                                      placeholder: (ctx, url) =>
                                          Container(color: Colors.grey[900]),
                                      errorWidget: (ctx, url, err) =>
                                          Container(color: Colors.grey[900]),
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
                            );
                          },
                        ),
                      ),
                if (isMe)
                  (_saved.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: PostsGrid(
                            posts: _saved,
                            onTap: (p) => _onPostTap(p),
                          ),
                        )),
                _tagged.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: PostsGrid(
                          posts: _tagged,
                          onTap: (p) => _onPostTap(p),
                        ),
                      ),
              ];

        return DefaultTabController(
          key: ValueKey('profile-tabs-${tabs.length}'),
          length: tabViews.length,
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
              appBar: AppBar(
                automaticallyImplyLeading: !isMe,
                backgroundColor: theme.appBarTheme.backgroundColor,
                foregroundColor: theme.appBarTheme.foregroundColor,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(username, style: TextStyle(color: fgColor)),
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
                    onPressed: () => _openCreateUpload(
                      mode: UploadMode.post,
                    ),
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
                    child: ProfileHeader(
                      username: username,
                      fullName: fullName,
                      bio: bio,
                      avatarUrl: avatar,
                      posts: postsCount,
                      followers: followers,
                      following: following,
                      ads: _vendorAds.length,
                      isMe: isMe,
                      isVendor: isVendor,
                      isFollowing:
                          (displayProfile?['is_followed_by_me'] as bool?) ??
                              false,
                      isFavorite: _isFavoriteProfile,
                      hasStory: _hasStory,
                      onEdit: isMe ? _onEdit : null,
                      onFollow: isMe ? null : _onFollow,
                      onShare: () => _shareProfile(displayProfile),
                      onFavorite: () => _toggleFavoriteProfile(username),
                      onMore: () => _showProfileMoreActions(displayProfile),
                      onMessage: _openMessaging,
                      onAvatarTap: _openStoriesFromProfile,
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverTabBarDelegate(
                      TabBar(
                        tabs: tabs,
                        indicator: const UnderlineTabIndicator(
                            borderSide: BorderSide(
                                width: 1.5, color: DesignTokens.instaPink)),
                        labelColor: DesignTokens.instaPink,
                        unselectedLabelColor:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: tabViews,
                ),
              ),
            ),
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
  bool _loading = true;
  bool _uploading = false;
  String? _avatarUrl;
  Map<String, dynamic>? _profile;
  String? _effectiveUserId;

  @override
  void initState() {
    super.initState();
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
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await xfile.readAsBytes();
      final ext = xfile.path.split('.').last;
      final path =
          '$_effectiveUserId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final res = await _svc.uploadFile('avatars', path, bytes);
      if (mounted) {
        setState(() {
          _avatarUrl = res['fileUrl'] as String?;
          _uploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
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
              onTap: _uploading ? null : _uploadAvatar,
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
                            ? Image.network(_avatarUrl!,
                                width: 86,
                                height: 86,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _placeholderAvatar())
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
              onPressed: _uploading ? null : _uploadAvatar,
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
