import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/media_model.dart';

class VideoEditResult {
  final Duration trimStart;
  final Duration trimEnd;

  const VideoEditResult({
    required this.trimStart,
    required this.trimEnd,
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
    if (mounted) setState(() {});
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
              // ── Top bar
              _buildTopBar(),

              // ── Video Preview (fills remaining vertical space above controls)
              Expanded(child: _buildVideoPreview()),

              // ── Playback controls
              _buildPlaybackControls(),

              // ── Bottom editing panel
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
          // Back – chevron up, inside a dark rounded button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white12,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.expand_less, color: Colors.white, size: 26),
            ),
          ),

          // Next – solid blue circle with arrow
          GestureDetector(
            onTap: () {
              final start = _trimStart;
              final end = _trimEnd > _trimStart ? _trimEnd : _videoDuration;
              Navigator.of(context).pop(
                VideoEditResult(
                  trimStart: start,
                  trimEnd: end,
                ),
              );
            },
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

  // ─────────────────────────────────────────────
  // VIDEO PREVIEW
  // ─────────────────────────────────────────────
  Widget _buildVideoPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
            child: AspectRatio(
              // Portrait card (matches Instagram's 9:16 crop area)
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    return Stack(
                      children: [
                        // Black background (letterbox)
                        Container(color: Colors.black),
                        // Video – cover fills the card
                        SizedBox(
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
                        // Text overlays
                        for (int i = 0; i < _textOverlays.length; i++)
                          _buildTextOverlayWidget(
                            overlay: _textOverlays[i],
                            index: i,
                            width: width,
                            height: height,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PLAYBACK CONTROLS ROW
  // ─────────────────────────────────────────────
  Widget _buildPlaybackControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          // Play / Pause button
          GestureDetector(
            onTap: _togglePlay,
            child: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: Colors.white,
              size: 36,
            ),
          ),

          // Timestamp centred
          Expanded(
            child: Center(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: _formatDuration(_controller.value.position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' / ${_formatDuration(_controller.value.isInitialized ? _controller.value.duration : Duration.zero)}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
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
      decoration: BoxDecoration(
        color: Colors.white10,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white70, size: 18),
    );
  }

  // ─────────────────────────────────────────────
  // BOTTOM PANEL
  // ─────────────────────────────────────────────
  Widget _buildBottomPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timeline (tick marks + thumbnail strip)
          _buildTimeline(),

          // Audio row
          _buildTrackRow(
            icon: Icons.music_note,
            label: 'Tap to add audio',
            onTap: () {},
          ),

          // Divider
          Container(height: 0.5, color: Colors.white12,
              margin: const EdgeInsets.symmetric(horizontal: 0)),

          // Text row
          _buildTrackRow(
            iconWidget: const Text(
              'Aa',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            label: 'Tap to add text',
            onTap: _openTextEditor,
          ),

          const SizedBox(height: 12),

          // Hint
          const Text(
            'Tap on a track to trim. Pinch to zoom.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),

          const SizedBox(height: 12),

          // Tool chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildToolChip(Icons.text_fields, 'Text', onTap: _openTextEditor),
                _buildToolChip(Icons.sentiment_satisfied_alt, 'Sticker'),
                _buildToolChip(Icons.library_music_outlined, 'Audio'),
                _buildToolChip(Icons.video_library_outlined, 'Add clips'),
                _buildToolChip(Icons.layers_outlined, 'Overlay'),
                _buildToolChip(Icons.content_cut, 'Edit'),
                _buildToolChip(Icons.closed_caption_outlined, 'Captions'),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTrackRow({
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            iconWidget ??
                Icon(icon, color: Colors.white54, size: 16),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolChip(IconData icon, String label, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label coming soon')),
              );
            },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TIMELINE
  // ─────────────────────────────────────────────
  Widget _buildTimeline() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const horizontalPadding = 32.0;
        const handleWidth = 18.0;
        final usableWidth = totalWidth - horizontalPadding * 2;

        final leftX = horizontalPadding + usableWidth * _startFraction;
        final rightX = horizontalPadding + usableWidth * _endFraction;

        double playFraction = 0.0;
        if (_controller.value.isInitialized &&
            _videoDuration.inMilliseconds > 0) {
          playFraction = _controller.value.position.inMilliseconds /
              _videoDuration.inMilliseconds;
        }
        playFraction = playFraction.clamp(_startFraction, _endFraction);
        final playX = horizontalPadding + usableWidth * playFraction;

        // How many seconds the video is (for tick marks)
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
                // ── Tick marks row (dots + second labels)
                Positioned(
                  top: 0,
                  left: horizontalPadding,
                  right: horizontalPadding,
                  child: _buildTickMarks(usableWidth, totalSecs),
                ),

                // ── Thumbnail strip background
                Positioned(
                  top: 22,
                  left: leftX,
                  right: totalWidth - rightX,
                  height: 52,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _buildThumbnailStrip(),
                  ),
                ),

                // ── Dark overlay outside trim region (left)
                if (_startFraction > 0)
                  Positioned(
                    top: 22,
                    left: horizontalPadding,
                    width: leftX - horizontalPadding,
                    height: 52,
                    child: Container(color: Colors.black54),
                  ),

                // ── Dark overlay outside trim region (right)
                if (_endFraction < 1.0)
                  Positioned(
                    top: 22,
                    left: rightX,
                    right: horizontalPadding,
                    height: 52,
                    child: Container(color: Colors.black54),
                  ),

                // ── Left trim handle
                Positioned(
                  top: 22,
                  left: leftX - handleWidth / 2,
                  width: handleWidth,
                  height: 52,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final delta = details.delta.dx / usableWidth;
                        _startFraction =
                            (_startFraction + delta).clamp(0.0, _endFraction - 0.05);
                        final totalMs = _videoDuration.inMilliseconds;
                        _trimStart = Duration(
                            milliseconds:
                                (totalMs * _startFraction).toInt());
                        if (_controller.value.position < _trimStart) {
                          _controller.seekTo(_trimStart);
                        }
                      });
                    },
                    child: _buildHandle(),
                  ),
                ),

                // ── Right trim handle
                Positioned(
                  top: 22,
                  left: rightX - handleWidth / 2,
                  width: handleWidth,
                  height: 52,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final delta = details.delta.dx / usableWidth;
                        _endFraction =
                            (_endFraction + delta).clamp(_startFraction + 0.05, 1.0);
                        final totalMs = _videoDuration.inMilliseconds;
                        _trimEnd = Duration(
                            milliseconds:
                                (totalMs * _endFraction).toInt());
                        if (_controller.value.position > _trimEnd) {
                          _controller.seekTo(_trimEnd);
                        }
                      });
                    },
                    child: _buildHandle(),
                  ),
                ),

                // ── White playhead line (spans full timeline height)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: playX - 1,
                  width: 2,
                  child: Container(color: Colors.white),
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
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Icon(Icons.drag_handle, color: Colors.black45, size: 14),
      ),
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
}
