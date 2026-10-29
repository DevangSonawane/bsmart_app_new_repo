import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';

import '../api/api_client.dart';
import '../utils/current_user.dart';
import 'call_service.dart';
import 'chat_socket_service.dart';

enum CallStatus { idle, outgoingRinging, incomingRinging, connecting, active }

class CallPeer {
  const CallPeer({required this.id, required this.name, this.avatar});
  final String id;
  final String name;
  final String? avatar;
}

/// App-wide call coordinator. It mirrors the React CallOverlay flow and keeps
/// Cloudflare media negotiation separate from Socket.io signalling.
class CallController extends ChangeNotifier {
  static final CallController instance = CallController._();
  CallController._();

  final CallService _calls = CallService();
  final ChatSocketService _socket = ChatSocketService();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  Timer? _timer;
  bool _published = false;
  bool _pulled = false;
  bool _ready = false;

  CallStatus status = CallStatus.idle;
  String? callId;
  CallPeer? peer;
  String? error;
  int elapsedSeconds = 0;
  bool muted = false;

  Future<void> initialize() async {
    if (_ready) return;
    await remoteRenderer.initialize();
    final token = await ApiClient().getToken();
    if (token == null || token.isEmpty) return;
    _socket.connect(token: token, userId: await CurrentUser.id);
    _socket.on('call:ringing', _onRinging);
    _socket.on('call:accepted', _onAccepted);
    _socket.on('call:rejected', _onEnded);
    _socket.on('call:ended', _onEnded);
    _socket.on('call:missed', _onEnded);
    _socket.on('call:peer-ready', _onPeerReady);
    _ready = true;
  }

  Future<void> start(
      {required CallPeer peer, String callType = 'voice'}) async {
    await initialize();
    error = null;
    _calls.initiate(peer.id, callType, (ack) {
      final id = ack['callId']?.toString();
      if (id == null || id.isEmpty) {
        error = ack['error']?.toString() ?? 'Could not start call.';
      } else {
        callId = id;
        this.peer = peer;
        status = CallStatus.outgoingRinging;
      }
      notifyListeners();
    });
  }

  /// Used by Android FCM data pushes while the app is foregrounded. Killed-app
  /// CallKit/PushKit presentation remains native-platform responsibility.
  Future<void> receiveIncomingPush(Map<String, dynamic> data) async {
    await initialize();
    final id = data['callId']?.toString() ?? data['call_id']?.toString() ?? '';
    if (id.isNotEmpty) {
      await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
        id: id,
        nameCaller: data['callerName']?.toString() ?? 'B Smart caller',
        appName: 'B Smart',
        avatar: data['callerAvatar']?.toString(),
        handle: data['callerId']?.toString() ?? '',
        type: 0,
        duration: 45000,
        extra: Map<String, dynamic>.from(data),
        android: const AndroidParams(
            isCustomNotification: true,
            incomingCallNotificationChannelName: 'Incoming calls',
            missedCallNotificationChannelName: 'Missed calls'),
        ios: const IOSParams(
            iconName: 'CallKitLogo',
            handleType: 'generic',
            supportsVideo: false),
      ));
    }
    _onRinging(data);
  }

  void _onRinging(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    callId = map['callId']?.toString();
    peer = CallPeer(
      id: map['callerId']?.toString() ?? '',
      name: map['callerName']?.toString() ?? 'Unknown',
      avatar: map['callerAvatar']?.toString(),
    );
    status = CallStatus.incomingRinging;
    error = null;
    notifyListeners();
  }

  void _onAccepted(dynamic data) {
    if (data is! Map || data['callId']?.toString() != callId) return;
    status = CallStatus.connecting;
    notifyListeners();
    unawaited(_beginMedia());
  }

  Future<void> accept() async {
    final id = callId;
    if (id == null) return;
    _calls.accept(id, (ack) {
      if (ack['error'] != null) {
        error = ack['error'].toString();
        notifyListeners();
        return;
      }
      status = CallStatus.connecting;
      notifyListeners();
      unawaited(_beginMedia());
    });
  }

  Future<void> _beginMedia() async {
    final id = callId;
    if (id == null || _pc != null) return;
    try {
      _localStream = await navigator.mediaDevices
          .getUserMedia({'audio': true, 'video': false});
      _pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.cloudflare.com:3478'},
        ],
      });
      _pc!.onTrack = (event) {
        if (event.streams.isNotEmpty)
          remoteRenderer.srcObject = event.streams.first;
        status = CallStatus.active;
        _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
          elapsedSeconds++;
          notifyListeners();
        });
        notifyListeners();
      };
      for (final track in _localStream!.getAudioTracks()) {
        await _pc!.addTrack(track, _localStream!);
      }
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      await _waitForIce();
      final localDescription = await _pc!.getLocalDescription();
      final response = await _calls.publish(
        callId: id,
        sdpOffer: localDescription!.sdp!,
        mid: '0',
      );
      final answer = response['sdpAnswer']?.toString();
      if (answer == null || answer.isEmpty)
        throw StateError('No media answer received.');
      await _pc!.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
      _published = true;
      _calls.trackPublished(id);
    } catch (e) {
      error = 'Could not connect audio: $e';
      notifyListeners();
      end(reason: 'media_error');
    }
  }

  Future<void> _waitForIce() async {
    final pc = _pc;
    if (pc == null ||
        pc.iceGatheringState ==
            RTCIceGatheringState.RTCIceGatheringStateComplete) return;
    final done = Completer<void>();
    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !done.isCompleted) done.complete();
    };
    await Future.any(
        [done.future, Future<void>.delayed(const Duration(seconds: 3))]);
  }

  void _onPeerReady(dynamic data) {
    if (data is! Map ||
        data['callId']?.toString() != callId ||
        _pulled ||
        !_published) return;
    _pulled = true;
    unawaited(_pull());
  }

  Future<void> _pull() async {
    final id = callId;
    final pc = _pc;
    if (id == null || pc == null) return;
    try {
      final response = await _calls.pull(id);
      if (response['requiresImmediateRenegotiation'] == true &&
          response['sdpOffer'] != null) {
        await pc.setRemoteDescription(
            RTCSessionDescription(response['sdpOffer'].toString(), 'offer'));
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await _waitForIce();
        final localDescription = await pc.getLocalDescription();
        await _calls.renegotiate(callId: id, sdpAnswer: localDescription!.sdp!);
      }
    } catch (e) {
      error = 'Could not connect remote audio: $e';
      notifyListeners();
    }
  }

  void reject() {
    final id = callId;
    if (id != null) _calls.reject(id);
    _reset();
  }

  void end({String reason = 'hang up'}) {
    final id = callId;
    if (id != null) _calls.end(id, reason: reason);
    _reset();
  }

  void _onEnded(dynamic _) => _reset();
  void toggleMute() {
    muted = !muted;
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    notifyListeners();
  }

  Future<void> _reset() async {
    _timer?.cancel();
    _timer = null;
    elapsedSeconds = 0;
    await _pc?.close();
    _pc = null;
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    _localStream = null;
    remoteRenderer.srcObject = null;
    _published = false;
    _pulled = false;
    muted = false;
    status = CallStatus.idle;
    callId = null;
    peer = null;
    error = null;
    notifyListeners();
  }
}
