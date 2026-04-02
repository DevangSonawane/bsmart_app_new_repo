import 'package:flutter/material.dart';

class ReelOverlayDurationSheet extends StatefulWidget {
  final double totalDurationMs;
  final double startMs;
  final double endMs;
  final ValueChanged<({double startMs, double endMs})> onApply;

  const ReelOverlayDurationSheet({
    super.key,
    required this.totalDurationMs,
    required this.startMs,
    required this.endMs,
    required this.onApply,
  });

  @override
  State<ReelOverlayDurationSheet> createState() => _ReelOverlayDurationSheetState();
}

class _ReelOverlayDurationSheetState extends State<ReelOverlayDurationSheet> {
  late double _startMs;
  late double _endMs;

  @override
  void initState() {
    super.initState();
    _startMs = widget.startMs;
    _endMs = widget.endMs;
  }

  @override
  Widget build(BuildContext context) {
    final maxMs = widget.totalDurationMs <= 0 ? 1.0 : widget.totalDurationMs;
    return Container(
      height: 220,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Start', style: TextStyle(color: Colors.white)),
              Text('End', style: TextStyle(color: Colors.white)),
            ],
          ),
          Slider(
            value: _startMs.clamp(0.0, maxMs),
            min: 0,
            max: maxMs,
            onChanged: (v) {
              final next = v.clamp(0.0, _endMs - 500);
              setState(() => _startMs = next);
            },
            activeColor: const Color(0xFF0095F6),
          ),
          Slider(
            value: _endMs.clamp(0.0, maxMs),
            min: 0,
            max: maxMs,
            onChanged: (v) {
              final next = v.clamp(_startMs + 500, maxMs);
              setState(() => _endMs = next);
            },
            activeColor: const Color(0xFF0095F6),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onApply((startMs: _startMs, endMs: _endMs)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0095F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
