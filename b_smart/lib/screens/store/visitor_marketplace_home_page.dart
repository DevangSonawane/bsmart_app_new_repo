import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../services/page_cache_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/current_user.dart';
import '../../utils/url_helper.dart';
import '../../widgets/safe_network_image.dart';
import 'shared/marketplace_figma_home.dart';
import 'shared/marketplace_listing_card.dart';
import 'shared/marketplace_people_section.dart';
import 'shared/marketplace_swiggy_header.dart';
import 'shared/store_shared_widgets.dart';
import 'store_address_book.dart';
import 'store_bcoins_page.dart';
import 'store_models.dart';
import 'store_profile_page.dart';
import 'store_profile_state.dart';
import 'store_saved_address_page.dart';
import 'store_wishlist.dart';

class VisitorMarketplaceHomePage extends StatefulWidget {
  final String? ownerUserId;
  final bool showTopBar;
  final bool showSellerHero;

  const VisitorMarketplaceHomePage({
    super.key,
    this.ownerUserId,
    this.showTopBar = true,
    this.showSellerHero = true,
  });

  @override
  State<VisitorMarketplaceHomePage> createState() =>
      _VisitorMarketplaceHomePageState();
}

enum _VisitorStoreFilter { all, services, products }

class _VisitorMarketplaceHomePageState
    extends State<VisitorMarketplaceHomePage> {
  _VisitorStoreFilter _selectedFilter = _VisitorStoreFilter.all;
  late Future<_VisitorStoreOwner?> _ownerFuture;
  String _searchQuery = '';
  String? _selectedCategory;
  String? _sellerName;
  String? _currentUserName;
  final PageCacheService _pageCache = PageCacheService();

  // Figma marketplace home state (used when no specific store is open).
  final TextEditingController _searchController = TextEditingController();
  MkHomeTab _homeTab = MkHomeTab.all;
  int _categoryIndex = 0;
  int _summerAudience = 0;
  MkListingTab _listingTab = MkListingTab.newlyArrived;
  MkCreatorFilter _creatorFilter = MkCreatorFilter.all;
  MkCreatorCategory? _creatorCategory;

  bool get _isMarketplace => (widget.ownerUserId?.trim() ?? '').isEmpty;

  @override
  void initState() {
    super.initState();
    _ownerFuture = _loadOwner();
    _trackHeaderNames();
    StoreMockState.instance.addListener(_handleStoreChanged);
    StoreProfileState.instance.addListener(_handleStoreChanged);
    StoreAddressBook.instance.addListener(_handleStoreChanged);
    mkRecentlyViewed.addListener(_handleStoreChanged);
    unawaited(StoreMockState.instance.ensureMarketplace());
    unawaited(StoreMockState.instance.ensureCart());
    unawaited(StoreProfileState.instance.ensureLoaded(widget.ownerUserId));
    unawaited(StoreAddressBook.instance.ensureLoaded());
    if (_isMarketplace) {
      MkFollowing.ids.addListener(_handleStoreChanged);
      unawaited(MkFollowing.load());
    }
  }

  @override
  void dispose() {
    StoreMockState.instance.removeListener(_handleStoreChanged);
    StoreProfileState.instance.removeListener(_handleStoreChanged);
    StoreAddressBook.instance.removeListener(_handleStoreChanged);
    mkRecentlyViewed.removeListener(_handleStoreChanged);
    MkFollowing.ids.removeListener(_handleStoreChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VisitorMarketplaceHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerUserId != widget.ownerUserId) {
      _ownerFuture = _loadOwner();
      _trackHeaderNames();
      unawaited(StoreProfileState.instance.ensureLoaded(widget.ownerUserId));
    }
  }

  void _handleStoreChanged() {
    if (!mounted) return;
    // Shared stores (address book, catalog) can notify while another page is
    // mid-build, e.g. a storefront pushed on top calling ensureLoaded() in
    // initState. Rebuilding then throws, so wait for the frame to finish.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  void _trackHeaderNames() {
    _ownerFuture.then((owner) {
      if (!mounted) return;
      final name = owner?.displayName.trim() ?? '';
      if (name.isNotEmpty && name != _sellerName) {
        setState(() => _sellerName = name);
      }
    });
    final ownerId = widget.ownerUserId?.trim() ?? '';
    if (ownerId.isEmpty) {
      _loadCurrentUserName();
    } else if (_currentUserName != null) {
      setState(() => _currentUserName = null);
    }
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final id = await CurrentUser.id;
      if (id == null || id.isEmpty || !mounted) return;
      if ((widget.ownerUserId?.trim() ?? '').isNotEmpty) return;
      final user = await SupabaseService().getUserById(id);
      if (user == null || !mounted) return;
      final name = _firstString(user, const [
        'full_name',
        'fullName',
        'displayName',
        'name',
        'username',
      ]);
      if (name != null && name.isNotEmpty && name != _currentUserName) {
        setState(() => _currentUserName = name);
      }
    } on Exception catch (_) {}
  }

  List<String> _headerCategories() {
    final store = StoreMockState.instance;
    Iterable<StoreMockCatalogItem> items = switch (_selectedFilter) {
      _VisitorStoreFilter.all => [...store.products, ...store.services],
      _VisitorStoreFilter.products => store.products,
      _VisitorStoreFilter.services => store.services,
    };
    final ownerId = widget.ownerUserId?.trim() ?? '';
    if (ownerId.isNotEmpty) {
      items = items.where(
          (item) => _StoreItemsContent._belongsToOwner(item.raw, ownerId));
    }
    final out = <String>[];
    for (final item in items) {
      final category = item.category.trim();
      if (category.isNotEmpty && !out.contains(category)) out.add(category);
    }
    return out;
  }

  Future<_VisitorStoreOwner?> _loadOwner({bool forceNetwork = false}) async {
    final ownerId = widget.ownerUserId?.trim();
    if (ownerId == null || ownerId.isEmpty) return null;

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

  List<MkListingTab> get _listingTabs => _homeTab == MkHomeTab.people
      ? const [
          MkListingTab.newlyArrived,
          MkListingTab.nearbyServices,
          MkListingTab.under499,
        ]
      : const [
          MkListingTab.newlyArrived,
          MkListingTab.under499,
          MkListingTab.recentlyBrowsed,
        ];

  void _selectHomeTab(MkHomeTab tab) {
    setState(() {
      _homeTab = tab;
      if (!_listingTabs.contains(_listingTab)) {
        _listingTab = MkListingTab.newlyArrived;
      }
      _selectedFilter = switch (tab) {
        MkHomeTab.products => _VisitorStoreFilter.products,
        MkHomeTab.services => _VisitorStoreFilter.services,
        MkHomeTab.all || MkHomeTab.people => _VisitorStoreFilter.all,
      };
      _selectedCategory = null;
    });
  }

  void _selectTopCategory(int index, List<String> catalogCategories) {
    final label = mkCategories[index].label.toLowerCase();
    String? match;
    for (final c in catalogCategories) {
      final lower = c.toLowerCase();
      if (lower == label || lower.contains(label) || label.contains(lower)) {
        match = c;
        break;
      }
    }
    setState(() {
      _categoryIndex = index;
      _selectedCategory = match;
    });
  }

  List<StoreMockCatalogItem> _figmaListing() {
    final store = StoreMockState.instance;
    Iterable<StoreMockCatalogItem> items = switch (_selectedFilter) {
      _VisitorStoreFilter.all => [...store.products, ...store.services],
      _VisitorStoreFilter.products => store.products,
      _VisitorStoreFilter.services => store.services,
    };
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items.where((item) =>
          item.title.toLowerCase().contains(q) ||
          item.category.toLowerCase().contains(q) ||
          item.description.toLowerCase().contains(q));
    }
    final category = _selectedCategory?.trim().toLowerCase() ?? '';
    if (category.isNotEmpty) {
      items =
          items.where((item) => item.category.trim().toLowerCase() == category);
    }
    switch (_listingTab) {
      case MkListingTab.newlyArrived:
        final list = items.toList();
        DateTime created(StoreMockCatalogItem i) =>
            DateTime.tryParse(
                '${i.raw['created_at'] ?? i.raw['createdAt'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        list.sort((a, b) => created(b).compareTo(created(a)));
        return list;
      case MkListingTab.under499:
        return items.where((i) => i.price > 0 && i.price <= 499).toList();
      case MkListingTab.nearbyServices:
        // Listings carry no coordinates, so "nearby" means the service
        // mentions the city of the selected delivery address.
        final city =
            StoreAddressBook.instance.selected?.city.trim().toLowerCase() ?? '';
        if (city.isEmpty) return const [];
        return items
            .where((i) =>
                i.type == StoreMockItemType.service &&
                _mentionsCity(i.raw, city))
            .toList();
      case MkListingTab.recentlyBrowsed:
        final byId = {for (final i in items) i.id: i};
        return [
          for (final id in mkRecentlyViewed.value)
            if (byId[id] != null) byId[id]!,
        ];
    }
  }

  static bool _mentionsCity(Map<String, dynamic> raw, String city) {
    for (final key in const [
      'city',
      'location',
      'service_area',
      'serviceArea',
      'address',
      'service_location',
      'areas',
    ]) {
      final v = raw[key];
      if (v != null && v.toString().toLowerCase().contains(city)) return true;
    }
    return false;
  }

  List<Widget> _peopleSections(BuildContext context) {
    final store = StoreMockState.instance;
    final creators = mkCreatorsFromCatalog(store.products, store.services);
    final following = MkFollowing.ids.value;
    final favorites = following.isEmpty
        ? const <MkCreator>[]
        : creators.where((c) => following.contains(c.id)).toList();
    final favoritesShown = favorites.isNotEmpty ? favorites : creators;
    var popular = creators.where((c) => switch (_creatorFilter) {
          MkCreatorFilter.all => true,
          MkCreatorFilter.products => c.productCount > 0,
          MkCreatorFilter.services => c.serviceCount > 0,
        });
    final cat = _creatorCategory;
    if (cat != null) popular = popular.where(cat.matches);
    final popularList = popular.toList();

    void openList(String title, List<MkCreator> list) =>
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => MkCreatorListPage(title: title, creators: list),
        ));

    return [
      if (creators.isEmpty && store.catalogLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (creators.isNotEmpty) ...[
        MkFavoriteCreators(
          // Until the user follows a creator, suggest the most active ones.
          creators: favoritesShown.take(10).toList(),
          onSeeAll: () => openList(
              favorites.isNotEmpty ? 'Your Favorite Creators' : 'Creators',
              favoritesShown),
        ),
        const SizedBox(height: 33),
      ],
      MkCreatorsByCategory(
        selected: cat,
        onTap: (c) => setState(() =>
            _creatorCategory = _creatorCategory?.title == c.title ? null : c),
        onSeeAll: () => openList('All Creators', creators),
      ),
      const SizedBox(height: 32),
      MkPopularCreators(
        creators: popularList.take(3).toList(),
        filter: _creatorFilter,
        onFilter: (f) => setState(() => _creatorFilter = f),
        category: cat,
        onClearCategory: () => setState(() => _creatorCategory = null),
        onSeeAll: () => openList(
            cat == null ? 'Popular Creators' : '${cat.title} Creators',
            popularList),
      ),
      const SizedBox(height: 32),
      MkPostServicesBanner(
        onSeeBenefits: () => Navigator.of(context).pushNamed('/store/setup'),
      ),
      const SizedBox(height: 32),
    ];
  }

  Widget _buildFigmaHome(BuildContext context) {
    final store = StoreMockState.instance;
    final searching = _searchQuery.trim().isNotEmpty;
    final showPromos = _homeTab == MkHomeTab.all && !searching;
    final showPeople = _homeTab == MkHomeTab.people && !searching;
    final catalogCategories = _headerCategories();
    final listing = _figmaListing();
    final emptyBody = switch (_listingTab) {
      _ when searching => 'No listings match "${_searchQuery.trim()}".',
      MkListingTab.under499 => 'Nothing under ₹499 here yet.',
      MkListingTab.nearbyServices => StoreAddressBook.instance.selected == null
          ? 'Add a delivery address to see services near you.'
          : 'No services listed in ${StoreAddressBook.instance.selected!.city} yet.',
      MkListingTab.recentlyBrowsed => 'Listings you open will show up here.',
      MkListingTab.newlyArrived =>
        'Products and services published by creators will appear here.',
    };

    return SliverList.list(
      children: [
        MkGreetingHeader(
          userName: _currentUserName,
          location: StoreAddressBook.instance.selected?.summaryLine,
          topStatusPadding: !widget.showTopBar && !widget.showSellerHero,
          onLocationTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const StoreSavedAddressPage()),
          ),
          onBellTap: () => Navigator.of(context).pushNamed('/notifications'),
        ),
        MkFolderTabs(selected: _homeTab, onSelected: _selectHomeTab),
        MkHero(
          showBanner: showPromos || showPeople,
          theme: MkTabTheme.of(_homeTab),
          textOnly: _homeTab == MkHomeTab.people,
          onExplore: () => _selectHomeTab(MkHomeTab.products),
          search: MkSearchField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        if (showPromos) ...[
          MkExploreByCategory(
            selectedIndex: _categoryIndex,
            onSelected: (i) => _selectTopCategory(i, catalogCategories),
            onSubCategoryTap: (sub) =>
                openStoreSearch(context, query: sub.label),
          ),
          const SizedBox(height: 34),
          MkDealsAndOffers(
            onCreatorOffer: () => openStoreSearch(context),
            onBeauty: () => openStoreSearch(context, category: 'Beauty'),
            onElectronics: () =>
                openStoreSearch(context, category: 'Electronics'),
            onBCoins: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StoreBCoinsPage()),
            ),
          ),
          const SizedBox(height: 32),
          MkTrendySummer(
            audienceIndex: _summerAudience,
            onAudienceSelected: (i) => setState(() => _summerAudience = i),
            onItemTap: (item) => openStoreSearch(context, query: item.label),
            onExploreAll: () => openStoreSearch(context,
                query:
                    '${mkSummerAudiences[_summerAudience]} summer collection'),
          ),
          const SizedBox(height: 32),
          MkPopularServices(
            onTap: (svc) => openStoreSearch(context, query: svc.title),
          ),
          const SizedBox(height: 22),
          MkBrowseByLifestyle(
            onTap: (l) => openStoreSearch(context, query: l.label),
          ),
          const SizedBox(height: 18),
          MkMeetCreators(onExplore: () => openStoreSearch(context)),
          const SizedBox(height: 32),
        ] else if (showPeople) ...[
          const SizedBox(height: 32),
          ..._peopleSections(context),
        ] else
          const SizedBox(height: 16),
        ...[
          MkListingTabs(
            selected: _listingTab,
            tabs: _listingTabs,
            onSelected: (tab) => setState(() => _listingTab = tab),
          ),
          const SizedBox(height: 16),
          if (catalogCategories.isNotEmpty) ...[
            MkFilterChips(
              categories: catalogCategories,
              selected: _selectedCategory,
              onSelected: (c) => setState(() => _selectedCategory = c),
            ),
            const SizedBox(height: 16),
          ],
          if (store.catalogLoading && StoreMockState.catalog.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (StoreMockState.catalog.isEmpty && store.lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
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
          else if (listing.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: StoreEmptyState(
                icon: LucideIcons.store,
                title: searching ? 'No matches' : 'Nothing here yet',
                body: emptyBody,
              ),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(
                    '${_homeTab.name}|${_listingTab.name}|${_selectedCategory ?? ''}'),
                child: MkProductGrid(items: listing),
              ),
            ),
          const SizedBox(height: 32),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isMarketplace) return _buildFigmaHome(context);
    final store = StoreMockState.instance;
    final categories = _headerCategories();
    final selectedTab = switch (_selectedFilter) {
      _VisitorStoreFilter.all => MarketplaceTab.all,
      _VisitorStoreFilter.products => MarketplaceTab.products,
      _VisitorStoreFilter.services => MarketplaceTab.services,
    };
    final headerNeedsStatusPadding =
        !widget.showTopBar && !widget.showSellerHero;

    return SliverList.list(
      children: [
        if (widget.showTopBar) const _VisitorStoreTopBar(),
        if (widget.showSellerHero)
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
        // Swiggy-style: user name, folder tabs, search, filters,
        // image/hero, then the listings grid.
        Builder(
          builder: (context) {
            final ownerId = widget.ownerUserId?.trim() ?? '';
            String? headerName;
            String? headerSubtitle;
            if (ownerId.isNotEmpty) {
              final profile =
                  StoreProfileState.instance.profileFor(widget.ownerUserId);
              final storeName = profile?.storeName.trim() ?? '';
              headerName = storeName.isNotEmpty
                  ? storeName
                  : (_sellerName?.isNotEmpty == true ? _sellerName : 'Store');
              final storeType = profile?.storeType.trim() ?? '';
              headerSubtitle = storeType.isNotEmpty ? storeType : null;
            } else {
              headerName = _currentUserName;
              headerSubtitle = null;
            }
            return SwiggyMarketplaceHeader(
              userName: headerName,
              userSubtitle: headerSubtitle,
              onUserTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StoreProfilePage(
                    ownerUserId: widget.ownerUserId,
                  ),
                ),
              ),
              onWishlistTap: () => openWishlist(context),
              topStatusPadding: headerNeedsStatusPadding,
              selectedTab: selectedTab,
              onTabSelected: (tab) => setState(() {
                _selectedFilter = switch (tab) {
                  MarketplaceTab.all => _VisitorStoreFilter.all,
                  MarketplaceTab.products => _VisitorStoreFilter.products,
                  MarketplaceTab.services => _VisitorStoreFilter.services,
                };
                _selectedCategory = null;
              }),
              query: _searchQuery,
              onQueryChanged: (value) => setState(() => _searchQuery = value),
              onClearQuery: _searchQuery.isEmpty
                  ? null
                  : () => setState(() => _searchQuery = ''),
              categories: categories,
              selectedCategory: _selectedCategory,
              onCategorySelected: (category) =>
                  setState(() => _selectedCategory = category),
            );
          },
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
            // Fluid crossfade + slide when switching All/Products/Services.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(
                    '${_selectedFilter.name}|${_selectedCategory ?? ''}'),
                child: _StoreItemsContent(
                  filter: _selectedFilter,
                  ownerUserId: widget.ownerUserId,
                  query: _searchQuery,
                  category: _selectedCategory,
                ),
              ),
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

class _StoreItemsContent extends StatelessWidget {
  final _VisitorStoreFilter filter;
  final String? ownerUserId;
  final String query;
  final String? category;

  const _StoreItemsContent({
    required this.filter,
    required this.ownerUserId,
    required this.query,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final store = StoreMockState.instance;
    final products = _inCategory(_matchingItems(_ownedItems(store.products)));
    final services = _inCategory(_matchingItems(_ownedItems(store.services)));
    final catalog = <StoreMockCatalogItem>[...products, ...services];
    final emptyBody = query.trim().isEmpty
        ? 'This store has not published products or services yet.'
        : 'No listings match "${query.trim()}".';
    Widget gridFor(List<StoreMockCatalogItem> items) => _StoreItemsGrid(
          children: [
            for (final item in items)
              MarketplaceListingCard(item: item, ownerUserId: ownerUserId),
          ],
        );
    return switch (filter) {
      _VisitorStoreFilter.services => services.isEmpty
          ? const StoreEmptyState(
              icon: LucideIcons.briefcaseBusiness,
              title: 'No services yet',
              body: 'Services published by influencers will appear here.',
            )
          : gridFor(services),
      _VisitorStoreFilter.products => products.isEmpty
          ? const StoreEmptyState(
              icon: LucideIcons.package,
              title: 'No products yet',
              body: 'Products published by influencers will appear here.',
            )
          : gridFor(products),
      _VisitorStoreFilter.all => catalog.isEmpty
          ? StoreEmptyState(
              icon: LucideIcons.store,
              title: query.trim().isEmpty ? 'No listings yet' : 'No matches',
              body: emptyBody,
            )
          : gridFor(catalog.take(8).toList()),
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

  List<StoreMockCatalogItem> _inCategory(List<StoreMockCatalogItem> items) {
    final selected = category?.trim().toLowerCase() ?? '';
    if (selected.isEmpty) return items;
    return items
        .where((item) => item.category.trim().toLowerCase() == selected)
        .toList();
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
        const verticalGap = 12.0;
        const rightColumnOffset = 38.0;
        final leftItems = <Widget>[];
        final rightItems = <Widget>[];
        for (var index = 0; index < children.length; index++) {
          (index.isEven ? leftItems : rightItems).add(children[index]);
        }

        Widget listingColumn(List<Widget> items, {double topPadding = 0}) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    SizedBox(
                      height: MarketplaceListingCard.gridHeight,
                      width: double.infinity,
                      child: items[index],
                    ),
                    if (index < items.length - 1)
                      const SizedBox(height: verticalGap),
                  ],
                ],
              ),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            listingColumn(leftItems),
            const SizedBox(width: gap),
            listingColumn(rightItems, topPadding: rightColumnOffset),
          ],
        );
      },
    );
  }
}
