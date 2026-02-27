enum BoostStatus {
  pending,
  active,
  paused,
  completed,
  cancelled,
  refunded,
}

enum BoostDuration {
  oneHour(1),
  sixHours(6),
  twelveHours(12),
  twentyFourHours(24),
  fortyEightHours(48);

  final int hours;
  const BoostDuration(this.hours);
}

enum BoostPaymentStatus {
  pending,
  processing,
  completed,
  failed,
  refunded,
}

class PostBoost {
  final String id;
  final String postId;
  final String userId;
  final BoostDuration duration;
  final DateTime startTime;
  final DateTime? endTime;
  final BoostStatus status;
  final BoostPaymentStatus paymentStatus;
  final double cost;
  final String? paymentId;
  final int targetImpressions;
  final int actualImpressions;
  final int engagementCount;
  final String? pauseReason;
  final String? cancellationReason;
  final bool isRefunded;
  final DateTime createdAt;
  final DateTime? pausedAt;
  final DateTime? cancelledAt;
  final Map<String, dynamic>? metadata;

  PostBoost({
    required this.id,
    required this.postId,
    required this.userId,
    required this.duration,
    required this.startTime,
    this.endTime,
    this.status = BoostStatus.pending,
    this.paymentStatus = BoostPaymentStatus.pending,
    required this.cost,
    this.paymentId,
    this.targetImpressions = 0,
    this.actualImpressions = 0,
    this.engagementCount = 0,
    this.pauseReason,
    this.cancellationReason,
    this.isRefunded = false,
    required this.createdAt,
    this.pausedAt,
    this.cancelledAt,
    this.metadata,
  });

  PostBoost copyWith({
    String? id,
    String? postId,
    String? userId,
    BoostDuration? duration,
    DateTime? startTime,
    DateTime? endTime,
    BoostStatus? status,
    BoostPaymentStatus? paymentStatus,
    double? cost,
    String? paymentId,
    int? targetImpressions,
    int? actualImpressions,
    int? engagementCount,
    String? pauseReason,
    String? cancellationReason,
    bool? isRefunded,
    DateTime? createdAt,
    DateTime? pausedAt,
    DateTime? cancelledAt,
    Map<String, dynamic>? metadata,
  }) {
    return PostBoost(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      duration: duration ?? this.duration,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      cost: cost ?? this.cost,
      paymentId: paymentId ?? this.paymentId,
      targetImpressions: targetImpressions ?? this.targetImpressions,
      actualImpressions: actualImpressions ?? this.actualImpressions,
      engagementCount: engagementCount ?? this.engagementCount,
      pauseReason: pauseReason ?? this.pauseReason,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      isRefunded: isRefunded ?? this.isRefunded,
      createdAt: createdAt ?? this.createdAt,
      pausedAt: pausedAt ?? this.pausedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isActive => status == BoostStatus.active;
  bool get isExpired => endTime != null && DateTime.now().isAfter(endTime!);
  Duration? get remainingDuration {
    if (endTime == null) return null;
    final remaining = endTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class BoostAnalytics {
  final String boostId;
  final int impressions;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final double engagementRate;
  final DateTime lastUpdated;

  BoostAnalytics({
    required this.boostId,
    this.impressions = 0,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.engagementRate = 0.0,
    required this.lastUpdated,
  });
}
