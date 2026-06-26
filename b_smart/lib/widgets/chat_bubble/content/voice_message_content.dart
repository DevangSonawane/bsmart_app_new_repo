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

  @override
  void didUpdateWidget(covariant VoiceMessageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl == widget.audioUrl &&
        oldWidget.totalDurationSeconds == widget.totalDurationSeconds) {
      return;
    }
    _playbackTimer?.cancel();
    _isPlaying = false;
    _currentSeconds = 0;
    _resolvedDuration = max(1, widget.totalDurationSeconds);
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
    final cs = Theme.of(context).colorScheme;

    final progress =
        (_currentSeconds / max(1, _resolvedDuration)).clamp(0.0, 1.0);
    final currentLabel = _formatDuration(_currentSeconds);
    final totalLabel = _formatDuration(_resolvedDuration);
    final timeLabel = _isPlaying ? '$currentLabel / $totalLabel' : totalLabel;

    final fg = widget.isOutgoing ? colors.outgoingText : colors.incomingText;
    final muted = widget.isOutgoing ? colors.outgoingMeta : colors.incomingMeta;
    final trackBg = widget.isOutgoing
        ? Colors.white.withValues(alpha: 0.18)
        : cs.onSurface.withValues(alpha: 0.10);
    final progressColor =
        widget.isOutgoing ? Colors.white.withValues(alpha: 0.96) : cs.primary;
    final thumbColor = widget.isOutgoing ? Colors.white : cs.primary;
    final iconBg = widget.isOutgoing
        ? Colors.white.withValues(alpha: 0.18)
        : cs.primary.withValues(alpha: 0.10);
    final iconColor =
        widget.isOutgoing ? Colors.white : cs.primary.withValues(alpha: 0.95);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width * 0.65;
        final usableWidth = width.clamp(0.0, 340.0);
        final compact = usableWidth < 220;

        Widget progressBar() {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              if (usableWidth <= 0) return;
              unawaited(
                  _seekToFraction(details.localPosition.dx / usableWidth));
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                width: double.infinity,
                height: 8,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(color: trackBg),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              progressColor.withValues(alpha: 0.60),
                              progressColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: max(0, (usableWidth * progress) - 5),
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: thumbColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final playButton = GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              _isPlaying ? LucideIcons.pause : LucideIcons.play,
              size: 18,
              color: iconColor,
            ),
          ),
        );

        final durationChip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isOutgoing
                ? Colors.white.withValues(alpha: 0.14)
                : cs.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            timeLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
            ),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        );

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: usableWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          playButton,
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _isPlaying ? 'Playing voice note' : 'Voice note',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fg,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: progressBar()),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: durationChip,
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          playButton,
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _isPlaying ? 'Playing voice note' : 'Voice note',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fg,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: progressBar()),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: durationChip,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
