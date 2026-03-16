import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/supabase_service.dart';
import '../utils/current_user.dart';
import '../theme/design_tokens.dart';
import '../state/app_state.dart';
import '../state/feed_actions.dart';
import '../models/feed_post_model.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  const CommentsSheet({super.key, required this.postId});

  static Future<void> show(BuildContext context, String postId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: CommentsSheet(postId: postId),
      ),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final SupabaseService _svc = SupabaseService();
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

  @override
  void initState() {
    super.initState();
    _load();
    _initMe();
    _loadPost();
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
        final replies = await _svc.getReplies(id, page: 1, limit: 50);
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
      final post = await _svc.getPostById(widget.postId);
      if (!mounted) return;
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
    final itemType = (post['item_type'] ?? post['itemType'] ?? '').toString().toLowerCase();
    if (itemType == 'ad') return true;
    if (post['vendor_id'] != null || post['vendorId'] != null) return true;
    if (post['total_budget_coins'] != null || post['totalBudgetCoins'] != null) return true;
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

  Widget _buildPostIntro(Map<String, dynamic> post) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = post['user_id'] is Map
        ? Map<String, dynamic>.from(post['user_id'] as Map)
        : post['user'] is Map
            ? Map<String, dynamic>.from(post['user'] as Map)
            : post['users'] is Map
                ? Map<String, dynamic>.from(post['users'] as Map)
                : <String, dynamic>{};
    final vendor = post['vendor_id'] is Map
        ? Map<String, dynamic>.from(post['vendor_id'] as Map)
        : <String, dynamic>{};
    final username = (user['username'] ?? vendor['business_name'] ?? post['username'] ?? 'user').toString();
    final avatar = (user['avatar_url'] ?? vendor['logo_url'] ?? post['avatar_url'])?.toString();
    final created = (post['created_at'] ?? post['createdAt'] ?? '').toString();
    final caption = (post['caption'] ?? '').toString();

    final border = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final surface = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);

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
          Row(
            children: [
              _avatar(avatar, username.isNotEmpty ? username[0].toUpperCase() : 'U', size: 18, ring: avatar != null && avatar.isNotEmpty),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(_relative(created), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (caption.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(caption, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _buildAdInfo(Map<String, dynamic> post) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final category = (post['category'] ?? '').toString().trim();
    final budget = _toInt(post['total_budget_coins'] ?? post['totalBudgetCoins']);
    final views = _toInt(post['views_count'] ?? post['viewsCount']);
    final unique = _toInt(post['unique_views_count'] ?? post['uniqueViewsCount']);
    final completed = _toInt(post['completed_views_count'] ?? post['completedViewsCount']);
    final targetLocations = _asStringList(post['target_location'] ?? post['targetLocation']);
    final targetLanguages = _asStringList(post['target_language'] ?? post['target_languages'] ?? post['targetLanguage'] ?? post['targetLanguages']);

    final border = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08);
    final surface = isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final muted = isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.55);

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
      if (!isReply) {
        _dispatchCommentsDelta(1);
      }
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
      _dispatchCommentsDelta(-1);
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
    final cid = (c['_id'] as String?) ?? (c['id'] as String?) ?? '';
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

  Future<void> _toggleReplyLike(String parentId, int replyIndex) async {
    final list = _replies[parentId];
    if (list == null || replyIndex < 0 || replyIndex >= list.length) return;
    final reply = Map<String, dynamic>.from(list[replyIndex]);
    final id = (reply['_id'] as String?) ?? (reply['id'] as String?) ?? '';
    if (id.isEmpty) return;

    final liked = _liked.contains(id);
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

    final res = liked ? await _svc.unlikeComment(id) : await _svc.likeComment(id);
    if (res == null || !mounted) return;
    setState(() {
      final latest = Map<String, dynamic>.from(list[replyIndex]);
      if (res.containsKey('likes_count')) {
        latest['likes_count'] = res['likes_count'] as int? ?? latest['likes_count'];
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
      list[replyIndex] = latest;
    });
  }

  Future<void> _deleteReply(String parentId, int replyIndex) async {
    final list = _replies[parentId];
    if (list == null || replyIndex < 0 || replyIndex >= list.length) return;
    final reply = list[replyIndex];
    final id = (reply['_id'] as String?) ?? (reply['id'] as String?) ?? '';
    if (id.isEmpty) return;
    final ok = await _svc.deleteComment(id);
    if (!ok || !mounted) return;

    setState(() {
      list.removeAt(replyIndex);
      final parentIndex = _comments.indexWhere((c) {
        final cid = (c['_id'] as String?) ?? (c['id'] as String?) ?? '';
        return cid == parentId;
      });
      if (parentIndex >= 0) {
        final parent = Map<String, dynamic>.from(_comments[parentIndex]);
        final current = (parent['replies_count'] as int?) ??
            (parent['reply_count'] as int?) ??
            (parent['replyCount'] as int?) ??
            (parent['repliesCount'] as int?) ??
            0;
        final next = current > 0 ? current - 1 : 0;
        parent['replies_count'] = next;
        parent['reply_count'] = next;
        _comments[parentIndex] = parent;
      }
      _svc.setRepliesCache(parentId, list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final showAdInfo = !_loadingPost && _isAdPost(_post);
    final showPostIntro = !_loadingPost && _post != null;
    final introCount = showPostIntro ? 1 : 0;
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
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: introCount + adCount + (_comments.isEmpty ? 1 : _comments.length),
                      itemBuilder: (context, i) {
                        if (showPostIntro && i == 0) return _buildPostIntro(_post!);
                        if (showAdInfo && i == introCount) return _buildAdInfo(_post!);
                        if (_comments.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'No comments yet.\nBe the first to comment.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          );
                        }
                        final idx = i - introCount - adCount;
                        final c = _comments[idx];
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
                                    onLongPress: () => _onLongPressComment(c, isMine, idx),
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
                                                          const Padding(
                                                            padding: EdgeInsets.only(left: 4),
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
                                                Row(
                                                  children: [
                                                    Text(_relative(created), style: theme.textTheme.bodySmall),
                                                    if (likesCount > 0) ...[
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        '$likesCount ${likesCount == 1 ? 'like' : 'likes'}',
                                                        style: theme.textTheme.bodySmall,
                                                      ),
                                                    ],
                                                    const SizedBox(width: 10),
                                                    TextButton(
                                                      onPressed: () => _startReply(cid, un),
                                                      style: TextButton.styleFrom(
                                                        padding: EdgeInsets.zero,
                                                        minimumSize: Size.zero,
                                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      ),
                                                      child: Text(
                                                        'Reply',
                                                        style: theme.textTheme.bodySmall?.copyWith(
                                                          fontWeight: FontWeight.w600,
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
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                IconButton(
                                                  icon: Icon(
                                                    liked ? Icons.favorite : LucideIcons.heart,
                                                    size: 20,
                                                    color: liked ? Colors.red : theme.iconTheme.color,
                                                  ),
                                                  onPressed: () => _toggleLike(c, idx),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                ),
                                                if (likesCount > 0)
                                                  Text(
                                                    '$likesCount',
                                                    style: theme.textTheme.bodySmall,
                                                  ),
                                                if (isMine)
                                                  IconButton(
                                                    icon: Icon(
                                                      LucideIcons.trash2,
                                                      size: 14,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                    onPressed: () => _delete(c, idx),
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(),
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
                                        final isExpanded = _expandedComments.contains(cid);
                                        final totalReplies = _replyCount(c, cid);
                                        if (!hasReplies) return const SizedBox.shrink();
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
                                                  color: theme.colorScheme.onSurfaceVariant
                                                      .withValues(alpha: 0.7),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isExpanded
                                                      ? 'Hide replies'
                                                      : 'View replies (${totalReplies > 0 ? totalReplies : (_replies[cid]?.length ?? 0)})',
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
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
                                      if (_expandedComments.contains(cid) && _replies[cid] != null)
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
                                                  final rLiked = _liked.contains(
                                                    (r['_id'] as String?) ?? (r['id'] as String?) ?? '',
                                                  );
                                                  final rLikesCount = (r['likes_count'] as int?) ?? 0;
                                                  final rUserIdValue =
                                                      (ru?['id'] ?? ru?['_id'] ?? ru?['user_id'])?.toString();
                                                  final myId = snap.data;
                                                  final rIsMine = myId != null &&
                                                      ((ru?['id'] as String?) == myId ||
                                                          (ru?['_id'] as String?) == myId ||
                                                          (ru?['user_id'] as String?) == myId);
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
                                                        SizedBox(
                                                          width: 34,
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              IconButton(
                                                                onPressed: () => _toggleReplyLike(cid, _replies[cid]!.indexOf(r)),
                                                                icon: Icon(
                                                                  rLiked ? Icons.favorite : LucideIcons.heart,
                                                                  size: 14,
                                                                  color: rLiked ? Colors.red : theme.colorScheme.onSurfaceVariant,
                                                                ),
                                                                padding: EdgeInsets.zero,
                                                                constraints: const BoxConstraints(),
                                                              ),
                                                              if (rLikesCount > 0)
                                                                Text(
                                                                  '$rLikesCount',
                                                                  style: theme.textTheme.bodySmall,
                                                                ),
                                                              if (rIsMine)
                                                                IconButton(
                                                                  onPressed: () => _deleteReply(
                                                                    cid,
                                                                    _replies[cid]!.indexOf(r),
                                                                  ),
                                                                  icon: Icon(
                                                                    LucideIcons.trash2,
                                                                    size: 12,
                                                                    color: theme.colorScheme.onSurfaceVariant,
                                                                  ),
                                                                  padding: EdgeInsets.zero,
                                                                  constraints: const BoxConstraints(),
                                                                ),
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
                    ),
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
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                            color: hasText ? const Color(0xFF3B82F6) : theme.colorScheme.onSurfaceVariant,
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
