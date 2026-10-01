import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shared/store_shared_widgets.dart';
import 'store_models.dart';

/// Seller view of incoming service bookings (`GET /service-bookings/seller/mine`).
///
/// Status flow per Phase 2 spec: confirmed → in_progress → completed.
/// Cancellation refunds when already paid.
class SelfStoreBookingsScreen extends StatelessWidget {
  const SelfStoreBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFC),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SelfStoreBookingsPage(),
            SliverToBoxAdapter(
              child:
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 18),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BookingTab { incoming, inProgress, completed, cancelled }

class SelfStoreBookingsPage extends StatefulWidget {
  const SelfStoreBookingsPage({super.key});

  @override
  State<SelfStoreBookingsPage> createState() => _SelfStoreBookingsPageState();
}

class _SelfStoreBookingsPageState extends State<SelfStoreBookingsPage> {
  _BookingTab _tab = _BookingTab.incoming;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StoreMockState.instance.refreshSellerBookings();
    });
  }

  List<_SellerBooking> get _bookings =>
      StoreMockState.instance.sellerBookings.map(_SellerBooking.fromApi).toList();

  bool _matches(_SellerBooking booking) {
    final status = booking.status;
    return switch (_tab) {
      _BookingTab.incoming =>
        status == 'pending' || status == 'confirmed' || status == 'paid',
      _BookingTab.inProgress => status == 'in_progress',
      _BookingTab.completed =>
        status == 'completed' || status == 'delivered',
      _BookingTab.cancelled =>
        status == 'cancelled' || status == 'canceled',
    };
  }

  String? _nextStatus(_SellerBooking booking) {
    return switch (booking.status) {
      'pending' || 'paid' => 'confirmed',
      'confirmed' => 'in_progress',
      'in_progress' => 'completed',
      _ => null,
    };
  }

  String _actionLabel(_SellerBooking booking) {
    return switch (booking.status) {
      'pending' || 'paid' => 'Confirm booking',
      'confirmed' => 'Start service',
      'in_progress' => 'Mark completed',
      _ => 'Update',
    };
  }

  Future<void> _advance(_SellerBooking booking) async {
    final next = _nextStatus(booking);
    if (next == null || _updating) return;
    setState(() => _updating = true);
    try {
      await StoreMockState.instance.advanceBookingStatus(booking.id, next);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking status updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StoreMockState.instance,
      builder: (context, _) {
        final filtered =
            _bookings.where(_matches).toList(growable: false);
        final loading = StoreMockState.instance.bookingsLoading;
        return SliverList.list(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                MediaQuery.of(context).padding.top + 14,
                18,
                0,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StoreBsmartWordmark(),
                  SizedBox(height: 16),
                  Text(
                    'Service bookings',
                    style: TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
              child: StoreUnderlineTabs(
                tabs: const ['New', 'In progress', 'Completed', 'Cancelled'],
                selectedIndex: _BookingTab.values.indexOf(_tab),
                onSelected: (index) =>
                    setState(() => _tab = _BookingTab.values[index]),
              ),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 8),
            for (final booking in filtered)
              _BookingCard(
                booking: booking,
                updating: _updating,
                actionLabel: _actionLabel(booking),
                canAdvance: _nextStatus(booking) != null,
                onAdvance: () => _advance(booking),
              ),
            if (filtered.isEmpty && !loading)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
                child: StoreEmptyState(
                  icon: LucideIcons.calendarCheck,
                  title: 'No bookings here',
                  body: 'Incoming service bookings will appear here.',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SellerBooking {
  final String id;
  final String serviceName;
  final String date;
  final String slot;
  final String customer;
  final String address;
  final String paymentMethod;
  final String status;

  const _SellerBooking({
    required this.id,
    required this.serviceName,
    required this.date,
    required this.slot,
    required this.customer,
    required this.address,
    required this.paymentMethod,
    required this.status,
  });

  static String _text(Map<String, dynamic> m, List<String> keys,
      [String fallback = '']) {
    for (final key in keys) {
      final value = m[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  factory _SellerBooking.fromApi(Map<String, dynamic> m) {
    final service = m['service'];
    final serviceMap = service is Map
        ? service.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final slot = m['time_slot'];
    final slotMap = slot is Map
        ? slot.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final address = m['customer_address'];
    final addressMap = address is Map
        ? address.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    final subservices = m['selected_subservices'];
    String serviceName = _text(serviceMap, const ['name', 'title']);
    if (serviceName.isEmpty) {
      serviceName = _text(m, const ['service_name', 'service_title'],
          'Service booking');
    }
    if (subservices is List && subservices.isNotEmpty) {
      final first = subservices.first;
      if (first is Map) {
        final name = first['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) serviceName = '$serviceName · $name';
      } else if ('$first'.trim().isNotEmpty) {
        serviceName = '$serviceName · ${'$first'.trim()}';
      }
    }
    final start = _text(slotMap, const ['start']);
    final end = _text(slotMap, const ['end']);
    return _SellerBooking(
      id: StoreMockState.bookingIdOf(m).isEmpty
          ? 'booking'
          : StoreMockState.bookingIdOf(m),
      serviceName: serviceName,
      date: _text(m, const ['booking_date', 'date'], '—'),
      slot: start.isEmpty && end.isEmpty ? '—' : '$start – $end',
      customer: _text(addressMap, const ['name'], 'Customer'),
      address: [
        addressMap['address_line1'],
        addressMap['city'],
        addressMap['pincode'],
      ]
          .where((e) =>
              e != null && e.toString().trim().isNotEmpty)
          .join(', '),
      paymentMethod: _text(m, const ['payment_method'], 'wallet'),
      status: StoreMockState.statusOf(m).isEmpty
          ? 'pending'
          : StoreMockState.statusOf(m),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final _SellerBooking booking;
  final bool updating;
  final String actionLabel;
  final bool canAdvance;
  final VoidCallback onAdvance;

  const _BookingCard({
    required this.booking,
    required this.updating,
    required this.actionLabel,
    required this.canAdvance,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: storeSoftCardDecoration(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    booking.serviceName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(status: booking.status),
              ],
            ),
            const SizedBox(height: 10),
            _BookingRow(
                icon: LucideIcons.calendarDays, text: booking.date),
            const SizedBox(height: 6),
            _BookingRow(icon: LucideIcons.clock, text: booking.slot),
            const SizedBox(height: 6),
            _BookingRow(icon: LucideIcons.userRound, text: booking.customer),
            if (booking.address.isNotEmpty) ...[
              const SizedBox(height: 6),
              _BookingRow(icon: LucideIcons.mapPin, text: booking.address),
            ],
            const SizedBox(height: 6),
            _BookingRow(
              icon: LucideIcons.wallet,
              text: 'Paid via ${booking.paymentMethod} · #${booking.id}',
            ),
            if (canAdvance) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  onPressed: updating ? null : onAdvance,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF078D92),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: Text(
                    updating ? 'Updating...' : actionLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BookingRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF29304D), size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF29304D),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'in_progress' => const Color(0xFF684AC8),
      'completed' => const Color(0xFF047C58),
      'cancelled' || 'canceled' => const Color(0xFFB3261E),
      _ => const Color(0xFF078D92),
    };
    final background = switch (status) {
      'in_progress' => const Color(0xFFF4EEFF),
      'completed' => const Color(0xFFE9F8E6),
      'cancelled' || 'canceled' => const Color(0xFFFDECEA),
      _ => const Color(0xFFEAF7F6),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
