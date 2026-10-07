import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'self_store_dashboard_page.dart';
import 'self_store_orders_page.dart';
import 'self_store_products_page.dart';
import 'self_store_services_manage_page.dart';
import 'shared/store_shared_widgets.dart';
import 'store_bcoins_page.dart';
import 'store_order_tracking_page.dart';
import 'store_profile_page.dart';
import 'store_role_setup_screen.dart';
import 'store_role_switch_sheet.dart';
import 'store_theme.dart';
import 'store_saved_address_page.dart';
import 'store_floating_cart_button.dart';
import 'store_models.dart';
import 'store_wishlist.dart';
import 'visitor_marketplace_home_page.dart';
import 'visitor_store_cart_page.dart';

class StoreScreen extends StatefulWidget {
  final bool isSelfStore;
  final String? ownerUserId;

  const StoreScreen({
    super.key,
    this.isSelfStore = true,
    this.ownerUserId,
  });

  static StoreScreen fromRouteArgs(Object? args) {
    if (args is StoreScreenArgs) {
      return StoreScreen(
        isSelfStore: args.isSelfStore,
        ownerUserId: args.ownerUserId,
      );
    }
    if (args is Map) {
      final rawIsSelf = args['isSelfStore'];
      return StoreScreen(
        isSelfStore: rawIsSelf is bool ? rawIsSelf : true,
        ownerUserId: args['ownerUserId']?.toString(),
      );
    }
    return const StoreScreen();
  }

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreAddManagePage extends StatelessWidget {
  const _StoreAddManagePage();

  @override
  Widget build(BuildContext context) {
    Future<void> addProduct() async {
      if (!await StoreRoleGate.ensureInfluencer(context)) return;
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const StoreAddProductFlowScreen(),
        ),
      );
    }

    Future<void> addService() async {
      if (!await StoreRoleGate.ensureInfluencer(context)) return;
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const StoreAddServiceFlowScreen(),
        ),
      );
    }

    return SliverList.list(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _StoreAddHero(
            onAddProduct: addProduct,
            onAddService: addService,
          ),
        ),
        const SizedBox(height: 14),
        _StoreAddManageSection(
          title: 'My Products',
          icon: LucideIcons.package,
          addLabel: 'Add Product',
          onAdd: addProduct,
          api: const _ProductApi(),
        ),
        const SizedBox(height: 18),
        _StoreAddManageSection(
          title: 'My Services',
          icon: LucideIcons.briefcaseBusiness,
          addLabel: 'Add Service',
          onAdd: addService,
          api: const _ServiceApi(),
        ),
      ],
    );
  }
}

class _StoreAddHero extends StatelessWidget {
  final VoidCallback onAddProduct;
  final VoidCallback onAddService;

  const _StoreAddHero({
    required this.onAddProduct,
    required this.onAddService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: BStoreColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.sparkles, color: Colors.white, size: 22),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Create a listing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Add something customers can buy or book from your store.',
            style: TextStyle(
              color: Color(0xFFD9DEE8),
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAddProduct,
                  icon: const Icon(LucideIcons.packagePlus, size: 17),
                  label: const Text('Product'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BStoreColors.primary,
                    foregroundColor: Colors.white,
                    fixedSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAddService,
                  icon: const Icon(LucideIcons.calendarPlus, size: 17),
                  label: const Text('Service'),
                  style: FilledButton.styleFrom(
                    backgroundColor: BStoreColors.accentPurple,
                    foregroundColor: Colors.white,
                    fixedSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreAddManageSection extends StatefulWidget {
  final String title;
  final IconData icon;
  final String addLabel;
  final VoidCallback onAdd;
  final _StoreManageApi api;

  const _StoreAddManageSection({
    required this.title,
    required this.icon,
    required this.addLabel,
    required this.onAdd,
    required this.api,
  });

  @override
  State<_StoreAddManageSection> createState() => _StoreAddManageSectionState();
}

class _StoreAddManageSectionState extends State<_StoreAddManageSection> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.api.load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F5F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: BStoreColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text(widget.addLabel),
                style: TextButton.styleFrom(
                  foregroundColor: BStoreColors.primary,
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              if (items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BStoreColors.borderSoft),
                  ),
                  child: Text(
                    'No ${widget.title.toLowerCase()} yet. Tap ${widget.addLabel} to create your first.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BStoreColors.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final title =
                      (item['name'] ?? item['title'] ?? 'Item').toString();
                  final price = item['price'] ?? item['amount'] ?? 0;
                  final imageUrl = StoreMockState.firstImageUrl(item);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BStoreColors.borderSoft),
                    ),
                    child: Row(
                      children: [
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SafeNetworkImage(
                              url: imageUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              debugLabel: 'my-listing-thumbnail',
                              placeholder: _placeholder(),
                              errorWidget: _placeholder(),
                            ),
                          )
                        else
                          _placeholder(),
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
                                  color: BStoreColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$price',
                                style: const TextStyle(
                                  color: BStoreColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
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
            },
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(LucideIcons.package, size: 20, color: Colors.grey.shade400),
    );
  }
}

abstract class _StoreManageApi {
  Future<List<Map<String, dynamic>>> load();
}

class _ProductApi implements _StoreManageApi {
  const _ProductApi();

  @override
  Future<List<Map<String, dynamic>>> load() => Phase2StoreApi().myProducts();
}

class _ServiceApi implements _StoreManageApi {
  const _ServiceApi();

  @override
  Future<List<Map<String, dynamic>>> load() => Phase2StoreApi().myServices();
}

class StoreScreenArgs {
  final bool isSelfStore;
  final String? ownerUserId;

  const StoreScreenArgs({
    this.isSelfStore = true,
    this.ownerUserId,
  });
}

enum _StoreNavSection {
  home,
  myStore,
  add,
  orders,
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

class _StoreScreenState extends State<StoreScreen> {
  int _selectedNav = 0;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    // The embedded wishlist section cannot host its own ListenableBuilder
    // (a box widget is not a sliver), so the shell rebuilds on change.
    WishlistState.instance.addListener(_onWishlistChanged);
  }

  @override
  void dispose() {
    WishlistState.instance.removeListener(_onWishlistChanged);
    super.dispose();
  }

  void _onWishlistChanged() {
    if (mounted) setState(() {});
  }

  List<_StoreNavItem> get _navItems {
    if (widget.isSelfStore) {
      return const [
        _StoreNavItem(
          icon: LucideIcons.house,
          label: 'Home',
          section: _StoreNavSection.home,
        ),
        _StoreNavItem(
          icon: LucideIcons.store,
          label: 'My Store',
          section: _StoreNavSection.myStore,
        ),
        _StoreNavItem(
          icon: LucideIcons.squarePlus,
          label: '',
          section: _StoreNavSection.add,
        ),
        _StoreNavItem(
          icon: LucideIcons.shoppingBag,
          label: 'Orders',
          section: _StoreNavSection.orders,
        ),
        _StoreNavItem(
          icon: LucideIcons.shoppingCart,
          label: 'Cart',
          section: _StoreNavSection.cart,
        ),
      ];
    }

    return const [
      _StoreNavItem(
        icon: LucideIcons.house,
        label: 'Home',
        section: _StoreNavSection.home,
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
    final navItems = _navItems;
    final selectedIndex = _selectedNav.clamp(0, navItems.length - 1);
    final section = navItems[selectedIndex].section;
    if (section == _StoreNavSection.home) {
      await Future.wait([
        StoreMockState.instance.refreshMarketplace(),
        StoreMockState.instance.refreshCart(),
      ]);
      return;
    }
    if (section == _StoreNavSection.cart) {
      await StoreMockState.instance.refreshCart();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems;
    final selectedIndex = _selectedNav.clamp(0, navItems.length - 1);
    final selectedItem = navItems[selectedIndex];
    final isHomeMarketplace = selectedItem.section == _StoreNavSection.home;

    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.backgroundAlt,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: RefreshIndicator.adaptive(
                      color: BStoreColors.primary,
                      onRefresh: _refreshStorePage,
                      child: CustomScrollView(
                        key: ValueKey('${selectedItem.section}-$_refreshTick'),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // Home tab is the Swiggy-style marketplace: its
                          // maroon header bleeds from the very top, so the
                          // white title/profile bar is hidden here.
                          if (!isHomeMarketplace)
                            _MarketplaceHeaderSliver(
                              title: selectedItem.label.isEmpty
                                  ? 'Create'
                                  : selectedItem.label,
                              onProfileTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => StoreProfilePage(
                                      ownerUserId: widget.ownerUserId,
                                    ),
                                  ),
                                );
                              },
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
                    onSelected: (index) {
                      if (index == _selectedNav) return;
                      setState(() => _selectedNav = index);
                    },
                  ),
                ],
              ),
              // Draggable cart bubble floating above every store tab. Buyers
              // only: a self store has nothing to buy, so the bubble is hidden
              // there rather than rendered inert.
              if (!widget.isSelfStore)
                Positioned.fill(
                  child: StoreFloatingCartButton(
                    onTap: () {
                      final index = navItems.indexWhere(
                          (item) => item.section == _StoreNavSection.cart);
                      if (index >= 0 && index != _selectedNav) {
                        setState(() => _selectedNav = index);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(_StoreNavSection section) {
    return switch (section) {
      _StoreNavSection.home => widget.isSelfStore
          ? const StoreRoleGateSliver(
              child: VisitorMarketplaceHomePage(
                  showTopBar: false, showSellerHero: false),
            )
          : VisitorMarketplaceHomePage(
              ownerUserId: widget.ownerUserId,
              showTopBar: false,
              showSellerHero: false,
            ),
      _StoreNavSection.myStore => const StoreRoleGateSliver(
          child: SelfStoreDashboardPage(showHeader: false)),
      _StoreNavSection.add => const _StoreAddManagePage(),
      _StoreNavSection.orders => const StoreRoleGateSliver(
          child: SelfStoreOrdersPage(showHeader: false)),
      _StoreNavSection.cart => widget.isSelfStore
          ? const StoreRoleGateSliver(
              child: VisitorStoreCartPage(showHeader: false))
          : VisitorStoreCartPage(
              ownerUserId: widget.ownerUserId,
              showHeader: false,
            ),
      _StoreNavSection.profile =>
        _ProfileSection(isSelfStore: widget.isSelfStore),
    };
  }
}

class _MarketplaceHeaderSliver extends StatelessWidget {
  final String title;
  final VoidCallback onProfileTap;

  const _MarketplaceHeaderSliver({
    required this.title,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          18,
          MediaQuery.of(context).padding.top + 12,
          18,
          14,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Color(0xFFE8EBF0)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _MarketplaceHeaderIcon(
              icon: LucideIcons.heart,
              tooltip: 'Wishlist',
              badgeCount: WishlistState.instance.count,
              onTap: () => openWishlist(context),
            ),
            const SizedBox(width: 8),
            _MarketplaceHeaderIcon(
              icon: LucideIcons.circleUserRound,
              tooltip: 'Profile',
              onTap: onProfileTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceHeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  const _MarketplaceHeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 21),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFF1F4F8),
        foregroundColor: BStoreColors.textPrimary,
        fixedSize: const Size(40, 40),
      ),
    );
    if (badgeCount <= 0) return button;
    return Badge.count(
      count: badgeCount,
      backgroundColor: BStoreColors.primary,
      textColor: Colors.white,
      textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
      child: button,
    );
  }
}

class _InboxSection extends StatelessWidget {
  const _InboxSection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        StoreSectionTitle(
          title: 'Inbox',
          subtitle: 'Customer messages and store conversations.',
        ),
        StoreEmptyState(
          icon: LucideIcons.messageCircle,
          title: 'No store messages yet',
          body: 'Customer questions and booking chats will appear here.',
        ),
      ],
    );
  }
}

class _NetworkSection extends StatelessWidget {
  const _NetworkSection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        StoreSectionTitle(
          title: 'Network',
          subtitle: 'Connections and activity around this store.',
        ),
        StoreEmptyState(
          icon: LucideIcons.usersRound,
          title: 'No network activity yet',
          body:
              'Store followers, connections, and interactions will appear here.',
        ),
      ],
    );
  }
}

class _SelfStoreHubSection extends StatelessWidget {
  const _SelfStoreHubSection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            MediaQuery.of(context).padding.top + 12,
            18,
            0,
          ),
          child: const SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(child: StoreBsmartWordmark()),
                Icon(LucideIcons.search,
                    color: BStoreColors.textPrimary, size: 23),
                SizedBox(width: 18),
                _StoreNotificationBell(),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 22, 18, 0),
          child: Text(
            'My Store',
            style: TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _StoreRoleCard(),
        const SizedBox(height: 12),
        _SelfStoreHubCard(
          icon: LucideIcons.package,
          title: 'My Products',
          subtitle: 'Manage products, stock, drafts, and publishing.',
          countFuture: _HubCounts.products(),
          countSuffix: 'active',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SelfStoreProductsScreen(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SelfStoreHubCard(
          icon: LucideIcons.briefcaseBusiness,
          title: 'My Services',
          subtitle: 'Manage service listings, requests, and availability.',
          countFuture: _HubCounts.services(),
          countSuffix: 'published',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SelfStoreServicesManageScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Self-store role manager (member ↔ influencer).
///
/// Lives on the My Store home next to the creator tooling: one tap to
/// switch back to Member, or open the influencer setup form.
class _StoreRoleCard extends StatefulWidget {
  const _StoreRoleCard();

  @override
  State<_StoreRoleCard> createState() => _StoreRoleCardState();
}

class _StoreRoleCardState extends State<_StoreRoleCard> {
  late Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _loadRole();
  }

  static Future<String> _loadRole() async {
    try {
      final user = await AuthService().fetchCurrentUser();
      return (user?.role ?? '').trim().toLowerCase();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openSwitcher() async {
    await showStoreRoleSwitchSheet(context);
    if (!mounted) return;
    setState(() => _roleFuture = _loadRole());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        final role = snapshot.data ?? '';
        final isInfluencer = role == 'influencer';
        final label = role.isEmpty
            ? 'Unknown'
            : role[0].toUpperCase() + role.substring(1);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openSwitcher,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                decoration: storeSoftCardDecoration(radius: 12),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isInfluencer
                            ? const Color(0xFFE5F5F3)
                            : const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isInfluencer
                            ? LucideIcons.store
                            : LucideIcons.userRound,
                        color: isInfluencer
                            ? BStoreColors.primary
                            : BStoreColors.textPrimary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Store role',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: BStoreColors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: BStoreColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Switch between Member and Influencer.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: BStoreColors.textSecondary,
                              fontSize: 12.5,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      LucideIcons.chevronRight,
                      color: BStoreColors.primary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StoreNotificationBell extends StatelessWidget {
  const _StoreNotificationBell();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(LucideIcons.bell, color: BStoreColors.textPrimary, size: 23),
        Positioned(
          right: -2,
          top: -4,
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: BStoreColors.accentPurple,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelfStoreHubCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Future<int> countFuture;
  final String countSuffix;
  final VoidCallback onTap;

  const _SelfStoreHubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.countFuture,
    required this.countSuffix,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            decoration: storeSoftCardDecoration(radius: 12),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F5F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: BStoreColors.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: BStoreColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<int>(
                            future: countFuture,
                            builder: (context, snapshot) {
                              final text = snapshot.hasData
                                  ? '${snapshot.data} $countSuffix'
                                  : '…';
                              return Text(
                                text,
                                style: const TextStyle(
                                  color: BStoreColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BStoreColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  LucideIcons.chevronRight,
                  color: BStoreColors.primary,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live counters for the My Store hub cards (replaces hardcoded counts).
class _HubCounts {
  const _HubCounts._();

  static Future<int> products() async {
    try {
      final items = await Phase2StoreApi().myProducts();
      return items.where((p) {
        final status = p['status']?.toString().toLowerCase() ?? 'active';
        final stock = p['stock_quantity'];
        final qty = stock is num ? stock.toInt() : int.tryParse('$stock') ?? 1;
        return status != 'draft' && qty > 0;
      }).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> services() async {
    try {
      final items = await Phase2StoreApi().myServices();
      return items.where((s) => s['visible_to_customers'] != false).length;
    } catch (_) {
      return 0;
    }
  }
}

class _VisitorProductSection extends StatelessWidget {
  const _VisitorProductSection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        StoreSectionTitle(
          title: 'Product',
          subtitle: 'Products available from this store.',
        ),
        StoreListingPreviewList(),
      ],
    );
  }
}

class _VisitorServiceSection extends StatelessWidget {
  const _VisitorServiceSection();

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: const [
        StoreSectionTitle(
          title: 'Service',
          subtitle: 'Services available from this store.',
        ),
        StoreEmptyState(
          icon: LucideIcons.briefcaseBusiness,
          title: 'Open Store tab',
          body: 'Use the Services filter on the store home page to browse.',
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
        StoreSectionTitle(
          title: 'Cart',
          subtitle: 'Items selected from this store.',
        ),
        StoreEmptyState(
          icon: LucideIcons.shoppingCart,
          title: 'Your cart is empty',
          body: 'Add products or services from the store to prepare checkout.',
        ),
      ],
    );
  }
}

class _ProfileSection extends StatefulWidget {
  final bool isSelfStore;

  const _ProfileSection({required this.isSelfStore});

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  late final Future<_StoreProfileUser> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<_StoreProfileUser> _loadProfile() async {
    final user = await AuthService().fetchCurrentUser();
    final name = (user?.fullName?.trim().isNotEmpty == true)
        ? user!.fullName!.trim()
        : (user?.username.trim().isNotEmpty == true ? user!.username : 'You');
    final email = user?.email?.trim();

    return _StoreProfileUser(
      name: name,
      email: email?.isNotEmpty == true ? email! : 'No email added',
      avatarUrl: UrlHelper.absoluteUrl(user?.avatarUrl ?? ''),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSelfStore) {
      return SliverList.list(
        children: const [
          StoreSectionTitle(
            title: 'Profile',
            subtitle: 'Seller details and ways to connect.',
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: StoreActionPanel(
              icon: LucideIcons.badgeCheck,
              title: 'Verified seller profile',
              body:
                  'Store information, policies, and contact options will appear here.',
              actionLabel: 'View details',
            ),
          ),
        ],
      );
    }

    return SliverList.list(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: FutureBuilder<_StoreProfileUser>(
            future: _profileFuture,
            builder: (context, snapshot) {
              return _SelfStoreProfileCard(
                user: snapshot.data ?? _StoreProfileUser.loading(),
                isLoading: snapshot.connectionState != ConnectionState.done,
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _StoreProfileMenu(
            items: [
              _StoreProfileMenuItem(
                icon: LucideIcons.repeat,
                title: 'Store role',
                subtitle: 'Switch Member / Influencer',
                onTap: () => showStoreRoleSwitchSheet(context),
              ),
              _StoreProfileMenuItem(
                icon: LucideIcons.usersRound,
                title: 'Network',
                subtitle: 'People, requests, and connections',
                onTap: () =>
                    Navigator.of(context).pushNamed('/follow-requests'),
              ),
              _StoreProfileMenuItem(
                icon: LucideIcons.mapPinHouse,
                title: 'Saved Address',
                subtitle: 'Delivery and billing locations',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StoreSavedAddressPage(),
                    ),
                  );
                },
              ),
              _StoreProfileMenuItem(
                icon: LucideIcons.coins,
                title: 'Add bCoins',
                subtitle: 'Use wallet rewards at checkout',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StoreBCoinsPage(),
                    ),
                  );
                },
              ),
              _StoreProfileMenuItem(
                icon: LucideIcons.truck,
                title: 'Tracking Order',
                subtitle: 'Live delivery updates and order status',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StoreOrderTrackingListPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreProfileUser {
  final String name;
  final String email;
  final String avatarUrl;

  const _StoreProfileUser({
    required this.name,
    required this.email,
    required this.avatarUrl,
  });

  factory _StoreProfileUser.loading() {
    return const _StoreProfileUser(
      name: 'Loading profile...',
      email: 'Please wait',
      avatarUrl: '',
    );
  }
}

class _SelfStoreProfileCard extends StatelessWidget {
  final _StoreProfileUser user;
  final bool isLoading;

  const _SelfStoreProfileCard({
    required this.user,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final initial = user.name.trim().isEmpty
        ? 'B'
        : user.name.trim().characters.first.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BStoreDecorations.card(radius: BStoreRadii.cardLarge),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: BStoreColors.primarySoft,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: user.avatarUrl.trim().isNotEmpty
                ? SafeNetworkImage(
                    url: user.avatarUrl,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    debugLabel: 'store-profile-avatar',
                  )
                : Center(
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            initial,
                            style: const TextStyle(
                              color: BStoreColors.primary,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
          ),
          const SizedBox(height: 14),
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            user.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BStoreColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (route) => false,
                );
              },
              icon: const Icon(LucideIcons.house, size: 18),
              label: const Text('Go to bSmart'),
              style: BStoreButtons.filled(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreProfileMenu extends StatelessWidget {
  final List<_StoreProfileMenuItem> items;

  const _StoreProfileMenu({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BStoreDecorations.card(radius: BStoreRadii.cardLarge),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _StoreProfileMenuTile(item: items[i]),
            if (i != items.length - 1)
              const Divider(
                height: 1,
                indent: 64,
                color: BStoreColors.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _StoreProfileMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _StoreProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _StoreProfileMenuTile extends StatelessWidget {
  final _StoreProfileMenuItem item;

  const _StoreProfileMenuTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: BStoreColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: BStoreColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textMuted,
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
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Padding(
      padding: EdgeInsets.only(bottom: isIOS ? 4 : 0),
      child: SafeArea(
        top: false,
        bottom: !isIOS,
        child: SizedBox(
          height: 42,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned.fill(
                child: CustomPaint(
                  painter: _StoreFooterShapePainter(
                    backgroundColor: BStoreColors.surface,
                    borderColor: BStoreColors.borderSoft,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < items.length; i++)
                    _StoreFooterIconButton(
                      item: items[i],
                      selected: i == selectedIndex,
                      onTap: () => onSelected(i),
                      isCenterAdd:
                          i == 2 && items[i].section == _StoreNavSection.add,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreFooterIconButton extends StatefulWidget {
  final _StoreNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool isCenterAdd;

  const _StoreFooterIconButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.isCenterAdd = false,
  });

  @override
  State<_StoreFooterIconButton> createState() => _StoreFooterIconButtonState();
}

class _StoreFooterIconButtonState extends State<_StoreFooterIconButton> {
  bool _rotating = false;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.selected ? BStoreColors.primary : BStoreColors.textSecondary;

    if (widget.isCenterAdd) {
      return Transform.translate(
        offset: const Offset(0, -8),
        child: GestureDetector(
          onTap: () {
            setState(() => _rotating = true);
            widget.onTap();
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _rotating = false);
            });
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: BStoreColors.primary,
              boxShadow: [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: AnimatedRotation(
                turns: _rotating ? 1 / 8 : 0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(
                  LucideIcons.plus,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final child = InkWell(
      onTap: widget.selected ? null : widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Icon(widget.item.icon, color: color, size: 30),
          ),
        ),
      ),
    );

    return child;
  }
}

class _StoreFooterShapePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;

  const _StoreFooterShapePainter({
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = _buildPath(size);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  Path _buildPath(Size size) {
    const notchWidth = 86.0;
    const notchDepth = 36.0;
    const shoulderWidth = 20.0;
    final centerX = size.width / 2;
    final notchLeft = centerX - notchWidth / 2;
    final notchRight = centerX + notchWidth / 2;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(notchLeft - shoulderWidth, 0)
      ..cubicTo(
        notchLeft + 2,
        0,
        centerX - 28,
        notchDepth,
        centerX,
        notchDepth,
      )
      ..cubicTo(
        centerX + 28,
        notchDepth,
        notchRight - 2,
        0,
        notchRight + shoulderWidth,
        0,
      )
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _StoreFooterShapePainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}
