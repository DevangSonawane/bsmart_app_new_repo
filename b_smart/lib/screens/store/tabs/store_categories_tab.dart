import 'package:flutter/material.dart';

import '../store_theme.dart';

class StoreCategoriesTab extends StatefulWidget {
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenCamera;

  const StoreCategoriesTab({
    super.key,
    required this.onOpenSearch,
    required this.onOpenCamera,
  });

  @override
  State<StoreCategoriesTab> createState() => _StoreCategoriesTabState();
}

class _StoreCategoriesTabState extends State<StoreCategoriesTab> {
  int _selectedRailIndex = 0;

  static const _railItems = [
    _CategoryRailItem('For You', Icons.recommend_rounded),
    _CategoryRailItem('Grocery', Icons.local_grocery_store_outlined),
    _CategoryRailItem('Fashion', Icons.checkroom_outlined),
    _CategoryRailItem('Mobiles', Icons.phone_android_outlined),
    _CategoryRailItem('Appliances', Icons.kitchen_outlined),
    _CategoryRailItem('Electronics', Icons.devices_other_outlined),
    _CategoryRailItem('Smart Gadgets', Icons.watch_outlined),
    _CategoryRailItem('Home', Icons.chair_outlined),
    _CategoryRailItem('Beauty', Icons.spa_outlined),
  ];

  static const _popularStores = [
    _CategoryProduct(
      'Value 365',
      Icons.discount_rounded,
      Color(0xFFFFEEF0),
      Color(0xFFDB2F43),
    ),
    _CategoryProduct(
      'Sale is Live',
      Icons.local_fire_department_rounded,
      Color(0xFFFFF5C8),
      Color(0xFFFF9D00),
    ),
    _CategoryProduct(
      'Festival Sale',
      Icons.celebration_rounded,
      Color(0xFFFFEAF1),
      Color(0xFFE1507A),
    ),
    _CategoryProduct(
      'Sneakers',
      Icons.directions_run_rounded,
      Color(0xFFE9F3FF),
      Color(0xFF326BC8),
      badge: 'RECENT DROP',
    ),
    _CategoryProduct(
      'Trains Launched!',
      Icons.train_rounded,
      Color(0xFFEAF7FF),
      Color(0xFF2784B8),
    ),
    _CategoryProduct(
      'Grocery',
      Icons.shopping_basket_rounded,
      Color(0xFFFFF0D9),
      Color(0xFFE08D22),
    ),
  ];

  static const _launches = [
    _CategoryProduct(
      'vivo T5 5G',
      Icons.phone_iphone_rounded,
      Color(0xFFEFF6FF),
      Color(0xFF8DA6B9),
      badge: 'NOTIFY ME',
      imageAsset: 'assets/bSmart_Store/mobilephone/images.jpeg',
    ),
    _CategoryProduct(
      'boltt ACE 5G',
      Icons.watch_rounded,
      Color(0xFFF3EAFD),
      Color(0xFF76489E),
      badge: 'NOTIFY ME',
      imageAsset: 'assets/bSmart_Store/mobilephone/images (1).jpeg',
    ),
    _CategoryProduct(
      'boltt EVO',
      Icons.smartphone_rounded,
      Color(0xFFEAF4FF),
      Color(0xFF3D79BD),
      badge: 'NOTIFY ME',
      imageAsset: 'assets/bSmart_Store/mobilephone/images (2).jpeg',
    ),
    _CategoryProduct(
      'POCO M8x 5G',
      Icons.phone_android_rounded,
      Color(0xFFEAF7EF),
      Color(0xFF56956E),
      badge: 'BUY NOW',
      imageAsset: 'assets/bSmart_Store/mobilephone/shopping.webp',
    ),
    _CategoryProduct(
      'Lava Virat V1 5G',
      Icons.phone_iphone_rounded,
      Color(0xFFEDEFFF),
      Color(0xFF6670B7),
      badge: 'BUY NOW',
      imageAsset: 'assets/bSmart_Store/mobilephone/download.webp',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRail(),
              Expanded(child: _buildCategoryContent()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        MediaQuery.of(context).padding.top + 10,
        12,
        8,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'All Categories',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
          _HeaderAction(
            icon: Icons.search_rounded,
            onTap: widget.onOpenSearch,
          ),
          const SizedBox(width: 12),
          _HeaderAction(
            icon: Icons.camera_alt_rounded,
            onTap: widget.onOpenCamera,
          ),
          const SizedBox(width: 12),
          const _CartAction(),
        ],
      ),
    );
  }

  Widget _buildRail() {
    return Container(
      width: 72,
      color: const Color(0xFFF4F6FA),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 5, bottom: 10),
        itemCount: _railItems.length,
        itemBuilder: (context, index) {
          final item = _railItems[index];
          final selected = index == _selectedRailIndex;
          return InkWell(
            onTap: () => setState(() => _selectedRailIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              height: 68,
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xFFF4F6FA),
                border: Border(
                  left: BorderSide(
                    color: selected ? StorePalette.blue : Colors.transparent,
                    width: 4,
                  ),
                  bottom: BorderSide(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFEAF1FF)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        color: selected
                            ? StorePalette.blue
                            : const Color(0xFF63708A),
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected
                            ? StorePalette.blue
                            : const Color(0xFF6B7892),
                        fontSize: 9,
                        height: 1.05,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 18),
      children: const [
        _CategorySection(
          title: 'Popular Store',
          products: _popularStores,
        ),
        SizedBox(height: 10),
        _CategorySection(
          title: 'New & Upcoming Launches',
          products: _launches,
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final List<_CategoryProduct> products;

  const _CategorySection({
    required this.title,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 5),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) {
            return _CategoryProductTile(product: products[index]);
          },
        ),
      ],
    );
  }
}

class _CategoryProductTile extends StatelessWidget {
  final _CategoryProduct product;

  const _CategoryProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: product.background,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: product.imageAsset == null
                    ? Center(
                        child: Icon(
                          product.icon,
                          color: product.iconColor,
                          size: 30,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          product.imageAsset!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            product.icon,
                            color: product.iconColor,
                            size: 30,
                          ),
                        ),
                      ),
              ),
              if (product.badge != null)
                Positioned(
                  bottom: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF008C84),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      product.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: product.badge == null ? 5 : 10),
        Text(
          product.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 10.5,
            height: 1.08,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(icon, color: Colors.black, size: 22),
      ),
    );
  }
}

class _CartAction extends StatelessWidget {
  const _CartAction();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Padding(
          padding: EdgeInsets.all(3),
          child:
              Icon(Icons.shopping_cart_rounded, color: Colors.black, size: 22),
        ),
        Positioned(
          right: -3,
          top: -3,
          child: Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFF314A),
              shape: BoxShape.circle,
            ),
            child: const Text(
              '1',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryRailItem {
  final String label;
  final IconData icon;

  const _CategoryRailItem(this.label, this.icon);
}

class _CategoryProduct {
  final String title;
  final IconData icon;
  final Color background;
  final Color iconColor;
  final String? badge;
  final String? imageAsset;

  const _CategoryProduct(
    this.title,
    this.icon,
    this.background,
    this.iconColor, {
    this.badge,
    this.imageAsset,
  });
}
