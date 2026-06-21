import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/media_model.dart';
import '../services/create_service.dart';

class VideoEditResult {
  final Duration trimStart;
  final Duration trimEnd;
  final String? outputPath;

  const VideoEditResult({
    required this.trimStart,
    required this.trimEnd,
    this.outputPath,
  });
}

class EditVideoScreen extends StatefulWidget {
  final MediaItem media;

  const EditVideoScreen({super.key, required this.media});

  @override
  State<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends State<EditVideoScreen> {
  final CreateService _createService = CreateService();
  late final VideoPlayerController _controller;
  Future<void>? _initFuture;
  bool _isPlaying = false;
  bool _isExporting = false;
  bool _hasInitError = false;

  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  double _startFraction = 0.0;
  double _endFraction = 1.0;

  Duration get _videoDuration => _controller.value.duration;

  @override
  void initState() {
    super.initState();
    final path = widget.media.filePath;
    if (path == null || path.isEmpty) {
      _controller = VideoPlayerController.file(File(''));
      _hasInitError = true;
      _initFuture = Future<void>.value();
      return;
    }

    _controller = VideoPlayerController.file(File(path));
    _initFuture = _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _trimStart = Duration.zero;
        _trimEnd = _controller.value.duration;
        _startFraction = 0.0;
        _endFraction = 1.0;
      });
      _controller.setLooping(true);
      _controller.addListener(_handleTick);
      _controller.play();
      _isPlaying = true;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTick);
    _controller.dispose();
    super.dispose();
  }

  void _handleTick() {
    if (!_controller.value.isInitialized) return;
    final current = _controller.value.position;
    if (current < _trimStart) {
      _controller.seekTo(_trimStart);
    } else if (current > _trimEnd) {
      _controller.seekTo(_trimStart);
    }
  }

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString();
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _togglePlayback() {
    if (!_controller.value.isInitialized) return;
    setState(() {
      if (_isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  void _updateTrimRange(RangeValues values) {
    if (!_controller.value.isInitialized) return;
    final durationMs = _videoDuration.inMilliseconds;
    if (durationMs <= 0) return;

    setState(() {
      _startFraction = values.start.clamp(0.0, 1.0);
      _endFraction = values.end.clamp(_startFraction, 1.0);
      _trimStart =
          Duration(milliseconds: (durationMs * _startFraction).round());
      _trimEnd = Duration(milliseconds: (durationMs * _endFraction).round());
    });

    if (_controller.value.position < _trimStart ||
        _controller.value.position > _trimEnd) {
      _controller.seekTo(_trimStart);
    }
  }

  Future<void> _saveTrimAndClose() async {
    if (!_controller.value.isInitialized || _isExporting) return;
    final inputPath = widget.media.filePath;
    if (inputPath == null || inputPath.isEmpty) return;

    setState(() => _isExporting = true);
    try {
      final outputPath = await _createService.trimVideoForUpload(
        inputPath: inputPath,
        trimStart: _trimStart,
        trimEnd: _trimEnd,
        videoDuration: _videoDuration,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        VideoEditResult(
          trimStart: _trimStart,
          trimEnd: _trimEnd,
          outputPath: outputPath,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save trim: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isExporting,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: FutureBuilder<void>(
                  future: _initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done ||
                        !_controller.value.isInitialized) {
                      if (_hasInitError) {
                        return const Center(
                          child: Text(
                            'Video not available',
                            style: TextStyle(color: Colors.white70),
                          ),
                        );
                      }
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }

                    final duration = _videoDuration;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 9 / 16,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(color: Colors.black),
                                      FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: _controller.value.size.width,
                                          height: _controller.value.size.height,
                                          child: VideoPlayer(_controller),
                                        ),
                                      ),
                                      Positioned(
                                        left: 16,
                                        right: 16,
                                        top: 16,
                                        child: IgnorePointer(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.45),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Trim only',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_isExporting)
                                        Container(
                                          color: Colors.black
                                              .withValues(alpha: 0.55),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _togglePlayback,
                                icon: Icon(
                                  _isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_formatDuration(_trimStart)} - ${_formatDuration(_trimEnd)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Selected range ${_formatDuration(Duration(milliseconds: (_trimEnd - _trimStart).inMilliseconds.clamp(0, duration.inMilliseconds)))}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: RangeSlider(
                            values: RangeValues(_startFraction, _endFraction),
                            min: 0,
                            max: 1,
                            divisions: 100,
                            activeColor: const Color(0xFF0095F6),
                            inactiveColor: Colors.white24,
                            labels: RangeLabels(
                              _formatDuration(Duration(
                                milliseconds:
                                    (duration.inMilliseconds * _startFraction)
                                        .round(),
                              )),
                              _formatDuration(Duration(
                                milliseconds:
                                    (duration.inMilliseconds * _endFraction)
                                        .round(),
                              )),
                            ),
                            onChanged: _updateTrimRange,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_trimStart),
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                              Text(
                                _formatDuration(_trimEnd),
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isExporting ? null : _cancel,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side:
                                        const BorderSide(color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      _isExporting ? null : _saveTrimAndClose,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0095F6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text('Done'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Only the trimmed section will be exported.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isExporting ? null : _cancel,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 22),
            ),
          ),
          const Spacer(),
          const Text(
            'Trim video',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}
