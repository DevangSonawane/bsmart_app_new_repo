import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../services/supabase_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_shared_widgets.dart';

class VisitorServiceBookingFlowPage extends StatefulWidget {
  final String? ownerUserId;
  final String imageAsset;
  final String title;
  final String duration;
  final String price;

  const VisitorServiceBookingFlowPage({
    super.key,
    required this.ownerUserId,
    required this.imageAsset,
    required this.title,
    required this.duration,
    required this.price,
  });

  @override
  State<VisitorServiceBookingFlowPage> createState() =>
      _VisitorServiceBookingFlowPageState();
}

class _VisitorServiceBookingFlowPageState
    extends State<VisitorServiceBookingFlowPage> {
  late final Future<_BookingProvider?> _providerFuture;
  int _step = 0;
  late DateTime _selectedDate;
  late DateTime _dateWindowStart;
  String _selectedTime = '10:00 AM';
  String _selectedDuration = '2-3 hrs';
  bool _useBCoins = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
    _dateWindowStart = _selectedDate;
    _providerFuture = _loadProvider();
  }

  List<_BookingDate> get _visibleDates {
    return List.generate(
      5,
      (index) => _BookingDate(_dateWindowStart.add(Duration(days: index))),
    );
  }

  _BookingDate get _selectedBookingDate => _BookingDate(_selectedDate);

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 180)),
      helpText: 'Select availability',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF078D92),
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;
    final selected = _dateOnly(picked);
    setState(() {
      _selectedDate = selected;
      _dateWindowStart = selected;
    });
  }

  Future<_BookingProvider?> _loadProvider() async {
    final ownerId = widget.ownerUserId?.trim();
    if (ownerId == null || ownerId.isEmpty) return null;

    final user = await SupabaseService().getUserById(ownerId);
    if (user == null) return null;

    final name = _firstString(user, const [
      'full_name',
      'fullName',
      'displayName',
      'name',
      'username',
    ]);
    final avatarUrl = UrlHelper.absoluteUrl(
      _firstString(user, const [
            'avatar_url',
            'avatarUrl',
            'profile_picture',
            'profilePicture',
            'profile_image',
            'profileImage',
            'photoUrl',
            'avatar',
          ]) ??
          '',
    );

    Map<String, String>? avatarHeaders;
    if (avatarUrl.isNotEmpty && UrlHelper.shouldAttachAuthHeader(avatarUrl)) {
      final token = await ApiClient().getToken();
      if (token != null && token.isNotEmpty) {
        avatarHeaders = {'Authorization': 'Bearer $token'};
      }
    }

    return _BookingProvider(
      name: name ?? 'Store owner',
      avatarUrl: avatarUrl,
      avatarHeaders: avatarHeaders,
    );
  }

  static String? _firstString(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BookingProvider?>(
      future: _providerFuture,
      builder: (context, snapshot) {
        final provider = snapshot.data;
        return Scaffold(
          backgroundColor: const Color(0xFFFFFEFC),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 18,
                      16,
                      _step == 3 ? 18 : 8,
                    ),
                    children: [
                      _BookingHeader(
                        title: switch (_step) {
                          0 => 'Select availability',
                          1 => 'Review request',
                          2 => 'Payment',
                          _ => 'Request sent',
                        },
                        onBack: () {
                          if (_step == 0) {
                            Navigator.of(context).maybePop();
                          } else {
                            setState(() => _step -= 1);
                          }
                        },
                      ),
                      SizedBox(height: _step == 0 ? 26 : 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: switch (_step) {
                          0 => _SelectAvailabilityStep(
                              key: const ValueKey('availability'),
                              dates: _visibleDates,
                              selectedDate: _selectedDate,
                              selectedTime: _selectedTime,
                              selectedDuration: _selectedDuration,
                              onDateSelected: (date) {
                                setState(() => _selectedDate = date);
                              },
                              onCalendarTap: _pickDate,
                              onTimeSelected: (time) {
                                setState(() => _selectedTime = time);
                              },
                              onDurationChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedDuration = value);
                              },
                            ),
                          1 => _ReviewRequestStep(
                              key: const ValueKey('review'),
                              service: widget,
                              provider: provider,
                              selectedDate: _selectedBookingDate,
                              selectedTime: _selectedTime,
                              selectedDuration: _selectedDuration,
                              useBCoins: _useBCoins,
                              onUseBCoinsChanged: (value) {
                                setState(() => _useBCoins = value);
                              },
                            ),
                          2 => _PaymentStep(
                              key: const ValueKey('payment'),
                              amount: widget.price,
                            ),
                          _ => _RequestSentStep(
                              key: const ValueKey('sent'),
                              providerName: provider?.name ?? 'the provider',
                            ),
                        },
                      ),
                    ],
                  ),
                ),
                if (_step < 3)
                  _BookingFooterButton(
                    label: switch (_step) {
                      0 => 'Continue',
                      1 => 'Send request',
                      _ => 'Pay ${widget.price}',
                    },
                    icon: _step == 2 ? LucideIcons.lockKeyhole : null,
                    onPressed: () => setState(() => _step += 1),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BookingHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _BookingHeader({
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(LucideIcons.chevronLeft, size: 23),
              color: const Color(0xFF060D35),
              tooltip: 'Back',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            ),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF060D35),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingDate {
  final DateTime value;

  const _BookingDate(this.value);

  String get day => DateFormat('E').format(value);
  String get date => DateFormat('d').format(value);
  String get month => DateFormat('MMM').format(value);
  String get heading => DateFormat('MMMM d').format(value);

  bool isSameDay(DateTime other) {
    return value.year == other.year &&
        value.month == other.month &&
        value.day == other.day;
  }
}

class _BookingProvider {
  final String name;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;

  const _BookingProvider({
    required this.name,
    required this.avatarUrl,
    required this.avatarHeaders,
  });
}

class _SelectAvailabilityStep extends StatelessWidget {
  final List<_BookingDate> dates;
  final DateTime selectedDate;
  final String selectedTime;
  final String selectedDuration;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onCalendarTap;
  final ValueChanged<String> onTimeSelected;
  final ValueChanged<String?> onDurationChanged;

  const _SelectAvailabilityStep({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedDuration,
    required this.onDateSelected,
    required this.onCalendarTap,
    required this.onTimeSelected,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < dates.length; i++) ...[
                Expanded(
                  child: _DateChip(
                    date: dates[i],
                    selected: dates[i].isSameDay(selectedDate),
                    onTap: () => onDateSelected(dates[i].value),
                  ),
                ),
                const SizedBox(width: 5),
              ],
              _CalendarChip(onTap: onCalendarTap),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _BookingDate(selectedDate).heading,
          style: const TextStyle(
            color: Color(0xFF060D35),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        const _SlotHeading('Morning'),
        const SizedBox(height: 10),
        _TimeGrid(
          times: const ['10:00 AM', '11:00 AM', '12:00 PM'],
          selectedTime: selectedTime,
          onTimeSelected: onTimeSelected,
        ),
        const SizedBox(height: 18),
        const _SlotHeading('Afternoon'),
        const SizedBox(height: 10),
        _TimeGrid(
          times: const ['1:00 PM', '2:00 PM', '3:00 PM'],
          selectedTime: selectedTime,
          onTimeSelected: onTimeSelected,
        ),
        const SizedBox(height: 18),
        _BookingSelectTile(
          icon: LucideIcons.clock3,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedDuration,
              isExpanded: true,
              icon: const Icon(LucideIcons.chevronDown, size: 18),
              items: const [
                DropdownMenuItem(value: '1-2 hrs', child: Text('1-2 hrs')),
                DropdownMenuItem(value: '2-3 hrs', child: Text('2-3 hrs')),
                DropdownMenuItem(value: '3-4 hrs', child: Text('3-4 hrs')),
              ],
              onChanged: onDurationChanged,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _BookingSelectTile(
          icon: LucideIcons.mapPin,
          trailing: LucideIcons.chevronRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Service address'),
              SizedBox(height: 2),
              Text(
                '24 Market Street',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final _BookingDate date;
  final bool selected;
  final VoidCallback onTap;

  const _DateChip({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF7F6) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF078D92) : const Color(0xFFE2E6EA),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF078D92)
                    : const Color(0xFF060D35),
                fontSize: 9,
                height: 1.05,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date.date,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF078D92)
                    : const Color(0xFF060D35),
                fontSize: 13.5,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              date.month,
              style: const TextStyle(
                color: Color(0xFF29304D),
                fontSize: 9,
                height: 1.05,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarChip extends StatelessWidget {
  final VoidCallback onTap;

  const _CalendarChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 58,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E6EA)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            LucideIcons.calendarDays,
            color: Color(0xFF060D35),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _SlotHeading extends StatelessWidget {
  final String label;

  const _SlotHeading(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF684AC8),
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _TimeGrid extends StatelessWidget {
  final List<String> times;
  final String selectedTime;
  final ValueChanged<String> onTimeSelected;

  const _TimeGrid({
    required this.times,
    required this.selectedTime,
    required this.onTimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < times.length; i++) ...[
          Expanded(
            child: _TimeChip(
              label: times[i],
              selected: selectedTime == times[i],
              onTap: () => onTimeSelected(times[i]),
            ),
          ),
          if (i != times.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? const Color(0xFF078D92) : Colors.white,
          foregroundColor: selected ? Colors.white : const Color(0xFF060D35),
          side: BorderSide(
            color: selected ? const Color(0xFF078D92) : const Color(0xFFE1E5EA),
          ),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _BookingSelectTile extends StatelessWidget {
  final IconData icon;
  final Widget child;
  final IconData? trailing;

  const _BookingSelectTile({
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: storeSoftCardDecoration(radius: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF29304D), size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Color(0xFF29304D),
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
              child: child,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Icon(trailing, color: const Color(0xFF29304D), size: 18),
          ],
        ],
      ),
    );
  }
}

class _ReviewRequestStep extends StatelessWidget {
  final VisitorServiceBookingFlowPage service;
  final _BookingProvider? provider;
  final _BookingDate selectedDate;
  final String selectedTime;
  final String selectedDuration;
  final bool useBCoins;
  final ValueChanged<bool> onUseBCoinsChanged;

  const _ReviewRequestStep({
    super.key,
    required this.service,
    required this.provider,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedDuration,
    required this.useBCoins,
    required this.onUseBCoinsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final providerName = provider?.name ?? 'Store owner';
    return Column(
      children: [
        Container(
          decoration: storeSoftCardDecoration(radius: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: _ReviewServiceSummary(
                  service: service,
                  provider: provider,
                  providerName: providerName,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ReviewInfoRow(
                            icon: LucideIcons.calendarDays,
                            text: selectedDate.heading,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ReviewInfoRow(
                            icon: LucideIcons.clock,
                            text: selectedTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ReviewInfoRow(
                      icon: LucideIcons.clock3,
                      text: selectedDuration,
                    ),
                    const SizedBox(height: 10),
                    const _ReviewInfoRow(
                      icon: LucideIcons.mapPin,
                      text: '24 Market Street',
                    ),
                  ],
                ),
              ),
              const _ReviewDivider(),
              const _ReviewActionRow(
                icon: LucideIcons.penLine,
                title: 'Add a note',
              ),
              const _ReviewDivider(),
              _ReviewBCoinsRow(
                value: useBCoins,
                onChanged: onUseBCoinsChanged,
              ),
              const _ReviewDivider(),
              const _ReviewPaymentRow(),
              const _ReviewDivider(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Estimated total',
                        style: TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      service.price,
                      style: const TextStyle(
                        color: Color(0xFF078D92),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.info, color: Color(0xFF6E748B), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You will only be charged after $providerName confirms.',
                  style: const TextStyle(
                    color: Color(0xFF29304D),
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewServiceSummary extends StatelessWidget {
  final VisitorServiceBookingFlowPage service;
  final _BookingProvider? provider;
  final String providerName;

  const _ReviewServiceSummary({
    required this.service,
    required this.provider,
    required this.providerName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            service.imageAsset,
            width: 92,
            height: 92,
            fit: BoxFit.cover,
            cacheWidth: 260,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _ReviewProviderAvatar(provider: provider),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewProviderAvatar extends StatelessWidget {
  final _BookingProvider? provider;

  const _ReviewProviderAvatar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final name = provider?.name ?? 'Store owner';
    final initial =
        name.trim().isEmpty ? 'S' : name.characters.first.toUpperCase();
    return ClipOval(
      child: Container(
        width: 42,
        height: 42,
        color: const Color(0xFFEAD8CC),
        alignment: Alignment.center,
        child: provider?.avatarUrl.trim().isNotEmpty == true
            ? SafeNetworkImage(
                url: provider!.avatarUrl,
                headers: provider!.avatarHeaders,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                debugLabel: 'service-booking-review-provider-avatar',
                errorWidget: Text(
                  initial,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : Text(
                initial,
                style: const TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _ReviewInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ReviewInfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF29304D), size: 18),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF29304D),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewActionRow extends StatelessWidget {
  final IconData icon;
  final String title;

  const _ReviewActionRow({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF29304D), size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF29304D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: Color(0xFF29304D),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewBCoinsRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ReviewBCoinsRow({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
        child: Row(
          children: [
            const _ReviewBCoinIcon(),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Use bCoins',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF29304D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Text(
              'You have 120 bCoins',
              style: TextStyle(
                color: Color(0xFF29304D),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: value,
                activeThumbColor: const Color(0xFF078D92),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewBCoinIcon extends StatelessWidget {
  const _ReviewBCoinIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF078D92),
        shape: BoxShape.circle,
      ),
      child: const Text(
        'B',
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReviewPaymentRow extends StatelessWidget {
  const _ReviewPaymentRow();

  @override
  Widget build(BuildContext context) {
    return const _ReviewActionRow(
      icon: LucideIcons.creditCard,
      title: 'Visa  •••• 4821',
    );
  }
}

class _ReviewDivider extends StatelessWidget {
  const _ReviewDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFE8EBF0),
    );
  }
}

class _PaymentStep extends StatefulWidget {
  final String amount;

  const _PaymentStep({super.key, required this.amount});

  @override
  State<_PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends State<_PaymentStep> {
  int _selectedMethod = 0;
  bool _useDeliveryAddress = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AmountDueCard(amount: widget.amount),
        const SizedBox(height: 14),
        const Text(
          'Choose payment method',
          style: TextStyle(
            color: Color(0xFF060D35),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        _PaymentMethodTile(
          selected: _selectedMethod == 0,
          title: 'Visa •••• 4821',
          subtitle: 'Expires 08/29',
          badge: 'Selected',
          iconChild: const Text(
            'VISA',
            style: TextStyle(
              color: Color(0xFF2445B8),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          onTap: () => setState(() => _selectedMethod = 0),
        ),
        const SizedBox(height: 8),
        _PaymentMethodTile(
          selected: _selectedMethod == 1,
          title: 'Add new card',
          iconChild: const Icon(
            LucideIcons.creditCard,
            color: Color(0xFF060D35),
            size: 26,
          ),
          onTap: () => setState(() => _selectedMethod = 1),
        ),
        const SizedBox(height: 8),
        _PaymentMethodTile(
          selected: _selectedMethod == 2,
          title: 'Digital wallet',
          iconChild: const Icon(
            LucideIcons.wallet,
            color: Color(0xFF060D35),
            size: 26,
          ),
          onTap: () => setState(() => _selectedMethod = 2),
        ),
        const SizedBox(height: 8),
        _PaymentMethodTile(
          selected: _selectedMethod == 3,
          title: 'Pay with bCoins',
          iconChild: const _BCoinBadge(),
          onTap: () => setState(() => _selectedMethod = 3),
        ),
        const SizedBox(height: 10),
        _BillingAddressTile(
          value: _useDeliveryAddress,
          onChanged: (value) => setState(() => _useDeliveryAddress = value),
        ),
        const SizedBox(height: 13),
        const _SecurePaymentNote(),
      ],
    );
  }
}

class _AmountDueCard extends StatelessWidget {
  final String amount;

  const _AmountDueCard({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      decoration: storeSoftCardDecoration(radius: 12),
      child: Column(
        children: [
          const Text(
            'Amount due',
            style: TextStyle(
              color: Color(0xFF596174),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount,
              style: const TextStyle(
                color: Color(0xFF078D92),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String? subtitle;
  final String? badge;
  final Widget iconChild;
  final VoidCallback onTap;

  const _PaymentMethodTile({
    required this.selected,
    required this.title,
    required this.iconChild,
    required this.onTap,
    this.subtitle,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: storeSoftCardDecoration(radius: 12),
        child: Row(
          children: [
            _RadioMark(selected: selected),
            const SizedBox(width: 9),
            Container(
              width: 40,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFE7EAF0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.035),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: iconChild,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF596174),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF078D92),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else
              const Icon(
                LucideIcons.chevronRight,
                color: Color(0xFF29304D),
                size: 21,
              ),
          ],
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  final bool selected;

  const _RadioMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 18,
      height: 18,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? const Color(0xFF078D92) : const Color(0xFF596174),
          width: selected ? 2.2 : 1.5,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF078D92) : Colors.transparent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _BCoinBadge extends StatelessWidget {
  const _BCoinBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF684AC8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Text(
        'b',
        style: TextStyle(
          color: Color(0xFF684AC8),
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BillingAddressTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _BillingAddressTile({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
      decoration: storeSoftCardDecoration(radius: 12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF078D92),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Use delivery address\nas billing address',
              style: TextStyle(
                color: Color(0xFF060D35),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF078D92),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFD6DCE3),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SecurePaymentNote extends StatelessWidget {
  const _SecurePaymentNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.shieldCheck, color: Color(0xFF078D92), size: 28),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Secure payment',
                style: TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Your payment information is encrypted and processed securely.',
                style: TextStyle(
                  color: Color(0xFF29304D),
                  fontSize: 11.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestSentStep extends StatelessWidget {
  final String providerName;

  const _RequestSentStep({super.key, required this.providerName});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF7F6),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.circleCheck,
            color: Color(0xFF078D92),
            size: 36,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Request sent',
          style: TextStyle(
            color: Color(0xFF060D35),
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Request #SV2048',
          style: TextStyle(
            color: Color(0xFF684AC8),
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF4EEFF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Pending confirmation',
            style: TextStyle(
              color: Color(0xFF684AC8),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 13),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(11),
          decoration: storeSoftCardDecoration(radius: 12),
          child: Column(
            children: [
              const Divider(height: 1, color: Color(0xFFE3E7ED)),
              const SizedBox(height: 12),
              Text(
                '$providerName will respond soon. We will notify you when the booking is confirmed.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF29304D),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _WideActionButton(
            label: 'View booking', filled: true, onPressed: () {}),
        const SizedBox(height: 10),
        _WideActionButton(
          label: 'Message $providerName',
          filled: false,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _BookingFooterButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  const _BookingFooterButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        7,
        16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      child: _WideActionButton(
        label: label,
        filled: true,
        icon: icon,
        onPressed: onPressed,
      ),
    );
  }
}

class _WideActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final IconData? icon;
  final VoidCallback onPressed;

  const _WideActionButton({
    required this.label,
    required this.filled,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(9));
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF078D92),
                foregroundColor: Colors.white,
                shape: shape,
              ),
              child: _ButtonLabel(label: label, icon: icon),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF078D92),
                side: const BorderSide(color: Color(0xFF078D92)),
                shape: shape,
              ),
              child: _ButtonLabel(label: label, icon: icon),
            ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _ButtonLabel({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16),
          const SizedBox(width: 7),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
