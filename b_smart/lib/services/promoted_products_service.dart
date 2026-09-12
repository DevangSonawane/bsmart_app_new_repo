import '../models/promoted_product_model.dart';

class PromotedProductsService {
  static final PromotedProductsService _instance =
      PromotedProductsService._internal();
  factory PromotedProductsService() => _instance;

  List<PromotedProduct> _products = [];
  List<CompanyDetail> _companies = [];
  List<ProductCategory> _categories = [];

  PromotedProductsService._internal() {
    _initializeData();
  }

  void _initializeData() {
    // Categories
    _categories = [
      ProductCategory(id: 'all', name: 'All', productCount: 0),
      ProductCategory(id: 'fashion', name: 'Fashion', productCount: 0),
      ProductCategory(id: 'beauty', name: 'Beauty', productCount: 0),
      ProductCategory(id: 'electronics', name: 'Electronics', productCount: 0),
      ProductCategory(id: 'fitness', name: 'Fitness', productCount: 0),
      ProductCategory(id: 'home', name: 'Home & Living', productCount: 0),
    ];

    _companies = const <CompanyDetail>[];
    _products = const <PromotedProduct>[];

    // Update category counts
    for (final category in _categories) {
      if (category.id != 'all') {
        final count = _products.where((p) => p.category == category.id).length;
        _categories[_categories.indexWhere((c) => c.id == category.id)] =
            category.copyWith(productCount: count);
      }
    }
  }

  List<PromotedProduct> getProducts({ProductFilter? filter}) {
    var products = List<PromotedProduct>.from(_products);

    if (filter == null || !filter.hasFilters) {
      return products;
    }

    // Apply filters
    if (filter.category != null && filter.category != 'all') {
      products = products.where((p) => p.category == filter.category).toList();
    }

    if (filter.brand != null) {
      products = products.where((p) => p.companyName == filter.brand).toList();
    }

    if (filter.minPrice != null) {
      products = products
          .where((p) => p.price != null && p.price! >= filter.minPrice!)
          .toList();
    }

    if (filter.maxPrice != null) {
      products = products
          .where((p) => p.price != null && p.price! <= filter.maxPrice!)
          .toList();
    }

    if (filter.trendingOnly == true) {
      products = products.where((p) => p.isTrending).toList();
    }

    if (filter.newArrivalsOnly == true) {
      products = products.where((p) => p.isNewArrival).toList();
    }

    if (filter.offerType != null) {
      if (filter.offerType == 'discount') {
        products = products
            .where((p) =>
                p.discountPercentage != null && p.discountPercentage! > 0)
            .toList();
      } else if (filter.offerType == 'new') {
        products = products.where((p) => p.isNewArrival).toList();
      }
    }

    return products;
  }

  PromotedProduct? getProductById(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  List<PromotedProduct> getProductsByCompany(String companyId) {
    return _products.where((p) => p.companyId == companyId).toList();
  }

  List<PromotedProduct> getProductsByCategory(String categoryId) {
    if (categoryId == 'all') {
      return List<PromotedProduct>.from(_products);
    }
    return _products.where((p) => p.category == categoryId).toList();
  }

  List<CompanyDetail> getCompanies() {
    return List<CompanyDetail>.from(_companies);
  }

  CompanyDetail? getCompanyById(String companyId) {
    try {
      return _companies.firstWhere((c) => c.id == companyId);
    } catch (e) {
      return null;
    }
  }

  List<ProductCategory> getCategories() {
    return List<ProductCategory>.from(_categories);
  }

  void incrementProductViews(String productId) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final product = _products[index];
      _products[index] = PromotedProduct(
        id: product.id,
        name: product.name,
        description: product.description,
        imageUrl: product.imageUrl,
        price: product.price,
        currency: product.currency,
        originalPrice: product.originalPrice,
        discountPercentage: product.discountPercentage,
        offerBadge: product.offerBadge,
        companyId: product.companyId,
        companyName: product.companyName,
        companyLogoUrl: product.companyLogoUrl,
        category: product.category,
        tags: product.tags,
        externalUrl: product.externalUrl,
        isTrending: product.isTrending,
        isNewArrival: product.isNewArrival,
        createdAt: product.createdAt,
        views: product.views + 1,
        clicks: product.clicks,
      );
    }
  }

  void incrementProductClicks(String productId) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final product = _products[index];
      _products[index] = PromotedProduct(
        id: product.id,
        name: product.name,
        description: product.description,
        imageUrl: product.imageUrl,
        price: product.price,
        currency: product.currency,
        originalPrice: product.originalPrice,
        discountPercentage: product.discountPercentage,
        offerBadge: product.offerBadge,
        companyId: product.companyId,
        companyName: product.companyName,
        companyLogoUrl: product.companyLogoUrl,
        category: product.category,
        tags: product.tags,
        externalUrl: product.externalUrl,
        isTrending: product.isTrending,
        isNewArrival: product.isNewArrival,
        createdAt: product.createdAt,
        views: product.views,
        clicks: product.clicks + 1,
      );
    }
  }
}

extension ProductCategoryExtension on ProductCategory {
  ProductCategory copyWith({int? productCount}) {
    return ProductCategory(
      id: id,
      name: name,
      icon: icon,
      productCount: productCount ?? this.productCount,
    );
  }
}
