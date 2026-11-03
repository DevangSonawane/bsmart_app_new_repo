import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/call_controller.dart';
import '../services/call_media.dart';
import '../services/group_call_controller.dart';
import 'call_add_people_panel.dart';
import 'floating_pip.dart';
import 'safe_network_image.dart';

/// Global call UI for both 1:1 ([CallController]) and group
/// ([GroupCallController]) calls. Mounted once above the app's Navigator so
/// incoming calls ring on every screen. It hosts its own [Overlay] so text
/// fields (add-people search) work even though it sits outside the Navigator.
class CallOverlay extends StatefulWidget {
  const CallOverlay({super.key, required this.child});
  final Widget child;
  @override
  State<CallOverlay> createState() => _CallOverlayState();
}

class _CallOverlayState extends State<CallOverlay> {
  final _calls = CallController.instance;
  final _group = GroupCallController.instance;
  late final Listenable _both = Listenable.merge([_calls, _group]);
  late final OverlayEntry _entry = OverlayEntry(
    builder: (context) => AnimatedBuilder(animation: _both, builder: (context, _) => _layer(context)),
  );
  bool _addingPeople = false;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    _calls.initialize();
    _group.initialize();
    _both.addListener(_onChange);
  }

  @override
  void dispose() {
    _both.removeListener(_onChange);
    _errorTimer?.cancel();
    super.dispose();
  }

  /// The call UI lives in [_entry], so rebuild the entry, not this widget.
  void _update(VoidCallback fn) {
    fn();
    _entry.markNeedsBuild();
  }

  void _onChange() {
    if (!_calls.isBusy && !_group.isBusy && _addingPeople) {
      _addingPeople = false;
    }
    // Errors raised while idle (busy, failed to start, call full) show as a
    // short toast and then clear themselves.
    final idleError = (!_calls.isBusy && _calls.error != null) || (!_group.isBusy && _group.error != null);
    if (idleError && _errorTimer == null) {
      _errorTimer = Timer(const Duration(seconds: 3), () {
        _errorTimer = null;
        _calls.clearError();
        _group.clearError();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        Positioned.fill(child: Overlay(initialEntries: [_entry])),
      ]);

  Widget _layer(BuildContext context) {
    final Widget? ui;
    if (_calls.isBusy) {
      ui = _addingPeople
          ? _addPeoplePanel(exclude: {if (_calls.peer != null) _calls.peer!.id}, onSubmit: _calls.addPeople)
          : _calls.minimized
              ? (_calls.isVideo
                  ? _videoTile(context,
                      renderer: _calls.status == CallStatus.active && _calls.hasRemoteVideo ? _calls.remoteRenderer : null,
                      name: _calls.peer?.name ?? 'Call',
                      avatar: _calls.peer?.avatar,
                      subtitle: _oneToOneLabel(),
                      onExpand: () => _calls.setMinimized(false),
                      onEnd: _calls.end)
                  : _bubble(context, title: _calls.peer?.name ?? 'Call', subtitle: _oneToOneLabel(), avatar: _calls.peer?.avatar, onExpand: () => _calls.setMinimized(false), onEnd: _calls.end))
              : _OneToOneCallView(calls: _calls, onAddPeople: () => _update(() => _addingPeople = true));
    } else if (_group.isBusy) {
      ui = _addingPeople
          ? _addPeoplePanel(exclude: _group.participants.keys.toSet(), onSubmit: _group.invite)
          : _group.minimized
              ? (_group.isVideo
                  ? _groupVideoTile(context)
                  : _bubble(context, title: _group.title, subtitle: CallMedia.formatElapsed(_group.elapsedSeconds), avatar: _group.avatar, onExpand: () => _group.setMinimized(false), onEnd: _group.leave))
              : _GroupCallView(group: _group, onAddPeople: () => _update(() => _addingPeople = true));
    } else {
      ui = null;
    }
    final error = _calls.isBusy || _group.isBusy ? null : (_calls.error ?? _group.error);
    if (ui == null && error == null) return const SizedBox.shrink();
    return Stack(children: [
      if (ui != null) Positioned.fill(child: ui),
      if (error != null)
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          child: Material(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(error, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ),
    ]);
  }

  String _oneToOneLabel() => _calls.status == CallStatus.active
      ? CallMedia.formatElapsed(_calls.elapsedSeconds)
      : _calls.status == CallStatus.connecting
          ? 'Connecting…'
          : 'Calling…';

  Widget _addPeoplePanel({required Set<String> exclude, required void Function(List<String>) onSubmit}) => CallAddPeoplePanel(
        excludeIds: exclude,
        onCancel: () => _update(() => _addingPeople = false),
        onSubmit: (ids) {
          _update(() => _addingPeople = false);
          onSubmit(ids);
        },
      );

  Widget _groupVideoTile(BuildContext context) {
    GroupCallParticipant? shown;
    for (final p in _group.participants.values) {
      if (p.hasVideo && p.renderer != null) {
        shown = p;
        break;
      }
    }
    shown ??= _group.participants.values.firstOrNull;
    return _videoTile(context,
        renderer: shown?.renderer != null && shown!.hasVideo ? shown.renderer : null,
        name: shown?.name ?? _group.title,
        avatar: shown?.avatar ?? _group.avatar,
        subtitle: CallMedia.formatElapsed(_group.elapsedSeconds),
        onExpand: () => _group.setMinimized(false),
        onEnd: _group.leave);
  }

  /// Instagram-style minimized video call: a draggable tile showing the
  /// other person's video (or their avatar until it arrives).
  Widget _videoTile(BuildContext context,
      {RTCVideoRenderer? renderer,
      required String name,
      String? avatar,
      required String subtitle,
      required VoidCallback onExpand,
      required VoidCallback onEnd}) {
    return FloatingPip(
      key: const ValueKey('call-mini-video'),
      size: const Size(120, 180),
      initialCorner: PipCorner.bottomRight,
      margin: _miniMargin(context),
      onTap: onExpand,
      child: Material(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned.fill(
              child: renderer != null
                  ? RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                  : Center(child: _Avatar(url: avatar, name: name, radius: 30)),
            ),
            Positioned(
              left: 6,
              right: 6,
              top: 6,
              child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 4)])),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: InkResponse(
                  onTap: onEnd,
                  child: const CircleAvatar(radius: 16, backgroundColor: Colors.red, child: Icon(Icons.call_end, color: Colors.white, size: 16)),
                ),
              ),
            ),
          ]),
        ),
    );
  }

  EdgeInsets _miniMargin(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    // Keep clear of the status bar and the app's bottom navigation bar.
    return EdgeInsets.fromLTRB(12, pad.top + 12, 12, pad.bottom + 76);
  }

  /// Compact draggable widget shown while a voice call is minimized.
  Widget _bubble(BuildContext context,
      {required String title, required String subtitle, String? avatar, required VoidCallback onExpand, required VoidCallback onEnd}) {
    return FloatingPip(
      key: const ValueKey('call-mini-voice'),
      size: const Size(220, 64),
      initialCorner: PipCorner.bottomRight,
      margin: _miniMargin(context),
      borderRadius: 32,
      onTap: onExpand,
      child: Material(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(32),
          child: Row(children: [
            const SizedBox(width: 8),
            _Avatar(url: avatar, name: title, radius: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            IconButton(onPressed: onEnd, icon: const CircleAvatar(radius: 18, backgroundColor: Colors.red, child: Icon(Icons.call_end, color: Colors.white, size: 18))),
          ]),
        ),
    );
  }
}

class _OneToOneCallView extends StatefulWidget {
  const _OneToOneCallView({required this.calls, required this.onAddPeople});
  final CallController calls;
  final VoidCallback onAddPeople;

  @override
  State<_OneToOneCallView> createState() => _OneToOneCallViewState();
}

class _OneToOneCallViewState extends State<_OneToOneCallView> {
  /// When true the self-view is full-screen and the peer is in the small box.
  bool _swapped = false;

  CallController get calls => widget.calls;

  @override
  Widget build(BuildContext context) {
    final incoming = calls.status == CallStatus.incomingRinging;
    final active = calls.status == CallStatus.active;
    final peer = calls.peer;
    final label = switch (calls.status) {
      CallStatus.outgoingRinging => 'Calling…',
      CallStatus.incomingRinging => calls.isVideo ? 'Incoming video call' : 'Incoming voice call',
      CallStatus.connecting => 'Connecting…',
      CallStatus.active => CallMedia.formatElapsed(calls.elapsedSeconds),
      _ => '',
    };
    final remoteVideo = calls.isVideo && active && calls.hasRemoteVideo;
    final localVideo = calls.isVideo && !calls.cameraOff && calls.localRenderer.srcObject != null;
    // Two-up layout (big + small box) only once both sides have video.
    final twoUp = remoteVideo && localVideo;
    final swapped = twoUp && _swapped;
    final media = MediaQuery.of(context);

    Widget remoteView() => RTCVideoView(calls.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);
    Widget localView() => RTCVideoView(calls.localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);

    final Widget? background = remoteVideo
        ? (swapped ? localView() : remoteView())
        : (localVideo && !active)
            // Ringing/connecting video call: full-screen self preview.
            ? localView()
            : null;
    final onVideo = background != null;

    return Material(
      // Always fully opaque so the app never shows through while ringing.
      color: Colors.black,
      child: Stack(children: [
        if (background != null)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: KeyedSubtree(key: ValueKey('bg-$swapped'), child: background),
            ),
          )
        else ...[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2B2B2B), Color(0xFF0A0A0A)]),
              ),
            ),
          ),
          // Audio needs no visible renderer on mobile, but keep one mounted.
          SizedBox(height: 1, width: 1, child: RTCVideoView(calls.remoteRenderer)),
        ],
        if (onVideo)
          // Scrims so text and buttons stay readable over bright video.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x99000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                    stops: [0, .25, .7, 1],
                  ),
                ),
              ),
            ),
          ),
        SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: incoming
                  ? const SizedBox(height: 48)
                  : Padding(
                      padding: const EdgeInsets.all(8),
                      child: _RoundIcon(icon: LucideIcons.chevronDown, onTap: () => calls.setMinimized(true)),
                    ),
            ),
            if (onVideo) ...[
              Text(peer?.name ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 4)])),
              Text(label, style: const TextStyle(color: Colors.white70, shadows: [Shadow(blurRadius: 4)])),
              const Spacer(),
            ] else ...[
              const Spacer(),
              _Avatar(url: peer?.avatar, name: peer?.name ?? '?', radius: 52),
              const SizedBox(height: 18),
              Text(peer?.name ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(color: Colors.white70)),
              const Spacer(),
            ],
            if (calls.error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(calls.error!, style: const TextStyle(color: Colors.redAccent))),
            if (incoming)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _CallButton(icon: Icons.call_end, color: Colors.red, onTap: calls.reject, label: 'Decline', large: true),
                const SizedBox(width: 56),
                _CallButton(icon: calls.isVideo ? Icons.videocam : Icons.call, color: Colors.green, onTap: calls.accept, label: 'Accept', large: true),
              ])
            else
              Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 12, children: [
                _CallButton(icon: calls.muted ? LucideIcons.micOff : LucideIcons.mic, onTap: calls.toggleMute, active: calls.muted),
                if (calls.isVideo) _CallButton(icon: calls.cameraOff ? LucideIcons.videoOff : LucideIcons.video, onTap: calls.toggleCamera, active: calls.cameraOff),
                if (calls.isVideo) _CallButton(icon: LucideIcons.switchCamera, onTap: calls.switchCamera),
                _CallButton(icon: calls.speakerOn ? LucideIcons.volume2 : LucideIcons.volume1, onTap: calls.toggleSpeaker, active: calls.speakerOn),
                if (active) _CallButton(icon: LucideIcons.userPlus, onTap: widget.onAddPeople),
                _CallButton(icon: Icons.call_end, color: Colors.red, onTap: calls.end),
              ]),
            const SizedBox(height: 24),
          ]),
        ),
        if (twoUp)
          // Self-view floats above everything; drag to move, tap to swap.
          Positioned.fill(
            child: FloatingPip(
              size: const Size(110, 160),
              margin: EdgeInsets.fromLTRB(12, media.padding.top + 12, 12, media.padding.bottom + 130),
              borderRadius: 12,
              onTap: () => setState(() => _swapped = !_swapped),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                clipBehavior: Clip.antiAlias,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: KeyedSubtree(key: ValueKey('pip-$swapped'), child: swapped ? remoteView() : localView()),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _GroupCallView extends StatelessWidget {
  const _GroupCallView({required this.group, required this.onAddPeople});
  final GroupCallController group;
  final VoidCallback onAddPeople;

  @override
  Widget build(BuildContext context) {
    final incoming = group.status == GroupCallStatus.incomingRinging;
    final joining = group.status == GroupCallStatus.joining;
    return Material(
      color: const Color(0xFF111111),
      child: SafeArea(
        child: incoming ? _incoming() : Column(children: [
          Row(children: [
            Padding(padding: const EdgeInsets.all(8), child: _RoundIcon(icon: LucideIcons.chevronDown, onTap: () => group.setMinimized(true))),
            Expanded(
              child: Column(children: [
                Text(group.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                Text(
                  joining ? 'Joining…' : '${CallMedia.formatElapsed(group.elapsedSeconds)} · ${group.participants.length + 1} in call',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ]),
            ),
            const SizedBox(width: 48),
          ]),
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: _grid())),
          if (group.error != null)
            Padding(padding: const EdgeInsets.all(8), child: Text(group.error!, style: const TextStyle(color: Colors.redAccent))),
          Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 12, children: [
            _CallButton(icon: group.muted ? LucideIcons.micOff : LucideIcons.mic, onTap: group.toggleMute, active: group.muted),
            if (group.isVideo) _CallButton(icon: group.cameraOff ? LucideIcons.videoOff : LucideIcons.video, onTap: group.toggleCamera, active: group.cameraOff),
            if (group.isVideo) _CallButton(icon: LucideIcons.switchCamera, onTap: group.switchCamera),
            _CallButton(icon: group.speakerOn ? LucideIcons.volume2 : LucideIcons.volume1, onTap: group.toggleSpeaker, active: group.speakerOn),
            if (!joining) _CallButton(icon: LucideIcons.userPlus, onTap: onAddPeople),
            _CallButton(icon: Icons.call_end, color: Colors.red, onTap: group.leave),
          ]),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _incoming() => Column(children: [
        const Spacer(),
        _Avatar(url: group.avatar, name: group.title, radius: 52),
        const SizedBox(height: 18),
        Text(group.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          '${group.initiatorName != null ? '${group.initiatorName} · ' : ''}Incoming group ${group.isVideo ? 'video' : 'voice'} call',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _CallButton(icon: Icons.call_end, color: Colors.red, onTap: group.decline, label: 'Decline', large: true),
          const SizedBox(width: 56),
          _CallButton(icon: group.isVideo ? Icons.videocam : Icons.call, color: Colors.green, onTap: group.accept, label: 'Join', large: true),
        ]),
        const SizedBox(height: 40),
      ]);

  Widget _grid() {
    final tiles = <Widget>[
      _tile(
        name: 'You',
        renderer: group.isVideo && !group.cameraOff && group.localRenderer.srcObject != null ? group.localRenderer : null,
        mirror: true,
        muted: group.muted,
      ),
      for (final p in group.participants.values)
        _tile(
          name: p.name,
          avatar: p.avatar,
          renderer: p.hasVideo ? p.renderer : null,
          connecting: !p.hasAudio && !p.hasVideo,
        ),
    ];
    if (tiles.length <= 2) {
      return Column(children: [for (final t in tiles) Expanded(child: Padding(padding: const EdgeInsets.all(4), child: t))]);
    }
    return LayoutBuilder(builder: (context, c) {
      final rows = (tiles.length / 2).ceil();
      final tileHeight = (c.maxHeight / rows).clamp(120.0, double.infinity);
      return GridView.count(
        crossAxisCount: 2,
        childAspectRatio: (c.maxWidth / 2) / tileHeight,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: tiles,
      );
    });
  }

  Widget _tile({required String name, String? avatar, RTCVideoRenderer? renderer, bool mirror = false, bool muted = false, bool connecting = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: const Color(0xFF262626),
        child: Stack(children: [
          if (renderer != null)
            Positioned.fill(child: RTCVideoView(renderer, mirror: mirror, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover))
          else
            Center(child: _Avatar(url: avatar, name: name, radius: 34)),
          Positioned(
            left: 8,
            bottom: 8,
            right: 8,
            child: Row(children: [
              if (muted) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(LucideIcons.micOff, color: Colors.white, size: 14)),
              Flexible(
                child: Text(
                  connecting ? '$name · connecting…' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 4)]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name, required this.radius});
  final String? url;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (url?.isNotEmpty == true) {
      return ClipOval(child: SafeNetworkImage(url: url!, width: radius * 2, height: radius * 2, fit: BoxFit.cover));
    }
    return CircleAvatar(
      radius: radius,
      child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: TextStyle(fontSize: radius * .65)),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({required this.icon, required this.onTap, this.color, this.active = false, this.label, this.large = false});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool active;
  final String? label;

  /// Big accept/decline buttons on the ringing screen; in-call controls stay small.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (active ? Colors.white : Colors.black.withValues(alpha: .45));
    final fg = color == null && active ? Colors.black : Colors.white;
    final radius = large ? 29.0 : 22.0;
    final button = InkResponse(
      onTap: onTap,
      child: CircleAvatar(radius: radius, backgroundColor: bg, child: Icon(icon, color: fg, size: large ? 26 : 20)),
    );
    if (label == null) return button;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      button,
      const SizedBox(height: 6),
      Text(label!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ]);
  }
}

/// Small dark circular icon button that stays visible over bright video.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        child: CircleAvatar(radius: 18, backgroundColor: Colors.black.withValues(alpha: .7), child: Icon(icon, color: Colors.white, size: 20)),
      );
}
