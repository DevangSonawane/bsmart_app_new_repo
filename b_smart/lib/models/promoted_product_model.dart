class PromotedProduct {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final double? price;
  final String? currency;
  final double? originalPrice;
  final double? discountPercentage;
  final String? offerBadge; // e.g., "50% OFF", "New Arrival"
  final String companyId;
  final String companyName;
  final String? companyLogoUrl;
  final String? category;
  final List<String> tags;
  final String externalUrl; // Link to external e-commerce page
  final bool isTrending;
  final bool isNewArrival;
  final DateTime createdAt;
  final int views;
  final int clicks;

  PromotedProduct({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.price,
    this.currency,
    this.originalPrice,
    this.discountPercentage,
    this.offerBadge,
    required this.companyId,
    required this.companyName,
    this.companyLogoUrl,
    this.category,
    this.tags = const [],
    required this.externalUrl,
    this.isTrending = false,
    this.isNewArrival = false,
    required this.createdAt,
    this.views = 0,
    this.clicks = 0,
  });
}

class CompanyDetail {
  final String id;
  final String name;
  final String? logoUrl;
  final String? description;
  final String? website;
  final bool isVerified;
  final int followers;
  final List<PromotedProduct> products;
  final List<String> categories;
  final DateTime joinedDate;

  CompanyDetail({
    required this.id,
    required this.name,
    this.logoUrl,
    this.description,
    this.website,
    this.isVerified = false,
    this.followers = 0,
    this.products = const [],
    this.categories = const [],
    required this.joinedDate,
  });
}

class ProductCategory {
  final String id;
  final String name;
  final String? icon;
  final int productCount;

  ProductCategory({
    required this.id,
    required this.name,
    this.icon,
    this.productCount = 0,
  });
}

class ProductFilter {
  final String? category;
  final String? brand;
  final double? minPrice;
  final double? maxPrice;
  final bool? trendingOnly;
  final bool? newArrivalsOnly;
  final String? offerType;

  ProductFilter({
    this.category,
    this.brand,
    this.minPrice,
    this.maxPrice,
    this.trendingOnly,
    this.newArrivalsOnly,
    this.offerType,
  });

  bool get hasFilters {
    return category != null ||
        brand != null ||
        minPrice != null ||
        maxPrice != null ||
        trendingOnly == true ||
        newArrivalsOnly == true ||
        offerType != null;
  }
}
