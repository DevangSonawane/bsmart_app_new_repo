import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import '../services/supabase_service.dart';
import '../services/comment_sync_service.dart';
import '../theme/design_tokens.dart';
import '../utils/current_user.dart';
import '../utils/id_extractor.dart';
import '../api/api_exceptions.dart';
import '../config/api_config.dart';
import '../api/api_client.dart';
import '../utils/timezone_service.dart';
import '../utils/app_error_handler.dart';
import '../utils/location_utils.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../state/app_state.dart';
import '../state/feed_actions.dart';
import '../widgets/share_content_modal.dart';

/// Modal matching React PostDetailModal: image left, details + comments right.
class PostDetailModal extends StatefulWidget {
  final String postId;
  final Map<String, dynamic>? initialPost;
  final VoidCallback? onClose;
  final bool isTweet;

  const PostDetailModal({
    super.key,
    required this.postId,
    this.initialPost,
    this.onClose,
    this.isTweet = false,
  });

  @override
  State<PostDetailModal> createState() => _PostDetailModalState();
}

class _PostDetailModalState extends State<PostDetailModal> {
  final SupabaseService _svc = SupabaseService();
  final CommentSyncService _commentSync = CommentSyncService();
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
  final Map<String, double> _resolvedImageAspectRatios = <String, double>{};
  final Set<String> _resolvingImageAspectRatioUrls = <String>{};
  late bool _isTweet;
  String? _currentUserId;
  StreamSubscription<CommentChangeEvent>? _commentSyncSub;

  String? _extractId(dynamic value) {
    return extractEntityId(value);
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
    if (likes is! List || currentUserId == null || currentUserId.isEmpty) {
      return null;
    }
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

  String _commentId(Map<String, dynamic> comment) {
    final raw = comment['id'] ??
        comment['_id'] ??
        comment['comment_id'] ??
        comment['commentId'];
    return raw?.toString().trim() ?? '';
  }

  bool _isCommentLiked(Map<String, dynamic> comment) {
    final uid = _currentUserId?.trim();
    final likes = comment['likes'];
    if (uid != null && uid.isNotEmpty && likes is List) {
      for (final entry in likes) {
        if (entry is String && entry == uid) return true;
        if (entry is Map) {
          final likedUserId = _extractId(entry['user_id']) ??
              _extractId(entry['id']) ??
              _extractId(entry['_id']) ??
              (entry['user'] is Map ? _extractId(entry['user']) : null);
          if (likedUserId != null && likedUserId == uid) return true;
        }
      }
    }
    return _asBool(comment['is_liked_by_me']) ||
        _asBool(comment['liked_by_me']) ||
        _asBool(comment['liked']) ||
        _asBool(comment['is_liked']);
  }

  int _commentLikesCount(Map<String, dynamic> comment) {
    final value = comment['likes_count'] ??
        comment['likesCount'] ??
        comment['like_count'] ??
        comment['likeCount'] ??
        comment['likes'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is List) return value.length;
    return 0;
  }

  void _applyCommentLikeState(Map<String, dynamic> comment, bool liked) {
    comment['is_liked_by_me'] = liked;
    comment['liked_by_me'] = liked;
    comment['liked'] = liked;
    comment['is_liked'] = liked;
    final current = _commentLikesCount(comment);
    comment['likes_count'] =
        liked ? current + 1 : (current > 0 ? current - 1 : 0);
  }

  void _applyExternalCommentLikeState(String commentId, bool liked) {
    final id = commentId.trim();
    if (id.isEmpty) return;
    setState(() {
      for (var i = 0; i < _comments.length; i++) {
        final comment = _comments[i];
        if (_commentId(comment) != id) continue;
        final currentLiked = _isCommentLiked(comment);
        if (currentLiked == liked) continue;
        final currentCount = _commentLikesCount(comment);
        final updated = Map<String, dynamic>.from(comment);
        _applyCommentLikeState(updated, liked);
        updated['likes_count'] =
            liked ? currentCount + 1 : (currentCount > 0 ? currentCount - 1 : 0);
        _comments[i] = updated;
      }
    });
  }

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

  bool _isAdPost(Map<String, dynamic>? post) {
    if (post == null) return false;
    final itemType =
        (post['item_type'] ?? post['itemType'] ?? '').toString().toLowerCase();
    if (itemType == 'ad') return true;
    if (post['vendor_id'] != null || post['vendorId'] != null) return true;
    if (post['total_budget_coins'] != null ||
        post['totalBudgetCoins'] != null) {
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

  Widget _buildAdInfo() {
    final post = _post;
    if (!_isAdPost(post) || post == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final surface =
        isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.55);

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
  }

  @override
  void dispose() {
    _commentSyncSub?.cancel();
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
    bool eagerSaved = _isSaved;
    int eagerLikeCount = _likeCount;

    if (eagerPost == null && initial != null) {
      eagerPost = Map<String, dynamic>.from(initial);
      final normalizedUser = _extractUserMap(eagerPost['user']) ??
          _extractUserMap(eagerPost['users']) ??
          _extractUserMap(eagerPost['user_id']) ??
          <String, dynamic>{};
      final userId = _extractId(normalizedUser) ??
          _extractId(eagerPost['user_id']) ??
          _extractId(eagerPost['user']) ??
          _extractId(eagerPost['users']);
      if (userId != null && userId.isNotEmpty) {
        normalizedUser['id'] = userId;
        normalizedUser['_id'] = userId;
      }
      normalizedUser['username'] = (normalizedUser['username'] ??
              eagerPost['username'] ??
              eagerPost['user_name'] ??
              eagerPost['full_name'])
          ?.toString()
          .trim();
      normalizedUser['full_name'] = (normalizedUser['full_name'] ??
              eagerPost['full_name'] ??
              eagerPost['fullName'])
          ?.toString()
          .trim();
      normalizedUser['avatar_url'] = (normalizedUser['avatar_url'] ??
              eagerPost['avatar_url'] ??
              eagerPost['userAvatar'] ??
              eagerPost['avatar'])
          ?.toString()
          .trim();
      eagerUser = normalizedUser;
      eagerLiked = _extractLikedFlag(eagerPost) ?? eagerLiked;
      eagerSaved = _asBool(eagerPost['is_saved_by_me']) ||
          _asBool(eagerPost['saved_by_me']);
      eagerLikeCount = _extractLikesCount(eagerPost) ?? eagerLikeCount;
      final itemType = (eagerPost['item_type'] ?? eagerPost['itemType'] ?? '')
          .toString()
          .toLowerCase();
      if (itemType == 'tweet') _isTweet = true;
    }

    if (mounted) {
      setState(() {
        if (eagerPost != null) {
          _post = eagerPost;
          _postUser = eagerUser;
          _isLiked = eagerLiked;
          _isSaved = eagerSaved;
          _likeCount = eagerLikeCount;
          _loadingPost = false;
        } else {
          _loadingPost = true;
        }
        _loadingComments = true;
      });
    }

    final fetchedPost =
        await _svc.getPostById(widget.postId, isTweet: _isTweet);
    final post = fetchedPost ?? _post;
    if (post == null || !mounted) {
      if (mounted) setState(() => _loadingPost = false);
      return;
    }
    final itemType =
        (post['item_type'] ?? post['itemType'] ?? '').toString().toLowerCase();
    if (itemType == 'tweet') _isTweet = true;
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
    final comments = await _svc.getComments(widget.postId, isTweet: _isTweet);
    final currentUserId = await CurrentUser.id;
    final currentUserIdString = currentUserId?.toString();
    final isLiked =
        _extractLikedFlag(post, currentUserId: currentUserId) ?? false;
    final likeCount = _extractLikesCount(post) ?? 0;
    final isSaved = _isTweet
        ? false
        : (_asBool(post['is_saved_by_me']) || _asBool(post['saved_by_me']));
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
        _currentUserId = currentUserIdString;
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
    final liked =
        await _svc.setPostLike(widget.postId, like: desired, isTweet: _isTweet);
    if (!mounted) return;
    try {
      final p =
          await SupabaseService().getPostById(widget.postId, isTweet: _isTweet);
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
      await _svc.addComment(widget.postId, userId, content, isTweet: _isTweet);
      StoreProvider.of<AppState>(context, listen: false).dispatch(
        UpdatePostCommentsCount(widget.postId, _comments.length + 1),
      );
      _commentController.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  Future<void> _toggleCommentLike(
      Map<String, dynamic> comment, int index) async {
    final id = _commentId(comment);
    if (id.isEmpty) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to like comments')),
        );
      }
      return;
    }

    final liked = _isCommentLiked(comment);
    final targetLiked = !liked;
    final prevCount = _commentLikesCount(comment);
    final prevLiked = liked;

    setState(() {
      final updated = Map<String, dynamic>.from(comment);
      _applyCommentLikeState(updated, targetLiked);
      if (index >= 0 && index < _comments.length) {
        _comments[index] = updated;
      }
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
        final latest = Map<String, dynamic>.from(comment);
        final likedNow = res['liked'] as bool? ?? !liked;
        _applyCommentLikeState(latest, likedNow);
        if (res.containsKey('likes_count')) {
          latest['likes_count'] = _toInt(res['likes_count']);
        } else {
          latest['likes_count'] =
              likedNow ? prevCount + 1 : (prevCount > 0 ? prevCount - 1 : 0);
        }
        _svc.syncCommentLikeState(
          postId: widget.postId,
          commentId: id,
          liked: likedNow,
          isTweet: _isTweet,
        );
        if (index >= 0 && index < _comments.length) {
          _comments[index] = latest;
        }
      });
    } on ApiException catch (e) {
      if (_isDuplicateCommentLikeError(e)) {
        if (!mounted) return;
        setState(() {
          final reconciled = Map<String, dynamic>.from(comment);
          _applyCommentLikeState(reconciled, targetLiked);
          reconciled['likes_count'] = prevCount;
          _svc.syncCommentLikeState(
            postId: widget.postId,
            commentId: id,
            liked: targetLiked,
            isTweet: _isTweet,
          );
          if (index >= 0 && index < _comments.length) {
            _comments[index] = reconciled;
          }
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        final reverted = Map<String, dynamic>.from(comment);
        _applyCommentLikeState(reverted, prevLiked);
        reverted['likes_count'] = prevCount;
        if (index >= 0 && index < _comments.length) {
          _comments[index] = reverted;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to like comment: ${e.message}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final reverted = Map<String, dynamic>.from(comment);
        _applyCommentLikeState(reverted, prevLiked);
        reverted['likes_count'] = prevCount;
        if (index >= 0 && index < _comments.length) {
          _comments[index] = reverted;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to like comment')),
      );
    }
  }

  Future<void> _handleSave() async {
    if (_isTweet) return;
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

    final saved = await _svc.setPostSaved(widget.postId,
        save: desired, isTweet: _isTweet);
    if (!mounted) return;
    try {
      final p = await _svc.getPostById(widget.postId, isTweet: _isTweet);
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
    if (_isTweet) return;
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
    return TimezoneService.instance.formatPostTimestamp(dateString);
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

  bool _isControllerUsable(VideoPlayerController? controller) {
    if (controller == null) return false;
    try {
      controller.value;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _isControllerInitialized(VideoPlayerController? controller) {
    if (!_isControllerUsable(controller)) return false;
    try {
      return controller!.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  bool _isControllerPlaying(VideoPlayerController? controller) {
    if (!_isControllerUsable(controller)) return false;
    try {
      return controller!.value.isPlaying;
    } catch (_) {
      return false;
    }
  }

  double _controllerAspectRatio(VideoPlayerController? controller) {
    if (!_isControllerUsable(controller)) return 9 / 16;
    try {
      final ar = controller!.value.aspectRatio;
      return ar <= 0 ? 9 / 16 : ar;
    } catch (_) {
      return 9 / 16;
    }
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

  double? _parseAspectRatio(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      final v = raw.toDouble();
      return v > 0 ? v : null;
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s.contains(':') || s.contains('/')) {
      final parts = s.split(RegExp(r'[:/]'));
      if (parts.length >= 2) {
        final a = double.tryParse(parts[0].trim());
        final b = double.tryParse(parts[1].trim());
        if (a != null && b != null && a > 0 && b > 0) return a / b;
      }
      return null;
    }
    final v = double.tryParse(s);
    return (v != null && v > 0) ? v : null;
  }

  double? _aspectRatioFromItem(dynamic item) {
    if (item is! Map) return null;
    final map = item;
    final rawAr = map['aspect_ratio'] ??
        map['aspectRatio'] ??
        (map['crop'] is Map ? (map['crop'] as Map)['aspect_ratio'] : null) ??
        (map['crop'] is Map ? (map['crop'] as Map)['aspectRatio'] : null) ??
        (map['crop_settings'] is Map
            ? (map['crop_settings'] as Map)['aspect_ratio']
            : null) ??
        (map['crop_settings'] is Map
            ? (map['crop_settings'] as Map)['aspectRatio']
            : null);
    final parsed = _parseAspectRatio(rawAr);
    if (parsed != null) return parsed;

    final w = map['width'] ?? map['w'];
    final h = map['height'] ?? map['h'];
    if (w is num && h is num && w > 0 && h > 0) {
      return w.toDouble() / h.toDouble();
    }
    final ws = double.tryParse(w?.toString() ?? '');
    final hs = double.tryParse(h?.toString() ?? '');
    if (ws != null && hs != null && ws > 0 && hs > 0) return ws / hs;
    return null;
  }

  bool _isReelLike(dynamic item) {
    final postType = (_post?['type'] ?? _post?['media_type'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if (postType == 'reel' || postType.contains('reel')) return true;
    if (item is Map) {
      final t = (item['type'] as String?)?.toLowerCase().trim() ?? '';
      if (t == 'reel' || t.contains('reel')) return true;
    }
    return false;
  }

  double _currentMediaAspectRatio(dynamic currentItem) {
    if (_isVideoMedia(currentItem)) {
      final controller = _videoController;
      if (_videoReady &&
          _isControllerInitialized(controller) &&
          controller != null) {
        final ar = controller.value.aspectRatio;
        if (ar > 0) return ar;
      }
      final fromMeta = _aspectRatioFromItem(currentItem);
      if (fromMeta != null && fromMeta > 0) return fromMeta;
      return _isReelLike(currentItem) ? (9 / 16) : (16 / 9);
    }

    final url = _mediaUrl(currentItem);
    final resolved = _resolvedImageAspectRatios[url];
    if (resolved != null && resolved > 0) return resolved;
    return _aspectRatioFromItem(currentItem) ?? 4 / 5;
  }

  Future<void> _ensureCurrentImageAspectRatio() async {
    if (!mounted) return;
    final media = _mediaItems;
    if (media.isEmpty || _currentMediaIndex >= media.length) return;
    final item = media[_currentMediaIndex];
    if (_isVideoMedia(item)) return;
    final url = _mediaUrl(item);
    if (url.isEmpty) return;
    if (_resolvedImageAspectRatios.containsKey(url)) return;
    if (_resolvingImageAspectRatioUrls.contains(url)) return;
    _resolvingImageAspectRatioUrls.add(url);
    try {
      final token = await ApiClient().getToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      final provider = CachedNetworkImageProvider(
        url,
        headers: headers.isEmpty ? null : headers,
      );
      final stream = provider.resolve(const ImageConfiguration());
      ImageStreamListener? listener;
      final completer = Completer<ImageInfo>();
      listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info);
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      );
      stream.addListener(listener);
      try {
        final info = await completer.future.timeout(const Duration(seconds: 8));
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (w > 0 && h > 0 && mounted) {
          setState(() {
            _resolvedImageAspectRatios[url] = w / h;
          });
        }
      } finally {
        stream.removeListener(listener);
      }
    } catch (_) {
      // ignore
    } finally {
      _resolvingImageAspectRatioUrls.remove(url);
    }
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

    final currentItem = media[_currentMediaIndex.clamp(0, media.length - 1)];
    final clampedAspectRatio =
        _currentMediaAspectRatio(currentItem).clamp(0.35, 4.0);

    // Best-effort resolve of real image dimensions to avoid letterboxing.
    unawaited(_ensureCurrentImageAspectRatio());

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        double w = maxW;
        double h = w / clampedAspectRatio;
        if (h > maxH) {
          h = maxH;
          w = h * clampedAspectRatio;
        }

        return Center(
          child: SizedBox(
            width: w,
            height: h,
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
                    unawaited(_ensureCurrentImageAspectRatio());
                  },
                  itemBuilder: (_, index) {
                    final item = media[index];
                    final url = _mediaUrl(item);
                    final isVideo = _isVideoMedia(item);
                    if (url.isEmpty) {
                      return const Center(
                        child: Icon(LucideIcons.imageOff,
                            size: 64, color: Colors.white54),
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
                                  _isControllerInitialized(controller)
                              ? GestureDetector(
                                  onTap: () {
                                    if (!_isControllerUsable(controller)) {
                                      return;
                                    }
                                    if (_isControllerPlaying(controller)) {
                                      controller.pause();
                                    } else {
                                      controller.play();
                                    }
                                    if (mounted) setState(() {});
                                  },
                                  child: AspectRatio(
                                    aspectRatio:
                                        _controllerAspectRatio(controller),
                                    child: VideoPlayer(controller!),
                                  ),
                                )
                              : _videoLoading && isCurrent
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : Icon(LucideIcons.video,
                                      size: 48,
                                      color:
                                          Colors.white.withValues(alpha: 0.7)),
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
                              child: CircularProgressIndicator(
                                  color: Colors.white)),
                          errorWidget: (_, __, ___) => const Icon(
                              LucideIcons.imageOff,
                              size: 64,
                              color: Colors.white54),
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
                        icon: const Icon(LucideIcons.chevronLeft,
                            color: Colors.white),
                        onPressed: () {
                          final next = (_currentMediaIndex - 1)
                              .clamp(0, media.length - 1);
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
                        icon: const Icon(LucideIcons.chevronRight,
                            color: Colors.white),
                        onPressed: () {
                          final next = (_currentMediaIndex + 1)
                              .clamp(0, media.length - 1);
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetails() {
    final theme = Theme.of(context);
    final baseTextColor = theme.colorScheme.onSurface;
    final username = _postUser?['username'] as String? ?? 'User';
    final avatarUrl = _postUser?['avatar_url'] as String?;
    final caption = (_post?['caption'] ?? _post?['content']) as String? ?? '';
    final locationPlace = locationPlaceFromDynamic(
      _post?['location_place'] ??
          _post?['locationPlace'] ??
          _post?['location_data'] ??
          _post?['locationData'] ??
          _post?['location'],
    );
    final location = locationPlace?.displayText ??
        (_post?['location']?.toString().trim() ?? '');
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
                      final itemType =
                          (_post?['item_type'] ?? _post?['itemType'] ?? '')
                              .toString()
                              .toLowerCase();
                      final isAdItem = itemType == 'ad' ||
                          _post?['vendor_id'] != null ||
                          _post?['vendorId'] != null ||
                          _post?['is_ad'] == true ||
                          _post?['isAd'] == true;
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed(isAdItem
                          ? '/vendor/$userId/public'
                          : '/profile/$userId');
                    }
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
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
                            if (location.isNotEmpty)
                              InkWell(
                                onTap: () async {
                                  final place = locationPlace ??
                                      locationPlaceFromDynamic(location);
                                  if (place == null ||
                                      place.searchText.isEmpty) {
                                    return;
                                  }
                                  await openLocationInMaps(place);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.mapPin,
                                        size: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          location,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
                                                                      messenger
                                                                          .showSnackBar(
                                                                        SnackBar(
                                                                          content:
                                                                              Text(AppErrorHandler.userMessage(e)),
                                                                        ),
                                                                      );
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
                                style: TextStyle(
                                    color: baseTextColor, fontSize: 14),
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
                    ..._comments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final c = entry.value;
                      final u = c['user'] as Map<String, dynamic>?;
                      final un = u?['username'] as String? ?? 'user';
                      final uAvatar = u?['avatar_url'] as String?;
                      final liked = _isCommentLiked(c);
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
                                      style: TextStyle(
                                          color: baseTextColor, fontSize: 14),
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
                              icon: Icon(
                                liked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 14,
                                color: liked ? Colors.red : Colors.black87,
                              ),
                              onPressed: () => _toggleCommentLike(c, index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
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
              IconButton(
                icon: const Icon(LucideIcons.send),
                onPressed: () {
                  ShareContentModal.show(
                    context,
                    contentType: _isTweet ? 'tweet' : 'post',
                    contentId: widget.postId,
                  );
                },
              ),
              const Spacer(),
              if (!_isTweet)
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
    return TimezoneService.instance
        .formatDate(dateString, pattern: 'MMMM d, yyyy');
  }
}
