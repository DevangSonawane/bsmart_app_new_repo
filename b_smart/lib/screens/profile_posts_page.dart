import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/feed_post_model.dart';
import '../widgets/post_card.dart';
import '../widgets/posts_grid.dart';
import '../widgets/safe_network_image.dart';
import '../utils/url_helper.dart';

class ProfilePostsPage extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final Map<String, String>? avatarHeaders;
  final List<FeedPost> posts;
  final List<FeedPost> reels;
  final List<FeedPost> tweets;
  final List<FeedPost> promotes;
  final bool isMe;
  final bool isValidated;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final int initialTab;

  const ProfilePostsPage({
    super.key,
    required this.profile,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.avatarHeaders,
    required this.posts,
    required this.reels,
    this.tweets = const <FeedPost>[],
    this.promotes = const <FeedPost>[],
    required this.isMe,
    required this.isValidated,
    required this.onBack,
    required this.onMenu,
    this.initialTab = 0,
  });

  String _title() {
    final displayName = fullName?.trim().isNotEmpty == true
        ? fullName!.trim()
        : username.trim();
    return displayName.isNotEmpty ? displayName : 'Profile';
  }

  void _openPost(BuildContext context, FeedPost post) {
    if (post.id.trim().isEmpty) return;
    Navigator.of(context).pushNamed('/post/${post.id}');
  }

  Widget _buildEmptyState({
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              emptyIcon,
              size: 48,
              color: Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              emptyTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsGrid(BuildContext context) {
    if (posts.isEmpty) {
      return _buildEmptyState(
        emptyTitle: 'No posts yet',
        emptySubtitle: 'Posts will appear here once they are published.',
        emptyIcon: LucideIcons.grid2x2,
      );
    }

    return PostsGrid(
      posts: posts,
      backgroundColor: Colors.black,
      onTap: (post) => _openPost(context, post),
    );
  }

  Widget _buildBSparksGrid(BuildContext context) {
    if (reels.isEmpty) {
      return _buildEmptyState(
        emptyTitle: 'No bSparks yet',
        emptySubtitle: 'bSparks will appear here once they are published.',
        emptyIcon: LucideIcons.clapperboard,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: reels.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) {
        final post = reels[index];
        return _MediaPillCard(
          post: post,
          icon: LucideIcons.play,
          onTap: () => _openPost(context, post),
        );
      },
    );
  }

  Widget _buildBuzzList(BuildContext context) {
    if (tweets.isEmpty) {
      return _buildEmptyState(
        emptyTitle: 'No Buzz yet',
        emptySubtitle: 'Buzz posts will appear here once they are published.',
        emptyIcon: LucideIcons.messageCircle,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: tweets.length,
      itemBuilder: (context, index) {
        final tweet = tweets[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PostCard(
            post: tweet,
            isOwnPost: isMe,
            onComment: () =>
                Navigator.of(context).pushNamed('/post/${tweet.id}?type=tweet'),
            onUserTap: () {},
          ),
        );
      },
    );
  }

  Widget _buildCampaignsList(BuildContext context) {
    if (promotes.isEmpty) {
      return _buildEmptyState(
        emptyTitle: 'No campaigns yet',
        emptySubtitle: 'Campaigns will appear here once they are published.',
        emptyIcon: LucideIcons.sparkles,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: promotes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final post = promotes[index];
        return _CampaignContentCard(
          post: post,
          onTap: () => _openPost(context, post),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _title();

    return DefaultTabController(
      length: 4,
      initialIndex: initialTab.clamp(0, 3),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.92),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (isValidated)
                const Icon(
                  Icons.verified_rounded,
                  color: ProfilePostsPage._gold,
                  size: 18,
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: onMenu,
            ),
          ],
          bottom: const TabBar(
            indicatorColor: ProfilePostsPage._gold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            padding: EdgeInsets.symmetric(horizontal: 12),
            labelPadding: EdgeInsets.symmetric(horizontal: 16),
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            unselectedLabelStyle:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Posts'),
              Tab(text: 'bSparks'),
              Tab(text: 'Buzz'),
              Tab(text: 'Campaigns'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _buildPostsGrid(context),
              _buildBSparksGrid(context),
              _buildBuzzList(context),
              _buildCampaignsList(context),
            ],
          ),
        ),
      ),
    );
  }

  static const Color _gold = Color(0xFFD4AF37);
}

class _MediaPillCard extends StatelessWidget {
  final FeedPost post;
  final IconData icon;
  final VoidCallback onTap;

  const _MediaPillCard({
    required this.post,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbFor(post);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: thumb.isEmpty
                  ? _mediaFallback(icon)
                  : SafeNetworkImage(
                      url: thumb,
                      fit: BoxFit.cover,
                      debugLabel: 'profile-full-media-pill',
                      placeholder: _mediaFallback(icon),
                      errorWidget: _mediaFallback(icon),
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 88,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      Colors.black.withValues(alpha: 0.74),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignContentCard extends StatelessWidget {
  final FeedPost post;
  final VoidCallback onTap;

  const _CampaignContentCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final thumb = _thumbFor(post);
    final caption = post.caption?.trim().isNotEmpty == true
        ? post.caption!.trim()
        : 'Campaign';
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: thumb.isEmpty
                    ? _mediaFallback(LucideIcons.sparkles)
                    : SafeNetworkImage(
                        url: thumb,
                        fit: BoxFit.cover,
                        debugLabel: 'profile-full-campaign',
                        placeholder: _mediaFallback(LucideIcons.sparkles),
                        errorWidget: _mediaFallback(LucideIcons.sparkles),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Campaign',
                        style: TextStyle(
                          color: ProfilePostsPage._gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${post.likes} likes • ${post.comments} comments',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  LucideIcons.chevronRight,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _mediaFallback(IconData icon) {
  return ColoredBox(
    color: Colors.white.withValues(alpha: 0.06),
    child: Center(
      child: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.42),
        size: 34,
      ),
    ),
  );
}

String _thumbFor(FeedPost post) {
  final raw = post.thumbnailUrl?.trim().isNotEmpty == true
      ? post.thumbnailUrl!.trim()
      : post.mediaUrls.isNotEmpty
          ? post.mediaUrls.first.trim()
          : '';
  return UrlHelper.normalizeUrl(raw);
}
