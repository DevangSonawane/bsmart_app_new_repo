import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../api/api_client.dart';
import '../api/api_exceptions.dart';
import '../services/comment_sync_service.dart';
import '../services/supabase_service.dart';
import '../utils/current_user.dart';
import '../theme/design_tokens.dart';
import '../state/app_state.dart';
import '../state/feed_actions.dart';
import '../models/feed_post_model.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final bool isTweet;
  const CommentsSheet({super.key, required this.postId, this.isTweet = false});

  static Future<void> show(BuildContext context, String postId,
      {bool isTweet = false}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: CommentsSheet(postId: postId, isTweet: isTweet),
      ),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final SupabaseService _svc = SupabaseService();
  final CommentSyncService _commentSync = CommentSyncService();
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _loadingPost = true;
  bool _posting = false;
  final Set<String> _liked = {};
  final Set<String> _expandedComments = {};
  final Map<String, List<Map<String, dynamic>>> _replies = {};
  final Set<String> _loadingReplies = {};
  String? _replyParentId;
  String? _replyingTo;
  final FocusNode _inputFocus = FocusNode();
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _post;
  late bool _isTweet;
  StreamSubscription<CommentChangeEvent>? _commentSyncSub;

  String _toId(dynamic v) => (v ?? '').toString().trim();

  bool _isDuplicateCommentLikeError(Object error) {
    if (error is! ApiException) return false;
    final message = error.message.toLowerCase();
    return error.statusCode == 409 ||
        (error.statusCode == 400 &&
            (message.contains('already liked') ||
                message.contains('already unliked') ||
                message.contains('already exists') ||
                message.contains('duplicate') ||
                message.contains('conflict')));
  }

  String _commentIdOf(Map<String, dynamic> c) {
    return _toId(c['_id'] ?? c['id'] ?? c['comment_id'] ?? c['commentId']);
  }

  String _userIdFromMap(Map<String, dynamic>? user) {
    if (user == null) return '';
    return _toId(user['id'] ?? user['_id'] ?? user['user_id'] ?? user['uid']);
  }

  bool _isMineUser(Map<String, dynamic>? user, String? myId) {
    final mid = (myId ?? '').trim();
    if (mid.isEmpty) return false;
    final uid = _userIdFromMap(user);
    return uid.isNotEmpty && uid == mid;
  }

  void _dispatchCommentsDelta(int delta) {
    if (!mounted || delta == 0) return;
    final store = StoreProvider.of<AppState>(context, listen: false);
    FeedPost? post;
    for (final p in store.state.feedState.posts) {
      if (p.id == widget.postId) {
        post = p;
        break;
      }
    }
    if (post == null) return;
    final next = post.comments + delta;
    store.dispatch(UpdatePostCommentsCount(widget.postId, next < 0 ? 0 : next));
  }

  void _applyExternalCommentLikeState(String commentId, bool liked) {
    final id = commentId.trim();
    if (id.isEmpty) return;

    void updateComment(Map<String, dynamic> comment) {
      if (_commentIdOf(comment) != id) return;
      final currentLiked = _liked.contains(id);
      if (currentLiked == liked) return;
      final currentCount = _toInt(
        comment['likes_count'] ??
            comment['likesCount'] ??
            comment['like_count'] ??
            comment['likeCount'] ??
            comment['likes'],
      );
      comment['is_liked_by_me'] = liked;
      comment['liked_by_me'] = liked;
      comment['liked'] = liked;
      comment['is_liked'] = liked;
      comment['likes_count'] =
          liked ? currentCount + 1 : (currentCount > 0 ? currentCount - 1 : 0);
    }

    setState(() {
      for (final comment in _comments) {
        updateComment(comment);
      }
      for (final replies in _replies.values) {
        for (final reply in replies) {
          updateComment(reply);
        }
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
    _isTweet = widget.isTweet;
    _commentSyncSub = _commentSync.changes.listen((event) {
      if (!mounted) return;
      if (event.commentId != null && event.liked != null) {
        _applyExternalCommentLikeState(event.commentId!, event.liked!);
        return;
      }
      if (event.postId != widget.postId || event.isTweet != _isTweet) return;
      unawaited(_load());
    });
    _load();
    _initMe();
    _loadPost();
  }

  @override
  void dispose() {
    _commentSyncSub?.cancel();
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _svc.getComments(
      widget.postId,
      page: 1,
      limit: 100,
      newestFirst: true,
      isTweet: _isTweet,
    );
    final uid = await CurrentUser.id;
    final likedIds = <String>{};
    final ids = <String>[];
    for (final c in list) {
      try {
        final cid = _commentIdOf(c);
        if (cid.isNotEmpty) ids.add(cid);
        bool likedByMe = false;
        if (c['is_liked_by_me'] == true ||
            c['liked_by_me'] == true ||
            c['liked'] == true) {
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
      _expandedComments.clear();
      _liked
        ..clear()
        ..addAll(likedIds);
      for (final entry in preloadedReplies.entries) {
        _replies[entry.key] = entry.value;
      }
      _loading = false;
    });

    // React parity: eagerly fetch replies for each top-level comment.
    for (final id in ids) {
      unawaited(() async {
        final replies =
            await _svc.getReplies(id, page: 1, limit: 50, isTweet: _isTweet);
        if (!mounted) return;
        setState(() {
          _replies[id] = replies;
          _svc.setRepliesCache(id, replies);
        });
      }());
    }
  }

  Future<void> _loadPost() async {
    setState(() => _loadingPost = true);
    try {
      final post = await _svc.getPostById(widget.postId, isTweet: _isTweet);
      if (!mounted) return;
      final itemType = (post?['item_type'] ?? post?['itemType'] ?? '')
          .toString()
          .toLowerCase();
      if (itemType == 'tweet') _isTweet = true;
      setState(() {
        _post = post;
        _loadingPost = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _post = null;
        _loadingPost = false;
      });
    }
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
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return const [];
      if (s.contains(',')) {
        return s
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [s];
    }
    return const [];
  }

  Map<String, dynamic> _commentUserMap(Map<String, dynamic> c) {
    Map<String, dynamic>? pick(dynamic value) {
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);
        final nested = m['user'];
        if (nested is Map) return Map<String, dynamic>.from(nested);
        return m;
      }
      return null;
    }

    return pick(c['user']) ??
        pick(c['user_id']) ??
        pick(c['userId']) ??
        pick(c['users']) ??
        pick(c['author']) ??
        pick(c['posted_by']) ??
        pick(c['commented_by']) ??
        <String, dynamic>{};
  }

  String _commentUsername(Map<String, dynamic> c) {
    final u = _commentUserMap(c);
    final username = (u['username'] ??
            u['full_name'] ??
            u['name'] ??
            u['business_name'] ??
            u['company_name'])
        ?.toString()
        .trim();
    if (username != null && username.isNotEmpty) return username;
    final fallback = (c['username'] ??
            c['user_name'] ??
            c['userName'] ??
            c['author_name'] ??
            c['authorName'])
        ?.toString()
        .trim();
    return (fallback != null && fallback.isNotEmpty) ? fallback : 'user';
  }

  String? _commentAvatar(Map<String, dynamic> c) {
    final u = _commentUserMap(c);
    final url = (u['avatar_url'] ??
            u['avatarUrl'] ??
            u['avatar'] ??
            u['profile_image'] ??
            u['profileImage'] ??
            c['avatar_url'])
        ?.toString()
        .trim();
    return (url != null && url.isNotEmpty) ? url : null;
  }

  bool _commentVerified(Map<String, dynamic> c) {
    final u = _commentUserMap(c);
    return u['is_verified'] == true || u['verified'] == true;
  }

  Widget _buildAdInfo(Map<String, dynamic> post) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final category = (post['category'] ?? '').toString().trim();
    final budget =
        _toInt(post['total_budget_coins'] ?? post['totalBudgetCoins']);
    final views = _toInt(post['views_count'] ?? post['viewsCount']);
    final unique =
        _toInt(post['unique_views_count'] ?? post['uniqueViewsCount']);
    final completed =
        _toInt(post['completed_views_count'] ?? post['completedViewsCount']);
    final targetLocations =
        _asStringList(post['target_location'] ?? post['targetLocation']);
    final targetLanguages = _asStringList(post['target_language'] ??
        post['target_languages'] ??
        post['targetLanguage'] ??
        post['targetLanguages']);

    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final surface =
        isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.55);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1A3B82F6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x333B82F6)),
                  ),
                  child: Text(
                    category,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB)),
                  ),
                ),
              if (budget > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1AF59E0B),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x33F59E0B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.coins,
                          size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        '${_fmt(budget)} bCoins budget',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD97706)),
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
                if (views > 0)
                  Text('${_fmt(views)} views',
                      style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontWeight: FontWeight.w600)),
                if (unique > 0)
                  Text('${_fmt(unique)} unique',
                      style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontWeight: FontWeight.w600)),
                if (completed > 0)
                  Text('${_fmt(completed)} completed',
                      style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          if (targetLocations.isNotEmpty || targetLanguages.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (targetLocations.isNotEmpty)
              Text(
                '📍 ${targetLocations.join(', ')}',
                style: TextStyle(
                    fontSize: 12, color: muted, fontWeight: FontWeight.w600),
              ),
            if (targetLanguages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '🌐 ${targetLanguages.join(', ')}',
                  style: TextStyle(
                      fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
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

  Future<void> _postComment() async {
    final text = _controller.text.trim();
    final uid = await CurrentUser.id;
    if (text.isEmpty || uid == null) return;
    final isReply = _replyParentId != null && _replyParentId!.isNotEmpty;
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final me = _me ?? await _svc.getUserById(uid);
    var bumpedParentReplyCount = false;
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
        final existingReplies =
            List<Map<String, dynamic>>.from(_replies[parentId] ?? const []);
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
          return _commentIdOf(c) == parentId;
        });
        if (parentIndex >= 0) {
          final updatedParent =
              Map<String, dynamic>.from(_comments[parentIndex]);
          final rc = (updatedParent['replies_count'] as int?) ??
              (updatedParent['replyCount'] as int?) ??
              (updatedParent['repliesCount'] as int?) ??
              0;
          updatedParent['replies_count'] = rc + 1;
          _comments[parentIndex] = updatedParent;
          bumpedParentReplyCount = true;
        }
      }
    });
    final createdRaw = await _svc.addComment(
      widget.postId,
      uid,
      text,
      parentId: _replyParentId,
      isTweet: _isTweet,
    );
    if (createdRaw != null) {
      Map<String, dynamic> created = createdRaw;
      if (created['user'] == null) {
        final meUser = await _svc.getUserById(uid);
        if (meUser != null) {
          created = {
            ...created,
            'user': meUser,
            'created_at': created['created_at'] ??
                created['createdAt'] ??
                DateTime.now().toIso8601String(),
            'content': created['content'] ?? created['text'] ?? text,
          };
        }
      }
      if (!isReply) {
        setState(() {
          final idx =
              _comments.indexWhere((x) => (x['_id'] ?? x['id']) == tempId);
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
          final existingReplies =
              List<Map<String, dynamic>>.from(_replies[parentId] ?? const []);
          final idx = existingReplies
              .indexWhere((r) => (r['_id'] ?? r['id']) == tempId);
          if (idx >= 0) {
            existingReplies[idx] = created;
          } else {
            existingReplies.insert(0, created);
          }
          _replies[parentId] = existingReplies;
          _svc.setRepliesCache(parentId, existingReplies);
          final parentIndex = _comments.indexWhere((c) {
            return _commentIdOf(c) == parentId;
          });
          if (!bumpedParentReplyCount && parentIndex >= 0) {
            final updatedParent =
                Map<String, dynamic>.from(_comments[parentIndex]);
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
      if (!isReply) {
        _dispatchCommentsDelta(1);
      }
    }
    if (mounted) setState(() => _posting = false);
  }

  Widget _avatar(String? url, String fallback,
      {double size = 18, bool ring = false}) {
    final child = CircleAvatar(
      radius: size,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: (url == null || url.isEmpty)
          ? Text(fallback,
              style: TextStyle(
                  fontSize: size - 4,
                  color: Theme.of(context).colorScheme.primary))
          : null,
    );
    if (!ring || url == null || url.isEmpty) return child;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            LinearGradient(colors: [Colors.pinkAccent, Colors.orangeAccent]),
      ),
      child: child,
    );
  }

  Future<void> _toggleLike(Map<String, dynamic> c, int index) async {
    final id = _commentIdOf(c);
    if (id.isEmpty) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like comments')),
      );
      return;
    }
    final liked = _liked.contains(id);
    final prevLiked = liked;
    final prevCount = ((c['likes_count'] as int?) ?? 0);
    final targetLiked = !liked;
    setState(() {
      if (liked) {
        _liked.remove(id);
      } else {
        _liked.add(id);
      }
      final cc = Map<String, dynamic>.from(_comments[index]);
      final count = (cc['likes_count'] as int?) ?? 0;
      cc['likes_count'] =
          targetLiked ? count + 1 : (count - 1).clamp(0, 1 << 31);
      _comments[index] = cc;
    });
    try {
      final res = liked
          ? await _svc.unlikeComment(
              id,
              isTweet: _isTweet,
              throwOnError: true,
            )
          : await _svc.likeComment(
              id,
              isTweet: _isTweet,
              throwOnError: true,
            );
      if (res == null || !mounted) return;
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
          _svc.syncCommentLikeState(
            postId: widget.postId,
            commentId: id,
            liked: likedNow,
            isTweet: _isTweet,
          );
        }
        _comments[index] = cc;
      });
    } on ApiException catch (e) {
      if (_isDuplicateCommentLikeError(e)) {
        if (!mounted) return;
        setState(() {
          final cc = Map<String, dynamic>.from(_comments[index]);
          cc['likes_count'] = prevCount;
          _comments[index] = cc;
          if (targetLiked) {
            _liked.add(id);
          } else {
            _liked.remove(id);
          }
          _svc.syncCommentLikeState(
            postId: widget.postId,
            commentId: id,
            liked: targetLiked,
            isTweet: _isTweet,
          );
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        final cc = Map<String, dynamic>.from(_comments[index]);
        cc['likes_count'] = prevCount;
        _comments[index] = cc;
        if (prevLiked) {
          _liked.add(id);
        } else {
          _liked.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like comment: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final cc = Map<String, dynamic>.from(_comments[index]);
        cc['likes_count'] = prevCount;
        _comments[index] = cc;
        if (prevLiked) {
          _liked.add(id);
        } else {
          _liked.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to like comment')),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> c, int index) async {
    final id = _commentIdOf(c);
    if (id.isEmpty) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to delete comments')),
      );
      return;
    }
    if (id.startsWith('temp-')) {
      setState(() => _comments.removeAt(index));
      return;
    }
    final ok = await _svc.deleteComment(id, isTweet: _isTweet);
    if (ok) {
      setState(() {
        _comments.removeAt(index);
      });
      _dispatchCommentsDelta(-1);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to delete comment')),
    );
  }

  Future<void> _deleteReply(String parentId, int replyIndex) async {
    final list = _replies[parentId];
    if (list == null || replyIndex < 0 || replyIndex >= list.length) return;
    final reply = Map<String, dynamic>.from(list[replyIndex]);
    final id = _commentIdOf(reply);
    if (id.isEmpty) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to delete comments')),
      );
      return;
    }

    if (id.startsWith('temp-')) {
      setState(() {
        final next = List<Map<String, dynamic>>.from(list);
        next.removeAt(replyIndex);
        _replies[parentId] = next;
        _svc.setRepliesCache(parentId, next);
      });
      return;
    }

    final ok = await _svc.deleteComment(id, isTweet: _isTweet);
    if (!mounted) return;
    if (ok) {
      setState(() {
        final next = List<Map<String, dynamic>>.from(list);
        next.removeAt(replyIndex);
        _replies[parentId] = next;
        _svc.setRepliesCache(parentId, next);

        final parentIndex = _comments.indexWhere((c) {
          return _commentIdOf(c) == parentId;
        });
        if (parentIndex >= 0) {
          final updatedParent =
              Map<String, dynamic>.from(_comments[parentIndex]);
          final rc = (updatedParent['replies_count'] as int?) ??
              (updatedParent['replyCount'] as int?) ??
              (updatedParent['repliesCount'] as int?) ??
              0;
          updatedParent['replies_count'] = (rc - 1).clamp(0, 1 << 31);
          _comments[parentIndex] = updatedParent;
        }
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to delete reply')),
    );
  }

  Future<void> _loadRepliesFor(String commentId) async {
    if (_loadingReplies.contains(commentId)) return;
    setState(() => _loadingReplies.add(commentId));
    final list = await _svc.getReplies(
      commentId,
      page: 1,
      limit: 10,
      isTweet: _isTweet,
    );
    if (!mounted) return;
    setState(() {
      _replies[commentId] = list;
      _svc.setRepliesCache(commentId, list);
      _loadingReplies.remove(commentId);
    });
  }

  int _replyCount(Map<String, dynamic> c, String cid) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final direct = toInt(c['reply_count']);
    if (direct > 0) return direct;
    final countA = toInt(c['replies_count']);
    if (countA > 0) return countA;
    final countB = toInt(c['replyCount']);
    if (countB > 0) return countB;
    final countC = toInt(c['repliesCount']);
    if (countC > 0) return countC;
    final loaded = _replies[cid];
    if (loaded != null && loaded.isNotEmpty) return loaded.length;
    if (c['replies'] is List) return (c['replies'] as List).length;
    return 0;
  }

  Future<void> _toggleReplies(Map<String, dynamic> c) async {
    final cid = _commentIdOf(c);
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

  void _showDeleteSheet({
    required VoidCallback onDelete,
  }) {
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
                onDelete();
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

  void _onLongPressComment(Map<String, dynamic> c, bool isMine, int index) {
    if (!isMine) return;
    _showDeleteSheet(onDelete: () => _delete(c, index));
  }

  void _onLongPressReply(String parentId, int replyIndex, bool isMine) {
    if (!isMine) return;
    _showDeleteSheet(onDelete: () => _deleteReply(parentId, replyIndex));
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

  Future<void> _toggleReplyLike(String parentId, int replyIndex) async {
    final list = _replies[parentId];
    if (list == null || replyIndex < 0 || replyIndex >= list.length) return;
    final reply = Map<String, dynamic>.from(list[replyIndex]);
    final id = _commentIdOf(reply);
    if (id.isEmpty) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like comments')),
      );
      return;
    }

    final liked = _liked.contains(id);
    final prevLiked = liked;
    final prevCount = (reply['likes_count'] as int?) ?? 0;
    setState(() {
      if (liked) {
        _liked.remove(id);
      } else {
        _liked.add(id);
      }
      final count = (reply['likes_count'] as int?) ?? 0;
      reply['likes_count'] = liked ? (count - 1).clamp(0, 1 << 31) : count + 1;
      list[replyIndex] = reply;
    });

    try {
      final res = liked
          ? await _svc.unlikeComment(
              id,
              isTweet: _isTweet,
              throwOnError: true,
            )
          : await _svc.likeComment(
              id,
              isTweet: _isTweet,
              throwOnError: true,
            );
      if (res == null || !mounted) return;
      setState(() {
        final latest = Map<String, dynamic>.from(list[replyIndex]);
        if (res.containsKey('likes_count')) {
          latest['likes_count'] =
              res['likes_count'] as int? ?? latest['likes_count'];
        }
        final likedNow = res['liked'] as bool?;
        if (likedNow != null) {
          if (likedNow) {
            _liked.add(id);
          } else {
            _liked.remove(id);
          }
          _svc.syncCommentLikeState(
            postId: widget.postId,
            commentId: id,
            liked: likedNow,
            isTweet: _isTweet,
          );
        }
        list[replyIndex] = latest;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        final latest = Map<String, dynamic>.from(list[replyIndex]);
        latest['likes_count'] = prevCount;
        list[replyIndex] = latest;
        if (prevLiked) {
          _liked.add(id);
        } else {
          _liked.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like reply: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final latest = Map<String, dynamic>.from(list[replyIndex]);
        latest['likes_count'] = prevCount;
        list[replyIndex] = latest;
        if (prevLiked) {
          _liked.add(id);
        } else {
          _liked.remove(id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to like reply')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final showAdInfo = !_loadingPost && _isAdPost(_post);
    const introCount = 0;
    final adCount = showAdInfo ? 1 : 0;
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
                        'Comments (${_comments.length})',
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
                          color: DesignTokens.instaPink))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: introCount +
                          adCount +
                          (_comments.isEmpty ? 1 : _comments.length),
                      itemBuilder: (context, i) {
                        if (showAdInfo && i == introCount) {
                          return _buildAdInfo(_post!);
                        }
                        if (_comments.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No comments yet.\nBe the first to comment.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          );
                        }
                        final idx = i - introCount - adCount;
                        final c = _comments[idx];
                        final un = _commentUsername(c);
                        final av = _commentAvatar(c);
                        final content = c['content'] as String? ??
                            c['text'] as String? ??
                            '';
                        final created = c['created_at'] as String? ??
                            c['createdAt'] as String? ??
                            '';
                        final cid = _commentIdOf(c);
                        final isVerified = _commentVerified(c);
                        final u = _commentUserMap(c);
                        final userIdValue = _userIdFromMap(u);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: FutureBuilder<String?>(
                            future: CurrentUser.id,
                            builder: (ctx, snap) {
                              final myId = snap.data;
                              final isMine = _isMineUser(u, myId);
                              final liked = _liked.contains(cid);
                              final likesCount =
                                  (c['likes_count'] as int?) ?? 0;
                              final isPending = c['pending'] == true;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onLongPress: () =>
                                    _onLongPressComment(c, isMine, idx),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: userIdValue.isNotEmpty
                                              ? () => Navigator.of(context)
                                                  .pushNamed(
                                                      '/profile/$userIdValue')
                                              : null,
                                          child: _avatar(
                                              av,
                                              un.isNotEmpty
                                                  ? un[0].toUpperCase()
                                                  : 'U',
                                              size: 16,
                                              ring:
                                                  av != null && av.isNotEmpty),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              RichText(
                                                text: TextSpan(
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    color: isPending
                                                        ? theme.colorScheme
                                                            .onSurfaceVariant
                                                        : theme.colorScheme
                                                            .onSurface,
                                                    height: 1.15,
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text: un,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700),
                                                    ),
                                                    if (isVerified)
                                                      const WidgetSpan(
                                                        alignment:
                                                            PlaceholderAlignment
                                                                .middle,
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                  left: 4,
                                                                  right: 4),
                                                          child: Icon(
                                                              Icons
                                                                  .check_circle,
                                                              size: 13,
                                                              color: Colors
                                                                  .blueAccent),
                                                        ),
                                                      )
                                                    else
                                                      const TextSpan(
                                                          text: '  '),
                                                    TextSpan(
                                                        text: content.isEmpty
                                                            ? '-'
                                                            : content),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Text(_relative(created),
                                                      style: theme
                                                          .textTheme.bodySmall),
                                                  if (likesCount > 0) ...[
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      '$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
                                                      style: theme
                                                          .textTheme.bodySmall,
                                                    ),
                                                  ],
                                                  const SizedBox(width: 10),
                                                  TextButton(
                                                    onPressed: cid.isEmpty
                                                        ? null
                                                        : () => _startReply(
                                                            cid, un),
                                                    style: TextButton.styleFrom(
                                                      padding: EdgeInsets.zero,
                                                      minimumSize: Size.zero,
                                                      tapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                    ),
                                                    child: Text(
                                                      'Reply',
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 40,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  liked
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  size: 20,
                                                  color: liked
                                                      ? Colors.red
                                                      : theme.iconTheme.color,
                                                ),
                                                onPressed: () =>
                                                    _toggleLike(c, idx),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                              if (likesCount > 0)
                                                Text(
                                                  '$likesCount',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Builder(builder: (context) {
                                      final hasReplies = ((c['replies']
                                                      as List?)
                                                  ?.isNotEmpty ??
                                              false) ||
                                          (((c['replies_count'] as int?) ??
                                                  (c['replyCount'] as int?) ??
                                                  (c['repliesCount'] as int?) ??
                                                  0) >
                                              0) ||
                                          ((_replies[cid]?.isNotEmpty ??
                                              false));
                                      final isExpanded =
                                          _expandedComments.contains(cid);
                                      final totalReplies = _replyCount(c, cid);
                                      if (!hasReplies) {
                                        return const SizedBox.shrink();
                                      }
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton(
                                          onPressed: () => _toggleReplies(c),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 24,
                                                height: 1,
                                                color: theme.colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.7),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                isExpanded
                                                    ? 'Hide replies'
                                                    : 'View replies (${totalReplies > 0 ? totalReplies : (_replies[cid]?.length ?? 0)})',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                    if (_loadingReplies.contains(cid))
                                      const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 8),
                                        child: SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: DesignTokens.instaPink),
                                        ),
                                      ),
                                    if (_expandedComments.contains(cid) &&
                                        _replies[cid] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 42, right: 8, bottom: 8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            for (var replyIndex = 0;
                                                replyIndex <
                                                    _replies[cid]!.length;
                                                replyIndex++)
                                              () {
                                                final r =
                                                    _replies[cid]![replyIndex];
                                                final rn = _commentUsername(r);
                                                final rav = _commentAvatar(r);
                                                final rcontent =
                                                    r['content'] as String? ??
                                                        r['text'] as String? ??
                                                        '';
                                                final rcreated = r['created_at']
                                                        as String? ??
                                                    r['createdAt'] as String? ??
                                                    '';
                                                final rIsVerified =
                                                    _commentVerified(r);
                                                final rUser =
                                                    _commentUserMap(r);
                                                final rIsMine =
                                                    _isMineUser(rUser, myId);
                                                final rid = _commentIdOf(r);
                                                final rLiked =
                                                    _liked.contains(rid);
                                                final rLikesCount =
                                                    (r['likes_count']
                                                            as int?) ??
                                                        0;
                                                final rUserIdValue =
                                                    _userIdFromMap(rUser);
                                                return GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onLongPress: () =>
                                                      _onLongPressReply(cid,
                                                          replyIndex, rIsMine),
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 6),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        GestureDetector(
                                                          onTap: rUserIdValue
                                                                  .isNotEmpty
                                                              ? () => Navigator
                                                                      .of(
                                                                          context)
                                                                  .pushNamed(
                                                                      '/profile/$rUserIdValue')
                                                              : null,
                                                          child: _avatar(
                                                              rav,
                                                              rn.isNotEmpty
                                                                  ? rn[0]
                                                                      .toUpperCase()
                                                                  : 'U',
                                                              size: 14,
                                                              ring: rav !=
                                                                      null &&
                                                                  rav.isNotEmpty),
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              GestureDetector(
                                                                onTap: rUserIdValue
                                                                        .isNotEmpty
                                                                    ? () => Navigator.of(
                                                                            context)
                                                                        .pushNamed(
                                                                            '/profile/$rUserIdValue')
                                                                    : null,
                                                                child: RichText(
                                                                  text:
                                                                      TextSpan(
                                                                    style: theme
                                                                        .textTheme
                                                                        .bodyMedium
                                                                        ?.copyWith(
                                                                      height:
                                                                          1.15,
                                                                      color: theme
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                    children: [
                                                                      TextSpan(
                                                                          text:
                                                                              rn,
                                                                          style:
                                                                              const TextStyle(fontWeight: FontWeight.w700)),
                                                                      if (rIsVerified)
                                                                        const WidgetSpan(
                                                                          alignment:
                                                                              PlaceholderAlignment.middle,
                                                                          child:
                                                                              Padding(
                                                                            padding:
                                                                                EdgeInsets.only(left: 4, right: 4),
                                                                            child: Icon(Icons.check_circle,
                                                                                size: 12,
                                                                                color: Colors.blueAccent),
                                                                          ),
                                                                        )
                                                                      else
                                                                        const TextSpan(
                                                                            text:
                                                                                '  '),
                                                                      TextSpan(
                                                                          text: rcontent.isEmpty
                                                                              ? '-'
                                                                              : rcontent),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  height: 2),
                                                              Row(
                                                                children: [
                                                                  Text(
                                                                      _relative(
                                                                          rcreated),
                                                                      style: theme
                                                                          .textTheme
                                                                          .bodySmall),
                                                                  if (rLikesCount >
                                                                      0) ...[
                                                                    const SizedBox(
                                                                        width:
                                                                            10),
                                                                    Text(
                                                                      '$rLikesCount ${rLikesCount == 1 ? 'like' : 'likes'}',
                                                                      style: theme
                                                                          .textTheme
                                                                          .bodySmall,
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 34,
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              IconButton(
                                                                onPressed: () =>
                                                                    _toggleReplyLike(
                                                                        cid,
                                                                        replyIndex),
                                                                icon: Icon(
                                                                  rLiked
                                                                      ? Icons
                                                                          .favorite
                                                                      : LucideIcons
                                                                          .heart,
                                                                  size: 14,
                                                                  color: rLiked
                                                                      ? Colors
                                                                          .red
                                                                      : theme
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                ),
                                                                padding:
                                                                    EdgeInsets
                                                                        .zero,
                                                                constraints:
                                                                    const BoxConstraints(),
                                                              ),
                                                              if (rLikesCount >
                                                                  0)
                                                                Text(
                                                                  '$rLikesCount',
                                                                  style: theme
                                                                      .textTheme
                                                                      .bodySmall,
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }(),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            if (_replyParentId != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to ${_replyingTo ?? ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                        onPressed: _cancelReply, child: const Text('Cancel')),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: (_me?['avatar_url'] is String &&
                            (_me?['avatar_url'] as String).isNotEmpty)
                        ? NetworkImage(_me?['avatar_url'] as String)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: _controller,
                        focusNode: _inputFocus,
                        decoration: InputDecoration(
                          hintText: _replyingTo != null
                              ? 'Reply to @$_replyingTo...'
                              : 'Add a comment...',
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          hintStyle: TextStyle(color: theme.hintColor),
                        ),
                        onSubmitted: (_) => _postComment(),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return TextButton(
                        onPressed: _posting || !hasText ? null : _postComment,
                        child: Text(
                          'Post',
                          style: TextStyle(
                            color: hasText
                                ? const Color(0xFF3B82F6)
                                : theme.colorScheme.onSurfaceVariant,
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
