import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'store_theme.dart';

class StoreHomeScreen extends StatefulWidget {
  final bool isSelfStore;
  final String? ownerUserId;

  const StoreHomeScreen({
    super.key,
    this.isSelfStore = true,
    this.ownerUserId,
  });

  static StoreHomeScreen fromRouteArgs(Object? args) {
    if (args is StoreHomeScreenArgs) {
      return StoreHomeScreen(
        isSelfStore: args.isSelfStore,
        ownerUserId: args.ownerUserId,
      );
    }
    if (args is Map) {
      final rawIsSelf = args['isSelfStore'];
      return StoreHomeScreen(
        isSelfStore: rawIsSelf is bool ? rawIsSelf : true,
        ownerUserId: args['ownerUserId']?.toString(),
      );
    }
    return const StoreHomeScreen();
  }

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class StoreHomeScreenArgs {
  final bool isSelfStore;
  final String? ownerUserId;

  const StoreHomeScreenArgs({
    this.isSelfStore = true,
    this.ownerUserId,
  });
}

enum _StoreNavSection {
  dashboard,
  listings,
  activity,
  inbox,
  store,
  history,
  cart,
  profile,
}

class _StoreNavItem {
  final IconData icon;
  final String label;
  final _StoreNavSection section;

  const _StoreNavItem({
    required this.icon,
    required this.label,
    required this.section,
  });
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  int _selectedNav = 0;
  int _refreshTick = 0;

  List<_StoreNavItem> get _navItems {
    if (widget.isSelfStore) {
      return const [
        _StoreNavItem(
          icon: LucideIcons.house,
          label: 'Dashboard',
          section: _StoreNavSection.dashboard,
        ),
        _StoreNavItem(
          icon: LucideIcons.box,
          label: 'Listings',
          section: _StoreNavSection.listings,
        ),
        _StoreNavItem(
          icon: LucideIcons.trendingUp,
          label: 'Activity',
          section: _StoreNavSection.activity,
        ),
        _StoreNavItem(
          icon: LucideIcons.messageCircle,
          label: 'Inbox',
          section: _StoreNavSection.inbox,
        ),
        _StoreNavItem(
          icon: LucideIcons.circleUserRound,
          label: 'Profile',
          section: _StoreNavSection.profile,
        ),
      ];
    }

    return const [
      _StoreNavItem(
        icon: LucideIcons.store,
        label: 'Store',
        section: _StoreNavSection.store,
      ),
      _StoreNavItem(
        icon: LucideIcons.history,
        label: 'History',
        section: _StoreNavSection.history,
      ),
      _StoreNavItem(
        icon: LucideIcons.shoppingCart,
        label: 'Cart',
        section: _StoreNavSection.cart,
      ),
        _StoreNavItem(
          icon: LucideIcons.circleUserRound,
          label: 'Profile',
          section: _StoreNavSection.profile,
        ),
    ];
  }

  Future<void> _refreshStorePage() async {
    setState(() => _refreshTick++);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems;
    final selectedIndex = _selectedNav.clamp(0, navItems.length - 1);
    final selectedItem = navItems[selectedIndex];
    final isSelfDashboard = widget.isSelfStore &&
        selectedItem.section == _StoreNavSection.dashboard;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator.adaptive(
                color: StorePalette.blue,
                onRefresh: _refreshStorePage,
                child: CustomScrollView(
                  key: ValueKey('${selectedItem.section}-$_refreshTick'),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    if (!isSelfDashboard)
                      _StoreHeader(
                        isSelfStore: widget.isSelfStore,
                        activeLabel: selectedItem.label,
                        ownerUserId: widget.ownerUserId,
                      ),
                    _buildSection(selectedItem.section),
                    const SliverToBoxAdapter(child: SizedBox(height: 22)),
                  ],
                ),
              ),
            ),
            _StoreFooterNav(
              items: navItems,
              selectedIndex: selectedIndex,
              onSelected: (index) => setState(() => _selectedNav = index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(_StoreNavSection section) {
    return switch (section) {
      _StoreNavSection.dashboard => const _SelfDashboardPage(),
      _StoreNavSection.listings => const _ListingsSection(),
      _StoreNavSection.activity => const _ActivitySection(),
      _StoreNavSection.inbox => const _InboxSection(),
      _StoreNavSection.profile =>
        _ProfileSection(isSelfStore: widget.isSelfStore),
      _StoreNavSection.store => const _VisitorStoreSection(),
      _StoreNavSection.history => const _HistorySection(),
      _StoreNavSection.cart => const _CartSection(),
    };
  }
}

class _StoreHeader extends StatelessWidget {
  final bool isSelfStore;
  final String activeLabel;
  final String? ownerUserId;

  const _StoreHeader({
    required this.isSelfStore,
    required this.activeLabel,
    required this.ownerUserId,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          18,
          MediaQuery.of(context).padding.top + 14,
          18,
          18,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE8EBF0)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(LucideIcons.arrowLeft, size: 21),
                  tooltip: 'Back',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F4F8),
                    foregroundColor: Colors.black87,
                    fixedSize: const Size(40, 40),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isSelfStore ? 'My Store' : 'Store',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/store/search'),
                  icon: const Icon(LucideIcons.search, size: 21),
                  tooltip: 'Search',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F4F8),
                    foregroundColor: Colors.black87,
                    fixedSize: const Size(40, 40),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              activeLabel,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isSelfStore
                  ? 'Manage products, services, reach, and store identity.'
                  : 'Browse this seller, track activity, and manage checkout.',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!isSelfStore && ownerUserId != null) ...[
              const SizedBox(height: 8),
              Text(
                'Store owner: $ownerUserId',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black45,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelfDashboardPage extends StatelessWidget {
  const _SelfDashboardPage();

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
            childAspectRatio: 0.82,
            children: const [
              _DashboardStatCard(
                icon: LucideIcons.briefcaseBusiness,
                label: 'Services',
                value: '3',
                suffix: 'active',
                tone: _DashboardTone.teal,
              ),
              _DashboardStatCard(
                icon: LucideIcons.box,
                label: 'Products',
                value: '8',
                suffix: 'active',
                tone: _DashboardTone.purple,
              ),
              _DashboardStatCard(
                icon: LucideIcons.calendarDays,
                label: 'Bookings',
                value: '4',
                suffix: 'new',
                tone: _DashboardTone.teal,
              ),
              _DashboardStatCard(
                icon: LucideIcons.shoppingBag,
                label: 'Orders',
                value: '7',
                suffix: 'open',
                tone: _DashboardTone.purple,
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
                  tone: _DashboardTone.teal,
                  onTap: () => Navigator.of(context)
                      .pushNamed('/store/publish/add-product'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionButton(
                  label: 'Add Product',
                  tone: _DashboardTone.purple,
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
          child: _RecentActivityCard(),
        ),
      ],
    );
  }
}

class _SelfDashboardHeader extends StatelessWidget {
  const _SelfDashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 18,
        20,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _BsmartWordmark()),
              const SizedBox(width: 12),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EDF9),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.userRound,
                      color: Color(0xFF684AC8),
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Creator mode',
                      style: TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    LucideIcons.bell,
                    color: Color(0xFF060D35),
                    size: 30,
                  ),
                  Positioned(
                    right: -2,
                    top: -4,
                    child: Container(
                      width: 13,
                      height: 13,
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
          const SizedBox(height: 42),
          const Text(
            'My Store',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 42,
              fontWeight: FontWeight.w800,
              fontFamily: 'serif',
            ),
          ),
        ],
      ),
    );
  }
}

class _BsmartWordmark extends StatelessWidget {
  const _BsmartWordmark();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: RichText(
        text: const TextSpan(
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
          children: [
            TextSpan(text: 'B', style: TextStyle(color: Color(0xFF078D92))),
            TextSpan(text: 'SMART', style: TextStyle(color: Color(0xFF071238))),
          ],
        ),
      ),
    );
  }
}

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                        size: 11,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Live',
                        style: TextStyle(
                          color: Color(0xFF00913F),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Your store is live and visible to customers.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF29304D),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 54, color: const Color(0xFFC5D3D8)),
            const SizedBox(width: 14),
            const Icon(LucideIcons.eye, color: Color(0xFF078D92), size: 28),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'View as customer',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF078D92),
                  fontSize: 16,
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
      constraints: const BoxConstraints(minHeight: 162),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  r'$1,240',
                  style: TextStyle(
                    color: Color(0xFF078D92),
                    fontSize: 40,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  height: 44,
                  width: double.infinity,
                  child: CustomPaint(painter: _SparklinePainter()),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 104, color: const Color(0xFFD7D9DE)),
          const SizedBox(width: 24),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 13),
                Text(
                  r'$860',
                  style: TextStyle(
                    color: Color(0xFF078D92),
                    fontSize: 38,
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
      ..strokeWidth = 2.6
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

enum _DashboardTone { teal, purple }

extension _DashboardToneColor on _DashboardTone {
  Color get color => switch (this) {
        _DashboardTone.teal => const Color(0xFF078D92),
        _DashboardTone.purple => const Color(0xFF684AC8),
      };

  Color get background => switch (this) {
        _DashboardTone.teal => const Color(0xFFE9F6F5),
        _DashboardTone.purple => const Color(0xFFF1ECFA),
      };
}

class _DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String suffix;
  final _DashboardTone tone;

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
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
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
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: tone.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: tone.color, size: 26),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF060D35),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333956),
                ),
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: tone.color,
                      fontSize: 21,
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
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF060D35),
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final _DashboardTone tone;
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 73,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.color,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(LucideIcons.plus, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 18),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 16,
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

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard();

  static const _items = [
    _ActivityItem(
      icon: LucideIcons.calendarDays,
      title: 'New booking request',
      subtitle: 'Today, 10:24 AM',
      tone: _DashboardTone.teal,
    ),
    _ActivityItem(
      icon: LucideIcons.shoppingBag,
      title: 'New product order',
      subtitle: 'Today, 9:15 AM',
      tone: _DashboardTone.purple,
    ),
    _ActivityItem(
      icon: LucideIcons.star,
      title: 'Review received',
      subtitle: 'Yesterday, 6:42 PM',
      tone: _DashboardTone.teal,
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

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final _DashboardTone tone;

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
      height: 70,
      child: Row(
        children: [
          const SizedBox(width: 13),
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: item.tone.background,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.tone.color, size: 23),
          ),
          const SizedBox(width: 14),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF333956),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight,
              color: Color(0xFF29304D), size: 24),
          const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _ListingsSection extends StatelessWidget {
  const _ListingsSection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        _SectionTitle(
          title: 'Listings',
          subtitle: 'Products and services published from your store.',
        ),
        _ListingPreviewList(),
      ],
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        _SectionTitle(
          title: 'Activity',
          subtitle: 'Orders, bookings, reviews, and store updates.',
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _RecentActivityCard(),
        ),
      ],
    );
  }
}

class _InboxSection extends StatelessWidget {
  const _InboxSection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        _SectionTitle(
          title: 'Inbox',
          subtitle: 'Customer messages and store conversations.',
        ),
        _EmptyState(
          icon: LucideIcons.messageCircle,
          title: 'No store messages yet',
          body: 'Customer questions and booking chats will appear here.',
        ),
      ],
    );
  }
}

class _VisitorStoreSection extends StatelessWidget {
  const _VisitorStoreSection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        const _SectionTitle(
          title: 'Store',
          subtitle: 'Products and services from this user.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SearchStrip(
            onTap: () => Navigator.of(context).pushNamed('/store/search'),
          ),
        ),
        const SizedBox(height: 14),
        const _ListingPreviewList(),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        _SectionTitle(
          title: 'History',
          subtitle:
              'Viewed listings, previous purchases, and store interactions.',
        ),
        _EmptyState(
          icon: LucideIcons.clock3,
          title: 'No store history yet',
          body:
              'Products and services you view from this store will show here.',
        ),
      ],
    );
  }
}

class _CartSection extends StatelessWidget {
  const _CartSection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        _SectionTitle(
          title: 'Cart',
          subtitle: 'Items selected from this store.',
        ),
        _EmptyState(
          icon: LucideIcons.shoppingCart,
          title: 'Your cart is empty',
          body: 'Add products or services from the store to prepare checkout.',
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final bool isSelfStore;

  const _ProfileSection({required this.isSelfStore});

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        _SectionTitle(
          title: 'Profile',
          subtitle: isSelfStore
              ? 'Store identity, public details, and seller preferences.'
              : 'Seller details and ways to connect.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ActionPanel(
            icon: LucideIcons.badgeCheck,
            title: isSelfStore
                ? 'Complete store profile'
                : 'Verified seller profile',
            body: isSelfStore
                ? 'Logo, address, categories, and support details will be managed here.'
                : 'Store information, policies, and contact options will appear here.',
            actionLabel: isSelfStore ? 'Edit profile' : 'View details',
            onTapRoute: isSelfStore ? '/edit-profile' : null,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final String? onTapRoute;

  const _ActionPanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.onTapRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3E7ED)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: StorePalette.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: FilledButton(
                    onPressed: onTapRoute == null
                        ? null
                        : () => Navigator.of(context).pushNamed(onTapRoute!),
                    style: FilledButton.styleFrom(
                      backgroundColor: StorePalette.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE7EBF1),
                      disabledForegroundColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
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

class _SearchStrip extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchStrip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE3E7ED)),
          ),
          child: const Row(
            children: [
              Icon(LucideIcons.search, color: Colors.black54, size: 20),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Search this store',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

class _ListingPreviewList extends StatelessWidget {
  const _ListingPreviewList();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _ListingRow(
            icon: LucideIcons.packageOpen,
            title: 'Product listings',
            subtitle: 'Inventory, pricing, photos, and delivery settings.',
          ),
          SizedBox(height: 10),
          _ListingRow(
            icon: LucideIcons.briefcaseBusiness,
            title: 'Service listings',
            subtitle: 'Availability, location, pricing, and booking details.',
          ),
        ],
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ListingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3E7ED)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronRight, color: Colors.black38, size: 20),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3E7ED)),
        ),
        child: Column(
          children: [
            Icon(icon, color: StorePalette.blue, size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreFooterNav extends StatelessWidget {
  final List<_StoreNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _StoreFooterNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE1E4E8)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _FooterButton(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final _StoreNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _FooterButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? StorePalette.blue : const Color(0xFF657080);
    return Tooltip(
      message: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: selected ? null : onTap,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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
