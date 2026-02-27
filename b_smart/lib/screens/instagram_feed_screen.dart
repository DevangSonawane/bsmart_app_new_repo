import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import '../models/feed_post_model.dart';
import '../models/story_model.dart';
import '../services/feed_service.dart';
import '../services/wallet_service.dart';
import '../services/supabase_service.dart';
import '../services/user_account_service.dart';
import '../models/user_account_model.dart';
import '../utils/current_user.dart';
import '../theme/instagram_theme.dart';
import '../widgets/clay_container.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'story_viewer_screen.dart';
import 'wallet_screen.dart';
import 'boost_post_screen.dart';

class InstagramFeedScreen extends StatefulWidget {
  const InstagramFeedScreen({super.key});

  @override
  State<InstagramFeedScreen> createState() => _InstagramFeedScreenState();
}

class _InstagramFeedScreenState extends State<InstagramFeedScreen> {
  final FeedService _feedService = FeedService();
  final WalletService _walletService = WalletService();
  final SupabaseService _supabase = SupabaseService();
  
  final ScrollController _scrollController = ScrollController();
  bool _isHeaderVisible = true;
  double _lastScrollOffset = 0;
  
  List<FeedPost> _feedPosts = [];
  List<StoryGroup> _stories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    if (currentOffset > _lastScrollOffset && currentOffset > 50) {
      if (_isHeaderVisible) setState(() => _isHeaderVisible = false);
    } else if (currentOffset < _lastScrollOffset) {
      if (!_isHeaderVisible) setState(() => _isHeaderVisible = true);
    }
    _lastScrollOffset = currentOffset;
    if (currentOffset >= _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    final uid = await CurrentUser.id;
    final posts = await _feedService.fetchFeedFromBackend(
      limit: 20,
      offset: 0,
      currentUserId: uid,
    );
    final stories = await _feedService.fetchStoriesFeed();
    setState(() {
      _feedPosts = posts;
      _stories = stories;
      _isLoading = false;
    });
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final uid = await CurrentUser.id;
    final morePosts = await _feedService.fetchFeedFromBackend(
      limit: 20,
      offset: _feedPosts.length,
      currentUserId: uid,
    );
    setState(() {
      _feedPosts.addAll(morePosts);
      _isLoadingMore = false;
    });
  }

  Future<void> _handleLike(FeedPost post) async {
    final desired = !post.isLiked;
    setState(() {
      final index = _feedPosts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        final prev = _feedPosts[index];
        _feedPosts[index] = prev.copyWith(
          isLiked: desired,
          likes: desired ? prev.likes + 1 : prev.likes - 1,
        );
      }
    });
    final liked = await _supabase.setPostLike(post.id, like: desired);
    if (!mounted) return;
    setState(() {
      final index = _feedPosts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        final prev = _feedPosts[index];
        _feedPosts[index] = prev.copyWith(
          isLiked: liked,
          likes: liked ? prev.likes : prev.likes, // likes already adjusted optimistically; keep if server agrees
        );
      }
    });
  }

  Future<void> _handleSave(FeedPost post) async {
    final desired = !post.isSaved;
    setState(() {
      final index = _feedPosts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        final prev = _feedPosts[index];
        _feedPosts[index] = prev.copyWith(isSaved: desired);
      }
    });
    final saved = await _supabase.setPostSaved(post.id, save: desired);
    if (!mounted) return;
    try {
      final data = await _supabase.getPostById(post.id);
      final serverSaved = (data?['is_saved_by_me'] as bool?) ?? saved;
      setState(() {
        final index = _feedPosts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          final prev = _feedPosts[index];
          _feedPosts[index] = prev.copyWith(isSaved: serverSaved);
        }
      });
    } catch (_) {
      setState(() {
        final index = _feedPosts.indexWhere((p) => p.id == post.id);
        if (index != -1) {
          final prev = _feedPosts[index];
          _feedPosts[index] = prev.copyWith(isSaved: saved);
        }
      });
    }
  }

  void _handleFollow(FeedPost post) {
    setState(() {
      final index = _feedPosts.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        _feedPosts[index] = _feedService.toggleFollow(post);
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(InstagramTheme.primaryPink),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFeed,
              color: InstagramTheme.primaryPink,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    floating: false,
                    pinned: true,
                    snap: false,
                    backgroundColor: InstagramTheme.backgroundWhite,
                    elevation: 0,
                    toolbarHeight: 56,
                    leading: _buildProfileIcon(),
                    title: _buildSearchBar(),
                    actions: _buildHeaderActions(),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(72),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: _buildLocationSelector(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildStoriesSection()),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < _feedPosts.length) {
                          return _buildPostCard(_feedPosts[index]);
                        } else if (_isLoadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(InstagramTheme.primaryPink),
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                      childCount: _feedPosts.length + (_isLoadingMore ? 1 : 0),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLocationSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        // TODO: hook up location picker.
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: InstagramTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: InstagramTheme.borderGrey),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: InstagramTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: InstagramTheme.textBlack,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOME',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: InstagramTheme.textGrey,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Plot No.20, 2nd Floor, Shivaram Nivas',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: InstagramTheme.textBlack,
                          fontWeight: FontWeight.w600,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: InstagramTheme.textGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileIcon() {
    final user = _feedService.getCurrentUser();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      },
      child: Center(
        child: ClayContainer(
          width: 36,
          height: 36,
          borderRadius: 18,
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.transparent,
            child: Text(
              user.name[0].toUpperCase(),
              style: const TextStyle(
                color: InstagramTheme.primaryPink,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ClayContainer(
        borderRadius: 20,
        color: InstagramTheme.surfaceWhite,
        child: TextField(
          style: const TextStyle(color: InstagramTheme.textBlack),
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: TextStyle(color: InstagramTheme.textGrey.withValues(alpha: 0.5)),
            prefixIcon: const Icon(Icons.search, size: 20, color: InstagramTheme.textGrey),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHeaderActions() {
    return [
      IconButton(
        icon: const Icon(Icons.favorite_border, color: InstagramTheme.textBlack),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const NotificationsScreen()),
          );
        },
      ),
      Center(
        child: Padding(
          padding: const EdgeInsets.only(right: 16, left: 8),
          child: ClayContainer(
            height: 32,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.coins, color: InstagramTheme.primaryPink, size: 16),
                    const SizedBox(height: 2),
                    FutureBuilder<int>(
                      future: _walletService.getCoinBalance(),
                      initialData: 0,
                      builder: (context, snapshot) {
                        return Text(
                          '${snapshot.data ?? 0}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: InstagramTheme.textBlack,
                            fontSize: 11,
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildStoriesSection() {
    if (_stories.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _stories.length,
        itemBuilder: (context, index) => _buildStoryItem(_stories[index]),
      ),
    );
  }

  Widget _buildStoryItem(StoryGroup storyGroup) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StoryViewerScreen(
              storyGroups: _stories,
              initialIndex: _stories.indexOf(storyGroup),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                ClayContainer(
                  width: 74,
                  height: 74,
                  borderRadius: 37,
                  color: InstagramTheme.surfaceWhite,
                  child: Center(
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: NetworkImage('https://via.placeholder.com/150'), // Replace with actual
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          storyGroup.userName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: InstagramTheme.surfaceWhite, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              storyGroup.userName.split(' ').first,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(FeedPost post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      child: ClayContainer(
        borderRadius: 24,
        color: InstagramTheme.surfaceWhite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(post),
            _buildMediaSection(post),
            _buildActionBar(post),
            if (post.likes > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${post.likes} likes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (post.caption != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: RichText(
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyLarge,
                    children: [
                      TextSpan(
                        text: '${post.userName} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: post.caption),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(FeedPost post) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: post.userId.isNotEmpty
                  ? () => Navigator.of(context).pushNamed('/profile/${post.userId}')
                  : null,
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: InstagramTheme.dividerGrey,
                    child: Text(
                      post.userName.isNotEmpty ? post.userName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: InstagramTheme.primaryPink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          post.userName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (post.isAd) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Sponsored',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 11,
                              color: InstagramTheme.primaryPink,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: InstagramTheme.textGrey, size: 24),
            onPressed: () => _showMoreOptions(context, post),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(FeedPost post) {
    return Container(
      height: 300,
      width: double.infinity,
      color: InstagramTheme.dividerGrey,
      child: const Center(
        child: Icon(Icons.image, size: 60, color: InstagramTheme.textGrey),
      ),
    );
  }

  Widget _buildActionBar(FeedPost post) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              post.isLiked ? Icons.favorite : Icons.favorite_border,
              color: post.isLiked ? InstagramTheme.errorRed : InstagramTheme.textBlack,
              size: 28,
            ),
            onPressed: () => _handleLike(post),
          ),
          IconButton(
            icon: const Icon(Icons.comment_outlined, color: InstagramTheme.textBlack, size: 28),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined, color: InstagramTheme.textBlack, size: 28),
            onPressed: () {},
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              post.isFollowed ? Icons.person_add_alt_1 : Icons.person_add_alt_1_outlined,
              color: post.isFollowed ? InstagramTheme.primaryPink : InstagramTheme.textBlack,
              size: 28,
            ),
            onPressed: () => _handleFollow(post),
          ),
          IconButton(
            icon: Icon(
              post.isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: post.isSaved ? InstagramTheme.primaryPink : InstagramTheme.textBlack,
              size: 28,
            ),
            onPressed: () => _handleSave(post),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context, FeedPost post) {
    final accountService = UserAccountService();
    final currentAccount = accountService.getCurrentAccount();
    final canBoost = currentAccount.accountType != AccountType.regular;
    final messenger = ScaffoldMessenger.of(this.context);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canBoost)
              ListTile(
                leading: const Icon(Icons.trending_up),
                title: const Text('Boost Post'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => BoostPostScreen(
                        postId: post.id,
                        contentType: 'post',
                      ),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.report),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                messenger.showSnackBar(const SnackBar(content: Text('Report submitted')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.not_interested),
              title: const Text('Not Interested'),
              onTap: () {
                Navigator.pop(context);
                messenger.showSnackBar(const SnackBar(content: Text('We\'ll show you less like this')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
