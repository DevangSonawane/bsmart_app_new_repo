import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  const PostDetailScreen({Key? key, required this.postId, this.initialPost}) : super(key: key);

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final SupabaseService _svc = SupabaseService();
  Map<String, dynamic>? _post;
  Map<String, dynamic>? _postUser;
  List<Map<String, dynamic>> _comments = [];
  bool _loadingPost = true;
  bool _loadingComments = true;
  final _commentController = TextEditingController();
  bool _isLiked = false;
  bool _postingComment = false;
  String? _currentUserId;
  bool _isAuthorFollowed = false;
  bool _followLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
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
    final userId = post['user_id'] as String?;
    Map<String, dynamic>? user;
    if (userId != null) {
      user = await _svc.getUserById(userId);
    }
    final comments = await _svc.getComments(widget.postId);
    final likes = post['likes'] as List<dynamic>? ?? [];
    final currentUserId = await CurrentUser.id;
    bool isLiked = false;
    for (final e in likes) {
      if (e is Map) {
        String? uid = (e['user_id'] as String?) ?? (e['id'] as String?) ?? (e['_id'] as String?);
        if (uid == null && e['user'] is Map) {
          final u = (e['user'] as Map);
          uid = (u['id'] as String?) ?? (u['_id'] as String?);
        }
        if (uid != null && currentUserId != null && uid.toString() == currentUserId.toString()) {
          isLiked = true;
          break;
        }
      } else if (e is String && currentUserId != null && e.toString() == currentUserId.toString()) {
        isLiked = true;
        break;
      }
    }
    final meId2 = currentUserId?.toString();
    bool isFollowed = (post['is_followed_by_me'] as bool?) ?? (user?['is_followed_by_me'] as bool?) ?? false;
    if (mounted) {
      setState(() {
        _post = post;
        _postUser = user;
        _comments = comments;
        _isLiked = isLiked;
        _loadingPost = false;
        _loadingComments = false;
        _currentUserId = meId2;
        _isAuthorFollowed = isFollowed;
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

  void _onAuthorTap() {
    final userId = _postUser?['id'] as String?;
    if (userId == null) return;
    Navigator.of(context).pushNamed('/profile/$userId');
  }

  Future<void> _toggleFollowAuthor() async {
    if (_followLoading) return;
    final targetId = (_postUser?['id'] as String?) ?? (_post?['user_id'] as String?);
    final meId = _currentUserId;
    if (targetId == null || targetId.isEmpty || meId == null || meId.isEmpty || targetId == meId) return;
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
    final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    return url.startsWith('/') ? '$origin$url' : '$origin/$url';
  }

  String _displayImageUrl() {
    final media = _post?['media'] as List<dynamic>?;
    if (media == null || media.isEmpty) return 'https://via.placeholder.com/600';
    final first = media.first;
    String? raw;
    if (first is Map && first.containsKey('image')) raw = first['image'] as String?;
    if (raw == null && first is Map && first.containsKey('url')) raw = first['url'] as String?;
    if (raw == null && first is String) raw = first;
    if (raw == null || raw.isEmpty) return 'https://via.placeholder.com/600';
    return _absolute(raw);
    return 'https://via.placeholder.com/600';
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

    if (_loadingPost && _post == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: theme.appBarTheme.foregroundColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          backgroundColor: theme.appBarTheme.backgroundColor,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator(color: DesignTokens.instaPink)),
      );
    }
    if (_post == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: theme.appBarTheme.foregroundColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          backgroundColor: theme.appBarTheme.backgroundColor,
          title: Text('Post', style: TextStyle(color: theme.appBarTheme.foregroundColor)),
        ),
        body: const Center(child: Text('Post not found')),
      );
    }

    final username = _postUser?['username'] as String? ?? 'User';
    final avatarUrl = _postUser?['avatar_url'] as String?;
    final caption = _post?['caption'] as String? ?? '';
    final location = _post?['location'] as String?;
    final createdAt = _post?['created_at'] as String? ?? '';
    final ownerId = (_postUser?['id'] as String?) ?? (_post?['user_id'] as String?);
    final isOwner = ownerId != null && _currentUserId != null && ownerId.toString() == _currentUserId.toString();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: theme.appBarTheme.foregroundColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text('Posts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.appBarTheme.foregroundColor)),
        centerTitle: true,
        actions: [
          if (!isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _followLoading ? null : _toggleFollowAuthor,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  backgroundColor: _isAuthorFollowed ? Colors.transparent : DesignTokens.instaPink,
                  foregroundColor: _isAuthorFollowed ? theme.colorScheme.onSurface : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: _isAuthorFollowed
                        ? BorderSide(color: theme.colorScheme.outline)
                        : BorderSide.none,
                  ),
                ),
                child: Text(_isAuthorFollowed ? 'Following' : 'Follow'),
              ),
            ),
        ],
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
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U', style: TextStyle(color: theme.colorScheme.primary))
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _onAuthorTap,
                                child: Text(username, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                              ),
                              if (location != null && location.isNotEmpty)
                                Text(location, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(LucideIcons.ellipsis, color: theme.iconTheme.color),
                          onPressed: () async {
                            final uid = await CurrentUser.id;
                            final ownerId = _post?['user_id'] as String?;
                            final isOwner = uid != null && ownerId != null && uid == ownerId;
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
                                          const SnackBar(content: Text('Report submitted')),
                                        );
                                      },
                                    ),
                                    if (isOwner)
                                      ListTile(
                                        leading: const Icon(Icons.delete_outline, color: Colors.red),
                                        title: const Text('Delete Post', style: TextStyle(color: Colors.red)),
                                        onTap: () async {
                                          Navigator.pop(ctx);
                                          bool isDeleting = false;
                                          final messenger = ScaffoldMessenger.of(context);
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
                                                                  const Text(
                                                                    'Delete Post?',
                                                                    textAlign: TextAlign.center,
                                                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: theme.textTheme.bodyMedium,
                                  children: [
                                    TextSpan(text: '$username ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    TextSpan(text: caption),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(_formatRelativeTime(createdAt), style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.sizeOf(context).width,
                    child: Container(
                      color: theme.brightness == Brightness.dark ? Colors.black : Colors.grey.shade200,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: _displayImageUrl(),
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: DesignTokens.instaPink)),
                          errorWidget: (_, __, ___) => Icon(LucideIcons.imageOff, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingComments)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: DesignTokens.instaPink)))
                  else if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text('No comments yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                    )
                  else
                    ..._comments.map((c) {
                      final u = c['user'] as Map<String, dynamic>?;
                      final un = u?['username'] as String? ?? 'user';
                      final uAvatar = u?['avatar_url'] as String?;
                      return Padding(
                        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              backgroundImage: uAvatar != null && uAvatar.isNotEmpty ? NetworkImage(uAvatar) : null,
                              child: uAvatar == null || uAvatar.isEmpty
                                  ? Text(un.isNotEmpty ? un[0].toUpperCase() : 'U', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary))
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: theme.textTheme.bodyMedium,
                                      children: [
                                        TextSpan(text: '$un ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        TextSpan(text: c['content'] as String? ?? ''),
                                      ],
                                    ),
                                  ),
                                  Text(_formatRelativeTime(c['created_at'] as String? ?? ''), style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ),
                            IconButton(icon: Icon(LucideIcons.heart, size: 14, color: theme.iconTheme.color), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          ],
                        ),
                      );
                    }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(_formatFullDate(createdAt), style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: AnimatedScale(
                    scale: _isLiked ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(LucideIcons.heart, color: _isLiked ? Colors.red : theme.iconTheme.color),
                  ),
                  onPressed: () async {
                    final hasToken = await ApiClient().hasToken;
                    if (!hasToken) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please log in to like posts')),
                        );
                      }
                      return;
                    }
                    if (_post == null) return;
                    final desired = !_isLiked;
                    setState(() => _isLiked = desired);
                    final liked = await _svc.setPostLike(widget.postId, like: desired);
                    if (mounted) {
                    setState(() => _isLiked = liked);
                       await _load();
                    }
                  },
                ),
                IconButton(icon: Icon(LucideIcons.messageCircle, color: theme.iconTheme.color), onPressed: () {}),
                IconButton(icon: Icon(LucideIcons.send, color: theme.iconTheme.color), onPressed: () {}),
                const Spacer(),
                IconButton(icon: Icon(LucideIcons.bookmark, color: theme.iconTheme.color), onPressed: () {}),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
            child: Row(
              children: [
                Text('$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () async {
                    final users = await _svc.getPostLikes(widget.postId);
                    if (!mounted) return;
                    await showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              Text('Liked by', style: Theme.of(ctx).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Flexible(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: users.length,
                                  itemBuilder: (context, index) {
                                    final u = users[index];
                                    final id = (u['_id'] as String?) ?? (u['id'] as String?) ?? '';
                                    final username = (u['username'] as String?) ?? (u['full_name'] as String?) ?? 'User';
                                    final avatar = (u['avatar_url'] as String?) ?? '';
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                                        child: avatar.isEmpty ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U') : null,
                                      ),
                                      title: Text(username),
                                      onTap: id.isNotEmpty ? () => Navigator.of(context).pushNamed('/profile/$id') : null,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: const Text('Liked by'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(icon: Icon(LucideIcons.smile, color: theme.iconTheme.color), onPressed: () {}),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintStyle: TextStyle(color: theme.hintColor),
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _commentController,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return TextButton(
                      onPressed: _postingComment || !hasText ? null : _postComment,
                      child: Text('Post', style: TextStyle(color: hasText ? DesignTokens.instaPink : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
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
