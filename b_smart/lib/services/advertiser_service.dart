import '../models/advertiser_model.dart';

class AdvertiserService {
  static final AdvertiserService _instance = AdvertiserService._internal();
  factory AdvertiserService() => _instance;

  final Map<String, AdvertiserAccount> _accounts = {};
  List<AdvertiserAd> _ads = [];
  final Map<String, AdAnalytics> _analytics = {};
  final String _currentAdvertiserId = 'advertiser-1';

  // Conversion rate: ₹1 = 10 coins
  static const double rupeesToCoinsRate = 10.0;

  AdvertiserService._internal() {
    _initializeDummyData();
  }

  void _initializeDummyData() {
    final now = DateTime.now();

    // Advertiser Account
    _accounts[_currentAdvertiserId] = AdvertiserAccount(
      id: _currentAdvertiserId,
      companyName: 'TechBrand',
      email: 'advertiser@techbrand.com',
      phone: '+1234567890',
      currentPlan: AdPlan.premium,
      planExpiresAt: now.add(const Duration(days: 30)),
      totalCoinsPurchased: 50000,
      coinsAvailable: 25000,
      coinsConsumed: 25000,
      createdAt: now.subtract(const Duration(days: 90)),
      kycVerified: true,
      salesOfficerContact: 'sales@bsmart.com',
    );

    // Sample Ads
    _ads = [
      AdvertiserAd(
        id: 'ad-adv-1',
        advertiserId: _currentAdvertiserId,
        category: AdCategory.product,
        companyName: 'TechBrand',
        companyDescription: 'Leading technology products',
        targetLocations: ['US', 'India'],
        targetLanguages: ['en', 'hi'],
        targetInterests: ['technology', 'gadgets'],
        budgetRupees: 5000.0,
        coinsAllocated: 50000,
        coinsConsumed: 25000,
        coinsRemaining: 25000,
        estimatedRewards: 5000,
        estimatedReach: 10000,
        status: AdStatus.active,
        createdAt: now.subtract(const Duration(days: 5)),
        approvedAt: now.subtract(const Duration(days: 4)),
        startedAt: now.subtract(const Duration(days: 4)),
        plan: AdPlan.premium,
      ),
      AdvertiserAd(
        id: 'ad-adv-2',
        advertiserId: _currentAdvertiserId,
        category: AdCategory.companyPromotion,
        companyName: 'TechBrand',
        budgetRupees: 3000.0,
        coinsAllocated: 30000,
        coinsConsumed: 30000,
        coinsRemaining: 0,
        estimatedRewards: 3000,
        estimatedReach: 6000,
        status: AdStatus.completed,
        createdAt: now.subtract(const Duration(days: 30)),
        approvedAt: now.subtract(const Duration(days: 29)),
        startedAt: now.subtract(const Duration(days: 29)),
        endedAt: now.subtract(const Duration(days: 15)),
        plan: AdPlan.standard,
      ),
    ];

    // Sample Analytics
    _analytics['ad-adv-1'] = AdAnalytics(
      adId: 'ad-adv-1',
      totalImpressions: 12500,
      uniqueViewers: 10000,
      repeatViewers: 2500,
      reachByGeography: {'US': 8000, 'India': 4500},
      reachByLanguage: {'en': 10000, 'hi': 2500},
      reachByInterest: {'technology': 7000, 'gadgets': 5500},
      totalViews: 10000,
      validViews: 8500,
      viewThroughRate: 0.85,
      averageWatchDuration: 25.5,
      completionRate: 0.75,
      dropOffPoints: {'0-25%': 500, '25-50%': 1000, '50-75%': 500, '75-100%': 2500},
      totalWatchHours: 70.8,
      averageWatchTimePerView: 25.5,
      watchHoursByDay: {'Monday': 12.5, 'Tuesday': 15.2, 'Wednesday': 14.8},
      genderSplit: {'Male': 6000, 'Female': 4000},
      ageGroups: {'18-24': 3000, '25-34': 5000, '35-44': 2000},
      totalCoinsAllocated: 50000,
      coinsConsumed: 25000,
      coinsRemaining: 25000,
      rewardsIssued: 2500,
      averageCoinsPerUser: 10.0,
      costPerValidReward: 10.0,
      costPerWatchMinute: 0.35,
      clickThroughRate: 250,
      profileVisits: 500,
      companyPageOpens: 300,
      externalLinkClicks: 150,
      followActions: 200,
      lastUpdated: now,
    );
  }

  // Get advertiser account
  AdvertiserAccount? getAccount(String advertiserId) {
    return _accounts[advertiserId];
  }

  AdvertiserAccount getCurrentAccount() {
    return _accounts[_currentAdvertiserId] ?? AdvertiserAccount(
      id: _currentAdvertiserId,
      companyName: 'Unknown',
      createdAt: DateTime.now(),
    );
  }

  // Convert rupees to coins
  int rupeesToCoins(double rupees) {
    return (rupees * rupeesToCoinsRate).round();
  }

  // Convert coins to rupees
  double coinsToRupees(int coins) {
    return coins / rupeesToCoinsRate;
  }

  // Get dashboard metrics
  DashboardMetrics getDashboardMetrics(String advertiserId) {
    final account = getAccount(advertiserId);
    if (account == null) {
      return DashboardMetrics.empty();
    }

    final allAds = _ads.where((a) => a.advertiserId == advertiserId).toList();
    final activeAds = allAds.where((a) => a.status == AdStatus.active).toList();
    final totalImpressions = allAds.fold<int>(0, (sum, ad) {
      final analytics = _analytics[ad.id];
      return sum + (analytics?.totalImpressions ?? 0);
    });
    final totalRewardedUsers = allAds.fold<int>(0, (sum, ad) {
      final analytics = _analytics[ad.id];
      return sum + (analytics?.rewardsIssued ?? 0);
    });
    final totalWatchHours = allAds.fold<double>(0.0, (sum, ad) {
      final analytics = _analytics[ad.id];
      return sum + (analytics?.totalWatchHours ?? 0.0);
    });
    final averageWatchTime = totalWatchHours > 0
        ? (totalWatchHours * 3600) / totalImpressions
        : 0.0;

    // Find best and worst performing ads
    AdvertiserAd? bestAd;
    AdvertiserAd? worstAd;
    double bestEngagement = 0.0;
    double worstEngagement = double.infinity;

    for (final ad in allAds) {
      final analytics = _analytics[ad.id];
      if (analytics != null) {
        final engagement = analytics.viewThroughRate;
        if (engagement > bestEngagement) {
          bestEngagement = engagement;
          bestAd = ad;
        }
        if (engagement < worstEngagement) {
          worstEngagement = engagement;
          worstAd = ad;
        }
      }
    }

    return DashboardMetrics(
      totalAdsCreated: allAds.length,
      activeAds: activeAds.length,
      adsRemainingInPlan: account.currentPlan != null
          ? account.currentPlan!.maxAdsPerMonth - activeAds.length
          : 0,
      totalCoinsPurchased: account.totalCoinsPurchased,
      coinsAvailable: account.coinsAvailable,
      coinsConsumed: account.coinsConsumed,
      totalImpressions: totalImpressions,
      totalRewardedUsers: totalRewardedUsers,
      totalWatchHours: totalWatchHours,
      averageWatchTimePerUser: averageWatchTime,
      costPerRewardedUser: totalRewardedUsers > 0
          ? account.coinsConsumed / totalRewardedUsers
          : 0.0,
      bestPerformingAd: bestAd,
      lowestPerformingAd: worstAd,
    );
  }

  // Get ad analytics
  AdAnalytics? getAdAnalytics(String adId) {
    return _analytics[adId];
  }

  // Get all ads for advertiser
  List<AdvertiserAd> getAdvertiserAds(String advertiserId) {
    return _ads.where((a) => a.advertiserId == advertiserId).toList();
  }

  // Create new ad
  Future<AdvertiserAd> createAd({
    required String advertiserId,
    required AdCategory category,
    required String companyName,
    required double budgetRupees,
    String? videoUrl,
    String? bannerUrl,
    String? ctaText,
    String? companyDescription,
    List<String>? companyImages,
    List<String>? targetLocations,
    List<String>? targetLanguages,
    List<String>? targetInterests,
    String? targetAgeRange,
    String? targetGender,
    bool commentsDisabled = false,
    bool likesDisabled = false,
    bool sharingDisabled = false,
    bool hideViewCount = false,
  }) async {
    final account = getAccount(advertiserId);
    if (account == null) {
      throw Exception('Advertiser account not found');
    }

    // Check plan limits
    if (account.currentPlan != null) {
      final activeAds = _ads.where((a) =>
        a.advertiserId == advertiserId && a.status == AdStatus.active
      ).length;
      
      if (activeAds >= account.currentPlan!.maxAdsPerMonth) {
        throw Exception('Plan limit reached. Upgrade to create more ads.');
      }
    }

    final coinsAllocated = rupeesToCoins(budgetRupees);
    final estimatedRewards = (coinsAllocated / 10).round(); // Assuming 10 coins per reward
    final estimatedReach = estimatedRewards * 2; // Rough estimate

    final ad = AdvertiserAd(
      id: 'ad-${DateTime.now().millisecondsSinceEpoch}',
      advertiserId: advertiserId,
      category: category,
      videoUrl: videoUrl,
      bannerUrl: bannerUrl,
      ctaText: ctaText,
      companyName: companyName,
      companyDescription: companyDescription,
      companyImages: companyImages,
      targetLocations: targetLocations ?? [],
      targetLanguages: targetLanguages ?? [],
      targetInterests: targetInterests ?? [],
      targetAgeRange: targetAgeRange,
      targetGender: targetGender,
      commentsDisabled: commentsDisabled,
      likesDisabled: likesDisabled,
      sharingDisabled: sharingDisabled,
      hideViewCount: hideViewCount,
      budgetRupees: budgetRupees,
      coinsAllocated: coinsAllocated,
      coinsRemaining: coinsAllocated,
      estimatedRewards: estimatedRewards,
      estimatedReach: estimatedReach,
      status: AdStatus.pendingReview,
      createdAt: DateTime.now(),
      plan: account.currentPlan,
    );

    _ads.add(ad);
    return ad;
  }

  // Approve ad
  Future<bool> approveAd(String adId) async {
    final index = _ads.indexWhere((a) => a.id == adId);
    if (index == -1) return false;

    final ad = _ads[index];
    _ads[index] = ad.copyWith(
      status: AdStatus.approved,
      approvedAt: DateTime.now(),
    );

    // Initialize analytics
    _analytics[adId] = AdAnalytics(
      adId: adId,
      totalCoinsAllocated: ad.coinsAllocated,
      coinsRemaining: ad.coinsRemaining,
      lastUpdated: DateTime.now(),
    );

    return true;
  }

  // Reject ad
  Future<bool> rejectAd(String adId, String reason) async {
    final index = _ads.indexWhere((a) => a.id == adId);
    if (index == -1) return false;

    final ad = _ads[index];
    _ads[index] = ad.copyWith(
      status: AdStatus.rejected,
      rejectionReason: reason,
    );

    return true;
  }

  // Activate ad
  Future<bool> activateAd(String adId) async {
    final index = _ads.indexWhere((a) => a.id == adId);
    if (index == -1) return false;

    final ad = _ads[index];
    if (ad.status != AdStatus.approved) return false;

    _ads[index] = ad.copyWith(
      status: AdStatus.active,
      startedAt: DateTime.now(),
    );

    return true;
  }

  // Update ad analytics (called by ad serving system)
  void updateAdAnalytics(String adId, {
    int? impressions,
    int? views,
    int? validViews,
    double? watchDuration,
    Map<String, int>? geography,
    Map<String, int>? language,
    Map<String, int>? interest,
    Map<String, int>? gender,
    Map<String, int>? ageGroups,
    int? coinsConsumed,
    int? rewardsIssued,
  }) {
    final analytics = _analytics[adId];
    if (analytics == null) return;

    final ad = _ads.firstWhere((a) => a.id == adId, orElse: () => throw Exception('Ad not found'));

    final updatedImpressions = impressions ?? analytics.totalImpressions;
    final updatedViews = views ?? analytics.totalViews;
    final updatedValidViews = validViews ?? analytics.validViews;
    final vtr = updatedImpressions > 0 ? updatedViews / updatedImpressions : 0.0;
    final avgWatchDuration = watchDuration ?? analytics.averageWatchDuration;
    final completionRate = avgWatchDuration > 0 && ad.category.durationSeconds > 0
        ? (avgWatchDuration / ad.category.durationSeconds).clamp(0.0, 1.0)
        : 0.0;
    final totalWatchHours = (updatedViews * avgWatchDuration) / 3600.0;
    final avgWatchTimePerView = avgWatchDuration;
    final updatedCoinsConsumed = coinsConsumed ?? analytics.coinsConsumed;
    final updatedRewardsIssued = rewardsIssued ?? analytics.rewardsIssued;
    final costPerReward = updatedRewardsIssued > 0
        ? updatedCoinsConsumed / updatedRewardsIssued
        : 0.0;
    final costPerMinute = totalWatchHours > 0
        ? updatedCoinsConsumed / (totalWatchHours * 60)
        : 0.0;

    final updatedCoinsRemaining = ad.coinsAllocated - updatedCoinsConsumed;

    _analytics[adId] = AdAnalytics(
      adId: adId,
      totalImpressions: updatedImpressions,
      uniqueViewers: analytics.uniqueViewers,
      repeatViewers: analytics.repeatViewers,
      reachByGeography: geography ?? analytics.reachByGeography,
      reachByLanguage: language ?? analytics.reachByLanguage,
      reachByInterest: interest ?? analytics.reachByInterest,
      totalViews: updatedViews,
      validViews: updatedValidViews,
      viewThroughRate: vtr,
      averageWatchDuration: avgWatchDuration,
      completionRate: completionRate,
      dropOffPoints: analytics.dropOffPoints,
      totalWatchHours: totalWatchHours,
      averageWatchTimePerView: avgWatchTimePerView,
      watchHoursByDay: analytics.watchHoursByDay,
      watchHoursByWeek: analytics.watchHoursByWeek,
      watchHoursByMonth: analytics.watchHoursByMonth,
      genderSplit: gender ?? analytics.genderSplit,
      ageGroups: ageGroups ?? analytics.ageGroups,
      totalCoinsAllocated: analytics.totalCoinsAllocated,
      coinsConsumed: updatedCoinsConsumed,
      coinsRemaining: updatedCoinsRemaining,
      rewardsIssued: updatedRewardsIssued,
      averageCoinsPerUser: updatedRewardsIssued > 0
          ? updatedCoinsConsumed / updatedRewardsIssued
          : 0.0,
      costPerValidReward: costPerReward,
      costPerWatchMinute: costPerMinute,
      clickThroughRate: analytics.clickThroughRate,
      profileVisits: analytics.profileVisits,
      companyPageOpens: analytics.companyPageOpens,
      externalLinkClicks: analytics.externalLinkClicks,
      followActions: analytics.followActions,
      lastUpdated: DateTime.now(),
    );

    // Update ad coins consumed
    final adIndex = _ads.indexWhere((a) => a.id == adId);
    if (adIndex != -1) {
      _ads[adIndex] = ad.copyWith(
        coinsConsumed: updatedCoinsConsumed,
        coinsRemaining: updatedCoinsRemaining,
      );
    }

    // Handle coins reaching zero (grace period)
    if (updatedCoinsRemaining <= 0 && ad.status == AdStatus.active) {
      // In real app, would continue with grace period, then stop
      // For now, mark as completed
      _ads[adIndex] = ad.copyWith(
        status: AdStatus.completed,
        endedAt: DateTime.now(),
      );
    }
  }

  // Get ads by status
  List<AdvertiserAd> getAdsByStatus(String advertiserId, AdStatus status) {
    return _ads.where((a) =>
      a.advertiserId == advertiserId && a.status == status
    ).toList();
  }
}

class DashboardMetrics {
  final int totalAdsCreated;
  final int activeAds;
  final int adsRemainingInPlan;
  final int totalCoinsPurchased;
  final int coinsAvailable;
  final int coinsConsumed;
  final int totalImpressions;
  final int totalRewardedUsers;
  final double totalWatchHours;
  final double averageWatchTimePerUser;
  final double costPerRewardedUser;
  final AdvertiserAd? bestPerformingAd;
  final AdvertiserAd? lowestPerformingAd;

  DashboardMetrics({
    required this.totalAdsCreated,
    required this.activeAds,
    required this.adsRemainingInPlan,
    required this.totalCoinsPurchased,
    required this.coinsAvailable,
    required this.coinsConsumed,
    required this.totalImpressions,
    required this.totalRewardedUsers,
    required this.totalWatchHours,
    required this.averageWatchTimePerUser,
    required this.costPerRewardedUser,
    this.bestPerformingAd,
    this.lowestPerformingAd,
  });

  factory DashboardMetrics.empty() {
    return DashboardMetrics(
      totalAdsCreated: 0,
      activeAds: 0,
      adsRemainingInPlan: 0,
      totalCoinsPurchased: 0,
      coinsAvailable: 0,
      coinsConsumed: 0,
      totalImpressions: 0,
      totalRewardedUsers: 0,
      totalWatchHours: 0.0,
      averageWatchTimePerUser: 0.0,
      costPerRewardedUser: 0.0,
    );
  }
}
