import '../api/api_client.dart';
import 'chat_socket_service.dart';

/// Backend contract for call history, permission and Cloudflare SDP exchange.
/// UI/WebRTC code can use this without ever exposing the Cloudflare app token.
class CallService {
  CallService({ApiClient? client, ChatSocketService? socket})
      : _client = client ?? ApiClient(),
        _socket = socket ?? ChatSocketService();

  final ApiClient _client;
  final ChatSocketService _socket;

  Future<bool> canCall(String userId) async {
    final data = await _client.get('/calls/can-call/$userId');
    return data is Map && data['can_call'] == true;
  }

  Future<Map<String, dynamic>> history({int page = 1, int limit = 20}) async {
    final data = await _client.get('/calls', queryParams: {
      'page': '$page',
      'limit': '$limit',
    });
    return _map(data);
  }

  Future<Map<String, dynamic>> detail(String callId) async =>
      _map(await _client.get('/calls/$callId'));

  /// [tracks] is one `{mid, kind}` entry per local transceiver — one for a
  /// voice call, two (audio + video) for a video call.
  Future<Map<String, dynamic>> publish({
    required String callId,
    required String sdpOffer,
    required List<Map<String, String>> tracks,
  }) async =>
      _map(await _client.post('/calls/$callId/webrtc/publish', body: {
        'sdpOffer': sdpOffer,
        'tracks': tracks,
      }));

  Future<Map<String, dynamic>> pull(String callId) async =>
      _map(await _client.post('/calls/$callId/webrtc/pull'));

  Future<Map<String, dynamic>> renegotiate({
    required String callId,
    required String sdpAnswer,
  }) async =>
      _map(await _client.put('/calls/$callId/webrtc/renegotiate', body: {
        'sdpAnswer': sdpAnswer,
      }));

  void initiate(String receiverId, String callType,
      void Function(Map<String, dynamic>) onAck) {
    _socket.emitCall(
        'call:initiate',
        {
          'receiverId': receiverId,
          'callType': callType,
        },
        ack: (data) => onAck(_map(data)));
  }

  void accept(String callId, void Function(Map<String, dynamic>) onAck) =>
      _socket.emitCall('call:accept', {'callId': callId},
          ack: (data) => onAck(_map(data)));
  void reject(String callId, {String reason = 'rejected'}) =>
      _socket.emitCall('call:reject', {'callId': callId, 'reason': reason});
  void end(String callId, {String reason = 'hang up'}) =>
      _socket.emitCall('call:end', {'callId': callId, 'reason': reason});
  void trackPublished(String callId) =>
      _socket.emitCall('call:track-published', {'callId': callId});

  /// Turns a live 1:1 call into a group call with [userIds] invited. Both
  /// original parties then receive `call:escalated`.
  void escalateToGroup(String callId, List<String> userIds,
          void Function(Map<String, dynamic>) onAck) =>
      _socket.emitCall(
          'call:escalate-to-group', {'callId': callId, 'userIds': userIds},
          ack: (data) => onAck(_map(data)));

  static Map<String, dynamic> _map(dynamic data) {
    if (data is List && data.isNotEmpty) data = data.first;
    return data is Map
      ? data.map((key, value) => MapEntry(key.toString(), value))
      : <String, dynamic>{};
  }
}
