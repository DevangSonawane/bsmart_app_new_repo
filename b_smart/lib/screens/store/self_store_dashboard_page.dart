import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shared/store_shared_widgets.dart';

class SelfStoreDashboardPage extends StatelessWidget {
  const SelfStoreDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        const _SelfDashboardHeader(),
        const _LiveStatusCard(),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _RevenueCard(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: GridView.count(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.74,
            children: const [
              _DashboardStatCard(
                icon: LucideIcons.briefcaseBusiness,
                label: 'Services',
                value: '3',
                suffix: 'active',
                tone: StoreDashboardTone.teal,
              ),
              _DashboardStatCard(
                icon: LucideIcons.box,
                label: 'Products',
                value: '8',
                suffix: 'active',
                tone: StoreDashboardTone.purple,
              ),
              _DashboardStatCard(
                icon: LucideIcons.calendarDays,
                label: 'Bookings',
                value: '4',
                suffix: 'new',
                tone: StoreDashboardTone.teal,
              ),
              _DashboardStatCard(
                icon: LucideIcons.shoppingBag,
                label: 'Orders',
                value: '7',
                suffix: 'open',
                tone: StoreDashboardTone.purple,
              ),
            ],
          ),
        ),
        const _DashboardSectionHeading('Quick actions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  label: 'Add Service',
                  tone: StoreDashboardTone.teal,
                  onTap: () => Navigator.of(context)
                      .pushNamed('/store/publish/add-product'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionButton(
                  label: 'Add Product',
                  tone: StoreDashboardTone.purple,
                  onTap: () => Navigator.of(context)
                      .pushNamed('/store/publish/add-product'),
                ),
              ),
            ],
          ),
        ),
        const _DashboardSectionHeading('Recent activity'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: StoreRecentActivityCard(),
        ),
      ],
    );
  }
}

class StoreRecentActivityCard extends StatelessWidget {
  const StoreRecentActivityCard({super.key});

  static const _items = [
    _ActivityItem(
      icon: LucideIcons.calendarDays,
      title: 'New booking request',
      subtitle: 'Today, 10:24 AM',
      tone: StoreDashboardTone.teal,
    ),
    _ActivityItem(
      icon: LucideIcons.shoppingBag,
      title: 'New product order',
      subtitle: 'Today, 9:15 AM',
      tone: StoreDashboardTone.purple,
    ),
    _ActivityItem(
      icon: LucideIcons.star,
      title: 'Review received',
      subtitle: 'Yesterday, 6:42 PM',
      tone: StoreDashboardTone.teal,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            _RecentActivityRow(item: _items[i]),
            if (i != _items.length - 1)
              const Divider(
                height: 1,
                indent: 72,
                endIndent: 12,
                color: Color(0xFFE8E8E8),
              ),
          ],
        ],
      ),
    );
  }
}

class _SelfDashboardHeader extends StatelessWidget {
  const _SelfDashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 12,
        16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: StoreBsmartWordmark()),
              const SizedBox(width: 8),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EDF9),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.userRound,
                      color: Color(0xFF684AC8),
                      size: 19,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Creator mode',
                      style: TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    LucideIcons.bell,
                    color: Color(0xFF060D35),
                    size: 25,
                  ),
                  Positioned(
                    right: -2,
                    top: -4,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: const BoxDecoration(
                        color: Color(0xFF654BD2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'My Store',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 34,
              fontWeight: FontWeight.w800,
              fontFamily: 'serif',
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFBF8FFFF),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFFD9E4E5)),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        color: Color(0xFF049844),
                        size: 9,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Live',
                        style: TextStyle(
                          color: Color(0xFF00913F),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Your store is live and visible to customers.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF29304D),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 38, color: const Color(0xFFC5D3D8)),
            const SizedBox(width: 8),
            const Icon(LucideIcons.eye, color: Color(0xFF078D92), size: 21),
            const SizedBox(width: 6),
            const Flexible(
              child: Text(
                'View as customer',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF078D92),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This month',
                  style: TextStyle(
                    color: Color(0xFF333956),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  r'$1,240',
                  style: TextStyle(
                    color: Color(0xFF078D92),
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 34,
                  width: double.infinity,
                  child: CustomPaint(painter: _SparklinePainter()),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 82, color: const Color(0xFFD7D9DE)),
          const SizedBox(width: 18),
          const Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Available balance',
                  style: TextStyle(
                    color: Color(0xFF333956),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 9),
                Text(
                  r'$860',
                  style: TextStyle(
                    color: Color(0xFF078D92),
                    fontSize: 31,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'serif',
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

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFF078D92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x33078D92), Color(0x00078D92)],
      ).createShader(Offset.zero & size);
    final path = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(
        size.width * 0.18,
        size.height * 0.35,
        size.width * 0.28,
        size.height * 0.92,
        size.width * 0.42,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.56,
        size.height * 0.05,
        size.width * 0.60,
        size.height * 0.80,
        size.width * 0.72,
        size.height * 0.26,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * -0.16,
        size.width * 0.84,
        size.height * 0.68,
        size.width,
        size.height * 0.12,
      );

    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final StoreDashboardTone tone;

  const _DashboardStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.suffix,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 9, 6, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: tone.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tone.color, size: 18),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF060D35),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333956),
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: tone.color,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(text: ' $suffix'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionHeading extends StatelessWidget {
  final String title;

  const _DashboardSectionHeading(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 11),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF060D35),
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final StoreDashboardTone tone;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.tone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tone.color,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(LucideIcons.plus, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final StoreDashboardTone tone;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
  });
}

class _RecentActivityRow extends StatelessWidget {
  final _ActivityItem item;

  const _RecentActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          const SizedBox(width: 11),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.tone.background,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.tone.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF333956),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight,
              color: Color(0xFF29304D), size: 21),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
