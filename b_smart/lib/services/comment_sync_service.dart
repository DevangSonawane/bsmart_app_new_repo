import 'dart:async';

class CommentChangeEvent {
  final String postId;
  final bool isTweet;
  final int delta;

  const CommentChangeEvent({
    required this.postId,
    required this.isTweet,
    this.delta = 0,
  });
}

class CommentSyncService {
  static final CommentSyncService _instance = CommentSyncService._internal();
  factory CommentSyncService() => _instance;
  CommentSyncService._internal();

  final StreamController<CommentChangeEvent> _controller =
      StreamController<CommentChangeEvent>.broadcast();

  Stream<CommentChangeEvent> get changes => _controller.stream;

  void notifyChanged({
    required String postId,
    required bool isTweet,
    int delta = 0,
  }) {
    final id = postId.trim();
    if (id.isEmpty) return;
    _controller
        .add(CommentChangeEvent(postId: id, isTweet: isTweet, delta: delta));
  }
}
