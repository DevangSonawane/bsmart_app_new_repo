import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shared/store_shared_widgets.dart';
import 'shared/store_money.dart';
import 'store_models.dart';
import 'store_theme.dart';
import 'store_wishlist.dart';
import 'visitor_product_detail_page.dart';

enum _WishlistSort { newest, priceAsc, priceDesc, name }

/// Shared wishlist body used by both the standalone [StoreWishlistScreen]
/// route and the sliver-embedded [StoreWishlistSliver] nav section.
mixin StoreWishlistBodyMixin<T extends StatefulWidget> on State<T> {
  String _query = '';
  _WishlistSort _sort = _WishlistSort.newest;
  bool _confirmingClear = false;

  @override
  void initState() {
    super.initState();
    unawaited(WishlistState.instance.ensureLoaded());
  }

  List<StoreMockCatalogItem> _visible(List<StoreMockCatalogItem> items) {
    final q = _query.trim().toLowerCase();
    var list = q.isEmpty
        ? List<StoreMockCatalogItem>.from(items)
        : items.where((item) {
            return item.title.toLowerCase().contains(q) ||
                item.category.toLowerCase().contains(q) ||
                item.description.toLowerCase().contains(q);
          }).toList();
    switch (_sort) {
      case _WishlistSort.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case _WishlistSort.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case _WishlistSort.name:
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case _WishlistSort.newest:
        break; // Backend already returns newest-added first.
    }
    return list;
  }

  Future<void> _confirmClear() async {
    if (!_confirmingClear) {
      setState(() => _confirmingClear = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _confirmingClear = false);
      });
      return;
    }
    setState(() => _confirmingClear = false);
    try {
      await WishlistState.instance.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(WishlistState.instance.lastErrorMessage ?? '')),
      );
    }
  }

  /// Builds the wishlist slivers. [topInset] is only applied in standalone
  /// mode (the section is already inside a SafeArea-aware scroll view).
  List<Widget> _slivers(
    BuildContext context, {
    required double topInset,
    required bool showBack,
    VoidCallback? onExplore,
  }) {
    final state = WishlistState.instance;
    final visible = _visible(state.items);
    return [
      SliverToBoxAdapter(
        child: _topBar(context, state,
            topInset: topInset, showBack: showBack),
      ),
      if (state.items.isNotEmpty)
        SliverToBoxAdapter(child: _statsRow(state)),
      if (state.items.isNotEmpty)
        SliverToBoxAdapter(child: _searchSortRow()),
      if (state.loading && state.items.isEmpty)
        const SliverToBoxAdapter(child: _WishlistSkeletons())
      else if (state.items.isEmpty && state.lastError == null)
        SliverToBoxAdapter(child: _emptyBody(onExplore))
      else if (state.items.isEmpty)
        SliverToBoxAdapter(
          child: _errorBody(state, onRetry: state.refresh),
        )
      else if (visible.isEmpty)
        SliverToBoxAdapter(child: _noResultsBody())
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 296,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _WishlistCard(item: visible[index]),
              childCount: visible.length,
            ),
          ),
        ),
      // The store shell appends its own 22px spacer when this body is used as
      // a nav section, so only add one in standalone mode.
      if (showBack) const SliverToBoxAdapter(child: SizedBox(height: 22)),
    ];
  }

  Widget _topBar(
    BuildContext context,
    WishlistState state, {
    required double topInset,
    required bool showBack,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        topInset + MediaQuery.of(context).padding.top + 8,
        16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        LucideIcons.chevronLeft,
                        color: BStoreColors.textPrimary,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                    ),
                  ),
                const Center(child: StoreBsmartWordmark()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Wishlist',
                style: TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 9),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: BStoreColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  state.loading && state.items.isEmpty
                      ? '…'
                      : '${state.count} saved',
                  style: const TextStyle(
                    color: BStoreColors.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              if (state.items.isNotEmpty)
                TextButton.icon(
                  onPressed: state.clearing ? null : _confirmClear,
                  icon: state.clearing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.trash2, size: 16),
                  label:
                      Text(_confirmingClear ? 'Confirm clear?' : 'Clear all'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        _confirmingClear ? Colors.white : BStoreColors.primary,
                    backgroundColor:
                        _confirmingClear ? BStoreColors.primary : null,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Synced to your account · newest-added first',
                  style: TextStyle(
                    color: BStoreColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: state.loading ? null : state.refresh,
                icon: state.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.refreshCw, size: 19),
                color: BStoreColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (state.lastError != null && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF3C2C2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.lastErrorMessage ?? 'Something went wrong.',
                        style: const TextStyle(
                          color: Color(0xFFB3261E),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: state.refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statsRow(WishlistState state) {
    final rated = state.items.where((i) => _ratingValue(i) > 0).toList();
    final avg = rated.isEmpty
        ? '—'
        : (rated.map(_ratingValue).reduce((a, b) => a + b) / rated.length)
            .toStringAsFixed(1);
    final stats = [
      (LucideIcons.heart, 'Saved items', '${state.count}'),
      (
        LucideIcons.shoppingBag,
        'Total value',
        formatStoreMoney(state.totalValue, decimals: 2)
      ),
      (LucideIcons.star, 'Avg rating', avg),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 12),
                decoration: BStoreDecorations.card(),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: BStoreColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        stats[i].$1,
                        color: BStoreColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stats[i].$2.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BStoreColors.textMuted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            stats[i].$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: BStoreColors.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != stats.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _searchSortRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search your wishlist…',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: BStoreColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: BStoreColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<_WishlistSort>(
            value: _sort,
            underline: const SizedBox.shrink(),
            icon: const Icon(LucideIcons.chevronDown, size: 16),
            items: const [
              DropdownMenuItem(
                  value: _WishlistSort.newest, child: Text('Newest')),
              DropdownMenuItem(
                  value: _WishlistSort.priceAsc,
                  child: Text('Price ↑')),
              DropdownMenuItem(
                  value: _WishlistSort.priceDesc,
                  child: Text('Price ↓')),
              DropdownMenuItem(
                  value: _WishlistSort.name, child: Text('A–Z')),
            ],
            onChanged: (v) => setState(() => _sort = v ?? _sort),
          ),
        ],
      ),
    );
  }

  Widget _emptyBody(VoidCallback? onExplore) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 0),
      child: Column(
        children: [
          const StoreEmptyState(
            icon: LucideIcons.heart,
            title: 'Your wishlist is empty',
            body:
                'Tap the heart on any product to save it here — it syncs to your account.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onExplore ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(LucideIcons.chevronRight, size: 16),
            label: const Text('Explore Marketplace'),
            style: BStoreButtons.filled(),
          ),
        ],
      ),
    );
  }

  Widget _errorBody(WishlistState state,
      {required Future<void> Function() onRetry}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 0),
      child: Column(
        children: [
          StoreEmptyState(
            icon: LucideIcons.cloudOff,
            title: "Couldn't load wishlist",
            body: state.lastErrorMessage ?? 'Please try again.',
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _noResultsBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 0),
      child: Column(
        children: [
          StoreEmptyState(
            icon: LucideIcons.search,
            title: 'No matches',
            body: 'No wishlist items match “${_query.trim()}”.',
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _query = ''),
            child: const Text('Clear search'),
          ),
        ],
      ),
    );
  }

  static double _ratingValue(StoreMockCatalogItem item) {
    return double.tryParse(item.rating) ?? 0;
  }
}

/// Wishlist screen — server-backed product wishlist (GET /wishlist et al).
///
/// Same BStore design language as the marketplace: cream background,
/// white 14-radius cards, teal (#078D92) prices and accents.
class StoreWishlistScreen extends StatefulWidget {
  const StoreWishlistScreen({super.key});

  @override
  State<StoreWishlistScreen> createState() => _StoreWishlistScreenState();
}

class _StoreWishlistScreenState extends State<StoreWishlistScreen>
    with StoreWishlistBodyMixin<StoreWishlistScreen> {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.backgroundAlt,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: WishlistState.instance,
            builder: (context, _) => CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: _slivers(
                context,
                topInset: 0,
                showBack: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sliver-embeddable wishlist body for the store's bottom-nav section.
///
/// Rebuilds are driven by [StoreHomeScreen] listening to [WishlistState],
/// since a [ListenableBuilder] cannot sit inside a `slivers` list.
class StoreWishlistSliver extends StatefulWidget {
  final VoidCallback? onExplore;

  const StoreWishlistSliver({super.key, this.onExplore});

  @override
  State<StoreWishlistSliver> createState() => _StoreWishlistSliverState();
}

class _StoreWishlistSliverState extends State<StoreWishlistSliver>
    with StoreWishlistBodyMixin<StoreWishlistSliver> {
  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: _slivers(
        context,
        topInset: 0,
        showBack: false,
        onExplore: widget.onExplore,
      ),
    );
  }
}

class _WishlistSkeletons extends StatelessWidget {
  const _WishlistSkeletons();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 2; i++) ...[
            Expanded(
              child: Container(
                height: 260,
                decoration: storeSoftCardDecoration(radius: 14),
              ),
            ),
            if (i == 0) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final StoreMockCatalogItem item;

  const _WishlistCard({required this.item});

  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitorProductDetailPage(
          product: VisitorProductDetailData(item: item),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: storeSoftCardDecoration(radius: 14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                StoreItemImage(
                  imageUrl: item.imageUrl,
                  icon: item.icon,
                  width: double.infinity,
                  height: 132,
                  debugLabel: 'wishlist-card',
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'WISHLIST',
                      style: TextStyle(
                        color: BStoreColors.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: WishlistHeartButton(productId: item.id),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.priceLabel,
                    style: const TextStyle(
                      color: BStoreColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 34,
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        StoreMockState.instance.addToCart(item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${item.title} added to cart')),
                        );
                      },
                      icon: const Icon(LucideIcons.shoppingCart, size: 15),
                      label: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: BStoreButtons.filled(radius: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
