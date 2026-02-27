import '../api/api.dart';
import '../config/api_config.dart';
import '../models/feed_post_model.dart';
import '../models/story_model.dart';
import '../models/user_model.dart';
import '../utils/url_helper.dart';
import 'supabase_service.dart';

class FeedService {
  static final FeedService _instance = FeedService._internal();
  factory FeedService() => _instance;

  FeedService._internal();

  final PostsApi _postsApi = PostsApi();
  final AuthApi _authApi = AuthApi();
  final StoriesApi _storiesApi = StoriesApi();

  // Get personalized feed with ranking
  List<FeedPost> getPersonalizedFeed({
    List<String>? followedUserIds,
    List<String>? userInterests,
    List<String>? searchHistory,
  }) {
    final allPosts = _generateFeedPosts();

    // Rank posts based on relevance
    final rankedPosts = allPosts.map((post) {
      double score = 0.0;

      // Follow relationship (high priority)
      if (followedUserIds != null && followedUserIds.contains(post.userId)) {
        score += 100.0;
      }

      // Tagged posts (high priority)
      if (post.isTagged) {
        score += 80.0;
      }

      // Engagement history (liked posts from followed users)
      if (post.isLiked &&
          followedUserIds != null &&
          followedUserIds.contains(post.userId)) {
        score += 50.0;
      }

      // Interest matching
      if (userInterests != null) {
        final matchingHashtags = post.hashtags
            .where((tag) => userInterests
                .any((interest) =>
                    tag.toLowerCase().contains(interest.toLowerCase())))
            .length;
        score += matchingHashtags * 10.0;
      }

      // Search history matching
      if (searchHistory != null && post.caption != null) {
        final matchingKeywords = searchHistory
            .where((keyword) =>
                post.caption!.toLowerCase().contains(keyword.toLowerCase()))
            .length;
        score += matchingKeywords * 5.0;
      }

      // Recent posts get slight boost
      final hoursSincePost =
          DateTime.now().difference(post.createdAt).inHours;
      score += (24 - hoursSincePost).clamp(0, 24) * 0.5;

      return {'post': post, 'score': score};
    }).toList();

    // Sort by score (highest first)
    rankedPosts.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double));

    // Insert ads every 5 posts
    final finalFeed = <FeedPost>[];
    for (int i = 0; i < rankedPosts.length; i++) {
      finalFeed.add(rankedPosts[i]['post'] as FeedPost);
      if ((i + 1) % 5 == 0 && i < rankedPosts.length - 1) {
        final ads = _getAds();
        if (ads.isNotEmpty) {
          finalFeed.add(ads[i % ads.length]);
        }
      }
    }

    return finalFeed;
  }

  List<FeedPost> _generateFeedPosts() {
    final now = DateTime.now();
    return [
      FeedPost(
        id: 'post-1',
        userId: 'user-2',
        userName: 'Alice Smith',
        mediaType: PostMediaType.image,
        mediaUrls: ['image_url_1'],
        caption: 'Beautiful sunset today! 🌅 #sunset #nature #photography',
        hashtags: ['sunset', 'nature', 'photography'],
        createdAt: now.subtract(const Duration(hours: 2)),
        likes: 245,
        comments: 12,
        isLiked: false,
        isFollowed: true,
      ),
      FeedPost(
        id: 'post-2',
        userId: 'user-3',
        userName: 'Bob Johnson',
        mediaType: PostMediaType.video,
        mediaUrls: ['https://assets.mixkit.co/videos/preview/mixkit-tree-branches-in-the-breeze-1188-large.mp4'],
        thumbnailUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
        caption: 'Working on something exciting! 💻 #coding #tech',
        hashtags: ['coding', 'tech'],
        createdAt: now.subtract(const Duration(hours: 5)),
        likes: 189,
        comments: 8,
        views: 1200,
        isLiked: true,
        isFollowed: true,
      ),
      FeedPost(
        id: 'post-3',
        userId: 'user-4',
        userName: 'Emma Wilson',
        mediaType: PostMediaType.carousel,
        mediaUrls: ['https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&q=80', 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=800&q=80'],
        caption: 'Tagged you in this! @JohnDoe #friends #memories',
        hashtags: ['friends', 'memories'],
        createdAt: now.subtract(const Duration(hours: 1)),
        likes: 156,
        comments: 5,
        isLiked: false,
        isTagged: true,
      ),
      FeedPost(
        id: 'post-4',
        userId: 'user-5',
        userName: 'Mike Brown',
        mediaType: PostMediaType.carousel,
        mediaUrls: ['https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=800&q=80'],
        caption: 'Check out my new collection! 🎨 #art #design',
        hashtags: ['art', 'design'],
        createdAt: now.subtract(const Duration(hours: 3)),
        likes: 320,
        comments: 15,
        isLiked: false,
        isFollowed: true,
      ),
      FeedPost(
        id: 'post-5',
        userId: 'user-6',
        userName: 'Sarah Davis',
        mediaType: PostMediaType.reel,
        mediaUrls: ['https://assets.mixkit.co/videos/preview/mixkit-girl-dancing-happy-in-a-room-4179-large.mp4'],
        thumbnailUrl: 'https://images.unsplash.com/photo-1547153760-18fc86324498?w=800&q=80',
        caption: 'Quick tutorial! #tutorial #tips',
        hashtags: ['tutorial', 'tips'],
        createdAt: now.subtract(const Duration(hours: 4)),
        likes: 890,
        comments: 45,
        views: 5000,
        isLiked: false,
        isFollowed: false,
      ),
      FeedPost(
        id: 'post-6',
        userId: 'user-7',
        userName: 'David Lee',
        mediaType: PostMediaType.image,
        mediaUrls: ['image_url_7'],
        caption: 'Amazing day at the beach! 🏖️ #beach #summer',
        hashtags: ['beach', 'summer'],
        createdAt: now.subtract(const Duration(hours: 6)),
        likes: 278,
        comments: 22,
        isLiked: false,
      ),
      FeedPost(
        id: 'post-7',
        userId: 'user-8',
        userName: 'Lisa Chen',
        isVerified: true,
        mediaType: PostMediaType.video,
        mediaUrls: ['video_url_2'],
        caption: 'New recipe I tried today! 🍰 #food #cooking',
        hashtags: ['food', 'cooking'],
        createdAt: now.subtract(const Duration(hours: 8)),
        likes: 412,
        comments: 18,
        views: 2500,
        isLiked: true,
      ),
    ];
  }

  List<FeedPost> _getAds() {
    final now = DateTime.now();
    return [
      FeedPost(
        id: 'ad-post-1',
        userId: 'advertiser-1',
        userName: 'Sponsored',
        mediaType: PostMediaType.image,
        mediaUrls: ['ad_image_1'],
        caption: 'Special Offer - 50% Off!',
        createdAt: now.subtract(const Duration(hours: 1)),
        likes: 0,
        comments: 0,
        isAd: true,
        adTitle: 'Special Offer',
        adCompanyId: 'company-1',
        adCompanyName: 'TechCorp',
      ),
    ];
  }

  /// Fetch feed from the REST API backend.
  ///
  /// Replaces the previous Supabase-direct `fetchFeedFromBackend`.
  Future<List<FeedPost>> fetchFeedFromBackend({
    int limit = 50,
    int offset = 0,
    String? currentUserId,
  }) async {
    Set<String> locallySaved = <String>{};
    Set<String> followedUsers = <String>{};
    if (currentUserId != null && currentUserId.isNotEmpty) {
      final svc = SupabaseService();
      locallySaved = await svc.getSavedPostIds(currentUserId);
      followedUsers = await svc.getFollowedUserIds(currentUserId);
    }
    try {
      final page = (offset ~/ limit) + 1;
      final data = await _postsApi.getFeed(page: page, limit: limit);
      List<Map<String, dynamic>> items = [];
      if (data is List) {
        items = (data as List).cast<Map<String, dynamic>>();
      } else if (data is Map) {
        final map = data as Map;
        if (map['posts'] is List) {
          items = (map['posts'] as List).cast<Map<String, dynamic>>();
        } else if (map['data'] is List) {
          items = (map['data'] as List).cast<Map<String, dynamic>>();
        } else if (map['data'] is Map && (map['data'] as Map)['posts'] is List) {
          items = ((map['data'] as Map)['posts'] as List).cast<Map<String, dynamic>>();
        }
      }

      final mapped = <FeedPost>[];

      for (final raw in items) {
        try {
          final Map<String, dynamic> item =
              Map<String, dynamic>.from(raw as Map<dynamic, dynamic>);

          final postId = item['_id'] as String? ?? item['id'] as String? ?? '';
        // The API nests the author info inside `user_id` as a populated object.
          Map<String, dynamic> user = {};
          if (item['user_id'] is Map) {
            user = Map<String, dynamic>.from(item['user_id'] as Map);
          } else if (item['users'] is Map) {
            user = Map<String, dynamic>.from(item['users'] as Map);
          }

        final rawLikesAny = (item['likes'] as List<dynamic>?) ??
            (item['liked_by'] as List<dynamic>?) ??
            const [];
        final likesCount = (item['likes_count'] as int?) ?? rawLikesAny.length;
        bool computedLiked = false;
        if (currentUserId != null && rawLikesAny.isNotEmpty) {
          for (final e in rawLikesAny) {
            if (e is Map) {
              String? uid = (e['user_id'] as String?) ??
                  (e['id'] as String?) ??
                  (e['_id'] as String?);
              if (uid == null && e['user'] is Map) {
                final u = (e['user'] as Map);
                uid = (u['id'] as String?) ?? (u['_id'] as String?);
              }
              if (uid != null && uid.toString() == currentUserId.toString()) {
                computedLiked = true;
                break;
              }
            } else if (e is String && e.toString() == currentUserId.toString()) {
              computedLiked = true;
              break;
            }
          }
        }
        final hasLikesArray = rawLikesAny.isNotEmpty;
        final isLikedByMe = hasLikesArray
            ? computedLiked
            : ((item['is_liked_by_me'] as bool?) ?? false);

        bool isSavedByMe = (item['is_saved_by_me'] as bool?) ?? false;
        if (!isSavedByMe && currentUserId != null) {
          final savedBy = (item['saved_by'] as List<dynamic>?) ??
              (item['bookmarks'] as List<dynamic>?) ??
              const [];
          for (final entry in savedBy) {
            if (entry is String && entry == currentUserId) {
              isSavedByMe = true;
              break;
            }
            if (entry is Map) {
              final id = (entry['id'] as String?) ??
                  (entry['_id'] as String?) ??
                  (entry['user_id'] as String?);
              if (id != null && id == currentUserId) {
                isSavedByMe = true;
                break;
              }
            }
          }
        }
        if (!isSavedByMe && locallySaved.isNotEmpty) {
          if (locallySaved.contains(postId)) {
            isSavedByMe = true;
          }
        }

        final authorId = user['_id'] as String? ??
            user['id'] as String? ??
            (item['user_id'] is String ? item['user_id'] as String : '');

        bool isFollowedByMe = (item['is_followed_by_me'] as bool?) ?? false;
        if (!isFollowedByMe && followedUsers.isNotEmpty && authorId.isNotEmpty) {
          if (followedUsers.contains(authorId)) {
            isFollowedByMe = true;
          }
        }

          final dynamic rawMedia = item['media'] ?? item['images'] ?? item['attachments'];
          final List<dynamic> media = rawMedia is List
              ? rawMedia
              : rawMedia is Map
                  ? <dynamic>[rawMedia]
                  : <dynamic>[];

          List<String> mediaUrls = media.map((m) {
          String? url;
          if (m is String) {
            url = m;
          } else if (m is Map) {
            if (m['file'] is Map) {
              final f = (m['file'] as Map);
              url = (f['fileUrl'] ?? f['file_url'] ?? f['url'] ?? f['path'])?.toString();
            } else if (m['file'] is String) {
              url = (m['file'] as String);
            }
            url ??= (m['fileUrl'] ??
                    m['file_url'] ??
                    m['image'] ??
                    m['imageUrl'] ??
                    m['url'] ??
                    m['file_path'])
                ?.toString();
            if ((url == null || url.isEmpty) && m['fileName'] != null) {
              final fn = m['fileName'].toString();
              url = '/uploads/$fn';
            }
          }
            return UrlHelper.normalizeUrl(url);
          }).where((u) => u.isNotEmpty).cast<String>().toList();
          if (mediaUrls.isEmpty) {
          final single = (item['imageUrl'] ??
                  item['image'] ??
                  item['fileUrl'] ??
                  item['file_url'] ??
                  item['url'] ??
                  item['file_path'])
              ?.toString();
          final normalized = UrlHelper.normalizeUrl(single);
            if (normalized.isNotEmpty) {
              mediaUrls = [normalized];
            }
          }
          if (mediaUrls.isEmpty) {
          final single = (item['imageUrl'] ?? item['image'] ?? item['url'])?.toString();
          if (single != null && single.isNotEmpty) {
            mediaUrls.add(single);
          }
          }

          final typeStr = ((item['type'] as String?) ?? (item['media_type'] as String?) ?? 'post').toLowerCase();
          bool hasVideo = false;
          for (final mm in media) {
          if (mm is Map) {
            final t = (mm['type'] as String?)?.toLowerCase();
            if (t == 'video' || t == 'reel') {
              hasVideo = true;
              break;
            }
            final cand = (mm['fileUrl'] ??
                    mm['file_url'] ??
                    mm['url'] ??
                    mm['file_path'] ??
                    (mm['file'] is String ? mm['file'] : null) ??
                    (mm['file'] is Map ? ((mm['file'] as Map)['url'] ?? (mm['file'] as Map)['fileUrl']) : null))
                ?.toString()
                .toLowerCase();
            if (cand != null &&
                (cand.endsWith('.mp4') || cand.endsWith('.mov') || cand.contains('.m3u8'))) {
              hasVideo = true;
              break;
            }
          } else if (mm is String) {
            final s = mm.toLowerCase();
            if (s.endsWith('.mp4') || s.endsWith('.mov')) {
              hasVideo = true;
              break;
            }
          }
          }
          PostMediaType mediaType = PostMediaType.image;
          if (typeStr == 'reel') {
            mediaType = PostMediaType.reel;
          } else if (hasVideo) {
            mediaType = mediaUrls.length == 1 ? PostMediaType.reel : PostMediaType.video;
          } else if (mediaUrls.length > 1) {
            mediaType = PostMediaType.carousel;
          }

          String? thumbnailUrl;
          if (media.isNotEmpty) {
            final first = media.first;
            if (first is Map) {
              final thumb = (first['thumbnail'] ?? first['thumbnailUrl'] ?? first['thumb'])?.toString();
              if (thumb != null && thumb.isNotEmpty) {
                thumbnailUrl = UrlHelper.normalizeUrl(thumb);
              }
            }
          }

          final post = FeedPost(
            id: postId,
            userId: authorId,
            userName: user['username'] as String? ?? (item['username'] as String?) ?? 'user',
            fullName: user['full_name'] as String? ?? (item['full_name'] as String?),
            userAvatar: user['avatar_url'] as String? ?? (item['userAvatar'] as String?),
            isVerified: user['is_verified'] as bool? ?? false,
            mediaType: mediaType,
            mediaUrls: mediaUrls,
            thumbnailUrl: thumbnailUrl,
            caption: item['caption'] as String?,
            hashtags: ((item['tags'] as List<dynamic>?) ?? [])
                .map((e) => e.toString())
                .toList(),
            createdAt: item['createdAt'] is String
                ? DateTime.parse(item['createdAt'] as String)
                : (item['created_at'] is String
                    ? DateTime.tryParse(item['created_at'] as String) ?? DateTime.now()
                    : DateTime.now()),
            likes: likesCount,
            comments: item['comments'] is List
                ? (item['comments'] as List).length
                : (item['comments_count'] as int? ?? (item['commentCount'] as int? ?? 0)),
            views: 0,
            isLiked: isLikedByMe,
            isSaved: isSavedByMe,
            isFollowed: isFollowedByMe,
            isTagged: (item['people_tags'] as List?)?.isNotEmpty ?? false,
            peopleTags: (item['people_tags'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList(),
            isShared: false,
            isAd: false,
            rawLikes: rawLikesAny.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList(),
          );

          mapped.add(post);
        } catch (_) {
          // Skip any malformed items so a single bad post doesn't break the feed.
          continue;
        }
      }

      return mapped;
    } catch (_) {
      // On any top-level error, fall back to empty list so UI can recover.
      return [];
    }
  }

  // Get stories for online users
  List<StoryGroup> getStories() {
    return [];
  }

  /// Fetch stories feed from backend and map to [StoryGroup]s.
  Future<List<StoryGroup>> fetchStoriesFeed() async {
    final feed = await _storiesApi.feed();
    final groups = feed.map<StoryGroup>((item) {
      final Map data = item as Map;
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final preview = data['preview_item'] as Map<String, dynamic>? ?? {};
      final itemsCount = (data['items_count'] as int?) ?? 0;
      final seen = (data['seen'] as bool?) ?? false;
      final storyId = (data['_id'] as String?) ?? (data['id'] as String?);
      final previewUserId = (preview['user_id'] as String?) ?? '';
      final rawMedia = preview['media'];
      Map<String, dynamic>? media;
      if (rawMedia is List && rawMedia.isNotEmpty && rawMedia.first is Map) {
        media = Map<String, dynamic>.from(rawMedia.first as Map);
      } else if (rawMedia is Map) {
        media = Map<String, dynamic>.from(rawMedia);
      }
      return StoryGroup(
        userId: previewUserId.isNotEmpty
            ? previewUserId
            : (user['_id'] as String?) ?? (user['id'] as String?) ?? 'unknown',
        userName: (user['username'] as String?) ?? 'User',
        userAvatar: user['avatar_url'] as String?,
        isOnline: true,
        isCloseFriend: false,
        isSubscribedCreator: false,
        storyId: storyId,
        stories: preview.isEmpty || media == null
            ? <Story>[]
            : <Story>[
                Story(
                  id: (preview['_id'] as String?) ?? 'item',
                  userId: previewUserId.isNotEmpty
                      ? previewUserId
                      : (user['_id'] as String?) ?? (user['id'] as String?) ?? '',
                  userName: (user['username'] as String?) ?? 'User',
                  userAvatar: user['avatar_url'] as String?,
                  mediaUrl: UrlHelper.normalizeUrl((media['url'] as String?) ?? ''),
                  mediaType: (media['type'] as String?) == 'image'
                      ? StoryMediaType.image
                      : StoryMediaType.video,
                  createdAt: DateTime.tryParse(preview['createdAt'] as String? ?? '') ?? DateTime.now(),
                  views: (data['views_count'] as int?) ?? 0,
                  isViewed: seen,
                  expiresAt: DateTime.tryParse(preview['expiresAt'] as String? ?? ''),
                  isDeleted: (preview['isDeleted'] as bool?) ?? false,
                ),
              ],
      );
    }).toList();

    // Sort so that:
    // - Users with unseen stories come first
    // - Within each group, preview uses latest story
    groups.sort((a, b) {
      final aStory = a.stories.isNotEmpty ? a.stories.first : null;
      final bStory = b.stories.isNotEmpty ? b.stories.first : null;

      final aSeen = aStory?.isViewed ?? false;
      final bSeen = bStory?.isViewed ?? false;
      if (aSeen != bSeen) {
        return aSeen ? 1 : -1; // unseen first
      }

      final ad = aStory?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = bStory?.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad); // newest first
    });

    return groups;
  }

  /// Fetch all items for a specific story.
  Future<List<Story>> fetchStoryItems(String storyId, {String? ownerUserName, String? ownerAvatar}) async {
    final rawItems = await _storiesApi.items(storyId);
    final items = List<Map<String, dynamic>>.from(rawItems.map((e) => Map<String, dynamic>.from(e as Map)));

    items.sort((a, b) {
      final ad = DateTime.tryParse(a['createdAt'] as String? ?? a['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse(b['createdAt'] as String? ?? b['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      // Oldest first so that the latest story is viewed last
      return ad.compareTo(bd);
    });

    return items.map<Story>((m) {
      final rawMedia = m['media'];
      Map<String, dynamic>? media;
      if (rawMedia is List && rawMedia.isNotEmpty && rawMedia.first is Map) {
        media = Map<String, dynamic>.from(rawMedia.first as Map);
      } else if (rawMedia is Map) {
        media = Map<String, dynamic>.from(rawMedia);
      }
      final mediaUrl = UrlHelper.normalizeUrl(media?['url'] as String? ?? '');
      final mediaType = (media?['type'] == 'image') ? StoryMediaType.image : StoryMediaType.video;
      final texts = (m['texts'] is List) ? (m['texts'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : null;
      final mentions = (m['mentions'] is List) ? (m['mentions'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : null;
      final transform = (m['transform'] is Map) ? Map<String, dynamic>.from(m['transform'] as Map) : null;
      final filter = (m['filter'] is Map) ? Map<String, dynamic>.from(m['filter'] as Map) : null;
      final int? durationSec = (media?['durationSec'] is int) ? (media?['durationSec'] as int) : (m['durationSec'] as int?);
      return Story(
        id: (m['_id'] as String?) ?? 'item',
        userId: (m['user_id'] as String?) ?? '',
        userName: ownerUserName ?? '',
        userAvatar: ownerAvatar,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
        views: 0,
        isViewed: false,
        expiresAt: DateTime.tryParse(m['expiresAt'] as String? ?? ''),
        isDeleted: (m['isDeleted'] as bool?) ?? false,
        texts: texts,
        mentions: mentions,
        transform: transform,
        filter: filter,
        durationSec: durationSec,
      );
    }).toList();
  }

  /// Mark an item as viewed.
  Future<void> markItemViewed(String itemId) async {
    await _storiesApi.viewItem(itemId);
  }

  // Get current user for profile icon
  User getCurrentUser() {
    // Will be populated after fetching /auth/me.
    // Return a placeholder; the caller should use AuthService.fetchCurrentUser() instead.
    return User(
      id: 'unknown',
      name: 'User',
      email: '',
    );
  }

  /// Fetch the current user from the REST API.
  Future<User> fetchCurrentUser() async {
    try {
      final data = await _authApi.me();
      return User(
        id: data['id'] as String? ?? data['_id'] as String? ?? 'unknown',
        name: data['full_name'] as String? ??
            data['username'] as String? ??
            'User',
        email: data['email'] as String? ?? '',
        avatarUrl: data['avatar_url'] as String?,
        username: data['username'] as String?,
      );
    } catch (_) {
      return User(id: 'unknown', name: 'User', email: '');
    }
  }

  // Like/Unlike post
  FeedPost toggleLike(FeedPost post) {
    return post.copyWith(
      isLiked: !post.isLiked,
      likes: post.isLiked ? post.likes - 1 : post.likes + 1,
    );
  }

  // Save/Unsave post
  FeedPost toggleSave(FeedPost post) {
    return post.copyWith(isSaved: !post.isSaved);
  }

  // Follow/Unfollow user
  FeedPost toggleFollow(FeedPost post) {
    return post.copyWith(isFollowed: !post.isFollowed);
  }
}
