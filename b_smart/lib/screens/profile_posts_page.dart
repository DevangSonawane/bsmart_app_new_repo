import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/feed_post_model.dart';
import '../widgets/posts_grid.dart';

class ProfilePostsPage extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final Map<String, String>? avatarHeaders;
  final List<FeedPost> posts;
  final List<FeedPost> reels;
  final bool isMe;
  final bool isValidated;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;

  const ProfilePostsPage({
    super.key,
    required this.profile,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.avatarHeaders,
    required this.posts,
    required this.reels,
    required this.isMe,
    required this.isValidated,
    required this.onBack,
    required this.onMenu,
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

  Widget _buildGrid(BuildContext context, List<FeedPost> items,
      {required bool reelsMode}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                reelsMode ? LucideIcons.clapperboard : LucideIcons.grid2x2,
                size: 48,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 12),
              Text(
                reelsMode ? 'No reels yet' : 'No posts yet',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                reelsMode
                    ? 'Reels will appear here once they are published.'
                    : 'Posts will appear here once they are published.',
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

    return PostsGrid(
      posts: items,
      onTap: (post) => _openPost(context, post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _title();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.92),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: onBack,
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
            tabs: [
              Tab(text: 'Posts'),
              Tab(text: 'Reels'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: [
              _buildGrid(context, posts, reelsMode: false),
              _buildGrid(context, reels, reelsMode: true),
            ],
          ),
        ),
      ),
    );
  }

  static const Color _gold = Color(0xFFD4AF37);
}