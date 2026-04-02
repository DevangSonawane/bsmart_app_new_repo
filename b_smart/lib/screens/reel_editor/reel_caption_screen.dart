import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ReelCaption {
  final double startMs;
  final double endMs;
  final String text;

  const ReelCaption({
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  ReelCaption copyWith({double? startMs, double? endMs, String? text}) {
    return ReelCaption(
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      text: text ?? this.text,
    );
  }
}

class ReelCaptionScreen extends StatefulWidget {
  final String videoPath;
  final List<ReelCaption> initialCaptions;
  final ValueChanged<List<ReelCaption>> onSave;

  const ReelCaptionScreen({
    super.key,
    required this.videoPath,
    required this.initialCaptions,
    required this.onSave,
  });

  @override
  State<ReelCaptionScreen> createState() => _ReelCaptionScreenState();
}

class _ReelCaptionScreenState extends State<ReelCaptionScreen> {
  VideoPlayerController? _controller;
  List<ReelCaption> _captions = [];

  @override
  void initState() {
    super.initState();
    _captions = widget.initialCaptions.isNotEmpty
        ? List<ReelCaption>.from(widget.initialCaptions)
        : _buildPlaceholderCaptions();
    final controller = VideoPlayerController.file(File(widget.videoPath));
    _controller = controller;
    controller.initialize().then((_) {
      if (!mounted) return;
      controller.setLooping(true);
      controller.setVolume(0.0);
      controller.play();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<ReelCaption> _buildPlaceholderCaptions() {
    return const [
      ReelCaption(startMs: 0, endMs: 1000, text: 'Caption 1'),
      ReelCaption(startMs: 1200, endMs: 2400, text: 'Caption 2'),
      ReelCaption(startMs: 2600, endMs: 3600, text: 'Caption 3'),
    ];
  }

  void _addCaptionAtPlayhead() {
    final pos = _controller?.value.position.inMilliseconds.toDouble() ?? 0.0;
    setState(() {
      _captions.add(ReelCaption(startMs: pos, endMs: pos + 1000, text: ''));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Captions'),
        actions: [
          TextButton(
            onPressed: () {
              widget.onSave(_captions);
              Navigator.of(context).pop();
            },
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCaptionAtPlayhead,
        backgroundColor: Colors.white,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: _controller != null && _controller!.value.isInitialized
                    ? VideoPlayer(_controller!)
                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _captions.length,
              itemBuilder: (context, index) {
                final c = _captions[index];
                final controller = TextEditingController(text: c.text);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatRange(c.startMs, c.endMs),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Add caption…',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                          onChanged: (v) {
                            _captions[index] = c.copyWith(text: v);
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatRange(double startMs, double endMs) {
    String fmt(double ms) {
      final d = Duration(milliseconds: ms.toInt());
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '${fmt(startMs)} – ${fmt(endMs)}';
  }
}
