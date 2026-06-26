import 'dart:async';

enum ContentSyncKind {
  like,
  save,
  follow,
  commentCount,
}

class ContentSyncEvent {
  final ContentSyncKind kind;
  final String contentId;
  final String userId;
  final bool? liked;
  final int? likesCount;
  final int? likesDelta;
  final bool? saved;
  final bool? followed;
  final String? followState;
  final int? commentsCount;
  final int? commentsDelta;
  final bool? isTweet;

  const ContentSyncEvent({
    required this.kind,
    this.contentId = '',
    this.userId = '',
    this.liked,
    this.likesCount,
    this.likesDelta,
    this.saved,
    this.followed,
    this.followState,
    this.commentsCount,
    this.commentsDelta,
    this.isTweet,
  });
}

class ContentSyncService {
  static final ContentSyncService _instance = ContentSyncService._internal();
  factory ContentSyncService() => _instance;
  ContentSyncService._internal();

  final StreamController<ContentSyncEvent> _controller =
      StreamController<ContentSyncEvent>.broadcast();

  Stream<ContentSyncEvent> get changes => _controller.stream;

  void publish(ContentSyncEvent event) {
    if (event.contentId.trim().isEmpty && event.userId.trim().isEmpty) return;
    _controller.add(event);
  }

  void publishLike({
    required String contentId,
    required bool liked,
    int? likesCount,
    int? likesDelta,
    bool? isTweet,
  }) {
    publish(ContentSyncEvent(
      kind: ContentSyncKind.like,
      contentId: contentId.trim(),
      liked: liked,
      likesCount: likesCount,
      likesDelta: likesDelta,
      isTweet: isTweet,
    ));
  }

  void publishSave({
    required String contentId,
    required bool saved,
    bool? isTweet,
  }) {
    publish(ContentSyncEvent(
      kind: ContentSyncKind.save,
      contentId: contentId.trim(),
      saved: saved,
      isTweet: isTweet,
    ));
  }

  void publishFollow({
    required String userId,
    required bool followed,
    String? followState,
  }) {
    publish(ContentSyncEvent(
      kind: ContentSyncKind.follow,
      userId: userId.trim(),
      followed: followed,
      followState: followState,
    ));
  }

  void publishCommentCount({
    required String contentId,
    int? commentsCount,
    int? commentsDelta,
    bool? isTweet,
  }) {
    publish(ContentSyncEvent(
      kind: ContentSyncKind.commentCount,
      contentId: contentId.trim(),
      commentsCount: commentsCount,
      commentsDelta: commentsDelta,
      isTweet: isTweet,
    ));
  }
}
