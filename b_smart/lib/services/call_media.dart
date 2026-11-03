import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Pure WebRTC helpers shared by [CallController] and [GroupCallController].
/// The call state machines themselves are deliberately not shared.
class CallMedia {
  CallMedia._();

  static const Map<String, dynamic> rtcConfig = {
    'iceServers': [
      {'urls': 'stun:stun.cloudflare.com:3478'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  static Future<MediaStream> getLocalStream({required bool video}) =>
      navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': video
            ? {
                'facingMode': 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
              }
            : false,
      });

  /// Cloudflare's API is a single HTTP round trip (no trickle ICE), so wait
  /// for gathering to finish before sending the local description.
  static Future<void> waitForIce(RTCPeerConnection pc) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) return;
    final done = Completer<void>();
    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !done.isCompleted) done.complete();
    };
    await Future.any(
        [done.future, Future<void>.delayed(const Duration(seconds: 3))]);
  }

  /// `{mid, kind}` per local sending transceiver, for the publish body.
  static Future<List<Map<String, String>>> localTracks(
      RTCPeerConnection pc) async {
    final tracks = <Map<String, String>>[];
    for (final t in await pc.getTransceivers()) {
      final kind = t.sender.track?.kind;
      if (kind == null || t.mid.isEmpty) continue;
      tracks.add({'mid': t.mid, 'kind': kind});
    }
    return tracks;
  }

  /// Creates the local offer, waits for ICE and returns the final SDP.
  static Future<String> createLocalOffer(RTCPeerConnection pc) async {
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await waitForIce(pc);
    final local = await pc.getLocalDescription();
    final sdp = local?.sdp;
    if (sdp == null || sdp.isEmpty) throw StateError('No local SDP.');
    return sdp;
  }

  /// Applies a Cloudflare renegotiation offer and returns the SDP answer.
  static Future<String> answerOffer(RTCPeerConnection pc, String offer) async {
    await pc.setRemoteDescription(RTCSessionDescription(offer, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await waitForIce(pc);
    final local = await pc.getLocalDescription();
    final sdp = local?.sdp;
    if (sdp == null || sdp.isEmpty) throw StateError('No local SDP.');
    return sdp;
  }

  static String formatElapsed(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}
