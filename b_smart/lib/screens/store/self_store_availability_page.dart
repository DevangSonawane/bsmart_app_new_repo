import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import 'shared/store_shared_widgets.dart';
import 'store_models.dart';

/// Seller editor for `weekly_availability`.
///
/// An empty slot list for a weekday means Unavailable (matches buyer UI +
/// server validation in the Phase 2 spec).
class SelfStoreAvailabilityScreen extends StatelessWidget {
  final String serviceId;
  final String serviceName;
  final Map<String, dynamic> initialAvailability;

  const SelfStoreAvailabilityScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.initialAvailability,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFC),
      body: SafeArea(
        top: false,
        child: SelfStoreAvailabilityPage(
          serviceId: serviceId,
          serviceName: serviceName,
          initialAvailability: initialAvailability,
        ),
      ),
    );
  }
}

class SelfStoreAvailabilityPage extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final Map<String, dynamic> initialAvailability;

  const SelfStoreAvailabilityPage({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.initialAvailability,
  });

  @override
  State<SelfStoreAvailabilityPage> createState() =>
      _SelfStoreAvailabilityPageState();
}

class _DayWindow {
  bool enabled;
  TimeOfDay start;
  TimeOfDay end;

  _DayWindow({
    required this.enabled,
    required this.start,
    required this.end,
  });
}

class _SelfStoreAvailabilityPageState
    extends State<SelfStoreAvailabilityPage> {
  static const _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const _labels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late final Map<String, _DayWindow> _windows;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _windows = {
      for (final day in _days) day: _parseDay(day, widget.initialAvailability),
    };
  }

  static TimeOfDay? _parseTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static _DayWindow _parseDay(String day, Map<String, dynamic> raw) {
    const fallback = TimeOfDay(hour: 9, minute: 0);
    const fallbackEnd = TimeOfDay(hour: 17, minute: 0);
    final slots = raw[day];
    if (slots is List && slots.isNotEmpty && slots.first is Map) {
      final first = Map<String, dynamic>.from(slots.first as Map);
      final start =
          _parseTime(first['start']?.toString() ?? '') ?? fallback;
      final end = _parseTime(first['end']?.toString() ?? '') ?? fallbackEnd;
      return _DayWindow(enabled: true, start: start, end: end);
    }
    return _DayWindow(
        enabled: false, start: fallback, end: fallbackEnd);
  }

  static String _format(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(String day, bool isStart) async {
    final window = _windows[day]!;
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? window.start : window.end,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        window.start = picked;
      } else {
        window.end = picked;
      }
    });
  }

  Future<void> _save() async {
    for (final day in _days) {
      final window = _windows[day]!;
      if (!window.enabled) continue;
      final start = window.start.hour * 60 + window.start.minute;
      final end = window.end.hour * 60 + window.end.minute;
      if (end <= start) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_labels[_days.indexOf(day)]}: end time must be after start time.'),
          ),
        );
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await Phase2StoreApi().updateService(widget.serviceId, {
        'weekly_availability': {
          for (final day in _days)
            day: _windows[day]!.enabled
                ? [
                    {
                      'start': _format(_windows[day]!.start),
                      'end': _format(_windows[day]!.end),
                    }
                  ]
                : [],
        },
      });
      await StoreMockState.instance.refreshMarketplace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Availability updated.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 14,
        18,
        MediaQuery.of(context).padding.bottom + 18,
      ),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.arrowLeft, size: 22),
              color: const Color(0xFF060D35),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly availability',
                    style: TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    widget.serviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF29304D),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Buyers can only book inside these windows. Days off stay empty (Unavailable).',
          style: TextStyle(
            color: Color(0xFF29304D),
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _days.length; i++)
          _DayRow(
            label: _labels[i],
            window: _windows[_days[i]]!,
            onToggle: (value) =>
                setState(() => _windows[_days[i]]!.enabled = value),
            onStartTap: () => _pickTime(_days[i], true),
            onEndTap: () => _pickTime(_days[i], false),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF078D92),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: Text(
              _saving ? 'Saving...' : 'Save availability',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  final String label;
  final _DayWindow window;
  final ValueChanged<bool> onToggle;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;

  const _DayRow({
    required this.label,
    required this.window,
    required this.onToggle,
    required this.onStartTap,
    required this.onEndTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  window.enabled ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    color: window.enabled
                        ? const Color(0xFF078D92)
                        : const Color(0xFF6E748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Switch.adaptive(
                  value: window.enabled,
                  activeThumbColor: const Color(0xFF078D92),
                  onChanged: onToggle,
                ),
              ],
            ),
            if (window.enabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: 'Start',
                      value: _formatTime(window.start),
                      onTap: onStartTap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TimeButton(
                      label: 'End',
                      value: _formatTime(window.end),
                      onTap: onEndTap,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $suffix';
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D9E0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6E748B),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF060D35),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
