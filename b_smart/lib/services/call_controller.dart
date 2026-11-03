import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';

import '../api/api_client.dart';
import '../utils/current_user.dart';
import 'call_media.dart';
import 'call_service.dart';
import 'chat_socket_service.dart';
import 'group_call_controller.dart';

enum CallStatus { idle, outgoingRinging, incomingRinging, connecting, active }

class CallPeer {
  const CallPeer({required this.id, required this.name, this.avatar});
  final String id;
  final String name;
  final String? avatar;
}

/// App-wide 1:1 call coordinator. It mirrors the React CallOverlay flow and
/// keeps Cloudflare media negotiation separate from Socket.io signalling.
class CallController extends ChangeNotifier {
  static final CallController instance = CallController._();
  CallController._();

  final CallService _calls = CallService();
  final ChatSocketService _socket = ChatSocketService();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  Timer? _timer;
  bool _published = false;
  bool _pulled = false;
  bool _ready = false;
  bool _initializing = false;

  CallStatus status = CallStatus.idle;
  String? callId;
  CallPeer? peer;
  String? error;
  int elapsedSeconds = 0;
  bool muted = false;
  String callType = 'voice';
  bool cameraOff = false;
  bool speakerOn = false;
  bool hasRemoteVideo = false;

  /// Compact floating-widget mode (vs full-screen call UI).
  bool minimized = false;

  bool get isVideo => callType == 'video';
  bool get isBusy => status != CallStatus.idle;

  Future<void> initialize() async {
    if (_ready || _initializing) return;
    _initializing = true;
    try {
      await remoteRenderer.initialize();
      await localRenderer.initialize();
      final token = await ApiClient().getToken();
      if (token == null || token.isEmpty) return;
      _socket.connect(token: token, userId: await CurrentUser.id);
      _socket.on('call:ringing', _onRinging);
      _socket.on('call:accepted', _onAccepted);
      _socket.on('call:rejected', _onEnded);
      _socket.on('call:ended', _onEnded);
      _socket.on('call:missed', _onEnded);
      _socket.on('call:peer-ready', _onPeerReady);
      _socket.on('call:escalated', _onEscalated);
      _ready = true;
    } finally {
      _initializing = false;
    }
  }

  Future<void> start(
      {required CallPeer peer, String callType = 'voice'}) async {
    await initialize();
    if (isBusy || GroupCallController.instance.isBusy) {
      error = 'You are already in a call.';
      notifyListeners();
      return;
    }
    error = null;
    _calls.initiate(peer.id, callType, (ack) {
      final id = ack['callId']?.toString();
      final ackStatus = ack['status']?.toString();
      if (id == null || id.isEmpty || ack['error'] != null) {
        error = ack['error']?.toString() ?? 'Could not start call.';
      } else if (ackStatus == 'busy') {
        error = '${peer.name} is on another call.';
      } else {
        callId = id;
        this.peer = peer;
        this.callType = callType;
        speakerOn = callType == 'video';
        minimized = false;
        status = CallStatus.outgoingRinging;
        if (callType == 'video') unawaited(_startLocalPreview());
      }
      notifyListeners();
    });
  }

  /// Used by Android FCM data pushes while the app is foregrounded. Killed-app
  /// CallKit/PushKit presentation remains native-platform responsibility.
  Future<void> receiveIncomingPush(Map<String, dynamic> data) async {
    await initialize();
    final id = data['callId']?.toString() ?? data['call_id']?.toString() ?? '';
    final video = (data['callType'] ?? data['call_type'])?.toString() == 'video';
    if (id.isNotEmpty) {
      await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
        id: id,
        nameCaller: data['callerName']?.toString() ?? 'B Smart caller',
        appName: 'B Smart',
        avatar: data['callerAvatar']?.toString(),
        handle: data['callerId']?.toString() ?? '',
        type: video ? 1 : 0,
        duration: 45000,
        extra: Map<String, dynamic>.from(data),
        android: const AndroidParams(
            isCustomNotification: true,
            incomingCallNotificationChannelName: 'Incoming calls',
            missedCallNotificationChannelName: 'Missed calls'),
        ios: IOSParams(
            iconName: 'CallKitLogo',
            handleType: 'generic',
            supportsVideo: video),
      ));
    }
    _onRinging(data);
  }

  void _onRinging(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final id = map['callId']?.toString();
    if (id == null || id.isEmpty) return;
    // Already on a call (1:1 or group): let it ring out to missed.
    if ((isBusy && id != callId) || GroupCallController.instance.isBusy) return;
    callId = id;
    peer = CallPeer(
      id: map['callerId']?.toString() ?? '',
      name: map['callerName']?.toString() ?? 'Unknown',
      avatar: map['callerAvatar']?.toString(),
    );
    callType = map['callType']?.toString() == 'video' ? 'video' : 'voice';
    speakerOn = isVideo;
    minimized = false;
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

  Future<void> _startLocalPreview() async {
    if (_localStream != null) return;
    try {
      _localStream = await CallMedia.getLocalStream(video: isVideo);
      localRenderer.srcObject = _localStream;
      notifyListeners();
    } catch (_) {
      // Permission errors surface again (with a message) in _beginMedia.
    }
  }

  Future<void> _beginMedia() async {
    final id = callId;
    if (id == null || _pc != null) return;
    try {
      _localStream ??= await CallMedia.getLocalStream(video: isVideo);
      if (isVideo) localRenderer.srcObject = _localStream;
      await Helper.setSpeakerphoneOn(speakerOn);
      final pc = await createPeerConnection(CallMedia.rtcConfig);
      _pc = pc;
      pc.onTrack = _onTrack;
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
      final sdp = await CallMedia.createLocalOffer(pc);
      final response = await _calls.publish(
        callId: id,
        sdpOffer: sdp,
        tracks: await CallMedia.localTracks(pc),
      );
      final answer = response['sdpAnswer']?.toString();
      if (answer == null || answer.isEmpty)
        throw StateError('No media answer received.');
      await pc.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
      _published = true;
      _calls.trackPublished(id);
    } catch (e) {
      error = 'Could not connect ${isVideo ? 'video' : 'audio'}: $e';
      notifyListeners();
      end(reason: 'media_error');
    }
  }

  void _onTrack(RTCTrackEvent event) {
    // Audio plays natively; video needs a renderer. Route by track kind.
    if (event.track.kind == 'video') {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
      }
      hasRemoteVideo = true;
    } else if (remoteRenderer.srcObject == null && event.streams.isNotEmpty) {
      remoteRenderer.srcObject = event.streams.first;
    }
    status = CallStatus.active;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
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
        final sdp =
            await CallMedia.answerOffer(pc, response['sdpOffer'].toString());
        await _calls.renegotiate(callId: id, sdpAnswer: sdp);
      }
    } catch (e) {
      error = 'Could not connect remote media: $e';
      notifyListeners();
    }
  }

  /// Escalates this live 1:1 call into a group call with [userIds] invited.
  void addPeople(List<String> userIds) {
    final id = callId;
    if (id == null || userIds.isEmpty) return;
    _calls.escalateToGroup(id, userIds, (ack) {
      if (ack['error'] != null) {
        error = ack['error'].toString();
        notifyListeners();
      }
      // Success is handled by the `call:escalated` event both sides receive.
    });
  }

  void _onEscalated(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    if (map['oldCallId']?.toString() != callId) return;
    final groupCallId = map['groupCallId']?.toString();
    final type = map['callType']?.toString() ?? callType;
    final previousPeer = peer;
    // The server already ended the CallLog, so tear down without call:end.
    unawaited(_reset().then((_) {
      if (groupCallId == null || groupCallId.isEmpty) return;
      GroupCallController.instance.enterEscalated(
        groupCallId: groupCallId,
        callType: type,
        knownPeer: previousPeer,
      );
    }));
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

  void _onEnded(dynamic data) {
    if (data is Map &&
        data['callId'] != null &&
        data['callId'].toString() != callId) return;
    _reset();
  }

  void toggleMute() {
    muted = !muted;
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    notifyListeners();
  }

  void toggleCamera() {
    cameraOff = !cameraOff;
    for (final track
        in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !cameraOff;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    await Helper.setSpeakerphoneOn(speakerOn);
    notifyListeners();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  void setMinimized(bool value) {
    if (minimized == value) return;
    minimized = value;
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
    await _localStream?.dispose();
    _localStream = null;
    remoteRenderer.srcObject = null;
    localRenderer.srcObject = null;
    _published = false;
    _pulled = false;
    muted = false;
    cameraOff = false;
    speakerOn = false;
    hasRemoteVideo = false;
    minimized = false;
    callType = 'voice';
    status = CallStatus.idle;
    callId = null;
    peer = null;
    error = null;
    notifyListeners();
  }
}
