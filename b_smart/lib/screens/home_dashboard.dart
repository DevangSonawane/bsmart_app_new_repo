import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/feed_service.dart';
import '../services/supabase_service.dart';
import '../services/wallet_service.dart';
import '../state/app_state.dart';
import '../state/profile_actions.dart';
import '../state/profile_actions.dart';
import '../state/feed_actions.dart';
import '../widgets/post_card.dart';
import '../widgets/stories_row.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/sidebar.dart';
import '../theme/design_tokens.dart';
import '../models/story_model.dart';
import '../models/feed_post_model.dart';
import '../models/media_model.dart';
import '../widgets/post_detail_modal.dart';
import '../widgets/comments_sheet.dart';
import 'ads_screen.dart';
import 'promote_screen.dart';
import 'reels_screen.dart';
import 'story_viewer_screen.dart';
import 'own_story_viewer_screen.dart';
import 'create_upload_screen.dart';
import '../utils/current_user.dart';
import '../api/api_exceptions.dart';
import '../api/api_client.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'profile_screen.dart';

class HomeDashboard extends StatefulWidget {
  final int? initialIndex;

  const HomeDashboard({Key? key, this.initialIndex}) : super(key: key);

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final FeedService _feedService = FeedService();
  final SupabaseService _supabase = SupabaseService();
  final WalletService _walletService = WalletService();
  String? _currentLocation;
  bool _locationLoading = false;

  List<Map<String, dynamic>> _storyUsers = [];
  List<StoryGroup> _storyGroups = [];
  List<Story> _myStories = [];
  String? _myStoryId;
  bool _yourStoryHasActive = false;
  Map<String, Map<String, bool>> _storyStatuses = {};
  int _currentIndex = 0;
  int _balance = 0;
  /// Current user profile from `users` table (same source as React web app) for header avatar.
  Map<String, dynamic>? _currentUserProfile;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != null) {
      _currentIndex = widget.initialIndex!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = StoreProvider.of<AppState>(context);
      _loadData(store);
      _fetchCurrentLocation();
    });
  }

  Future<void> _loadData(Store<AppState> store) async {
    store.dispatch(SetFeedLoading(true));
    // Use REST API-backed CurrentUser helper for the authenticated user ID.
    final currentUserId = await CurrentUser.id;
    final currentProfile =
        currentUserId != null ? await _supabase.getUserById(currentUserId) : null;
    // Same as React Home.jsx: fetch all posts, order by created_at desc
    final fetched = await _feedService.fetchFeedFromBackend(currentUserId: currentUserId);
    final bal = await _walletService.getCoinBalance();
    // Stories feed from backend
    final groups = await _feedService.fetchStoriesFeed();
    final allGroups = List<StoryGroup>.from(groups);
    final myGroups = currentUserId != null
        ? allGroups.where((g) => g.userId == currentUserId).toList()
        : <StoryGroup>[];
    final otherGroups = currentUserId != null
        ? allGroups.where((g) => g.userId != currentUserId).toList()
        : allGroups;

    final baseStatuses = _computeStoryStatuses(otherGroups);
    final previousStatuses = Map<String, Map<String, bool>>.from(_storyStatuses);
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
      final ad = a.stories.isNotEmpty ? a.stories.first.createdAt : DateTime.fromMillisecondsSinceEpoch(0);
      final bd = b.stories.isNotEmpty ? b.stories.first.createdAt : DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });

    final users = otherGroups.map((g) {
      return {
        'id': g.userId,
        'username': g.userName,
        'avatar_url': g.userAvatar,
      };
    }).toList();
    final my = currentUserId != null
        ? myGroups.expand((g) => g.stories).toList()
        : _buildMyStories(currentProfile);
    if (mounted) {
      store.dispatch(SetFeedPosts(fetched));
      setState(() {
        _currentUserProfile = currentProfile;
        _currentUserId = currentUserId;
        _storyUsers = users;
        _storyGroups = otherGroups;
        _storyStatuses = mergedStatuses;
        _myStories = my;
        _myStoryId = myGroups.isNotEmpty ? myGroups.first.storyId : null;
        _yourStoryHasActive = _myStories.isNotEmpty;
        _balance = bal;
      });
      // Preload profile into Redux so ProfileScreen opens instantly
      if (currentUserId != null && currentProfile != null) {
        store.dispatch(SetProfile(currentProfile));
      }
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      if (mounted) setState(() => _locationLoading = true);
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        if (mounted) setState(() => _locationLoading = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
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
        loc = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
      }
      if (mounted) setState(() {
        _currentLocation = loc;
        _locationLoading = false;
      });
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
    final store = StoreProvider.of<AppState>(context);
    store.dispatch(UpdatePostLiked(post.id, desired));
    if (mounted) setState(() {}); // trigger rebuild to reflect optimistic change
    final liked = await _supabase.setPostLike(post.id, like: desired);
    if (!mounted) return;
    try {
      final p = await SupabaseService().getPostById(post.id);
      final serverLiked = (p?['is_liked_by_me'] as bool?) ?? liked;
      final likesCount = (p?['likes_count'] as int?) ?? (post.likes + (desired ? 1 : -1));
      store.dispatch(UpdatePostLikedWithCount(post.id, serverLiked, likesCount));
      if (mounted) setState(() {}); // reflect reconciled count/color
    } catch (_) {
      store.dispatch(UpdatePostLiked(post.id, liked));
      if (mounted) setState(() {}); // reflect reconciled state
    }
  }

  void _onCommentPost(FeedPost post) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.9,
          child: CommentsSheet(postId: post.id),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PostDetailModal(postId: post.id),
        ),
      );
    }
  }

  void _onSharePost(FeedPost post) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Share link copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onSavePost(FeedPost post) async {
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
    final saved = await _supabase.setPostSaved(post.id, save: desired);
    if (!mounted) return;
    try {
      final p = await SupabaseService().getPostById(post.id);
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
    
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: Text(followed ? 'Following ${post.userName}' : 'Unfollowed ${post.userName}'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));

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
        messenger.clearSnackBars();
        messenger.showSnackBar(const SnackBar(content: Text('Action failed')));
      } else {
        // Success: Update "My Profile" following count in Redux
        final meId = await CurrentUser.id;
        if (meId == null || meId.isEmpty) return;
        
        final cachedProfile = store.state.profileState.profile;
        final cachedId = cachedProfile?['id']?.toString() ?? cachedProfile?['_id']?.toString();
        
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
                  const SnackBar(content: Text('We\'ll show you less like this')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied'), behavior: SnackBarBehavior.floating),
                );
              },
            ),
            FutureBuilder<String?>(
              future: CurrentUser.id,
              builder: (context, snapshot) {
                final isOwner = snapshot.data != null && snapshot.data == post.userId;
                if (!isOwner) return const SizedBox.shrink();
                return ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
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
                                  width: MediaQuery.of(context).size.width * 0.9,
                                  constraints: const BoxConstraints(maxWidth: 360),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                  ),
                                  child: isDeleting
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: 48,
                                              height: 48,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 4,
                                                color: Colors.red,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Deleting post...',
                                              style: TextStyle(
                                                color: Theme.of(context).textTheme.bodyMedium?.color,
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
                                              'Delete Post?',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Are you sure you want to delete this post? This action cannot be undone.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
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
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                      foregroundColor: Colors.white,
                                                    ),
                                                    onPressed: () async {
                                                      setState(() => isDeleting = true);
                                                      try {
                                                        final ok = await SupabaseService().deletePost(post.id);
                                                        await Future.delayed(const Duration(milliseconds: 1500));
                                                        if (ok) {
                                                          if (mounted) {
                                                            StoreProvider.of<AppState>(context).dispatch(RemovePost(post.id));
                                                            Navigator.pop(context);
                                                            messenger.showSnackBar(const SnackBar(content: Text('Post deleted')));
                                                          }
                                                        } else {
                                                          if (mounted) {
                                                            setState(() => isDeleting = false);
                                                            Navigator.pop(context);
                                                            messenger.showSnackBar(const SnackBar(content: Text('Failed to delete post')));
                                                          }
                                                        }
                                                      } on ApiException catch (e) {
                                                        if (mounted) {
                                                          setState(() => isDeleting = false);
                                                          Navigator.pop(context);
                                                          messenger.showSnackBar(SnackBar(content: Text(e.message)));
                                                        }
                                                      } catch (e) {
                                                        if (mounted) {
                                                          setState(() => isDeleting = false);
                                                          Navigator.pop(context);
                                                          messenger.showSnackBar(SnackBar(content: Text(e.toString())));
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
            bottom: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200),
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
                      text: 'HOME ',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: _currentLocation == null
                          ? (_locationLoading ? 'Detecting current location...' : 'Tap to detect location')
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

  List<StoryGroup> _buildStoryGroupsFromUsers(List<Map<String, dynamic>> users) {
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
            mediaUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400',
            mediaType: StoryMediaType.image,
            createdAt: now.subtract(const Duration(hours: 2)),
            views: 0,
            isViewed: idx % 3 == 0,
            productUrl: idx == 0 ? 'https://bsmart.asynk.store/product/123' : null,
            externalLink: idx == 3 ? 'https://example.com' : null,
            hasPollQuiz: idx == 4,
          ),
        ],
      );
    }).toList();
  }

  Map<String, Map<String, bool>> _computeStoryStatuses(List<StoryGroup> groups) {
    final map = <String, Map<String, bool>>{};
    for (final g in groups) {
      final hasUnseen = g.stories.any((s) => s.isViewed == false);
      final allViewed = g.stories.isNotEmpty && g.stories.every((s) => s.isViewed == true);
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
        userName: (profile['username'] ?? profile['full_name'] ?? 'You').toString(),
        userAvatar: profile['avatar_url'] as String?,
        mediaUrl: 'https://images.unsplash.com/photo-1606787366850-de6330128bfc?w=400',
        mediaType: StoryMediaType.image,
        createdAt: now.subtract(const Duration(minutes: 30)),
        views: 12,
        isViewed: false,
      ),
    ];
  }

  void _onStoryTap(int userIndex) async {
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
    await _onRefresh();
  }

  Future<void> _onRefresh() async {
    final store = StoreProvider.of<AppState>(context);
    await _loadData(store);
  }

  Future<void> _openStoryCamera() async {
    await Navigator.of(context).pushNamed('/story-camera');
    if (!mounted) return;
    await _onRefresh();
  }

  void _onNavTap(int idx) {
    if (idx == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CreateUploadScreen(
            initialMode: UploadMode.post,
          ),
        ),
      );
      return;
    }
    // Profile from sidebar (desktop)
    if (idx == 5) {
      Navigator.of(context).pushNamed('/profile');
      return;
    }
    
    // If switching back to Home, refresh data
    if (idx == 0 && _currentIndex != 0) {
      final store = StoreProvider.of<AppState>(context);
      _loadData(store);
    }
    
    if (idx != _currentIndex) {
      setState(() {
        _currentIndex = idx;
      });
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
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, -4))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('Create', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: DesignTokens.instaGradient, borderRadius: BorderRadius.circular(12)),
                  child: Icon(LucideIcons.image, color: Colors.white, size: 22),
                ),
                title: const Text('Create Post'),
                subtitle: Text('Photo or video', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CreateUploadScreen(
                          initialMode: UploadMode.post,
                        ),
                      ),
                    );
                  });
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(gradient: DesignTokens.instaGradient, borderRadius: BorderRadius.circular(12)),
                  child: Icon(LucideIcons.video, color: Colors.white, size: 22),
                ),
                title: const Text('Upload Reel'),
                subtitle: Text('Short video', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
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
    final store = StoreProvider.of<AppState>(context);
    final feedState = store.state.feedState;
    final posts = feedState.posts;
    final isLoading = feedState.isLoading;
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final isFullScreen = _currentIndex == 3 || _currentIndex == 4; // Promote, Reels

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarBg = theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final appBarFg = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final content = Scaffold(
      extendBody: true,
      backgroundColor: isFullScreen ? (isDark ? const Color(0xFF121212) : Colors.black) : null,
      appBar: isFullScreen
          ? null
          : AppBar(
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [DesignTokens.instaPurple, DesignTokens.instaPink, DesignTokens.instaOrange],
                ).createShader(bounds),
                child: Text('b_smart', style: TextStyle(color: appBarFg, fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'cursive')),
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(gradient: DesignTokens.instaGradient, shape: BoxShape.circle),
                                  child: Icon(LucideIcons.wallet, size: 12, color: Colors.white),
                                ),
                                const SizedBox(width: 6),
                                Text('$_balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: appBarFg)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(onPressed: () => Navigator.of(context).pushNamed('/notifications'), icon: Icon(LucideIcons.heart, size: 24, color: appBarFg)),
                            Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: DesignTokens.instaPink, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFFE8E8E8) : Colors.white, width: 1.5)))),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, right: 12),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.transparent,
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade200,
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
                                            ? ((_currentUserProfile!['username'] ?? _currentUserProfile!['full_name'] ?? 'U') as String).isNotEmpty
                                                ? ((_currentUserProfile!['username'] ?? _currentUserProfile!['full_name'] ?? 'U') as String).substring(0, 1).toUpperCase()
                                                : 'U'
                                            : 'U',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: appBarFg),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Home tab
          RefreshIndicator(
            onRefresh: _onRefresh,
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: DesignTokens.instaPink))
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLocationSelector(isDark: isDark),
                        StoriesRow(
                          users: _storyUsers,
                          onYourStoryTap: () {
                            if (_yourStoryHasActive) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => OwnStoryViewerScreen(
                                    stories: _myStories,
                                    storyId: _myStoryId,
                                    userName: (_currentUserProfile?['username'] ?? _currentUserProfile?['full_name'] ?? 'You').toString(),
                                  ),
                                ),
                              );
                            } else {
                              _openStoryCamera();
                            }
                          },
                          onYourStoryAddTap: _openStoryCamera,
                          onUserStoryTap: _storyGroups.isEmpty ? null : _onStoryTap,
                          yourStoryHasActive: _yourStoryHasActive,
                          showYourStory: true,
                          userStatuses: _storyStatuses,
                        ),
                        if (posts.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.image, size: 48, color: Theme.of(context).textTheme.bodyMedium?.color),
                                const SizedBox(height: 12),
                                Text(
                                  'No posts yet',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create your first post from the + button',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final p = posts[index];
                              final isOwnPost =
                                  _currentUserId != null && p.userId == _currentUserId;
                              return PostCard(
                                post: p,
                                onLike: () => _onLikePost(p),
                                onComment: () => _onCommentPost(p),
                                onShare: () => _onSharePost(p),
                                onSave: () => _onSavePost(p),
                                onFollow: isOwnPost ? null : () => _onFollowPost(p),
                                onMore: () => _onMorePost(context, p),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
          ),
          // Ads tab
          const AdsScreen(),
          // Placeholder for create (kept empty since create opens modal/route)
          Container(),
          // Promote tab
          const PromoteScreen(),
          // Reels tab
          const ReelsScreen(),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : BottomNav(currentIndex: _currentIndex, onTap: _onNavTap),
    );

    if (isDesktop) {
      return Row(
        children: [
          Sidebar(
            currentIndex: _currentIndex,
            onNavTap: _onNavTap,
            onCreatePost: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateUploadScreen(
                    initialMode: UploadMode.post,
                  ),
                ),
              );
            },
            onUploadReel: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateUploadScreen(
                    initialMode: UploadMode.reel,
                  ),
                ),
              );
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
    }
    return content;
  }
}

class _DesktopNotificationsButton extends StatefulWidget {
  @override
  State<_DesktopNotificationsButton> createState() => _DesktopNotificationsButtonState();
}

class _DesktopNotificationsButtonState extends State<_DesktopNotificationsButton> {
  bool _showDropdown = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = theme.cardColor;
    final fgColor = theme.colorScheme.onSurface;
    return MouseRegion(
      onEnter: (_) => setState(() => _showDropdown = true),
      onExit: (_) => setState(() => _showDropdown = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: surfaceColor,
            elevation: 4,
            shadowColor: Colors.black26,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => setState(() => _showDropdown = !_showDropdown),
              customBorder: const CircleBorder(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade100)),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(child: Icon(LucideIcons.heart, size: 20, color: fgColor)),
                    Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: DesignTokens.instaPink, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFFE8E8E8) : Colors.white, width: 1.5)))),
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
                  decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade100)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: fgColor)),
                            GestureDetector(onTap: () {}, child: Text('Mark all read', style: TextStyle(fontSize: 12, color: DesignTokens.instaPink, fontWeight: FontWeight.w500))),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            _NotificationTile(icon: LucideIcons.bell, iconColor: Colors.blue, title: 'New follower: Sarah', time: '2 min ago'),
                            _NotificationTile(icon: LucideIcons.heart, iconColor: DesignTokens.instaPink, title: 'Mike liked your post', time: '1 hour ago'),
                            _NotificationTile(icon: LucideIcons.messageCircle, iconColor: DesignTokens.instaPurple, title: 'Anna commented: "Amazing!"', time: '2 hours ago'),
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

  const _NotificationTile({required this.icon, required this.iconColor, required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600;
    return ListTile(
      leading: CircleAvatar(backgroundColor: iconColor.withAlpha(40), child: Icon(icon, size: 14, color: iconColor)),
      title: Text(title, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface)),
      subtitle: Text(time, style: TextStyle(fontSize: 12, color: mutedColor)),
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
            border: Border.all(color: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(gradient: DesignTokens.instaGradient, shape: BoxShape.circle, boxShadow: [BoxShadow(color: DesignTokens.instaPink.withAlpha(80), blurRadius: 8)]),
                child: Icon(LucideIcons.wallet, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Balance', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600)),
                  Text('$balance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: fgColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
