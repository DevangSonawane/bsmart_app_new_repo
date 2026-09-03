import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../store_models.dart';
import '../store_theme.dart';

class StoreHomeTab extends StatelessWidget {
  final TextEditingController searchController;
  final List<StoreCategory> categories;
  final List<StoreProduct> products;
  final int selectedCategory;
  final bool speechListening;
  final ValueChanged<int> onCategorySelected;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenCamera;
  final VoidCallback onToggleSpeech;
  final VoidCallback onOpenQrScanner;
  final VoidCallback onOpenMainApp;

  const StoreHomeTab({
    super.key,
    required this.searchController,
    required this.categories,
    required this.products,
    required this.selectedCategory,
    required this.speechListening,
    required this.onCategorySelected,
    required this.onOpenSearch,
    required this.onOpenCamera,
    required this.onToggleSpeech,
    required this.onOpenQrScanner,
    required this.onOpenMainApp,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: buildSlivers(context));
  }

  List<Widget> buildSlivers(BuildContext context) {
    return [
      SliverToBoxAdapter(child: _buildTopBar(context)),
      SliverToBoxAdapter(child: _buildSearch()),
      SliverToBoxAdapter(child: _buildCategories()),
      SliverToBoxAdapter(child: _buildHeroBanner()),
      SliverToBoxAdapter(child: _buildRecommendations()),
      SliverToBoxAdapter(child: _buildFeatureBanner()),
    ];
  }

  Widget _buildTopBar(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: DesignTokens.instaGradient),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, StorePalette.paleBlue],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              MediaQuery.of(context).padding.top + 10,
              14,
              12,
            ),
            child: Column(
              children: [
                _buildExperienceSwitcher(),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBFE3FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.home_rounded, color: Colors.black87, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'HOME  A-404, Shri Krishna Kunj CH...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.black87, size: 18),
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

  Widget _buildExperienceSwitcher() {
    return Row(
      children: [
        Expanded(
          child: _experienceLogoCard(
            imageAsset: 'assets/bSmart_Store/bstore.png',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _experienceLogoCard(
            imageAsset: 'assets/bSmart_Store/bsmart.png',
            padding: EdgeInsets.zero,
            fit: BoxFit.cover,
            onTap: onOpenMainApp,
          ),
        ),
      ],
    );
  }

  Widget _experienceLogoCard({
    required String imageAsset,
    required VoidCallback onTap,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    BoxFit fit = BoxFit.contain,
  }) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: padding,
              child: Image.asset(
                imageAsset,
                width: double.infinity,
                height: double.infinity,
                fit: fit,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text(
                    'App',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: StorePalette.paleBlue,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: StorePalette.blue, width: 2),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded,
                      color: Colors.black87, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      readOnly: true,
                      onTap: onOpenSearch,
                      maxLines: 1,
                      cursorColor: StorePalette.blue,
                      decoration: const InputDecoration(
                        hintText: 'Search products',
                        hintStyle:
                            TextStyle(color: Colors.black54, fontSize: 14),
                        filled: true,
                        fillColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style:
                          const TextStyle(color: Colors.black87, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    onPressed: onOpenCamera,
                    icon: const Icon(Icons.camera_alt_outlined,
                        color: Colors.black54, size: 20),
                    tooltip: 'Open camera',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 9),
                  IconButton(
                    onPressed: onToggleSpeech,
                    icon: Icon(
                      speechListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color:
                          speechListening ? StorePalette.blue : Colors.black54,
                      size: 20,
                    ),
                    tooltip: 'Voice search',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onOpenQrScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.black54, size: 26),
            tooltip: 'Scan QR code',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return Container(
      height: 88,
      color: StorePalette.paleBlue,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = index == selectedCategory;
          return GestureDetector(
            onTap: () => onCategorySelected(index),
            child: SizedBox(
              width: 62,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFD8EEFF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(category.icon, color: Colors.black87, size: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 3,
                    width: selected ? 48 : 0,
                    decoration: BoxDecoration(
                      color: StorePalette.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/bSmart_Store/banner.png',
          height: 148,
          width: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }

  Widget _buildRecommendations() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Picked for you',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 174,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final product = products[index];
                return Container(
                  width: 132,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ColoredBox(
                            color: product.color,
                            child: Image.asset(
                              product.imageAsset,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.local_mall_rounded,
                                size: 42,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54),
                      ),
                      Text(
                        product.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
      child: Container(
        height: 104,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE4F6C7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Text(
                'Make room for\nbetter living',
                style: TextStyle(
                  fontSize: 19,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(Icons.weekend_rounded, size: 58, color: Color(0xFF4F8B3A)),
          ],
        ),
      ),
    );
  }
}
