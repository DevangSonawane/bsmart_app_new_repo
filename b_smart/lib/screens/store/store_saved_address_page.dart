import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shared/store_shared_widgets.dart';
import 'store_theme.dart';

class StoreSavedAddressPage extends StatefulWidget {
  const StoreSavedAddressPage({super.key});

  @override
  State<StoreSavedAddressPage> createState() => _StoreSavedAddressPageState();
}

class _StoreSavedAddressPageState extends State<StoreSavedAddressPage> {
  int _selectedIndex = 0;

  static const _addresses = [
    _SavedAddressData(
      type: 'Home',
      name: 'Alex Morgan',
      address: '24 Market Street, San Diego, CA 92101',
      phone: '+1 619 555 0148',
      icon: LucideIcons.house,
      isDefault: true,
    ),
    _SavedAddressData(
      type: 'Work',
      name: 'Alex Morgan',
      address: '460 Harbor Avenue, San Diego, CA 92101',
      phone: '+1 619 555 0148',
      icon: LucideIcons.briefcaseBusiness,
      isDefault: false,
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
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    BStoreSpacing.screenX,
                    8,
                    BStoreSpacing.screenX,
                    MediaQuery.of(context).padding.bottom + 104,
                  ),
                  children: [
                    const _AddressHeader(),
                    const SizedBox(height: 14),
                    const _MapPreview(),
                    const SizedBox(height: 20),
                    const Text(
                      'Saved addresses',
                      style: TextStyle(
                        color: BStoreColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < _addresses.length; i++) ...[
                      _SavedAddressCard(
                        address: _addresses[i],
                        selected: _selectedIndex == i,
                        onTap: () => setState(() => _selectedIndex = i),
                      ),
                      const SizedBox(height: 9),
                    ],
                    const _AddAddressButton(),
                  ],
                ),
              ),
              const _DeliverHereButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedAddressData {
  final String type;
  final String name;
  final String address;
  final String phone;
  final IconData icon;
  final bool isDefault;

  const _SavedAddressData({
    required this.type,
    required this.name,
    required this.address,
    required this.phone,
    required this.icon,
    required this.isDefault,
  });
}

class _AddressHeader extends StatelessWidget {
  const _AddressHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.chevronLeft, size: 26),
              color: BStoreColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoreBsmartWordmark(),
              SizedBox(height: 14),
              Text(
                'Select address',
                style: TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 20,
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

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BStoreDecorations.card(radius: 18),
      clipBehavior: Clip.antiAlias,
      child: const CustomPaint(
        painter: _MapPreviewPainter(),
        child: Stack(
          children: [
            Positioned(
              left: 112,
              top: 114,
              child: _MapPin(size: 50),
            ),
            Positioned(
              right: 104,
              top: 50,
              child: _MapPin(size: 50),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  const _MapPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final water = Paint()..color = const Color(0xFFB9E2F1);
    final park = Paint()..color = const Color(0xFFD9EECF);
    final land = Paint()..color = const Color(0xFFF3F0EB);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadThin = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadShadow = Paint()
      ..color = const Color(0xFFE3DFD7)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(Offset.zero & size, land);

    final bay = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.22, 0)
      ..cubicTo(size.width * 0.15, size.height * 0.28, size.width * 0.17,
          size.height * 0.55, size.width * 0.08, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bay, water);

    for (final rect in [
      Rect.fromLTWH(size.width * 0.50, 10, 72, 72),
      Rect.fromLTWH(size.width * 0.74, 20, 110, 72),
      Rect.fromLTWH(size.width * 0.58, size.height * 0.66, 88, 66),
      Rect.fromLTWH(size.width * 0.82, size.height * 0.54, 58, 44),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        park,
      );
    }

    void drawRoad(List<Offset> points, Paint paint) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, roadShadow);
      canvas.drawPath(path, paint);
    }

    for (final x in [0.30, 0.43, 0.60, 0.72, 0.86]) {
      drawRoad([
        Offset(size.width * x, -8),
        Offset(size.width * (x - 0.02), size.height * 0.45),
        Offset(size.width * (x + 0.01), size.height + 8),
      ], roadThin);
    }

    for (final y in [0.18, 0.38, 0.58, 0.78]) {
      drawRoad([
        Offset(size.width * 0.08, size.height * y),
        Offset(size.width * 0.44, size.height * (y - 0.03)),
        Offset(size.width * 0.95, size.height * (y + 0.01)),
      ], y == 0.58 ? road : roadThin);
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    void drawLabel(String text, Offset offset, double angle) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle);
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.62),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
      canvas.restore();
    }

    drawLabel('Market St', Offset(size.width * 0.46, size.height * 0.41), -0.1);
    drawLabel('1st Ave', Offset(size.width * 0.70, size.height * 0.34), 1.52);
    drawLabel(
        'Kettner Blvd', Offset(size.width * 0.43, size.height * 0.70), 1.55);
    drawLabel('Marina', Offset(size.width * 0.92, size.height * 0.48), 0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPin extends StatelessWidget {
  final double size;

  const _MapPin({required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(
      LucideIcons.mapPin,
      color: BStoreColors.primary,
      size: size,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _SavedAddressCard extends StatelessWidget {
  final _SavedAddressData address;
  final bool selected;
  final VoidCallback onTap;

  const _SavedAddressCard({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 14, 11, 14),
        decoration: BStoreDecorations.card(radius: 18),
        child: Row(
          children: [
            _AddressRadio(selected: selected),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(address.icon, color: BStoreColors.primary, size: 23),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          address.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BStoreColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        const _DefaultBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    address.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.address,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 74, color: BStoreColors.divider),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(LucideIcons.pencil, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: BStoreColors.primary,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressRadio extends StatelessWidget {
  final bool selected;

  const _AddressRadio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 25,
      height: 25,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? BStoreColors.primary : BStoreColors.textMuted,
          width: selected ? 2.2 : 1.2,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? BStoreColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BStoreColors.accentPurpleSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Default',
        style: TextStyle(
          color: BStoreColors.accentPurple,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AddAddressButton extends StatelessWidget {
  const _AddAddressButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: const CustomPaint(
          painter: _DashedBorderPainter(),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.circlePlus,
                  color: BStoreColors.primary,
                  size: 21,
                ),
                SizedBox(width: 10),
                Text(
                  'Add new address',
                  style: TextStyle(
                    color: BStoreColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BStoreColors.primary
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 2.8).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 5.2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DeliverHereButton extends StatelessWidget {
  const _DeliverHereButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BStoreColors.background,
      padding: EdgeInsets.fromLTRB(
        BStoreSpacing.screenX,
        12,
        BStoreSpacing.screenX,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: BStoreButtons.filled(radius: 10),
          child: const Text(
            'Deliver here',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
