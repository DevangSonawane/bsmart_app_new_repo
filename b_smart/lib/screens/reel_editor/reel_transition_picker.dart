import 'package:flutter/material.dart';

class ReelTransitionPicker extends StatefulWidget {
  final String initialType;
  final double initialDurationMs;
  final void Function(String type, double durationMs) onApply;

  const ReelTransitionPicker({
    super.key,
    required this.initialType,
    required this.initialDurationMs,
    required this.onApply,
  });

  @override
  State<ReelTransitionPicker> createState() => _ReelTransitionPickerState();
}

class _ReelTransitionPickerState extends State<ReelTransitionPicker> {
  late String _type;
  late double _durationMs;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _durationMs = widget.initialDurationMs;
  }

  @override
  Widget build(BuildContext context) {
    final durationSec = (_durationMs / 1000).toStringAsFixed(1);
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text('Transition', style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 90 / 70,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _tile('None', Icons.content_cut, 'none'),
                _tile('Fade', Icons.opacity, 'fade'),
                _tile('Slide', Icons.arrow_forward, 'slide_left'),
                _tile('Zoom', Icons.zoom_in, 'zoom'),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Duration: ${durationSec}s', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    Slider(
                      value: _durationMs.clamp(100, 1000),
                      min: 100,
                      max: 1000,
                      onChanged: (v) => setState(() => _durationMs = v),
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => widget.onApply(_type, _durationMs),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, IconData icon, String type) {
    final selected = _type == type;
    return GestureDetector(
      onTap: () => setState(() => _type = type),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF0095F6) : Colors.white24, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
