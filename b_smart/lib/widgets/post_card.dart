import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/feed_post_model.dart';
import '../services/video_pool.dart';
import '../utils/url_helper.dart';
import 'dynamic_media_widget.dart';

/// Instagram-style post card with jank-free media rendering.
/// Media aspect ratios are resolved once and cached globally via DynamicMediaWidget.
class PostCard extends StatefulWidget {
  final FeedPost post;
  final bool isTabActive;
  final bool isActive; // supplied by parent center detection
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;
  final VoidCallback? onUserTap;
  final VoidCallback? onDoubleTapLike;

  const PostCard({
    super.key,
    required this.post,
    this.isTabActive = true,
    this.isActive = true,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onFollow,
    this.onMore,
    this.onUserTap,
    this.onDoubleTapLike,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showDoubleTapLike = false;
  Timer? _doubleTapLikeTimer;
  bool _isMuted = VideoPool.instance.isMuted;

  bool get _isVideo =>
      widget.post.mediaType == PostMediaType.video ||
      widget.post.mediaType == PostMediaType.reel;

  @override
  void dispose() {
    _doubleTapLikeTimer?.cancel();
    super.dispose();
  }

  void _handleDoubleTap() {
    widget.onDoubleTapLike?.call();
    _doubleTapLikeTimer?.cancel();
    setState(() => _showDoubleTapLike = true);
    _doubleTapLikeTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showDoubleTapLike = false);
    });
  }

  void _toggleMuted() {
    final next = !_isMuted;
    setState(() => _isMuted = next);
    unawaited(VideoPool.instance.setMuted(next));
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(post, isDark, theme),
          RepaintBoundary(
            child: Stack(
              children: [
                DynamicMediaWidget(
                  id: post.id,
                  url: post.mediaUrls.first,
                  thumbnailUrl: post.thumbnailUrl,
                  isVideo: _isVideo,
                  isActive: widget.isActive && widget.isTabActive,
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onDoubleTap: _handleDoubleTap,
                      onTap: _isVideo ? null : widget.onComment,
                    ),
                  ),
                ),
                if (_isVideo)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: _toggleMuted,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: _showDoubleTapLike ? 1 : 0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 260),
                          scale: _showDoubleTapLike ? 1 : 0.6,
                          curve: Curves.easeOutBack,
                          child: const Icon(
                            Icons.favorite,
                            size: 90,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 14,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildActionBar(post, theme),
          _buildPostDetails(post, theme),
        ],
      ),
    );
  }

  Widget _buildHeader(FeedPost post, bool isDark, ThemeData theme) {
    final avatarUrl =
        post.userAvatar != null ? UrlHelper.absoluteUrl(post.userAvatar!) : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onUserTap,
            child: Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFACC15),
                    Color(0xFFF97316),
                    Color(0xFFEC4899)
                  ],
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.scaffoldBackgroundColor,
                ),
                padding: const EdgeInsets.all(1),
                child: CircleAvatar(
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  backgroundColor:
                      isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade200,
                  child: avatarUrl.isEmpty
                      ? Text(
                          post.userName.isNotEmpty
                              ? post.userName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: widget.onUserTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    post.userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.isAd)
                    Text(
                      'Sponsored',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (!post.isAd &&
                      post.fullName != null &&
                      post.fullName!.trim().isNotEmpty)
                    Text(
                      post.fullName!,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          Text(
            _formatTimestamp(post.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(width: 4),
          if (widget.onMore != null)
            GestureDetector(
              onTap: widget.onMore,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(LucideIcons.ellipsis, size: 18),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar(FeedPost post, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            iconSize: 22,
            icon: Icon(
              post.isLiked ? Icons.favorite : LucideIcons.heart,
              color: post.isLiked ? Colors.red : null,
            ),
            onPressed: widget.onLike,
          ),
          IconButton(
            iconSize: 22,
            icon: const Icon(LucideIcons.messageCircle),
            onPressed: widget.onComment,
          ),
          IconButton(
            iconSize: 22,
            icon: const Icon(LucideIcons.send),
            onPressed: widget.onShare,
          ),
          const Spacer(),
          if (widget.onFollow != null)
            GestureDetector(
              onTap: widget.onFollow,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    Icon(
                      post.isFollowed
                          ? LucideIcons.userCheck
                          : LucideIcons.userPlus,
                      size: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.isFollowed ? 'Following' : 'Follow',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            iconSize: 22,
            icon: Icon(
              post.isSaved ? Icons.bookmark : LucideIcons.bookmark,
            ),
            onPressed: widget.onSave,
          ),
        ],
      ),
    );
  }

  Widget _buildPostDetails(FeedPost post, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${post.likes} likes',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          if (post.isAd && post.adTitle != null && post.adTitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              post.adTitle!.trim(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
          if (post.caption != null && post.caption!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              children: [
                GestureDetector(
                  onTap: widget.onUserTap,
                  child: Text(
                    '${post.userName} ',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Text(
                  post.caption!,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
          if (post.comments > 1) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: widget.onComment,
              child: Text(
                'View all ${post.comments >= 1000 ? '${(post.comments / 1000).toStringAsFixed(1)}K' : post.comments} comments',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
          if (post.latestCommentText != null && post.latestCommentText!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(
                    text: '${(post.latestCommentUser ?? post.userName).trim()} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: post.latestCommentText!.trim(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(post.createdAt).toUpperCase(),
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10.5,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
