import '../models/ad_model.dart';
import '../models/user_model.dart';

class AdTargetingService {
  static final AdTargetingService _instance = AdTargetingService._internal();
  factory AdTargetingService() => _instance;

  AdTargetingService._internal();

  // Filter and rank ads based on user profile
  List<Ad> getTargetedAds({
    required List<Ad> availableAds,
    required User user,
    List<String>? userLanguages,
    List<String>? userPreferences,
    List<String>? searchHistory,
    String? userLocation,
  }) {
    // Filter ads based on eligibility and targeting
    final filteredAds = availableAds.where((ad) {
      // Check if ad matches user's language
      if (userLanguages != null && userLanguages.isNotEmpty) {
        final hasMatchingLanguage = ad.targetLanguages.isEmpty ||
            ad.targetLanguages.any((lang) => userLanguages.contains(lang));
        if (!hasMatchingLanguage) return false;
      }

      // Check if ad matches user's location
      if (userLocation != null && ad.targetLocation != null) {
        if (ad.targetLocation != userLocation) return false;
      }

      // Check if ad is active and not exhausted
      if (!ad.isActive || ad.currentViews >= ad.maxRewardableViews) {
        return false;
      }

      return true;
    }).toList();

    // Rank ads by relevance score
    filteredAds.sort((a, b) {
      final scoreA = _calculateRelevanceScore(
        a,
        userLanguages: userLanguages,
        userPreferences: userPreferences,
        searchHistory: searchHistory,
      );
      final scoreB = _calculateRelevanceScore(
        b,
        userLanguages: userLanguages,
        userPreferences: userPreferences,
        searchHistory: searchHistory,
      );
      return scoreB.compareTo(scoreA); // Higher score first
    });

    return filteredAds;
  }

  // Calculate relevance score for an ad
  double _calculateRelevanceScore(
    Ad ad, {
    List<String>? userLanguages,
    List<String>? userPreferences,
    List<String>? searchHistory,
  }) {
    double score = 0.0;

    // Language match (high weight)
    if (userLanguages != null && ad.targetLanguages.isNotEmpty) {
      final matchingLanguages = ad.targetLanguages
          .where((lang) => userLanguages.contains(lang))
          .length;
      score += matchingLanguages * 10.0;
    }

    // Category/preference match
    if (userPreferences != null && ad.targetCategories.isNotEmpty) {
      final matchingCategories = ad.targetCategories
          .where((cat) => userPreferences.contains(cat))
          .length;
      score += matchingCategories * 5.0;
    }

    // Search history match
    if (searchHistory != null && searchHistory.isNotEmpty) {
      final matchingKeywords = searchHistory
          .where((keyword) =>
              ad.title.toLowerCase().contains(keyword.toLowerCase()) ||
              ad.description.toLowerCase().contains(keyword.toLowerCase()))
          .length;
      score += matchingKeywords * 3.0;
    }

    // Reward value (higher reward = slightly higher score)
    score += ad.coinReward * 0.1;

    return score;
  }
}
