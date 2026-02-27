enum AdCategory {
  product(30),
  companyPromotion(60),
  productLaunch(120),
  filmMovie(180);

  final int durationSeconds;
  const AdCategory(this.durationSeconds);
}

enum AdStatus {
  draft,
  pendingReview,
  approved,
  rejected,
  active,
  paused,
  completed,
  expired,
}

enum AdPlan {
  basic(5),
  standard(10),
  premium(15),
  enterprise(25);

  final int maxAdsPerMonth;
  const AdPlan(this.maxAdsPerMonth);
}

class AdvertiserAd {
  final String id;
  final String advertiserId;
  final AdCategory category;
  final String? videoUrl;
  final String? bannerUrl;
  final String? ctaText;
  final String companyName;
  final String? companyDescription;
  final List<String>? companyImages;
  final List<String>? employeeImages;
  final List<String> targetLocations;
  final List<String> targetLanguages;
  final List<String> targetInterests;
  final String? targetAgeRange;
  final String? targetGender;
  final bool commentsDisabled;
  final bool likesDisabled;
  final bool sharingDisabled;
  final bool hideViewCount;
  final double budgetRupees;
  final int coinsAllocated;
  final int coinsConsumed;
  final int coinsRemaining;
  final int estimatedRewards;
  final int estimatedReach;
  final AdStatus status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final AdPlan? plan;

  AdvertiserAd({
    required this.id,
    required this.advertiserId,
    required this.category,
    this.videoUrl,
    this.bannerUrl,
    this.ctaText,
    required this.companyName,
    this.companyDescription,
    this.companyImages,
    this.employeeImages,
    this.targetLocations = const [],
    this.targetLanguages = const [],
    this.targetInterests = const [],
    this.targetAgeRange,
    this.targetGender,
    this.commentsDisabled = false,
    this.likesDisabled = false,
    this.sharingDisabled = false,
    this.hideViewCount = false,
    required this.budgetRupees,
    required this.coinsAllocated,
    this.coinsConsumed = 0,
    this.coinsRemaining = 0,
    this.estimatedRewards = 0,
    this.estimatedReach = 0,
    this.status = AdStatus.draft,
    this.rejectionReason,
    required this.createdAt,
    this.approvedAt,
    this.startedAt,
    this.endedAt,
    this.plan,
  });

  AdvertiserAd copyWith({
    String? id,
    String? advertiserId,
    AdCategory? category,
    String? videoUrl,
    String? bannerUrl,
    String? ctaText,
    String? companyName,
    String? companyDescription,
    List<String>? companyImages,
    List<String>? employeeImages,
    List<String>? targetLocations,
    List<String>? targetLanguages,
    List<String>? targetInterests,
    String? targetAgeRange,
    String? targetGender,
    bool? commentsDisabled,
    bool? likesDisabled,
    bool? sharingDisabled,
    bool? hideViewCount,
    double? budgetRupees,
    int? coinsAllocated,
    int? coinsConsumed,
    int? coinsRemaining,
    int? estimatedRewards,
    int? estimatedReach,
    AdStatus? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? approvedAt,
    DateTime? startedAt,
    DateTime? endedAt,
    AdPlan? plan,
  }) {
    return AdvertiserAd(
      id: id ?? this.id,
      advertiserId: advertiserId ?? this.advertiserId,
      category: category ?? this.category,
      videoUrl: videoUrl ?? this.videoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      ctaText: ctaText ?? this.ctaText,
      companyName: companyName ?? this.companyName,
      companyDescription: companyDescription ?? this.companyDescription,
      companyImages: companyImages ?? this.companyImages,
      employeeImages: employeeImages ?? this.employeeImages,
      targetLocations: targetLocations ?? this.targetLocations,
      targetLanguages: targetLanguages ?? this.targetLanguages,
      targetInterests: targetInterests ?? this.targetInterests,
      targetAgeRange: targetAgeRange ?? this.targetAgeRange,
      targetGender: targetGender ?? this.targetGender,
      commentsDisabled: commentsDisabled ?? this.commentsDisabled,
      likesDisabled: likesDisabled ?? this.likesDisabled,
      sharingDisabled: sharingDisabled ?? this.sharingDisabled,
      hideViewCount: hideViewCount ?? this.hideViewCount,
      budgetRupees: budgetRupees ?? this.budgetRupees,
      coinsAllocated: coinsAllocated ?? this.coinsAllocated,
      coinsConsumed: coinsConsumed ?? this.coinsConsumed,
      coinsRemaining: coinsRemaining ?? this.coinsRemaining,
      estimatedRewards: estimatedRewards ?? this.estimatedRewards,
      estimatedReach: estimatedReach ?? this.estimatedReach,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      plan: plan ?? this.plan,
    );
  }
}

class AdvertiserAccount {
  final String id;
  final String companyName;
  final String? email;
  final String? phone;
  final AdPlan? currentPlan;
  final DateTime? planExpiresAt;
  final int totalCoinsPurchased;
  final int coinsAvailable;
  final int coinsConsumed;
  final DateTime createdAt;
  final bool kycVerified;
  final String? salesOfficerContact;

  AdvertiserAccount({
    required this.id,
    required this.companyName,
    this.email,
    this.phone,
    this.currentPlan,
    this.planExpiresAt,
    this.totalCoinsPurchased = 0,
    this.coinsAvailable = 0,
    this.coinsConsumed = 0,
    required this.createdAt,
    this.kycVerified = false,
    this.salesOfficerContact,
  });
}

class AdAnalytics {
  final String adId;
  final int totalImpressions;
  final int uniqueViewers;
  final int repeatViewers;
  final Map<String, int> reachByGeography; // Country/State/City
  final Map<String, int> reachByLanguage;
  final Map<String, int> reachByInterest;
  final int totalViews;
  final int validViews; // Rewarded views
  final double viewThroughRate; // VTR
  final double averageWatchDuration; // seconds
  final double completionRate; // percentage
  final Map<String, int> dropOffPoints; // 0-25%, 25-50%, etc.
  final double totalWatchHours;
  final double averageWatchTimePerView;
  final Map<String, double> watchHoursByDay;
  final Map<String, double> watchHoursByWeek;
  final Map<String, double> watchHoursByMonth;
  final Map<String, int> genderSplit;
  final Map<String, int> ageGroups;
  final int totalCoinsAllocated;
  final int coinsConsumed;
  final int coinsRemaining;
  final int rewardsIssued;
  final double averageCoinsPerUser;
  final double costPerValidReward;
  final double costPerWatchMinute;
  final int clickThroughRate;
  final int profileVisits;
  final int companyPageOpens;
  final int externalLinkClicks;
  final int followActions;
  final DateTime lastUpdated;

  AdAnalytics({
    required this.adId,
    this.totalImpressions = 0,
    this.uniqueViewers = 0,
    this.repeatViewers = 0,
    this.reachByGeography = const {},
    this.reachByLanguage = const {},
    this.reachByInterest = const {},
    this.totalViews = 0,
    this.validViews = 0,
    this.viewThroughRate = 0.0,
    this.averageWatchDuration = 0.0,
    this.completionRate = 0.0,
    this.dropOffPoints = const {},
    this.totalWatchHours = 0.0,
    this.averageWatchTimePerView = 0.0,
    this.watchHoursByDay = const {},
    this.watchHoursByWeek = const {},
    this.watchHoursByMonth = const {},
    this.genderSplit = const {},
    this.ageGroups = const {},
    this.totalCoinsAllocated = 0,
    this.coinsConsumed = 0,
    this.coinsRemaining = 0,
    this.rewardsIssued = 0,
    this.averageCoinsPerUser = 0.0,
    this.costPerValidReward = 0.0,
    this.costPerWatchMinute = 0.0,
    this.clickThroughRate = 0,
    this.profileVisits = 0,
    this.companyPageOpens = 0,
    this.externalLinkClicks = 0,
    this.followActions = 0,
    required this.lastUpdated,
  });
}
