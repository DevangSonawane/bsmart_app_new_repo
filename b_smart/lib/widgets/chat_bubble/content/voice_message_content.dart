import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chat_bubble_theme.dart';

class VoiceMessageContent extends StatefulWidget {
  final String audioUrl;
  final int totalDurationSeconds;
  final bool isOutgoing;

  const VoiceMessageContent({
    super.key,
    required this.audioUrl,
    required this.totalDurationSeconds,
    required this.isOutgoing,
  });

  @override
  State<VoiceMessageContent> createState() => _VoiceMessageContentState();
}

class _VoiceMessageContentState extends State<VoiceMessageContent> {
  static const List<double> waveformHeights = [
    8,
    11,
    16,
    12,
    18,
    10,
    20,
    14,
    9,
    17,
    12,
    15,
    19,
    11,
    13,
    18,
    10,
    16,
    12,
    20,
  ];

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  Timer? _playbackTimer;
  bool _isPlaying = false;
  int _currentSeconds = 0;
  late int _resolvedDuration;

  @override
  void initState() {
    super.initState();
    _resolvedDuration = max(1, widget.totalDurationSeconds);
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playbackTimer?.cancel();
        _player.seek(Duration.zero);
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentSeconds = 0;
          });
        }
      }
    });
    unawaited(_init());
  }

  Future<void> _init() async {
    final url = widget.audioUrl.trim();
    if (url.isEmpty) return;
    try {
      await _player.setUrl(url);
      final d = _player.duration;
      if (d != null && d.inSeconds > 0 && mounted) {
        setState(() => _resolvedDuration = d.inSeconds);
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _playerStateSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _currentSeconds = _player.position.inSeconds);
    });
  }

  Future<void> _togglePlayPause() async {
    if (widget.audioUrl.trim().isEmpty) return;
    if (_isPlaying) {
      await _player.pause();
      _playbackTimer?.cancel();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    final dur = max(1, _resolvedDuration);
    if (_currentSeconds >= dur) {
      await _player.seek(Duration.zero);
      if (mounted) setState(() => _currentSeconds = 0);
    }

    await _player.play();
    _startPlaybackTimer();
    if (mounted) setState(() => _isPlaying = true);
  }

  Future<void> _seekToFraction(double fraction) async {
    final dur = max(1, _resolvedDuration);
    final target = (fraction.clamp(0.0, 1.0) * dur).round();
    await _player.seek(Duration(seconds: target));
    if (mounted) setState(() => _currentSeconds = target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatBubbleTheme.of(context);
    final colors = theme.colors;

    final progress =
        (_currentSeconds / max(1, _resolvedDuration)).clamp(0.0, 1.0);
    final activeBars = (progress * waveformHeights.length).floor();

    final timeLabel = _isPlaying
        ? _formatDuration(_currentSeconds)
        : _formatDuration(_resolvedDuration);

    final fg = widget.isOutgoing ? colors.outgoingText : colors.incomingText;
    final faded =
        (widget.isOutgoing ? colors.outgoingMeta : colors.incomingMeta);

    final primary = Theme.of(context).colorScheme.primary;
    final innerBg = Color.lerp(primary, Colors.white, 0.22)!
        .withValues(alpha: widget.isOutgoing ? 0.38 : 0.24);
    final innerBorder = Color.lerp(primary, Colors.white, 0.40)!
        .withValues(alpha: widget.isOutgoing ? 0.65 : 0.35);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: innerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: innerBorder),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: (widget.isOutgoing ? Colors.white : Colors.black)
                      .withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isPlaying ? LucideIcons.pause : LucideIcons.play,
                  size: 18,
                  color: fg,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (d) {
                      if (w <= 0) return;
                      unawaited(_seekToFraction(d.localPosition.dx / w));
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 22,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children:
                                List.generate(waveformHeights.length, (i) {
                              final active = i <= activeBars;
                              return Container(
                                width: 3,
                                height: waveformHeights[i],
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 1.3),
                                decoration: BoxDecoration(
                                  color:
                                      active ? fg : fg.withValues(alpha: 0.30),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Stack(
                            children: [
                              Container(
                                height: 2,
                                color: fg.withValues(alpha: 0.18),
                              ),
                              FractionallySizedBox(
                                widthFactor: progress,
                                child: Container(
                                  height: 2,
                                  color: fg.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Text(
              timeLabel,
              style: TextStyle(
                color: faded,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
              textScaler: MediaQuery.textScalerOf(context),
            ),
          ],
        ),
      ),
    );
  }
}
