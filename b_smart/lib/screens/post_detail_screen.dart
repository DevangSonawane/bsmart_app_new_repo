import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import '../services/supabase_service.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../api/api_exceptions.dart';
import '../config/api_config.dart';
import '../api/api_client.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../state/app_state.dart';
import '../state/feed_actions.dart';
import '../models/feed_post_model.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final FeedPost? initialPost;

  const PostDetailScreen({super.key, required this.postId, this.initialPost});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final SupabaseService _svc = SupabaseService();
  Map<String, dynamic>? _post;
  Map<String, dynamic>? _postUser;
  List<Map<String, dynamic>> _comments = [];
  final Map<String, List<Map<String, dynamic>>> _replies = {};
  final Set<String> _expandedComments = <String>{};
  final Set<String> _loadingReplies = <String>{};
  bool _loadingPost = true;
  bool _loadingComments = true;
  final _commentController = TextEditingController();
  bool _isLiked = false;
  bool _postingComment = false;
  String? _currentUserId;
  bool _isAuthorFollowed = false;
  bool _followLoading = false;
  String? _replyParentId;
  String? _replyingTo;
  final PageController _mediaPageController = PageController();
  int _currentMediaIndex = 0;
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoLoading = false;
  String? _activeVideoUrl;

  String? _extractId(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      final id = value['id'] ?? value['_id'];
      if (id is String && id.isNotEmpty) return id;
      if (id != null) return id.toString();
    }
    return null;
  }

  Map<String, dynamic>? _extractUserMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _mediaPageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final initial = widget.initialPost;
    Map<String, dynamic>? eagerPost = _post;
    Map<String, dynamic>? eagerUser = _postUser;
    bool eagerLiked = _isLiked;
    bool eagerFollowed = _isAuthorFollowed;
    String? meId = _currentUserId;

    if (eagerPost == null && initial != null) {
      eagerPost = {
        'id': initial.id,
        'user_id': initial.userId,
        'caption': initial.caption,
        'created_at': initial.createdAt.toIso8601String(),
        'media': initial.mediaUrls.map((u) => {'url': u}).toList(),
        'likes_count': initial.likes,
        'is_liked_by_me': initial.isLiked,
        'is_saved_by_me': initial.isSaved,
        'is_followed_by_me': initial.isFollowed,
      };
      eagerUser = {
        'id': initial.userId,
        'username': initial.userName,
        'full_name': initial.fullName,
        'avatar_url': initial.userAvatar,
      };
      eagerLiked = initial.isLiked;
      eagerFollowed = initial.isFollowed;
    }

    meId ??= (await CurrentUser.id)?.toString();

    if (mounted) {
      setState(() {
        if (eagerPost != null) {
          _post = eagerPost;
          _postUser = eagerUser;
          _isLiked = eagerLiked;
          _isAuthorFollowed = eagerFollowed;
          _currentUserId = meId;
          _loadingPost = false;
        } else {
          _loadingPost = true;
        }
        _loadingComments = true;
      });
    }

    final post = await _svc.getPostById(widget.postId);
    if (post == null || !mounted) {
      if (mounted && _post == null) {
        setState(() => _loadingPost = false);
      }
      return;
    }
    final userId = _extractId(post['user_id']) ??
        _extractId(post['user']) ??
        _extractId(post['users']);
    Map<String, dynamic>? user = _extractUserMap(post['user']) ??
        _extractUserMap(post['users']) ??
        _extractUserMap(post['user_id']);
    if (userId != null) {
      final fetched = await _svc.getUserById(userId);
      if (fetched != null) user = fetched;
    }
    final comments = await _svc.getComments(widget.postId);
    final seededReplies = <String, List<Map<String, dynamic>>>{};
    final topLevelComments = <Map<String, dynamic>>[];
    for (final c in comments) {
      final cid = ((c['_id'] ?? c['id'])?.toString() ?? '').trim();
      final parentId =
          ((c['parent_id'] ?? c['parentId'])?.toString() ?? '').trim();
      if (parentId.isNotEmpty) {
        final bucket = seededReplies[parentId] ?? <Map<String, dynamic>>[];
        bucket.add(Map<String, dynamic>.from(c));
        seededReplies[parentId] = bucket;
        continue;
      }
      if (cid.isEmpty) {
        topLevelComments.add(Map<String, dynamic>.from(c));
        continue;
      }
      topLevelComments.add(Map<String, dynamic>.from(c));
      final inlineReplies = c['replies'];
      if (inlineReplies is List && inlineReplies.isNotEmpty) {
        seededReplies[cid] = inlineReplies
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    final likes = post['likes'] as List<dynamic>? ?? [];
    final currentUserId = await CurrentUser.id;
    bool isLiked = false;
    for (final e in likes) {
      if (e is Map) {
        String? uid = _extractId(e['user_id']) ??
            _extractId(e['id']) ??
            _extractId(e['_id']);
        if (uid == null && e['user'] is Map) {
          uid = _extractId(e['user']);
        }
        if (uid != null &&
            currentUserId != null &&
            uid.toString() == currentUserId.toString()) {
          isLiked = true;
          break;
        }
      } else if (e is String &&
          currentUserId != null &&
          e.toString() == currentUserId.toString()) {
        isLiked = true;
        break;
      }
    }
    final meId2 = currentUserId?.toString();
    bool isFollowed = (post['is_followed_by_me'] as bool?) ??
        (user?['is_followed_by_me'] as bool?) ??
        false;
    if (mounted) {
      setState(() {
        _post = post;
        _postUser = user;
        _comments = topLevelComments;
        _replies
          ..clear()
          ..addAll(seededReplies);
        _isLiked = isLiked;
        _loadingPost = false;
        _loadingComments = false;
        _currentUserId = meId2;
        _isAuthorFollowed = isFollowed;
      });
      _syncCurrentMediaPlayback();
      _prefetchRepliesForTopLevelComments(topLevelComments);
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    final userId = await CurrentUser.id;
    if (content.isEmpty || userId == null) return;
    final parentId = _replyParentId;
    setState(() => _postingComment = true);
    try {
      await _svc.addComment(widget.postId, userId, content, parentId: parentId);
      _commentController.clear();
      if (parentId != null && parentId.isNotEmpty) {
        _expandedComments.add(parentId);
      }
      _replyParentId = null;
      _replyingTo = null;
      await _load();
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  String _commentId(Map<String, dynamic> c) {
    return ((c['_id'] ?? c['id'])?.toString() ?? '').trim();
  }

  Map<String, dynamic> _commentUser(Map<String, dynamic> c) {
    final dynamic user = c['user'] ?? c['users'];
    if (user is Map) return Map<String, dynamic>.from(user);
    return <String, dynamic>{};
  }

  int _replyCount(Map<String, dynamic> c) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final direct = toInt(c['reply_count']);
    if (direct > 0) return direct;
    final repliesCount = toInt(c['replies_count']);
    if (repliesCount > 0) return repliesCount;
    final replyCountAlt = toInt(c['replyCount']);
    if (replyCountAlt > 0) return replyCountAlt;
    final repliesCountAlt = toInt(c['repliesCount']);
    if (repliesCountAlt > 0) return repliesCountAlt;
    return (c['replies'] is List) ? (c['replies'] as List).length : 0;
  }

  Future<void> _loadRepliesFor(String commentId) async {
    if (commentId.isEmpty || _loadingReplies.contains(commentId)) return;
    setState(() => _loadingReplies.add(commentId));
    final list = await _svc.getReplies(commentId, page: 1, limit: 50);
    if (!mounted) return;
    setState(() {
      _replies[commentId] = list;
      _loadingReplies.remove(commentId);
    });
  }

  Future<void> _prefetchRepliesForTopLevelComments(
      List<Map<String, dynamic>> comments) async {
    for (final c in comments) {
      final cid = _commentId(c);
      if (cid.isEmpty) continue;
      if (_loadingReplies.contains(cid)) continue;
      if ((_replies[cid]?.isNotEmpty ?? false)) continue;

      final list = await _svc.getReplies(cid, page: 1, limit: 50);
      if (!mounted) return;
      if (list.isEmpty) continue;
      setState(() {
        _replies[cid] = list;
      });
    }
  }

  Future<void> _toggleReplies(Map<String, dynamic> c) async {
    final cid = _commentId(c);
    if (cid.isEmpty) return;
    if (_expandedComments.contains(cid)) {
      setState(() => _expandedComments.remove(cid));
      return;
    }
    if (!(_replies[cid]?.isNotEmpty ?? false)) {
      await _loadRepliesFor(cid);
    }
    if (!mounted) return;
    setState(() => _expandedComments.add(cid));
  }

  void _startReplyTo(String commentId, String username) {
    if (commentId.isEmpty) return;
    setState(() {
      _replyParentId = commentId;
      _replyingTo = username;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyParentId = null;
      _replyingTo = null;
    });
  }

  void _onAuthorTap() {
    final userId = _extractId(_postUser?['id']) ??
        _extractId(_post?['user_id']) ??
        _extractId(_post?['user']) ??
        _extractId(_post?['users']);
    if (userId == null) return;
    Navigator.of(context).pushNamed('/profile/$userId');
  }

  Future<void> _toggleFollowAuthor() async {
    if (_followLoading) return;
    final targetId = _extractId(_postUser?['id']) ??
        _extractId(_post?['user_id']) ??
        _extractId(_post?['user']) ??
        _extractId(_post?['users']);
    final meId = _currentUserId;
    if (targetId == null ||
        targetId.isEmpty ||
        meId == null ||
        meId.isEmpty ||
        targetId == meId) {
      return;
    }
    setState(() => _followLoading = true);
    final desired = !_isAuthorFollowed;
    bool ok;
    if (desired) {
      ok = await _svc.followUser(targetId);
    } else {
      ok = await _svc.unfollowUser(targetId);
    }
    if (!mounted) return;
    setState(() {
      if (ok) {
        _isAuthorFollowed = desired;
      }
      _followLoading = false;
    });
  }

  static String _formatRelativeTime(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  static String _formatFullDate(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return '';
    return '${date.month} ${date.day}, ${date.year}';
  }

  String _absolute(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin =
        '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }

  List<dynamic> get _mediaItems {
    final media = _post?['media'] as List<dynamic>?;
    if (media != null && media.isNotEmpty) return media;
    final fallback = _post?['imageUrl'] as String?;
    if (fallback != null && fallback.isNotEmpty) return [fallback];
    return const [];
  }

  String _mediaUrl(dynamic item) {
    String? raw;
    if (item is Map && item.containsKey('image')) {
      raw = item['image'] as String?;
    }
    if (raw == null && item is Map && item.containsKey('url')) {
      raw = item['url'] as String?;
    }
    if (raw == null && item is Map && item.containsKey('fileUrl')) {
      raw = item['fileUrl'] as String?;
    }
    if (raw == null && item is Map && item.containsKey('file_url')) {
      raw = item['file_url'] as String?;
    }
    if (raw == null && item is String) {
      raw = item;
    }
    if (raw == null || raw.isEmpty) return '';
    return _absolute(raw);
  }

  bool _isVideoMedia(dynamic item) {
    final url = _mediaUrl(item).toLowerCase();
    final type = (item is Map ? item['type'] as String? : null)?.toLowerCase();
    return type == 'video' ||
        type == 'reel' ||
        url.endsWith('.mp4') ||
        url.endsWith('.mov') ||
        url.contains('.m3u8');
  }

  Future<void> _syncCurrentMediaPlayback() async {
    final media = _mediaItems;
    if (media.isEmpty || _currentMediaIndex >= media.length) {
      _currentMediaIndex = 0;
    }
    if (media.isEmpty) {
      _videoController?.dispose();
      _videoController = null;
      _activeVideoUrl = null;
      if (mounted) {
        setState(() {
          _videoReady = false;
          _videoLoading = false;
        });
      }
      return;
    }

    final item = media[_currentMediaIndex];
    if (!_isVideoMedia(item)) {
      _videoController?.pause();
      _videoController?.dispose();
      _videoController = null;
      _activeVideoUrl = null;
      if (mounted) {
        setState(() {
          _videoReady = false;
          _videoLoading = false;
        });
      }
      return;
    }

    final url = _mediaUrl(item);
    if (url.isEmpty) return;
    if (_activeVideoUrl == url &&
        _videoController?.value.isInitialized == true) {
      return;
    }

    final previous = _videoController;
    _videoController = null;
    _activeVideoUrl = url;
    if (mounted) {
      setState(() {
        _videoReady = false;
        _videoLoading = true;
      });
    }
    previous?.dispose();

    try {
      final token = await ApiClient().getToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();

      if (!mounted || _activeVideoUrl != url) {
        controller.dispose();
        return;
      }

      _videoController = controller;
      setState(() {
        _videoReady = true;
        _videoLoading = false;
      });
    } catch (_) {
      if (!mounted || _activeVideoUrl != url) return;
      setState(() {
        _videoReady = false;
        _videoLoading = false;
      });
    }
  }

  double _aspectRatioForItem(dynamic item) {
    if (item is Map && item['crop'] is Map) {
      final crop = item['crop'] as Map;
      final ratio = crop['aspect_ratio']?.toString();
      if (ratio == '1:1') return 1.0;
      if (ratio == '16:9') return 16 / 9;
      if (ratio == '9:16') return 9 / 16;
      if (ratio == '4:5') return 4 / 5;
    }
    return 4 / 5;
  }

  Widget _buildMediaSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final mediaBg = isDark ? Colors.black : Colors.grey.shade200;
    final mediaFg = isDark ? Colors.white : Colors.black;
    final media = _mediaItems;
    final currentItem = media.isNotEmpty
        ? media[_currentMediaIndex.clamp(0, media.length - 1)]
        : null;
    final aspectRatio = _aspectRatioForItem(currentItem);
    if (media.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(
          color: mediaBg,
          child: Icon(LucideIcons.imageOff,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _mediaPageController,
            itemCount: media.length,
            onPageChanged: (index) {
              setState(() {
                _currentMediaIndex = index;
              });
              _syncCurrentMediaPlayback();
            },
            itemBuilder: (_, index) {
              final item = media[index];
              final url = _mediaUrl(item);
              final isVideo = _isVideoMedia(item);
              if (url.isEmpty) {
                return Container(
                  color: mediaBg,
                  child: Icon(LucideIcons.imageOff,
                      size: 64,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                );
              }
              if (isVideo) {
                final isCurrent = index == _currentMediaIndex;
                final controller = _videoController;
                return Container(
                  color: mediaBg,
                  child: Center(
                    child: isCurrent &&
                            _videoReady &&
                            controller != null &&
                            controller.value.isInitialized
                        ? GestureDetector(
                            onTap: () {
                              if (controller.value.isPlaying) {
                                controller.pause();
                              } else {
                                controller.play();
                              }
                              setState(() {});
                            },
                            child: AspectRatio(
                              aspectRatio: controller.value.aspectRatio <= 0
                                  ? 9 / 16
                                  : controller.value.aspectRatio,
                              child: VideoPlayer(controller),
                            ),
                          )
                        : _videoLoading && isCurrent
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Icon(LucideIcons.video,
                                size: 48,
                                color: mediaFg.withValues(alpha: 0.7)),
                  ),
                );
              }
              return Container(
                color: mediaBg,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(
                            color: DesignTokens.instaPink)),
                    errorWidget: (_, __, ___) => Icon(LucideIcons.imageOff,
                        size: 64,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ),
              );
            },
          ),
          if (media.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(LucideIcons.chevronLeft, color: mediaFg),
                  onPressed: () {
                    final next =
                        (_currentMediaIndex - 1).clamp(0, media.length - 1);
                    _mediaPageController.animateToPage(
                      next,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: Icon(LucideIcons.chevronRight, color: mediaFg),
                  onPressed: () {
                    final next =
                        (_currentMediaIndex + 1).clamp(0, media.length - 1);
                    _mediaPageController.animateToPage(
                      next,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  media.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: index == _currentMediaIndex
                          ? mediaFg
                          : mediaFg.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  int get _likeCount {
    final flag = _post?['likes_count'] as int?;
    if (flag != null) return flag;
    final likes = _post?['likes'] as List<dynamic>? ?? [];
    return likes.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageBg = theme.scaffoldBackgroundColor;
    final appBarBg = theme.appBarTheme.backgroundColor ?? pageBg;
    final primaryText = theme.colorScheme.onSurface;
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    final dividerColor =
        theme.dividerColor.withValues(alpha: isDark ? 0.45 : 0.7);

    if (_loadingPost && _post == null) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: primaryText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          backgroundColor: appBarBg,
          surfaceTintColor: appBarBg,
          elevation: 0,
        ),
        body: const Center(
            child: CircularProgressIndicator(color: DesignTokens.instaPink)),
      );
    }
    if (_post == null) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: primaryText),
            onPressed: () => Navigator.of(context).pop(),
          ),
          backgroundColor: appBarBg,
          surfaceTintColor: appBarBg,
          title: Text('Post', style: TextStyle(color: primaryText)),
        ),
        body: const Center(child: Text('Post not found')),
      );
    }

    final username = _postUser?['username'] as String? ?? 'User';
    final avatarUrl = _postUser?['avatar_url'] as String?;
    final caption = _post?['caption'] as String? ?? '';
    final location = _post?['location'] as String?;
    final createdAt = _post?['created_at'] as String? ?? '';
    final ownerId = _extractId(_postUser?['id']) ??
        _extractId(_post?['user_id']) ??
        _extractId(_post?['user']) ??
        _extractId(_post?['users']);
    final isOwner = ownerId != null &&
        _currentUserId != null &&
        ownerId.toString() == _currentUserId.toString();

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: appBarBg,
        surfaceTintColor: appBarBg,
        elevation: 0,
        title: Text('Post',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: primaryText)),
        centerTitle: true,
        actions: const [SizedBox(width: 24)],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _onAuthorTap,
                          child: Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFBBF24),
                                  Color(0xFFF97316),
                                  Color(0xFFEC4899),
                                ],
                              ),
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                backgroundImage:
                                    avatarUrl != null && avatarUrl.isNotEmpty
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                child: avatarUrl == null || avatarUrl.isEmpty
                                    ? Text(
                                        username.isNotEmpty
                                            ? username[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(color: primaryText))
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _onAuthorTap,
                                child: Text(
                                  username,
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: primaryText),
                                ),
                              ),
                              if (location != null && location.isNotEmpty)
                                Text(
                                  location,
                                  style: TextStyle(
                                      color: secondaryText, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        if (isOwner)
                          IconButton(
                            icon:
                                Icon(LucideIcons.ellipsis, color: primaryText),
                            onPressed: () async {
                              final uid = await CurrentUser.id;
                              final ownerId = _extractId(_post?['user_id']) ??
                                  _extractId(_post?['user']) ??
                                  _extractId(_post?['users']);
                              final isOwner = uid != null &&
                                  ownerId != null &&
                                  uid == ownerId;
                              showModalBottomSheet(
                                context: context,
                                builder: (ctx) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.copy),
                                        title: const Text('Copy link'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text('Link copied')),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading:
                                            const Icon(Icons.report_outlined),
                                        title: const Text('Report'),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('Report submitted')),
                                          );
                                        },
                                      ),
                                      if (isOwner)
                                        ListTile(
                                          leading: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red),
                                          title: const Text('Delete Post',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            bool isDeleting = false;
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            await showDialog<void>(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (dctx) {
                                                return StatefulBuilder(
                                                  builder: (context, setState) {
                                                    return Center(
                                                      child: Material(
                                                        color:
                                                            Colors.transparent,
                                                        child: Container(
                                                          width: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.9,
                                                          constraints:
                                                              const BoxConstraints(
                                                                  maxWidth:
                                                                      360),
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(16),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Theme.of(
                                                                    context)
                                                                .cardColor,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                            border: Border.all(
                                                                color: Theme.of(
                                                                        context)
                                                                    .dividerColor),
                                                          ),
                                                          child: isDeleting
                                                              ? Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                    const SizedBox(
                                                                      width: 48,
                                                                      height:
                                                                          48,
                                                                      child:
                                                                          CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            4,
                                                                        color: Colors
                                                                            .red,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            16),
                                                                    Text(
                                                                      'Deleting post...',
                                                                      style:
                                                                          TextStyle(
                                                                        color: Theme.of(context)
                                                                            .textTheme
                                                                            .bodyMedium
                                                                            ?.color,
                                                                        fontWeight:
                                                                            FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                  ],
                                                                )
                                                              : Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    const SizedBox(
                                                                        height:
                                                                            4),
                                                                    const Text(
                                                                      'Delete Post?',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                          fontSize:
                                                                              18,
                                                                          fontWeight:
                                                                              FontWeight.bold),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                    Text(
                                                                      'Are you sure you want to delete this post? This action cannot be undone.',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: TextStyle(
                                                                          color: Theme.of(context)
                                                                              .textTheme
                                                                              .bodySmall
                                                                              ?.color),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            16),
                                                                    Row(
                                                                      children: [
                                                                        Expanded(
                                                                          child:
                                                                              OutlinedButton(
                                                                            onPressed:
                                                                                () {
                                                                              Navigator.pop(context);
                                                                            },
                                                                            child:
                                                                                const Text('Cancel'),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                8),
                                                                        Expanded(
                                                                          child:
                                                                              ElevatedButton(
                                                                            style:
                                                                                ElevatedButton.styleFrom(
                                                                              backgroundColor: Colors.red,
                                                                              foregroundColor: Colors.white,
                                                                            ),
                                                                            onPressed:
                                                                                () async {
                                                                              setState(() => isDeleting = true);
                                                                              try {
                                                                                final ok = await _svc.deletePost(widget.postId);
                                                                                await Future.delayed(const Duration(milliseconds: 1500));
                                                                                if (ok) {
                                                                                  if (mounted) {
                                                                                    Navigator.pop(context);
                                                                                    messenger.showSnackBar(const SnackBar(content: Text('Post deleted')));
                                                                                    try {
                                                                                      StoreProvider.of<AppState>(context).dispatch(RemovePost(widget.postId));
                                                                                    } catch (_) {}
                                                                                    Navigator.of(context).pop();
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
                                                                            child:
                                                                                const Text('Delete'),
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
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                  _buildMediaSection(theme),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            LucideIcons.heart,
                            size: 28,
                            color: _isLiked ? Colors.red : primaryText,
                          ),
                          onPressed: () async {
                            final hasToken = await ApiClient().hasToken;
                            if (!hasToken) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Please log in to like posts')),
                                );
                              }
                              return;
                            }
                            if (_post == null) return;
                            final desired = !_isLiked;
                            setState(() => _isLiked = desired);
                            final liked = await _svc.setPostLike(widget.postId,
                                like: desired);
                            if (mounted) {
                              setState(() => _isLiked = liked);
                              await _load();
                            }
                          },
                        ),
                        IconButton(
                            icon:
                                const Icon(LucideIcons.messageCircle, size: 28),
                            color: primaryText,
                            onPressed: () {}),
                        IconButton(
                            icon: const Icon(LucideIcons.send, size: 28),
                            color: primaryText,
                            onPressed: () {}),
                        const Spacer(),
                        IconButton(
                            icon: const Icon(LucideIcons.bookmark, size: 28),
                            color: primaryText,
                            onPressed: () {}),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 16, color: primaryText),
                        children: [
                          TextSpan(
                            text: '$username ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: caption),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: Text(
                      _formatRelativeTime(createdAt).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: secondaryText,
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: dividerColor),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Comments',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                        ),
                        if (_loadingComments)
                          const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(
                                      color: DesignTokens.instaPink)))
                        else if (_comments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 48, 16, 56),
                            child: Center(
                              child: Text(
                                'No comments yet. Be the first to comment!',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: secondaryText,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else
                          ..._comments.map((c) {
                            final cid = _commentId(c);
                            final user = _commentUser(c);
                            final username =
                                (user['username'] ?? 'user').toString();
                            final avatar = user['avatar_url']?.toString();
                            final text =
                                (c['text'] ?? c['content'] ?? '').toString();
                            final createdAt =
                                (c['created_at'] ?? c['createdAt'] ?? '')
                                    .toString();
                            final likesCount = (c['likes_count'] as int?) ??
                                ((c['likes'] is List)
                                    ? (c['likes'] as List).length
                                    : 0);
                            final inlineReplies = (c['replies'] is List)
                                ? (c['replies'] as List)
                                    .whereType<Map>()
                                    .map((e) => Map<String, dynamic>.from(e))
                                    .toList()
                                : const <Map<String, dynamic>>[];
                            final loadedReplies =
                                _replies[cid] ?? inlineReplies;
                            final hasReplies =
                                _replyCount(c) > 0 || loadedReplies.isNotEmpty;
                            final isExpanded = _expandedComments.contains(cid);
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: theme.colorScheme
                                            .surfaceContainerHighest,
                                        backgroundImage:
                                            avatar != null && avatar.isNotEmpty
                                                ? NetworkImage(avatar)
                                                : null,
                                        child: avatar == null || avatar.isEmpty
                                            ? Text(
                                                username.isNotEmpty
                                                    ? username[0].toUpperCase()
                                                    : 'U',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: primaryText),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  username,
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: primaryText),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _formatRelativeTime(
                                                      createdAt),
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: secondaryText),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              text,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: primaryText),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (likesCount > 0)
                                                  Text(
                                                    '$likesCount likes',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: secondaryText),
                                                  ),
                                                if (likesCount > 0)
                                                  const SizedBox(width: 12),
                                                TextButton(
                                                  onPressed: () =>
                                                      _startReplyTo(
                                                          cid, username),
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  child: Text(
                                                    'Reply',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: secondaryText),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                          icon: Icon(LucideIcons.heart,
                                              size: 14, color: secondaryText),
                                          onPressed: () {},
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints()),
                                    ],
                                  ),
                                  if (hasReplies) ...[
                                    const SizedBox(height: 4),
                                    TextButton(
                                      onPressed: () => _toggleReplies(c),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 1,
                                            color: secondaryText.withValues(
                                                alpha: 0.6),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            isExpanded
                                                ? 'Hide replies'
                                                : 'View replies (${_replyCount(c) > 0 ? _replyCount(c) : loadedReplies.length})',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: secondaryText),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  if (_loadingReplies.contains(cid))
                                    const Padding(
                                      padding:
                                          EdgeInsets.only(top: 6, left: 32),
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: DesignTokens.instaPink,
                                        ),
                                      ),
                                    ),
                                  if (isExpanded && loadedReplies.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 32, top: 8),
                                      child: Column(
                                        children: loadedReplies.map((r) {
                                          final ru = _commentUser(r);
                                          final rName =
                                              (ru['username'] ?? 'user')
                                                  .toString();
                                          final rAvatar =
                                              ru['avatar_url']?.toString();
                                          final rText =
                                              (r['text'] ?? r['content'] ?? '')
                                                  .toString();
                                          final rCreated = (r['created_at'] ??
                                                  r['createdAt'] ??
                                                  '')
                                              .toString();
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor: theme
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  backgroundImage: rAvatar !=
                                                              null &&
                                                          rAvatar.isNotEmpty
                                                      ? NetworkImage(rAvatar)
                                                      : null,
                                                  child: rAvatar == null ||
                                                          rAvatar.isEmpty
                                                      ? Text(
                                                          rName.isNotEmpty
                                                              ? rName[0]
                                                                  .toUpperCase()
                                                              : 'U',
                                                          style: TextStyle(
                                                              fontSize: 10,
                                                              color:
                                                                  primaryText),
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      RichText(
                                                        text: TextSpan(
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              color:
                                                                  primaryText),
                                                          children: [
                                                            TextSpan(
                                                              text: '$rName ',
                                                              style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600),
                                                            ),
                                                            TextSpan(
                                                                text: rText),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        _formatRelativeTime(
                                                            rCreated),
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                secondaryText),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 88),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: dividerColor),
          if (_replyParentId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              color: pageBg,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingTo ?? ''}',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelReply,
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            color: pageBg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                    icon: Icon(LucideIcons.smile, color: primaryText),
                    onPressed: () {}),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: primaryText, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: _replyingTo != null
                          ? 'Reply to $_replyingTo...'
                          : 'Add a comment...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintStyle: TextStyle(color: secondaryText),
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _commentController,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return TextButton(
                      onPressed:
                          _postingComment || !hasText ? null : _postComment,
                      child: Text('Post',
                          style: TextStyle(
                              color: hasText
                                  ? theme.colorScheme.primary
                                  : secondaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
