import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

class ReelVoiceRecorderSheet extends StatefulWidget {
  final ValueChanged<({String path, String filterId})> onConfirm;

  const ReelVoiceRecorderSheet({
    super.key,
    required this.onConfirm,
  });

  @override
  State<ReelVoiceRecorderSheet> createState() => _ReelVoiceRecorderSheetState();
}

class _ReelVoiceRecorderSheetState extends State<ReelVoiceRecorderSheet> {
  bool _recording = false;
  Timer? _waveTimer;
  final List<double> _bars = List<double>.filled(20, 4);
  String? _recordedPath;
  Duration _recordedDuration = Duration.zero;
  String _selectedFilter = 'None';

  @override
  void dispose() {
    _waveTimer?.cancel();
    super.dispose();
  }

  void _toggleRecord() async {
    if (_recording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _recordedPath = null;
      _recordedDuration = Duration.zero;
    });
    _waveTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      setState(() {
        for (int i = 0; i < _bars.length; i++) {
          _bars[i] = 4 + (i % 5) * 4 + (DateTime.now().millisecond % 10);
          if (_bars[i] > 28) _bars[i] = 28;
        }
      });
    });
  }

  Future<void> _stopRecording() async {
    _waveTimer?.cancel();
    setState(() {
      _recording = false;
      _bars.fillRange(0, _bars.length, 4);
    });
    // Simulated 3s recording
    _recordedDuration = const Duration(seconds: 3);
    final path =
        '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
    await File(path).writeAsBytes([], flush: true);
    setState(() => _recordedPath = path);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.65;
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Voice over', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _toggleRecord,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _recording ? Colors.red : Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _bars
                .map((h) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        width: 3,
                        height: h,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('None'),
                _filterChip('Robot'),
                _filterChip('Chipmunk'),
                _filterChip('Echo'),
                _filterChip('Deep'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_recordedPath != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_recordedDuration),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          const Spacer(),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(() {
                  _recordedPath = null;
                  _recordedDuration = Duration.zero;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text('Retake'),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _recordedPath == null
                    ? null
                    : () => widget.onConfirm(
                          (path: _recordedPath!, filterId: _selectedFilter),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0095F6),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Use voice →'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(999),
            border: isSelected
                ? Border.all(color: const Color(0xFF0095F6), width: 1.5)
                : null,
          ),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final s = d.inSeconds;
    return '0:${s.toString().padLeft(2, '0')}';
  }
}
