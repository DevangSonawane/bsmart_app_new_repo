import 'dart:typed_data';
import '../api/api.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/current_user.dart';

/// Service layer that was previously calling Supabase directly.
///
/// Now delegates to the new REST API endpoints while keeping the same
/// public interface so existing screens/widgets continue to work unchanged.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final UsersApi _usersApi = UsersApi();
  final PostsApi _postsApi = PostsApi();
  final CommentsApi _commentsApi = CommentsApi();
  final UploadApi _uploadApi = UploadApi();
  final FollowsApi _followsApi = FollowsApi();
  final Map<String, bool> _commentLikeOverrides = {};
  void setCommentLikeOverride(String commentId, bool liked) {
    _commentLikeOverrides[commentId] = liked;
  }
  bool? getCommentLikeOverride(String commentId) {
    return _commentLikeOverrides[commentId];
  }
  final Map<String, List<Map<String, dynamic>>> _repliesCache = {};
  void setRepliesCache(String commentId, List<Map<String, dynamic>> replies) {
    _repliesCache[commentId] = List<Map<String, dynamic>>.from(replies);
    () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('replies_cache_$commentId', jsonEncode(replies));
      } catch (_) {}
    }();
  }
  List<Map<String, dynamic>> getRepliesCached(String commentId) {
    return List<Map<String, dynamic>>.from(_repliesCache[commentId] ?? const []);
  }
  Future<Map<String, List<Map<String, dynamic>>>> loadRepliesCacheFor(List<String> commentIds) async {
    final result = <String, List<Map<String, dynamic>>>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final id in commentIds) {
        final raw = prefs.getString('replies_cache_$id');
        if (raw != null && raw.isNotEmpty) {
          final parsed = jsonDecode(raw);
          if (parsed is List) {
            final list = parsed.map((e) => (e as Map).cast<String, dynamic>()).toList().cast<Map<String, dynamic>>();
            _repliesCache[id] = list;
            result[id] = list;
          }
        }
      }
    } catch (_) {}
    return result;
  }

  static const String _savedPostsKeyPrefix = 'saved_posts_';
  static const String _followedUsersKeyPrefix = 'followed_users_';

  Future<Set<String>> getSavedPostIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_savedPostsKeyPrefix$userId');
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
      return <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _setSavedPostIds(String userId, Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_savedPostsKeyPrefix$userId',
        jsonEncode(ids.toList()),
      );
    } catch (_) {}
  }

  Future<void> _updateLocalSaved(String postId, bool saved) async {
    try {
      final uid = await CurrentUser.id;
      if (uid == null || uid.isEmpty) return;
      final current = await getSavedPostIds(uid);
      if (saved) {
        current.add(postId);
      } else {
        current.remove(postId);
      }
      await _setSavedPostIds(uid, current);
    } catch (_) {}
  }

  Future<Set<String>> getFollowedUserIds(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_followedUsersKeyPrefix$userId');
      if (raw == null || raw.isEmpty) return <String>{};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
      return <String>{};
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _setFollowedUserIds(String userId, Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_followedUsersKeyPrefix$userId',
        jsonEncode(ids.toList()),
      );
    } catch (_) {}
  }

  Future<void> syncFollowStatus(String targetUserId, bool followed) async {
    await _updateLocalFollow(targetUserId, followed);
  }

  Future<void> _updateLocalFollow(String targetUserId, bool followed) async {
    try {
      final uid = await CurrentUser.id;
      if (uid == null || uid.isEmpty) return;
      final current = await getFollowedUserIds(uid);
      if (followed) {
        current.add(targetUserId);
      } else {
        current.remove(targetUserId);
      }
      await _setFollowedUserIds(uid, current);
    } catch (_) {}
  }

  // ── Users ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    // Primary source: public users endpoint with posts
    try {
      final data = await _usersApi.getUserProfile(userId);
      
      // Case 1: data['user'] exists (Standard format)
      if (data['user'] is Map) {
        return data['user'] as Map<String, dynamic>;
      }
      
      // Case 2: data['data'] exists (Sometimes wrapped)
      if (data['data'] is Map) {
        final d = data['data'] as Map;
        if (d['user'] is Map) return d['user'] as Map<String, dynamic>;
        // If data['data'] IS the user object
        if (d['username'] != null || d['full_name'] != null || d['_id'] != null) {
          return d.cast<String, dynamic>();
        }
      }

      // Case 3: data IS the user object (Direct return)
      if (data['username'] != null || data['full_name'] != null || data['_id'] != null || data['id'] != null) {
        return data;
      }
    } catch (_) {}

    // Fallback: authenticated user endpoint
    try {
      final me = await AuthApi().me();
      // Only return if it matches the requested id or no public profile existed
      final meId = me['id'] as String? ?? me['_id'] as String?;
      if (meId != null && meId == userId) {
        return me;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final results = await _usersApi.search(email);
      final match = results.firstWhere(
        (u) => (u['email'] as String?)?.toLowerCase() == email.toLowerCase(),
        orElse: () => {},
      );
      if (match.isEmpty) return null;
      return match;
    } catch (_) {
      return null;
    }
  }

  Future<bool> checkUsernameAvailable(String username) async {
    // No dedicated endpoint – the server rejects duplicate usernames at
    // registration time. Return true optimistically.
    return true;
  }

  Future<bool> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      await _usersApi.updateUser(
        userId,
        fullName: updates['full_name'] as String?,
        bio: updates['bio'] as String?,
        avatarUrl: updates['avatar_url'] as String?,
        phone: updates['phone'] as String?,
        username: updates['username'] as String?,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Posts ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getPostById(String postId) async {
    try {
      return await _postsApi.getPost(postId);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getUserPosts(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final data = await _usersApi.getUserProfile(userId);
      List<dynamic> posts = [];
      if (data['posts'] is List) {
        posts = data['posts'] as List<dynamic>;
      } else if (data['user'] is Map && (data['user'] as Map)['posts'] is List) {
        posts = ((data['user'] as Map)['posts'] as List<dynamic>);
      } else if (data['data'] is Map && (data['data'] as Map)['posts'] is List) {
        posts = ((data['data'] as Map)['posts'] as List<dynamic>);
      }
      if (posts.isNotEmpty) {
        return posts.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    try {
      final page = (offset ~/ limit) + 1;
      final data = await _postsApi.getFeed(page: page, limit: limit * 3);
      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        raw = data['posts'] as List<dynamic>? ?? [];
      }
      final posts = raw.where((p) {
        final m = (p as Map).cast<String, dynamic>();
        final uid = m['user_id'];
        if (uid is String) {
          if (uid == userId) return true;
        } else if (uid is Map) {
          final id = uid['_id'] as String? ?? uid['id'] as String?;
          if (id == userId) return true;
        }
        final joinedUser = m['users'];
        if (joinedUser is Map) {
          final id = joinedUser['id'] as String? ?? joinedUser['_id'] as String?;
          if (id == userId) return true;
        }
        return false;
      }).toList();
      return posts.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserSavedPosts(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final page = (offset ~/ limit) + 1;
      final data = await _postsApi.getFeed(page: page, limit: limit * 3);
      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        raw = data['posts'] as List<dynamic>? ?? [];
      }
      final posts = raw.where((p) {
        final m = (p as Map).cast<String, dynamic>();
        final isSaved = m['is_saved_by_me'] as bool?;
        if (isSaved == true) return true;
        final savedBy = m['saved_by'] as List<dynamic>?;
        if (savedBy != null) {
          for (final entry in savedBy) {
            if (entry is String && entry == userId) return true;
            if (entry is Map) {
              final id = entry['id'] as String? ?? entry['_id'] as String? ?? entry['user_id'] as String?;
              if (id == userId) return true;
            }
          }
        }
        final bookmarks = m['bookmarks'] as List<dynamic>?;
        if (bookmarks != null) {
          for (final b in bookmarks) {
            if (b is String && b == userId) return true;
            if (b is Map) {
              final id = b['id'] as String? ?? b['_id'] as String? ?? b['user_id'] as String?;
              if (id == userId) return true;
            }
          }
        }
        return false;
      }).toList();
      return posts.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserTaggedPosts(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final page = (offset ~/ limit) + 1;
      final data = await _postsApi.getFeed(page: page, limit: limit * 3);
      List<dynamic> raw = [];
      if (data is List) {
        raw = data;
      } else if (data is Map) {
        raw = data['posts'] as List<dynamic>? ?? [];
      }
      final posts = raw.where((p) {
        final m = (p as Map).cast<String, dynamic>();
        final peopleTags = (m['people_tags'] as List<dynamic>?) ?? (m['peopleTags'] as List<dynamic>?) ?? const [];
        for (final t in peopleTags) {
          if (t is String && t == userId) return true;
          if (t is Map) {
            final id = t['user_id'] as String? ?? t['id'] as String? ?? t['_id'] as String?;
            if (id == userId) return true;
          }
        }
        return false;
      }).toList();
      return posts.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchFeed(
      {int limit = 20, int offset = 0}) async {
    try {
      final page = (offset ~/ limit) + 1;
      final data = await _postsApi.getFeed(page: page, limit: limit);
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
      final posts = (data as Map)['posts'] as List<dynamic>? ?? [];
      return posts.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createPost(Map<String, dynamic> postData) async {
    try {
      final media = postData['media'] as List<dynamic>? ?? [];
      await _postsApi.createPost(
        media: media.cast<Map<String, dynamic>>(),
        caption: postData['caption'] as String?,
        location: postData['location'] as String?,
        tags: (postData['tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
        hideLikesCount: postData['hide_likes_count'] as bool?,
        turnOffCommenting: postData['turn_off_commenting'] as bool?,
        peopleTags: (postData['people_tags'] as List<dynamic>?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList(),
        type: postData['type'] as String? ?? 'post',
      );
      return true;
    } on ApiException {
      // Fallback: retry with a minimal media payload if server rejects full schema
      try {
        final media = (postData['media'] as List<dynamic>? ?? [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .map((m) => {
                  'fileUrl': m['fileUrl'],
                  'type': m['type'],
                })
            .toList();
        await _postsApi.createPost(
          media: media,
          caption: postData['caption'] as String?,
          location: postData['location'] as String?,
          type: postData['type'] as String? ?? 'post',
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // ── Follows ────────────────────────────────────────────────────────────────

  Future<bool> toggleFollow(String userId, String targetUserId) async {
    try {
      if (userId == targetUserId) {
        return true;
      }
      final res = await _followsApi.follow(targetUserId);
      final followed = res['followed'] as bool? ?? true;
      return followed;
    } catch (_) {
      return false;
    }
  }

  Future<bool> followUser(String targetUserId) async {
    bool result = false; // Default to failure for optimistic UI revert
    try {
      final res = await _followsApi.follow(targetUserId);
      final followed = res['followed'] as bool?;
      if (followed != null) {
        result = followed;
      } else {
        // Fallback if 'followed' key missing but no error
        result = true;
      }
    } catch (_) {
      try {
        final res = await _followsApi.followById(targetUserId);
        final followed = res['followed'] as bool?;
        if (followed != null) {
          result = followed;
        } else {
           result = true;
        }
      } catch (_) {
        result = false;
      }
    }
    // Only update local cache if operation appeared successful (or explicitly returned status)
    if (result) {
      await _updateLocalFollow(targetUserId, true);
    }
    return result;
  }

  Future<bool> unfollowUser(String targetUserId) async {
    bool result = false; // Default to failure
    try {
      final res = await _followsApi.unfollow(targetUserId);
      final followed = res['followed'] as bool?;
      if (followed != null) {
        result = !followed; // If followed=false, then unfollow succeeded (result=true means "success")
      } else {
        result = true;
      }
    } catch (_) {
      result = false;
    }
    // If unfollow succeeded (result=true), we update cache to false (not following)
    if (result) {
      await _updateLocalFollow(targetUserId, false);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getFollowers(String userId) {
    return _followsApi.getFollowers(userId);
  }

  Future<List<Map<String, dynamic>>> getFollowing(String userId) {
    return _followsApi.getFollowing(userId);
  }

  Future<List<Map<String, dynamic>>> getAllFollowers() {
    return _followsApi.getAllFollowers();
  }

  Future<List<Map<String, dynamic>>> getAllFollowing() {
    return _followsApi.getAllFollowing();
  }

  Future<int> getFollowersCount(String userId) async {
    try {
      final list = await _followsApi.getFollowers(userId);
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getFollowingCount(String userId) async {
    try {
      final list = await _followsApi.getFollowing(userId);
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> isFollowing(String meId, String targetUserId) async {
    try {
      final ids = await getFollowedUserIds(meId);
      if (ids.contains(targetUserId)) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── Uploads ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadFile(String bucket, String path, Uint8List bytes,
      {bool makePublic = true}) async {
    final result = await _uploadApi.uploadFileBytes(
      bytes: bytes,
      filename: path.split('/').last,
    );
    return result;
  }

  // ── Comments ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getComments(String postId,
      {int page = 1, int limit = 50, bool newestFirst = true}) async {
    try {
      final data = await _commentsApi.getComments(postId, page: page, limit: limit);
      List<Map<String, dynamic>> comments = [];
      if (data is List) {
        comments = (data as List).cast<Map<String, dynamic>>();
      } else if (data is Map) {
        final map = data as Map;
        if (map['comments'] is List) {
          comments = (map['comments'] as List).cast<Map<String, dynamic>>();
        } else if (map['data'] is List) {
          comments = (map['data'] as List).cast<Map<String, dynamic>>();
        } else if (map['data'] is Map && (map['data'] as Map)['comments'] is List) {
          comments = ((map['data'] as Map)['comments'] as List).cast<Map<String, dynamic>>();
        }
      }
      if (newestFirst) {
        comments.sort((a, b) {
          final as = (a['created_at'] as String?) ?? (a['createdAt'] as String?) ?? '';
          final bs = (b['created_at'] as String?) ?? (b['createdAt'] as String?) ?? '';
          final ad = DateTime.tryParse(as) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = DateTime.tryParse(bs) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
      }
      return comments;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> addComment(
      String postId, String userId, String content, {String? parentId}) async {
    try {
      final created = await _commentsApi.addComment(
        postId,
        text: content,
        parentId: parentId,
      );
      return created;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await _commentsApi.deleteComment(commentId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> likeComment(String commentId) async {
    try {
      final res = await _commentsApi.likeComment(commentId);
      return res;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> unlikeComment(String commentId) async {
    try {
      final res = await _commentsApi.unlikeComment(commentId);
      return res;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getReplies(String commentId,
      {int page = 1, int limit = 10}) async {
    try {
      final res = await _commentsApi.getReplies(commentId, page: page, limit: limit);
      final replies = res['replies'] as List<dynamic>? ?? [];
      final casted = replies.cast<Map<String, dynamic>>();
      setRepliesCache(commentId, casted);
      return casted;
    } catch (_) {
      return getRepliesCached(commentId);
    }
  }

  // ── Likes ──────────────────────────────────────────────────────────────────

  Future<Set<String>> getLikedPostIds(String userId) async {
    // The new API doesn't have a batch "get liked post IDs" endpoint.
    // Feed posts include `is_liked_by_me` so we derive it at render time.
    return {};
  }

  Future<bool> updatePostLikes(
      String postId, List<Map<String, dynamic>> likes) async {
    // Replaced by explicit like/unlike endpoints.
    return false;
  }

  Future<bool> togglePostLike(String postId, String userId) async {
    try {
      // Try to like; if already liked the server returns 400, then unlike.
      try {
        await _postsApi.likePost(postId);
        return true; // liked
      } on BadRequestException {
        await _postsApi.unlikePost(postId);
        return false; // unliked
      }
    } catch (_) {
      return false;
    }
  }

  /// Explicitly set post like state.
  ///
  /// Calls `/posts/:id/like` when [like] is true, otherwise `/posts/:id/unlike`.
  /// Returns the server's authoritative `liked` state.
  Future<bool> setPostLike(String postId, {required bool like}) async {
    try {
      final res = like ? await _postsApi.likePost(postId) : await _postsApi.unlikePost(postId);
      final liked = res['liked'] as bool?;
      if (liked != null) return liked;
      final lc = res['likes_count'] as int?;
      if (lc != null) return lc > 0;
      // As a final fallback, re-fetch the post to derive authoritative state.
      try {
        final post = await _postsApi.getPost(postId);
        final isLikedByMe = post['is_liked_by_me'] as bool?;
        if (isLikedByMe != null) return isLikedByMe;
        final likesCount = post['likes_count'] as int?;
        if (likesCount != null) return likesCount > 0;
      } catch (_) {}
      return like;
    } on BadRequestException {
      // Already in desired state; fetch current state to avoid incorrect flips.
      try {
        final post = await _postsApi.getPost(postId);
        final isLikedByMe = post['is_liked_by_me'] as bool?;
        if (isLikedByMe != null) return isLikedByMe;
        final likesCount = post['likes_count'] as int?;
        if (likesCount != null) return likesCount > 0;
      } catch (_) {}
      return like;
    } on UnauthorizedException {
      // Token missing/expired – cannot persist. Try to read current state; otherwise keep desired for UI.
      try {
        final post = await _postsApi.getPost(postId);
        final isLikedByMe = post['is_liked_by_me'] as bool?;
        if (isLikedByMe != null) return isLikedByMe;
      } catch (_) {}
      return like;
    } catch (_) {
      // Network or other error – avoid flipping; best-effort read of server state failed.
      return like;
    }
  }

  Future<bool> setPostSaved(String postId, {required bool save}) async {
    bool result = save;
    try {
      final res = save ? await _postsApi.savePost(postId) : await _postsApi.unsavePost(postId);
      final saved = res['saved'] as bool?;
      if (saved != null) result = saved;
      final isSavedByMe = res['is_saved_by_me'] as bool?;
      if (isSavedByMe != null) result = isSavedByMe;
      if (saved == null && isSavedByMe == null) {
        try {
          final post = await _postsApi.getPost(postId);
          final postSaved = post['is_saved_by_me'] as bool?;
          if (postSaved != null) result = postSaved;
        } catch (_) {}
      }
    } on BadRequestException {
      try {
        final post = await _postsApi.getPost(postId);
        final postSaved = post['is_saved_by_me'] as bool?;
        if (postSaved != null) result = postSaved;
      } catch (_) {}
    } on UnauthorizedException {
      try {
        final post = await _postsApi.getPost(postId);
        final postSaved = post['is_saved_by_me'] as bool?;
        if (postSaved != null) result = postSaved;
      } catch (_) {}
    } catch (_) {
      result = save;
    }
    await _updateLocalSaved(postId, result);
    return result;
  }

  /// Get users who liked a post.
  ///
  /// Returns a list of user objects: `{ id, _id, username, full_name, avatar_url }`.
  Future<List<Map<String, dynamic>>> getPostLikes(String postId) async {
    try {
      final res = await _postsApi.getLikes(postId);
      final users = res['users'] as List<dynamic>? ?? [];
      return users.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Ads & Products ─────────────────────────────────────────────────────────
  // These are not part of the new API docs. Keep stubs returning empty data.

  Future<List<Map<String, dynamic>>> fetchAds(
      {int limit = 20, int offset = 0}) async {
    return [];
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    return null;
  }

  // ── Users list ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchUsers(
      {String? excludeUserId, int limit = 100}) async {
    // Not available in the new REST API; provide a static fallback so StoriesRow
    // renders similarly to the web app's StoryRail.
    final samples = <Map<String, dynamic>>[
      {
        'id': 'u-your',
        'username': 'your_story',
        'avatar_url':
            'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-2',
        'username': 'jane_doe',
        'avatar_url':
            'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-3',
        'username': 'john_smith',
        'avatar_url':
            'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-4',
        'username': 'travel_lover',
        'avatar_url':
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-5',
        'username': 'foodie_life',
        'avatar_url':
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-6',
        'username': 'tech_guru',
        'avatar_url':
            'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&auto=format&fit=crop&q=60'
      },
      {
        'id': 'u-7',
        'username': 'art_daily',
        'avatar_url':
            'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&auto=format&fit=crop&q=60'
      },
    ];
    if (excludeUserId != null && excludeUserId.isNotEmpty) {
      return samples.where((u) => u['id'] != excludeUserId).take(limit).toList();
    }
    return samples.take(limit).toList();
  }

  Future<List<Map<String, dynamic>>> searchUsersByUsername(String query,
      {int limit = 20}) async {
    // Not available in the new REST API.
    return [];
  }

  // ── Wallet ─────────────────────────────────────────────────────────────────
  // Wallet endpoints are not defined in the new API docs yet.
  // Keeping Supabase-less stubs so the app compiles.

  Future<int> getCoinBalance(String userId) async {
    return 0;
  }

  Future<List<Map<String, dynamic>>> getTransactions(String userId,
      {int limit = 50}) async {
    return [];
  }

  Future<bool> rewardUserForAdView(
      String userId, String adId, int amount) async {
    return false;
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _postsApi.deletePost(postId);
      return true;
    } on ApiException catch (e) {
      throw e;
    } catch (e) {
      throw ServerException(message: e.toString());
    }
  }
}
