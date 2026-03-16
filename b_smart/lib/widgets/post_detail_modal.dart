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

/// Modal matching React PostDetailModal: image left, details + comments right.
class PostDetailModal extends StatefulWidget {
  final String postId;
  final VoidCallback? onClose;

  const PostDetailModal({super.key, required this.postId, this.onClose});

  @override
  State<PostDetailModal> createState() => _PostDetailModalState();
}

class _PostDetailModalState extends State<PostDetailModal> {
  final SupabaseService _svc = SupabaseService();
  Map<String, dynamic>? _post;
  Map<String, dynamic>? _postUser;
  List<Map<String, dynamic>> _comments = [];
  bool _loadingPost = true;
  bool _loadingComments = true;
  final _commentController = TextEditingController();
  bool _isLiked = false;
  bool _isSaved = false;
  int _likeCount = 0;
  bool _postingComment = false;
  bool _likeAnimate = false;
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

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1';
    }
    return false;
  }

  bool? _asNullableBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true' || v == '1') return true;
      if (v == 'false' || v == '0') return false;
    }
    return null;
  }

  bool? _extractLikedFlag(Map<String, dynamic>? post, {String? currentUserId}) {
    if (post == null) return null;
    final direct = _asNullableBool(post['is_liked_by_me']) ??
        _asNullableBool(post['liked_by_me']) ??
        _asNullableBool(post['is_liked']) ??
        _asNullableBool(post['liked']);
    if (direct != null) return direct;

    final likes = post['likes'];
    if (likes is! List || currentUserId == null || currentUserId.isEmpty)
      return null;
    for (final e in likes) {
      if (e is String && e == currentUserId) return true;
      if (e is Map) {
        final uid = _extractId(e['user_id']) ??
            _extractId(e['id']) ??
            _extractId(e['_id']) ??
            (e['user'] is Map ? _extractId(e['user']) : null);
        if (uid != null && uid == currentUserId) return true;
      }
    }
    return false;
  }

  int? _extractLikesCount(Map<String, dynamic>? post) {
    if (post == null) return null;
    final raw = post['likes_count'] ?? post['likesCount'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    final likes = post['likes'];
    if (likes is List) return likes.length;
    return null;
  }

  bool _isAdPost(Map<String, dynamic>? post) {
    if (post == null) return false;
    final itemType =
        (post['item_type'] ?? post['itemType'] ?? '').toString().toLowerCase();
    if (itemType == 'ad') return true;
    if (post['vendor_id'] != null || post['vendorId'] != null) return true;
    if (post['total_budget_coins'] != null || post['totalBudgetCoins'] != null) {
      return true;
    }
    return false;
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return const [];
      if (s.contains(',')) {
        return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [s];
    }
    return const [];
  }

  Widget _buildAdInfo() {
    final post = _post;
    if (!_isAdPost(post) || post == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final surface = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final muted = isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.55);

    final category = (post['category'] ?? '').toString().trim();
    final budget = _toInt(post['total_budget_coins'] ?? post['totalBudgetCoins']);
    final views = _toInt(post['views_count'] ?? post['viewsCount']);
    final unique = _toInt(post['unique_views_count'] ?? post['uniqueViewsCount']);
    final completed = _toInt(post['completed_views_count'] ?? post['completedViewsCount']);
    final targetLocations = _asStringList(post['target_location'] ?? post['targetLocation']);
    final targetLanguages = _asStringList(post['target_language'] ?? post['target_languages'] ?? post['targetLanguage'] ?? post['targetLanguages']);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (category.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1A3B82F6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x333B82F6)),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                  ),
                ),
              if (budget > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1AF59E0B),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x33F59E0B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.coins, size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        '${_fmt(budget)} coins budget',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (views > 0 || unique > 0 || completed > 0) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                if (views > 0) Text('${_fmt(views)} views', style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
                if (unique > 0) Text('${_fmt(unique)} unique', style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
                if (completed > 0) Text('${_fmt(completed)} completed', style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          if (targetLocations.isNotEmpty || targetLanguages.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (targetLocations.isNotEmpty)
              Text(
                '📍 ${targetLocations.join(', ')}',
                style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
              ),
            if (targetLanguages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '🌐 ${targetLanguages.join(', ')}',
                  style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
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
    setState(() {
      _loadingPost = true;
      _loadingComments = true;
    });
    final post = await _svc.getPostById(widget.postId);
    if (post == null || !mounted) {
      if (mounted) setState(() => _loadingPost = false);
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
    final currentUserId = await CurrentUser.id;
    final isLiked =
        _extractLikedFlag(post, currentUserId: currentUserId) ?? false;
    final likeCount = _extractLikesCount(post) ?? 0;
    final isSaved =
        _asBool(post['is_saved_by_me']) || _asBool(post['saved_by_me']);
    if (mounted) {
      setState(() {
        _post = post;
        _postUser = user;
        _comments = comments;
        _isLiked = isLiked;
        _isSaved = isSaved;
        _likeCount = likeCount;
        _loadingPost = false;
        _loadingComments = false;
      });
      _syncCurrentMediaPlayback();
    }
  }

  Future<void> _handleLike() async {
    if (_post == null) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like posts')),
        );
      }
      return;
    }
    final desired = !_isLiked;
    setState(() {
      _isLiked = desired;
      _likeCount =
          desired ? _likeCount + 1 : (_likeCount > 0 ? _likeCount - 1 : 0);
      _likeAnimate = true;
    });
    final liked = await _svc.setPostLike(widget.postId, like: desired);
    if (!mounted) return;
    try {
      final p = await SupabaseService().getPostById(widget.postId);
      final currentUserId = await CurrentUser.id;
      final serverLiked =
          _extractLikedFlag(p, currentUserId: currentUserId) ?? liked;
      final likesCount = _extractLikesCount(p) ?? _likeCount;
      setState(() {
        _isLiked = serverLiked;
        _likeCount = likesCount;
        _likeAnimate = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = liked;
        _likeAnimate = false;
      });
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    final userId = await CurrentUser.id;
    if (content.isEmpty || userId == null) return;
    setState(() => _postingComment = true);
    try {
      await _svc.addComment(widget.postId, userId, content);
      _commentController.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  Future<void> _handleSave() async {
    if (_post == null) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save posts')),
        );
      }
      return;
    }

    final desired = !_isSaved;
    setState(() => _isSaved = desired);
    StoreProvider.of<AppState>(context, listen: false)
        .dispatch(UpdatePostSaved(widget.postId, desired));

    final saved = await _svc.setPostSaved(widget.postId, save: desired);
    if (!mounted) return;
    try {
      final p = await _svc.getPostById(widget.postId);
      final serverSaved =
          _asBool(p?['is_saved_by_me']) || _asBool(p?['saved_by_me']) || saved;
      setState(() => _isSaved = serverSaved);
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(UpdatePostSaved(widget.postId, serverSaved));
    } catch (_) {
      setState(() => _isSaved = saved);
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(UpdatePostSaved(widget.postId, saved));
    }
  }

  Future<void> _showLikesList() async {
    final users = await _svc.getPostLikes(widget.postId);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text('Liked by', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final u = users[index];
                    final id =
                        (u['_id'] as String?) ?? (u['id'] as String?) ?? '';
                    final username = (u['username'] as String?) ??
                        (u['full_name'] as String?) ??
                        'User';
                    final avatar = (u['avatar_url'] as String?) ?? '';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            avatar.isNotEmpty ? NetworkImage(avatar) : null,
                        child: avatar.isEmpty
                            ? Text(username.isNotEmpty
                                ? username[0].toUpperCase()
                                : 'U')
                            : null,
                      ),
                      title: Text(username),
                      onTap: id.isNotEmpty
                          ? () =>
                              Navigator.of(context).pushNamed('/profile/$id')
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String formatRelativeTime(String dateString) {
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
    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin =
        '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    return raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : (raw.startsWith('/') ? '$origin$raw' : '$origin/$raw');
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
    if (url.isEmpty) {
      return;
    }
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

  @override
  Widget build(BuildContext context) {
    if (_loadingPost && _post == null) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: DesignTokens.instaPink)));
    }
    if (_post == null) {
      return Scaffold(
        appBar: AppBar(
            leading: IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.of(context).pop())),
        body: const Center(child: Text('Post not found')),
      );
    }

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(
                maxWidth: 1200,
                maxHeight: MediaQuery.sizeOf(context).height * 0.9),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isMobile ? 0 : 12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Flexible(
                  child: isMobile
                      ? Column(
                          children: [
                            Expanded(flex: 2, child: _buildImage()),
                            Expanded(flex: 3, child: _buildDetails()),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: 400, child: _buildImage()),
                            Expanded(child: _buildDetails()),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final media = _mediaItems;
    if (media.isEmpty) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(LucideIcons.imageOff, size: 64, color: Colors.white54),
        ),
      );
    }

    return Stack(
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
              return const Center(
                child:
                    Icon(LucideIcons.imageOff, size: 64, color: Colors.white54),
              );
            }
            if (isVideo) {
              final isCurrent = index == _currentMediaIndex;
              final controller = _videoController;
              return Container(
                color: Colors.black,
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
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Icon(LucideIcons.video,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.7)),
                ),
              );
            }
            return Container(
              color: Colors.black,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
                  errorWidget: (_, __, ___) => const Icon(LucideIcons.imageOff,
                      size: 64, color: Colors.white54),
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
                icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
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
                icon: const Icon(LucideIcons.chevronRight, color: Colors.white),
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
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetails() {
    final theme = Theme.of(context);
    final baseTextColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
    final username = _postUser?['username'] as String? ?? 'User';
    final avatarUrl = _postUser?['avatar_url'] as String?;
    final caption = _post?['caption'] as String? ?? '';
    final location = _post?['location'] as String?;
    final createdAt = _post?['created_at'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    final userId = _extractId(_postUser?['id']) ??
                        _extractId(_post?['user_id']) ??
                        _extractId(_post?['user']) ??
                        _extractId(_post?['users']);
                    if (userId != null && userId.isNotEmpty) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed('/profile/$userId');
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(username.isNotEmpty
                                ? username[0].toUpperCase()
                                : 'U')
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(username,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                                overflow: TextOverflow.ellipsis),
                            if (location != null && location.isNotEmpty)
                              Text(location,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.ellipsis),
                onPressed: () async {
                  final uid = await CurrentUser.id;
                  final ownerId = _extractId(_post?['user_id']) ??
                      _extractId(_post?['user']) ??
                      _extractId(_post?['users']);
                  final isOwner =
                      uid != null && ownerId != null && uid == ownerId;
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copied')),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.report_outlined),
                            title: const Text('Report'),
                            onTap: () {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Report submitted')),
                              );
                            },
                          ),
                          if (isOwner)
                            ListTile(
                              leading: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              title: const Text('Delete Post',
                                  style: TextStyle(color: Colors.red)),
                              onTap: () async {
                                Navigator.pop(ctx);
                                final messenger = ScaffoldMessenger.of(context);
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
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width *
                                                  0.9,
                                              constraints: const BoxConstraints(
                                                  maxWidth: 360),
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color:
                                                    Theme.of(context).cardColor,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color: Theme.of(context)
                                                        .dividerColor),
                                              ),
                                              child: isDeleting
                                                  ? Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const SizedBox(
                                                            height: 8),
                                                        const SizedBox(
                                                          width: 48,
                                                          height: 48,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 4,
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 16),
                                                        Text(
                                                          'Deleting post...',
                                                          style: TextStyle(
                                                            color: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyMedium
                                                                ?.color,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                      ],
                                                    )
                                                  : Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const SizedBox(
                                                            height: 4),
                                                        const Text(
                                                          'Delete Post?',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                              fontSize: 18,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(
                                                          'Are you sure you want to delete this post? This action cannot be undone.',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                              color: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.color),
                                                        ),
                                                        const SizedBox(
                                                            height: 16),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child:
                                                                  OutlinedButton(
                                                                onPressed: () {
                                                                  Navigator.pop(
                                                                      context);
                                                                },
                                                                child: const Text(
                                                                    'Cancel'),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                            Expanded(
                                                              child:
                                                                  ElevatedButton(
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                  foregroundColor:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                                onPressed:
                                                                    () async {
                                                                  setState(() =>
                                                                      isDeleting =
                                                                          true);
                                                                  try {
                                                                    final ok = await _svc
                                                                        .deletePost(
                                                                            widget.postId);
                                                                    await Future.delayed(const Duration(
                                                                        milliseconds:
                                                                            1500));
                                                                    if (ok) {
                                                                      if (mounted) {
                                                                        Navigator.pop(
                                                                            context);
                                                                        messenger.showSnackBar(const SnackBar(
                                                                            content:
                                                                                Text('Post deleted')));
                                                                        try {
                                                                          StoreProvider.of<AppState>(context)
                                                                              .dispatch(RemovePost(widget.postId));
                                                                        } catch (_) {}
                                                                        if (widget.onClose !=
                                                                            null) {
                                                                          widget
                                                                              .onClose!();
                                                                        } else {
                                                                          Navigator.of(context)
                                                                              .pop();
                                                                        }
                                                                      }
                                                                    } else {
                                                                      if (mounted) {
                                                                        setState(() =>
                                                                            isDeleting =
                                                                                false);
                                                                        Navigator.pop(
                                                                            context);
                                                                        messenger.showSnackBar(const SnackBar(
                                                                            content:
                                                                                Text('Failed to delete post')));
                                                                      }
                                                                    }
                                                                  } on ApiException catch (e) {
                                                                    if (mounted) {
                                                                      setState(() =>
                                                                          isDeleting =
                                                                              false);
                                                                      Navigator.pop(
                                                                          context);
                                                                      messenger.showSnackBar(SnackBar(
                                                                          content:
                                                                              Text(e.message)));
                                                                    }
                                                                  } catch (e) {
                                                                    if (mounted) {
                                                                      setState(() =>
                                                                          isDeleting =
                                                                              false);
                                                                      Navigator.pop(
                                                                          context);
                                                                      messenger.showSnackBar(SnackBar(
                                                                          content:
                                                                              Text(e.toString())));
                                                                    }
                                                                  }
                                                                },
                                                                child: const Text(
                                                                    'Delete'),
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
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                          radius: 14,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(fontSize: 12))
                              : null),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(color: baseTextColor, fontSize: 14),
                                children: [
                                  TextSpan(
                                      text: '$username ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  TextSpan(text: caption),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(formatRelativeTime(createdAt),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _buildAdInfo(),
                  const SizedBox(height: 16),
                  if (_loadingComments)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                                color: DesignTokens.instaPink)))
                  else if (_comments.isEmpty)
                    Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('No comments yet.',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14))))
                  else
                    ..._comments.map((c) {
                      final u = c['user'] as Map<String, dynamic>?;
                      final un = u?['username'] as String? ?? 'user';
                      final uAvatar = u?['avatar_url'] as String?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                                radius: 14,
                                backgroundImage: uAvatar != null
                                    ? NetworkImage(uAvatar)
                                    : null,
                                child: uAvatar == null
                                    ? Text(
                                        un.isNotEmpty
                                            ? un[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(fontSize: 12))
                                    : null),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: TextStyle(color: baseTextColor, fontSize: 14),
                                      children: [
                                        TextSpan(
                                            text: '$un ',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600)),
                                        TextSpan(
                                            text:
                                                c['content'] as String? ?? ''),
                                      ],
                                    ),
                                  ),
                                  Text(
                                      formatRelativeTime(
                                          c['created_at'] as String? ?? ''),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            IconButton(
                                icon: const Icon(LucideIcons.heart, size: 14),
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints()),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              AnimatedScale(
                scale: _likeAnimate ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: IconButton(
                    icon: Icon(LucideIcons.heart,
                        color: _isLiked ? Colors.red : Colors.black87),
                    onPressed: _handleLike),
              ),
              IconButton(
                  icon: const Icon(LucideIcons.messageCircle),
                  onPressed: () {}),
              IconButton(icon: const Icon(LucideIcons.send), onPressed: () {}),
              const Spacer(),
              IconButton(
                  icon: Icon(
                    _isSaved ? Icons.bookmark : LucideIcons.bookmark,
                  ),
                  onPressed: _handleSave),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          child: Row(
            children: [
              Text('$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 12),
              TextButton(
                  onPressed: _showLikesList, child: const Text('Liked by')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          child: Text(
            _formatFullDate(createdAt),
            style: TextStyle(
                fontSize: 10, color: Colors.grey.shade600, letterSpacing: 0.5),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(icon: const Icon(LucideIcons.smile), onPressed: () {}),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8)),
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
                            color:
                                !hasText ? Colors.grey : DesignTokens.instaPink,
                            fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatFullDate(String dateString) {
    final date = DateTime.tryParse(dateString);
    if (date == null) return '';
    return '${date.month} ${date.day}, ${date.year}';
  }
}
