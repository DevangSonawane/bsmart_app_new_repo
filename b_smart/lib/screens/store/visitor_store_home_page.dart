import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../services/page_cache_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/current_user.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/store_money.dart';
import 'shared/store_shared_widgets.dart';
import 'store_models.dart';
import 'store_profile_page.dart';
import 'store_profile_state.dart';
import 'store_theme.dart';
import 'store_wishlist.dart';
import 'visitor_product_detail_page.dart';
import 'visitor_service_detail_page.dart';

class VisitorStorefrontScreen extends StatelessWidget {
  final String ownerUserId;

  const VisitorStorefrontScreen({
    super.key,
    required this.ownerUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.backgroundAlt,
        body: SafeArea(
          top: false,
          child: RefreshIndicator.adaptive(
            color: BStoreColors.primary,
            onRefresh: () => Future.wait([
              StoreMockState.instance.refreshMarketplace(),
              StoreProfileState.instance.load(ownerUserId, force: true),
            ]),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                VisitorStoreHomePage(
                  ownerUserId: ownerUserId,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VisitorStoreHomePage extends StatefulWidget {
  final String? ownerUserId;

  const VisitorStoreHomePage({
    super.key,
    this.ownerUserId,
  });

  @override
  State<VisitorStoreHomePage> createState() => _VisitorStoreHomePageState();
}

enum _VisitorStoreFilter { all, services, products }

class _VisitorStoreHomePageState extends State<VisitorStoreHomePage> {
  _VisitorStoreFilter _selectedFilter = _VisitorStoreFilter.all;
  late Future<_VisitorStoreOwner?> _ownerFuture;
  final PageCacheService _pageCache = PageCacheService();

  @override
  void initState() {
    super.initState();
    _ownerFuture = _loadOwner();
    StoreMockState.instance.addListener(_handleStoreChanged);
    StoreProfileState.instance.addListener(_handleStoreChanged);
    unawaited(StoreMockState.instance.ensureMarketplace());
    unawaited(StoreMockState.instance.ensureCart());
    unawaited(StoreProfileState.instance.ensureLoaded(widget.ownerUserId));
  }

  @override
  void dispose() {
    StoreMockState.instance.removeListener(_handleStoreChanged);
    StoreProfileState.instance.removeListener(_handleStoreChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VisitorStoreHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerUserId != widget.ownerUserId) {
      _ownerFuture = _loadOwner();
      unawaited(StoreProfileState.instance.ensureLoaded(widget.ownerUserId));
    }
  }

  void _handleStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<_VisitorStoreOwner?> _loadOwner({bool forceNetwork = false}) async {
    final ownerId = widget.ownerUserId?.trim();
    if (ownerId == null || ownerId.isEmpty) return null;

    final currentUserId = await CurrentUser.id;
    final cacheParams = <String, dynamic>{'ownerId': ownerId};
    final cached = forceNetwork
        ? null
        : await _pageCache.get('vendor_public', ownerId, cacheParams);

    if (cached != null && !forceNetwork) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final user = _map(decoded['user'] ?? decoded);
        final displayName = _firstString(user, const [
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
        return _VisitorStoreOwner(
          displayName: displayName ?? 'Store owner',
          avatarUrl: avatarUrl,
          avatarHeaders: null,
        );
      } on Exception catch (_) {
        _pageCache.invalidate('vendor_public', ownerId);
      }
    }

    final user = await SupabaseService().getUserById(ownerId);
    if (user == null) return null;

    final displayName = _firstString(user, const [
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

    final owner = _VisitorStoreOwner(
      displayName: displayName ?? 'Store owner',
      avatarUrl: avatarUrl,
      avatarHeaders: avatarHeaders,
    );

    try {
      await _pageCache.set(
        'vendor_public',
        ownerId,
        cacheParams,
        jsonEncode(<String, dynamic>{
          'user': user,
        }),
      );
    } on Exception catch (_) {}

    return owner;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
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
    final store = StoreMockState.instance;
    return SliverList.list(
      children: [
        const _VisitorStoreTopBar(),
        FutureBuilder<_VisitorStoreOwner?>(
          future: _ownerFuture,
          builder: (context, snapshot) {
            return _SellerHeroCard(
              owner: snapshot.data,
              isLoading: snapshot.connectionState != ConnectionState.done,
              ownerUserId: widget.ownerUserId,
            );
          },
        ),
        _StoreFilterTabs(
          selectedFilter: _selectedFilter,
          onSelected: (filter) => setState(() => _selectedFilter = filter),
        ),
        if (store.catalogLoading && StoreMockState.catalog.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 28, 10, 0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (StoreMockState.catalog.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 18, 10, 0),
            child: store.lastError == null
                ? const StoreEmptyState(
                    icon: LucideIcons.store,
                    title: 'No listings yet',
                    body:
                        'Products and services published by influencers will appear here.',
                  )
                : Column(
                    children: [
                      StoreEmptyState(
                        icon: LucideIcons.cloudOff,
                        title: "Couldn't load marketplace",
                        body: '${store.lastError}',
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            StoreMockState.instance.refreshMarketplace(),
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: _StoreItemsContent(
              filter: _selectedFilter,
              ownerUserId: widget.ownerUserId,
              query: '',
            ),
          ),
      ],
    );
  }
}

class _VisitorStoreOwner {
  final String displayName;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;

  const _VisitorStoreOwner({
    required this.displayName,
    required this.avatarUrl,
    required this.avatarHeaders,
  });
}

class _StoreSearchNavIcon extends StatelessWidget {
  const _StoreSearchNavIcon();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/store/search'),
      behavior: HitTestBehavior.opaque,
      child: const Icon(LucideIcons.search, color: Color(0xFF060D35), size: 23),
    );
  }
}

class _NotifiedBell extends StatelessWidget {
  const _NotifiedBell();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(LucideIcons.bell, color: Color(0xFF060D35), size: 23),
        Positioned(
          right: -2,
          top: -4,
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFF684AC8),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _VisitorStoreTopBar extends StatelessWidget {
  const _VisitorStoreTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top + 10,
        16,
        0,
      ),
      child: const SizedBox(
        height: 32,
        child: Row(
          children: [
            Expanded(child: StoreBsmartWordmark()),
            _StoreSearchNavIcon(),
            SizedBox(width: 18),
            _NotifiedBell(),
          ],
        ),
      ),
    );
  }
}

class _SellerHeroCard extends StatelessWidget {
  final _VisitorStoreOwner? owner;
  final bool isLoading;
  final String? ownerUserId;

  const _SellerHeroCard({
    required this.owner,
    required this.isLoading,
    this.ownerUserId,
  });

  @override
  Widget build(BuildContext context) {
    final profile = StoreProfileState.instance.profileFor(ownerUserId);
    final fallbackName = owner?.displayName.trim().isNotEmpty == true
        ? owner!.displayName.trim()
        : (isLoading ? 'Loading store...' : 'Store owner');
    // Prefer the seller's storefront name, then the account display name.
    final name = (profile?.storeName.trim().isNotEmpty == true
        ? profile!.storeName.trim()
        : fallbackName);
    final storeType = profile?.storeType.trim().isNotEmpty == true
        ? profile!.storeType.trim()
        : 'Personal Store';
    final badges = profile?.trustBadges ?? const <String>[];
    final badgeLine = badges.isEmpty
        ? 'Professional • Trusted • Reliable'
        : badges.join(' • ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
      child: InkWell(
        onTap: ownerUserId == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StoreProfilePage(ownerUserId: ownerUserId),
                  ),
                ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: storeSoftCardDecoration(radius: 16),
          child: Row(
            children: [
              _VerifiedAvatar(
                initials: _initialsFor(name),
                avatarUrl: owner?.avatarUrl ?? '',
                avatarHeaders: owner?.avatarHeaders,
                size: 78,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      storeType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF684AC8),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(LucideIcons.package,
                            color: Color(0xFF078D92), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          profile == null ? '—' : '${profile.productCount}',
                          style: const TextStyle(
                            color: Color(0xFF060D35),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Icon(LucideIcons.briefcaseBusiness,
                            color: Color(0xFF078D92), size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            profile == null
                                ? '—'
                                : '${profile.serviceCount} services',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF060D35),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badgeLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF29304D),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: ownerUserId == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                StoreProfilePage(ownerUserId: ownerUserId),
                          ),
                        ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF060D35),
                  side: const BorderSide(color: Color(0xFFE1E5EA)),
                  fixedSize: const Size(56, 56),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.store, size: 21),
                    SizedBox(height: 4),
                    Text(
                      'Store',
                      style:
                          TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'S';
    final first = parts.first.characters.first.toUpperCase();
    if (parts.length == 1) return first;
    return '$first${parts.last.characters.first.toUpperCase()}';
  }
}

class _VerifiedAvatar extends StatelessWidget {
  final String initials;
  final String avatarUrl;
  final Map<String, String>? avatarHeaders;
  final double size;

  const _VerifiedAvatar({
    required this.initials,
    required this.avatarUrl,
    required this.avatarHeaders,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Color(0xFFEAD8CC),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: avatarUrl.trim().isEmpty
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : SafeNetworkImage(
                    url: avatarUrl,
                    headers: avatarHeaders,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    debugLabel: 'visitor-store-owner-avatar',
                    errorWidget: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: 3,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF078D92),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.check, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }
}

class _StoreFilterTabs extends StatelessWidget {
  final _VisitorStoreFilter selectedFilter;
  final ValueChanged<_VisitorStoreFilter> onSelected;

  const _StoreFilterTabs({
    required this.selectedFilter,
    required this.onSelected,
  });

  static const _tabs = [
    (_VisitorStoreFilter.all, LucideIcons.layoutGrid, 'All'),
    (_VisitorStoreFilter.services, LucideIcons.briefcaseBusiness, 'Services'),
    (_VisitorStoreFilter.products, LucideIcons.box, 'Products'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Container(
        height: 46,
        decoration: storeSoftCardDecoration(radius: 18),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++) ...[
              Expanded(
                child: _StoreFilterTab(
                  icon: _tabs[i].$2,
                  label: _tabs[i].$3,
                  selected: selectedFilter == _tabs[i].$1,
                  onTap: () => onSelected(_tabs[i].$1),
                ),
              ),
              if (i != _tabs.length - 1)
                Container(width: 1, height: 22, color: const Color(0xFFE2E5EA)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoreFilterTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StoreFilterTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF078D92) : const Color(0xFF060D35);
    return InkWell(
      onTap: selected ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 2,
            width: selected ? 32 : 0,
            decoration: BoxDecoration(
              color: const Color(0xFF078D92),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreItemsContent extends StatelessWidget {
  final _VisitorStoreFilter filter;
  final String? ownerUserId;
  final String query;

  const _StoreItemsContent({
    required this.filter,
    required this.ownerUserId,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final store = StoreMockState.instance;
    final products = _matchingItems(_ownedItems(store.products));
    final services = _matchingItems(_ownedItems(store.services));
    final catalog = <StoreMockCatalogItem>[...products, ...services];
    final emptyBody = query.trim().isEmpty
        ? 'This store has not published products or services yet.'
        : 'No listings match "${query.trim()}".';
    return switch (filter) {
      _VisitorStoreFilter.services =>
        _VisitorServiceList(ownerUserId: ownerUserId, services: services),
      _VisitorStoreFilter.products =>
        _VisitorProductList(ownerUserId: ownerUserId, products: products),
      _VisitorStoreFilter.all => catalog.isEmpty
          ? StoreEmptyState(
              icon: LucideIcons.store,
              title: query.trim().isEmpty ? 'No listings yet' : 'No matches',
              body: emptyBody,
            )
          : _StoreItemsGrid(
              children: [
                if (services.isNotEmpty)
                  _ServiceFeatureCard(
                    ownerUserId: ownerUserId,
                    service: services.first,
                  ),
                for (final item in catalog
                    .where((item) =>
                        services.isEmpty || item.id != services.first.id)
                    .take(7))
                  item.type == StoreMockItemType.service
                      ? _ServiceFeatureCard(
                          ownerUserId: ownerUserId,
                          service: item,
                        )
                      : _ProductCard(item: item, ownerUserId: ownerUserId),
              ],
            ),
    };
  }

  List<StoreMockCatalogItem> _ownedItems(List<StoreMockCatalogItem> items) {
    final ownerId = ownerUserId?.trim();
    if (ownerId == null || ownerId.isEmpty) return items;
    return items.where((item) => _belongsToOwner(item.raw, ownerId)).toList();
  }

  List<StoreMockCatalogItem> _matchingItems(List<StoreMockCatalogItem> items) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((item) {
      return item.title.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q) ||
          item.priceLabel.toLowerCase().contains(q);
    }).toList();
  }

  static bool _belongsToOwner(Map<String, dynamic> item, String ownerId) {
    final expected = _normaliseId(ownerId);
    if (expected.isEmpty) return false;

    for (final key in const [
      'influencer_id',
      'influencerId',
      'user_id',
      'userId',
      'owner_id',
      'ownerId',
      'seller_id',
      'sellerId',
      'created_by',
      'createdBy',
      'created_by_id',
      'createdById',
      'provider_id',
      'providerId',
      'vendor_id',
      'vendorId',
    ]) {
      if (_valueMatchesOwner(item[key], expected)) return true;
    }

    for (final key in const [
      'influencer',
      'owner',
      'seller',
      'user',
      'created_by',
      'createdBy',
      'creator',
      'provider',
      'vendor',
    ]) {
      if (_valueMatchesOwner(item[key], expected)) return true;
    }
    return false;
  }

  static bool _valueMatchesOwner(dynamic value, String expected) {
    if (value is Map) {
      final map = value.map((k, v) => MapEntry(k.toString(), v));
      for (final key in const [
        'id',
        '_id',
        'user_id',
        'userId',
        'owner_id',
        'ownerId',
        'seller_id',
        'sellerId',
      ]) {
        if (_normaliseId(map[key]?.toString()) == expected) return true;
      }
      return false;
    }
    return _normaliseId(value?.toString()) == expected;
  }

  static String _normaliseId(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || text == 'null') return '';
    return text.toLowerCase();
  }
}

class _StoreItemsGrid extends StatelessWidget {
  final List<Widget> children;

  const _StoreItemsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 20;
        final columnWidth = ((width - gap) / 2).clamp(120.0, 260.0);
        return GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: gap,
          mainAxisSpacing: 12,
          childAspectRatio: columnWidth / 260,
          children: children,
        );
      },
    );
  }
}

class _CatalogImage extends StatelessWidget {
  final StoreMockCatalogItem item;
  final double height;

  const _CatalogImage({
    required this.item,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return StoreItemImage(
      imageUrl: item.imageUrl,
      icon: item.icon,
      width: double.infinity,
      height: height,
      debugLabel: 'visitor-store-catalog',
    );
  }
}

class _VisitorServiceList extends StatelessWidget {
  final String? ownerUserId;
  final List<StoreMockCatalogItem> services;

  const _VisitorServiceList({
    required this.ownerUserId,
    required this.services,
  });

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const StoreEmptyState(
        icon: LucideIcons.briefcaseBusiness,
        title: 'No services yet',
        body: 'Services published by influencers will appear here.',
      );
    }
    return _StoreItemsGrid(
      children: [
        for (final service in services)
          _ServiceFeatureCard(ownerUserId: ownerUserId, service: service),
      ],
    );
  }
}

class _ServiceFeatureCard extends StatelessWidget {
  final String? ownerUserId;
  final StoreMockCatalogItem service;

  const _ServiceFeatureCard({
    required this.ownerUserId,
    required this.service,
  });

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitorServiceDetailPage(
          ownerUserId: ownerUserId,
          item: service,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.expand(
        child: Container(
          decoration: storeSoftCardDecoration(radius: 14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _CatalogImage(item: service, height: 104),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF060D35),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          formatCompactStoreMoney(service.price),
                          style: const TextStyle(
                            color: Color(0xFF078D92),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            service.duration,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF29304D),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.star,
                          color: Color(0xFF078D92),
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          service.rating,
                          style: const TextStyle(
                            color: Color(0xFF060D35),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '(${service.reviews})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF29304D),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => VisitorServiceDetailPage(
                              ownerUserId: ownerUserId,
                              item: service,
                            ),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF078D92),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(LucideIcons.chevronRight, size: 17),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final StoreMockCatalogItem item;
  final String? ownerUserId;

  const _ProductCard({
    required this.item,
    this.ownerUserId,
  });

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitorProductDetailPage(
          ownerUserId: ownerUserId,
          product: VisitorProductDetailData(
            item: item,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.expand(
        child: Container(
          decoration: storeSoftCardDecoration(radius: 14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _CatalogImage(item: item, height: 104),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistHeartButton(productId: item.id),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            formatCompactStoreMoney(item.price),
                            style: const TextStyle(
                              color: Color(0xFF078D92),
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'From',
                            style: TextStyle(
                              color: Color(0xFF29304D),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.star,
                            color: Color(0xFF078D92),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.rating,
                            style: const TextStyle(
                              color: Color(0xFF060D35),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '(${item.reviews})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF29304D),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        width: double.infinity,
                        child: _InlineCartStepper(item: item),
                      ),
                    ],
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

class _VisitorProductList extends StatelessWidget {
  final String? ownerUserId;
  final List<StoreMockCatalogItem> products;

  const _VisitorProductList({
    required this.ownerUserId,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const StoreEmptyState(
        icon: LucideIcons.package,
        title: 'No products yet',
        body: 'Products published by influencers will appear here.',
      );
    }
    return Stack(
      children: [
        _VisitorProductGrid(
          children: [
            for (final product in products)
              _VisitorProductGridCard(
                item: product,
                ownerUserId: ownerUserId,
              ),
          ],
        ),
      ],
    );
  }
}

class _VisitorProductGrid extends StatelessWidget {
  final List<Widget> children;

  const _VisitorProductGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 20;
        final columnWidth = ((width - gap) / 2).clamp(120.0, 260.0);
        return GridView.count(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: gap,
          mainAxisSpacing: 12,
          childAspectRatio: columnWidth / 260,
          children: children,
        );
      },
    );
  }
}

class _VisitorProductGridCard extends StatelessWidget {
  final StoreMockCatalogItem item;
  final String? ownerUserId;

  const _VisitorProductGridCard({
    required this.item,
    this.ownerUserId,
  });

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitorProductDetailPage(
          ownerUserId: ownerUserId,
          product: VisitorProductDetailData(
            item: item,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.expand(
        child: Container(
          decoration: storeSoftCardDecoration(radius: 14),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _CatalogImage(item: item, height: 104),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistHeartButton(productId: item.id),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 14.5,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatCompactStoreMoney(item.price),
                        style: const TextStyle(
                          color: Color(0xFF078D92),
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.star,
                            color: Color(0xFF078D92),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item.rating,
                            style: const TextStyle(
                              color: Color(0xFF060D35),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              '(${item.reviews})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF29304D),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 32,
                        width: double.infinity,
                        child: _InlineCartStepper(item: item),
                      ),
                    ],
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

class _InlineCartStepper extends StatelessWidget {
  final StoreMockCatalogItem item;

  const _InlineCartStepper({required this.item});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StoreMockState.instance,
      builder: (context, _) {
        final quantity = StoreMockState.instance.quantityFor(item.id);
        final maxQuantity = StoreMockState.instance.maxQuantityFor(item);
        if (quantity == 0) {
          return OutlinedButton(
            onPressed: maxQuantity <= 0
                ? null
                : () => StoreMockState.instance.addToCart(item),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF078D92),
              side: const BorderSide(color: Color(0xFFD5DEE4)),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shoppingCart, size: 15),
                  SizedBox(width: 8),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF078D92),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Expanded(
                child: _StepperTapTarget(
                  icon: LucideIcons.minus,
                  onTap: () => StoreMockState.instance.updateQuantity(
                    item.id,
                    quantity - 1,
                  ),
                ),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: _StepperTapTarget(
                  icon: LucideIcons.plus,
                  enabled: quantity < maxQuantity,
                  onTap: quantity >= maxQuantity
                      ? null
                      : () => StoreMockState.instance.updateQuantity(
                            item.id,
                            quantity + 1,
                          ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepperTapTarget extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _StepperTapTarget({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(7),
      child: Center(
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white54,
          size: 16,
        ),
      ),
    );
  }
}
