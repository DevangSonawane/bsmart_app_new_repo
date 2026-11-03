import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../api/api_client.dart';
import '../utils/current_user.dart';
import 'call_controller.dart';
import 'call_media.dart';
import 'chat_socket_service.dart';
import 'group_call_service.dart';

enum GroupCallStatus { idle, incomingRinging, joining, active }

class GroupCallParticipant {
  GroupCallParticipant({required this.userId, required this.name, this.avatar});
  final String userId;
  String name;
  String? avatar;
  RTCVideoRenderer? renderer;
  bool hasVideo = false;
  bool hasAudio = false;
}

/// App-wide group call coordinator (mirrors the React GroupCallOverlay).
/// Each participant publishes into their own Cloudflare session and pulls
/// every other participant's tracks one peer at a time.
class GroupCallController extends ChangeNotifier {
  static final GroupCallController instance = GroupCallController._();
  GroupCallController._();

  final GroupCallService _calls = GroupCallService();
  final ChatSocketService _socket = ChatSocketService();
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  Timer? _timer;
  bool _ready = false;
  bool _initializing = false;
  bool _published = false;
  String? _selfId;

  /// Pulls run strictly one after another so an `onTrack` can be attributed
  /// to whichever peer is currently being pulled (Cloudflare doesn't label
  /// pulled tracks with their origin).
  Future<void> _pullChain = Future<void>.value();
  String? _pullingFrom;
  final Set<String> _pulledFrom = <String>{};
  final Set<String> _pendingPeers = <String>{};

  GroupCallStatus status = GroupCallStatus.idle;
  String? groupCallId;
  String? conversationId;
  String title = 'Group call';
  String? avatar;
  String? initiatorName;
  String callType = 'voice';
  String? error;
  int elapsedSeconds = 0;
  bool muted = false;
  bool cameraOff = false;
  bool speakerOn = true;

  /// Compact floating-widget mode (vs full-screen call UI).
  bool minimized = false;
  final Map<String, GroupCallParticipant> participants =
      <String, GroupCallParticipant>{};

  bool get isVideo => callType == 'video';
  bool get isBusy => status != GroupCallStatus.idle;

  Future<void> initialize() async {
    if (_ready || _initializing) return;
    _initializing = true;
    try {
      await localRenderer.initialize();
      final token = await ApiClient().getToken();
      if (token == null || token.isEmpty) return;
      _selfId = await CurrentUser.id;
      _socket.connect(token: token, userId: _selfId);
      _socket.on('group-call:ringing', _onRinging);
      _socket.on('group-call:participant-joined', _onParticipantJoined);
      _socket.on('group-call:participant-left', _onParticipantLeft);
      _socket.on('group-call:peer-ready', _onPeerReady);
      _socket.on('group-call:missed', _onMissed);
      _ready = true;
    } finally {
      _initializing = false;
    }
  }

  /// Starts a call in a group conversation, or joins it if one is live.
  Future<void> start({
    required String conversationId,
    String callType = 'voice',
    String? title,
    String? avatar,
  }) async {
    await initialize();
    if (isBusy || CallController.instance.isBusy) {
      error = 'You are already in a call.';
      notifyListeners();
      return;
    }
    error = null;
    status = GroupCallStatus.joining;
    this.conversationId = conversationId;
    this.callType = callType;
    this.title = title ?? 'Group call';
    this.avatar = avatar;
    notifyListeners();
    _calls.initiate(conversationId, callType, (ack) {
      final id = ack['groupCallId']?.toString();
      if (id == null || id.isEmpty || ack['error'] != null) {
        final message = ack['error']?.toString() ?? 'Could not start call.';
        unawaited(_reset().then((_) {
          error = message;
          notifyListeners();
        }));
        return;
      }
      groupCallId = id;
      this.callType = ack['callType']?.toString() ?? callType;
      this.title = _nonEmpty(ack['conversationTitle']) ?? this.title;
      this.avatar = _nonEmpty(ack['conversationAvatar']) ?? this.avatar;
      _applyRoster(ack['roster']);
      _enterActive();
    });
  }

  /// Entered directly after a 1:1 call was escalated — both original parties
  /// are already `joined` server-side, so skip ring/join and just publish.
  void enterEscalated({
    required String groupCallId,
    required String callType,
    CallPeer? knownPeer,
  }) {
    unawaited(initialize());
    this.groupCallId = groupCallId;
    this.callType = callType;
    conversationId = null;
    title = 'Group call';
    avatar = null;
    error = null;
    if (knownPeer != null && knownPeer.id.isNotEmpty) {
      participants[knownPeer.id] = GroupCallParticipant(
          userId: knownPeer.id, name: knownPeer.name, avatar: knownPeer.avatar);
    }
    _enterActive();
  }

  void _onRinging(dynamic data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final id = map['groupCallId']?.toString();
    if (id == null || id.isEmpty) return;
    if (isBusy || CallController.instance.isBusy) return;
    groupCallId = id;
    conversationId = map['conversationId']?.toString();
    title = _nonEmpty(map['conversationTitle']) ?? 'Group call';
    avatar = _nonEmpty(map['conversationAvatar']) ??
        _nonEmpty(map['initiatorAvatar']);
    initiatorName = _nonEmpty(map['initiatorName']);
    callType = map['callType']?.toString() == 'video' ? 'video' : 'voice';
    error = null;
    status = GroupCallStatus.incomingRinging;
    notifyListeners();
  }

  /// Used by FCM data pushes for group-call invites while foregrounded.
  Future<void> receiveIncomingPush(Map<String, dynamic> data) async {
    await initialize();
    _onRinging(data);
  }

  void accept() {
    final id = groupCallId;
    if (id == null) return;
    status = GroupCallStatus.joining;
    notifyListeners();
    _calls.join(id, (ack) {
      if (ack['error'] != null) {
        final message = ack['error'].toString();
        unawaited(_reset().then((_) {
          error = message;
          notifyListeners();
        }));
        return;
      }
      _applyRoster(ack['roster']);
      _enterActive();
    });
  }

  void decline() {
    final id = groupCallId;
    if (id != null) _calls.decline(id);
    unawaited(_reset());
  }

  void leave({String reason = 'left'}) {
    final id = groupCallId;
    if (id != null) _calls.leave(id, reason: reason);
    unawaited(_reset());
  }

  void invite(List<String> userIds) {
    final id = groupCallId;
    if (id == null || userIds.isEmpty) return;
    _calls.invite(id, userIds, (ack) {
      if (ack['error'] != null) {
        error = ack['error'].toString();
        notifyListeners();
      }
    });
  }

  void _enterActive() {
    status = GroupCallStatus.active;
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds++;
      notifyListeners();
    });
    notifyListeners();
    unawaited(_beginMedia());
  }

  void _applyRoster(dynamic roster) {
    if (roster is! List) return;
    for (final entry in roster.whereType<Map>()) {
      final userId = entry['userId']?.toString() ?? '';
      if (userId.isEmpty || userId == _selfId) continue;
      _upsert(userId, entry['name']?.toString(), entry['avatar']?.toString());
      _pendingPeers.add(userId);
    }
  }

  GroupCallParticipant _upsert(String userId, String? name, String? avatar) {
    final existing = participants[userId];
    if (existing != null) {
      if (_nonEmpty(name) != null) existing.name = name!;
      if (_nonEmpty(avatar) != null) existing.avatar = avatar;
      return existing;
    }
    return participants[userId] = GroupCallParticipant(
        userId: userId, name: _nonEmpty(name) ?? 'Participant', avatar: avatar);
  }

  Future<void> _beginMedia() async {
    final id = groupCallId;
    if (id == null || _pc != null) return;
    try {
      _selfId ??= await CurrentUser.id;
      _localStream = await CallMedia.getLocalStream(video: isVideo);
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
        groupCallId: id,
        sdpOffer: sdp,
        tracks: await CallMedia.localTracks(pc),
      );
      final answer = response['sdpAnswer']?.toString();
      if (answer == null || answer.isEmpty)
        throw StateError('No media answer received.');
      await pc.setRemoteDescription(RTCSessionDescription(answer, 'answer'));
      if (groupCallId != id) return;
      _published = true;
      _calls.trackPublished(id);
      final pending = List<String>.from(_pendingPeers);
      _pendingPeers.clear();
      pending.forEach(_enqueuePull);
    } catch (e) {
      error = 'Could not connect ${isVideo ? 'video' : 'audio'}: $e';
      notifyListeners();
      leave(reason: 'media_error');
    }
  }

  void _onTrack(RTCTrackEvent event) {
    final from = _pullingFrom;
    if (from == null) return;
    final p = participants[from] ?? _upsert(from, null, null);
    if (event.track.kind == 'video') {
      p.hasVideo = true;
      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        unawaited(_attachRenderer(p, stream));
      }
    } else {
      p.hasAudio = true;
    }
    notifyListeners();
  }

  Future<void> _attachRenderer(GroupCallParticipant p, MediaStream s) async {
    var renderer = p.renderer;
    if (renderer == null) {
      renderer = RTCVideoRenderer();
      await renderer.initialize();
      p.renderer = renderer;
    }
    renderer.srcObject = s;
    notifyListeners();
  }

  void _enqueuePull(String userId) {
    if (userId.isEmpty || userId == _selfId) return;
    if (_pulledFrom.contains(userId)) return;
    _pulledFrom.add(userId);
    final id = groupCallId;
    _pullChain = _pullChain.then((_) => _pullOne(id, userId));
  }

  Future<void> _pullOne(String? id, String userId) async {
    final pc = _pc;
    if (id == null || pc == null || id != groupCallId) return;
    _pullingFrom = userId;
    try {
      final response =
          await _calls.pull(groupCallId: id, fromUserId: userId);
      if (response['requiresImmediateRenegotiation'] == true &&
          response['sdpOffer'] != null) {
        final sdp =
            await CallMedia.answerOffer(pc, response['sdpOffer'].toString());
        await _calls.renegotiate(groupCallId: id, sdpAnswer: sdp);
      }
    } catch (e) {
      _pulledFrom.remove(userId);
      debugPrint('[GroupCall] pull from $userId failed: $e');
    } finally {
      _pullingFrom = null;
    }
  }

  void _onPeerReady(dynamic data) {
    if (data is! Map || data['groupCallId']?.toString() != groupCallId) return;
    final from = data['fromUserId']?.toString() ?? '';
    if (from.isEmpty || from == _selfId) return;
    _upsert(from, null, null);
    if (_published) {
      _enqueuePull(from);
    } else {
      _pendingPeers.add(from);
    }
    notifyListeners();
  }

  void _onParticipantJoined(dynamic data) {
    if (data is! Map || data['groupCallId']?.toString() != groupCallId) return;
    final userId = data['userId']?.toString() ?? '';
    if (userId.isEmpty || userId == _selfId) return;
    _upsert(userId, data['name']?.toString(), data['avatar']?.toString());
    notifyListeners();
  }

  void _onParticipantLeft(dynamic data) {
    if (data is! Map || data['groupCallId']?.toString() != groupCallId) return;
    final userId = data['userId']?.toString() ?? '';
    final p = participants.remove(userId);
    _pulledFrom.remove(userId);
    _pendingPeers.remove(userId);
    if (p?.renderer != null) {
      p!.renderer!.srcObject = null;
      unawaited(p.renderer!.dispose());
    }
    notifyListeners();
  }

  void _onMissed(dynamic data) {
    if (data is! Map || data['groupCallId']?.toString() != groupCallId) return;
    if (status == GroupCallStatus.incomingRinging) unawaited(_reset());
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

  void setMinimized(bool value) {
    if (minimized == value) return;
    minimized = value;
    notifyListeners();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  Future<void> _reset() async {
    _timer?.cancel();
    _timer = null;
    elapsedSeconds = 0;
    final pc = _pc;
    _pc = null;
    await pc?.close();
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    await _localStream?.dispose();
    _localStream = null;
    localRenderer.srcObject = null;
    for (final p in participants.values) {
      p.renderer?.srcObject = null;
      await p.renderer?.dispose();
    }
    participants.clear();
    _pulledFrom.clear();
    _pendingPeers.clear();
    _pullingFrom = null;
    _pullChain = Future<void>.value();
    _published = false;
    muted = false;
    cameraOff = false;
    speakerOn = true;
    minimized = false;
    callType = 'voice';
    status = GroupCallStatus.idle;
    groupCallId = null;
    conversationId = null;
    title = 'Group call';
    avatar = null;
    initiatorName = null;
    error = null;
    notifyListeners();
  }

  static String? _nonEmpty(dynamic v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }
}
