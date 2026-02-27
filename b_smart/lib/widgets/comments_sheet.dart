import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/supabase_service.dart';
import '../utils/current_user.dart';
import '../theme/design_tokens.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  const CommentsSheet({Key? key, required this.postId}) : super(key: key);

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final SupabaseService _svc = SupabaseService();
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _posting = false;
  final Set<String> _liked = {};
  final Map<String, List<Map<String, dynamic>>> _replies = {};
  final Set<String> _loadingReplies = {};
  final List<String> _emojis = ['❤️','🙌','🔥','👏','🤣','😍','👍','💪','😂'];
  String? _replyParentId;
  String? _replyingTo;
  final FocusNode _inputFocus = FocusNode();
  Map<String, dynamic>? _me;
  String? _postAuthorName;

  @override
  void initState() {
    super.initState();
    _load();
    _initMe();
    _initPostAuthor();
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _svc.getComments(widget.postId, page: 1, limit: 100, newestFirst: true);
    final uid = await CurrentUser.id;
    final likedIds = <String>{};
    final ids = <String>[];
    for (final c in list) {
      try {
        final cid = (c['_id'] as String?) ?? (c['id'] as String?) ?? '';
        if (cid.isNotEmpty) ids.add(cid);
        bool likedByMe = false;
        if (c['is_liked_by_me'] == true || c['liked_by_me'] == true || c['liked'] == true) {
          likedByMe = true;
        } else if (uid != null) {
          final likes = c['likes'];
          if (likes is List) {
            for (final e in likes) {
              if (e is Map) {
                final lu = (e['user_id'] ?? e['uid'] ?? e['id'])?.toString();
                final flag = (e['like'] ?? e['liked'] ?? e['status']) as bool?;
                if (lu == uid && (flag == null ? true : flag == true)) {
                  likedByMe = true;
                  break;
                }
              } else if (e is String) {
                if (e == uid) {
                  likedByMe = true;
                  break;
                }
              }
            }
          }
        }
        final override = _svc.getCommentLikeOverride(cid);
        if (override != null) likedByMe = override;
        if (likedByMe && cid.isNotEmpty) likedIds.add(cid);
      } catch (_) {}
    }
    final preloadedReplies = await _svc.loadRepliesCacheFor(ids);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _liked
        ..clear()
        ..addAll(likedIds);
      for (final entry in preloadedReplies.entries) {
        _replies[entry.key] = entry.value;
      }
      _loading = false;
    });
  }

  Future<void> _initMe() async {
    final uid = await CurrentUser.id;
    if (uid == null) return;
    final me = await _svc.getUserById(uid);
    if (!mounted) return;
    setState(() {
      _me = me;
    });
  }

  Future<void> _initPostAuthor() async {
    final data = await _svc.getPostById(widget.postId);
    if (!mounted) return;
    String? username;
    if (data != null) {
      if (data['user_id'] is Map) {
        final u = data['user_id'] as Map<String, dynamic>;
        username = u['username'] as String?;
      } else if (data['users'] is Map) {
        final u = data['users'] as Map<String, dynamic>;
        username = u['username'] as String?;
      } else if (data['username'] is String) {
        username = data['username'] as String;
      }
    }
    setState(() {
      _postAuthorName = username;
    });
  }

  Future<void> _postComment() async {
    final text = _controller.text.trim();
    final uid = await CurrentUser.id;
    if (text.isEmpty || uid == null) return;
    final isReply = _replyParentId != null && _replyParentId!.isNotEmpty;
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final me = _me ?? await _svc.getUserById(uid);
    setState(() {
      _posting = true;
      if (!isReply) {
        _comments = [
          {
            '_id': tempId,
            'user': me ?? {'username': 'me'},
            'text': text,
            'createdAt': DateTime.now().toIso8601String(),
            'likes_count': 0,
            'pending': true,
          },
          ..._comments
        ];
      } else {
        final parentId = _replyParentId!;
        final existingReplies = List<Map<String, dynamic>>.from(_replies[parentId] ?? const []);
        existingReplies.insert(0, {
          '_id': tempId,
          'parent_id': parentId,
          'user': me ?? {'username': 'me'},
          'text': text,
          'createdAt': DateTime.now().toIso8601String(),
          'likes_count': 0,
          'pending': true,
        });
        _replies[parentId] = existingReplies;
        _svc.setRepliesCache(parentId, existingReplies);
        final parentIndex = _comments.indexWhere((c) {
          final cid = (c['_id'] as String?) ?? (c['id'] as String?) ?? '';
          return cid == parentId;
        });
        if (parentIndex >= 0) {
          final updatedParent = Map<String, dynamic>.from(_comments[parentIndex]);
          final rc = (updatedParent['replies_count'] as int?) ??
              (updatedParent['replyCount'] as int?) ??
              (updatedParent['repliesCount'] as int?) ??
              0;
          updatedParent['replies_count'] = rc + 1;
          _comments[parentIndex] = updatedParent;
        }
      }
    });
    final createdRaw = await _svc.addComment(widget.postId, uid, text, parentId: _replyParentId);
    if (createdRaw != null) {
      Map<String, dynamic> created = createdRaw;
      if (created['user'] == null) {
        final meUser = await _svc.getUserById(uid);
        if (meUser != null) {
          created = {
            ...created,
            'user': meUser,
            'created_at': created['created_at'] ?? created['createdAt'] ?? DateTime.now().toIso8601String(),
            'content': created['content'] ?? created['text'] ?? text,
          };
        }
      }
      if (!isReply) {
        setState(() {
          final idx = _comments.indexWhere((x) => (x['_id'] ?? x['id']) == tempId);
          if (idx >= 0) {
            _comments[idx] = created;
          } else {
            _comments = [created, ..._comments];
          }
          _replyParentId = null;
          _replyingTo = null;
        });
      } else {
        final parentId = _replyParentId!;
        setState(() {
          final existingReplies = List<Map<String, dynamic>>.from(_replies[parentId] ?? const []);
          final idx = existingReplies.indexWhere((r) => (r['_id'] ?? r['id']) == tempId);
          if (idx >= 0) {
            existingReplies[idx] = created;
          } else {
            existingReplies.insert(0, created);
          }
          _replies[parentId] = existingReplies;
          _svc.setRepliesCache(parentId, existingReplies);
          final parentIndex = _comments.indexWhere((c) {
            final cid = (c['_id'] as String?) ?? (c['id'] as String?) ?? '';
            return cid == parentId;
          });
          if (parentIndex >= 0) {
            final updatedParent = Map<String, dynamic>.from(_comments[parentIndex]);
            final rc = (updatedParent['replies_count'] as int?) ??
                (updatedParent['replyCount'] as int?) ??
                (updatedParent['repliesCount'] as int?) ??
                0;
            updatedParent['replies_count'] = (rc > 0 ? rc : 0) + 1;
            _comments[parentIndex] = updatedParent;
          }
          _replyParentId = null;
          _replyingTo = null;
        });
      }
      _controller.clear();
    }
    if (mounted) setState(() => _posting = false);
  }

  Widget _avatar(String? url, String fallback, {double size = 18, bool ring = false}) {
    final child = CircleAvatar(
      radius: size,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: (url == null || url.isEmpty)
          ? Text(fallback, style: TextStyle(fontSize: size - 4, color: Theme.of(context).colorScheme.primary))
          : null,
    );
    if (!ring || url == null || url.isEmpty) return child;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [Colors.pinkAccent, Colors.orangeAccent]),
      ),
      child: child,
    );
  }

  Future<void> _toggleLike(Map<String, dynamic> c, int index) async {
    final id = (c['_id'] as String?) ?? (c['id'] as String?) ?? '';
    if (id.isEmpty) return;
    final liked = _liked.contains(id);
    setState(() {
      if (liked) {
        _liked.remove(id);
      } else {
        _liked.add(id);
      }
      final cc = Map<String, dynamic>.from(_comments[index]);
      final count = (cc['likes_count'] as int?) ?? 0;
      cc['likes_count'] = liked ? (count - 1).clamp(0, 1 << 31) : count + 1;
      _comments[index] = cc;
    });
    if (liked) {
      final res = await _svc.unlikeComment(id);
      if (res != null) {
        setState(() {
          final cc = Map<String, dynamic>.from(_comments[index]);
          if (res.containsKey('likes_count')) {
            cc['likes_count'] = res['likes_count'] as int? ?? cc['likes_count'];
          }
          final likedNow = res['liked'] as bool?; // API returns authoritative state
          if (likedNow != null) {
            if (likedNow) {
              _liked.add(id);
            } else {
              _liked.remove(id);
            }
            _svc.setCommentLikeOverride(id, likedNow);
          }
          _comments[index] = cc;
        });
      }
    } else {
      final res = await _svc.likeComment(id);
      if (res != null) {
        setState(() {
          final cc = Map<String, dynamic>.from(_comments[index]);
          if (res.containsKey('likes_count')) {
            cc['likes_count'] = res['likes_count'] as int? ?? cc['likes_count'];
          }
          final likedNow = res['liked'] as bool?;
          if (likedNow != null) {
            if (likedNow) {
              _liked.add(id);
            } else {
              _liked.remove(id);
            }
            _svc.setCommentLikeOverride(id, likedNow);
          }
          _comments[index] = cc;
        });
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> c, int index) async {
    final id = (c['_id'] as String?) ?? (c['id'] as String?) ?? '';
    if (id.isEmpty) return;
    final ok = await _svc.deleteComment(id);
    if (ok) {
      setState(() {
        _comments.removeAt(index);
      });
    }
  }

  Future<void> _loadRepliesFor(String commentId) async {
    if (_loadingReplies.contains(commentId)) return;
    setState(() => _loadingReplies.add(commentId));
    final list = await _svc.getReplies(commentId, page: 1, limit: 10);
    if (!mounted) return;
    setState(() {
      _replies[commentId] = list;
      _svc.setRepliesCache(commentId, list);
      _loadingReplies.remove(commentId);
    });
  }

  void _appendEmoji(String e) {
    _controller.text = '${_controller.text}$e';
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    FocusScope.of(context).requestFocus(_inputFocus);
  }

  void _startReply(String parentId, String username) {
    setState(() {
      _replyParentId = parentId;
      _replyingTo = username;
    });
    FocusScope.of(context).requestFocus(_inputFocus);
  }

  void _cancelReply() {
    setState(() {
      _replyParentId = null;
      _replyingTo = null;
    });
  }

  void _onLongPressComment(Map<String, dynamic> c, bool isMine, int index) {
    if (!isMine) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.of(ctx).pop();
                _delete(c, index);
              },
            ),
            ListTile(
              title: const Text('Cancel'),
              onTap: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  String _relative(String dateString) {
    final d = DateTime.tryParse(dateString);
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Comments',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, color: theme.iconTheme.color),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: DesignTokens.instaPink))
                  : (_comments.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No comments yet.\nBe the first to comment.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _comments.length,
                          itemBuilder: (context, i) {
                            final c = _comments[i];
                            final u = c['user'] as Map<String, dynamic>? ?? {};
                            final un = u['username'] as String? ?? 'user';
                            final av = u['avatar_url'] as String?;
                            final content = c['content'] as String? ?? c['text'] as String? ?? '';
                            final created = c['created_at'] as String? ?? c['createdAt'] as String? ?? '';
                            final cid = (c['_id'] as String?) ?? (c['id'] as String?) ?? '';
                            final isVerified = (u['is_verified'] as bool?) ?? false;
                            final userIdValue = (u['id'] ?? u['_id'] ?? u['user_id'])?.toString();
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: FutureBuilder<String?>(
                                future: CurrentUser.id,
                                builder: (ctx, snap) {
                                  final myId = snap.data;
                                  final isMine = myId != null &&
                                      ((u['id'] as String?) == myId ||
                                          (u['_id'] as String?) == myId ||
                                          (u['user_id'] as String?) == myId);
                                  final liked = _liked.contains(cid);
                                  final likesCount = (c['likes_count'] as int?) ?? 0;
                                  final isPending = c['pending'] == true;
                                  return GestureDetector(
                                    onLongPress: () => _onLongPressComment(c, isMine, i),
                                    child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              GestureDetector(
                                                onTap: userIdValue != null && userIdValue.isNotEmpty
                                                    ? () => Navigator.of(context).pushNamed('/profile/$userIdValue')
                                                    : null,
                                                child: _avatar(av, un.isNotEmpty ? un[0].toUpperCase() : 'U', size: 16, ring: av != null && av.isNotEmpty),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        GestureDetector(
                                                          onTap: userIdValue != null && userIdValue.isNotEmpty
                                                              ? () => Navigator.of(context).pushNamed('/profile/$userIdValue')
                                                              : null,
                                                          child: Text(un, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                        ),
                                                        if (isVerified)
                                                          Padding(
                                                            padding: const EdgeInsets.only(left: 4),
                                                            child: Icon(Icons.check_circle, size: 14, color: Colors.blueAccent),
                                                          ),
                                                        const SizedBox(width: 8),
                                                        Text(_relative(created), style: theme.textTheme.bodySmall),
                                                      ],
                                                    ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  content,
                                                  style: theme.textTheme.bodyMedium?.copyWith(
                                                    color: isPending ? theme.colorScheme.onSurfaceVariant : theme.textTheme.bodyMedium?.color,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                TextButton(
                                                  onPressed: () => _startReply(cid, un),
                                                  child: Text('Reply', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 40,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    liked ? Icons.favorite : LucideIcons.heart,
                                                    size: 20,
                                                    color: liked ? Colors.red : theme.iconTheme.color,
                                                  ),
                                                  onPressed: () => _toggleLike(c, i),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                                if (likesCount > 0)
                                                  Text(
                                                    '$likesCount',
                                                    style: theme.textTheme.bodySmall,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Builder(builder: (context) {
                                        final hasReplies = ((c['replies'] as List?)?.isNotEmpty ?? false) ||
                                            (((c['replies_count'] as int?) ?? (c['replyCount'] as int?) ?? (c['repliesCount'] as int?) ?? 0) > 0) ||
                                            ((_replies[cid]?.isNotEmpty ?? false));
                                        if (!hasReplies) return const SizedBox.shrink();
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton(
                                            onPressed: () => _loadRepliesFor(cid),
                                            child: Text(
                                              _replies[cid] != null && _replies[cid]!.isNotEmpty
                                                  ? 'View ${_replies[cid]!.length} ${_replies[cid]!.length == 1 ? 'reply' : 'replies'}'
                                                  : 'View replies',
                                              style: theme.textTheme.bodySmall?.copyWith(color: DesignTokens.instaPink),
                                            ),
                                          ),
                                        );
                                      }),
                                      if (_loadingReplies.contains(cid))
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          child: SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: DesignTokens.instaPink),
                                          ),
                                        ),
                                      if (_replies[cid] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 42, right: 8, bottom: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: _replies[cid]!
                                                .map((r) {
                                                  final ru = r['user'] as Map<String, dynamic>?;
                                                  final rn = ru?['username'] as String? ?? 'user';
                                                  final rav = ru?['avatar_url'] as String?;
                                                  final rcontent = r['content'] as String? ?? r['text'] as String? ?? '';
                                                  final rcreated = r['created_at'] as String? ?? r['createdAt'] as String? ?? '';
                                                  final rUserIdValue =
                                                      (ru?['id'] ?? ru?['_id'] ?? ru?['user_id'])?.toString();
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                                    child: Row(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: rUserIdValue != null && rUserIdValue.isNotEmpty
                                                              ? () => Navigator.of(context).pushNamed('/profile/$rUserIdValue')
                                                              : null,
                                                          child: _avatar(
                                                              rav, rn.isNotEmpty ? rn[0].toUpperCase() : 'U', size: 14, ring: rav != null && rav.isNotEmpty),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              GestureDetector(
                                                                onTap: rUserIdValue != null && rUserIdValue.isNotEmpty
                                                                    ? () => Navigator.of(context).pushNamed('/profile/$rUserIdValue')
                                                                    : null,
                                                                child: RichText(
                                                                  text: TextSpan(
                                                                    style: theme.textTheme.bodyMedium,
                                                                    children: [
                                                                      TextSpan(text: '$rn ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                                                      TextSpan(text: rcontent),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(height: 2),
                                                              Text(_relative(rcreated), style: theme.textTheme.bodySmall),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                          ),
                                        ),
                                    ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        )),
            ),
            const Divider(height: 1),
            if (_replyParentId != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${_replyingTo ?? ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    TextButton(onPressed: _cancelReply, child: const Text('Cancel')),
                  ],
                ),
              ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _emojis.length,
                itemBuilder: (ctx, idx) {
                  final e = _emojis[idx];
                  return GestureDetector(
                    onTap: () => _appendEmoji(e),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: (_me?['avatar_url'] is String && (_me?['avatar_url'] as String).isNotEmpty)
                        ? NetworkImage(_me?['avatar_url'] as String)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _controller,
                        focusNode: _inputFocus,
                        decoration: InputDecoration(
                          hintText: _postAuthorName != null && _postAuthorName!.isNotEmpty
                              ? 'Add a comment for $_postAuthorName...'
                              : 'Add a comment...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          hintStyle: TextStyle(color: theme.hintColor),
                        ),
                        onSubmitted: (_) => _postComment(),
                      ),
                    ),
                  ),
                  TextButton(onPressed: () {}, child: const Text('GIF')),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return TextButton(
                        onPressed: _posting || !hasText ? null : _postComment,
                        child: Text(
                          'Post',
                          style: TextStyle(
                            color: hasText ? DesignTokens.instaPink : theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
