import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../features/reel_timeline/reel_timeline_models.dart';
import '../../models/media_model.dart' as app_models;

class ReelClipContextMenu extends StatefulWidget {
  final ReelClip clip;
  final VoidCallback onSplit;
  final VoidCallback onDuplicate;
  final ValueChanged<app_models.MediaItem> onReplace;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onReverse;
  final VoidCallback onFreeze;
  final VoidCallback onDelete;

  const ReelClipContextMenu({
    super.key,
    required this.clip,
    required this.onSplit,
    required this.onDuplicate,
    required this.onReplace,
    required this.onSpeedChanged,
    required this.onReverse,
    required this.onFreeze,
    required this.onDelete,
  });

  @override
  State<ReelClipContextMenu> createState() => _ReelClipContextMenuState();
}

class _ReelClipContextMenuState extends State<ReelClipContextMenu> {
  bool _showSpeed = false;
  bool _confirmDelete = false;
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    _speed = widget.clip.speed;
  }

  Future<void> _pickReplacement() async {
    final picker = ImagePicker();
    final picked = await picker.pickMedia();
    if (picked == null) return;

    final isVideo = picked.mimeType?.startsWith('video') ?? picked.path.toLowerCase().endsWith('.mp4');
    Duration? duration;
    if (isVideo) {
      final controller = VideoPlayerController.file(File(picked.path));
      await controller.initialize();
      duration = controller.value.duration;
      await controller.dispose();
    }

    final media = app_models.MediaItem(
      id: 'replace_${DateTime.now().millisecondsSinceEpoch}',
      type: isVideo ? app_models.MediaType.video : app_models.MediaType.image,
      filePath: picked.path,
      duration: duration,
      createdAt: DateTime.now(),
    );
    widget.onReplace(media);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 84,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _pill('Split', Icons.call_split, onTap: widget.onSplit),
                  const SizedBox(width: 8),
                  _pill('Duplicate', Icons.copy, onTap: widget.onDuplicate),
                  const SizedBox(width: 8),
                  _pill('Replace', Icons.swap_horiz, onTap: _pickReplacement),
                  const SizedBox(width: 8),
                  _pill('Speed', Icons.speed, onTap: () => setState(() => _showSpeed = !_showSpeed)),
                  const SizedBox(width: 8),
                  _pill('Reverse', Icons.replay, onTap: widget.onReverse),
                  const SizedBox(width: 8),
                  _pill('Freeze', Icons.pause_circle_outline, onTap: widget.onFreeze),
                  const SizedBox(width: 8),
                  _pill(
                    'Delete',
                    Icons.delete_outline,
                    onTap: () => setState(() => _confirmDelete = true),
                    color: const Color(0xFFFF3B30),
                  ),
                ],
              ),
            ),
          ),
          if (_showSpeed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  const Text('0.1x', style: TextStyle(color: Colors.white, fontSize: 11)),
                  Expanded(
                    child: Slider(
                      value: _speed.clamp(0.1, 4.0),
                      min: 0.1,
                      max: 4.0,
                      divisions: 39,
                      onChanged: (v) {
                        setState(() => _speed = v);
                        widget.onSpeedChanged(v);
                      },
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                  Text('${_speed.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white, fontSize: 11)),
                ],
              ),
            ),
          if (_confirmDelete)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: widget.onDelete,
                    child: const Text('Delete clip', style: TextStyle(color: Color(0xFFFF3B30))),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _confirmDelete = false),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon, {required VoidCallback onTap, Color? color}) {
    final tint = color ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: tint, size: 14),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: tint, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
