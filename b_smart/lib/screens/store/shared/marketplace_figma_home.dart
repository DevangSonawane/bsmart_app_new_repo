// Marketplace home ("iPhone 18 Pro - 5" frame in the Bsmart Figma file).
//
// Every section below maps 1:1 to a block of that frame. Measurements are the
// Figma values on a 402pt-wide canvas with a 16pt gutter.
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../store_models.dart';
import '../store_wishlist.dart';
import '../visitor_product_detail_page.dart';
import '../visitor_service_detail_page.dart';
import 'store_money.dart';
import 'store_shared_widgets.dart';

const _asset = 'assets/store/marketplace/home';

/// Design tokens pulled from the Figma file.
abstract final class MkColors {
  static const brand = Color(0xFFFA3E5E);
  static const heroPink = Color(0xFFFCB2BF);
  static const ink = Color(0xFF000000);
  static const body = Color(0xFF242424);
  static const muted = Color(0xFF414141);
  static const subtle = Color(0xFF555555);
  static const divider = Color(0xFFCBCBCB);
  static const shadow = Color(0x33000000);
}

List<BoxShadow> get _cardShadow => const [
      BoxShadow(color: MkColors.shadow, blurRadius: 10, offset: Offset(0, 4)),
    ];

TextStyle _sectionTitle() => GoogleFonts.sourceSans3(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: MkColors.ink,
      height: 1.25,
    );

void openStoreSearch(BuildContext context, {String? query, String? category}) {
  Navigator.of(context).pushNamed(
    '/store/search',
    arguments: <String, String>{
      if (query != null) 'q': query,
      if (category != null) 'category': category,
    },
  );
}

// ─────────────────────────── Greeting header ───────────────────────────

class MkGreetingHeader extends StatelessWidget {
  final String? userName;
  final String? location;
  final bool topStatusPadding;
  final VoidCallback? onLocationTap;
  final VoidCallback? onBellTap;

  const MkGreetingHeader({
    super.key,
    required this.userName,
    required this.location,
    this.topStatusPadding = true,
    this.onLocationTap,
    this.onBellTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = (userName ?? '').trim().split(RegExp(r'\s+')).first;
    final top = topStatusPadding ? MediaQuery.of(context).padding.top : 0.0;
    final greeting = GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: MkColors.ink,
      height: 1.25,
    );
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16, top + 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: firstName.isEmpty ? 'Hello!' : 'Hello ',
                    children: [
                      if (firstName.isNotEmpty)
                        TextSpan(
                          text: '$firstName!',
                          style: greeting.copyWith(color: MkColors.brand),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: greeting,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onLocationTap,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 16, color: MkColors.subtle),
                      const SizedBox(width: 4),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: Text(
                            (location ?? '').trim().isEmpty
                                ? 'Add delivery address'
                                : location!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: MkColors.subtle,
                            ),
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down,
                          size: 20, color: MkColors.subtle),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onBellTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MkColors.brand.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: MkColors.brand),
              ),
              child:
                  const Icon(LucideIcons.bell, size: 20, color: MkColors.brand),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Folder tabs ───────────────────────────

enum MkHomeTab { all, products, services, people }

/// Per-tab colour of the hero and the active folder tab (Figma frames 5, 7).
/// Pink is used until the PRODUCTS / SERVICES frames are built.
class MkTabTheme {
  final Color hero;
  final Color tabStroke;
  const MkTabTheme(this.hero, this.tabStroke);

  static const pink = MkTabTheme(MkColors.heroPink, MkColors.brand);
  static const blue = MkTabTheme(Color(0xFFB3C8FD), Color(0xFF5075FE));

  static MkTabTheme of(MkHomeTab tab) => tab == MkHomeTab.people ? blue : pink;
}

class MkFolderTabs extends StatelessWidget {
  final MkHomeTab selected;
  final ValueChanged<MkHomeTab> onSelected;

  const MkFolderTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const _labels = {
    MkHomeTab.all: 'ALL',
    MkHomeTab.products: 'PRODUCTS',
    MkHomeTab.services: 'SERVICES',
    MkHomeTab.people: 'PEOPLE',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth / MkHomeTab.values.length;
        final index = MkHomeTab.values.indexOf(selected);
        return Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: index * w,
              top: 0,
              bottom: 0,
              width: w,
              child: CustomPaint(
                painter: _FolderTabPainter(theme: MkTabTheme.of(selected)),
              ),
            ),
            Row(
              children: [
                for (final tab in MkHomeTab.values)
                  Expanded(
                    child: InkWell(
                      onTap: () => onSelected(tab),
                      child: Center(
                        child: Text(
                          _labels[tab]!,
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            fontWeight: tab == selected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color:
                                tab == selected ? MkColors.ink : MkColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

/// Rounded-top tab whose bottom corners flare outwards into the hero below.
class _FolderTabPainter extends CustomPainter {
  final MkTabTheme theme;
  const _FolderTabPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    const flare = 7.0;
    const r = 10.0;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, h)
      ..quadraticBezierTo(flare, h, flare, h - flare)
      ..lineTo(flare, r)
      ..quadraticBezierTo(flare, 0, flare + r, 0)
      ..lineTo(w - flare - r, 0)
      ..quadraticBezierTo(w - flare, 0, w - flare, r)
      ..lineTo(w - flare, h - flare)
      ..quadraticBezierTo(w - flare, h, w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = theme.hero);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.tabStroke, theme.tabStroke.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _FolderTabPainter old) => old.theme != theme;
}

// ─────────────────────────── Hero ───────────────────────────

class MkSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const MkSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final style =
        GoogleFonts.roboto(fontSize: 14, color: const Color(0xFF373737));
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: MkColors.shadow, blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.search, size: 22, color: Color(0xFF373737)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: style,
              // Override the app-wide input theme (filled + outlined).
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search by products, services & categories...',
                hintStyle: style,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: const Icon(LucideIcons.x,
                        size: 18, color: Color(0xFF373737)),
                  ),
          ),
        ],
      ),
    );
  }
}

class MkPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const MkPillButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFA3F5E),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.33,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(LucideIcons.arrowRight, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class MkHero extends StatelessWidget {
  final Widget search;
  final bool showBanner;
  final VoidCallback onExplore;
  final MkTabTheme theme;

  /// Frame 7 (PEOPLE) drops the illustration and runs the copy full width.
  final bool textOnly;

  const MkHero({
    super.key,
    required this.search,
    required this.onExplore,
    this.showBanner = true,
    this.theme = MkTabTheme.pink,
    this.textOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      color: theme.hero,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: search,
          ),
          if (!showBanner) const SizedBox(height: 16),
          if (showBanner && textOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(34, 22, 32, 52),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discover products & services from creators',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: MkColors.ink,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explore unique finds, exciting services & creator favourites.',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: const Color(0xFF252525),
                      height: 1.57,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MkPillButton(label: 'Explore', onTap: onExplore),
                ],
              ),
            ),
          if (showBanner && !textOnly)
            SizedBox(
              height: 197,
              child: Stack(
                children: [
                  Positioned(
                    right: 22,
                    bottom: 0,
                    width: 179,
                    height: 185,
                    child: Image.asset('$_asset/hero_creator.webp',
                        fit: BoxFit.contain),
                  ),
                  Positioned(
                    left: 16,
                    top: 31,
                    width: 224,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discover products & services from creators',
                          style: GoogleFonts.sourceSans3(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: MkColors.ink,
                            height: 1.28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Explore unique finds, exciting services & creator favourites.',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: MkColors.body,
                            height: 1.57,
                          ),
                        ),
                        const SizedBox(height: 8),
                        MkPillButton(label: 'Explore', onTap: onExplore),
                      ],
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

// ─────────────────────────── Explore by category ───────────────────────────

class MkCategory {
  final String label;
  final String icon;
  final Color color;
  final List<MkSubCategory> subcategories;
  const MkCategory(this.label, this.icon, this.color,
      [this.subcategories = const []]);
}

class MkSubCategory {
  final String label;
  final String image;
  const MkSubCategory(this.label, this.image);
}

const mkCategories = <MkCategory>[
  MkCategory('Fashion', 'cat_fashion', Color(0xFFBE1E2D), [
    MkSubCategory("Women's wear", 'sub_womens_wear'),
    MkSubCategory("Men's wear", 'sub_mens_wear'),
    MkSubCategory('Kids Fashion', 'sub_kids_fashion'),
    MkSubCategory('Footwear', 'sub_footwear'),
    MkSubCategory('Bag & Wallets', 'sub_bags_wallets'),
    MkSubCategory('Jewellery & Watches', 'sub_jewellery_watches'),
    MkSubCategory('Activewear', 'sub_activewear'),
    MkSubCategory('Innerwear & Sleepwear', 'sub_innerwear'),
  ]),
  MkCategory('Tech', 'cat_tech', Color(0xFF99E6EF)),
  MkCategory('Beauty', 'cat_beauty', Color(0xFFFADDC8)),
  MkCategory('Home Services', 'cat_home_services', Color(0xFF99E6EF)),
  MkCategory('Education', 'cat_education', Color(0xFFC8FACB)),
  MkCategory('Events', 'cat_events', Color(0xFFFACAB8)),
];

class MkExploreByCategory extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<MkSubCategory> onSubCategoryTap;

  const MkExploreByCategory({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSubCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final subs = mkCategories[selectedIndex].subcategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: MkColors.divider)),
          ),
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Text('Explore by category', style: _sectionTitle()),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < mkCategories.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      _CategoryChip(
                        category: mkCategories[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (subs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
            child: LayoutBuilder(builder: (context, c) {
              const cols = 4;
              const tileW = 80.0;
              final gap = (c.maxWidth - tileW * cols) / (cols - 1);
              return Wrap(
                spacing: gap,
                runSpacing: 16,
                children: [
                  for (final sub in subs)
                    _SubCategoryTile(
                      sub: sub,
                      onTap: () => onSubCategoryTap(sub),
                    ),
                ],
              );
            }),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final MkCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // Sized to the chip so the underline can stretch to match it inside the
      // horizontal scroller (which gives unbounded width).
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 47,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomLeft,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 37,
                    padding: const EdgeInsets.fromLTRB(46, 0, 10, 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? null : category.color,
                      gradient: selected
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF3A0A10), Color(0xFFBE1E2D)],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          selected ? Border.all(color: MkColors.brand) : null,
                    ),
                    child: Text(
                      category.label,
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: selected ? Colors.white : MkColors.ink,
                      ),
                    ),
                  ),
                  Positioned(
                    left: -2,
                    bottom: 0,
                    width: 48,
                    height: 48,
                    child: Image.asset('$_asset/${category.icon}.webp',
                        fit: BoxFit.contain),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: selected ? MkColors.brand : Colors.transparent,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubCategoryTile extends StatelessWidget {
  final MkSubCategory sub;
  final VoidCallback onTap;
  const _SubCategoryTile({required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              height: 99,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFFFF), Color(0xFFFA3F5E)],
                ),
              ),
              padding: const EdgeInsets.all(1),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Color(0xFFFBC3D5)],
                  ),
                ),
                child: Image.asset('$_asset/${sub.image}.webp',
                    fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: MkColors.ink,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Deals & Offers ───────────────────────────

class MkDealsAndOffers extends StatelessWidget {
  final VoidCallback onCreatorOffer;
  final VoidCallback onBeauty;
  final VoidCallback onElectronics;
  final VoidCallback onBCoins;

  const MkDealsAndOffers({
    super.key,
    required this.onCreatorOffer,
    required this.onBeauty,
    required this.onElectronics,
    required this.onBCoins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC8D2FC), Colors.white],
        ),
      ),
      padding: const EdgeInsets.only(bottom: 0),
      child: Column(
        children: [
          SizedBox(
            width: 234,
            height: 40,
            child: CustomPaint(
              painter: const _RibbonPainter(),
              child: Center(
                child: Text(
                  'Deals & Offers',
                  style: GoogleFonts.oleoScript(
                    fontSize: 20,
                    color: const Color(0xFF0F257B),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 17),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _CreatorOfferBanner(onTap: onCreatorOffer),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DealTile(
                        caption: 'Beauty Essential',
                        highlight: '50% OFF',
                        accent: MkColors.brand,
                        background: 'deal_beauty_bg',
                        product: 'deal_beauty_product',
                        onTap: onBeauty,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DealTile(
                        caption: 'Electronics up to',
                        highlight: '50% OFF',
                        accent: const Color(0xFF0159AA),
                        background: 'deal_electronics_bg',
                        product: 'deal_electronics_product',
                        onTap: onElectronics,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _BCoinsTile(onTap: onBCoins)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White ribbon with slanted sides hanging from the section's top edge.
class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const slant = 28.0;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - slant, size.height - 4)
      ..quadraticBezierTo(size.width - slant - 2, size.height,
          size.width - slant - 8, size.height)
      ..lineTo(slant + 8, size.height)
      ..quadraticBezierTo(slant + 2, size.height, slant, size.height - 4)
      ..close();
    canvas.drawShadow(path, const Color(0x40000000), 3, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFF5075FE), Color(0x00FFFFFF)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CreatorOfferBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CreatorOfferBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final small = GoogleFonts.roboto(fontSize: 14, color: MkColors.ink);
    final big = GoogleFonts.podkova(fontSize: 20, color: MkColors.ink);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 154,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('$_asset/deal_creator_bg.webp', fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [Color(0x00FFFFFF), Color(0xB2FFFFFF)],
                  ),
                ),
              ),
              Positioned(
                right: -17,
                top: 10,
                width: 216,
                height: 144,
                child: Image.asset('$_asset/deal_creator_people.webp',
                    fit: BoxFit.cover),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                top: 0,
                bottom: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Special Creator offers', style: small),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Extra '),
                        TextSpan(
                          text: '25%',
                          style: big.copyWith(
                            color: MkColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' OFF'),
                      ]),
                      style: big,
                    ),
                    const SizedBox(height: 2),
                    Text('on creator collection', style: small),
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

class _ArrowDot extends StatelessWidget {
  final Color color;
  final double size;
  const _ArrowDot({required this.color, this.size = 16});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(LucideIcons.arrowRight,
            size: size * 0.72, color: Colors.white),
      );
}

class _DealTile extends StatelessWidget {
  final String caption;
  final String highlight;
  final Color accent;
  final String background;
  final String product;
  final VoidCallback onTap;

  const _DealTile({
    required this.caption,
    required this.highlight,
    required this.accent,
    required this.background,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 147,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _cardShadow,
          image: DecorationImage(
            image: AssetImage('$_asset/$background.webp'),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(fontSize: 10, color: MkColors.ink)),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(
                  highlight,
                  style: GoogleFonts.sourceSans3(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: accent,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 4),
                _ArrowDot(color: accent),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child:
                    Image.asset('$_asset/$product.webp', fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BCoinsTile extends StatelessWidget {
  final VoidCallback onTap;
  const _BCoinsTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 147,
        decoration: BoxDecoration(
          color: const Color(0xFFF7E9BD),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _cardShadow,
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Earn B-Coins, Enjoy More Savings!',
              maxLines: 3,
              style: GoogleFonts.sourceSans3(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MkColors.ink,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Center(
                child: Image.asset('$_asset/deal_bcoins.webp',
                    fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Trendy Summer Collections ───────────────────────────

class MkSummerItem {
  final String label;
  final String image;
  const MkSummerItem(this.label, this.image);
}

const mkSummerAudiences = ["Women's", "Men's", "Kid's", "Elder's"];

/// The Figma frame only ships imagery for the Women's collection, so every
/// audience uses it until merchandising provides the rest.
const mkSummerItems = <MkSummerItem>[
  MkSummerItem('Crop tops', 'summer_crop_tops'),
  MkSummerItem('Tank tops', 'summer_tank_tops'),
  MkSummerItem('Sun glasses', 'summer_sunglasses'),
  MkSummerItem('Sun Hat', 'summer_fourth'),
];

class MkTrendySummer extends StatelessWidget {
  final int audienceIndex;
  final ValueChanged<int> onAudienceSelected;
  final ValueChanged<MkSummerItem> onItemTap;
  final VoidCallback onExploreAll;

  const MkTrendySummer({
    super.key,
    required this.audienceIndex,
    required this.onAudienceSelected,
    required this.onItemTap,
    required this.onExploreAll,
  });

  @override
  Widget build(BuildContext context) {
    final audience = mkSummerAudiences[audienceIndex];
    return Column(
      children: [
        Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 232,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('$_asset/summer_bg.webp', fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00FFFFFF), Colors.white],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  Text('Trendy',
                      style: GoogleFonts.oleoScript(
                          fontSize: 20, color: MkColors.ink, height: 1.4)),
                  Text(
                    'Summer Collections',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AudienceSwitch(
                    selected: audienceIndex,
                    onSelected: onAudienceSelected,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 161,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      clipBehavior: Clip.none,
                      itemCount: mkSummerItems.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 18),
                      itemBuilder: (context, i) => _SummerTile(
                        item: mkSummerItems[i],
                        onTap: () => onItemTap(mkSummerItems[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: Colors.white,
            shape: const StadiumBorder(side: BorderSide(color: MkColors.brand)),
            child: InkWell(
              onTap: onExploreAll,
              customBorder: const StadiumBorder(),
              child: SizedBox(
                height: 46,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Explore All $audience Summer Collections',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: MkColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.chevronRight,
                        size: 18, color: MkColors.ink),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AudienceSwitch extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  const _AudienceSwitch({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 39,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: const StadiumBorder(),
        shadows: _cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < mkSummerAudiences.length; i++)
            GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: i == selected
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF5D96A), Color(0xFFF7AA74)],
                        )
                      : null,
                ),
                child: Text(
                  mkSummerAudiences[i],
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight:
                        i == selected ? FontWeight.w500 : FontWeight.w400,
                    color: i == selected ? MkColors.ink : MkColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummerTile extends StatelessWidget {
  final MkSummerItem item;
  final VoidCallback onTap;
  const _SummerTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 101,
        height: 151,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: _cardShadow,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE57D), Color(0xFFF4AE17)],
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('$_asset/${item.image}.webp', fit: BoxFit.cover),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE57D),
                    borderRadius:
                        BorderRadius.only(bottomLeft: Radius.circular(6)),
                  ),
                  child: Text(
                    'UP TO 30% OFF',
                    style: GoogleFonts.roboto(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: MkColors.ink,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      height: 24,
                      color: Colors.black.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: Text(
                        item.label,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
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

// ─────────────────────────── Popular Services ───────────────────────────

class MkServicePromo {
  final String title;
  final String image;
  final int startingPrice;
  const MkServicePromo(this.title, this.image, this.startingPrice);
}

const mkPopularServices = <MkServicePromo>[
  MkServicePromo('Home Cleaning', 'svc_home_cleaning', 599),
  MkServicePromo('Electrician', 'svc_electrician', 599),
  MkServicePromo('Beauty & Salon', 'svc_beauty_salon', 599),
  MkServicePromo('Plumbing', 'svc_plumbing', 599),
  MkServicePromo('Photography', 'svc_photography', 599),
  MkServicePromo('Laptop / PC Repair', 'svc_laptop_repair', 599),
];

class MkPopularServices extends StatelessWidget {
  final ValueChanged<MkServicePromo> onTap;
  const MkPopularServices({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Popular Services', style: _sectionTitle()),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 256,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            clipBehavior: Clip.none,
            itemCount: mkPopularServices.length,
            separatorBuilder: (_, __) => const SizedBox(width: 17),
            itemBuilder: (context, i) => _ServiceCard(
              promo: mkPopularServices[i],
              onTap: () => onTap(mkPopularServices[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final MkServicePromo promo;
  final VoidCallback onTap;
  const _ServiceCard({required this.promo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final priceStyle = GoogleFonts.notoSans(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: MkColors.ink,
    );
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 156,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10.77),
              child: SizedBox(
                height: 220,
                width: 156,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('$_asset/${promo.image}.webp',
                        fit: BoxFit.cover),
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        height: 31,
                        color: MkColors.brand,
                        alignment: Alignment.center,
                        child: Text(
                          promo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sourceSans3(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 9,
              right: 8,
              top: 195,
              child: Container(
                height: 49,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10.77),
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5.4),
                    boxShadow: const [
                      BoxShadow(color: Color(0x59000000), blurRadius: 10),
                    ],
                  ),
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Start at '),
                      TextSpan(
                        text: '₹${promo.startingPrice}',
                        style: priceStyle.copyWith(color: MkColors.brand),
                      ),
                    ]),
                    style: priceStyle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Browse by lifestyle ───────────────────────────

class MkLifestyle {
  final String label;
  final String image;
  final Color background;
  final Color accent;
  const MkLifestyle(this.label, this.image, this.background, this.accent);
}

const mkLifestyles = <MkLifestyle>[
  MkLifestyle("For Men's", 'life_men', Color(0xFFA3D8F3), Color(0xFF0CAAFA)),
  MkLifestyle(
      "For Women's", 'life_women', Color(0xFFE09DD0), Color(0xFFFC1071)),
  MkLifestyle("For Kid's", 'life_kids', Color(0xFFF5D4C0), Color(0xFFFE7520)),
  MkLifestyle(
      "For Elder's", 'life_elders', Color(0xFFBEBAEF), Color(0xFF4336EA)),
];

class MkBrowseByLifestyle extends StatelessWidget {
  final ValueChanged<MkLifestyle> onTap;
  const MkBrowseByLifestyle({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Browse by lifestyle', style: _sectionTitle()),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 242,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            clipBehavior: Clip.none,
            itemCount: mkLifestyles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) => _LifestyleCard(
              data: mkLifestyles[i],
              onTap: () => onTap(mkLifestyles[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _LifestyleCard extends StatelessWidget {
  final MkLifestyle data;
  final VoidCallback onTap;
  const _LifestyleCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final white = GoogleFonts.roboto(color: Colors.white, height: 1.2);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 224,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ColoredBox(
            color: data.background,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('$_asset/${data.image}.webp', fit: BoxFit.cover),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    width: 36,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5.25),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFD0004),
                          Color(0xFFEE4245),
                          Color(0xFF970003),
                        ],
                        stops: [0, 0.51, 1],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('UP TO',
                            style: white.copyWith(
                                fontSize: 10, fontWeight: FontWeight.w500)),
                        Text('20%',
                            style: white.copyWith(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('OFF',
                            style: white.copyWith(
                                fontSize: 10, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 7,
                  bottom: 8,
                  child: Container(
                    height: 33,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.label,
                            style: GoogleFonts.sourceSans3(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: MkColors.ink,
                            ),
                          ),
                        ),
                        _ArrowDot(color: data.accent, size: 20),
                      ],
                    ),
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

// ─────────────────────────── Meet Our Creators ───────────────────────────

class MkMeetCreators extends StatelessWidget {
  final VoidCallback onExplore;
  const MkMeetCreators({super.key, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 175,
        decoration: BoxDecoration(
          color: const Color(0xFFAF9DEF),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: 1,
              bottom: 0,
              width: 162,
              height: 110,
              child: Image.asset('$_asset/creators_illustration.webp',
                  fit: BoxFit.contain),
            ),
            Positioned(
              left: 16,
              top: 24,
              width: 214,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meet Our Creators',
                    style: GoogleFonts.sourceSans3(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: MkColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Explore talented creators, shop their exclusive collections and book services directly from verified experts.',
                    maxLines: 3,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: MkColors.body,
                      height: 1.58,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MkPillButton(label: 'Explore', onTap: onExplore),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Listing tabs + chips ───────────────────────────

enum MkListingTab { newlyArrived, nearbyServices, under499, recentlyBrowsed }

class MkListingTabs extends StatelessWidget {
  final MkListingTab selected;
  final ValueChanged<MkListingTab> onSelected;
  final List<MkListingTab> tabs;
  const MkListingTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.tabs = const [
      MkListingTab.newlyArrived,
      MkListingTab.under499,
      MkListingTab.recentlyBrowsed,
    ],
  });

  static const _labels = {
    MkListingTab.newlyArrived: 'Newly Arrived',
    MkListingTab.nearbyServices: 'Nearby Services',
    MkListingTab.under499: 'Under ₹499',
    MkListingTab.recentlyBrowsed: 'Recently Browsed',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFB7B7B7))),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final tab in tabs)
                InkWell(
                  onTap: () => onSelected(tab),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 4,
                          color: tab == selected
                              ? const Color(0xFFFA3F5E)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Text(
                      _labels[tab]!,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight:
                            tab == selected ? FontWeight.w500 : FontWeight.w400,
                        color: tab == selected ? MkColors.ink : MkColors.muted,
                      ),
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

class MkFilterChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  const MkFilterChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool isSelected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: isSelected
                ? const Color(0xFFFA3F5E).withValues(alpha: 0.25)
                : Colors.white,
            shape: StadiumBorder(
              side: BorderSide(
                color: isSelected ? MkColors.brand : const Color(0xFF3B3B3B),
              ),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              color: MkColors.ink,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('All', selected == null, () => onSelected(null)),
          for (final c in categories) ...[
            const SizedBox(width: 10),
            chip(c, selected == c, () => onSelected(c)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Product card ───────────────────────────

class MkProductGrid extends StatelessWidget {
  final List<StoreMockCatalogItem> items;
  final String? ownerUserId;
  const MkProductGrid({super.key, required this.items, this.ownerUserId});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: MkProductCard(item: items[i], ownerUserId: ownerUserId)),
            const SizedBox(width: 16),
            Expanded(
              child: i + 1 < items.length
                  ? MkProductCard(item: items[i + 1], ownerUserId: ownerUserId)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ));
      if (i + 2 < items.length) rows.add(const SizedBox(height: 28));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: rows),
    );
  }
}

/// Listing ids the user opened this session, most recent first. Backs the
/// "Recently Browsed" tab.
final ValueNotifier<List<String>> mkRecentlyViewed = ValueNotifier(const []);

void _markViewed(String id) {
  final next = [id, ...mkRecentlyViewed.value.where((e) => e != id)];
  mkRecentlyViewed.value = next.take(20).toList();
}

class MkProductCard extends StatelessWidget {
  final StoreMockCatalogItem item;
  final String? ownerUserId;
  const MkProductCard({super.key, required this.item, this.ownerUserId});

  bool get _isService => item.type == StoreMockItemType.service;

  void _openDetail(BuildContext context) {
    _markViewed(item.id);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _isService
          ? VisitorServiceDetailPage(ownerUserId: ownerUserId, item: item)
          : VisitorProductDetailPage(
              ownerUserId: ownerUserId,
              product: VisitorProductDetailData(item: item),
            ),
    ));
  }

  static String? _sellerName(Map<String, dynamic> raw) {
    for (final key in const [
      'user_id',
      'influencer',
      'seller',
      'owner',
      'user',
      'creator',
      'vendor'
    ]) {
      final v = raw[key];
      if (v is Map) {
        for (final k in const [
          'full_name',
          'fullName',
          'name',
          'username',
          'store_name'
        ]) {
          final s = v[k]?.toString().trim() ?? '';
          if (s.isNotEmpty) return s;
        }
      }
    }
    for (final key in const [
      'store_name',
      'seller_name',
      'influencer_name',
      'creator_name'
    ]) {
      final s = raw[key]?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static String? _sellerAvatar(Map<String, dynamic> raw) {
    for (final key in const [
      'user_id',
      'influencer',
      'seller',
      'owner',
      'user',
      'creator',
      'vendor'
    ]) {
      final v = raw[key];
      if (v is Map) {
        for (final k in const [
          'avatar_url',
          'avatarUrl',
          'profile_picture',
          'avatar'
        ]) {
          final s = v[k]?.toString().trim() ?? '';
          if (s.startsWith('http')) return s;
        }
      }
    }
    return null;
  }

  static double _mrp(Map<String, dynamic> raw) {
    for (final key in const ['mrp', 'compare_at_price', 'original_price']) {
      final v = raw[key];
      final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
      if (n != null && n > 0) return n;
    }
    return 0;
  }

  static bool _isNew(Map<String, dynamic> raw) {
    final created =
        DateTime.tryParse('${raw['created_at'] ?? raw['createdAt'] ?? ''}');
    if (created == null) return false;
    return DateTime.now().difference(created).inDays <= 30;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreMockState.instance;
    final stock = _isService ? null : store.stockQuantityFor(item);
    final inStock = stock == null || stock > 0;
    final seller = _sellerName(item.raw);
    final avatar = _sellerAvatar(item.raw);
    final mrp = _mrp(item.raw);
    final discount = mrp > item.price && item.price > 0
        ? ((1 - item.price / mrp) * 100).round()
        : 0;
    final rating = double.tryParse(item.rating);

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC8C8C8), width: 0.5),
          boxShadow: _cardShadow,
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Color(0xA6FA3F5E)],
              stops: [0, 0.86, 1],
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 112,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: StoreItemImage(
                          imageUrl: item.imageUrl,
                          icon: item.icon,
                          fit: BoxFit.cover,
                          debugLabel: 'mk-product-card',
                        ),
                      ),
                      if (!_isService)
                        Positioned(
                          left: 5,
                          top: 5,
                          child: _Tag(
                            label: inStock ? 'In stock' : 'Out of stock',
                            background: inStock
                                ? const Color(0xFFB5FAC7)
                                : const Color(0xFFFFD6DC),
                            foreground: inStock
                                ? const Color(0xFF024213)
                                : const Color(0xFF8A0017),
                            fontSize: 8.2,
                          ),
                        ),
                      if (!_isService)
                        Positioned(
                          right: 5,
                          top: 5,
                          child: WishlistHeartButton(
                            productId: item.id,
                            size: 23,
                            iconSize: 12,
                          ),
                        ),
                      if (rating != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(6),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 13, color: Color(0xFFFEAC38)),
                                const SizedBox(width: 2),
                                Text(
                                  '${rating.toStringAsFixed(1)} (${item.reviews})',
                                  style: GoogleFonts.roboto(
                                      fontSize: 10, color: MkColors.ink),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (seller != null) ...[
                        Row(
                          children: [
                            ClipOval(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: avatar == null
                                    ? ColoredBox(
                                        color: const Color(0xFF1B1F4A),
                                        child: Center(
                                          child: Text(
                                            seller.characters.first
                                                .toUpperCase(),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      )
                                    : StoreItemImage(
                                        imageUrl: avatar,
                                        icon: LucideIcons.user,
                                        fit: BoxFit.cover,
                                        debugLabel: 'mk-seller-avatar',
                                      ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'By $seller',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                    fontSize: 12, color: MkColors.ink),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: const Color(0xFF2E2E2E),
                          height: 1.42,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 7,
                        runSpacing: 4,
                        children: [
                          _Tag(
                            label: item.category,
                            icon: item.icon,
                            background: Colors.black,
                            foreground: Colors.white,
                          ),
                          if (_isNew(item.raw))
                            const _Tag(
                              label: 'New',
                              background: Color(0xFFF4D779),
                              foreground: Color(0xFF553F02),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Flexible(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: _isService
                                      ? 'From ${formatStoreMoney(item.price)}'
                                      : formatStoreMoney(item.price),
                                  style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: MkColors.ink,
                                  ),
                                ),
                                if (discount > 0)
                                  TextSpan(
                                    text: ' ${formatStoreMoney(mrp)}',
                                    style: GoogleFonts.roboto(
                                      fontSize: 12,
                                      color: const Color(0xFF555555),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (discount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4.7),
                                border:
                                    Border.all(color: const Color(0xFF00BC32)),
                              ),
                              child: Text(
                                '$discount% OFF',
                                style: GoogleFonts.manrope(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF00BC32),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: _isService
                      ? _AddButton(
                          label: 'Book',
                          onTap: () => _openDetail(context),
                        )
                      : _CartButton(item: item, enabled: inStock),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final double fontSize;

  const _Tag({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: foreground),
            const SizedBox(width: 3),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: foreground,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: enabled
            ? const [BoxShadow(color: Color(0x96FA3F5E), blurRadius: 8)]
            : null,
      ),
      child: Material(
        color: enabled ? MkColors.brand : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: enabled ? Colors.white : const Color(0xFF8A8A8A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final StoreMockCatalogItem item;
  final bool enabled;
  const _CartButton({required this.item, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StoreMockState.instance,
      builder: (context, _) {
        final store = StoreMockState.instance;
        final quantity = store.quantityFor(item.id);
        final max = store.maxQuantityFor(item);
        if (quantity == 0) {
          return _AddButton(
            label: enabled ? 'Add' : 'Sold out',
            onTap: enabled && max > 0 ? () => store.addToCart(item) : null,
          );
        }
        final textStyle = GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        );
        Widget control(IconData icon, VoidCallback? onTap) => SizedBox(
              width: 40,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Icon(icon,
                    size: 16,
                    color: onTap == null ? Colors.white54 : Colors.white),
              ),
            );
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: MkColors.brand,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(color: Color(0x96FA3F5E), blurRadius: 8),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Row(
              children: [
                control(LucideIcons.minus,
                    () => store.updateQuantity(item.id, quantity - 1)),
                Expanded(
                  child: Text('$quantity',
                      textAlign: TextAlign.center, style: textStyle),
                ),
                control(
                  LucideIcons.plus,
                  quantity >= max
                      ? null
                      : () => store.updateQuantity(item.id, quantity + 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
