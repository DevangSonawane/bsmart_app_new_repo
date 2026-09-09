import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shared/store_shared_widgets.dart';
import 'store_models.dart';
import 'store_theme.dart';

class StoreOrderTrackingListPage extends StatelessWidget {
  const StoreOrderTrackingListPage({super.key});

  static const List<_TrackingOrder> _orders = [
    _TrackingOrder(
      id: 'BS10482',
      title: 'Eco Cleaning Kit',
      status: 'Arriving today',
      eta: '2:30-3:15 PM',
      imageAsset: 'assets/bSmart_Store/mockimages/vegetables.jpg',
      currentStep: 2,
      isService: false,
      courierName: 'Jordan Lee',
      courierRating: '4.9',
      courierDeliveries: '128 deliveries',
    ),
    _TrackingOrder(
      id: 'BS10471',
      title: 'Handmade Notebook',
      status: 'Packed',
      eta: 'Tomorrow, 11:00 AM',
      imageAsset: 'assets/bSmart_Store/mockimages/clothes.jpg',
      currentStep: 1,
      isService: false,
      courierName: 'Aarav Mehta',
      courierRating: '4.8',
      courierDeliveries: '96 deliveries',
    ),
    _TrackingOrder(
      id: 'BS10459',
      title: 'Wireless Desk Lamp',
      status: 'Order confirmed',
      eta: 'Sep 10, 4:00 PM',
      imageAsset: 'assets/bSmart_Store/mockimages/electronics.jpg',
      currentStep: 0,
      isService: false,
      courierName: 'Nina Carter',
      courierRating: '4.7',
      courierDeliveries: '214 deliveries',
    ),
  ];

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
                  final liveOrders = StoreMockState.instance.orders
                      .map(_TrackingOrder.fromMockOrder)
                      .toList();
                  final visibleOrders =
                      liveOrders.isEmpty ? _orders : liveOrders;
                  return Column(
                    children: [
                      for (final order in visibleOrders) ...[
                        _TrackingOrderCard(order: order),
                        const SizedBox(height: 10),
                      ],
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

class _StoreOrderTrackingDetailPage extends StatelessWidget {
  final _TrackingOrder order;

  const _StoreOrderTrackingDetailPage({
    required this.order,
  });

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
              const SizedBox(height: 12),
              _ArrivalCard(order: order),
              const SizedBox(height: 10),
              _TrackingMapCard(isService: order.isService),
              const SizedBox(height: 10),
              _TimelineCard(order: order),
              const SizedBox(height: 10),
              _CourierCard(order: order),
              const SizedBox(height: 10),
              _ViewDetailsCard(order: order),
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
  final String imageAsset;
  final int currentStep;
  final bool isService;
  final String courierName;
  final String courierRating;
  final String courierDeliveries;

  const _TrackingOrder({
    required this.id,
    required this.title,
    required this.status,
    required this.eta,
    required this.imageAsset,
    required this.currentStep,
    required this.isService,
    required this.courierName,
    required this.courierRating,
    required this.courierDeliveries,
  });

  factory _TrackingOrder.fromMockOrder(StoreMockOrder order) {
    final firstLine = order.lines.isEmpty ? null : order.lines.first;
    final hasService =
        order.lines.any((line) => line.item.type == StoreMockItemType.service);
    return _TrackingOrder(
      id: order.id,
      title: firstLine == null
          ? 'Store order'
          : order.lines.length == 1
              ? firstLine.item.title
              : '${firstLine.item.title} + ${order.lines.length - 1} more',
      status: hasService ? 'Request confirmed' : 'Order confirmed',
      eta: hasService ? 'Awaiting provider' : 'Sep 10, 4:00 PM',
      imageAsset: firstLine?.item.imageAsset ??
          'assets/bSmart_Store/mockimages/vegetables.jpg',
      currentStep: 0,
      isService: hasService,
      courierName: hasService ? 'Service provider' : 'Nina Carter',
      courierRating: '4.8',
      courierDeliveries: hasService ? '52 services' : '214 deliveries',
    );
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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                order.imageAsset,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
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

class _CourierCard extends StatelessWidget {
  final _TrackingOrder order;

  const _CourierCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BStoreDecorations.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            order.isService ? 'Your provider' : 'Your courier',
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: BStoreColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.userRound,
                  color: BStoreColors.primary,
                  size: 25,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.courierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: BStoreColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.star,
                          color: BStoreColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${order.courierRating} | ${order.courierDeliveries}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BStoreColors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _CourierAction(
                icon: LucideIcons.messageCircle,
                label: 'Message',
              ),
              const SizedBox(width: 6),
              const _CourierAction(icon: LucideIcons.phone, label: 'Call'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourierAction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CourierAction({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: BStoreColors.textPrimary,
          side: const BorderSide(color: BStoreColors.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17),
            const SizedBox(height: 2),
            Text(
              label,
              style:
                  const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewDetailsCard extends StatelessWidget {
  final _TrackingOrder order;

  const _ViewDetailsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.id} details will open here.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        decoration: BStoreDecorations.card(radius: 14),
        child: const Row(
          children: [
            Icon(
              LucideIcons.box,
              color: BStoreColors.primary,
              size: 24,
            ),
            SizedBox(width: 13),
            Expanded(
              child: Text(
                'View order details',
                style: TextStyle(
                  color: BStoreColors.primary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              color: BStoreColors.primary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
