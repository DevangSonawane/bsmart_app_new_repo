import '../models/ad_model.dart';
import '../services/ad_targeting_service.dart';
import '../services/dummy_data_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;

  final AdTargetingService _targetingService = AdTargetingService();
  List<Ad> _availableAds = [];

  AdService._internal() {
    _availableAds = _generateDummyAds();
  }

  List<Ad> _generateDummyAds() {
    final now = DateTime.now();
    return [
      Ad(
        id: 'ad-1',
        companyId: 'company-1',
        companyName: 'TechCorp',
        title: 'Special Offer - 50% Off',
        description: 'Get amazing deals on premium tech products',
        imageUrl: 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=800',
        coinReward: 50,
        watchDurationSeconds: 30,
        maxRewardableViews: 1000,
        currentViews: 250,
        targetLanguages: ['en', 'es'],
        targetCategories: ['technology', 'electronics'],
        targetLocation: 'US',
        isVerified: true,
        websiteUrl: 'https://techcorp.example.com',
        createdAt: now.subtract(const Duration(days: 5)),
        isActive: true,
      ),
      Ad(
        id: 'ad-2',
        companyId: 'company-2',
        companyName: 'FashionHub',
        title: 'New Product Launch',
        description: 'Discover the latest fashion trends',
        imageUrl: 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800',
        coinReward: 75,
        watchDurationSeconds: 45,
        maxRewardableViews: 500,
        currentViews: 120,
        targetLanguages: ['en'],
        targetCategories: ['fashion', 'accessories'],
        targetLocation: 'US',
        isVerified: false,
        websiteUrl: 'https://fashionhub.example.com',
        createdAt: now.subtract(const Duration(days: 3)),
        isActive: true,
      ),
      Ad(
        id: 'ad-3',
        companyId: 'company-3',
        companyName: 'FoodDelight',
        title: 'Summer Sale',
        description: 'Taste the best food in town',
        imageUrl: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
        coinReward: 100,
        watchDurationSeconds: 60,
        maxRewardableViews: 800,
        currentViews: 450,
        targetLanguages: ['en', 'fr'],
        targetCategories: ['food'],
        targetLocation: 'US',
        isVerified: true,
        websiteUrl: 'https://fooddelight.example.com',
        createdAt: now.subtract(const Duration(days: 7)),
        isActive: true,
      ),
      Ad(
        id: 'ad-4',
        companyId: 'company-1',
        companyName: 'TechCorp',
        title: 'Premium Products',
        description: 'Check out our premium product line',
        imageUrl: 'https://images.unsplash.com/photo-1526374965328-7f61d4f18da5?w=800',
        coinReward: 60,
        watchDurationSeconds: 40,
        maxRewardableViews: 600,
        currentViews: 380,
        targetLanguages: ['en'],
        targetCategories: ['technology', 'electronics'],
        targetLocation: 'US',
        isVerified: true,
        websiteUrl: 'https://techcorp.example.com',
        createdAt: now.subtract(const Duration(days: 2)),
        isActive: true,
      ),
      Ad(
        id: 'ad-5',
        companyId: 'company-4',
        companyName: 'ArtSupply Co',
        title: 'Creative Tools',
        description: 'Everything you need for your art projects',
        imageUrl: 'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=800',
        coinReward: 40,
        watchDurationSeconds: 25,
        maxRewardableViews: 700,
        currentViews: 200,
        targetLanguages: ['en'],
        targetCategories: ['art_supplies'],
        targetLocation: 'US',
        isVerified: false,
        websiteUrl: 'https://artsupply.example.com',
        createdAt: now.subtract(const Duration(days: 1)),
        isActive: true,
      ),
      Ad(
        id: 'ad-6',
        companyId: 'company-5',
        companyName: 'BabyCare',
        title: 'Safe & Healthy',
        description: 'Premium baby products for your little one',
        imageUrl: 'https://images.unsplash.com/photo-1555252333-9f8e92e65df9?w=800',
        coinReward: 55,
        watchDurationSeconds: 35,
        maxRewardableViews: 400,
        currentViews: 150,
        targetLanguages: ['en'],
        targetCategories: ['baby_products'],
        targetLocation: 'US',
        isVerified: true,
        websiteUrl: 'https://babycare.example.com',
        createdAt: now.subtract(const Duration(hours: 12)),
        isActive: true,
      ),
      Ad(
        id: 'ad-7',
        companyId: 'company-6',
        companyName: 'SportsZone',
        title: 'Get Active',
        description: 'Top quality sports equipment',
        imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=800',
        coinReward: 65,
        watchDurationSeconds: 50,
        maxRewardableViews: 900,
        currentViews: 320,
        targetLanguages: ['en'],
        targetCategories: ['sports'],
        targetLocation: 'US',
        isVerified: false,
        websiteUrl: 'https://sportszone.example.com',
        createdAt: now.subtract(const Duration(days: 4)),
        isActive: true,
      ),
    ];
  }

  // Get targeted ads for user
  List<Ad> getTargetedAds({
    List<String>? userLanguages,
    List<String>? userPreferences,
    List<String>? searchHistory,
    String? userLocation,
  }) {
    return _targetingService.getTargetedAds(
      availableAds: _availableAds,
      user: DummyDataService().getCurrentUser(),
      userLanguages: userLanguages ?? ['en'],
      userPreferences: userPreferences,
      searchHistory: searchHistory,
      userLocation: userLocation ?? 'US',
    );
  }

  // Get ad by ID
  Ad? getAdById(String adId) {
    try {
      return _availableAds.firstWhere((ad) => ad.id == adId);
    } catch (e) {
      return null;
    }
  }

  // Get company by ID
  AdCompany? getCompanyById(String companyId) {
    final companyAds = _availableAds.where((ad) => ad.companyId == companyId).toList();
    if (companyAds.isEmpty) return null;

    final firstAd = companyAds.first;
    return AdCompany(
      id: companyId,
      name: firstAd.companyName,
      description: 'Leading company in their industry',
      websiteUrl: firstAd.websiteUrl,
      isVerified: firstAd.isVerified,
      activeAds: companyAds,
    );
  }

  // Increment ad views
  void incrementAdViews(String adId) {
    final index = _availableAds.indexWhere((ad) => ad.id == adId);
    if (index != -1) {
      // In real app, this would be done server-side
      // For demo, we'll just track it
    }
  }
}
