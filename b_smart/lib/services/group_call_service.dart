import '../api/api_client.dart';
import 'chat_socket_service.dart';

/// Backend contract for group calls (`/api/group-calls` + `group-call:*`
/// socket events). Same shapes as [CallService] except pull is per-peer.
class GroupCallService {
  GroupCallService({ApiClient? client, ChatSocketService? socket})
      : _client = client ?? ApiClient(),
        _socket = socket ?? ChatSocketService();

  final ApiClient _client;
  final ChatSocketService _socket;

  Future<Map<String, dynamic>> history({int page = 1, int limit = 20}) async {
    final data = await _client.get('/group-calls', queryParams: {
      'page': '$page',
      'limit': '$limit',
    });
    return _map(data);
  }

  Future<Map<String, dynamic>> publish({
    required String groupCallId,
    required String sdpOffer,
    required List<Map<String, String>> tracks,
  }) async =>
      _map(await _client
          .post('/group-calls/$groupCallId/webrtc/publish', body: {
        'sdpOffer': sdpOffer,
        'tracks': tracks,
      }));

  /// Pulls exactly one peer's tracks.
  Future<Map<String, dynamic>> pull({
    required String groupCallId,
    required String fromUserId,
  }) async =>
      _map(await _client.post('/group-calls/$groupCallId/webrtc/pull',
          body: {'fromUserId': fromUserId}));

  Future<Map<String, dynamic>> renegotiate({
    required String groupCallId,
    required String sdpAnswer,
  }) async =>
      _map(await _client
          .put('/group-calls/$groupCallId/webrtc/renegotiate', body: {
        'sdpAnswer': sdpAnswer,
      }));

  void initiate(String conversationId, String callType,
          void Function(Map<String, dynamic>) onAck) =>
      _socket.emitCall('group-call:initiate',
          {'conversationId': conversationId, 'callType': callType},
          ack: (data) => onAck(_map(data)));

  void join(String groupCallId, void Function(Map<String, dynamic>) onAck) =>
      _socket.emitCall('group-call:join', {'groupCallId': groupCallId},
          ack: (data) => onAck(_map(data)));

  void decline(String groupCallId) =>
      _socket.emitCall('group-call:decline', {'groupCallId': groupCallId});

  void leave(String groupCallId, {String reason = 'left'}) => _socket.emitCall(
      'group-call:leave', {'groupCallId': groupCallId, 'reason': reason});

  void trackPublished(String groupCallId) => _socket.emitCall(
      'group-call:track-published', {'groupCallId': groupCallId});

  void invite(String groupCallId, List<String> userIds,
          void Function(Map<String, dynamic>) onAck) =>
      _socket.emitCall('group-call:invite',
          {'groupCallId': groupCallId, 'userIds': userIds},
          ack: (data) => onAck(_map(data)));

  static Map<String, dynamic> _map(dynamic data) {
    if (data is List && data.isNotEmpty) data = data.first;
    return data is Map
        ? data.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
  }
}
