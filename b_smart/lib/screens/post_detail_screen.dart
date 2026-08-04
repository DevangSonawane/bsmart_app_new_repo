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
import '../models/feed_post_model.dart';
import '../widgets/share_content_modal.dart';
import '../widgets/content_report_sheet.dart';
import '../utils/value_parsers.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final FeedPost? initialPost;
  final bool isTweet;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
    this.isTweet = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final SupabaseService _svc = SupabaseService();
  final CommentSyncService _commentSync = CommentSyncService();
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
  bool _isSaved = false;
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
  final Map<String, double> _resolvedImageAspectRatios = <String, double>{};
  final Set<String> _resolvingImageAspectRatioUrls = <String>{};
  bool _isTweet = false;
  StreamSubscription<CommentChangeEvent>? _commentSyncSub;
  String _likesSummaryText = '';
  String? _likesSummaryUserId;
  final Set<String> _likedCommentIds = <String>{};

  bool _isReelPost() {
    final post = _post;
    if (post == null) return false;
    final rawType = (post['type'] ??
            post['media_type'] ??
            post['mediaType'] ??
            post['item_type'] ??
            post['itemType'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();
    if (rawType == 'reel' || rawType.contains('reel')) return true;

    final media = post['media'];
    if (media is List) {
      for (final m in media) {
        if (m is Map) {
          final t = (m['type'] as String?)?.toLowerCase().trim();
          if (t == 'reel') return true;
        }
      }
    }
    return false;
  }

  Widget _buildVideoPlayerCover(VideoPlayerController controller) {
    final size = controller.value.size;
    if (size.width <= 0 || size.height <= 0) {
      return AspectRatio(
        aspectRatio: _controllerAspectRatio(controller),
        child: VideoPlayer(controller),
      );
    }
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }

  void _dispatchCommentsCount(int commentsCount) {
    if (!mounted) return;
    StoreProvider.of<AppState>(context, listen: false).dispatch(
        UpdatePostCommentsCount(
            widget.postId, commentsCount < 0 ? 0 : commentsCount));
  }

  String? _extractId(dynamic value) {
    return extractEntityId(value);
  }

  String? _extractPostUserId(Map<String, dynamic> post) {
    final candidates = <dynamic>[
      post['user_id'],
      post['user'],
      post['users'],
      post['userId'],
      post['userID'],
      post['author'],
      post['createdBy'],
      post['created_by'],
      post['vendor_id'],
      post['vendorId'],
      post['sender'],
    ];
    for (final c in candidates) {
      final id = _extractId(c);
      if (id != null && id.trim().isNotEmpty) return id.trim();
    }
    return null;
  }

  Map<String, dynamic>? _extractUserMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic>? _extractPostUserMap(Map<String, dynamic> post) {
    final candidates = <dynamic>[
      post['user'],
      post['users'],
      post['author'],
      post['user_id'],
      post['userId'],
      post['createdBy'],
      post['created_by'],
      post['sender'],
    ];
    for (final c in candidates) {
      final map = _extractUserMap(c);
      if (map == null || map.isEmpty) continue;
      final normalized = Map<String, dynamic>.from(map);
      final id = _extractId(normalized['id']) ??
          _extractId(normalized['_id']) ??
          _extractId(normalized);
      if (id != null && id.isNotEmpty) {
        normalized['id'] = id;
        normalized['_id'] = id;
      }
      normalized['username'] = (normalized['username'] ??
              normalized['handle'] ??
              normalized['user_name'] ??
              normalized['full_name'] ??
              normalized['name'] ??
              post['username'] ??
              post['user_name'])
          ?.toString()
          .trim();
      normalized['avatar_url'] = (normalized['avatar_url'] ??
              normalized['avatar'] ??
              normalized['profile_picture'] ??
              normalized['profilePicture'] ??
              normalized['profile_pic'] ??
              normalized['photo'] ??
              post['avatar_url'])
          ?.toString()
          .trim();
      return normalized;
    }
    return null;
  }

  String _extractTweetText(Map<String, dynamic> post) {
    final v = (post['text'] ??
            post['content'] ??
            post['tweet'] ??
            post['message'] ??
            post['body'])
        ?.toString()
        .trim();
    return v ?? '';
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

  int _commentLikesCount(Map<String, dynamic> comment) {
    final value = comment['likes_count'] ??
        comment['likesCount'] ??
        comment['like_count'] ??
        comment['likeCount'] ??
        comment['likes'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _isCommentLiked(Map<String, dynamic> comment, {String? currentUserId}) {
    final cid = _commentId(comment);
    if (cid.isNotEmpty && _likedCommentIds.contains(cid)) return true;
    final uid = (currentUserId ?? _currentUserId)?.trim();
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

  void _syncLikedCommentIdsFromState([String? currentUserId]) {
    _likedCommentIds.clear();
    void collect(Map<String, dynamic> comment) {
      final cid = _commentId(comment);
      if (cid.isNotEmpty &&
          _isCommentLiked(comment, currentUserId: currentUserId)) {
        _likedCommentIds.add(cid);
      }
    }

    for (final comment in _comments) {
      collect(comment);
    }
    for (final replies in _replies.values) {
      for (final reply in replies) {
        collect(reply);
      }
    }
  }

  void _applyLikeState(Map<String, dynamic> comment, bool liked) {
    comment['is_liked_by_me'] = liked;
    comment['liked_by_me'] = liked;
    comment['liked'] = liked;
    comment['is_liked'] = liked;
    final current = _commentLikesCount(comment);
    comment['likes_count'] =
        liked ? current + 1 : (current - 1 < 0 ? 0 : current - 1);
  }

  void _applyExternalCommentLikeState(String commentId, bool liked) {
    final id = commentId.trim();
    if (id.isEmpty) return;
    var changed = false;

    void updateComment(Map<String, dynamic> comment) {
      if (_commentId(comment) != id) return;
      final currentLiked = _likedCommentIds.contains(id);
      if (currentLiked == liked) return;
      final currentCount = _commentLikesCount(comment);
      _applyLikeState(comment, liked);
      comment['likes_count'] =
          liked ? currentCount + 1 : (currentCount > 0 ? currentCount - 1 : 0);
      changed = true;
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
        _likedCommentIds.add(id);
      } else {
        _likedCommentIds.remove(id);
      }
    });

    if (changed) {
      _svc.setCommentLikeOverride(id, liked);
    }
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

  @override
  void initState() {
    super.initState();
    _isTweet = widget.isTweet || (widget.initialPost?.isTweet ?? false);
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
        'item_type': initial.isTweet ? 'tweet' : 'post',
      };
      eagerUser = {
        'id': initial.userId,
        'username': initial.userName,
        'full_name': initial.fullName,
        'avatar_url': initial.userAvatar,
      };
      eagerLiked = initial.isLiked;
      eagerSaved = initial.isSaved;
      eagerFollowed = initial.isFollowed;
      _isTweet = _isTweet || initial.isTweet;
    }

    meId ??= (await CurrentUser.id)?.toString();

    if (mounted) {
      setState(() {
        if (eagerPost != null) {
          _post = eagerPost;
          _postUser = eagerUser;
          _isLiked = eagerLiked;
          _isSaved = eagerSaved;
          _isAuthorFollowed = eagerFollowed;
          _currentUserId = meId;
          _loadingPost = false;
        } else {
          _loadingPost = true;
        }
        _loadingComments = true;
      });
    }

    final post = await _svc.getPostById(widget.postId, isTweet: _isTweet);
    if (post == null || !mounted) {
      if (mounted && _post == null) {
        setState(() => _loadingPost = false);
      }
      return;
    }
    final itemType = (post['item_type'] ??
            post['itemType'] ??
            post['type'] ??
            post['content_type'] ??
            post['contentType'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();
    _isTweet = itemType == 'tweet' || itemType.contains('tweet') || _isTweet;

    if (_isTweet) {
      final tweetText = _extractTweetText(post);
      final existingCaption = (post['caption'] ?? '').toString().trim();
      if (existingCaption.isEmpty && tweetText.isNotEmpty) {
        post['caption'] = tweetText;
        post['text'] = tweetText;
      }
    }
    final userId = _extractPostUserId(post);
    Map<String, dynamic>? user = _extractPostUserMap(post);
    if (userId != null) {
      final fetched = await _svc.getUserById(userId);
      if (fetched != null) user = fetched;
    }
    final comments = await _svc.getComments(widget.postId, isTweet: _isTweet);
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
    bool isLiked = _asBool(post['is_liked_by_me']) ||
        _asBool(post['liked_by_me']) ||
        _asBool(post['is_liked']) ||
        _asBool(post['liked']);
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
    final isSaved = _isTweet
        ? false
        : (_asBool(post['is_saved_by_me']) || _asBool(post['saved_by_me']));
    bool isFollowed = _asBool(post['is_followed_by_me']) ||
        _asBool(user?['is_followed_by_me']);
    String likesSummaryText = '';
    String? likesSummaryUserId;
    try {
      final likedUsers = await _svc.getPostLikes(widget.postId);
      likesSummaryText = _buildLikesSummaryFromUsers(likedUsers);
      likesSummaryUserId = _firstLikeUserId(likedUsers);
      if (likesSummaryText.isEmpty) {
        final rawLikes = post['likes'];
        if (rawLikes is List) {
          final fallbackUsers = rawLikes
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          likesSummaryText = _buildLikesSummaryFromUsers(fallbackUsers);
          likesSummaryUserId ??= _firstLikeUserId(fallbackUsers);
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _post = post;
        _postUser = user;
        _comments = topLevelComments;
        _replies
          ..clear()
          ..addAll(seededReplies);
        _isLiked = isLiked;
        _isSaved = isSaved;
        _loadingPost = false;
        _loadingComments = false;
        _currentUserId = meId2;
        _isAuthorFollowed = isFollowed;
        _likesSummaryText = likesSummaryText;
        _likesSummaryUserId = likesSummaryUserId;
      });
      _syncLikedCommentIdsFromState(meId2);
      _syncCurrentMediaPlayback();
      _prefetchRepliesForTopLevelComments(topLevelComments);
      final serverCount = tryParseInt(
            post['comments_count'] ??
                post['commentsCount'] ??
                post['commentCount'] ??
                post['comment_count'] ??
                post['comments'],
          ) ??
          topLevelComments.length;
      _dispatchCommentsCount(serverCount);
    }
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

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    final userId = await CurrentUser.id;
    if (content.isEmpty || userId == null) return;
    final parentId = _replyParentId;
    setState(() => _postingComment = true);
    try {
      final isTopLevel = parentId == null || parentId.isEmpty;
      if (isTopLevel) {
        _dispatchCommentsCount(_comments.length + 1);
      }
      await _svc.addComment(
        widget.postId,
        userId,
        content,
        parentId: parentId,
        isTweet: _isTweet,
      );
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

  Future<void> _handleSave() async {
    if (_isTweet) return;
    if (_post == null) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to save moments')),
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
    final list =
        await _svc.getReplies(commentId, page: 1, limit: 50, isTweet: _isTweet);
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

      final list =
          await _svc.getReplies(cid, page: 1, limit: 50, isTweet: _isTweet);
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

  Future<void> _toggleCommentLike(Map<String, dynamic> comment, int index,
      {String? parentId, bool isReply = false, int? replyIndex}) async {
    final id = _commentId(comment);
    if (id.isEmpty) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like comments')),
      );
      return;
    }

    final liked = _isCommentLiked(comment);
    final prevLiked = liked;
    final prevCount = _commentLikesCount(comment);
    final targetLiked = !liked;

    setState(() {
      if (liked) {
        _likedCommentIds.remove(id);
      } else {
        _likedCommentIds.add(id);
      }
      final updated = Map<String, dynamic>.from(comment);
      _applyLikeState(updated, targetLiked);
      if (isReply && parentId != null && replyIndex != null) {
        final list = _replies[parentId];
        if (list != null &&
            replyIndex >= 0 &&
            replyIndex < list.length &&
            _commentId(list[replyIndex]) == id) {
          list[replyIndex] = updated;
        }
      } else if (!isReply && index >= 0 && index < _comments.length) {
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
        final likedNow = res['liked'] as bool? ?? targetLiked;
        latest['is_liked_by_me'] = likedNow;
        latest['liked_by_me'] = likedNow;
        latest['liked'] = likedNow;
        latest['is_liked'] = likedNow;
        if (res.containsKey('likes_count')) {
          latest['likes_count'] = tryParseInt(res['likes_count']) ??
              latest['likes_count'] ??
              prevCount;
        } else {
          latest['likes_count'] = likedNow
              ? prevCount + 1
              : (prevCount - 1 < 0 ? 0 : prevCount - 1);
        }
        if (likedNow) {
          _likedCommentIds.add(id);
        } else {
          _likedCommentIds.remove(id);
        }
        _svc.syncCommentLikeState(
          postId: widget.postId,
          commentId: id,
          liked: likedNow,
          isTweet: _isTweet,
        );
        if (isReply && parentId != null && replyIndex != null) {
          final list = _replies[parentId];
          if (list != null &&
              replyIndex >= 0 &&
              replyIndex < list.length &&
              _commentId(list[replyIndex]) == id) {
            list[replyIndex] = latest;
          }
        } else if (!isReply && index >= 0 && index < _comments.length) {
          _comments[index] = latest;
        }
      });
    } on ApiException catch (e) {
      if (_isDuplicateCommentLikeError(e)) {
        if (!mounted) return;
        setState(() {
          final reconciled = Map<String, dynamic>.from(comment);
          reconciled['likes_count'] = prevCount;
          reconciled['is_liked_by_me'] = targetLiked;
          reconciled['liked_by_me'] = targetLiked;
          reconciled['liked'] = targetLiked;
          reconciled['is_liked'] = targetLiked;
          if (targetLiked) {
            _likedCommentIds.add(id);
          } else {
            _likedCommentIds.remove(id);
          }
          _svc.syncCommentLikeState(
            postId: widget.postId,
            commentId: id,
            liked: targetLiked,
            isTweet: _isTweet,
          );
          if (isReply && parentId != null && replyIndex != null) {
            final list = _replies[parentId];
            if (list != null &&
                replyIndex >= 0 &&
                replyIndex < list.length &&
                _commentId(list[replyIndex]) == id) {
              list[replyIndex] = reconciled;
            }
          } else if (!isReply && index >= 0 && index < _comments.length) {
            _comments[index] = reconciled;
          }
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        final reverted = Map<String, dynamic>.from(comment);
        reverted['likes_count'] = prevCount;
        reverted['is_liked_by_me'] = prevLiked;
        reverted['liked_by_me'] = prevLiked;
        reverted['liked'] = prevLiked;
        reverted['is_liked'] = prevLiked;
        if (prevLiked) {
          _likedCommentIds.add(id);
        } else {
          _likedCommentIds.remove(id);
        }
        if (isReply && parentId != null && replyIndex != null) {
          final list = _replies[parentId];
          if (list != null &&
              replyIndex >= 0 &&
              replyIndex < list.length &&
              _commentId(list[replyIndex]) == id) {
            list[replyIndex] = reverted;
          }
        } else if (!isReply && index >= 0 && index < _comments.length) {
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
        reverted['likes_count'] = prevCount;
        reverted['is_liked_by_me'] = prevLiked;
        reverted['liked_by_me'] = prevLiked;
        reverted['liked'] = prevLiked;
        reverted['is_liked'] = prevLiked;
        if (prevLiked) {
          _likedCommentIds.add(id);
        } else {
          _likedCommentIds.remove(id);
        }
        if (isReply && parentId != null && replyIndex != null) {
          final list = _replies[parentId];
          if (list != null &&
              replyIndex >= 0 &&
              replyIndex < list.length &&
              _commentId(list[replyIndex]) == id) {
            list[replyIndex] = reverted;
          }
        } else if (!isReply && index >= 0 && index < _comments.length) {
          _comments[index] = reverted;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to like comment')),
      );
    }
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
    return TimezoneService.instance.formatPostTimestamp(dateString);
  }

  static String _formatFullDate(String dateString) {
    return TimezoneService.instance.formatDate(
      dateString,
      pattern: 'MMMM d, yyyy',
    );
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

  double _currentMediaAspectRatio(dynamic currentItem) {
    final isVideo = _isVideoMedia(currentItem);
    if (isVideo) {
      final controller = _videoController;
      if (_videoReady &&
          _isControllerInitialized(controller) &&
          controller != null) {
        final ar = controller.value.aspectRatio;
        if (ar > 0) return ar;
      }

      final fromMeta = _aspectRatioFromItem(currentItem);
      if (fromMeta != null && fromMeta > 0) return fromMeta;

      // Reasonable fallbacks while the controller is still initializing.
      return _isReelPost() ? (9 / 16) : (16 / 9);
    }

    final url = _mediaUrl(currentItem);
    final resolved = _resolvedImageAspectRatios[url];
    if (resolved != null && resolved > 0) return resolved;
    return _aspectRatioFromItem(currentItem) ?? 4 / 5;
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
    final aspectRatio =
        currentItem == null ? 4 / 5 : _currentMediaAspectRatio(currentItem);
    final clampedAspectRatio = aspectRatio.clamp(0.35, 4.0);
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
      aspectRatio: clampedAspectRatio,
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
                final reelMode = _isReelPost();
                return Container(
                  color: reelMode ? Colors.black : mediaBg,
                  child: Center(
                    child: isCurrent &&
                            _videoReady &&
                            _isControllerInitialized(controller)
                        ? GestureDetector(
                            onTap: () {
                              if (!_isControllerUsable(controller)) return;
                              if (_isControllerPlaying(controller)) {
                                controller.pause();
                              } else {
                                controller.play();
                              }
                              if (mounted) setState(() {});
                            },
                            child: reelMode
                                ? _buildVideoPlayerCover(controller!)
                                : _buildVideoPlayerCover(controller!),
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
    final post = _post;
    if (post == null) return 0;
    final parsed = tryParseInt(
      post['likes_count'] ??
          post['likesCount'] ??
          post['likeCount'] ??
          post['likes_total'] ??
          post['likesTotal'],
    );
    if (parsed != null) return parsed;
    final likes = post['likes'] as List<dynamic>? ?? const <dynamic>[];
    return likes.length;
  }

  int get _commentCount {
    final post = _post;
    if (post == null) return _comments.length;
    final explicit = post['comments_count'] ??
        post['commentsCount'] ??
        post['commentCount'] ??
        post['comment_count'];
    if (explicit is int) return explicit;
    if (explicit is num) return explicit.toInt();
    final parsed = int.tryParse(explicit?.toString() ?? '');
    if (parsed != null) return parsed;
    if (post['comments'] is List) return (post['comments'] as List).length;
    return _comments.length;
  }

  int get _shareCount {
    final post = _post;
    if (post == null) return 0;
    final explicit =
        post['shares_count'] ?? post['sharesCount'] ?? post['shareCount'];
    if (explicit is int) return explicit;
    if (explicit is num) return explicit.toInt();
    return int.tryParse(explicit?.toString() ?? '') ?? 0;
  }

  String _displayNameOf(dynamic item) {
    if (item is Map) {
      final candidate = (item['username'] ??
              item['user_name'] ??
              item['full_name'] ??
              item['name'] ??
              item['handle'])
          ?.toString()
          .trim();
      if (candidate != null && candidate.isNotEmpty) return candidate;
      final user = item['user'];
      if (user is Map) return _displayNameOf(user);
    } else if (item is String) {
      final candidate = item.trim();
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }

  String _buildLikesSummaryFromUsers(List<Map<String, dynamic>> users) {
    if (users.isEmpty) return '';
    final names = <String>[];
    for (final user in users) {
      final name = _displayNameOf(user);
      if (name.isNotEmpty && !names.contains(name)) {
        names.add(name);
      }
      if (names.length >= 2) break;
    }
    if (names.isEmpty) return '';
    if (users.length <= 1) return 'Liked by ${names.first}';
    final others = users.length - 1;
    return 'Liked by ${names.first} and $others ${others == 1 ? 'other' : 'others'}';
  }

  String? _firstLikeUserId(List<Map<String, dynamic>> users) {
    for (final user in users) {
      final direct =
          (user['id'] ?? user['_id'] ?? user['user_id'] ?? user['userId'])
              ?.toString()
              .trim();
      if (direct != null && direct.isNotEmpty) return direct;
      final nested = user['user'];
      if (nested is Map) {
        final nestedId = (nested['id'] ??
                nested['_id'] ??
                nested['user_id'] ??
                nested['userId'])
            ?.toString()
            .trim();
        if (nestedId != null && nestedId.isNotEmpty) return nestedId;
      }
    }
    return null;
  }

  DateTime? _parsePostCreatedAt() {
    final post = _post;
    if (post == null) return null;
    final raw = post['created_at'] ??
        post['createdAt'] ??
        post['created'] ??
        post['created_time'] ??
        post['createdTime'];
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is num) {
      final ms = raw > 1000000000000 ? raw.toInt() : (raw * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    if (parsed != null) return parsed;
    final epoch = int.tryParse(s);
    if (epoch != null) {
      final ms = epoch > 1000000000000 ? epoch : epoch * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return null;
  }

  Widget _actionWithCount({
    required IconData icon,
    required int count,
    required Color primaryText,
    required Color secondaryText,
    double iconSize = 26,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: iconColor ?? primaryText),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
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
    final bottomSafeInset = MediaQuery.of(context).viewPadding.bottom;

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
          title: Text('Moment', style: TextStyle(color: primaryText)),
        ),
        body: const Center(child: Text('Moment not found')),
      );
    }

    final usernameCandidate = (_postUser?['username'] ??
            _postUser?['handle'] ??
            _postUser?['user_name'] ??
            _postUser?['full_name'] ??
            _postUser?['name'])
        ?.toString()
        .trim();
    final username = (usernameCandidate != null && usernameCandidate.isNotEmpty)
        ? usernameCandidate
        : 'User';
    final avatarUrl = (_postUser?['avatar_url'] ??
            _postUser?['avatar'] ??
            _postUser?['profile_picture'] ??
            _postUser?['profilePicture'] ??
            _postUser?['profile_pic'])
        ?.toString();
    final caption = _post?['caption'] as String? ?? '';
    final locationPlace = locationPlaceFromDynamic(
      _post?['location_place'] ?? _post?['locationPlace'] ?? _post?['location'],
    );
    final location = locationPlace?.displayText ??
        (_post?['location']?.toString().trim() ?? '');
    final createdAt = _parsePostCreatedAt();
    final createdAtLabel = createdAt == null
        ? ''
        : TimezoneService.instance
            .formatPostTimestamp(createdAt.toIso8601String())
            .toUpperCase();
    final ownerId = _extractId(_postUser?['id']) ??
        (_post == null ? null : _extractPostUserId(_post!));
    final isOwner = ownerId != null &&
        _currentUserId != null &&
        ownerId.toString() == _currentUserId.toString();
    final likesSummary = _likesSummaryText;

    // Kick off a best-effort aspect ratio resolve for images so the media section
    // can size itself to the real dimensions (prevents side bars for non-4:5 posts).
    unawaited(_ensureCurrentImageAspectRatio());

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
        title: Text('Moment',
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
                          child: CircleAvatar(
                            radius: 19,
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _onAuthorTap,
                                child: Text(
                                  username,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: primaryText),
                                ),
                              ),
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
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 1),
                                    child: Text(
                                      location,
                                      style: TextStyle(
                                        color: secondaryText,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
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
                                          ContentReportSheet.show(
                                            context,
                                            contentType:
                                                _isTweet ? 'tweet' : 'post',
                                            contentId: widget.postId,
                                          );
                                        },
                                      ),
                                      if (isOwner)
                                        ListTile(
                                          leading: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red),
                                          title: const Text('Delete Moment',
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
                                                                      'Deleting moment...',
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
                                                                      'Delete Moment?',
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
                                                                      'Are you sure you want to delete this moment? This action cannot be undone.',
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
                                                                                final ok = await _svc.deletePost(
                                                                                  widget.postId,
                                                                                  isTweet: _isTweet,
                                                                                );
                                                                                await Future.delayed(const Duration(milliseconds: 1500));
                                                                                if (ok) {
                                                                                  if (mounted) {
                                                                                    Navigator.pop(context);
                                                                                    messenger.showSnackBar(const SnackBar(content: Text('Moment deleted')));
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
                                                                                  messenger.showSnackBar(
                                                                                    SnackBar(
                                                                                      content: Text(AppErrorHandler.userMessage(e)),
                                                                                    ),
                                                                                  );
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
                        _actionWithCount(
                          icon: _isLiked ? Icons.favorite : LucideIcons.heart,
                          iconColor: _isLiked ? Colors.red : primaryText,
                          count: _likeCount,
                          iconSize: 20,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          onTap: () async {
                            final hasToken = await ApiClient().hasToken;
                            if (!hasToken) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Please log in to like moments'),
                                  ),
                                );
                              }
                              return;
                            }
                            if (_post == null) return;
                            final desired = !_isLiked;
                            setState(() => _isLiked = desired);
                            final liked = await _svc.setPostLike(
                              widget.postId,
                              like: desired,
                              isTweet: _isTweet,
                            );
                            if (!mounted) return;
                            setState(() => _isLiked = liked);
                            await _load();
                          },
                        ),
                        _actionWithCount(
                          icon: LucideIcons.messageCircle,
                          count: _commentCount,
                          iconSize: 20,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          onTap: () {},
                        ),
                        _actionWithCount(
                          icon: LucideIcons.send,
                          count: _shareCount,
                          iconSize: 20,
                          primaryText: primaryText,
                          secondaryText: secondaryText,
                          onTap: () {
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
                                _isSaved
                                    ? Icons.bookmark
                                    : LucideIcons.bookmark,
                                size: 22,
                              ),
                              color: primaryText,
                              onPressed: _handleSave),
                      ],
                    ),
                  ),
                  if (likesSummary.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: InkWell(
                        onTap: _likesSummaryUserId == null
                            ? null
                            : () {
                                Navigator.of(context).pushNamed(
                                  '/profile/${_likesSummaryUserId!}',
                                );
                              },
                        child: Text(
                          likesSummary,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 15, color: primaryText),
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
                      createdAtLabel.isEmpty ? 'JUST NOW' : createdAtLabel,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: secondaryText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Comments',
                            style: TextStyle(
                              fontSize: 18,
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
                                  fontSize: 14,
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
                            final likesCount = tryParseInt(
                                  c['likes_count'] ??
                                      c['likesCount'] ??
                                      c['likes'],
                                ) ??
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
                                                      fontSize: 13,
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
                                                  fontSize: 12,
                                                  color: primaryText),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                if (likesCount > 0)
                                                  Text(
                                                    '$likesCount likes',
                                                    style: TextStyle(
                                                        fontSize: 11,
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
                                                        fontSize: 11,
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
                                        icon: Icon(
                                          _isCommentLiked(c)
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 14,
                                          color: _isCommentLiked(c)
                                              ? Colors.red
                                              : secondaryText,
                                        ),
                                        onPressed: () => _toggleCommentLike(
                                          c,
                                          _comments.indexOf(c),
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
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
                                          final rLiked = _isCommentLiked(r);
                                          final rLikesCount = tryParseInt(
                                                r['likes_count'] ??
                                                    r['likesCount'] ??
                                                    r['likes'],
                                              ) ??
                                              ((r['likes'] is List)
                                                  ? (r['likes'] as List).length
                                                  : 0);
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
                                                const SizedBox(width: 8),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(
                                                        rLiked
                                                            ? Icons.favorite
                                                            : Icons
                                                                .favorite_border,
                                                        size: 13,
                                                        color: rLiked
                                                            ? Colors.red
                                                            : secondaryText,
                                                      ),
                                                      onPressed: () =>
                                                          _toggleCommentLike(
                                                        r,
                                                        0,
                                                        parentId: cid,
                                                        isReply: true,
                                                        replyIndex:
                                                            loadedReplies
                                                                .indexOf(r),
                                                      ),
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                    ),
                                                    if (rLikesCount > 0)
                                                      Text(
                                                        '$rLikesCount',
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color:
                                                                secondaryText),
                                                      ),
                                                  ],
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
                  SizedBox(height: 88 + bottomSafeInset),
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
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomSafeInset),
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
                      child: Text('Moment',
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
