import '../models/ad_model.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;

  final List<Ad> _availableAds = const [];

  AdService._internal();

  // Get targeted ads for user
  List<Ad> getTargetedAds({
    List<String>? userLanguages,
    List<String>? userPreferences,
    List<String>? searchHistory,
    String? userLocation,
  }) {
    return const <Ad>[];
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
    final companyAds =
        _availableAds.where((ad) => ad.companyId == companyId).toList();
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
    // Ad view tracking is handled by the backend for real ad inventory.
  }
}
