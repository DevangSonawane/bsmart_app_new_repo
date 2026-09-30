import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../services/razorpay_checkout_service.dart';
import '../../services/supabase_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_shared_widgets.dart';
import 'store_address_book.dart';
import 'store_models.dart';
import 'store_saved_address_page.dart';

class VisitorServiceBookingFlowPage extends StatefulWidget {
  final String? ownerUserId;
  final StoreMockCatalogItem item;

  const VisitorServiceBookingFlowPage({
    super.key,
    required this.ownerUserId,
    required this.item,
  });

  String get imageUrl => item.imageUrl;
  String get title => item.title;
  String get duration => item.duration;
  String get price => item.priceLabel;

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
  String _paymentMethod = 'wallet';
  bool _submitting = false;
  String? _bookingId;
  String? _bookingError;
  final RazorpayCheckoutService _razorpay = RazorpayCheckoutService();
  final Set<String> _selectedSubservices = {};

  @override
  void dispose() {
    _razorpay.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
    _dateWindowStart = _selectedDate;
    _providerFuture = _loadProvider();
    StoreAddressBook.instance.ensureLoaded();
    _selectedSubservices.addAll(_defaultSubservices());
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
    _ensureTimeInSlots();
  }

  /// Weekday windows from the service payload (`weekly_availability`).
  /// Empty weekday array = Unavailable (matches seller UI + server 400s).
  static const _weekdayKeys = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  bool get _hasAvailabilityData =>
      widget.item.raw['weekly_availability'] is Map;

  List<(int, int)> _windowsFor(DateTime date) {
    final raw = widget.item.raw['weekly_availability'];
    if (raw is! Map) return const [];
    final day = raw[_weekdayKeys[date.weekday - 1]];
    if (day is! List) return const [];
    final out = <(int, int)>[];
    for (final entry in day) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final start = _parseHm(map['start']?.toString() ?? '');
      final end = _parseHm(map['end']?.toString() ?? '');
      if (start == null || end == null) continue;
      if (end <= start) continue;
      out.add((start, end));
    }
    return out;
  }

  /// "09:00" → minutes since midnight, null when malformed.
  static int? _parseHm(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  static String _label24(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve:${minute.toString().padLeft(2, '0')} $suffix';
  }

  /// Hourly start slots inside the day's windows. Null = no availability
  /// data on the service (legacy fixed grids apply).
  List<String>? _slotLabelsFor(DateTime date) {
    if (!_hasAvailabilityData) return null;
    final slots = <String>[];
    for (final (start, end) in _windowsFor(date)) {
      var cursor = start;
      while (cursor + 60 <= end) {
        slots.add(_label24(cursor));
        cursor += 60;
      }
    }
    return slots;
  }

  bool get _selectedDayUnavailable {
    final slots = _slotLabelsFor(_selectedDate);
    return slots != null && slots.isEmpty;
  }

  List<String> get _morningSlots {
    final slots = _slotLabelsFor(_selectedDate);
    if (slots == null) return const ['10:00 AM', '11:00 AM', '12:00 PM'];
    return slots.where((s) => !_isAfternoon(s)).toList();
  }

  List<String> get _afternoonSlots {
    final slots = _slotLabelsFor(_selectedDate);
    if (slots == null) return const ['1:00 PM', '2:00 PM', '3:00 PM'];
    return slots.where(_isAfternoon).toList();
  }

  static bool _isAfternoon(String label) {
    final match =
        RegExp(r'(\d{1,2}):(\d{2})\s*([AP]M)', caseSensitive: false)
            .firstMatch(label.trim());
    if (match == null) return false;
    var hour = int.tryParse(match.group(1) ?? '12') ?? 12;
    final suffix = (match.group(3) ?? 'AM').toUpperCase();
    if (suffix == 'PM' && hour < 12) hour += 12;
    if (suffix == 'AM' && hour == 12) hour = 0;
    return hour >= 12;
  }

  void _ensureTimeInSlots() {
    final slots = _slotLabelsFor(_selectedDate);
    if (slots == null || slots.isEmpty) return;
    if (!slots.contains(_selectedTime)) {
      setState(() => _selectedTime = slots.first);
    }
  }

  Future<void> _handleFooterTap() async {
    if (_step == 0) {
      if (_selectedDayUnavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Provider is unavailable on this day. Pick another date.'),
          ),
        );
        return;
      }
      _ensureTimeInSlots();
      setState(() => _step += 1);
      return;
    }
    if (_step == 1) {
      setState(() => _step += 1);
      return;
    }
    // Step 2: create the booking directly (services have no cart per spec).
    if (_submitting) return;
    // customer_address is required for at-customer-location bookings.
    if (_address == null) {
      setState(() => _bookingError =
          'Add a service address before confirming this booking.');
      return;
    }
    setState(() {
      _submitting = true;
      _bookingError = null;
    });
    try {
      final slot = _timeSlot24h(_selectedTime);
      final bookingDate =
          DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response =
          await StoreMockState.instance.createBooking({
        'service_id': widget.item.raw['id'] ??
            widget.item.raw['_id'] ??
            widget.item.id,
        'booking_date': bookingDate,
        'time_slot': slot,
        if (_selectedSubservices.isNotEmpty)
          'selected_subservices': [
            for (final name in _selectedSubservices) {'name': name}
          ],
        'customer_address': _address?.toCustomerJson() ?? const {},
        'payment_method': _paymentMethod,
      });
      final id = _bookingIdFrom(response);
      if (!mounted) return;
      if (_paymentMethod == 'razorpay') {
        await _payBookingWithRazorpay(response, id);
        return;
      }
      setState(() {
        _bookingId = id.isEmpty ? null : id;
        _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _bookingError = _friendlyBookingError(e));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_bookingError ?? 'Booking failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Opens Razorpay Checkout for a booking created with payment_method
  /// razorpay (stays pending until verified), then verifies and completes.
  Future<void> _payBookingWithRazorpay(
    Map<String, dynamic> response,
    String bookingId,
  ) async {
    final razorpay = RazorpayCheckoutService.razorpayOf(
      response,
      fallbackTotal: widget.item.price,
    );
    if (razorpay == null) {
      if (!mounted) return;
      setState(() {
        _bookingError =
            'Razorpay is not configured on the server. Pay with wallet instead.';
        _submitting = false;
      });
      return;
    }
    // Keep _submitting true while the native sheet is open; callbacks below
    // finish the flow (verify on success, pending notice on failure).
    _razorpay.open(
      keyId: razorpay.keyId,
      orderId: razorpay.orderId,
      amountPaise: razorpay.amountPaise,
      description: 'B-Smart booking $bookingId',
      onSuccess: (success) async {
        try {
          await StoreMockState.instance.verifyBookingPayment(
            bookingId: bookingId,
            razorpayOrderId: success.orderId,
            razorpayPaymentId: success.paymentId,
            razorpaySignature: success.signature,
          );
          if (!mounted) return;
          setState(() {
            _bookingId = bookingId;
            _step = 3;
          });
        } catch (e) {
          if (!mounted) return;
          setState(() => _bookingError = 'Payment verification failed: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment verification failed: $e')),
          );
        } finally {
          if (mounted) setState(() => _submitting = false);
        }
      },
      onFailure: (failure) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failure.dismissed
                  ? 'Payment cancelled. Booking $bookingId is pending — retry from My bookings.'
                  : 'Razorpay: ${failure.message} Booking $bookingId stays pending.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      },
    );
  }

  /// Converts "10:00 AM" to {"start": "10:00", "end": "12:00"} (2h default).
  static Map<String, String> _timeSlot24h(String label) {
    final match =
        RegExp(r'(\d{1,2}):(\d{2})\s*([AP]M)', caseSensitive: false)
            .firstMatch(label.trim());
    var hour = 10;
    var minute = 0;
    if (match != null) {
      hour = int.tryParse(match.group(1) ?? '10') ?? 10;
      minute = int.tryParse(match.group(2) ?? '0') ?? 0;
      final suffix = (match.group(3) ?? 'AM').toUpperCase();
      if (suffix == 'PM' && hour < 12) hour += 12;
      if (suffix == 'AM' && hour == 12) hour = 0;
    }
    final endHour = (hour + 2) % 24;
    String fmt(int h, int m) =>
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return {'start': fmt(hour, minute), 'end': fmt(endHour, minute)};
  }

  /// All subservices offered by the service, each with name/price strings.
  List<Map<String, String>> get _allSubservices {
    final raw = widget.item.raw['subservices'];
    if (raw is! List) return const [];
    final out = <Map<String, String>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final name = map['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      out.add({
        'name': name,
        'price': map['price']?.toString().trim() ?? '',
        'hours': (map['hours'] ?? map['duration'])?.toString().trim() ?? '',
      });
    }
    return out;
  }

  /// Default selection: first subservice (preserves previous auto behavior).
  Set<String> _defaultSubservices() {
    final all = _allSubservices;
    if (all.isEmpty) return {};
    return {all.first['name'] ?? ''}..remove('');
  }

  ShipAddress? get _address => StoreAddressBook.instance.selected;

  Future<void> _pickAddress() async {
    final picked = await Navigator.of(context).push<ShipAddress>(
      MaterialPageRoute<ShipAddress>(
        builder: (_) => const StoreSavedAddressPage(selectMode: true),
      ),
    );
    if (picked == null || !mounted) return;
    StoreAddressBook.instance.select(picked.id);
    setState(() {});
  }

  static String _bookingIdFrom(Map<String, dynamic> response) {
    for (final key in ['id', '_id', 'booking_id']) {
      final v = response[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    for (final key in ['booking', 'data', 'item']) {
      final nested = response[key];
      if (nested is Map) {
        for (final k in ['id', '_id', 'booking_id']) {
          final v = nested[k]?.toString().trim();
          if (v != null && v.isNotEmpty) return v;
        }
      }
    }
    return '';
  }

  static String _friendlyBookingError(Object e) {
    final text = e.toString();
    if (text.contains('409') || text.toLowerCase().contains('overlap')) {
      return 'This slot is already booked. Please pick another time.';
    }
    if (text.toLowerCase().contains('availability') ||
        text.toLowerCase().contains('slot')) {
      return 'Selected time is outside provider availability. Try another slot.';
    }
    return 'Booking failed: $e';
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
            child: AnimatedBuilder(
              animation: StoreAddressBook.instance,
              builder: (context, _) => Column(
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
                              morningTimes: _morningSlots,
                              afternoonTimes: _afternoonSlots,
                              dayUnavailable: _selectedDayUnavailable,
                              serviceAddress: _address?.summaryLine ??
                                  'Add a service address',
                              onDateSelected: (date) {
                                setState(() => _selectedDate = date);
                                _ensureTimeInSlots();
                              },
                              onCalendarTap: _pickDate,
                              onTimeSelected: (time) {
                                setState(() => _selectedTime = time);
                              },
                              onDurationChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedDuration = value);
                              },
                              onAddressTap: _pickAddress,
                            ),
                          1 => _ReviewRequestStep(
                              key: const ValueKey('review'),
                              service: widget,
                              provider: provider,
                              selectedDate: _selectedBookingDate,
                              selectedTime: _selectedTime,
                              selectedDuration: _selectedDuration,
                              addressLine: _address?.summaryLine ??
                                  'Add a service address',
                              onAddressTap: _pickAddress,
                              subservices: _allSubservices,
                              selectedSubservices: _selectedSubservices,
                              onSubserviceToggled: (name, selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedSubservices.add(name);
                                  } else {
                                    _selectedSubservices.remove(name);
                                  }
                                });
                              },
                              useBCoins: _useBCoins,
                              onUseBCoinsChanged: (value) {
                                setState(() => _useBCoins = value);
                              },
                            ),
                          2 => _PaymentStep(
                              key: const ValueKey('payment'),
                              amount: widget.price,
                              selectedMethod: _paymentMethod,
                              submitting: _submitting,
                              error: _bookingError,
                              onMethodChanged: (v) =>
                                  setState(() => _paymentMethod = v),
                            ),
                          _ => _RequestSentStep(
                              key: const ValueKey('sent'),
                              providerName: provider?.name ?? 'the provider',
                              bookingId: _bookingId,
                            ),
                        },
                      ),
                    ],
                  ),
                ),
                if (_step < 3)
                  _BookingFooterButton(
                    label: _submitting
                        ? 'Booking...'
                        : switch (_step) {
                            0 => 'Continue',
                            1 => 'Continue to payment',
                            _ => _paymentMethod == 'razorpay'
                                ? 'Pay ${widget.price} with Razorpay'
                                : 'Pay ${widget.price}',
                          },
                    icon: _step == 2 ? LucideIcons.lockKeyhole : null,
                    onPressed: _submitting ? () {} : _handleFooterTap,
                  ),
              ],
              ),
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
  final List<String> morningTimes;
  final List<String> afternoonTimes;
  final bool dayUnavailable;
  final String serviceAddress;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onCalendarTap;
  final ValueChanged<String> onTimeSelected;
  final ValueChanged<String?> onDurationChanged;
  final VoidCallback onAddressTap;

  const _SelectAvailabilityStep({
    super.key,
    required this.dates,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedDuration,
    required this.morningTimes,
    required this.afternoonTimes,
    required this.dayUnavailable,
    required this.serviceAddress,
    required this.onDateSelected,
    required this.onCalendarTap,
    required this.onTimeSelected,
    required this.onDurationChanged,
    required this.onAddressTap,
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
        if (dayUnavailable) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Provider is unavailable on this day. Please pick another date.',
              style: TextStyle(
                color: Color(0xFFB3261E),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (morningTimes.isNotEmpty) ...[
          const _SlotHeading('Morning'),
          const SizedBox(height: 10),
          _TimeGrid(
            times: morningTimes,
            selectedTime: selectedTime,
            onTimeSelected: onTimeSelected,
          ),
          const SizedBox(height: 18),
        ],
        if (afternoonTimes.isNotEmpty) ...[
          const _SlotHeading('Afternoon'),
          const SizedBox(height: 10),
          _TimeGrid(
            times: afternoonTimes,
            selectedTime: selectedTime,
            onTimeSelected: onTimeSelected,
          ),
          const SizedBox(height: 18),
        ],
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
        InkWell(
          onTap: onAddressTap,
          borderRadius: BorderRadius.circular(10),
          child: _BookingSelectTile(
            icon: LucideIcons.mapPin,
            trailing: LucideIcons.chevronRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Service address'),
                const SizedBox(height: 2),
                Text(
                  serviceAddress.isEmpty ? 'Select address' : serviceAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
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

class _SubservicePicker extends StatelessWidget {
  final List<Map<String, String>> subservices;
  final Set<String> selected;
  final void Function(String name, bool selected) onToggled;

  const _SubservicePicker({
    required this.subservices,
    required this.selected,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose subservices',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final sub in subservices)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                sub['name'] ?? '',
                style: const TextStyle(
                  color: Color(0xFF29304D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: ((sub['price'] ?? '').isNotEmpty ||
                      (sub['hours'] ?? '').isNotEmpty)
                  ? Text(
                      [
                        if ((sub['price'] ?? '').isNotEmpty)
                          '₹${sub['price']}',
                        if ((sub['hours'] ?? '').isNotEmpty)
                          '${sub['hours']}h',
                      ].join(' · '),
                      style: const TextStyle(
                        color: Color(0xFF6E748B),
                        fontSize: 11.5,
                      ),
                    )
                  : null,
              value: selected.contains(sub['name']),
              activeColor: const Color(0xFF078D92),
              onChanged: (value) =>
                  onToggled(sub['name'] ?? '', value ?? false),
            ),
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
  final String addressLine;
  final VoidCallback onAddressTap;
  final List<Map<String, String>> subservices;
  final Set<String> selectedSubservices;
  final void Function(String name, bool selected) onSubserviceToggled;
  final bool useBCoins;
  final ValueChanged<bool> onUseBCoinsChanged;

  const _ReviewRequestStep({
    super.key,
    required this.service,
    required this.provider,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedDuration,
    required this.addressLine,
    required this.onAddressTap,
    required this.subservices,
    required this.selectedSubservices,
    required this.onSubserviceToggled,
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
                    InkWell(
                      onTap: onAddressTap,
                      child: _ReviewInfoRow(
                        icon: LucideIcons.mapPin,
                        text: addressLine.isEmpty
                            ? 'Select address'
                            : addressLine,
                      ),
                    ),
                  ],
                ),
              ),
              if (subservices.isNotEmpty) ...[
                const _ReviewDivider(),
                _SubservicePicker(
                  subservices: subservices,
                  selected: selectedSubservices,
                  onToggled: onSubserviceToggled,
                ),
              ],
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
        StoreItemImage(
          imageUrl: service.imageUrl,
          icon: LucideIcons.briefcaseBusiness,
          width: 92,
          height: 92,
          borderRadius: 10,
          debugLabel: 'service-booking-review',
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

class _ReviewBCoinsRow extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ReviewBCoinsRow({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ReviewBCoinsRow> createState() => _ReviewBCoinsRowState();
}

class _ReviewBCoinsRowState extends State<_ReviewBCoinsRow> {
  late final Future<int> _balanceFuture;

  @override
  void initState() {
    super.initState();
    _balanceFuture = _loadBalance();
  }

  static Future<int> _loadBalance() async {
    try {
      return await WalletService().getCoinBalance();
    } catch (_) {
      return 0;
    }
  }

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
            FutureBuilder<int>(
              future: _balanceFuture,
              builder: (context, snapshot) => Text(
                'You have ${snapshot.data ?? 0} bCoins',
                style: const TextStyle(
                  color: Color(0xFF29304D),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: widget.value,
                activeThumbColor: const Color(0xFF078D92),
                onChanged: widget.onChanged,
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
      title: 'Wallet or Razorpay at next step',
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
  final String selectedMethod;
  final bool submitting;
  final String? error;
  final ValueChanged<String> onMethodChanged;

  const _PaymentStep({
    super.key,
    required this.amount,
    this.selectedMethod = 'wallet',
    this.submitting = false,
    this.error,
    required this.onMethodChanged,
  });

  @override
  State<_PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends State<_PaymentStep> {
  bool _useDeliveryAddress = true;

  @override
  Widget build(BuildContext context) {
    final method = widget.selectedMethod;
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
          selected: method == 'wallet',
          title: 'Wallet / bCoins',
          subtitle: '1 coin = ₹1 · deducted instantly',
          badge: method == 'wallet' ? 'Selected' : null,
          iconChild: const Icon(
            LucideIcons.wallet,
            color: Color(0xFF060D35),
            size: 26,
          ),
          onTap: () => widget.onMethodChanged('wallet'),
        ),
        const SizedBox(height: 8),
        _PaymentMethodTile(
          selected: method == 'razorpay',
          title: 'Razorpay',
          subtitle: 'UPI · cards · netbanking',
          badge: method == 'razorpay' ? 'Selected' : null,
          iconChild: const Icon(
            LucideIcons.creditCard,
            color: Color(0xFF060D35),
            size: 26,
          ),
          onTap: () => widget.onMethodChanged('razorpay'),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: 10),
          Text(widget.error!,
              style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        if (widget.submitting) ...[
          const SizedBox(height: 10),
          const LinearProgressIndicator(),
        ],
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
  final String? bookingId;

  const _RequestSentStep(
      {super.key, required this.providerName, this.bookingId});

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
        Text(
          bookingId == null || bookingId!.isEmpty
              ? 'Request received'
              : 'Request #${bookingId!}',
          style: const TextStyle(
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
            label: 'View bookings',
            filled: true,
            onPressed: () {
              StoreMockState.instance.refreshBuyerBookings();
              Navigator.of(context).popUntil((route) => route.isFirst);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Booking confirmed. See My bookings.')),
              );
            }),
        const SizedBox(height: 10),
        _WideActionButton(
          label: 'Back to store',
          filled: false,
          onPressed: () => Navigator.of(context).popUntil(
            (route) => route.isFirst,
          ),
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
