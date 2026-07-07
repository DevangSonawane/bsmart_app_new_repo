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
  StreamSubscription<Duration>? _positionSub;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _loadFailed = false;
  bool _isPrepared = false;
  bool _pendingPlayAfterLoad = false;
  Duration _position = Duration.zero;
  late int _resolvedDuration;
  Future<void>? _prepareFuture;

  @override
  void initState() {
    super.initState();
    _resolvedDuration = max(1, widget.totalDurationSeconds);
    _positionSub = _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _playerStateSub = _player.playerStateStream.listen((state) {
      final loading = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;
      if (mounted && loading != _isLoading) {
        setState(() => _isLoading = loading);
      }
      if (mounted) {
        final playing = state.playing &&
            state.processingState != ProcessingState.completed;
        if (playing != _isPlaying) {
          setState(() => _isPlaying = playing);
        }
      }
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
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
    _prepareFuture = null;
    _isPlaying = false;
    _isLoading = false;
    _loadFailed = false;
    _isPrepared = false;
    _pendingPlayAfterLoad = false;
    _position = Duration.zero;
    _resolvedDuration = max(1, widget.totalDurationSeconds);
    unawaited(_init());
  }

  Future<void> _init() async {
    await _prepareAudio();
  }

  Future<void> _prepareAudio() async {
    if (_isPrepared) return;
    final url = widget.audioUrl.trim();
    if (url.isEmpty) return;
    final existing = _prepareFuture;
    if (existing != null) {
      return existing;
    }
    final future = _doPrepareAudio(url);
    _prepareFuture = future;
    try {
      await future;
    } finally {
      if (identical(_prepareFuture, future)) {
        _prepareFuture = null;
      }
    }
  }

  Future<void> _doPrepareAudio(String url) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    try {
      await _player.stop();
      await _player.setUrl(url);
      final d = _player.duration;
      if (d != null && d.inSeconds > 0 && mounted) {
        setState(() => _resolvedDuration = d.inSeconds);
      }
      _isPrepared = true;
    } catch (_) {
      _isPrepared = false;
      if (mounted) {
        setState(() => _loadFailed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      if (_pendingPlayAfterLoad) {
        _pendingPlayAfterLoad = false;
        unawaited(_togglePlayPause());
      }
    }
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlayPause() async {
    if (widget.audioUrl.trim().isEmpty) return;
    if (_loadFailed) {
      await _prepareAudio();
      if (_loadFailed) return;
    }
    if (_isPlaying) {
      await _player.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    if (_isLoading && !_isPrepared) {
      _pendingPlayAfterLoad = true;
      return;
    }

    if (!_isPrepared) {
      _pendingPlayAfterLoad = true;
      await _prepareAudio();
      if (!mounted || _loadFailed || !_isPrepared) return;
    }

    final dur = max(1, _resolvedDuration);
    if (_position.inMilliseconds >= dur * 1000) {
      await _player.seek(Duration.zero);
      if (mounted) setState(() => _position = Duration.zero);
    }

    await _player.play();
    if (mounted) setState(() => _isPlaying = true);
  }

  Future<void> _seekToFraction(double fraction) async {
    final dur = max(1, _resolvedDuration);
    final target = (fraction.clamp(0.0, 1.0) * dur).round();
    await _player.seek(Duration(seconds: target));
    if (mounted) setState(() => _position = Duration(seconds: target));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ChatBubbleTheme.of(context);
    final colors = theme.colors;
    final cs = Theme.of(context).colorScheme;

    final totalMs = max(1, _resolvedDuration * 1000);
    final currentMs = _position.inMilliseconds.clamp(0, totalMs);
    final progress = (currentMs / totalMs).clamp(0.0, 1.0);
    final currentLabel = _formatDuration(currentMs ~/ 1000);
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isLoading && !_isPlaying
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  : Icon(
                      _isPlaying ? LucideIcons.pause : LucideIcons.play,
                      key: ValueKey(_isPlaying),
                      size: 18,
                      color: iconColor,
                    ),
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
              fontFamily: 'Montserrat',
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
