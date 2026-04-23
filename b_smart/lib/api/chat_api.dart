import 'dart:typed_data';

import 'api_client.dart';

/// REST API wrapper for `/chat` endpoints.
///
/// Mirrors the React web app:
/// - GET  /chat/conversations
/// - POST /chat/conversations { participantId }
/// - GET  /chat/conversations/:id/messages?page&limit
/// - POST /chat/conversations/:id/messages { text, mediaUrl, mediaType, replyTo }
/// - PUT  /chat/messages/:id/seen
/// - DELETE /chat/messages/:id
/// - POST /chat/conversations/:id/media (multipart, field `media`)
class ChatApi {
  static final ChatApi _instance = ChatApi._internal();
  factory ChatApi() => _instance;
  ChatApi._internal();

  final ApiClient _client = ApiClient();

  /// Fetch conversations for the logged-in user.
  ///
  /// Backend supports `type=normal|requests` (defaults to `normal`).
  Future<List<Map<String, dynamic>>> getConversations(
      {String type = 'normal'}) async {
    final t = type.trim().isEmpty ? 'normal' : type.trim();
    dynamic res;
    try {
      // Prefer explicit type for newer backends.
      res = await _client.get(
        '/chat/conversations',
        queryParams: {'type': t},
      );
    } catch (_) {
      // Some deployments reject/ignore the query param; fall back to the legacy
      // shape for the default "normal" inbox.
      if (t == 'normal') {
        res = await _client.get('/chat/conversations');
      } else {
        rethrow;
      }
    }
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (res is Map<String, dynamic>) {
      final data = res['data'];
      final list = res['conversations'] ??
          res['items'] ??
          (data is Map
              ? (data['conversations'] ?? data['items'] ?? data['data'])
              : null) ??
          data;
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const <Map<String, dynamic>>[];
  }

  /// Creates or returns an existing 1:1 conversation with `participantId`.
  Future<Map<String, dynamic>> createOrGetConversation({
    required String participantId,
  }) async {
    final res = await _client.post('/chat/conversations', body: {
      'participantId': participantId,
    });
    if (res is Map<String, dynamic>) {
      final conversation = res['conversation'];
      if (conversation is Map) return Map<String, dynamic>.from(conversation);
      return res;
    }
    return <String, dynamic>{};
  }

  /// Creates a new group conversation.
  ///
  /// Mirrors the web app endpoint: `POST /chat/groups`.
  Future<Map<String, dynamic>> createGroup({
    required List<String> participantIds,
    String? groupName,
    String? groupAvatar,
  }) async {
    final ids =
        participantIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) return <String, dynamic>{};
    final body = <String, dynamic>{'participantIds': ids};
    final name = groupName?.trim();
    if (name != null && name.isNotEmpty) body['groupName'] = name;
    final avatar = groupAvatar?.trim();
    if (avatar != null && avatar.isNotEmpty) body['groupAvatar'] = avatar;

    final res = await _client.post('/chat/groups', body: body);
    if (res is Map<String, dynamic>) {
      final conversation = res['conversation'] ?? res['group'] ?? res['data'];
      if (conversation is Map) return Map<String, dynamic>.from(conversation);
      return res;
    }
    return <String, dynamic>{};
  }

  /// Updates a group conversation's name or avatar.
  Future<Map<String, dynamic>> updateGroup({
    required String conversationId,
    String? groupName,
    String? groupAvatar,
  }) async {
    final id = conversationId.trim();
    if (id.isEmpty) return <String, dynamic>{};
    final body = <String, dynamic>{};
    final name = groupName?.trim();
    final avatar = groupAvatar?.trim();
    if (name != null && name.isNotEmpty) body['groupName'] = name;
    if (avatar != null && avatar.isNotEmpty) body['groupAvatar'] = avatar;
    if (body.isEmpty) return <String, dynamic>{};

    final res = await _client.patch('/chat/groups/$id', body: body);
    if (res is Map<String, dynamic>) {
      final conversation = res['conversation'] ?? res['group'] ?? res['data'];
      if (conversation is Map) return Map<String, dynamic>.from(conversation);
      return res;
    }
    return <String, dynamic>{};
  }

  /// Adds a member to a group conversation.
  Future<Map<String, dynamic>> addGroupMember({
    required String conversationId,
    required String userId,
  }) async {
    final cid = conversationId.trim();
    final uid = userId.trim();
    if (cid.isEmpty || uid.isEmpty) return <String, dynamic>{};
    final res =
        await _client.post('/chat/groups/$cid/members', body: {'userId': uid});
    if (res is Map<String, dynamic>) {
      final conversation = res['conversation'] ?? res['group'] ?? res['data'];
      if (conversation is Map) return Map<String, dynamic>.from(conversation);
      return res;
    }
    return <String, dynamic>{};
  }

  /// Removes a member from a group conversation (or leaves the group).
  Future<Map<String, dynamic>> removeGroupMember({
    required String conversationId,
    required String userId,
  }) async {
    final cid = conversationId.trim();
    final uid = userId.trim();
    if (cid.isEmpty || uid.isEmpty) return <String, dynamic>{};
    final res = await _client.delete('/chat/groups/$cid/members/$uid');
    if (res is Map<String, dynamic>) {
      final conversation = res['conversation'] ?? res['group'] ?? res['data'];
      if (conversation is Map) return Map<String, dynamic>.from(conversation);
      return res;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getMessages({
    required String conversationId,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _client.get(
      '/chat/conversations/$conversationId/messages',
      queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    if (res is Map<String, dynamic>) {
      final data = res['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return res;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _client.post(
      '/chat/conversations/$conversationId/messages',
      body: payload,
    );
    if (res is Map<String, dynamic>) {
      final message = res['message'];
      if (message is Map) return Map<String, dynamic>.from(message);
      final data = res['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return res;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> markMessageSeen(
      {required String messageId}) async {
    final res = await _client.put('/chat/messages/$messageId/seen');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> deleteMessage(
      {required String messageId}) async {
    final res = await _client.delete('/chat/messages/$messageId');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadChatMedia({
    required String conversationId,
    required String filePath,
  }) async {
    final res = await _client.multipartPost(
      '/chat/conversations/$conversationId/media',
      filePath: filePath,
      fileField: 'media',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadChatMediaManyBytes({
    required String conversationId,
    required List<MultipartBytesFile> files,
  }) async {
    final res = await _client.multipartPostManyBytes(
      '/chat/conversations/$conversationId/media',
      files: files,
      fileField: 'media',
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadVoiceMessage({
    required String conversationId,
    required Uint8List audioBytes,
    required int durationSeconds,
    String filename = 'voice-message.aac',
    String? replyTo,
  }) async {
    final extra = <String, String>{
      'duration': durationSeconds.toString(),
    };
    final trimmedReply = replyTo?.toString().trim();
    if (trimmedReply != null && trimmedReply.isNotEmpty) {
      extra['replyTo'] = trimmedReply;
    }
    final res = await _client.multipartPostBytes(
      '/chat/conversations/$conversationId/voice',
      bytes: audioBytes,
      filename: filename,
      fileField: 'audio',
      extraFields: extra,
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  /// Best-effort (backend-dependent) reaction support.
  Future<Map<String, dynamic>> addMessageReaction({
    required String messageId,
    required String emoji,
  }) async {
    final e = emoji.trim();
    if (e.isEmpty) return <String, dynamic>{};
    final res = await _client.post(
      '/chat/messages/$messageId/reaction',
      body: {'emoji': e},
    );
    if (res is Map<String, dynamic>) {
      final msg = res['message'];
      if (msg is Map) return Map<String, dynamic>.from(msg);
      final data = res['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return res;
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> removeMessageReaction({
    required String messageId,
  }) async {
    final res = await _client.delete('/chat/messages/$messageId/reaction');
    if (res is Map<String, dynamic>) {
      final msg = res['message'];
      if (msg is Map) return Map<String, dynamic>.from(msg);
      final data = res['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return res;
    }
    return <String, dynamic>{};
  }

  /// Returns online user IDs.
  ///
  /// Endpoint: `GET /api/chat/online-users`
  /// Optional query param: `ids=<comma-separated-ids>`
  Future<List<String>> getOnlineUsers({List<String>? ids}) async {
    final normalizedIds = (ids ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final queryParams = normalizedIds.isEmpty
        ? null
        : <String, String>{'ids': normalizedIds.join(',')};

    final res = await _client.get(
      '/chat/online-users',
      queryParams: queryParams,
    );

    dynamic list;
    if (res is Map<String, dynamic>) {
      final data = res['data'];
      list = res['onlineUserIds'] ??
          res['online_user_ids'] ??
          res['onlineUsers'] ??
          res['online_users'] ??
          res['users'] ??
          res['items'] ??
          (data is Map
              ? (data['onlineUserIds'] ??
                  data['online_user_ids'] ??
                  data['onlineUsers'] ??
                  data['online_users'] ??
                  data['users'] ??
                  data['items'])
              : null) ??
          data;
    } else {
      list = res;
    }

    if (list is! List) return const <String>[];

    final seen = <String>{};
    final out = <String>[];
    for (final e in list) {
      final id = e?.toString().trim() ?? '';
      if (id.isEmpty) continue;
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  /// Share a post/reel/ad/tweet to chat recipients (web parity).
  ///
  /// POST /chat/share
  /// Body: { recipientIds: [], conversationIds: [], contentType, contentId }
  Future<Map<String, dynamic>> shareContentToUsers({
    required String contentType,
    required String contentId,
    List<String> recipientIds = const <String>[],
    List<String> conversationIds = const <String>[],
  }) async {
    final type = contentType.trim();
    final id = contentId.trim();
    if (type.isEmpty || id.isEmpty) return <String, dynamic>{};

    final recipients = recipientIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final conversations = conversationIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final res = await _client.post(
      '/chat/share',
      body: <String, dynamic>{
        'recipientIds': recipients,
        'conversationIds': conversations,
        'contentType': type,
        'contentId': id,
      },
    );
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  /// Accepts a pending message request conversation.
  ///
  /// Backend implementations differ; try a few common routes/methods.
  Future<Map<String, dynamic>> acceptConversationRequest({
    required String conversationId,
  }) async {
    final id = conversationId.trim();
    if (id.isEmpty) return <String, dynamic>{};

    Object? lastError;
    final attempts = <Future<dynamic> Function()>[
      () => _client.post('/chat/conversations/$id/accept'),
      () => _client.patch('/chat/conversations/$id/accept'),
      () => _client.put('/chat/conversations/$id/accept'),
      () => _client.post('/chat/conversations/$id/approve'),
      () => _client.patch('/chat/conversations/$id/approve'),
      () => _client.put('/chat/conversations/$id/approve'),
      () => _client.post('/chat/conversations/$id/request/accept'),
      () => _client.patch('/chat/conversations/$id/request/accept'),
      () => _client.put('/chat/conversations/$id/request/accept'),
    ];

    for (final attempt in attempts) {
      try {
        final res = await attempt();
        return res is Map<String, dynamic> ? res : <String, dynamic>{};
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
    return <String, dynamic>{};
  }

  /// Deletes a conversation (used for declining/deleting message requests).
  ///
  /// Backend implementations differ; try a few common routes/methods.
  Future<Map<String, dynamic>> deleteConversation({
    required String conversationId,
  }) async {
    final id = conversationId.trim();
    if (id.isEmpty) return <String, dynamic>{};

    Object? lastError;
    final attempts = <Future<dynamic> Function()>[
      () => _client.delete('/chat/conversations/$id'),
      () => _client.delete('/chat/conversations/$id/delete'),
      () => _client.delete('/chat/conversations/$id/request'),
      () => _client.post('/chat/conversations/$id/delete'),
      () => _client.post('/chat/conversations/$id/request/delete'),
    ];

    for (final attempt in attempts) {
      try {
        final res = await attempt();
        return res is Map<String, dynamic> ? res : <String, dynamic>{};
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) throw lastError;
    return <String, dynamic>{};
  }
}
