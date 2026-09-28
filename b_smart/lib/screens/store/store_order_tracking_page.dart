import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../utils/url_helper.dart';
import 'shared/store_shared_widgets.dart';
import 'store_models.dart';
import 'store_theme.dart';

class StoreOrderTrackingListPage extends StatefulWidget {
  const StoreOrderTrackingListPage({super.key});

  @override
  State<StoreOrderTrackingListPage> createState() =>
      _StoreOrderTrackingListState();
}

class _StoreOrderTrackingListState extends State<StoreOrderTrackingListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StoreMockState.instance.refreshBuyerOrders();
      StoreMockState.instance.refreshBuyerBookings();
    });
  }

  Future<void> _retry() async {
    await Future.wait([
      StoreMockState.instance.refreshBuyerOrders(),
      StoreMockState.instance.refreshBuyerBookings(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              14,
              8,
              14,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              const _StorePageHeader(title: 'Tracking Order'),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: StoreMockState.instance,
                builder: (context, _) {
                  final visibleOrders = [
                    ...StoreMockState.instance.buyerOrders
                        .map(_TrackingOrder.fromApiOrder),
                    ...StoreMockState.instance.buyerBookings
                        .map(_TrackingOrder.fromApiBooking),
                  ];
                  final loading =
                      StoreMockState.instance.ordersLoading ||
                          StoreMockState.instance.bookingsLoading;
                  final error = !loading && visibleOrders.isEmpty
                      ? StoreMockState.instance.lastError
                      : null;
                  return Column(
                    children: [
                      if (loading) const LinearProgressIndicator(),
                      for (final order in visibleOrders) ...[
                        _TrackingOrderCard(order: order),
                        const SizedBox(height: 10),
                      ],
                      if (visibleOrders.isEmpty && !loading)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: error == null
                              ? const StoreEmptyState(
                                  icon: LucideIcons.packageSearch,
                                  title: 'No orders yet',
                                  body:
                                      'Your product orders and service bookings will appear here.',
                                )
                              : StoreEmptyState(
                                  icon: LucideIcons.cloudOff,
                                  title: "Couldn't load orders",
                                  body: '$error',
                                ),
                        ),
                      if (error != null && !loading)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: OutlinedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(
                                LucideIcons.refreshCw,
                                size: 16),
                            label: const Text('Retry'),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreOrderTrackingDetailPage extends StatefulWidget {
  final _TrackingOrder order;

  const _StoreOrderTrackingDetailPage({
    required this.order,
  });

  @override
  State<_StoreOrderTrackingDetailPage> createState() =>
      _StoreOrderTrackingDetailState();
}

class _StoreOrderTrackingDetailState
    extends State<_StoreOrderTrackingDetailPage> {
  late _TrackingOrder _order;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _refreshStatus();
  }

  /// Refetches the latest order/booking status by id (Phase 2 md:
  /// GET /api/orders/:id, GET /api/service-bookings/:id).
  Future<void> _refreshStatus() async {
    if (!_order.live || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      final data = _order.isService
          ? await Phase2StoreApi().getServiceBooking(_order.id)
          : await Phase2StoreApi().getOrder(_order.id);
      if (!mounted || data.isEmpty) return;
      final status = StoreMockState.statusOf(data);
      if (status.isEmpty) return;
      setState(() {
        _order = _TrackingOrder(
          id: _order.id,
          title: _order.title,
          status: status,
          eta: _order.isService
              ? (data['booking_date']?.toString() ?? _order.eta)
              : _order.eta,
          imageUrl: _order.imageUrl,
          currentStep: _order.isService
              ? _TrackingOrder.stepForBookingStatus(status)
              : _TrackingOrder.stepForOrderStatus(status),
          isService: _order.isService,
          live: true,
          rawStatus: status,
        );
      });
    } catch (_) {
      // Keep list data on failure.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  bool get _cancellable =>
      _order.live &&
      ['pending', 'confirmed', 'processing'].contains(_order.rawStatus);

  Future<void> _cancel(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Cancel?'),
        content: Text(_order.isService
            ? 'Cancel booking #${_order.id}? Refund issued if already paid.'
            : 'Cancel order #${_order.id}? Items restocked, refund issued.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      if (_order.isService) {
        await StoreMockState.instance.cancelBuyerBooking(_order.id);
      } else {
        await StoreMockState.instance.cancelBuyerOrder(_order.id);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancelled with refund where paid.')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cancel failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          bottom: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              14,
              8,
              14,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              const _StorePageHeader(title: 'Order tracking'),
              if (_refreshing) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              _ArrivalCard(order: _order),
              const SizedBox(height: 10),
              _TrackingMapCard(isService: _order.isService),
              const SizedBox(height: 10),
              _TimelineCard(order: _order),
              const SizedBox(height: 10),
              _StatusNoteCard(order: _order),
              if (_cancellable) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => _cancel(context),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red),
                    child: Text(_order.isService
                        ? 'Cancel booking'
                        : 'Cancel order'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingOrder {
  final String id;
  final String title;
  final String status;
  final String eta;
  final String imageUrl;
  final int currentStep;
  final bool isService;
  final bool live;
  final String rawStatus;

  const _TrackingOrder({
    required this.id,
    required this.title,
    required this.status,
    required this.eta,
    required this.imageUrl,
    required this.currentStep,
    required this.isService,
    this.live = false,
    this.rawStatus = '',
  });

  static int stepForOrderStatus(String s) => _stepForOrderStatus(s);

  static int stepForBookingStatus(String s) => _stepForBookingStatus(s);

  static int _stepForOrderStatus(String s) {
    return switch (s) {
      'processing' => 1,
      'shipped' => 2,
      'delivered' || 'completed' => 3,
      _ => 0,
    };
  }

  static int _stepForBookingStatus(String s) {
    return switch (s) {
      'in_progress' => 2,
      'completed' => 3,
      'confirmed' => 1,
      _ => 0,
    };
  }

  factory _TrackingOrder.fromApiOrder(Map<String, dynamic> m) {
    final id = StoreMockState.orderIdOf(m);
    final status = StoreMockState.statusOf(m);
    final items = m['items'];
    String title = 'Store order';
    String imageUrl = '';
    if (items is List && items.isNotEmpty) {
      final first = items.first;
      if (first is Map) {
        final fm = first.map((k, v) => MapEntry(k.toString(), v));
        final prod = fm['product'];
        final pm = prod is Map
            ? prod.map((k, v) => MapEntry(k.toString(), v))
            : fm;
        title = (pm['name'] ?? pm['title'] ?? 'Store order').toString();
        if (items.length > 1) title = '$title + ${items.length - 1} more';
        imageUrl = _imageOf(pm);
      }
    }
    return _TrackingOrder(
      id: id.isEmpty ? 'order' : id,
      title: title,
      status: status.isEmpty ? 'Order confirmed' : status,
      eta: 'Live order',
      imageUrl: imageUrl,
      currentStep: _stepForOrderStatus(status),
      isService: false,
      live: true,
      rawStatus: status,
    );
  }

  factory _TrackingOrder.fromApiBooking(Map<String, dynamic> m) {
    final id = StoreMockState.bookingIdOf(m);
    final status = StoreMockState.statusOf(m);
    final svc = m['service'];
    final sm = svc is Map
        ? svc.map((k, v) => MapEntry(k.toString(), v))
        : m;
    return _TrackingOrder(
      id: id.isEmpty ? 'booking' : id,
      title: (sm['name'] ?? sm['title'] ?? 'Service booking').toString(),
      status: status.isEmpty ? 'Request confirmed' : status,
      eta: (m['booking_date'] ?? 'Scheduled').toString(),
      imageUrl: _imageOf(sm),
      currentStep: _stepForBookingStatus(status),
      isService: true,
      live: true,
      rawStatus: status,
    );
  }

  static String _imageOf(Map<String, dynamic> json) {
    final images = json['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        for (final key in ['url', 'fileName', 'filename', 'path', 'src']) {
          final value = first[key]?.toString().trim() ?? '';
          if (value.isNotEmpty) return UrlHelper.absoluteUrl(value);
        }
      } else if (first is String && first.trim().isNotEmpty) {
        return UrlHelper.absoluteUrl(first.trim());
      }
    }
    return '';
  }
}

class _StorePageHeader extends StatelessWidget {
  final String title;

  const _StorePageHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.arrowLeft, size: 25),
              color: BStoreColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const StoreBsmartWordmark(),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 21,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackingOrderCard extends StatelessWidget {
  final _TrackingOrder order;

  const _TrackingOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _StoreOrderTrackingDetailPage(order: order),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BStoreDecorations.card(radius: 14),
        child: Row(
          children: [
            StoreItemImage(
              imageUrl: order.imageUrl,
              icon: order.isService
                  ? LucideIcons.briefcaseBusiness
                  : LucideIcons.package,
              width: 52,
              height: 52,
              borderRadius: 10,
              debugLabel: 'store-tracking-order',
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.primary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '#${order.id} • ${order.eta}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              color: BStoreColors.textPrimary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrivalCard extends StatelessWidget {
  final _TrackingOrder order;

  const _ArrivalCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
      decoration: BStoreDecorations.card(radius: 14),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: BStoreColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              order.isService
                  ? LucideIcons.briefcaseBusiness
                  : LucideIcons.package,
              color: BStoreColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: BStoreColors.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    order.eta,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingMapCard extends StatelessWidget {
  final bool isService;

  const _TrackingMapCard({required this.isService});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 158,
      decoration: BStoreDecorations.card(radius: 14),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _TrackingMapPainter(),
        child: Stack(
          children: [
            Positioned(
              left: 70,
              top: 58,
              child: _MapPin(
                icon: isService
                    ? LucideIcons.briefcaseBusiness
                    : LucideIcons.package,
              ),
            ),
            const Positioned(
              right: 42,
              top: 36,
              child: _MapPin(icon: LucideIcons.house),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFF5F4EF);
    canvas.drawRect(Offset.zero & size, background);

    final parkPaint = Paint()..color = const Color(0xFFE2EEDB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .06, size.height * .08, 92, 70),
        const Radius.circular(10),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .76, size.height * .48, 90, 58),
        const Radius.circular(10),
      ),
      parkPaint,
    );

    final river = Paint()
      ..color = const Color(0xFFD6EBF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round;
    final riverPath = Path()
      ..moveTo(size.width * .92, -20)
      ..quadraticBezierTo(size.width * .86, size.height * .32, size.width * .98,
          size.height * .92);
    canvas.drawPath(riverPath, river);

    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (final y in [20.0, 54.0, 96.0, 142.0]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 30), road);
    }
    for (final x in [42.0, 112.0, 190.0, 268.0]) {
      canvas.drawLine(Offset(x, 0), Offset(x - 68, size.height), road);
    }

    final route = Paint()
      ..color = BStoreColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * .18, size.height * .58)
      ..lineTo(size.width * .31, size.height * .73)
      ..quadraticBezierTo(size.width * .37, size.height * .45, size.width * .48,
          size.height * .50)
      ..lineTo(size.width * .60, size.height * .52)
      ..lineTo(size.width * .66, size.height * .34)
      ..lineTo(size.width * .78, size.height * .44)
      ..quadraticBezierTo(size.width * .86, size.height * .50, size.width * .91,
          size.height * .31);
    canvas.drawPath(path, route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPin extends StatelessWidget {
  final IconData icon;

  const _MapPin({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: BStoreColors.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: BStoreColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final _TrackingOrder order;

  const _TimelineCard({required this.order});

  static const _steps = [
    ('Order confirmed', '9:12 AM'),
    ('Packed', '10:03 AM'),
    ('Out for delivery', '12:48 PM'),
    ('Delivered', 'Upcoming'),
  ];

  static const _serviceSteps = [
    ('Request confirmed', '9:12 AM'),
    ('Provider assigned', '10:03 AM'),
    ('Service scheduled', 'Upcoming'),
    ('Completed', 'Upcoming'),
  ];

  @override
  Widget build(BuildContext context) {
    final steps = order.isService ? _serviceSteps : _steps;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BStoreDecorations.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Order ',
              children: [
                TextSpan(
                  text: '#${order.id}',
                  style: const TextStyle(color: BStoreColors.accentPurple),
                ),
              ],
            ),
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          for (var i = 0; i < steps.length; i++)
            _TimelineStep(
              title: steps[i].$1,
              time: i <= order.currentStep ? steps[i].$2 : 'Upcoming',
              isComplete: i < order.currentStep,
              isCurrent: i == order.currentStep,
              showLine: i != steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String time;
  final bool isComplete;
  final bool isCurrent;
  final bool showLine;

  const _TimelineStep({
    required this.title,
    required this.time,
    required this.isComplete,
    required this.isCurrent,
    required this.showLine,
  });

  @override
  Widget build(BuildContext context) {
    final active = isComplete || isCurrent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 21,
                  height: 21,
                  decoration: BoxDecoration(
                    color: isComplete ? BStoreColors.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? BStoreColors.primary : Colors.black12,
                      width: isCurrent ? 4 : 2,
                    ),
                  ),
                  child: isComplete
                      ? const Icon(
                          LucideIcons.check,
                          color: Colors.white,
                          size: 13,
                        )
                      : null,
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: active ? BStoreColors.primary : Colors.black12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    time,
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 11.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Honest status note: the backend exposes no courier assignment, so we
/// show payment/fulfilment state instead of inventing a courier.
class _StatusNoteCard extends StatelessWidget {
  final _TrackingOrder order;

  const _StatusNoteCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final note = order.isService
        ? 'The provider confirms each step. You will be notified on every update.'
        : 'The seller advances each step. Stock and refunds are handled automatically on cancel.';
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BStoreDecorations.card(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.info,
            color: BStoreColors.primary,
            size: 20,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.id}',
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

