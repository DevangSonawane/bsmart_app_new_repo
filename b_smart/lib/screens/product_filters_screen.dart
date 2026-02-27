import 'package:flutter/material.dart';
import '../models/promoted_product_model.dart';
import '../services/promoted_products_service.dart';
import '../theme/instagram_theme.dart';

class ProductFiltersScreen extends StatefulWidget {
  final ProductFilter? initialFilter;

  const ProductFiltersScreen({
    super.key,
    this.initialFilter,
  });

  @override
  State<ProductFiltersScreen> createState() => _ProductFiltersScreenState();
}

class _ProductFiltersScreenState extends State<ProductFiltersScreen> {
  final PromotedProductsService _productsService = PromotedProductsService();
  
  String? _selectedCategory;
  String? _selectedBrand;
  double? _minPrice;
  double? _maxPrice;
  bool _trendingOnly = false;
  bool _newArrivalsOnly = false;
  String? _offerType;

  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedCategory = widget.initialFilter!.category;
      _selectedBrand = widget.initialFilter!.brand;
      _minPrice = widget.initialFilter!.minPrice;
      _maxPrice = widget.initialFilter!.maxPrice;
      _trendingOnly = widget.initialFilter!.trendingOnly ?? false;
      _newArrivalsOnly = widget.initialFilter!.newArrivalsOnly ?? false;
      _offerType = widget.initialFilter!.offerType;
      
      if (_minPrice != null) {
        _minPriceController.text = _minPrice!.toStringAsFixed(2);
      }
      if (_maxPrice != null) {
        _maxPriceController.text = _maxPrice!.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final filter = ProductFilter(
      category: _selectedCategory,
      brand: _selectedBrand,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      trendingOnly: _trendingOnly,
      newArrivalsOnly: _newArrivalsOnly,
      offerType: _offerType,
    );

    Navigator.of(context).pop(filter);
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedBrand = null;
      _minPrice = null;
      _maxPrice = null;
      _trendingOnly = false;
      _newArrivalsOnly = false;
      _offerType = null;
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = _productsService.getCategories();
    final companies = _productsService.getCompanies();

    return Scaffold(
      backgroundColor: InstagramTheme.backgroundWhite,
      appBar: AppBar(
        title: const Text('Filters'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
        actions: [
          TextButton(
            onPressed: _clearFilters,
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                final isSelected = _selectedCategory == category.id;
                return FilterChip(
                  label: Text(category.name, style: const TextStyle(color: Colors.black87)),
                  selected: isSelected,
                  selectedColor: Colors.blue,
                  backgroundColor: Colors.white,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? category.id : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Brand
            const Text(
              'Brand',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: companies.map((company) {
                final isSelected = _selectedBrand == company.name;
                return FilterChip(
                  label: Text(company.name, style: const TextStyle(color: Colors.black87)),
                  selected: isSelected,
                  selectedColor: Colors.blue,
                  backgroundColor: Colors.white,
                  onSelected: (selected) {
                    setState(() {
                      _selectedBrand = selected ? company.name : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Price Range
            const Text(
              'Price Range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Min Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _minPrice = double.tryParse(value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Max Price',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _maxPrice = double.tryParse(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Options
            const Text(
              'Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Trending Only', style: TextStyle(color: Colors.black87)),
              value: _trendingOnly,
              onChanged: (value) {
                setState(() {
                  _trendingOnly = value ?? false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('New Arrivals Only', style: TextStyle(color: Colors.black87)),
              value: _newArrivalsOnly,
              onChanged: (value) {
                setState(() {
                  _newArrivalsOnly = value ?? false;
                });
              },
            ),
            const SizedBox(height: 16),

            // Offer Type
            const Text(
              'Offers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('With Discount', style: TextStyle(color: Colors.black87)),
                  selected: _offerType == 'discount',
                  selectedColor: Colors.blue,
                  backgroundColor: Colors.white,
                  onSelected: (selected) {
                    setState(() {
                      _offerType = selected ? 'discount' : null;
                    });
                  },
                ),
                FilterChip(
                  label: const Text('New Arrivals', style: TextStyle(color: Colors.black87)),
                  selected: _offerType == 'new',
                  selectedColor: Colors.blue,
                  backgroundColor: Colors.white,
                  onSelected: (selected) {
                    setState(() {
                      _offerType = selected ? 'new' : null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
