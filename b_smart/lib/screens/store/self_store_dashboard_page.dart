import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../services/auth/auth_service.dart';
import '../../services/wallet_service.dart';
import 'self_store_products_page.dart';
import 'self_store_services_manage_page.dart';
import 'shared/store_shared_widgets.dart';
import 'shared/store_money.dart';
import 'store_models.dart';
import 'store_role_setup_screen.dart';
import 'store_role_switch_sheet.dart';

class SelfStoreDashboardPage extends StatefulWidget {
  const SelfStoreDashboardPage({super.key});

  @override
  State<SelfStoreDashboardPage> createState() => _SelfStoreDashboardPageState();
}

class _DashboardData {
  final int products;
  final int services;
  final int openOrders;
  final int newBookings;
  final double orderVolume;
  final int walletCoins;
  final List<_ActivityItem> activity;

  const _DashboardData({
    required this.products,
    required this.services,
    required this.openOrders,
    required this.newBookings,
    required this.orderVolume,
    required this.walletCoins,
    required this.activity,
  });

  static const empty = _DashboardData(
    products: 0,
    services: 0,
    openOrders: 0,
    newBookings: 0,
    orderVolume: 0,
    walletCoins: 0,
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
    // Parallel: one round-trip instead of five sequential ones.
    final results = await Future.wait<dynamic>([
      api.myProducts().catchError((_) => <Map<String, dynamic>>[]),
      api.myServices().catchError((_) => <Map<String, dynamic>>[]),
      api.sellerOrders().catchError((_) => <Map<String, dynamic>>[]),
      api.sellerServiceBookings().catchError((_) => <Map<String, dynamic>>[]),
      WalletService().getCoinBalance().catchError((_) => 0),
    ]);
    final products =
        List<Map<String, dynamic>>.from(results[0] as List);
    final services =
        List<Map<String, dynamic>>.from(results[1] as List);
    final orders = List<Map<String, dynamic>>.from(results[2] as List);
    final bookings =
        List<Map<String, dynamic>>.from(results[3] as List);
    final coins = (results[4] as num?)?.toInt() ?? 0;

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
      if (status == 'pending' ||
          status == 'confirmed' ||
          status == 'paid') {
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
      walletCoins: coins,
      activity: activity,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        const _SelfDashboardHeader(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _RevenueCard(dataFuture: _dataFuture),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _StatsGrid(dataFuture: _dataFuture),
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
                  onTap: () async {
                    if (!await StoreRoleGate.ensureInfluencer(context)) return;
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StoreAddServiceFlowScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionButton(
                  label: 'Add Product',
                  tone: StoreDashboardTone.purple,
                  onTap: () async {
                    if (!await StoreRoleGate.ensureInfluencer(context)) return;
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StoreAddProductFlowScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const _DashboardSectionHeading('Recent activity'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ActivityCard(dataFuture: _dataFuture),
        ),
      ],
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


class _StatsGrid extends StatelessWidget {
  final Future<_DashboardData> dataFuture;

  const _StatsGrid({required this.dataFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _DashboardData.empty;
        return GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.74,
          children: [
            _DashboardStatCard(
              icon: LucideIcons.briefcaseBusiness,
              label: 'Services',
              value: '${data.services}',
              suffix: 'live',
              tone: StoreDashboardTone.teal,
            ),
            _DashboardStatCard(
              icon: LucideIcons.box,
              label: 'Products',
              value: '${data.products}',
              suffix: 'listed',
              tone: StoreDashboardTone.purple,
            ),
            _DashboardStatCard(
              icon: LucideIcons.calendarDays,
              label: 'Bookings',
              value: '${data.newBookings}',
              suffix: 'new',
              tone: StoreDashboardTone.teal,
            ),
            _DashboardStatCard(
              icon: LucideIcons.shoppingBag,
              label: 'Orders',
              value: '${data.openOrders}',
              suffix: 'open',
              tone: StoreDashboardTone.purple,
            ),
          ],
        );
      },
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final Future<_DashboardData> dataFuture;

  const _RevenueCard({required this.dataFuture});

  static String _money(double amount) =>
      formatStoreMoney(amount);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: dataFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? _DashboardData.empty;
        final loading =
            snapshot.connectionState != ConnectionState.done;
        return Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order volume',
                            style: TextStyle(
                              color: Color(0xFF333956),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _money(data.orderVolume),
                              style: const TextStyle(
                                color: Color(0xFF078D92),
                                fontSize: 32,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'serif',
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Across all non-cancelled orders',
                            style: TextStyle(
                              color: Color(0xFF596174),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                        width: 1, height: 82, color: const Color(0xFFD7D9DE)),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Wallet balance',
                            style: TextStyle(
                              color: Color(0xFF333956),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 9),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatStoreMoney(data.walletCoins.toDouble(), decimals: 0),
                              style: const TextStyle(
                                color: Color(0xFF078D92),
                                fontSize: 31,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'serif',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
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
