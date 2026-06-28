import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/promote_reels_api.dart';
import '../services/comment_sync_service.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../widgets/safe_network_image.dart';

class PromoteCommentsSheet extends StatefulWidget {
  final String promoteReelId;
  final int initialCount;
  final ValueChanged<int>? onCountChanged;

  const PromoteCommentsSheet({
    super.key,
    required this.promoteReelId,
    this.initialCount = 0,
    this.onCountChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String promoteReelId,
    int initialCount = 0,
    ValueChanged<int>? onCountChanged,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: PromoteCommentsSheet(
          promoteReelId: promoteReelId,
          initialCount: initialCount,
          onCountChanged: onCountChanged,
        ),
      ),
    );
  }

  @override
  State<PromoteCommentsSheet> createState() => _PromoteCommentsSheetState();
}

class _PromoteCommentsSheetState extends State<PromoteCommentsSheet> {
  final _api = PromoteReelsApi();
  final _commentSync = CommentSyncService();
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();

  bool _loading = true;
  bool _posting = false;
  List<Map<String, dynamic>> _comments = const [];
  final Map<String, List<Map<String, dynamic>>> _replies = {};
  final Set<String> _liked = <String>{};
  final Set<String> _loadingReplies = <String>{};
  StreamSubscription<CommentChangeEvent>? _commentSyncSub;

  String? _replyParentId;
  String? _replyingTo;
  String? _myId;
  int _count = 0;

  String _toId(dynamic v) => (v ?? '').toString().trim();

  String _commentId(Map<String, dynamic> c) =>
      _toId(c['_id'] ?? c['id'] ?? c['comment_id'] ?? c['commentId']);

  Map<String, dynamic>? _userOf(Map<String, dynamic> c) {
    final u = c['user'] ?? c['users'] ?? c['author'];
    if (u is Map) return Map<String, dynamic>.from(u);
    return null;
  }

  String _userId(Map<String, dynamic>? u) =>
      _toId(u?['_id'] ?? u?['id'] ?? u?['user_id'] ?? u?['uid']);

  String _userName(Map<String, dynamic>? u) {
    final username = _toId(u?['username'] ?? u?['handle']);
    if (username.isNotEmpty) return username;
    final full = _toId(u?['full_name'] ?? u?['name']);
    return full.isNotEmpty ? full : 'user';
  }

  String _userAvatar(Map<String, dynamic>? u) => _toId(
        u?['avatar_url'] ??
            u?['profile_picture'] ??
            u?['profilePicture'] ??
            u?['profile_pic'] ??
            u?['avatarUrl'],
      );

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  String _relative(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    DateTime? dt;
    try {
      dt = DateTime.tryParse(s);
      if (dt != null && dt.isUtc) dt = dt.toLocal();
    } catch (_) {}
    if (dt == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    final w = (diff.inDays / 7).floor();
    if (w < 5) return '${w}w';
    final mo = (diff.inDays / 30).floor();
    if (mo < 12) return '${mo}mo';
    final y = (diff.inDays / 365).floor();
    return '${y}y';
  }

  void _applyExternalCommentLikeState(String commentId, bool liked) {
    final id = commentId.trim();
    if (id.isEmpty) return;

    void updateIn(List<Map<String, dynamic>> list) {
      for (final c in list) {
        if (_commentId(c) != id) continue;
        final currentLiked = _liked.contains(id);
        if (currentLiked == liked) return;
        final cur = _toInt(c['likes_count'] ?? c['likesCount'] ?? c['like_count']);
        c['is_liked_by_me'] = liked;
        c['liked_by_me'] = liked;
        c['liked'] = liked;
        c['is_liked'] = liked;
        c['likes_count'] = liked ? cur + 1 : (cur > 0 ? cur - 1 : 0);
        return;
      }
    }

    setState(() {
      updateIn(_comments);
      for (final entry in _replies.entries) {
        updateIn(entry.value);
      }
      if (liked) {
        _liked.add(id);
      } else {
        _liked.remove(id);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
    _commentSyncSub = _commentSync.changes.listen((event) {
      if (!mounted) return;
      if (event.postId != widget.promoteReelId) return;
      if (event.commentId == null || event.liked == null) return;
      _applyExternalCommentLikeState(event.commentId!, event.liked!);
    });
    unawaited(_init());
  }

  @override
  void dispose() {
    _commentSyncSub?.cancel();
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _myId = await CurrentUser.id;
    await _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await _api.getComments(widget.promoteReelId);
      List<dynamic> list = const [];
      if (res is Map) {
        final data = res['data'] ?? res['comments'];
        if (data is List) list = data;
      } else if (res is List) {
        list = res;
      }
      final comments = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final liked = <String>{};
      for (final c in comments) {
        final id = _commentId(c);
        if (id.isEmpty) continue;
        final likedByMe = c['is_liked_by_me'] == true ||
            c['liked_by_me'] == true ||
            c['liked'] == true;
        if (likedByMe) liked.add(id);
      }
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _liked
          ..clear()
          ..addAll(liked);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _comments = const [];
        _liked.clear();
        _loading = false;
      });
    }
  }

  Future<void> _loadReplies(String commentId) async {
    if (commentId.isEmpty || _loadingReplies.contains(commentId)) return;
    setState(() => _loadingReplies.add(commentId));
    try {
      final res = await _api.getReplies(commentId);
      List<dynamic> list = const [];
      if (res is Map) {
        final data = res['data'] ?? res['replies'];
        if (data is List) list = data;
      } else if (res is List) {
        list = res;
      }
      final replies = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _replies[commentId] = replies;
        _loadingReplies.remove(commentId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingReplies.remove(commentId));
    }
  }

  void _setCount(int next) {
    final bounded = next < 0 ? 0 : next;
    _count = bounded;
    widget.onCountChanged?.call(bounded);
  }

  Future<void> _send() async {
    if (_posting) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    try {
      final created = await _api.addComment(
        widget.promoteReelId,
        text: text,
        parentId: _replyParentId,
      );
      final map = Map<String, dynamic>.from(created);
      if (!mounted) return;
      setState(() {
        _controller.clear();
        if (_replyParentId != null && _replyParentId!.isNotEmpty) {
          final pid = _replyParentId!;
          final list = List<Map<String, dynamic>>.from(_replies[pid] ?? const []);
          list.insert(0, map);
          _replies[pid] = list;
        } else {
          _comments = [map, ..._comments];
        }
        _replyParentId = null;
        _replyingTo = null;
        _posting = false;
      });
      _setCount(_count + 1);
      _inputFocus.requestFocus();
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post comment')),
      );
    }
  }

  Future<void> _toggleLike(String commentId) async {
    if (commentId.isEmpty) return;
    final wasLiked = _liked.contains(commentId);
    setState(() {
      if (wasLiked) {
        _liked.remove(commentId);
      } else {
        _liked.add(commentId);
      }
      _bumpLikeCount(commentId, wasLiked ? -1 : 1);
    });
    try {
      if (wasLiked) {
        await _api.unlikeComment(commentId);
      } else {
        await _api.likeComment(commentId);
      }
      _commentSync.notifyChanged(
        postId: widget.promoteReelId,
        isTweet: false,
        commentId: commentId,
        liked: !wasLiked,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasLiked) {
          _liked.add(commentId);
          _bumpLikeCount(commentId, 1);
        } else {
          _liked.remove(commentId);
          _bumpLikeCount(commentId, -1);
        }
      });
    }
  }

  void _bumpLikeCount(String commentId, int delta) {
    bool updateIn(List<Map<String, dynamic>> list) {
      for (final c in list) {
        if (_commentId(c) != commentId) continue;
        final cur = _toInt(c['likes_count'] ?? c['likesCount'] ?? c['like_count']);
        c['likes_count'] = (cur + delta) < 0 ? 0 : (cur + delta);
        return true;
      }
      return false;
    }

    if (updateIn(_comments)) return;
    for (final entry in _replies.entries) {
      if (updateIn(entry.value)) return;
    }
  }

  Future<void> _deleteComment(String commentId, {required bool isReply, String? parentId}) async {
    if (commentId.isEmpty) return;
    try {
      if (isReply) {
        final pid = (parentId ?? '').trim();
        if (pid.isEmpty) return;
        await _api.deleteReply(pid, commentId);
      } else {
        await _api.deleteComment(commentId);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      if (isReply) {
        final pid = (parentId ?? '').trim();
        final list = List<Map<String, dynamic>>.from(_replies[pid] ?? const []);
        list.removeWhere((c) => _commentId(c) == commentId);
        _replies[pid] = list;
      } else {
        _comments = _comments.where((c) => _commentId(c) != commentId).toList();
        _replies.remove(commentId);
      }
      _liked.remove(commentId);
    });
    _setCount(_count - 1);
  }

  void _startReply(Map<String, dynamic> comment) {
    final id = _commentId(comment);
    if (id.isEmpty) return;
    final user = _userOf(comment);
    setState(() {
      _replyParentId = id;
      _replyingTo = _userName(user);
    });
    _inputFocus.requestFocus();
  }

  Widget _buildCommentTile(Map<String, dynamic> c, {String? parentId}) {
    final id = _commentId(c);
    final user = _userOf(c);
    final name = _userName(user);
    final avatar = _userAvatar(user);
    final text = (c['text'] ?? c['comment'] ?? '').toString();
    final created = (c['created_at'] ?? c['createdAt'] ?? c['created'] ?? '')
        .toString();
    final likesCount = _toInt(c['likes_count'] ?? c['likesCount'] ?? c['like_count']);
    final isLiked = _liked.contains(id);
    final mine = _myId != null && _myId!.isNotEmpty && _userId(user) == _myId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: avatar.isNotEmpty
                  ? SafeNetworkImage(
                      url: avatar,
                      width: 34,
                      height: 34,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: DesignTokens.instaPurple.withValues(alpha: 0.18),
                        alignment: Alignment.center,
                        child: const Icon(LucideIcons.user,
                            color: Colors.white70, size: 18),
                      ),
                      errorWidget: Container(
                        color: DesignTokens.instaPurple.withValues(alpha: 0.18),
                        alignment: Alignment.center,
                        child: Text(
                          name.isEmpty ? 'U' : name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      color: DesignTokens.instaPurple.withValues(alpha: 0.18),
                      alignment: Alignment.center,
                      child: Text(
                        name.isEmpty ? 'U' : name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style.copyWith(
                          fontSize: 13,
                          height: 1.3,
                        ),
                    children: [
                      TextSpan(
                        text: name.isEmpty ? 'User' : name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(text: text.isEmpty ? '-' : text),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _relative(created),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (likesCount > 0) ...[
                      const SizedBox(width: 10),
                      Text(
                        '$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: id.isEmpty ? null : () => _startReply(c),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Reply',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: id.isEmpty
                            ? null
                            : () => unawaited(_deleteComment(
                                  id,
                                  isReply: parentId != null,
                                  parentId: parentId,
                                )),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Delete',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                  onPressed: id.isEmpty ? null : () => _toggleLike(id),
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? DesignTokens.instaPink : Colors.grey,
                  ),
                ),
                if (likesCount > 0)
                  Text(
                    _fmt(likesCount),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (!isDesktop) ...[
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Comments ($_count)',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
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
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: DesignTokens.instaPink),
                    )
                  : (_comments.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No comments yet.\nBe the first to comment.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            final c = _comments[index];
                            final cid = _commentId(c);
                            final replies = _replies[cid] ?? const [];
                            final loadingReplies =
                                _loadingReplies.contains(cid);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildCommentTile(c),
                                if (cid.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 60, right: 16, bottom: 8),
                                    child: Row(
                                      children: [
                                        TextButton(
                                          onPressed: () => _loadReplies(cid),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            loadingReplies
                                                ? 'Loading replies…'
                                                : replies.isEmpty
                                                    ? 'View replies'
                                                    : 'Refresh replies (${replies.length})',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (replies.isNotEmpty)
                                  ...replies.map(
                                    (r) => Padding(
                                      padding: const EdgeInsets.only(left: 22),
                                      child:
                                          _buildCommentTile(r, parentId: cid),
                                    ),
                                  ),
                                const Divider(height: 1),
                              ],
                            );
                          },
                        )),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_replyingTo != null && _replyingTo!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Replying to @$_replyingTo',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _replyParentId = null;
                                  _replyingTo = null;
                                });
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _inputFocus,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Add a comment…',
                              filled: true,
                              fillColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          onPressed: _posting ? null : _send,
                          icon: _posting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(LucideIcons.send),
                          color: DesignTokens.instaPink,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
