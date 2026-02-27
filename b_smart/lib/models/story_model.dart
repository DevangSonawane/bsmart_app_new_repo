class Story {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String mediaUrl;
  final StoryMediaType mediaType;
  final DateTime createdAt;
  final int views;
  final bool isViewed;
  final String? productUrl;
  final String? externalLink;
  final bool hasPollQuiz;
  final DateTime? expiresAt;
  final bool isDeleted;
  final List<Map<String, dynamic>>? texts;
  final List<Map<String, dynamic>>? mentions;
  final Map<String, dynamic>? transform;
  final Map<String, dynamic>? filter;
  final int? durationSec;

  Story({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.mediaUrl,
    required this.mediaType,
    required this.createdAt,
    this.views = 0,
    this.isViewed = false,
    this.productUrl,
    this.externalLink,
    this.hasPollQuiz = false,
    this.expiresAt,
    this.isDeleted = false,
    this.texts,
    this.mentions,
    this.transform,
    this.filter,
    this.durationSec,
  });
}

enum StoryMediaType {
  image,
  video,
}

class StoryGroup {
  final String userId;
  final String userName;
  final String? userAvatar;
  final bool isOnline;
  final bool isCloseFriend;
  final bool isSubscribedCreator;
  final String? storyId;
  final List<Story> stories;

  StoryGroup({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.isOnline = false,
    this.isCloseFriend = false,
    this.isSubscribedCreator = false,
    this.storyId,
    required this.stories,
  });
}
