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

/// Modal matching React PostDetailModal: image left, details + comments right.
class PostDetailModal extends StatefulWidget {
  final String postId;
  final VoidCallback? onClose;

  const PostDetailModal({Key? key, required this.postId, this.onClose}) : super(key: key);

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
  int _likeCount = 0;
  bool _postingComment = false;
  bool _likeAnimate = false;

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
    setState(() {
      _loadingPost = true;
      _loadingComments = true;
    });
    final post = await _svc.getPostById(widget.postId);
    if (post == null || !mounted) {
      if (mounted) setState(() => _loadingPost = false);
      return;
    }
    final userId = post['user_id'] as String?;
    Map<String, dynamic>? user;
    if (userId != null) {
      user = await _svc.getUserById(userId);
    }
    final comments = await _svc.getComments(widget.postId);
    final rawLikes = post['likes'] as List<dynamic>? ?? [];
    final currentUserId = await CurrentUser.id;
    bool isLiked = false;
    for (final e in rawLikes) {
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
    int likeCount = (post['likes_count'] as int?) ?? rawLikes.length;
    if (mounted) {
      setState(() {
        _post = post;
        _postUser = user;
        _comments = comments;
        _isLiked = isLiked;
        _likeCount = likeCount;
        _loadingPost = false;
        _loadingComments = false;
      });
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
      _likeCount = desired ? _likeCount + 1 : _likeCount - 1;
      _likeAnimate = true;
    });
    final liked = await _svc.setPostLike(widget.postId, like: desired);
    if (!mounted) return;
    try {
      final p = await SupabaseService().getPostById(widget.postId);
      final rawLikes = (p?['likes'] as List<dynamic>?) ?? [];
      bool serverLiked = false;
      final currentUserId = await CurrentUser.id;
      for (final e in rawLikes) {
        if (e is Map) {
          String? uid = (e['user_id'] as String?) ?? (e['id'] as String?) ?? (e['_id'] as String?);
          if (uid == null && e['user'] is Map) {
            final u = (e['user'] as Map);
            uid = (u['id'] as String?) ?? (u['_id'] as String?);
          }
          if (uid != null && currentUserId != null && uid.toString() == currentUserId.toString()) {
            serverLiked = true;
            break;
          }
        } else if (e is String && currentUserId != null && e.toString() == currentUserId.toString()) {
          serverLiked = true;
          break;
        }
      }
      final likesCount = (p?['likes_count'] as int?) ?? rawLikes.length;
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

  String _displayImageUrl() {
    final media = _post?['media'] as List<dynamic>?;
    if (media == null || media.isEmpty) return 'https://via.placeholder.com/600';
    final first = media.first;
    String? raw;
    if (first is Map && first.containsKey('image')) raw = first['image'] as String?;
    if (raw == null && first is Map && first.containsKey('url')) raw = first['url'] as String?;
    if (raw == null && first is String) raw = first;
    if (raw == null || raw.isEmpty) return 'https://via.placeholder.com/600';
    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    return raw.startsWith('http://') || raw.startsWith('https://') ? raw : (raw.startsWith('/') ? '$origin$raw' : '$origin/$raw');
    return 'https://via.placeholder.com/600';
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPost && _post == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: DesignTokens.instaPink)));
    }
    if (_post == null) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: Icon(LucideIcons.x), onPressed: () => Navigator.of(context).pop())),
        body: const Center(child: Text('Post not found')),
      );
    }

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 1200, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(isMobile ? 0 : 12)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(LucideIcons.x),
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
    return Container(
      color: Colors.black,
      child: Center(
        child: CachedNetworkImage(
          imageUrl: _displayImageUrl(),
          fit: BoxFit.contain,
          placeholder: (_, __) => const Center(child: CircularProgressIndicator(color: Colors.white)),
          errorWidget: (_, __, ___) => Icon(LucideIcons.imageOff, size: 64, color: Colors.white54),
        ),
      ),
    );
  }

  Widget _buildDetails() {
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
                    final userId = _postUser?['id'] as String?;
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
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U') : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                            if (location != null && location.isNotEmpty) Text(location, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(LucideIcons.ellipsis),
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
                                                                        if (widget.onClose != null) widget.onClose!();
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
                    CircleAvatar(radius: 14, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null, child: avatarUrl == null ? Text(username.isNotEmpty ? username[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 12)) : null),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(color: Colors.black, fontSize: 14),
                              children: [
                                TextSpan(text: '$username ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                TextSpan(text: caption),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(formatRelativeTime(createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_loadingComments)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: DesignTokens.instaPink)))
                else if (_comments.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No comments yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14))))
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
                          CircleAvatar(radius: 14, backgroundImage: uAvatar != null ? NetworkImage(uAvatar) : null, child: uAvatar == null ? Text(un.isNotEmpty ? un[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 12)) : null),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(color: Colors.black, fontSize: 14),
                                    children: [
                                      TextSpan(text: '$un ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      TextSpan(text: c['content'] as String? ?? ''),
                                    ],
                                  ),
                                ),
                                Text(formatRelativeTime(c['created_at'] as String? ?? ''), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          IconButton(icon: Icon(LucideIcons.heart, size: 14), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
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
                child: IconButton(icon: Icon(LucideIcons.heart, color: _isLiked ? Colors.red : Colors.black87), onPressed: _handleLike),
              ),
              IconButton(icon: Icon(LucideIcons.messageCircle), onPressed: () {}),
              IconButton(icon: Icon(LucideIcons.send), onPressed: () {}),
              const Spacer(),
              IconButton(icon: Icon(LucideIcons.bookmark), onPressed: () {}),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          child: Row(
            children: [
              Text('$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(width: 12),
              TextButton(onPressed: _showLikesList, child: const Text('Liked by')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          child: Text(
            _formatFullDate(createdAt),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, letterSpacing: 0.5),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(icon: Icon(LucideIcons.smile), onPressed: () {}),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(hintText: 'Add a comment...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                  onSubmitted: (_) => _postComment(),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _commentController,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return TextButton(
                    onPressed: _postingComment || !hasText ? null : _postComment,
                    child: Text('Post', style: TextStyle(color: !hasText ? Colors.grey : DesignTokens.instaPink, fontWeight: FontWeight.w600)),
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
