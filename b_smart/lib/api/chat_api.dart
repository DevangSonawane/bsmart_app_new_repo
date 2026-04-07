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

  Future<List<Map<String, dynamic>>> getConversations() async {
    final res = await _client.get('/chat/conversations');
    if (res is List) {
      return res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (res is Map<String, dynamic>) {
      final list = res['conversations'] ?? res['items'] ?? res['data'];
      if (list is List) {
        return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
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

  Future<Map<String, dynamic>> markMessageSeen({required String messageId}) async {
    final res = await _client.put('/chat/messages/$messageId/seen');
    return res is Map<String, dynamic> ? res : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> deleteMessage({required String messageId}) async {
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
}
