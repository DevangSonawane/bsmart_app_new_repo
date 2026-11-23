import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../api/api_exceptions.dart';
import '../api/posts_api.dart';
import '../models/feed_post_model.dart';
import '../state/app_state.dart';
import '../state/feed_actions.dart';

/// Emitted whenever a post is pinned/unpinned so open screens (profile grid,
/// feed, post detail) can update without refetching.
class PostPinEvent {
  final String postId;

  /// `null` means the post is now unpinned.
  final DateTime? pinnedAt;

  const PostPinEvent(this.postId, this.pinnedAt);

  bool get isPinned => pinnedAt != null;
}

/// Pin / unpin a user's own posts to the top of their profile.
///
/// See `docs/pinned-posts.md`. Rules (enforced server-side):
///  - up to [FeedPost.maxPinnedPosts] pinned posts per user (`400` beyond),
///  - only the author can pin (`403` otherwise),
///  - plain posts only — not reels, ads, tweets or promotes.
class PostPinService {
  static final PostPinService _instance = PostPinService._internal();
  factory PostPinService() => _instance;
  PostPinService._internal();

  final PostsApi _api = PostsApi();
  final StreamController<PostPinEvent> _controller =
      StreamController<PostPinEvent>.broadcast();

  Stream<PostPinEvent> get changes => _controller.stream;

  /// Whether the pin action applies to this post at all (ignores ownership).
  static bool canPin(FeedPost post) =>
      !post.isAd &&
      !post.isTweet &&
      !post.isPromote &&
      post.mediaType != PostMediaType.reel &&
      post.id.trim().isNotEmpty;

  /// Calls the API and returns the server's `pinned_at` (null when unpinned).
  /// Throws [ApiException] on failure (e.g. the 3-pin limit).
  Future<DateTime?> setPinned(String postId, bool pinned) async {
    final res =
        pinned ? await _api.pinPost(postId) : await _api.unpinPost(postId);
    final body = _unwrapPost(res);
    DateTime? pinnedAt = FeedPost.parsePinnedAt(body);
    final isPinned = body.isEmpty ? pinned : FeedPost.parseIsPinned(body);
    if (!isPinned) {
      pinnedAt = null;
    } else {
      pinnedAt ??= DateTime.now();
    }
    _controller.add(PostPinEvent(postId, pinnedAt));
    return pinnedAt;
  }

  /// UI helper: toggles the pin for [post], updates the Redux feed and shows
  /// a snackbar. Returns the new `pinnedAt` or `null` (also null on failure;
  /// check the returned record's `ok`).
  Future<({bool ok, DateTime? pinnedAt})> toggle(
    BuildContext context,
    FeedPost post,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final store = StoreProvider.of<AppState>(context, listen: false);
    final wantPinned = !post.isPinned;
    try {
      final pinnedAt = await setPinned(post.id, wantPinned);
      store.dispatch(UpdatePostPinned(post.id, pinnedAt));
      messenger?.showSnackBar(
        SnackBar(
          content: Text(pinnedAt != null
              ? 'Pinned to your profile'
              : 'Unpinned from your profile'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return (ok: true, pinnedAt: pinnedAt);
    } on ApiException catch (e) {
      final msg = e.message.trim().isNotEmpty
          ? e.message
          : (wantPinned ? 'Could not pin post' : 'Could not unpin post');
      messenger?.showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      messenger?.showSnackBar(
        SnackBar(
          content:
              Text(wantPinned ? 'Could not pin post' : 'Could not unpin post'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return (ok: false, pinnedAt: post.pinnedAt);
  }

  static Map<String, dynamic> _unwrapPost(Map<String, dynamic> res) {
    for (final key in const ['post', 'data']) {
      final inner = res[key];
      if (inner is Map) return Map<String, dynamic>.from(inner);
    }
    return res;
  }
}
