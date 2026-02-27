import 'package:flutter/material.dart';
import '../models/promoted_product_model.dart';
import '../services/promoted_products_service.dart';
import '../theme/instagram_theme.dart';
import '../widgets/clay_container.dart';
import 'product_detail_screen.dart';
import 'company_detail_screen.dart';
import 'product_filters_screen.dart';

class PromotedProductsScreen extends StatefulWidget {
  const PromotedProductsScreen({super.key});

  @override
  State<PromotedProductsScreen> createState() => _PromotedProductsScreenState();
}

class _PromotedProductsScreenState extends State<PromotedProductsScreen> {
  final PromotedProductsService _productsService = PromotedProductsService();
  List<PromotedProduct> _products = [];
  List<ProductCategory> _categories = [];
  String _selectedCategoryId = 'all';
  ProductFilter? _activeFilter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _isLoading = true;
    });

    _categories = _productsService.getCategories();
    _products = _productsService.getProducts(filter: _activeFilter);

    setState(() {
      _isLoading = false;
    });
  }

  void _onCategorySelected(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _activeFilter = ProductFilter(
        category: categoryId == 'all' ? null : categoryId,
        brand: _activeFilter?.brand,
        minPrice: _activeFilter?.minPrice,
        maxPrice: _activeFilter?.maxPrice,
        trendingOnly: _activeFilter?.trendingOnly,
        newArrivalsOnly: _activeFilter?.newArrivalsOnly,
        offerType: _activeFilter?.offerType,
      );
    });
    _loadData();
  }

  Future<void> _openFilters() async {
    final filter = await Navigator.of(context).push<ProductFilter>(
      MaterialPageRoute(
        builder: (context) => ProductFiltersScreen(initialFilter: _activeFilter),
      ),
    );

    if (filter != null) {
      setState(() {
        _activeFilter = filter;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InstagramTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Promoted Products'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilters,
            tooltip: 'Filters',
          ),
          if (_activeFilter != null && _activeFilter!.hasFilters)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _activeFilter = null;
                  _selectedCategoryId = 'all';
                });
                _loadData();
              },
              tooltip: 'Clear filters',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(InstagramTheme.primaryPink),
              ),
            )
          : Column(
              children: [
                // Category Chips
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedCategoryId == category.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _onCategorySelected(category.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? InstagramTheme.primaryPink : InstagramTheme.surfaceWhite,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? InstagramTheme.primaryPink : InstagramTheme.borderGrey,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${category.name} (${category.productCount})',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isSelected ? InstagramTheme.backgroundWhite : InstagramTheme.textBlack,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  fontSize: 12,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Products Grid
                Expanded(
                  child: _products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 64,
                                color: InstagramTheme.textGrey.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No products found',
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _activeFilter = null;
                                    _selectedCategoryId = 'all';
                                  });
                                  _loadData();
                                },
                                child: const Text('Clear filters'),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            return _buildProductCard(product);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildProductCard(PromotedProduct product) {
    return ClayContainer(
      borderRadius: 20,
      color: InstagramTheme.surfaceWhite,
      onTap: () {
        _productsService.incrementProductViews(product.id);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(productId: product.id),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    color: InstagramTheme.dividerGrey,
                    child: product.imageUrl != null
                        ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                        : Icon(
                            Icons.shopping_bag,
                            size: 56,
                            color: InstagramTheme.textGrey.withValues(alpha: 0.7),
                          ),
                  ),
                ),
                if (product.offerBadge != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: InstagramTheme.errorRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        product.offerBadge!,
                        style: const TextStyle(
                          color: InstagramTheme.textBlack,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CompanyDetailScreen(companyId: product.companyId),
                        ),
                      );
                    },
                    child: ClayContainer(
                      borderRadius: 12,
                      color: InstagramTheme.surfaceWhite.withValues(alpha: 0.9),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (product.companyLogoUrl != null)
                              Image.network(product.companyLogoUrl!, width: 16, height: 16)
                            else
                              const Icon(Icons.business, size: 16, color: InstagramTheme.primaryPink),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 90),
                              child: Text(
                                product.companyName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: InstagramTheme.textBlack,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (product.price != null) ...[
                      Text(
                        '${product.currency ?? '\$'}${product.price!.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: InstagramTheme.primaryPink,
                          fontSize: 14,
                        ),
                      ),
                      if (product.originalPrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${product.currency ?? '\$'}${product.originalPrice!.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ] else
                      Text(
                        'Price on request',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                if (product.isTrending || product.isNewArrival) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (product.isTrending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: InstagramTheme.primaryPink.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: InstagramTheme.primaryPink.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            'Trending',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: InstagramTheme.primaryPink,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (product.isNewArrival)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: InstagramTheme.textBlack.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: InstagramTheme.textBlack.withValues(alpha: 0.12)),
                          ),
                          child: Text(
                            'New',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: InstagramTheme.textBlack,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
