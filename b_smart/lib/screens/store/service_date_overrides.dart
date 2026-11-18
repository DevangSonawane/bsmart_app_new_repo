import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import 'publish/store_publish_ui.dart';
import 'store_theme.dart';

/// Per-date service availability overrides (`date_overrides` on an
/// influencer service).
///
/// A matching entry fully replaces the weekly pattern for that one date:
/// empty `slots` = the whole date is blocked, otherwise only those hours are
/// bookable. Mirrors the backend schema and the web `DateOverridesEditor`.

const kServiceBlockReasons = <String>[
  'unavailable',
  'fully_booked',
  'on_leave',
  'custom',
];

/// Max days a single date-range block expands into.
const kMaxBlockRangeDays = 60;

String serviceBlockReasonLabel(String reason) => switch (reason) {
      'fully_booked' => 'Fully Booked / Seats Full',
      'on_leave' => 'On Leave',
      'custom' => 'Custom Reason',
      _ => 'Unavailable',
    };

/// `yyyy-MM-dd` key for a calendar date (local date parts, no TZ shift).
String serviceDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "09:00" → minutes since midnight; null when malformed.
int? parseServiceHm(String value) {
  final parts = value.trim().split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

String _formatHm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _label12(String hm) {
  final minutes = parseServiceHm(hm);
  if (minutes == null) return hm;
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelve:${minute.toString().padLeft(2, '0')} $suffix';
}

class ServiceTimeRange {
  String start;
  String end;

  ServiceTimeRange(this.start, this.end);

  ServiceTimeRange copy() => ServiceTimeRange(start, end);

  String get label => '${_label12(start)} – ${_label12(end)}';
}

class ServiceDateOverride {
  DateTime date;
  List<ServiceTimeRange> slots;
  String reason;
  String customReason;

  ServiceDateOverride({
    required DateTime date,
    List<ServiceTimeRange>? slots,
    this.reason = 'unavailable',
    this.customReason = '',
  })  : date = _dateOnly(date),
        slots = slots ?? [];

  bool get wholeDay => slots.isEmpty;

  String get dateKey => serviceDateKey(date);

  /// Human-readable reason ("On Leave", or the custom text).
  String get reasonText => reason == 'custom' && customReason.trim().isNotEmpty
      ? customReason.trim()
      : serviceBlockReasonLabel(reason);

  String get hoursLabel => wholeDay
      ? 'Entire day blocked'
      : 'Only ${slots.map((s) => s.label).join(', ')}';

  ServiceDateOverride copy() => ServiceDateOverride(
        date: date,
        slots: [for (final s in slots) s.copy()],
        reason: reason,
        customReason: customReason,
      );

  Map<String, dynamic> toApi() => {
        'date': dateKey,
        'slots': [
          for (final s in slots) {'start': s.start, 'end': s.end},
        ],
        'reason': reason,
        if (reason == 'custom') 'custom_reason': customReason.trim(),
      };

  static ServiceDateOverride? fromApi(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final date = _parseApiDate(map['date']);
    if (date == null) return null;
    final slots = <ServiceTimeRange>[];
    final rawSlots = map['slots'];
    if (rawSlots is List) {
      for (final s in rawSlots) {
        if (s is! Map) continue;
        final start = s['start']?.toString() ?? '';
        final end = s['end']?.toString() ?? '';
        final a = parseServiceHm(start);
        final b = parseServiceHm(end);
        if (a == null || b == null || b <= a) continue;
        slots.add(ServiceTimeRange(start, end));
      }
    }
    final reason = map['reason']?.toString() ?? 'unavailable';
    return ServiceDateOverride(
      date: date,
      slots: slots,
      reason: kServiceBlockReasons.contains(reason) ? reason : 'unavailable',
      customReason: map['custom_reason']?.toString() ?? '',
    );
  }

  /// The API stores a Date (serialised as ISO, usually UTC midnight). Use the
  /// `yyyy-MM-dd` prefix so the calendar date never shifts with the device TZ.
  static DateTime? _parseApiDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }
}

/// Parses `date_overrides` from a service payload, sorted by date.
List<ServiceDateOverride> dateOverridesFromApi(dynamic raw) {
  if (raw is! List) return [];
  final out = <ServiceDateOverride>[];
  final seen = <String>{};
  for (final entry in raw) {
    final parsed = ServiceDateOverride.fromApi(entry);
    if (parsed == null || !seen.add(parsed.dateKey)) continue;
    out.add(parsed);
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

List<Map<String, dynamic>> dateOverridesToApi(List<ServiceDateOverride> list) =>
    [for (final o in list) o.toApi()];

/// The override for [date] on a raw service payload, if any.
ServiceDateOverride? findServiceDateOverride(
  Map<String, dynamic> service,
  DateTime date,
) {
  final key = serviceDateKey(date);
  for (final o in dateOverridesFromApi(service['date_overrides'])) {
    if (o.dateKey == key) return o;
  }
  return null;
}

String _serviceIdOf(Map<String, dynamic> service) =>
    (service['_id'] ?? service['id'] ?? '').toString();

String _serviceNameOf(Map<String, dynamic> service) =>
    (service['name'] ?? service['title'] ?? 'Service').toString();

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

/// Add / edit / remove UI for a service's blocked dates. Mutates [overrides]
/// in place and calls [onChanged], like the other publish-flow editors.
class DateOverridesEditor extends StatelessWidget {
  final List<ServiceDateOverride> overrides;
  final VoidCallback onChanged;

  const DateOverridesEditor({
    super.key,
    required this.overrides,
    required this.onChanged,
  });

  Future<void> _openForm(BuildContext context, {int? editIndex}) async {
    final editing = editIndex == null ? null : overrides[editIndex];
    final blocked = {
      for (final o in overrides)
        if (!identical(o, editing)) o.dateKey,
    };
    final result = await showModalBottomSheet<_FormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BStoreThemeScope(
        child: _DateOverrideFormSheet(
          initial: editing,
          blockedKeys: blocked,
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    if (editIndex != null) {
      overrides[editIndex] = result.entries.first;
    } else {
      overrides.addAll(result.entries);
    }
    overrides.sort((a, b) => a.date.compareTo(b.date));
    onChanged();
    if (result.skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skipped ${result.skipped} '
            '${result.skipped == 1 ? 'date that was' : 'dates that were'} '
            'already blocked.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overrides.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PublishStyle.fieldFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: PublishStyle.fieldBorder),
            ),
            child: const Text(
              'No blocked dates. Your weekly availability applies every day.',
              style: TextStyle(
                color: PublishStyle.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          for (var i = 0; i < overrides.length; i++) ...[
            _OverrideTile(
              entry: overrides[i],
              past: overrides[i].date.isBefore(today),
              onEdit: () => _openForm(context, editIndex: i),
              onRemove: () {
                overrides.removeAt(i);
                onChanged();
              },
            ),
            if (i != overrides.length - 1) const SizedBox(height: 8),
          ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: PublishAddButton(
            label: 'Block a date',
            icon: LucideIcons.calendarX,
            onTap: () => _openForm(context),
          ),
        ),
      ],
    );
  }
}

class _OverrideTile extends StatelessWidget {
  final ServiceDateOverride entry;
  final bool past;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _OverrideTile({
    required this.entry,
    required this.past,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = entry.wholeDay ? PublishStyle.danger : PublishStyle.purple;
    return Opacity(
      opacity: past ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PublishStyle.fieldBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                entry.wholeDay ? LucideIcons.calendarX : LucideIcons.clock,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEE, d MMM yyyy').format(entry.date) +
                        (past ? ' · past' : ''),
                    style: const TextStyle(
                      color: PublishStyle.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.hoursLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PublishStyle.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  PublishPill(label: entry.reasonText, color: color),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit',
              onPressed: onEdit,
              icon: const Icon(LucideIcons.pencil, size: 16),
              color: PublishStyle.muted,
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              icon: const Icon(LucideIcons.trash2, size: 16),
              color: PublishStyle.danger,
            ),
          ],
        ),
      ),
    );
  }
}

class _FormResult {
  final List<ServiceDateOverride> entries;
  final int skipped;

  const _FormResult(this.entries, this.skipped);
}

class _DateOverrideFormSheet extends StatefulWidget {
  final ServiceDateOverride? initial;
  final Set<String> blockedKeys;

  const _DateOverrideFormSheet({
    required this.initial,
    required this.blockedKeys,
  });

  @override
  State<_DateOverrideFormSheet> createState() => _DateOverrideFormSheetState();
}

class _DateOverrideFormSheetState extends State<_DateOverrideFormSheet> {
  bool _rangeMode = false;
  DateTime? _date;
  DateTimeRange? _range;
  bool _wholeDay = true;
  late List<ServiceTimeRange> _slots;
  String _reason = 'unavailable';
  final _customController = TextEditingController();
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _date = initial?.date;
    _wholeDay = initial?.wholeDay ?? true;
    _slots = initial == null || initial.wholeDay
        ? [ServiceTimeRange('09:00', '13:00')]
        : [for (final s in initial.slots) s.copy()];
    _reason = initial?.reason ?? 'unavailable';
    _customController.text = initial?.customReason ?? '';
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  DateTime get _today => _dateOnly(DateTime.now());
  DateTime get _lastDate => _today.add(const Duration(days: 365 * 2));

  bool _selectable(DateTime day) =>
      !widget.blockedKeys.contains(serviceDateKey(day));

  ThemeData _pickerTheme(BuildContext context) => Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: PublishStyle.teal,
              onPrimary: Colors.white,
            ),
      );

  Future<void> _pickDate() async {
    // initialDate must itself be selectable, or showDatePicker asserts.
    DateTime? initial = _date ?? _today;
    if (initial.isBefore(_today)) initial = _today;
    if (!_selectable(initial)) {
      initial = null;
      for (var d = _today;
          !d.isAfter(_lastDate);
          d = d.add(const Duration(days: 1))) {
        if (_selectable(d)) {
          initial = d;
          break;
        }
      }
      if (initial == null) return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _today,
      lastDate: _lastDate,
      helpText: 'Date to block',
      selectableDayPredicate: _selectable,
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = _dateOnly(picked);
      _error = null;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _today,
      lastDate: _lastDate,
      initialDateRange: _range,
      helpText: 'Dates to block',
      builder: (context, child) =>
          Theme(data: _pickerTheme(context), child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = DateTimeRange(
        start: _dateOnly(picked.start),
        end: _dateOnly(picked.end),
      );
      _error = null;
    });
  }

  Future<void> _pickTime(ServiceTimeRange slot, bool isStart) async {
    final minutes = parseServiceHm(isStart ? slot.start : slot.end) ?? 540;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        slot.start = _formatHm(picked);
      } else {
        slot.end = _formatHm(picked);
      }
      _error = null;
    });
  }

  String? _validate() {
    if (_rangeMode) {
      if (_range == null) return 'Pick a start and end date.';
      final days = _range!.end.difference(_range!.start).inDays + 1;
      if (days > kMaxBlockRangeDays) {
        return 'A range can cover at most $kMaxBlockRangeDays days.';
      }
    } else {
      if (_date == null) return 'Pick a date to block.';
      if (!_selectable(_date!)) return 'This date is already blocked.';
    }
    if (!_wholeDay) {
      if (_slots.isEmpty) return 'Add at least one time range.';
      final sorted = [..._slots]..sort((a, b) => (parseServiceHm(a.start) ?? 0)
          .compareTo(parseServiceHm(b.start) ?? 0));
      for (var i = 0; i < sorted.length; i++) {
        final start = parseServiceHm(sorted[i].start);
        final end = parseServiceHm(sorted[i].end);
        if (start == null || end == null || end <= start) {
          return 'Each time range needs an end after its start.';
        }
        if (i > 0 && (parseServiceHm(sorted[i - 1].end) ?? 0) > start) {
          return 'Time ranges must not overlap.';
        }
      }
    }
    if (_reason == 'custom' && _customController.text.trim().isEmpty) {
      return 'Enter a custom reason.';
    }
    return null;
  }

  ServiceDateOverride _entryFor(DateTime date) => ServiceDateOverride(
        date: date,
        slots: _wholeDay
            ? []
            : ([for (final s in _slots) s.copy()]..sort((a, b) =>
                (parseServiceHm(a.start) ?? 0)
                    .compareTo(parseServiceHm(b.start) ?? 0))),
        reason: _reason,
        customReason: _reason == 'custom' ? _customController.text.trim() : '',
      );

  void _submit() {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (!_rangeMode) {
      Navigator.of(context).pop(_FormResult([_entryFor(_date!)], 0));
      return;
    }
    final entries = <ServiceDateOverride>[];
    var skipped = 0;
    for (var d = _range!.start;
        !d.isAfter(_range!.end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      if (_selectable(d)) {
        entries.add(_entryFor(d));
      } else {
        skipped++;
      }
    }
    if (entries.isEmpty) {
      setState(() => _error = 'Every date in this range is already blocked.');
      return;
    }
    Navigator.of(context).pop(_FormResult(entries, skipped));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final fmt = DateFormat('EEE, d MMM yyyy');
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        decoration: const BoxDecoration(
          color: PublishStyle.canvas,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHeader(
              title: _editing ? 'Edit blocked date' : 'Block a date',
              subtitle: 'Overrides your weekly hours for the chosen date(s).',
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  if (!_editing) ...[
                    _Segmented(
                      options: const ['Single date', 'Date range'],
                      selected: _rangeMode ? 1 : 0,
                      onChanged: (i) => setState(() {
                        _rangeMode = i == 1;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const PublishFieldLabel('Date', required: true),
                  const SizedBox(height: 7),
                  _PickerBox(
                    icon: LucideIcons.calendarDays,
                    text: _rangeMode
                        ? (_range == null
                            ? 'Select date range'
                            : '${fmt.format(_range!.start)} → ${fmt.format(_range!.end)}')
                        : (_date == null ? 'Select date' : fmt.format(_date!)),
                    placeholder: _rangeMode ? _range == null : _date == null,
                    onTap: _rangeMode ? _pickRange : _pickDate,
                  ),
                  if (_rangeMode)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Each day becomes its own entry (max $kMaxBlockRangeDays days). '
                        'Dates already blocked are skipped.',
                        style: TextStyle(
                          color: PublishStyle.soft,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  const PublishFieldLabel('Availability on this date'),
                  const SizedBox(height: 7),
                  _Segmented(
                    options: const ['Entire day', 'Specific hours'],
                    selected: _wholeDay ? 0 : 1,
                    onChanged: (i) => setState(() {
                      _wholeDay = i == 0;
                      _error = null;
                    }),
                  ),
                  if (!_wholeDay) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Customers can book only inside these hours on this date.',
                      style: TextStyle(
                        color: PublishStyle.soft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _slots.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _PickerBox(
                                icon: LucideIcons.clock,
                                text: _label12(_slots[i].start),
                                onTap: () => _pickTime(_slots[i], true),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Text('–',
                                  style: TextStyle(color: PublishStyle.soft)),
                            ),
                            Expanded(
                              child: _PickerBox(
                                icon: LucideIcons.clock,
                                text: _label12(_slots[i].end),
                                onTap: () => _pickTime(_slots[i], false),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove range',
                              onPressed: _slots.length == 1
                                  ? null
                                  : () => setState(() => _slots.removeAt(i)),
                              icon: const Icon(LucideIcons.x, size: 16),
                              color: PublishStyle.muted,
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PublishAddButton(
                        label: 'Add time range',
                        onTap: () => setState(() {
                          final last = _slots.isEmpty ? null : _slots.last;
                          final from = parseServiceHm(last?.end ?? '') ?? 540;
                          final start = from.clamp(0, 22 * 60);
                          final end = (start + 60).clamp(0, 23 * 60 + 59);
                          String hm(int m) =>
                              '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
                          _slots.add(ServiceTimeRange(hm(start), hm(end)));
                        }),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  PublishSelectField<String>(
                    label: 'Reason',
                    required: true,
                    value: _reason,
                    items: kServiceBlockReasons,
                    labelBuilder: serviceBlockReasonLabel,
                    onChanged: (v) => setState(() {
                      _reason = v ?? _reason;
                      _error = null;
                    }),
                  ),
                  if (_reason == 'custom') ...[
                    const SizedBox(height: 12),
                    PublishField(
                      label: 'Custom reason',
                      required: true,
                      hint: 'e.g. Equipment maintenance',
                      controller: _customController,
                      maxLength: 120,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(_error!),
                  ],
                ],
              ),
            ),
            _SheetFooter(
              label: _editing ? 'Save changes' : 'Add block',
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick "Block dates" sheet from the services list
// ---------------------------------------------------------------------------

/// Opens the block-dates sheet for one service. Loads that service's current
/// blocks and saves by replacing them. Returns true when saved.
Future<bool> showBlockDatesForService(
  BuildContext context,
  Map<String, dynamic> service,
) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BStoreThemeScope(
      child: _BlockDatesSheet(services: [service], bulk: false),
    ),
  );
  return saved == true;
}

/// Opens the block-dates sheet in bulk mode: new blocks are *merged* into each
/// selected service's existing blocks (never replacing them). Returns true
/// when at least one service was updated.
Future<bool> showBulkBlockDates(
  BuildContext context,
  List<Map<String, dynamic>> services,
) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BStoreThemeScope(
      child: _BlockDatesSheet(services: services, bulk: true),
    ),
  );
  return saved == true;
}

class _BlockDatesSheet extends StatefulWidget {
  final List<Map<String, dynamic>> services;
  final bool bulk;

  const _BlockDatesSheet({required this.services, required this.bulk});

  @override
  State<_BlockDatesSheet> createState() => _BlockDatesSheetState();
}

class _BlockDatesSheetState extends State<_BlockDatesSheet> {
  final _api = Phase2StoreApi();
  final List<ServiceDateOverride> _overrides = [];
  final Set<String> _selected = {};
  bool _loading = false;
  bool _saving = false;
  String? _error;

  Map<String, dynamic> get _single => widget.services.first;

  @override
  void initState() {
    super.initState();
    if (!widget.bulk) _loadSingle();
  }

  Future<void> _loadSingle() async {
    setState(() => _loading = true);
    _overrides.addAll(dateOverridesFromApi(_single['date_overrides']));
    try {
      final fresh = await _api.getService(_serviceIdOf(_single));
      if (!mounted) return;
      if (fresh.containsKey('date_overrides')) {
        _overrides
          ..clear()
          ..addAll(dateOverridesFromApi(fresh['date_overrides']));
      }
    } catch (_) {
      // Fall back to the list payload already loaded above.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (!widget.bulk) {
        await _api.updateService(_serviceIdOf(_single), {
          'date_overrides': dateOverridesToApi(_overrides),
        });
        navigator.pop(true);
        messenger.showSnackBar(
          const SnackBar(content: Text('Blocked dates updated.')),
        );
        return;
      }
      if (_selected.isEmpty) {
        setState(() => _error = 'Select at least one service.');
        return;
      }
      if (_overrides.isEmpty) {
        setState(() => _error = 'Add at least one date to block.');
        return;
      }
      var updated = 0;
      final failed = <String>[];
      for (final service in widget.services) {
        final id = _serviceIdOf(service);
        if (!_selected.contains(id)) continue;
        try {
          var existingRaw = service['date_overrides'];
          try {
            final fresh = await _api.getService(id);
            if (fresh.containsKey('date_overrides')) {
              existingRaw = fresh['date_overrides'];
            }
          } catch (_) {}
          final merged = dateOverridesFromApi(existingRaw);
          final keys = {for (final o in merged) o.dateKey};
          for (final o in _overrides) {
            if (keys.add(o.dateKey)) merged.add(o.copy());
          }
          merged.sort((a, b) => a.date.compareTo(b.date));
          await _api.updateService(id, {
            'date_overrides': dateOverridesToApi(merged),
          });
          updated++;
        } catch (_) {
          failed.add(_serviceNameOf(service));
        }
      }
      if (failed.isNotEmpty) {
        if (!mounted) return;
        setState(() => _error = 'Could not update: ${failed.join(', ')}.'
            '${updated > 0 ? ' $updated other service(s) were updated.' : ''}');
        return;
      }
      navigator.pop(updated > 0);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Blocked dates added to $updated ${updated == 1 ? 'service' : 'services'}.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final allSelected = _selected.length == widget.services.length;
    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
      decoration: const BoxDecoration(
        color: PublishStyle.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            title: 'Block dates',
            subtitle: widget.bulk
                ? 'Add time off to several services at once. Existing blocks are kept.'
                : _serviceNameOf(_single),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                if (widget.bulk) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: PublishFieldLabel('Services', required: true),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          if (allSelected) {
                            _selected.clear();
                          } else {
                            _selected.addAll(widget.services.map(_serviceIdOf));
                          }
                        }),
                        child: Text(allSelected ? 'Clear' : 'Select all'),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: PublishStyle.fieldBorder),
                    ),
                    child: Column(
                      children: [
                        for (final s in widget.services)
                          CheckboxListTile(
                            dense: true,
                            value: _selected.contains(_serviceIdOf(s)),
                            activeColor: PublishStyle.teal,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              _serviceNameOf(s),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PublishStyle.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(_serviceIdOf(s));
                              } else {
                                _selected.remove(_serviceIdOf(s));
                              }
                              _error = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const PublishFieldLabel('Dates to block', required: true),
                  const SizedBox(height: 8),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  DateOverridesEditor(
                    overrides: _overrides,
                    onChanged: () => setState(() => _error = null),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(_error!),
                ],
              ],
            ),
          ),
          _SheetFooter(
            label: _saving
                ? 'Saving…'
                : widget.bulk
                    ? 'Apply to ${_selected.length} '
                        '${_selected.length == 1 ? 'service' : 'services'}'
                    : 'Save blocked dates',
            onTap: _saving || _loading ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared pieces
// ---------------------------------------------------------------------------

class _SheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SheetHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: PublishStyle.fieldBorder,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: PublishStyle.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PublishStyle.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(LucideIcons.x, size: 20),
                color: PublishStyle.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetFooter extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SheetFooter({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: PublishStyle.cardBorder)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: PublishStyle.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  const _Segmented({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PublishStyle.fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PublishStyle.fieldBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == selected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    options[i],
                    style: TextStyle(
                      color: i == selected
                          ? PublishStyle.teal
                          : PublishStyle.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool placeholder;
  final VoidCallback onTap;

  const _PickerBox({
    required this.icon,
    required this.text,
    required this.onTap,
    this.placeholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: PublishStyle.fieldFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PublishStyle.fieldBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: PublishStyle.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: placeholder ? PublishStyle.soft : PublishStyle.ink,
                  fontSize: 12.5,
                  fontWeight: placeholder ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB3261E),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
