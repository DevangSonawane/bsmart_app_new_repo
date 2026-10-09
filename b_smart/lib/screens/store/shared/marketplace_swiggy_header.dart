import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../store_theme.dart';

/// Shared Swiggy-style marketplace header.
///
/// Layout (matches Swiggy reference):
///   DARK SECTION   -> user name row + curved folder tabs
///   COLOURED PANEL -> search bar + category chips
///
/// The selected tab is painted in the SAME colour as the panel below it and
/// flares outward with concave curves, so the tab and panel look like one
/// continuous shape. The tab indicator slides between tabs, and every colour
/// animates when the tab changes.
///
/// Tab artwork: 3D icons from the Icons8 "3D Fluency" set
/// (free with attribution to Icons8), stored locally under
/// assets/store/marketplace/ so there is no runtime network dependency.
enum MarketplaceTab { all, products, services }

class SwiggyMarketplaceHeader extends StatelessWidget {
  final String? userName;
  final String? userSubtitle;
  final VoidCallback? onUserTap;
  final VoidCallback? onWishlistTap;
  final MarketplaceTab selectedTab;
  final ValueChanged<MarketplaceTab> onTabSelected;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onClearQuery;
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final bool showCategoryFilters;
  final bool showAllCollage;

  /// When true the header bleeds from the very top edge (no title bar above
  /// it): it pads for the status bar and forces light status-bar icons like
  /// the Swiggy reference.
  final bool topStatusPadding;

  const SwiggyMarketplaceHeader({
    super.key,
    this.userName,
    this.userSubtitle,
    this.onUserTap,
    this.onWishlistTap,
    required this.selectedTab,
    required this.onTabSelected,
    required this.query,
    required this.onQueryChanged,
    required this.onClearQuery,
    this.categories = const [],
    this.selectedCategory,
    required this.onCategorySelected,
    this.showCategoryFilters = true,
    this.showAllCollage = true,
    this.topStatusPadding = false,
  });

  static const deepMaroon = BStoreColors.primary;
  static const _fallbackText = Color(0xFFD8F2F1);
  static const _allCollageAsset =
      'assets/bSmart_Store/Shopping and Home Services Marketplace.png';
  static const _productsCollageAsset =
      'assets/bSmart_Store/Marketplace Essentials Collage.png';
  static const _servicesCollageAsset =
      'assets/bSmart_Store/ChatGPT Image Oct 9, 2026 at 12_51_45 PM.png';

  static const _anim = Duration(milliseconds: 320);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final name = userName?.trim() ?? '';
    final subtitle = userSubtitle?.trim() ?? '';
    final theme = _MarketplaceHeaderTheme.forTab(selectedTab);

    final header = Container(
      margin:
          topStatusPadding ? EdgeInsets.zero : const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          // ───────────── DARK SECTION: name row + tabs ─────────────
          AnimatedContainer(
            duration: _anim,
            curve: _curve,
            color: theme.dark,
            padding: EdgeInsets.only(
              top: topStatusPadding ? MediaQuery.of(context).padding.top : 0,
            ),
            child: Column(
              children: [
                if (name.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 14, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onUserTap,
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.normal,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                    if (onUserTap != null) ...[
                                      const SizedBox(width: 2),
                                      const Icon(
                                        LucideIcons.chevronRight,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ],
                                ),
                                if (subtitle.isNotEmpty)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 2, right: 8),
                                    child: Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.tabText,
                                        fontSize: 11,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (onWishlistTap != null)
                          GestureDetector(
                            onTap: onWishlistTap,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Icon(LucideIcons.heart,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                _SwiggyTabBar(
                  selectedTab: selectedTab,
                  theme: theme,
                  onTabSelected: onTabSelected,
                ),
              ],
            ),
          ),
          // ───────────── PANEL: search + chips (same colour as active tab) ─────────────
          AnimatedContainer(
            duration: _anim,
            curve: _curve,
            decoration: BoxDecoration(
              color: theme.active,
              borderRadius: (showCategoryFilters || showAllCollage)
                  ? const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    )
                  : BorderRadius.zero,
            ),
            padding: EdgeInsets.only(
              top: 14,
              bottom: selectedTab == MarketplaceTab.all ? 4 : 14,
            ),
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        const Icon(LucideIcons.search,
                            size: 20, color: Color(0xFF6B7280)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              inputDecorationTheme: const InputDecorationTheme(
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                            child: TextField(
                              onChanged: onQueryChanged,
                              textInputAction: TextInputAction.search,
                              cursorColor: theme.active,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: switch (selectedTab) {
                                  MarketplaceTab.products =>
                                    "Search for 'Products'",
                                  MarketplaceTab.services =>
                                    "Search for 'Services'",
                                  MarketplaceTab.all => "Search for 'Cake'",
                                },
                                hintStyle: const TextStyle(
                                  color: Color(0xFF9AA0AE),
                                  fontSize: 13,
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(
                                color: Color(0xFF060D35),
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        if (onClearQuery != null)
                          IconButton(
                            onPressed: onClearQuery,
                            icon: const Icon(LucideIcons.x,
                                size: 18, color: Color(0xFF6B7280)),
                            tooltip: 'Clear search',
                          ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                ),
                if (showCategoryFilters && categories.isNotEmpty)
                  MarketplaceCategoryFilterBar(
                    categories: categories,
                    selectedCategory: selectedCategory,
                    selectedTab: selectedTab,
                    onCategorySelected: onCategorySelected,
                  ),
                if (showAllCollage)
                  AnimatedSwitcher(
                    duration: _anim,
                    switchInCurve: _curve,
                    switchOutCurve: Curves.easeInCubic,
                    child: switch (selectedTab) {
                      MarketplaceTab.all => const MarketplaceAllCollage(),
                      MarketplaceTab.products =>
                        const MarketplaceProductsCollage(),
                      MarketplaceTab.services =>
                        const MarketplaceServicesCollage(),
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!topStatusPadding) return header;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: header,
    );
  }

  static bool _sameCategory(String? a, String? b) {
    return (a ?? '').trim().toLowerCase() == (b ?? '').trim().toLowerCase();
  }
}

class MarketplaceAllCollage extends StatelessWidget {
  const MarketplaceAllCollage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MarketplaceCollageImage(
      key: ValueKey('all-marketplace-collage'),
      asset: SwiggyMarketplaceHeader._allCollageAsset,
    );
  }
}

class MarketplaceProductsCollage extends StatelessWidget {
  const MarketplaceProductsCollage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MarketplaceCollageImage(
      key: ValueKey('products-marketplace-collage'),
      asset: SwiggyMarketplaceHeader._productsCollageAsset,
    );
  }
}

class MarketplaceServicesCollage extends StatelessWidget {
  const MarketplaceServicesCollage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MarketplaceCollageImage(
      key: ValueKey('services-marketplace-collage'),
      asset: SwiggyMarketplaceHeader._servicesCollageAsset,
    );
  }
}

class _MarketplaceCollageImage extends StatelessWidget {
  final String asset;

  const _MarketplaceCollageImage({
    super.key,
    required this.asset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1.62,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── CURVED TAB BAR ───────────────────────── */

class _SwiggyTabBar extends StatelessWidget {
  final MarketplaceTab selectedTab;
  final _MarketplaceHeaderTheme theme;
  final ValueChanged<MarketplaceTab> onTabSelected;

  const _SwiggyTabBar({
    required this.selectedTab,
    required this.theme,
    required this.onTabSelected,
  });

  static const double _height = 76;
  static const double _unselectedTop = 10;

  static const _tabs = [
    (
      MarketplaceTab.all,
      'All',
      'assets/store/marketplace/tab_all.png',
      LucideIcons.layoutGrid
    ),
    (
      MarketplaceTab.products,
      'Products',
      'assets/store/marketplace/tab_products.png',
      LucideIcons.package
    ),
    (
      MarketplaceTab.services,
      'Services',
      'assets/store/marketplace/tab_services.png',
      LucideIcons.briefcaseBusiness
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _tabs.indexWhere((t) => t.$1 == selectedTab);

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabW = constraints.maxWidth / _tabs.length;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 1) Unselected tab backgrounds (shorter, sit lower)
              Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: SwiggyMarketplaceHeader._anim,
                        curve: SwiggyMarketplaceHeader._curve,
                        margin: EdgeInsets.only(
                          top: _unselectedTop,
                          left: i == 0 ? 10 : 6,
                          right: i == _tabs.length - 1 ? 10 : 6,
                        ),
                        child: TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: theme.inactive),
                          duration: SwiggyMarketplaceHeader._anim,
                          curve: SwiggyMarketplaceHeader._curve,
                          builder: (context, color, _) {
                            return CustomPaint(
                              painter: _InactiveTabPainter(
                                color: color ?? theme.inactive,
                                flareLeft: i > 0,
                                flareRight: i < _tabs.length - 1,
                              ),
                              child: const SizedBox.expand(),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),

              // 2) Sliding selected tab: same colour as the panel below,
              //    with concave flares that melt into it.
              AnimatedPositioned(
                duration: SwiggyMarketplaceHeader._anim,
                curve: SwiggyMarketplaceHeader._curve,
                left: selectedIndex * tabW,
                width: tabW,
                top: 0,
                bottom: 0,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: theme.active),
                  duration: SwiggyMarketplaceHeader._anim,
                  curve: SwiggyMarketplaceHeader._curve,
                  builder: (context, color, _) {
                    return CustomPaint(
                      painter: _CurvedTabPainter(
                        color: color ?? theme.active,
                        flareLeft: selectedIndex > 0,
                        flareRight: selectedIndex < _tabs.length - 1,
                      ),
                    );
                  },
                ),
              ),

              // 3) Icons + labels + tap targets
              Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _TabLabel(
                        label: _tabs[i].$2,
                        iconAsset: _tabs[i].$3,
                        fallbackIcon: _tabs[i].$4,
                        selected: i == selectedIndex,
                        theme: theme,
                        onTap: () => onTabSelected(_tabs[i].$1),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InactiveTabPainter extends CustomPainter {
  final Color color;
  final bool flareLeft;
  final bool flareRight;

  const _InactiveTabPainter({
    required this.color,
    required this.flareLeft,
    required this.flareRight,
  });

  static const double _flare = 16;
  static const double _radius = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    if (flareLeft) {
      path.moveTo(-_flare, h);
      path.quadraticBezierTo(0, h, 0, h - _flare);
    } else {
      path.moveTo(0, h + 1);
      path.lineTo(0, _radius);
    }

    if (flareLeft) path.lineTo(0, _radius);
    path.quadraticBezierTo(0, 0, _radius, 0);
    path.lineTo(w - _radius, 0);
    path.quadraticBezierTo(w, 0, w, _radius);

    if (flareRight) {
      path.lineTo(w, h - _flare);
      path.quadraticBezierTo(w, h, w + _flare, h);
      path.lineTo(w + _flare, h + 1);
    } else {
      path.lineTo(w, h + 1);
    }

    path.lineTo(flareLeft ? -_flare : 0, h + 1);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _InactiveTabPainter old) =>
      old.color != color ||
      old.flareLeft != flareLeft ||
      old.flareRight != flareRight;
}

class _TabLabel extends StatelessWidget {
  final String label;
  final String iconAsset;
  final IconData fallbackIcon;
  final bool selected;
  final _MarketplaceHeaderTheme theme;
  final VoidCallback onTap;

  const _TabLabel({
    required this.label,
    required this.iconAsset,
    required this.fallbackIcon,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selected ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          top: selected ? 0 : _SwiggyTabBar._unselectedTop,
          bottom: 4,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              scale: selected ? 1.15 : 0.92,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: selected ? 1 : 0.8,
                child: Image.asset(
                  iconAsset,
                  width: 26,
                  height: 26,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    fallbackIcon,
                    size: 22,
                    color: selected ? Colors.white : theme.tabText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              style: TextStyle(
                color: selected ? Colors.white : theme.tabText,
                fontSize: selected ? 12.5 : 12,
                fontWeight: FontWeight.normal,
                height: 1.1,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws a tab with rounded top corners and concave "flares" at the bottom
/// corners so it blends seamlessly into the coloured panel underneath.
class _CurvedTabPainter extends CustomPainter {
  final Color color;
  final bool flareLeft;
  final bool flareRight;

  const _CurvedTabPainter({
    required this.color,
    required this.flareLeft,
    required this.flareRight,
  });

  static const double _flare = 20;
  static const double _radius = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // bottom-left (flare or straight)
    if (flareLeft) {
      path.moveTo(-_flare, h);
      path.quadraticBezierTo(0, h, 0, h - _flare);
    } else {
      path.moveTo(0, h);
    }

    // left edge + top-left corner
    path.lineTo(0, _radius);
    path.quadraticBezierTo(0, 0, _radius, 0);

    // top edge + top-right corner
    path.lineTo(w - _radius, 0);
    path.quadraticBezierTo(w, 0, w, _radius);

    // right edge + bottom-right (flare or straight)
    if (flareRight) {
      path.lineTo(w, h - _flare);
      path.quadraticBezierTo(w, h, w + _flare, h);
      path.lineTo(w + _flare, h + 2); // 2px overlap hides any seam
    } else {
      path.lineTo(w, h + 2);
    }

    path.lineTo(flareLeft ? -_flare : 0, h + 2);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CurvedTabPainter old) =>
      old.color != color ||
      old.flareLeft != flareLeft ||
      old.flareRight != flareRight;
}

/* ───────────────────────── CATEGORY FILTERS ───────────────────────── */

class MarketplaceCategoryFilterBar extends StatefulWidget {
  final List<String> categories;
  final String? selectedCategory;
  final MarketplaceTab selectedTab;
  final ValueChanged<String?> onCategorySelected;
  final double topPadding;
  final double height;

  const MarketplaceCategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.selectedTab,
    required this.onCategorySelected,
    this.topPadding = 14,
    this.height = 52,
  });

  @override
  State<MarketplaceCategoryFilterBar> createState() =>
      _CategoryFilterBarState();
}

class _CategoryFilterBarState extends State<MarketplaceCategoryFilterBar> {
  static const _allKey = '__all__';

  final _scrollController = ScrollController();
  final _viewportKey = GlobalKey();
  final Map<String, GlobalKey> _filterKeys = {};

  @override
  void initState() {
    super.initState();
    _syncFilterKeys();
    _centerSelectedAfterLayout();
  }

  @override
  void didUpdateWidget(covariant MarketplaceCategoryFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFilterKeys();
    if (oldWidget.selectedCategory != widget.selectedCategory ||
        oldWidget.categories.length != widget.categories.length) {
      _centerSelectedAfterLayout();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _syncFilterKeys() {
    final ids = {
      _allKey,
      for (final category in widget.categories) _keyForCategory(category),
    };
    _filterKeys.removeWhere((key, _) => !ids.contains(key));
    for (final id in ids) {
      _filterKeys.putIfAbsent(id, GlobalKey.new);
    }
  }

  String _selectedKey() {
    final selected = widget.selectedCategory;
    if (selected == null || selected.trim().isEmpty) return _allKey;
    return _keyForCategory(selected);
  }

  static String _keyForCategory(String category) {
    return category.trim().toLowerCase();
  }

  void _centerSelectedAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerFilter(_selectedKey());
    });
  }

  void _handleTap(String id, String? value) {
    widget.onCategorySelected(value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centerFilter(id);
    });
  }

  void _centerFilter(String id) {
    if (!_scrollController.hasClients) return;
    final filterContext = _filterKeys[id]?.currentContext;
    final viewportContext = _viewportKey.currentContext;
    if (filterContext == null || viewportContext == null) return;

    final filterBox = filterContext.findRenderObject() as RenderBox?;
    final viewportBox = viewportContext.findRenderObject() as RenderBox?;
    if (filterBox == null || viewportBox == null) return;

    final filterOffset = filterBox.localToGlobal(
      Offset.zero,
      ancestor: viewportBox,
    );
    final filterCenter = filterOffset.dx + filterBox.size.width / 2;
    final targetOffset =
        _scrollController.offset + filterCenter - viewportBox.size.width / 2;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = _MarketplaceHeaderTheme.forTab(widget.selectedTab);
    return Padding(
      padding: EdgeInsets.only(top: widget.topPadding),
      child: SizedBox(
        key: _viewportKey,
        height: widget.height - widget.topPadding,
        child: Stack(
          children: [
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: Container(
                height: 1,
                color: const Color(0xFFD1D5DB).withValues(alpha: 0.75),
              ),
            ),
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CategoryChip(
                    key: _filterKeys[_allKey],
                    label: 'All',
                    selected: widget.selectedCategory == null,
                    theme: theme,
                    onTap: () => _handleTap(_allKey, null),
                  ),
                  for (final category in widget.categories)
                    _CategoryChip(
                      key: _filterKeys[_keyForCategory(category)],
                      label: category,
                      selected: SwiggyMarketplaceHeader._sameCategory(
                        widget.selectedCategory,
                        category,
                      ),
                      theme: theme,
                      onTap: () =>
                          _handleTap(_keyForCategory(category), category),
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final _MarketplaceHeaderTheme theme;
  final VoidCallback onTap;

  const _CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _categoryIconFor(label);
    return Container(
      margin: const EdgeInsets.only(right: 18),
      child: GestureDetector(
        onTap: selected ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 38,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: selected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.72),
                  ),
                  const SizedBox(width: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 112),
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 28 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _categoryIconFor(String value) {
  final normalized = value.toLowerCase();
  if (normalized == 'all') return LucideIcons.layoutGrid;
  if (normalized.contains('grocery')) return LucideIcons.shoppingBasket;
  if (normalized.contains('mobile') ||
      normalized.contains('phone') ||
      normalized.contains('tablet')) {
    return LucideIcons.smartphone;
  }
  if (normalized.contains('electronics') ||
      normalized.contains('gadget') ||
      normalized.contains('appliance')) {
    return LucideIcons.plugZap;
  }
  if (normalized.contains('bag') || normalized.contains('luggage')) {
    return LucideIcons.briefcase;
  }
  if (normalized.contains('footwear') || normalized.contains('shoe')) {
    return LucideIcons.footprints;
  }
  if (normalized.contains('sport') || normalized.contains('fitness')) {
    return LucideIcons.dumbbell;
  }
  if (normalized.contains('toy')) return LucideIcons.gamepad2;
  if (normalized.contains('auto') || normalized.contains('vehicle')) {
    return LucideIcons.car;
  }
  if (normalized.contains('business')) return LucideIcons.chartNoAxesCombined;
  if (normalized.contains('education') || normalized.contains('stationery')) {
    return LucideIcons.graduationCap;
  }
  if (normalized.contains('event')) return LucideIcons.calendarDays;
  if (normalized.contains('offer') || normalized.contains('deal')) {
    return LucideIcons.badgePercent;
  }
  if (normalized.contains('food') || normalized.contains('gourmet')) {
    return LucideIcons.chefHat;
  }
  if (normalized.contains('service')) return LucideIcons.briefcaseBusiness;
  if (normalized.contains('product')) return LucideIcons.package;
  if (normalized.contains('bolt') || normalized.contains('fast')) {
    return LucideIcons.zap;
  }
  if (normalized.contains('beauty') || normalized.contains('salon')) {
    return LucideIcons.sparkles;
  }
  if (normalized.contains('health') || normalized.contains('wellness')) {
    return LucideIcons.heartPulse;
  }
  if (normalized.contains('home') || normalized.contains('decor')) {
    return LucideIcons.house;
  }
  if (normalized.contains('fashion') || normalized.contains('cloth')) {
    return LucideIcons.shirt;
  }
  if (normalized.contains('book') || normalized.contains('learn')) {
    return LucideIcons.bookOpen;
  }
  if (normalized.contains('tech') || normalized.contains('digital')) {
    return LucideIcons.smartphone;
  }

  const fallbackIcons = [
    LucideIcons.tag,
    LucideIcons.shoppingBag,
    LucideIcons.gem,
    LucideIcons.star,
    LucideIcons.badgeCheck,
    LucideIcons.palette,
    LucideIcons.gift,
    LucideIcons.layers,
  ];
  final hash = normalized.codeUnits.fold<int>(
    0,
    (sum, code) => sum + code,
  );
  return fallbackIcons[hash % fallbackIcons.length];
}

/* ───────────────────────── PER-TAB COLOURS ───────────────────────── */

/// dark     -> header background (name row + tab strip)
/// active   -> selected tab AND the panel below it (must be identical!)
/// inactive -> unselected tabs
class _MarketplaceHeaderTheme {
  static const _allActive = Color(0xFF0A8F93);

  final Color dark;
  final Color active;
  final Color inactive;
  final Color tabText;

  const _MarketplaceHeaderTheme({
    required this.dark,
    required this.active,
    required this.inactive,
    required this.tabText,
  });

  static const _all = _MarketplaceHeaderTheme(
    dark: Color(0xFF063F42),
    active: _allActive,
    inactive: Color(0xFF0B5A5E),
    tabText: SwiggyMarketplaceHeader._fallbackText,
  );

  static _MarketplaceHeaderTheme forTab(MarketplaceTab tab) {
    return switch (tab) {
      MarketplaceTab.all => _all,
      MarketplaceTab.products => const _MarketplaceHeaderTheme(
          dark: Color(0xFF0E1E4D),
          active: Color(0xFF2A4BA0),
          inactive: Color(0xFF1B367D),
          tabText: Color(0xFFE3EAFF),
        ),
      MarketplaceTab.services => const _MarketplaceHeaderTheme(
          dark: Color(0xFF24082F),
          active: Color(0xFF5B1A87),
          inactive: Color(0xFF421363),
          tabText: Color(0xFFFBE3FF),
        ),
    };
  }
}

/// Swiggy-style bottom gradient + offer label over listing images
/// (e.g. "ITEMS AT ₹79", "30% OFF").
class SwiggyOfferOverlay extends StatelessWidget {
  final String line1;
  final String? line2;

  const SwiggyOfferOverlay({super.key, required this.line1, this.line2});

  @override
  Widget build(BuildContext context) {
    if (line1.trim().isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.75),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              line1,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.normal,
                letterSpacing: 0.2,
              ),
            ),
            if (line2 != null && line2!.trim().isNotEmpty)
              Text(
                line2!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
