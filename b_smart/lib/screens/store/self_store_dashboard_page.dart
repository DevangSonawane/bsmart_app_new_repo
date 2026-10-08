import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../services/auth/auth_service.dart';
import 'self_store_orders_page.dart';
import 'self_store_products_page.dart';
import 'self_store_services_manage_page.dart';
import 'shared/store_shared_widgets.dart';
import 'shared/store_money.dart';
import 'store_models.dart';
import 'store_theme.dart';
import 'store_role_setup_screen.dart';
import 'store_role_switch_sheet.dart';

class SelfStoreDashboardPage extends StatefulWidget {
  final bool showHeader;

  const SelfStoreDashboardPage({
    super.key,
    this.showHeader = true,
  });

  @override
  State<SelfStoreDashboardPage> createState() => _SelfStoreDashboardPageState();
}

class _DashboardData {
  final int products;
  final int services;
  final int openOrders;
  final int newBookings;
  final double orderVolume;
  final List<_ActivityItem> activity;

  const _DashboardData({
    required this.products,
    required this.services,
    required this.openOrders,
    required this.newBookings,
    required this.orderVolume,
    required this.activity,
  });

  static const empty = _DashboardData(
    products: 0,
    services: 0,
    openOrders: 0,
    newBookings: 0,
    orderVolume: 0,
    activity: [],
  );
}

class _SelfStoreDashboardPageState extends State<SelfStoreDashboardPage> {
  late Future<_DashboardData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  static Future<_DashboardData> _load() async {
    final api = Phase2StoreApi();
    // Parallel: one round-trip instead of four sequential ones.
    final results = await Future.wait<dynamic>([
      api.myProducts().catchError((_) => <Map<String, dynamic>>[]),
      api.myServices().catchError((_) => <Map<String, dynamic>>[]),
      api.sellerOrders().catchError((_) => <Map<String, dynamic>>[]),
      api.sellerServiceBookings().catchError((_) => <Map<String, dynamic>>[]),
    ]);
    final products = List<Map<String, dynamic>>.from(results[0] as List);
    final services = List<Map<String, dynamic>>.from(results[1] as List);
    final orders = List<Map<String, dynamic>>.from(results[2] as List);
    final bookings = List<Map<String, dynamic>>.from(results[3] as List);

    var openOrders = 0;
    var volume = 0.0;
    for (final order in orders) {
      final status = StoreMockState.statusOf(order);
      if (status == 'cancelled' || status == 'canceled') continue;
      volume += StoreMockState.amountOf(order);
      if (status != 'delivered' && status != 'completed') openOrders++;
    }
    var newBookings = 0;
    for (final booking in bookings) {
      final status = StoreMockState.statusOf(booking);
      if (status == 'pending' || status == 'confirmed' || status == 'paid') {
        newBookings++;
      }
    }
    final liveServices =
        services.where((s) => s['visible_to_customers'] != false).length;

    final activity = <_ActivityItem>[];
    for (final order in orders.take(2)) {
      final id = StoreMockState.orderIdOf(order);
      activity.add(_ActivityItem(
        icon: LucideIcons.shoppingBag,
        title: 'Product order ${id.isEmpty ? '' : '#$id'}',
        subtitle: StoreMockState.statusOf(order).replaceAll('_', ' '),
        tone: StoreDashboardTone.purple,
      ));
    }
    for (final booking in bookings.take(3 - activity.length)) {
      final id = StoreMockState.bookingIdOf(booking);
      activity.add(_ActivityItem(
        icon: LucideIcons.calendarDays,
        title: 'Booking ${id.isEmpty ? 'request' : '#$id'}',
        subtitle: StoreMockState.statusOf(booking).replaceAll('_', ' '),
        tone: StoreDashboardTone.teal,
      ));
    }

    return _DashboardData(
      products: products.length,
      services: liveServices,
      openOrders: openOrders,
      newBookings: newBookings,
      orderVolume: volume,
      activity: activity,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The tab shell no longer shows its own title bar above this page, so the
    // first block carries the status-bar inset itself.
    final topInset =
        widget.showHeader ? 14.0 : MediaQuery.of(context).padding.top + 12;
    return SliverList.list(
      children: [
        if (widget.showHeader) const _SelfDashboardHeader(),
        Padding(
          padding: EdgeInsets.fromLTRB(16, topInset, 16, 0),
          child: _CommandDeck(dataFuture: _dataFuture),
        ),
        const _DashboardSectionHeading('Manage'),
        _ManageSection(dataFuture: _dataFuture),
        const _DashboardSectionHeading('Recent activity'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ActivityCard(dataFuture: _dataFuture),
        ),
      ],
    );
  }
}

class _CommandDeck extends StatelessWidget {
  final Future<_DashboardData> dataFuture;

  const _CommandDeck({required this.dataFuture});

  static const _neon = Color(0xFF5EEAD4);
  static const _ink = Color(0xFF0B1030);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_ink, Color(0xFF16215C), Color(0xFF2A1B5E)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF078D92).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -56,
            top: -64,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF078D92).withValues(alpha: 0.5),
                    const Color(0xFF078D92).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -48,
            bottom: -72,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF684AC8).withValues(alpha: 0.45),
                    const Color(0xFF684AC8).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: FutureBuilder<_DashboardData>(
              future: dataFuture,
              builder: (context, snapshot) {
                final data = snapshot.data ?? _DashboardData.empty;
                final loading =
                    snapshot.connectionState != ConnectionState.done;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PulseDot(),
                              SizedBox(width: 6),
                              Text(
                                'SELLER STUDIO · LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Total volume',
                      style: TextStyle(
                        color: Color(0xFF9AA3C7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    loading
                        ? const SizedBox(
                            height: 40,
                            width: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(_neon),
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatStoreMoney(data.orderVolume),
                              style: const TextStyle(
                                color: _neon,
                                fontSize: 38,
                                height: 1.0,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                    const SizedBox(height: 4),
                    const Text(
                      'Across all non-cancelled orders',
                      style: TextStyle(
                        color: Color(0xFF9AA3C7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _GlassStat(
                          icon: LucideIcons.box,
                          value: loading ? '–' : '${data.products}',
                          label: 'Products',
                        ),
                        _GlassStat(
                          icon: LucideIcons.briefcaseBusiness,
                          value: loading ? '–' : '${data.services}',
                          label: 'Services',
                        ),
                        _GlassStat(
                          icon: LucideIcons.shoppingBag,
                          value: loading ? '–' : '${data.openOrders}',
                          label: 'Open orders',
                        ),
                        _GlassStat(
                          icon: LucideIcons.calendarDays,
                          value: loading ? '–' : '${data.newBookings}',
                          label: 'Bookings',
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF34D399),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _GlassStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _GlassStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF9AA3C7), size: 15),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageSection extends StatelessWidget {
  final Future<_DashboardData> dataFuture;

  const _ManageSection({required this.dataFuture});

  void _openProducts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SelfStoreProductsScreen(),
      ),
    );
  }

  void _openServices(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SelfStoreServicesManageScreen(),
      ),
    );
  }

  void _openOrders(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SelfStoreOrdersPage(showHeader: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _DashboardData.empty;
        final attention = data.openOrders + data.newBookings;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _ManageNavCard(
                icon: LucideIcons.package,
                tint: BStoreColors.primary,
                tintSoft: BStoreColors.primarySoft,
                title: 'My Products',
                subtitle: '${data.products} listed',
                onTap: () => _openProducts(context),
              ),
              const SizedBox(height: 10),
              _ManageNavCard(
                icon: LucideIcons.briefcaseBusiness,
                tint: BStoreColors.accentPurple,
                tintSoft: BStoreColors.accentPurpleSoft,
                title: 'My Services',
                subtitle: '${data.services} live',
                onTap: () => _openServices(context),
              ),
              const SizedBox(height: 10),
              _ManageNavCard(
                icon: LucideIcons.shoppingBag,
                tint: const Color(0xFFE87822),
                tintSoft: const Color(0xFFFFF1E3),
                title: 'Orders & Bookings',
                subtitle: attention > 0
                    ? '$attention need attention'
                    : 'All caught up',
                alert: attention > 0,
                onTap: () => _openOrders(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ManageNavCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final Color tintSoft;
  final String title;
  final String subtitle;
  final bool alert;
  final VoidCallback onTap;

  const _ManageNavCard({
    required this.icon,
    required this.tint,
    required this.tintSoft,
    required this.title,
    required this.subtitle,
    this.alert = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BStoreDecorations.card(radius: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tintSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: tint, size: 24),
              ),
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
                        color: Color(0xFF060D35),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: alert
                            ? const Color(0xFFE87822)
                            : const Color(0xFF8B90A2),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.chevronRight,
                  color: Color(0xFF060D35),
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final Future<_DashboardData> dataFuture;

  const _ActivityCard({required this.dataFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: dataFuture,
      builder: (context, snapshot) {
        final items = snapshot.data?.activity ?? const <_ActivityItem>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const CircularProgressIndicator(),
          );
        }
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
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
            child: const Text(
              'No activity yet. New orders and bookings will appear here.',
              style: TextStyle(
                color: Color(0xFF333956),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
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
              for (var i = 0; i < items.length; i++) ...[
                _RecentActivityRow(item: items[i]),
                if (i != items.length - 1)
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
      },
    );
  }
}

class _SelfDashboardHeader extends StatelessWidget {
  const _SelfDashboardHeader();

  static Future<String> _loadRole() async {
    try {
      final user = await AuthService().fetchCurrentUser();
      final role = (user?.role ?? '').trim().toLowerCase();
      if (role.isEmpty) return 'Member';
      return role[0].toUpperCase() + role.substring(1);
    } catch (_) {
      return 'Member';
    }
  }

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
              InkWell(
                onTap: () => showStoreRoleSwitchSheet(context),
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2EDF9),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.userRound,
                        color: Color(0xFF684AC8),
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      FutureBuilder<String>(
                        future: _loadRole(),
                        builder: (context, snapshot) => Text(
                          snapshot.data ?? 'Member',
                          style: const TextStyle(
                            color: Color(0xFF060D35),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
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

