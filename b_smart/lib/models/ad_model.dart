class Ad {
  final String id;
  final String companyId;
  final String companyName;
  final String? companyLogo;
  final String title;
  final String description;
  final String? videoUrl;
  final String? imageUrl;
  final int coinReward; // Ad-specific reward
  final int watchDurationSeconds; // Required watch duration
  final int maxRewardableViews;
  final int currentViews;
  final List<String> targetLanguages;
  final List<String> targetCategories;
  final String? targetLocation;
  final bool isVerified;
  final String? websiteUrl;
  final DateTime createdAt;
  final bool isActive;

  Ad({
    required this.id,
    required this.companyId,
    required this.companyName,
    this.companyLogo,
    required this.title,
    required this.description,
    this.videoUrl,
    this.imageUrl,
    required this.coinReward,
    required this.watchDurationSeconds,
    required this.maxRewardableViews,
    this.currentViews = 0,
    this.targetLanguages = const [],
    this.targetCategories = const [],
    this.targetLocation,
    this.isVerified = false,
    this.websiteUrl,
    required this.createdAt,
    this.isActive = true,
  });
}

class AdCompany {
  final String id;
  final String name;
  final String? logo;
  final String description;
  final String? websiteUrl;
  final bool isVerified;
  final List<Ad> activeAds;

  AdCompany({
    required this.id,
    required this.name,
    this.logo,
    required this.description,
    this.websiteUrl,
    this.isVerified = false,
    this.activeAds = const [],
  });
}

class AdWatchSession {
  final String adId;
  final DateTime startTime;
  final int totalDuration;
  final int watchedDuration;
  final bool isMuted;
  final int pauseCount;
  final int totalPauseDuration;
  final bool isInForeground;
  final double watchPercentage;

  AdWatchSession({
    required this.adId,
    required this.startTime,
    required this.totalDuration,
    this.watchedDuration = 0,
    this.isMuted = false,
    this.pauseCount = 0,
    this.totalPauseDuration = 0,
    this.isInForeground = true,
    this.watchPercentage = 0.0,
  });

  AdWatchSession copyWith({
    String? adId,
    DateTime? startTime,
    int? totalDuration,
    int? watchedDuration,
    bool? isMuted,
    int? pauseCount,
    int? totalPauseDuration,
    bool? isInForeground,
    double? watchPercentage,
  }) {
    return AdWatchSession(
      adId: adId ?? this.adId,
      startTime: startTime ?? this.startTime,
      totalDuration: totalDuration ?? this.totalDuration,
      watchedDuration: watchedDuration ?? this.watchedDuration,
      isMuted: isMuted ?? this.isMuted,
      pauseCount: pauseCount ?? this.pauseCount,
      totalPauseDuration: totalPauseDuration ?? this.totalPauseDuration,
      isInForeground: isInForeground ?? this.isInForeground,
      watchPercentage: watchPercentage ?? this.watchPercentage,
    );
  }
}
