import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class VoiceRecorderSheet extends StatefulWidget {
  final Future<void> Function(Uint8List bytes, int durationSeconds) onSend;
  final VoidCallback onCancel;

  const VoiceRecorderSheet({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

enum _RecorderState { idle, recording, preview }

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet> {
  static const int maxDuration = 300;
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
    13,
    9,
    15,
    18,
  ];

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  _RecorderState _state = _RecorderState.idle;
  int _durationSeconds = 0;
  Uint8List? _audioBytes;
  bool _isPlaying = false;
  int _playbackSeconds = 0;
  bool _isSending = false;
  Timer? _recordingTimer;
  Timer? _playbackTimer;
  StreamSubscription<PlayerState>? _playerStateSub;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playbackTimer?.cancel();
        _player.seek(Duration.zero);
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _playbackSeconds = 0;
          });
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(startRecording());
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _playerStateSub?.cancel();
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }

  String formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> startRecording() async {
    if (_isSending) return;

    _playbackTimer?.cancel();
    await _player.stop();

    final perm = await Permission.microphone.request();
    if (!perm.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return;
    }

    try {
      if (!await _recorder.hasPermission(request: false)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required.')),
        );
        return;
      }

      final filename =
          'voice_${DateTime.now().millisecondsSinceEpoch.toString()}.aac';
      final path = p.join(Directory.systemTemp.path, filename);
      _recordingPath = path;

      _recordingTimer?.cancel();
      setState(() {
        _state = _RecorderState.recording;
        _durationSeconds = 0;
        _audioBytes = null;
        _isPlaying = false;
        _playbackSeconds = 0;
      });

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _durationSeconds += 1);
        if (_durationSeconds >= maxDuration) {
          unawaited(stopRecording());
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start recording.')),
      );
    }
  }

  Future<void> stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final path = await _recorder.stop();
      final finalPath = (path ?? _recordingPath ?? '').trim();
      if (finalPath.isEmpty) return;

      final bytes = await File(finalPath).readAsBytes();
      _recordingPath = finalPath;

      await _player.setFilePath(finalPath);
      final d = _player.duration;
      final resolved = d?.inSeconds ?? 0;

      if (!mounted) return;
      setState(() {
        _audioBytes = bytes;
        _state = _RecorderState.preview;
        _isPlaying = false;
        _playbackSeconds = 0;
        if (resolved > 0) _durationSeconds = resolved;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to stop recording.')),
      );
    }
  }

  Future<void> cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    try {
      await _recorder.cancel();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    widget.onCancel();
  }

  Future<void> _resetAndRestart() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _recorder.cancel();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _state = _RecorderState.idle;
      _durationSeconds = 0;
      _audioBytes = null;
      _isPlaying = false;
      _playbackSeconds = 0;
      _recordingPath = null;
    });
    await startRecording();
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final pos = _player.position;
      setState(() => _playbackSeconds = pos.inSeconds);
    });
  }

  Future<void> togglePlayback() async {
    if (_recordingPath == null || _audioBytes == null) return;
    if (_isPlaying) {
      await _player.pause();
      _playbackTimer?.cancel();
      if (!mounted) return;
      setState(() => _isPlaying = false);
      return;
    }

    if (_durationSeconds > 0 && _playbackSeconds >= _durationSeconds) {
      await _player.seek(Duration.zero);
      if (mounted) setState(() => _playbackSeconds = 0);
    }

    await _player.play();
    _startPlaybackTimer();
    if (mounted) setState(() => _isPlaying = true);
  }

  Future<void> handleSend() async {
    if (_isSending) return;
    final bytes = _audioBytes;
    if (bytes == null) return;
    setState(() => _isSending = true);
    try {
      await widget.onSend(bytes, max(0, _durationSeconds));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final bg = BoxDecoration(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(26),
      gradient: const RadialGradient(
        center: Alignment(-0.8, -0.2),
        radius: 1.4,
        colors: [
          Color(0xFF2A0000),
          Color(0xFF111111),
        ],
        stops: [0.0, 1.0],
      ),
    );

    Widget cancelButton({required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: const Icon(LucideIcons.x, size: 18, color: Colors.white),
        ),
      );
    }

    Widget stopButton() {
      return GestureDetector(
        onTap: stopRecording,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      );
    }

    Widget sendButton() {
      return GestureDetector(
        onTap: _isSending ? null : handleSend,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFF5B5EF4),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: _isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(LucideIcons.send, size: 18, color: Colors.white),
        ),
      );
    }

    Widget recordingCenter() {
      final progress = (_durationSeconds / maxDuration).clamp(0.0, 1.0);
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'RECORDING',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatDuration(_durationSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Stack(
                children: [
                  Container(
                    height: 4,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      height: 4,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFF5B5EF4)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget previewCenter() {
      final progress =
          (_playbackSeconds / max(1, _durationSeconds)).clamp(0.0, 1.0);
      return Expanded(
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF5B5EF4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: togglePlayback,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? LucideIcons.pause : LucideIcons.play,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Prevent overflow on narrow screens by adapting the number of bars.
                    const barWidth = 3.0;
                    const barMargin = 1.3; // each side
                    final perBar = barWidth + (barMargin * 2);
                    final maxBars =
                        max(6, min(waveformHeights.length, (constraints.maxWidth / perBar).floor()));
                    final activeBars = (progress * maxBars).floor();

                    double heightForBar(int i) {
                      if (maxBars <= 1) return waveformHeights.first;
                      final idx =
                          ((i * (waveformHeights.length - 1)) / (maxBars - 1))
                              .round()
                              .clamp(0, waveformHeights.length - 1);
                      return waveformHeights[idx];
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 22,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(maxBars, (i) {
                              final active = i <= activeBars;
                              return Container(
                                width: barWidth,
                                height: heightForBar(i),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: barMargin),
                                decoration: BoxDecoration(
                                  color: active
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.30),
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
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                              FractionallySizedBox(
                                widthFactor: progress,
                                child: Container(
                                  height: 2,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _isPlaying
                    ? formatDuration(_playbackSeconds)
                    : formatDuration(_durationSeconds),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget contentRow;
    if (_state == _RecorderState.preview) {
      contentRow = Row(
        children: [
          cancelButton(onTap: _resetAndRestart),
          const SizedBox(width: 10),
          previewCenter(),
          const SizedBox(width: 10),
          sendButton(),
        ],
      );
    } else {
      contentRow = Row(
        children: [
          cancelButton(onTap: () => unawaited(cancelRecording())),
          const SizedBox(width: 10),
          recordingCenter(),
          const SizedBox(width: 10),
          stopButton(),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad + 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: bg,
        child: DefaultTextStyle(
          style: TextStyle(color: cs.onSurface),
          child: contentRow,
        ),
      ),
    );
  }
}
