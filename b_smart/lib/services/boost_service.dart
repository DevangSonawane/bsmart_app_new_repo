import '../models/boost_model.dart';
import '../models/user_account_model.dart';
import '../services/user_account_service.dart';

class BoostService {
  static final BoostService _instance = BoostService._internal();
  factory BoostService() => _instance;

  List<PostBoost> _boosts = [];
  final Map<String, BoostAnalytics> _analytics = {};
  final UserAccountService _accountService = UserAccountService();

  // Pricing per hour
  static const double baseCostPerHour = 0.50;
  
  // Quality thresholds
  static const double minEngagementRate = 0.01; // 1% minimum
  static const int maxImpressionsPerHour = 1000;
  static const int maxActiveBoostsPerUser = 3;

  BoostService._internal() {
    _initializeDummyBoosts();
    // Auto-check expired boosts periodically
    _startExpirationChecker();
  }

  void _startExpirationChecker() {
    // In real app, this would be a background service
    // For now, checks happen on-demand
  }

  void _initializeDummyBoosts() {
    final now = DateTime.now();
    _boosts = [
      PostBoost(
        id: 'boost-1',
        postId: 'post-1',
        userId: 'user-1',
        duration: BoostDuration.twentyFourHours,
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.add(const Duration(hours: 22)),
        status: BoostStatus.active,
        paymentStatus: BoostPaymentStatus.completed,
        cost: 12.0,
        paymentId: 'payment-1',
        targetImpressions: 5000,
        actualImpressions: 1200,
        engagementCount: 45,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
  }

  // Check if user can boost a post
  Future<BoostEligibilityResult> checkBoostEligibility({
    required String userId,
    required String postId,
    required String contentType, // 'post' or 'reel'
  }) async {
    // Check account type
    final account = _accountService.getAccount(userId);
    if (account == null || account.accountType == AccountType.regular) {
      return BoostEligibilityResult(
        isEligible: false,
        reason: 'Only Creator and Business accounts can boost content',
      );
    }

    // Check active boosts limit
    final activeBoosts = _boosts.where((b) => 
      b.userId == userId && b.status == BoostStatus.active
    ).length;
    
    if (activeBoosts >= maxActiveBoostsPerUser) {
      return BoostEligibilityResult(
        isEligible: false,
        reason: 'You have reached the maximum number of active boosts (${maxActiveBoostsPerUser})',
      );
    }

    // Check for duplicate boost (Edge Case 1.3)
    final existingBoost = _boosts.where((b) => 
      b.postId == postId && 
      (b.status == BoostStatus.active || b.status == BoostStatus.pending)
    ).firstOrNull;
    
    if (existingBoost != null) {
      return BoostEligibilityResult(
        isEligible: false,
        reason: 'This content already has an active boost',
      );
    }

    // Check content moderation (Edge Case 4.3)
    final hasViolations = account.hasPolicyViolations;
    if (hasViolations) {
      return BoostEligibilityResult(
        isEligible: false,
        reason: 'Content with policy violations cannot be boosted',
      );
    }

    return BoostEligibilityResult(isEligible: true);
  }

  // Calculate boost cost
  double calculateBoostCost(BoostDuration duration) {
    return baseCostPerHour * duration.hours;
  }

  // Create boost request
  Future<PostBoost?> createBoost({
    required String userId,
    required String postId,
    required BoostDuration duration,
  }) async {
    // Check eligibility
    final eligibility = await checkBoostEligibility(
      userId: userId,
      postId: postId,
      contentType: 'post',
    );

    if (!eligibility.isEligible) {
      throw Exception(eligibility.reason);
    }

    final cost = calculateBoostCost(duration);
    final now = DateTime.now();
    final endTime = now.add(Duration(hours: duration.hours));

    final boost = PostBoost(
      id: 'boost-${now.millisecondsSinceEpoch}',
      postId: postId,
      userId: userId,
      duration: duration,
      startTime: now,
      endTime: endTime,
      status: BoostStatus.pending,
      paymentStatus: BoostPaymentStatus.pending,
      cost: cost,
      createdAt: now,
    );

    _boosts.add(boost);
    return boost;
  }

  // Process payment and activate boost (Edge Cases 1.1, 1.2, 1.3)
  Future<bool> processPaymentAndActivate(String boostId) async {
    final boost = _boosts.firstWhere(
      (b) => b.id == boostId,
      orElse: () => throw Exception('Boost not found'),
    );

    // Edge Case 1.3: Check for duplicate payment
    if (boost.paymentStatus == BoostPaymentStatus.completed && boost.isActive) {
      // Duplicate payment detected - block it
      return false;
    }

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 1));

    // In real app, would call payment gateway here. For now, assume success.

    // Activate boost immediately
    final index = _boosts.indexWhere((b) => b.id == boostId);
    if (index != -1) {
      _boosts[index] = boost.copyWith(
        status: BoostStatus.active,
        paymentStatus: BoostPaymentStatus.completed,
        paymentId: 'payment-${DateTime.now().millisecondsSinceEpoch}',
      );
      
      // Initialize analytics
      _analytics[boostId] = BoostAnalytics(
        boostId: boostId,
        lastUpdated: DateTime.now(),
      );
    }

    return true;
  }

  // Handle duplicate payment prevention (Edge Case 1.3)
  Future<bool> handleDuplicatePayment(String boostId) async {
    final boost = _boosts.firstWhere(
      (b) => b.id == boostId,
      orElse: () => throw Exception('Boost not found'),
    );

    // If boost is already active, refund duplicate payment
    if (boost.isActive && boost.paymentStatus == BoostPaymentStatus.completed) {
      // In real app, would process refund
      return false; // Duplicate payment blocked
    }

    return true;
  }

  // Pause boost (Edge Case 4.1 - content reported)
  Future<bool> pauseBoost(String boostId, String reason) async {
    final index = _boosts.indexWhere((b) => b.id == boostId);
    if (index == -1) return false;

    final boost = _boosts[index];
    if (boost.status != BoostStatus.active) return false;

    _boosts[index] = boost.copyWith(
      status: BoostStatus.paused,
      pauseReason: reason,
      pausedAt: DateTime.now(),
    );

    return true;
  }

  // Cancel boost (Edge Case 4.2 - content removed)
  Future<bool> cancelBoost(String boostId, String reason, {bool refund = false}) async {
    final index = _boosts.indexWhere((b) => b.id == boostId);
    if (index == -1) return false;

    final boost = _boosts[index];
    
    _boosts[index] = boost.copyWith(
      status: BoostStatus.cancelled,
      cancellationReason: reason,
      cancelledAt: DateTime.now(),
      isRefunded: refund,
      paymentStatus: refund ? BoostPaymentStatus.refunded : boost.paymentStatus,
    );

    return true;
  }

  // Check and auto-end expired boosts (Edge Case 2.1)
  void checkAndEndExpiredBoosts() {
    for (int i = 0; i < _boosts.length; i++) {
      final boost = _boosts[i];
      if (boost.isActive && boost.isExpired) {
        _boosts[i] = boost.copyWith(
          status: BoostStatus.completed,
        );
      }
    }
  }

  // Get active boosts for a user
  List<PostBoost> getUserActiveBoosts(String userId) {
    return _boosts.where((b) => 
      b.userId == userId && b.status == BoostStatus.active
    ).toList();
  }

  // Get boost by ID
  PostBoost? getBoost(String boostId) {
    try {
      return _boosts.firstWhere((b) => b.id == boostId);
    } catch (e) {
      return null;
    }
  }

  // Get boost analytics
  BoostAnalytics? getBoostAnalytics(String boostId) {
    return _analytics[boostId];
  }

  // Update boost analytics (called by feed system)
  void updateBoostAnalytics(String boostId, {
    int? impressions,
    int? views,
    int? likes,
    int? comments,
    int? shares,
  }) {
    final analytics = _analytics[boostId];
    if (analytics == null) return;

    final totalEngagement = (likes ?? analytics.likes) + 
                          (comments ?? analytics.comments) + 
                          (shares ?? analytics.shares);
    final totalViews = views ?? analytics.views;
    final engagementRate = totalViews > 0 ? totalEngagement / totalViews : 0.0;

    _analytics[boostId] = BoostAnalytics(
      boostId: boostId,
      impressions: impressions ?? analytics.impressions,
      views: views ?? analytics.views,
      likes: likes ?? analytics.likes,
      comments: comments ?? analytics.comments,
      shares: shares ?? analytics.shares,
      engagementRate: engagementRate,
      lastUpdated: DateTime.now(),
    );

    // Edge Case 3.2: Check quality threshold - pause if engagement too low
    if (engagementRate < minEngagementRate && totalViews > 100) {
      final boost = getBoost(boostId);
      if (boost != null && boost.isActive) {
        pauseBoost(boostId, 'Low engagement rate detected - feed quality protection');
      }
    }
  }

  // Edge Case 4.2: Handle content removal - cancel all active boosts
  Future<void> handleContentRemoved(String postId) async {
    final activeBoosts = _boosts.where((b) => 
      b.postId == postId && b.status == BoostStatus.active
    ).toList();

    for (final boost in activeBoosts) {
      await cancelBoost(
        boost.id,
        'Content removed',
        refund: true, // Refund remaining duration
      );
    }
  }

  // Edge Case 4.1: Handle content report - pause boost
  Future<void> handleContentReported(String postId) async {
    final activeBoosts = _boosts.where((b) => 
      b.postId == postId && b.status == BoostStatus.active
    ).toList();

    for (final boost in activeBoosts) {
      await pauseBoost(boost.id, 'Content reported - under review');
    }
  }

  // Edge Case 5.1: Check for duplicate content abuse
  bool isDuplicateContent(String userId, String contentHash) {
    // In real app, would check content similarity
    // For now, return false
    return false;
  }

  // Get all boosts for a user
  List<PostBoost> getUserBoosts(String userId) {
    return _boosts.where((b) => b.userId == userId).toList();
  }
}

class BoostEligibilityResult {
  final bool isEligible;
  final String? reason;

  BoostEligibilityResult({
    required this.isEligible,
    this.reason,
  });
}
