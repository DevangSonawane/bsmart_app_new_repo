import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../api/api_exceptions.dart';
import '../models/feed_post_model.dart';
import '../repositories/feed_repository.dart';
import '../services/content_sync_service.dart';
import '../utils/app_error_handler.dart';
import '../utils/current_user.dart';
import 'feed_paging_state.dart';

class FeedController extends ChangeNotifier {
  final FeedRepository _repository;
  final int pageSize;
  final Connectivity _connectivity;

  FeedPagingState _state = const FeedPagingState();
  FeedPagingState get state => _state;

  int _page = 1;
  String? _cursor;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<ContentSyncEvent>? _contentSyncSub;
  bool _disposed = false;

  FeedController({
    required FeedRepository repository,
    this.pageSize = 10,
    Connectivity? connectivity,
  })  : _repository = repository,
        _connectivity = connectivity ?? Connectivity() {
    _listenConnectivity();
    _contentSyncSub = ContentSyncService().changes.listen(_applyContentSync);
  }

  void _applyContentSync(ContentSyncEvent event) {
    if (_disposed || _state.posts.isEmpty) return;

    if (event.followed != null && event.userId.isNotEmpty) {
      var changed = false;
      final next = _state.posts.map((post) {
        if (post.userId != event.userId) return post;
        if (post.isFollowed == event.followed) return post;
        changed = true;
        return post.copyWith(isFollowed: event.followed);
      }).toList(growable: false);
      if (!changed) return;
      _setState(_state.copyWith(posts: next));
      return;
    }

    if (event.contentId.isEmpty) return;
    final idx = _state.posts.indexWhere((p) => p.id == event.contentId);
    if (idx == -1) return;
    final prev = _state.posts[idx];

    switch (event.kind) {
      case ContentSyncKind.like:
        if (event.likesCount == null &&
            event.likesDelta == null &&
            prev.isLiked == (event.liked ?? prev.isLiked)) {
          return;
        }
        final likesCount = event.likesCount ??
            ((event.likesDelta ?? 0) != 0
                ? (prev.likes + (event.likesDelta ?? 0))
                    .clamp(0, 1 << 31)
                    .toInt()
                : null);
        final updated = prev.copyWith(
          isLiked: event.liked ?? prev.isLiked,
          likes: likesCount ??
              ((event.liked ?? prev.isLiked)
                  ? prev.likes + 1
                  : (prev.likes > 0 ? prev.likes - 1 : 0)),
        );
        if (updated == prev) return;
        final next = List<FeedPost>.from(_state.posts);
        next[idx] = updated;
        _setState(_state.copyWith(posts: next));
        break;
      case ContentSyncKind.save:
        if (prev.isSaved == (event.saved ?? prev.isSaved)) return;
        final next = List<FeedPost>.from(_state.posts);
        next[idx] = prev.copyWith(isSaved: event.saved ?? prev.isSaved);
        _setState(_state.copyWith(posts: next));
        break;
      case ContentSyncKind.commentCount:
        if (event.commentsCount == null && event.commentsDelta == null) return;
        final commentsCount = event.commentsCount ??
            ((event.commentsDelta ?? 0) != 0
                ? (prev.comments + (event.commentsDelta ?? 0))
                    .clamp(0, 1 << 31)
                    .toInt()
                : null);
        final next = List<FeedPost>.from(_state.posts);
        next[idx] = prev.copyWith(comments: commentsCount ?? prev.comments);
        _setState(_state.copyWith(posts: next));
        break;
      case ContentSyncKind.follow:
        break;
    }
  }

  void _listenConnectivity() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final offline = results.contains(ConnectivityResult.none);
      if (_state.isOffline != offline) {
        _setState(_state.copyWith(isOffline: offline));
      }
    });
  }

  Future<void> loadInitial() async {
    if (_state.isInitialLoading) return;
    _page = 1;
    _cursor = null;
    _setState(
      _state.copyWith(
        isInitialLoading: true,
        isLoadingMore: false,
        hasMore: true,
        clearError: true,
        isOffline: false,
      ),
    );
    await _fetchPage(reset: true, loadStories: true);
  }

  Future<void> refresh() async {
    if (_state.isInitialLoading) return;
    _page = 1;
    _cursor = null;
    final shouldShowFullLoader = _state.posts.isEmpty;
    _setState(
      _state.copyWith(
        isInitialLoading: shouldShowFullLoader,
        isLoadingMore: false,
        hasMore: true,
        clearError: true,
        isOffline: false,
      ),
    );
    await _fetchPage(reset: true, loadStories: true);
  }

  Future<void> loadMore() async {
    if (_state.isInitialLoading || _state.isLoadingMore || !_state.hasMore) {
      return;
    }
    final online = await _isOnline();
    if (!online) {
      _setState(_state.copyWith(isOffline: true));
      return;
    }
    _setState(_state.copyWith(isLoadingMore: true, clearError: true));
    await _fetchPage(reset: false, loadStories: false);
  }

  void updatePost(FeedPost updated) {
    final idx = _state.posts.indexWhere((p) => p.id == updated.id);
    if (idx == -1) return;
    final next = List<FeedPost>.from(_state.posts);
    next[idx] = updated;
    _setState(_state.copyWith(posts: next));
  }

  void replacePostById(String postId, FeedPost Function(FeedPost) update) {
    final idx = _state.posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return;
    final next = List<FeedPost>.from(_state.posts);
    next[idx] = update(next[idx]);
    _setState(_state.copyWith(posts: next));
  }

  Future<void> _fetchPage({
    required bool reset,
    required bool loadStories,
  }) async {
    try {
      final uid = await CurrentUser.id;
      final page = _page;

      final pageData = await _repository.fetchFeedPage(
        page: page,
        limit: pageSize,
        currentUserId: uid,
        cursor: _cursor,
      );

      final incoming = _dedupePosts(pageData.posts);
      final merged = reset ? incoming : _mergePosts(_state.posts, incoming);
      final stories = loadStories
          ? await _repository.fetchStories()
          : _state.stories;

      _page = page + 1;
      _cursor = pageData.nextCursor ?? _cursor;

      _setState(
        _state.copyWith(
          posts: merged,
          stories: stories,
          isInitialLoading: false,
          isLoadingMore: false,
          hasMore: pageData.hasMore,
          clearError: true,
          isOffline: false,
        ),
      );
    } catch (e) {
      final offline = e is NetworkException;
      _setState(
        _state.copyWith(
          isInitialLoading: false,
          isLoadingMore: false,
          isOffline: offline,
          errorMessage: offline
              ? null
              : AppErrorHandler.userMessage(
                  e,
                  fallback: 'Failed to load feed. Please try again.',
                ),
          clearError: offline,
        ),
      );
    }
  }

  List<FeedPost> _dedupePosts(List<FeedPost> incoming) {
    final seen = <String>{};
    final result = <FeedPost>[];
    for (final post in incoming) {
      if (post.id.isEmpty) continue;
      if (seen.add(post.id)) result.add(post);
    }
    return result;
  }

  List<FeedPost> _mergePosts(List<FeedPost> existing, List<FeedPost> incoming) {
    if (incoming.isEmpty) return existing;
    final seen = existing.map((e) => e.id).toSet();
    final merged = List<FeedPost>.from(existing);
    for (final post in incoming) {
      if (post.id.isEmpty) continue;
      if (seen.add(post.id)) merged.add(post);
    }
    return merged;
  }

  Future<bool> _isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  void _setState(FeedPagingState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectivitySub?.cancel();
    _contentSyncSub?.cancel();
    super.dispose();
  }
}
