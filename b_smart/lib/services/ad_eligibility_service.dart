import '../models/ad_model.dart';

class AdWatchRecord {
  final String adId;
  final DateTime timestamp;
  final int coinsEarned;

  AdWatchRecord({
    required this.adId,
    required this.timestamp,
    required this.coinsEarned,
  });
}

class AdEligibilityService {
  static final AdEligibilityService _instance = AdEligibilityService._internal();
  factory AdEligibilityService() => _instance;

  // Eligibility Rules
  static const double minWatchPercentage = 0.90; // 90%
  static const int dailyEarningCap = 500; // coins per day
  static const int dailyAdViewLimit = 20; // ads per day
  static const int cooldownPeriodSeconds = 30; // seconds between ads
  static const int maxPauseCount = 3;
  static const int maxTotalPauseDuration = 10; // seconds

  // User watch history (in real app, this would be stored in database)
  final Map<String, List<AdWatchRecord>> _userWatchHistory = {};
  final Map<String, DateTime> _lastAdWatchTime = {};
  final Map<String, int> _dailyEarnings = {};
  final Map<String, int> _dailyAdViews = {};

  AdEligibilityService._internal();

  // Check if user is eligible to watch an ad
  EligibilityResult checkEligibility(String userId, Ad ad) {
    // Check if ad is already watched
    if (_hasWatchedAd(userId, ad.id)) {
      return EligibilityResult(
        isEligible: false,
        reason: 'You have already earned coins from this ad',
      );
    }

    // Check cooldown period
    if (_isInCooldown(userId)) {
      final lastWatch = _lastAdWatchTime[userId];
      if (lastWatch != null) {
        final cooldownEnd = lastWatch.add(Duration(seconds: cooldownPeriodSeconds));
        final remaining = cooldownEnd.difference(DateTime.now()).inSeconds;
        if (remaining > 0) {
          return EligibilityResult(
            isEligible: false,
            reason: 'Please wait $remaining seconds before watching another ad',
          );
        }
      }
    }

    // Check daily ad view limit
    if (_getDailyAdViews(userId) >= dailyAdViewLimit) {
      return EligibilityResult(
        isEligible: false,
        reason: 'Daily ad view limit reached ($dailyAdViewLimit ads/day)',
      );
    }

    // Check daily earning cap
    final dailyEarnings = _getDailyEarnings(userId);
    if (dailyEarnings + ad.coinReward > dailyEarningCap) {
      final remaining = dailyEarningCap - dailyEarnings;
      return EligibilityResult(
        isEligible: false,
        reason: remaining > 0
            ? 'Daily earning cap reached. You can earn $remaining more coins today'
            : 'Daily earning cap reached ($dailyEarningCap coins/day)',
      );
    }

    // Check if ad is exhausted
    if (ad.currentViews >= ad.maxRewardableViews) {
      return EligibilityResult(
        isEligible: false,
        reason: 'This ad has reached its maximum views',
      );
    }

    // Check if ad is active
    if (!ad.isActive) {
      return EligibilityResult(
        isEligible: false,
        reason: 'This ad is no longer available',
      );
    }

    return EligibilityResult(isEligible: true);
  }

  // Record ad watch
  void recordAdWatch(String userId, String adId, int coinsEarned) {
    if (!_userWatchHistory.containsKey(userId)) {
      _userWatchHistory[userId] = [];
    }
    _userWatchHistory[userId]!.add(
      AdWatchRecord(
        adId: adId,
        timestamp: DateTime.now(),
        coinsEarned: coinsEarned,
      ),
    );
    _lastAdWatchTime[userId] = DateTime.now();
    _dailyEarnings[userId] = (_dailyEarnings[userId] ?? 0) + coinsEarned;
    _dailyAdViews[userId] = (_dailyAdViews[userId] ?? 0) + 1;
  }

  // Check if user has watched this ad
  bool _hasWatchedAd(String userId, String adId) {
    final history = _userWatchHistory[userId];
    if (history == null) return false;
    return history.any((record) => record.adId == adId);
  }

  // Check cooldown
  bool _isInCooldown(String userId) {
    final lastWatch = _lastAdWatchTime[userId];
    if (lastWatch == null) return false;
    final elapsed = DateTime.now().difference(lastWatch).inSeconds;
    return elapsed < cooldownPeriodSeconds;
  }

  // Get daily ad views
  int _getDailyAdViews(String userId) {
    return _dailyAdViews[userId] ?? 0;
  }

  // Get daily earnings
  int _getDailyEarnings(String userId) {
    return _dailyEarnings[userId] ?? 0;
  }

  // Get remaining daily capacity
  DailyCapacity getDailyCapacity(String userId) {
    return DailyCapacity(
      remainingCoins: dailyEarningCap - (_dailyEarnings[userId] ?? 0),
      remainingAds: dailyAdViewLimit - (_dailyAdViews[userId] ?? 0),
      earnedToday: _dailyEarnings[userId] ?? 0,
      adsWatchedToday: _dailyAdViews[userId] ?? 0,
    );
  }

  // Reset daily counters (called at midnight)
  void resetDailyCounters(String userId) {
    _dailyEarnings[userId] = 0;
    _dailyAdViews[userId] = 0;
  }
}

class EligibilityResult {
  final bool isEligible;
  final String? reason;

  EligibilityResult({
    required this.isEligible,
    this.reason,
  });
}

class DailyCapacity {
  final int remainingCoins;
  final int remainingAds;
  final int earnedToday;
  final int adsWatchedToday;

  DailyCapacity({
    required this.remainingCoins,
    required this.remainingAds,
    required this.earnedToday,
    required this.adsWatchedToday,
  });
}
