import '../models/promoted_product_model.dart';

class PromotedProductsService {
  static final PromotedProductsService _instance = PromotedProductsService._internal();
  factory PromotedProductsService() => _instance;

  List<PromotedProduct> _products = [];
  List<CompanyDetail> _companies = [];
  List<ProductCategory> _categories = [];

  PromotedProductsService._internal() {
    _initializeData();
  }

  void _initializeData() {
    final now = DateTime.now();

    // Categories
    _categories = [
      ProductCategory(id: 'all', name: 'All', productCount: 0),
      ProductCategory(id: 'fashion', name: 'Fashion', productCount: 15),
      ProductCategory(id: 'beauty', name: 'Beauty', productCount: 12),
      ProductCategory(id: 'electronics', name: 'Electronics', productCount: 8),
      ProductCategory(id: 'fitness', name: 'Fitness', productCount: 10),
      ProductCategory(id: 'home', name: 'Home & Living', productCount: 6),
    ];

    // Companies
    _companies = [
      CompanyDetail(
        id: 'company-1',
        name: 'TechBrand',
        logoUrl: null,
        description: 'Leading technology products and accessories',
        website: 'https://techbrand.com',
        isVerified: true,
        followers: 125000,
        categories: ['electronics', 'fitness'],
        joinedDate: now.subtract(const Duration(days: 365)),
      ),
      CompanyDetail(
        id: 'company-2',
        name: 'FashionHub',
        logoUrl: null,
        description: 'Trendy fashion and lifestyle products',
        website: 'https://fashionhub.com',
        isVerified: true,
        followers: 89000,
        categories: ['fashion', 'beauty'],
        joinedDate: now.subtract(const Duration(days: 180)),
      ),
      CompanyDetail(
        id: 'company-3',
        name: 'BeautyGlow',
        logoUrl: null,
        description: 'Premium beauty and skincare products',
        website: 'https://beautyglow.com',
        isVerified: false,
        followers: 45000,
        categories: ['beauty'],
        joinedDate: now.subtract(const Duration(days: 90)),
      ),
    ];

    // Products
    _products = [
      PromotedProduct(
        id: 'product-1',
        name: 'Smart Watch Pro',
        description: 'Advanced fitness tracking smartwatch',
        imageUrl: null,
        price: 199.99,
        currency: 'USD',
        originalPrice: 299.99,
        discountPercentage: 33.3,
        offerBadge: '33% OFF',
        companyId: 'company-1',
        companyName: 'TechBrand',
        companyLogoUrl: null,
        category: 'electronics',
        tags: ['smartwatch', 'fitness', 'tech'],
        externalUrl: 'https://techbrand.com/products/smart-watch-pro',
        isTrending: true,
        isNewArrival: false,
        createdAt: now.subtract(const Duration(days: 5)),
        views: 15000,
        clicks: 450,
      ),
      PromotedProduct(
        id: 'product-2',
        name: 'Wireless Earbuds',
        description: 'Premium noise-cancelling earbuds',
        imageUrl: null,
        price: 79.99,
        currency: 'USD',
        originalPrice: 99.99,
        discountPercentage: 20.0,
        offerBadge: '20% OFF',
        companyId: 'company-1',
        companyName: 'TechBrand',
        companyLogoUrl: null,
        category: 'electronics',
        tags: ['audio', 'wireless', 'tech'],
        externalUrl: 'https://techbrand.com/products/wireless-earbuds',
        isTrending: true,
        isNewArrival: true,
        createdAt: now.subtract(const Duration(days: 2)),
        views: 8500,
        clicks: 320,
      ),
      PromotedProduct(
        id: 'product-3',
        name: 'Designer Handbag',
        description: 'Luxury leather handbag',
        imageUrl: null,
        price: 299.99,
        currency: 'USD',
        originalPrice: 399.99,
        discountPercentage: 25.0,
        offerBadge: '25% OFF',
        companyId: 'company-2',
        companyName: 'FashionHub',
        companyLogoUrl: null,
        category: 'fashion',
        tags: ['handbag', 'luxury', 'fashion'],
        externalUrl: 'https://fashionhub.com/products/designer-handbag',
        isTrending: false,
        isNewArrival: false,
        createdAt: now.subtract(const Duration(days: 10)),
        views: 12000,
        clicks: 280,
      ),
      PromotedProduct(
        id: 'product-4',
        name: 'Vitamin C Serum',
        description: 'Brightening vitamin C serum for glowing skin',
        imageUrl: null,
        price: 29.99,
        currency: 'USD',
        originalPrice: 39.99,
        discountPercentage: 25.0,
        offerBadge: '25% OFF',
        companyId: 'company-3',
        companyName: 'BeautyGlow',
        companyLogoUrl: null,
        category: 'beauty',
        tags: ['skincare', 'serum', 'beauty'],
        externalUrl: 'https://beautyglow.com/products/vitamin-c-serum',
        isTrending: true,
        isNewArrival: true,
        createdAt: now.subtract(const Duration(days: 1)),
        views: 9800,
        clicks: 410,
      ),
      PromotedProduct(
        id: 'product-5',
        name: 'Yoga Mat Premium',
        description: 'Non-slip premium yoga mat',
        imageUrl: null,
        price: 49.99,
        currency: 'USD',
        originalPrice: null,
        discountPercentage: null,
        offerBadge: 'New Arrival',
        companyId: 'company-1',
        companyName: 'TechBrand',
        companyLogoUrl: null,
        category: 'fitness',
        tags: ['yoga', 'fitness', 'exercise'],
        externalUrl: 'https://techbrand.com/products/yoga-mat',
        isTrending: false,
        isNewArrival: true,
        createdAt: now.subtract(const Duration(hours: 12)),
        views: 3200,
        clicks: 95,
      ),
      PromotedProduct(
        id: 'product-6',
        name: 'LED Desk Lamp',
        description: 'Adjustable LED desk lamp with USB charging',
        imageUrl: null,
        price: 39.99,
        currency: 'USD',
        originalPrice: 59.99,
        discountPercentage: 33.3,
        offerBadge: '33% OFF',
        companyId: 'company-1',
        companyName: 'TechBrand',
        companyLogoUrl: null,
        category: 'home',
        tags: ['lighting', 'desk', 'home'],
        externalUrl: 'https://techbrand.com/products/led-desk-lamp',
        isTrending: false,
        isNewArrival: false,
        createdAt: now.subtract(const Duration(days: 7)),
        views: 6500,
        clicks: 180,
      ),
    ];

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
      products = products.where((p) => p.price != null && p.price! >= filter.minPrice!).toList();
    }

    if (filter.maxPrice != null) {
      products = products.where((p) => p.price != null && p.price! <= filter.maxPrice!).toList();
    }

    if (filter.trendingOnly == true) {
      products = products.where((p) => p.isTrending).toList();
    }

    if (filter.newArrivalsOnly == true) {
      products = products.where((p) => p.isNewArrival).toList();
    }

    if (filter.offerType != null) {
      if (filter.offerType == 'discount') {
        products = products.where((p) => p.discountPercentage != null && p.discountPercentage! > 0).toList();
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
