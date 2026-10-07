import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../store_theme.dart';

/// Shared Swiggy-style marketplace header.
///
/// Order (matches Swiggy reference):
///   0. User name row (like "ankita jha >")
///   1. Folder tabs: All / Products / Services
///   2. Full-width search bar below tabs
///   3. Bottom filter card: single white card with category chips,
///      no dividers — one unified thing.
/// The listings grid is rendered below this header by the caller,
/// filtered by the selected tab + category.
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

  /// When true the maroon card bleeds from the very top edge (no title bar
  /// above it): it drops its top margin, pads for the status bar, and
  /// forces light status-bar icons like the Swiggy reference.
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
    this.topStatusPadding = false,
  });

  static const deepMaroon = BStoreColors.primary;
  static const tabActive = Color(0xFF0AA4A8);
  static const tabInactive = Color(0xFF066F73);
  static const tabInactiveText = Color(0xFFD8F2F1);

  @override
  Widget build(BuildContext context) {
    final name = userName?.trim() ?? '';
    final subtitle = userSubtitle?.trim() ?? '';
    final card = Container(
      margin: topStatusPadding
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(0, 10, 0, 0),
      padding: topStatusPadding
          ? EdgeInsets.only(top: MediaQuery.of(context).padding.top)
          : null,
      decoration: const BoxDecoration(
        color: deepMaroon,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ---- 0. User name row (like Swiggy's "ankita jha >") ----
          if (name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 0),
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (onUserTap != null) ...[
                                const SizedBox(width: 2),
                                const Icon(
                                  LucideIcons.chevronRight,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ],
                            ],
                          ),
                          if (subtitle.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2, right: 8),
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: tabInactiveText,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
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
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(LucideIcons.heart,
                            size: 17, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          // ---- 1. Folder tabs: All / Products / Services ----
          // Fluid sliding pill (Swiggy folder-tab feel) + 3D icons.
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 7, 6, 0),
            child: _SwiggyTabBar(
              selectedTab: selectedTab,
              onTabSelected: onTabSelected,
            ),
          ),
          // ---- 2. Search bar below tabs ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(LucideIcons.search,
                      size: 18, color: Color(0xFF6B7280)),
                  const SizedBox(width: 7),
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
                        cursorColor: BStoreColors.primary,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: switch (selectedTab) {
                            MarketplaceTab.products => "Search for 'Products'",
                            MarketplaceTab.services => "Search for 'Services'",
                            MarketplaceTab.all => "Search for 'Cake'",
                          },
                          hintStyle: const TextStyle(
                            color: Color(0xFF9AA0AE),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (onClearQuery != null)
                    IconButton(
                      onPressed: onClearQuery,
                      icon: const Icon(LucideIcons.x,
                          size: 16, color: Color(0xFF6B7280)),
                      tooltip: 'Clear search',
                    ),
                  Container(
                      width: 1, height: 22, color: const Color(0xFFE5E7EB)),
                  const IconButton(
                    onPressed: null,
                    icon: Icon(LucideIcons.mic,
                        size: 19, color: BStoreColors.primary),
                  ),
                ],
              ),
            ),
          ),
          // ---- 3. Bottom category filter tabs ----
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 0, 0),
            child: SizedBox(
              height: 34,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _CategoryTab(
                      label: 'All',
                      selected: selectedCategory == null,
                      onTap: () => onCategorySelected(null),
                    ),
                    for (final category in categories)
                      _CategoryTab(
                        label: category,
                        selected: selectedCategory == category,
                        onTap: () => onCategorySelected(category),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (!topStatusPadding) return card;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: card,
    );
  }
}

class _SwiggyTabBar extends StatelessWidget {
  final MarketplaceTab selectedTab;
  final ValueChanged<MarketplaceTab> onTabSelected;

  const _SwiggyTabBar({
    required this.selectedTab,
    required this.onTabSelected,
  });

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final tabWidth = totalWidth / _tabs.length;
        final selectedIndex =
            _tabs.indexWhere((t) => t.$1 == selectedTab).clamp(0, 2);
        return SizedBox(
          height: 86,
          child: Stack(
            children: [
              // Fluid sliding active folder behind the tabs.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: selectedIndex * tabWidth + 3,
                top: 0,
                bottom: 0,
                width: tabWidth - 6,
                child: CustomPaint(
                  painter: _SelectedFolderTabPainter(
                    color: SwiggyMarketplaceHeader.tabActive,
                    borderColor: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: _SwiggyTopTab(
                          label: _tabs[i].$2,
                          iconAsset: _tabs[i].$3,
                          fallbackIcon: _tabs[i].$4,
                          selected: selectedTab == _tabs[i].$1,
                          isFirst: i == 0,
                          isLast: i == _tabs.length - 1,
                          onTap: () => onTabSelected(_tabs[i].$1),
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

class _SwiggyTopTab extends StatelessWidget {
  final String label;
  final String iconAsset;
  final IconData fallbackIcon;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _SwiggyTopTab({
    required this.label,
    required this.iconAsset,
    required this.fallbackIcon,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selected ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: EdgeInsets.only(
          left: isFirst ? 0 : 3,
          right: isLast ? 0 : 3,
          top: selected ? 0 : 10,
        ),
        decoration: selected
            ? null
            : ShapeDecoration(
                color: SwiggyMarketplaceHeader.tabInactive,
                shape: _FolderTabBorder(
                  borderColor: Colors.white.withValues(alpha: 0.18),
                ),
              ),
        padding: EdgeInsets.fromLTRB(4, selected ? 9 : 7, 4, 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 3D icon with a fluid pop when selected.
            AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              scale: selected ? 1.10 : 1.0,
              child: Image.asset(
                iconAsset,
                width: selected ? 34 : 31,
                height: selected ? 34 : 31,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  fallbackIcon,
                  size: 25,
                  color: selected
                      ? Colors.white
                      : SwiggyMarketplaceHeader.tabInactiveText,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : SwiggyMarketplaceHeader.tabInactiveText,
                  fontSize: selected ? 13 : 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 2.5,
              width: selected ? 34 : 0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFolderTabPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  const _SelectedFolderTabPainter({
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final path = Path()
      ..moveTo(22, 0)
      ..lineTo(size.width - 22, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 22)
      ..lineTo(size.width, size.height - 14)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - 16,
        size.height,
      )
      ..lineTo(16, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 14)
      ..lineTo(0, 22)
      ..quadraticBezierTo(0, 0, 22, 0)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SelectedFolderTabPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.borderColor != borderColor;
  }
}

class _FolderTabBorder extends ShapeBorder {
  final Color borderColor;

  const _FolderTabBorder({required this.borderColor});

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(1.1);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _buildPath(rect.deflate(1.1));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _buildPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawPath(_buildPath(rect.deflate(0.55)), paint);
  }

  @override
  ShapeBorder scale(double t) => _FolderTabBorder(borderColor: borderColor);

  Path _buildPath(Rect rect) {
    final r = rect.shortestSide.clamp(0, 20).toDouble();
    final bottomRadius = (r * 0.72).clamp(0, 14).toDouble();
    return Path()
      ..moveTo(rect.left + r, rect.top)
      ..lineTo(rect.right - r, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + r)
      ..lineTo(rect.right, rect.bottom - bottomRadius)
      ..quadraticBezierTo(
        rect.right,
        rect.bottom,
        rect.right - bottomRadius,
        rect.bottom,
      )
      ..lineTo(rect.left + bottomRadius, rect.bottom)
      ..quadraticBezierTo(
        rect.left,
        rect.bottom,
        rect.left,
        rect.bottom - bottomRadius,
      )
      ..lineTo(rect.left, rect.top + r)
      ..quadraticBezierTo(rect.left, rect.top, rect.left + r, rect.top)
      ..close();
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(label);
    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: selected ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 34,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: selected
                        ? Colors.white
                        : SwiggyMarketplaceHeader.tabInactiveText,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : SwiggyMarketplaceHeader.tabInactiveText,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: selected ? 56 : 0,
                height: 3,
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

  IconData _iconFor(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'all') return LucideIcons.layoutGrid;
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
                fontSize: 17,
                fontWeight: FontWeight.w900,
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
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
