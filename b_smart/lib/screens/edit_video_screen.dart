import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import '../models/media_model.dart';

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

class _VideoTextOverlay {
  String text;
  Color color;
  double x;
  double y;

  _VideoTextOverlay({
    required this.text,
    required this.color,
    required this.x,
    required this.y,
  });
}

class EditVideoScreen extends StatefulWidget {
  final MediaItem media;

  const EditVideoScreen({super.key, required this.media});

  @override
  State<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends State<EditVideoScreen> {
  late final VideoPlayerController _controller;
  Future<void>? _init;
  bool _isPlaying = false;
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  double _startFraction = 0.0;
  double _endFraction = 1.0;
  final List<_VideoTextOverlay> _textOverlays = [];
  int? _activeTextIndex;

  // Thumbnail frames for the timeline strip
  final List<Uint8List?> _thumbnails = [];
  static const int _thumbnailCount = 8;

  Duration get _videoDuration => _controller.value.duration;
  final double _cropOffset = 0.5; // 0..1, position within crop area
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.media.filePath!));
    _init = _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.setLooping(true);
      setState(() {
        _trimEnd = _controller.value.duration;
        _trimStart = Duration.zero;
        _startFraction = 0.0;
        _endFraction = 1.0;
      });
      _controller.addListener(_handleVideoTick);
      _controller.play();
      _isPlaying = true;
      _generateThumbnails();
    });
  }

  Future<void> _generateThumbnails() async {
    final path = widget.media.filePath!;
    final durationMs = _controller.value.duration.inMilliseconds;
    final List<Uint8List?> frames = [];
    for (int i = 0; i < _thumbnailCount; i++) {
      final posMs = durationMs == 0
          ? 0
          : (durationMs * i / (_thumbnailCount - 1)).toInt();
      try {
        final bytes = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          timeMs: posMs,
          quality: 60,
        );
        frames.add(bytes);
      } catch (_) {
        frames.add(null);
      }
    }
    if (!mounted) return;
    setState(() {
      _thumbnails.clear();
      _thumbnails.addAll(frames);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleVideoTick);
    _controller.dispose();
    super.dispose();
  }

  void _handleVideoTick() {
    if (!_controller.value.isInitialized) return;
    final current = _controller.value.position;
    if (_trimEnd > _trimStart) {
      if (current > _trimEnd) {
        _controller.seekTo(_trimStart);
      } else if (current < _trimStart) {
        _controller.seekTo(_trimStart);
      }
    }
    // Removed setState here to stop rebuilding the entire screen every frame.
    // Instead, we use ValueListenableBuilder for the timer and the playhead.
  }

  void _togglePlay() {
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

  void _seekToFraction(double fraction) {
    if (!_controller.value.isInitialized) return;
    final clamped = fraction.clamp(_startFraction, _endFraction);
    final total = _controller.value.duration.inMilliseconds;
    final ms = (total * clamped).clamp(0, total);
    _controller.seekTo(Duration(milliseconds: ms.toInt()));
  }

  Future<void> _openTextEditor({int? index}) async {
    final existing = index != null && index >= 0 && index < _textOverlays.length
        ? _textOverlays[index]
        : null;
    final controller = TextEditingController(text: existing?.text ?? '');
    final media = MediaQuery.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          color: Colors.black.withAlpha(230),
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            Navigator.pop(ctx);
                          } else {
                            Navigator.pop(ctx, text);
                          }
                        },
                        child: const Text(
                          'Done',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      maxLines: null,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Tap to type',
                        hintStyle: TextStyle(color: Colors.white54, fontSize: 28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      setState(() {
        if (index != null && index >= 0 && index < _textOverlays.length) {
          _textOverlays[index].text = result;
        } else {
          _textOverlays.add(
            _VideoTextOverlay(text: result, color: Colors.white, x: 0.5, y: 0.5),
          );
          _activeTextIndex = _textOverlays.length - 1;
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    final s = d.inSeconds;
    final secs = (s % 60).toString().padLeft(2, '0');
    final mins = (s ~/ 60).toString();
    return '$mins:$secs';
  }

  Widget _buildTextOverlayWidget({
    required _VideoTextOverlay overlay,
    required int index,
    required double width,
    required double height,
  }) {
    final dx = overlay.x * width;
    final dy = overlay.y * height;
    final isActive = _activeTextIndex == index;
    return Positioned(
      left: dx,
      top: dy,
      child: GestureDetector(
        onTap: () {
          setState(() => _activeTextIndex = index);
          _openTextEditor(index: index);
        },
        onPanUpdate: (details) {
          setState(() {
            final px = overlay.x * width + details.delta.dx;
            final py = overlay.y * height + details.delta.dy;
            overlay.x = (px / width).clamp(0.0, 1.0);
            overlay.y = (py / height).clamp(0.0, 1.0);
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(isActive ? 0.4 : 0.25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            overlay.text,
            style: TextStyle(
              color: overlay.color,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // MAIN BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              _buildTopBar(),

              // Video preview
              Expanded(child: _buildVideoPreview()),

              // Playback controls (Play, Timestamp, Undo, Redo)
              _buildPlaybackControls(),

              // Timeline area
              const SizedBox(height: 12),
              _buildTimeline(),
              const SizedBox(height: 12),

              // "Tap to add..." rows
              _buildTrackRow(
                icon: const Icon(Icons.music_note, color: Colors.white70, size: 18),
                label: 'Tap to add audio',
                onTap: () {},
              ),
              _buildTrackRow(
                icon: const Text('Aa', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                label: 'Tap to add text',
                onTap: _openTextEditor,
              ),

              const SizedBox(height: 16),

              // Hint text
              const Text(
                'Tap on a track to trim. Pinch to zoom.',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 16),

              // Bottom toolbar
              _buildBottomPanel(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TOP BAR  (back ^ left, next → right)
  // ─────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back chevron
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.expand_less, color: Colors.white, size: 26),
            ),
          ),

          // Next button (Solid blue circle with arrow)
          GestureDetector(
            onTap: _exportVideo,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF0095F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBarIcon(IconData icon, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 26),
    );
  }

  // ─────────────────────────────────────────────
  // VIDEO PREVIEW
  // ─────────────────────────────────────────────
  Widget _buildVideoPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FutureBuilder<void>(
        future: _init,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              !_controller.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          return Center(
            child: GestureDetector(
              onTap: _togglePlay,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      return Stack(
                        children: [
                          Container(color: Colors.black),
                          RepaintBoundary(
                            child: SizedBox(
                              width: width,
                              height: height,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _controller.value.size.width,
                                  height: _controller.value.size.height,
                                  child: VideoPlayer(_controller),
                                ),
                              ),
                            ),
                          ),
                          // Text overlays
                          for (int i = 0; i < _textOverlays.length; i++)
                            _buildTextOverlayWidget(
                              overlay: _textOverlays[i],
                              index: i,
                              width: width,
                              height: height,
                            ),
                          // Play/Pause indicator overlay
                          if (!_isPlaying)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: Colors.black38,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 60,
                                ),
                              ),
                            ),
                          if (_exporting)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Play / Pause button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),

          // Timestamp centered (updates optimized with ValueListenableBuilder)
          Expanded(
            child: Center(
              child: ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, value, child) {
                  return RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _formatDuration(value.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' / ${_formatDuration(value.isInitialized ? value.duration : Duration.zero)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Undo
          _circleIconButton(Icons.undo),
          const SizedBox(width: 8),
          // Redo
          _circleIconButton(Icons.redo),
        ],
      ),
    );
  }

  Widget _circleIconButton(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Colors.white10,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white70, size: 20),
    );
  }

  Widget _buildTrackRow({
    Widget? icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              icon,
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ─────────────────────────────────────────────
  // BOTTOM PANEL
  // ─────────────────────────────────────────────
  Widget _buildBottomPanel() {
    return Container(
      height: 80,
      width: double.infinity,
      color: Colors.black,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _buildToolChip(Icons.text_fields_rounded, 'Text', onTap: () => _openTextEditor()),
            _buildToolChip(Icons.sentiment_satisfied_alt_rounded, 'Sticker'),
            _buildToolChip(Icons.music_note_rounded, 'Audio'),
            _buildToolChip(Icons.video_library_rounded, 'Add clips'),
            _buildToolChip(Icons.layers_rounded, 'Overlay'),
            _buildToolChip(Icons.content_cut_rounded, 'Edit', onTap: _showTrimEditor),
            _buildToolChip(Icons.closed_caption_rounded, 'Captions'),
          ],
        ),
      ),
    );
  }

  void _showTrimEditor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.4,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                      ),
                      const Text(
                        'Edit Video',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          // Already saved to main state via common variables
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Trim saved')),
                          );
                        },
                        child: const Text('Done', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // We use the same _buildTimeline but we need it to rebuild the MODAL when we drag.
                  // To fix the "not saving" issue, we wrap _buildTimeline with modal-specific updates.
                  Expanded(
                    child: _buildTimeline(
                      onUpdate: () => setModalState(() {}),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildToolChip(IconData icon, String label, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap ?? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label coming soon')),
              );
            },
            child: Container(
              width: 58,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TIMELINE
  // ─────────────────────────────────────────────
  Widget _buildTimeline({VoidCallback? onUpdate}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const horizontalPadding = 32.0;
        const handleWidth = 14.0;
        const hitAreaWidth = 40.0;
        final usableWidth = totalWidth - horizontalPadding * 2;

        final leftX = horizontalPadding + usableWidth * _startFraction;
        final rightX = horizontalPadding + usableWidth * _endFraction;

        final totalSecs = _controller.value.isInitialized
            ? _controller.value.duration.inSeconds
            : 4;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (d) {
            final fraction =
                ((d.localPosition.dx - horizontalPadding) / usableWidth)
                    .clamp(0.0, 1.0);
            _seekToFraction(fraction);
          },
          child: SizedBox(
            height: 100,
            child: Stack(
              children: [
                // 1. Tick marks
                Positioned(
                  top: 0,
                  left: horizontalPadding,
                  right: horizontalPadding,
                  child: _buildTickMarks(usableWidth, totalSecs),
                ),

                // 2. Fixed Thumbnail strip (Background)
                Positioned(
                  top: 22,
                  left: horizontalPadding,
                  right: horizontalPadding,
                  height: 52,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _buildThumbnailStrip(),
                  ),
                ),

                // 3. Dark overlays for non-selected areas
                // Left overlay
                Positioned(
                  top: 22,
                  left: horizontalPadding,
                  width: (leftX - horizontalPadding).clamp(0, usableWidth),
                  height: 52,
                  child: Container(color: Colors.black54),
                ),
                // Right overlay
                Positioned(
                  top: 22,
                  left: rightX,
                  right: horizontalPadding,
                  height: 52,
                  child: Container(color: Colors.black54),
                ),

                // 4. Selection Frame (White borders)
                Positioned(
                  top: 22,
                  left: leftX,
                  width: (rightX - leftX).clamp(0, usableWidth),
                  height: 52,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border.symmetric(
                        horizontal: BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),

                // 5. Left trim handle with large hit area
                Positioned(
                  top: 22,
                  left: leftX - hitAreaWidth / 2,
                  width: hitAreaWidth,
                  height: 52,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        final delta = details.delta.dx / usableWidth;
                        _startFraction = (_startFraction + delta).clamp(0.0, _endFraction - 0.05);
                        _trimStart = Duration(milliseconds: (_videoDuration.inMilliseconds * _startFraction).toInt());
                        _controller.seekTo(_trimStart); // Always seek while dragging for accuracy
                      });
                      if (onUpdate != null) onUpdate();
                    },
                    child: Center(child: _buildHandle()),
                  ),
                ),

                // 6. Right trim handle with large hit area
                Positioned(
                  top: 22,
                  left: rightX - hitAreaWidth / 2,
                  width: hitAreaWidth,
                  height: 52,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) {
                      setState(() {
                        final delta = details.delta.dx / usableWidth;
                        _endFraction = (_endFraction + delta).clamp(_startFraction + 0.05, 1.0);
                        _trimEnd = Duration(milliseconds: (_videoDuration.inMilliseconds * _endFraction).toInt());
                        _controller.seekTo(_trimEnd); // Always seek while dragging for accuracy
                      });
                      if (onUpdate != null) onUpdate();
                    },
                    child: Center(child: _buildHandle()),
                  ),
                ),

                // 7. White playhead line
                ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, value, child) {
                    double playFraction = 0.0;
                    if (value.isInitialized && _videoDuration.inMilliseconds > 0) {
                      playFraction = value.position.inMilliseconds / _videoDuration.inMilliseconds;
                    }
                    playFraction = playFraction.clamp(_startFraction, _endFraction);
                    final playX = horizontalPadding + usableWidth * playFraction;
                    
                    return Positioned(
                      top: 0,
                      bottom: 0,
                      left: playX - 1,
                      width: 2,
                      child: Container(color: Colors.white),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Thumbnail strip – shows actual video frames if available, else grey
  Widget _buildThumbnailStrip() {
    if (_thumbnails.isEmpty) {
      return Container(color: const Color(0xFF2A2A2A));
    }
    return Row(
      children: List.generate(_thumbnails.length, (i) {
        final bytes = _thumbnails[i];
        return Expanded(
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.cover)
              : Container(color: const Color(0xFF2A2A2A)),
        );
      }),
    );
  }

  // Rounded white handle pill
  Widget _buildHandle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      width: 12,
      height: 52,
    );
  }

  // Tick marks: dot • 1s • 3s • spaced evenly
  Widget _buildTickMarks(double width, int totalSecs) {
    // Show a dot at 0, then every second, then at the end
    final List<Widget> marks = [];
    for (int s = 0; s <= totalSecs; s++) {
      final fraction = totalSecs == 0 ? 0.0 : s / totalSecs;
      final isLabelled = s > 0 && s < totalSecs && s % 2 == 1;
      marks.add(
        Positioned(
          left: width * fraction - 12,
          width: 24,
          top: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLabelled)
                Text(
                  '${s}s',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  textAlign: TextAlign.center,
                )
              else
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white54,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 18,
      child: Stack(children: marks),
    );
  }

  Future<void> _exportVideo() async {
    if (!_controller.value.isInitialized || _exporting) return;
    setState(() => _exporting = true);

    try {
      final inputPath = widget.media.filePath!;
      final size = _controller.value.size;
      const a = 9 / 16.0;
      int cropW;
      int cropH;
      int cropX;
      int cropY;
      if (size.width / size.height > a) {
        cropH = (size.height / 2).floor() * 2;
        cropW = (cropH * a / 2).floor() * 2;
        final maxX = size.width - cropW;
        cropX = (maxX * _cropOffset / 2).floor() * 2;
        cropY = 0;
      } else {
        cropW = (size.width / 2).floor() * 2;
        cropH = (cropW / a / 2).floor() * 2;
        final maxY = size.height - cropH;
        cropY = (maxY * _cropOffset / 2).floor() * 2;
        cropX = 0;
      }

      final startMs = _trimStart.inMilliseconds;
      final endMs = (_trimEnd > _trimStart ? _trimEnd : _videoDuration).inMilliseconds;
      final durMs = (endMs - startMs).clamp(0, _videoDuration.inMilliseconds);
      final startSec = (startMs / 1000.0);
      final durSec = (durMs / 1000.0);

      final tmpDir = await Directory.systemTemp.createTemp('bsmart_edit_');
      final outPath = '${tmpDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final textFilters = <String>[];
      for (final t in _textOverlays) {
        final xPx = (t.x * 1080).toInt();
        final yPx = (t.y * 1920).toInt();
        final safeText = t.text.replaceAll(':', '\\:').replaceAll("'", "\\'");
        textFilters.add("drawtext=text='$safeText':fontcolor=white:fontsize=48:x=$xPx:y=$yPx");
      }
      final vf = [
        'crop=$cropW:$cropH:$cropX:$cropY',
        'scale=1080:1920',
        ...textFilters,
      ].join(',');

      // Using arguments list is much more reliable than a single string command.
      // Added compatibility flags for Android Codec2:
      // -profile:v baseline -level 3.1: Max compatibility for decoders
      // -movflags +faststart: Moves metadata to start of file for immediate playback
      final args = [
        '-y',
        '-i', inputPath,
        '-ss', startSec.toStringAsFixed(3),
        '-t', durSec.toStringAsFixed(3),
        '-vf', vf,
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        '-crf', '25', // Slightly higher compression to reduce decoder load
        '-profile:v', 'baseline',
        '-level', '3.1',
        '-pix_fmt', 'yuv420p',
        '-c:a', 'aac',
        '-movflags', '+faststart',
        outPath,
      ];

      debugPrint('FFmpeg Args: ${args.join(' ')}');

      final session = await FFmpegKit.executeWithArguments(args);
      final rc = await session.getReturnCode();
      final logs = await session.getAllLogsAsString();

      if (ReturnCode.isSuccess(rc)) {
        debugPrint('Export success: $outPath');
        if (!mounted) return;
        Navigator.of(context).pop(
          VideoEditResult(
            trimStart: _trimStart,
            trimEnd: _trimEnd,
            outputPath: outPath,
          ),
        );
      } else {
        debugPrint('FFmpeg Failed with RC: $rc');
        debugPrint('FFmpeg Logs: $logs');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${rc?.getValue() ?? "Unknown error"}')),
        );
      }
    } catch (e, stack) {
      debugPrint('Export Exception: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error during video export')),
        );
      }
    }
 finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
