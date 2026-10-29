import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/call_controller.dart';
import 'safe_network_image.dart';

class CallOverlay extends StatefulWidget {
  const CallOverlay({super.key, required this.child});
  final Widget child;
  @override State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  final _calls = CallController.instance;
  @override void initState() { super.initState(); _calls.initialize(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _calls,
    builder: (_, __) => Stack(children: [widget.child, if (_calls.status != CallStatus.idle) _sheet(context)]),
  );

  Widget _sheet(BuildContext context) {
    final incoming = _calls.status == CallStatus.incomingRinging;
    final active = _calls.status == CallStatus.active;
    final peer = _calls.peer;
    final elapsed = '${(_calls.elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:${(_calls.elapsedSeconds % 60).toString().padLeft(2, '0')}';
    final label = switch (_calls.status) {
      CallStatus.outgoingRinging => 'Calling…', CallStatus.incomingRinging => 'Incoming voice call',
      CallStatus.connecting => 'Connecting…', CallStatus.active => elapsed, _ => '',
    };
    return Positioned.fill(child: Material(
      color: Colors.black.withValues(alpha: .88),
      child: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (peer?.avatar?.isNotEmpty == true) ClipOval(child: SafeNetworkImage(url: peer!.avatar!, width: 104, height: 104, fit: BoxFit.cover))
        else CircleAvatar(radius: 52, child: Text((peer?.name ?? '?').substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 34))),
        const SizedBox(height: 18), Text(peer?.name ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.white70)),
        if (active) SizedBox(height: 1, width: 1, child: RTCVideoView(_calls.remoteRenderer)),
        if (_calls.error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_calls.error!, style: const TextStyle(color: Colors.redAccent))),
        const SizedBox(height: 44), Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (incoming) ...[
            _button(Icons.call_end, Colors.red, _calls.reject), const SizedBox(width: 36), _button(Icons.call, Colors.green, _calls.accept),
          ] else ...[
            if (active) _button(_calls.muted ? LucideIcons.micOff : LucideIcons.mic, Colors.white24, _calls.toggleMute),
            if (active) const SizedBox(width: 36), _button(Icons.call_end, Colors.red, _calls.end),
          ],
        ]),
      ])),
    ));
  }
  Widget _button(IconData icon, Color color, VoidCallback action) => InkResponse(onTap: action, child: CircleAvatar(radius: 29, backgroundColor: color, child: Icon(icon, color: Colors.white)));
}
