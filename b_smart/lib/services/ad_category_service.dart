import '../models/ad_category_model.dart';
import '../models/ad_model.dart';
import '../services/ad_service.dart';

class AdCategoryService {
  static final AdCategoryService _instance = AdCategoryService._internal();
  factory AdCategoryService() => _instance;

  final AdService _adService = AdService();

  AdCategoryService._internal();

  // Get all categories
  List<AdCategory> getCategories() {
    return [
      AdCategory(id: 'all', name: 'All'),
      AdCategory(id: 'accessories', name: 'Accessories'),
      AdCategory(id: 'action_figures', name: 'Action Figures'),
      AdCategory(id: 'art_supplies', name: 'Art Supplies'),
      AdCategory(id: 'baby_products', name: 'Baby Products'),
      AdCategory(id: 'electronics', name: 'Electronics'),
      AdCategory(id: 'fashion', name: 'Fashion'),
      AdCategory(id: 'food', name: 'Food'),
      AdCategory(id: 'health', name: 'Health'),
      AdCategory(id: 'home', name: 'Home'),
      AdCategory(id: 'sports', name: 'Sports'),
      AdCategory(id: 'technology', name: 'Technology'),
    ];
  }

  // Get ads by category
  List<Ad> getAdsByCategory({
    required String categoryId,
    List<String>? userLanguages,
    List<String>? userPreferences,
    String? userLocation,
  }) {
    if (categoryId == 'all') {
      return _adService.getTargetedAds(
        userLanguages: userLanguages ?? ['en'],
        userPreferences: userPreferences,
        userLocation: userLocation ?? 'US',
      );
    }

    // Filter ads by category
    final allAds = _adService.getTargetedAds(
      userLanguages: userLanguages ?? ['en'],
      userPreferences: userPreferences,
      userLocation: userLocation ?? 'US',
    );

    return allAds.where((ad) {
      // Match category based on ad's target categories
      // Check if any target category matches the selected category ID
      return ad.targetCategories.any((cat) {
        // Direct match
        if (cat == categoryId) return true;
        // Partial match (e.g., 'technology' matches 'technology')
        if (cat.toLowerCase().contains(categoryId.toLowerCase()) ||
            categoryId.toLowerCase().contains(cat.toLowerCase())) {
          return true;
        }
        // Handle category name variations
        final categoryMap = {
          'accessories': ['accessories', 'fashion'],
          'action_figures': ['action_figures', 'toys'],
          'art_supplies': ['art_supplies', 'art'],
          'baby_products': ['baby_products', 'baby'],
          'electronics': ['electronics', 'technology'],
          'fashion': ['fashion', 'lifestyle', 'accessories'],
          'food': ['food', 'restaurant'],
          'health': ['health', 'wellness'],
          'home': ['home', 'furniture'],
          'sports': ['sports', 'fitness'],
          'technology': ['technology', 'electronics'],
        };
        final mappedCategories = categoryMap[categoryId] ?? [];
        return mappedCategories.any((mapped) => cat.toLowerCase().contains(mapped.toLowerCase()));
      });
    }).toList();
  }

  // Get next eligible ad
  Ad? getNextEligibleAd({
    required String currentAdId,
    required String categoryId,
    List<String>? userLanguages,
    List<String>? userPreferences,
    String? userLocation,
  }) {
    final ads = getAdsByCategory(
      categoryId: categoryId,
      userLanguages: userLanguages,
      userPreferences: userPreferences,
      userLocation: userLocation,
    );

    final currentIndex = ads.indexWhere((ad) => ad.id == currentAdId);
    if (currentIndex == -1 || currentIndex >= ads.length - 1) {
      return null;
    }

    return ads[currentIndex + 1];
  }

  // Get previous ad
  Ad? getPreviousAd({
    required String currentAdId,
    required String categoryId,
    List<String>? userLanguages,
    List<String>? userPreferences,
    String? userLocation,
  }) {
    final ads = getAdsByCategory(
      categoryId: categoryId,
      userLanguages: userLanguages,
      userPreferences: userPreferences,
      userLocation: userLocation,
    );

    final currentIndex = ads.indexWhere((ad) => ad.id == currentAdId);
    if (currentIndex <= 0) {
      return null;
    }

    return ads[currentIndex - 1];
  }
}
