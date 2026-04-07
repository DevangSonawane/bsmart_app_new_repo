import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';

import '../models/feed_post_model.dart';
import '../services/video_pool.dart';
import '../utils/url_helper.dart';
import 'dynamic_media_widget.dart';
import 'safe_network_image.dart';

/// Instagram-style post card with jank-free media rendering.
/// Media aspect ratios are resolved once and cached globally via DynamicMediaWidget.
class PostCard extends StatefulWidget {
  final FeedPost post;
  final bool isTabActive;
  final bool isActive; // supplied by parent center detection
  final ValueListenable<String?>? activeIdListenable;
  final bool isOwnPost;
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
    this.activeIdListenable,
    this.isOwnPost = false,
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
  bool _showPeopleTags = false;
  final PageController _pageController = PageController();
  int _mediaIndex = 0;

  bool get _isCarousel => widget.post.mediaUrls.length > 1;

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m3u8') ||
        lower.contains('.mp4?') ||
        lower.contains('.mov?') ||
        lower.contains('.m3u8?');
  }

  bool get _isSingleVideo =>
      !_isCarousel &&
      (widget.post.mediaType == PostMediaType.video ||
          widget.post.mediaType == PostMediaType.reel);

  @override
  void dispose() {
    _doubleTapLikeTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _mediaIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        });
      }
    }
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

  void _togglePeopleTags() {
    if ((widget.post.peopleTags?.isNotEmpty ?? false) == false) return;
    setState(() => _showPeopleTags = !_showPeopleTags);
  }

  String _tagUsername(Map<String, dynamic> t) {
    final direct =
        (t['username'] ?? t['user_name'] ?? t['userName'])?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final user = t['user'];
    if (user is Map) {
      final u = Map<String, dynamic>.from(user);
      final name =
          (u['username'] ?? u['user_name'] ?? u['userName'])?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    return '';
  }

  String _formatTargetList(List<String> items) {
    final clean = items.where((e) => e.trim().isNotEmpty).toList();
    if (clean.isEmpty) return '';
    final shown = clean.take(3).toList();
    final more = clean.length > 3 ? '…' : '';
    return '${shown.join(', ')}$more';
  }

  Offset? _tagOffset(Map<String, dynamic> t, Size size) {
    if (size.width <= 0 || size.height <= 0) return null;
    final xAny = t['x'] ?? t['pos_x'] ?? t['position_x'];
    final yAny = t['y'] ?? t['pos_y'] ?? t['position_y'];
    if (xAny is! num || yAny is! num) return null;
    final x = xAny.toDouble().clamp(0.0, 1.0);
    final y = yAny.toDouble().clamp(0.0, 1.0);
    return Offset(x * size.width, y * size.height);
  }

  List<Map<String, dynamic>> _tagsForMediaIndex(int index) {
    final raw = widget.post.peopleTags ?? const [];
    final withIndex = raw.where((t) {
      final map = Map<String, dynamic>.from(t);
      final idxAny = map['mediaIndex'] ?? map['media_index'] ?? map['index'];
      if (idxAny is num) {
        return idxAny.toInt() == index;
      }
      return false;
    }).toList();
    if (withIndex.isNotEmpty) return withIndex;
    return raw.map((t) => Map<String, dynamic>.from(t)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaUrls = post.mediaUrls;
    final isCarousel = _isCarousel;
    final aspect = post.aspectRatio ?? 4 / 5;
    final mediaFilters = post.mediaFilters;
    final mediaAdjustments = post.mediaAdjustments;
    String? _filterForIndex(int index) {
      if (mediaFilters == null || index < 0 || index >= mediaFilters.length) {
        return null;
      }
      return mediaFilters[index];
    }

    Map<String, int>? _adjustmentsForIndex(int index) {
      if (mediaAdjustments == null ||
          index < 0 ||
          index >= mediaAdjustments.length) {
        return null;
      }
      return mediaAdjustments[index];
    }

    final activeListenable = widget.activeIdListenable;
    final tabActive = widget.isTabActive;
    final singleIsVideo = _isSingleVideo ||
        (!_isCarousel && mediaUrls.isNotEmpty && _isVideoUrl(mediaUrls.first));
    final activeIsVideo = isCarousel
        ? (mediaUrls.isNotEmpty && _mediaIndex < mediaUrls.length
            ? _isVideoUrl(mediaUrls[_mediaIndex])
            : false)
        : singleIsVideo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(post, isDark, theme),
        Stack(
          children: [
            if (mediaUrls.isEmpty)
              AspectRatio(
                aspectRatio: aspect,
                child: const ColoredBox(
                  color: Colors.black12,
                  child: Center(
                    child: Icon(Icons.broken_image, color: Colors.white70),
                  ),
                ),
              )
            else if (!isCarousel)
              activeListenable == null
                  ? RepaintBoundary(
                      child: DynamicMediaWidget(
                        id: post.id,
                        url: mediaUrls.first,
                        thumbnailUrl: post.thumbnailUrl,
                        isVideo: singleIsVideo,
                        isActive: widget.isActive && tabActive,
                        initialAspectRatio: post.aspectRatio,
                        filterName: _filterForIndex(0),
                        adjustments: _adjustmentsForIndex(0),
                      ),
                    )
                  : ValueListenableBuilder<String?>(
                      valueListenable: activeListenable,
                      builder: (context, activeId, _) {
                        final isActive = activeId == post.id && tabActive;
                        return RepaintBoundary(
                          child: DynamicMediaWidget(
                            id: post.id,
                            url: mediaUrls.first,
                            thumbnailUrl: post.thumbnailUrl,
                            isVideo: singleIsVideo,
                            isActive: isActive,
                            initialAspectRatio: post.aspectRatio,
                            filterName: _filterForIndex(0),
                            adjustments: _adjustmentsForIndex(0),
                          ),
                        );
                      },
                    )
            else
              AspectRatio(
                aspectRatio: aspect,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: mediaUrls.length,
                  onPageChanged: (i) {
                    setState(() => _mediaIndex = i);
                  },
                  itemBuilder: (context, i) {
                    final url = mediaUrls[i];
                    final isVideo = _isVideoUrl(url);
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: _handleDoubleTap,
                      onTap: () {
                        if (_showPeopleTags) {
                          setState(() => _showPeopleTags = false);
                          return;
                        }
                        widget.onComment?.call();
                      },
                      onLongPress: _togglePeopleTags,
                      child: activeListenable == null
                          ? RepaintBoundary(
                              child: DynamicMediaWidget(
                                id: '${post.id}_$i',
                                url: url,
                                thumbnailUrl: post.thumbnailUrl,
                                isVideo: isVideo,
                                isActive: widget.isActive &&
                                    tabActive &&
                                    _mediaIndex == i,
                                initialAspectRatio: post.aspectRatio,
                                filterName: _filterForIndex(i),
                                adjustments: _adjustmentsForIndex(i),
                              ),
                            )
                          : ValueListenableBuilder<String?>(
                              valueListenable: activeListenable,
                              builder: (context, activeId, _) {
                                final isActive = activeId == post.id &&
                                    tabActive &&
                                    _mediaIndex == i;
                                return RepaintBoundary(
                                  child: DynamicMediaWidget(
                                    id: '${post.id}_$i',
                                    url: url,
                                    thumbnailUrl: post.thumbnailUrl,
                                    isVideo: isVideo,
                                    isActive: isActive,
                                    initialAspectRatio: post.aspectRatio,
                                    filterName: _filterForIndex(i),
                                    adjustments: _adjustmentsForIndex(i),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
              ),
            if (isCarousel)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    mediaUrls.length,
                    (i) {
                      final active = i == _mediaIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: active ? 10 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (post.isAd)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'AD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            if (_showPeopleTags && (post.peopleTags?.isNotEmpty ?? false))
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.biggest;
                      final tags = _tagsForMediaIndex(_mediaIndex);
                      return Stack(
                        children: [
                          for (final raw in tags)
                            () {
                              final t = Map<String, dynamic>.from(raw);
                              final name = _tagUsername(t);
                              final pos = _tagOffset(t, size);
                              if (name.isEmpty || pos == null) {
                                return const SizedBox.shrink();
                              }
                              return Positioned(
                                left: pos.dx - 8,
                                top: pos.dy - 34,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              );
                            }(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            if (!isCarousel)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onDoubleTap: _handleDoubleTap,
                    onTap: activeIsVideo
                        ? null
                        : () {
                            if (_showPeopleTags) {
                              setState(() => _showPeopleTags = false);
                              return;
                            }
                            widget.onComment?.call();
                          },
                    onLongPress: activeIsVideo ? null : _togglePeopleTags,
                  ),
                ),
              ),
            if (post.peopleTags?.isNotEmpty ?? false)
              Positioned(
                bottom: 10,
                left: 10,
                child: GestureDetector(
                  onTap: _togglePeopleTags,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            if (activeIsVideo)
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
        _buildActionBar(post, theme),
        _buildPostDetails(post, theme),
      ],
    );
  }

  Widget _buildHeader(FeedPost post, bool isDark, ThemeData theme) {
    final avatarUrl =
        post.userAvatar != null ? UrlHelper.absoluteUrl(post.userAvatar!) : '';
    final fullName = (post.fullName ?? '').trim();
    final adCompany = (post.adCompanyName ?? '').trim();
    final subtitleName = fullName.isNotEmpty
        ? fullName
        : (post.isAd && adCompany.isNotEmpty && adCompany != post.userName
            ? adCompany
            : '');
    final location = (post.location ?? '').trim();
    final primaryText =
        theme.brightness == Brightness.dark ? Colors.white : Colors.black;
    final secondaryText = theme.brightness == Brightness.dark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
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
                  backgroundColor:
                      isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade200,
                  child: avatarUrl.isEmpty
                      ? Text(
                          post.userName.isNotEmpty
                              ? post.userName[0].toUpperCase()
                              : 'U',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        )
                      : ClipOval(
                          child: SafeNetworkImage(
                            url: avatarUrl,
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                            placeholder: const SizedBox.shrink(),
                            errorWidget: const SizedBox.shrink(),
                          ),
                        ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: primaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleName.isNotEmpty ||
                      location.isNotEmpty ||
                      post.isAd)
                    Row(
                      children: [
                        if (subtitleName.isNotEmpty)
                          Flexible(
                            child: Text(
                              subtitleName,
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (post.isAd) ...[
                          if (subtitleName.isNotEmpty)
                            Text(
                              ' · ',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryText,
                              ),
                            ),
                          Text(
                            'Sponsored',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (!post.isAd && location.isNotEmpty) ...[
                          if (subtitleName.isNotEmpty)
                            Text(
                              ' · ',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryText,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              location,
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
          Text(
            _formatTimestamp(post.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: secondaryText,
            ),
          ),
          if (post.isAd && post.totalBudgetCoins > 0) ...[
            const SizedBox(width: 8),
            _BudgetBadge(amount: post.totalBudgetCoins),
          ],
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
          if (!post.commentsDisabled)
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
    final primaryText =
        theme.brightness == Brightness.dark ? Colors.white : Colors.black;
    final secondaryText = theme.brightness == Brightness.dark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
    final accentBlue = theme.brightness == Brightness.dark
        ? const Color(0xFF60A5FA)
        : const Color(0xFF2563EB);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!post.hideLikesCount || widget.isOwnPost)
            Text(
              '${post.likes} likes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: primaryText,
              ),
            ),
          if (post.isAd) ...[
            if ((post.adCategory ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accentBlue.withValues(alpha: 0.35)),
                ),
                child: Text(
                  (post.adCategory ?? '').trim(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: accentBlue,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            if ((post.adCompanyName ?? '').trim().isNotEmpty ||
                (post.caption ?? '').trim().isNotEmpty)
              Wrap(
                children: [
                  if ((post.adCompanyName ?? '').trim().isNotEmpty)
                    Text(
                      '${post.adCompanyName!.trim()} ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: primaryText,
                      ),
                    ),
                  if ((post.caption ?? '').trim().isNotEmpty)
                    Text(
                      post.caption!.trim(),
                      style: TextStyle(fontSize: 13, color: primaryText),
                    ),
                ],
              ),
            const SizedBox(height: 4),
            if ((post.location ?? '').trim().isNotEmpty)
              Text(
                post.location!.trim(),
                style: TextStyle(
                  fontSize: 11,
                  color: secondaryText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            if ((post.targetLocations ?? const <String>[]).isNotEmpty ||
                (post.targetLanguages ?? const <String>[]).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    if ((post.targetLocations ?? const <String>[]).isNotEmpty)
                      Text(
                        '📍 ${_formatTargetList(post.targetLocations ?? const <String>[])}',
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryText,
                        ),
                      ),
                    if ((post.targetLanguages ?? const <String>[]).isNotEmpty)
                      Text(
                        '🌐 ${_formatTargetList(post.targetLanguages ?? const <String>[])}',
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
          ],
          if (!post.isAd &&
              post.caption != null &&
              post.caption!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              children: [
                GestureDetector(
                  onTap: widget.onUserTap,
                  child: Text(
                    '${post.userName} ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: primaryText,
                    ),
                  ),
                ),
                Text(
                  post.caption!,
                  style: TextStyle(fontSize: 13, color: primaryText),
                ),
              ],
            ),
          ],
          if (!post.isAd && !post.commentsDisabled && post.comments > 1) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: widget.onComment,
              child: Text(
                'View all ${post.comments >= 1000 ? '${(post.comments / 1000).toStringAsFixed(1)}K' : post.comments} comments',
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryText,
                ),
              ),
            ),
          ],
          if (!post.isAd &&
              !post.commentsDisabled &&
              post.latestCommentText != null &&
              post.latestCommentText!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(
                    text:
                        '${(post.latestCommentUser ?? post.userName).trim()} ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: post.latestCommentText!.trim(),
                    style: TextStyle(
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (post.isAd && post.views > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${post.views >= 1000000 ? '${(post.views / 1000000).toStringAsFixed(1)}M' : post.views >= 1000 ? '${(post.views / 1000).toStringAsFixed(1)}K' : post.views} views',
              style: TextStyle(
                fontSize: 11,
                color: secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatTimestamp(post.createdAt).toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF8A8A8A),
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
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _BudgetBadge extends StatelessWidget {
  final int amount;

  const _BudgetBadge({required this.amount});

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.brightness == Brightness.dark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.coins, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            _fmt(amount),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
