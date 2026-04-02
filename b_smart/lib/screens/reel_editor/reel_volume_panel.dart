import 'package:flutter/material.dart';

class ReelVolumePanel extends StatefulWidget {
  final double musicVolume;
  final double voiceVolume;
  final double originalVolume;
  final ValueChanged<({double music, double voice, double original})> onChanged;

  const ReelVolumePanel({
    super.key,
    required this.musicVolume,
    required this.voiceVolume,
    required this.originalVolume,
    required this.onChanged,
  });

  @override
  State<ReelVolumePanel> createState() => _ReelVolumePanelState();
}

class _ReelVolumePanelState extends State<ReelVolumePanel> {
  late double _music;
  late double _voice;
  late double _original;

  @override
  void initState() {
    super.initState();
    _music = widget.musicVolume;
    _voice = widget.voiceVolume;
    _original = widget.originalVolume;
  }

  void _notify() {
    widget.onChanged((music: _music, voice: _voice, original: _original));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          _sliderRow(
            icon: Icons.graphic_eq,
            label: 'Music',
            value: _music,
            onChanged: (v) {
              setState(() => _music = v);
              _notify();
            },
          ),
          _sliderRow(
            icon: Icons.mic_none,
            label: 'Voice',
            value: _voice,
            onChanged: (v) {
              setState(() => _voice = v);
              _notify();
            },
          ),
          _sliderRow(
            icon: Icons.movie,
            label: 'Original',
            value: _original,
            onChanged: (v) {
              setState(() => _original = v);
              _notify();
            },
          ),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required IconData icon,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (value * 100).round().toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  trackHeight: 3,
                ),
                child: Slider(
                  value: value,
                  min: 0.0,
                  max: 1.0,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
