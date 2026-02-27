import '../models/reel_model.dart';
import '../services/dummy_data_service.dart';

class ReelCommentsService {
  static final ReelCommentsService _instance = ReelCommentsService._internal();
  factory ReelCommentsService() => _instance;

  final Map<String, List<ReelComment>> _commentsByReel = {};

  ReelCommentsService._internal() {
    _generateDummyComments();
  }

  List<ReelComment> getComments(String reelId) {
    return _commentsByReel[reelId] ?? [];
  }

  int getCommentCount(String reelId) {
    final comments = getComments(reelId);
    int count = comments.length;
    for (final comment in comments) {
      count += comment.replies.length;
    }
    return count;
  }

  void addComment(String reelId, String text, {String? parentCommentId}) {
    final now = DateTime.now();
    final currentUser = DummyDataService().getCurrentUser();
    
    final comment = ReelComment(
      id: 'comment-${now.millisecondsSinceEpoch}',
      userId: currentUser.id,
      userName: currentUser.name,
      userAvatarUrl: currentUser.avatarUrl,
      text: text,
      createdAt: now,
      parentCommentId: parentCommentId,
      isCreator: false,
    );

    if (parentCommentId != null) {
      // Add as reply
      final comments = _commentsByReel[reelId] ?? [];
      final parentIndex = comments.indexWhere((c) => c.id == parentCommentId);
      if (parentIndex != -1) {
        final parent = comments[parentIndex];
        comments[parentIndex] = parent.copyWith(
          replies: [...parent.replies, comment],
        );
        _commentsByReel[reelId] = comments;
      }
    } else {
      // Add as top-level comment
      _commentsByReel[reelId] = [...(_commentsByReel[reelId] ?? []), comment];
    }
  }

  void toggleLikeComment(String reelId, String commentId) {
    final comments = _commentsByReel[reelId];
    if (comments == null) return;

    for (int i = 0; i < comments.length; i++) {
      if (comments[i].id == commentId) {
        final comment = comments[i];
        comments[i] = comment.copyWith(
          isLiked: !comment.isLiked,
          likes: comment.isLiked ? comment.likes - 1 : comment.likes + 1,
        );
        break;
      }
      
      // Check replies
      for (int j = 0; j < comments[i].replies.length; j++) {
        if (comments[i].replies[j].id == commentId) {
          final reply = comments[i].replies[j];
          final updatedReplies = List<ReelComment>.from(comments[i].replies);
          updatedReplies[j] = reply.copyWith(
            isLiked: !reply.isLiked,
            likes: reply.isLiked ? reply.likes - 1 : reply.likes + 1,
          );
          comments[i] = comments[i].copyWith(replies: updatedReplies);
          break;
        }
      }
    }
    _commentsByReel[reelId] = comments;
  }

  void _generateDummyComments() {
    final now = DateTime.now();
    final users = DummyDataService().getOnlineUsers();

    _commentsByReel['reel-1'] = [
      ReelComment(
        id: 'comment-1',
        userId: users[1].id,
        userName: users[1].name,
        userAvatarUrl: users[1].avatarUrl,
        text: 'Amazing content! 🔥',
        likes: 45,
        createdAt: now.subtract(const Duration(hours: 1)),
        isCreator: false,
        replies: [
          ReelComment(
            id: 'reply-1',
            userId: users[0].id,
            userName: users[0].name,
            userAvatarUrl: users[0].avatarUrl,
            text: 'Thank you!',
            likes: 12,
            createdAt: now.subtract(const Duration(minutes: 50)),
            parentCommentId: 'comment-1',
            isCreator: true,
          ),
        ],
      ),
      ReelComment(
        id: 'comment-2',
        userId: users[2].id,
        userName: users[2].name,
        userAvatarUrl: users[2].avatarUrl,
        text: 'Love this! ❤️',
        likes: 23,
        createdAt: now.subtract(const Duration(minutes: 30)),
        isCreator: false,
      ),
    ];

    _commentsByReel['reel-2'] = [
      ReelComment(
        id: 'comment-3',
        userId: users[0].id,
        userName: users[0].name,
        userAvatarUrl: users[0].avatarUrl,
        text: 'Beautiful!',
        likes: 15,
        createdAt: now.subtract(const Duration(hours: 2)),
        isCreator: false,
      ),
    ];
  }
}
