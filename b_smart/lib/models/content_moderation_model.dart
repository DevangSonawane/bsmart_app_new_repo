enum ContentSeverity {
  safe,
  mildSuggestive,
  sexualized,
  explicit,
}

enum ModerationAction {
  allow,
  allowWithRestrictions,
  restrict,
  block,
}

class ContentModerationResult {
  final ContentSeverity severity;
  final ModerationAction action;
  final double sexualScore;
  final bool nudityDetected;
  final bool explicitActivity;
  final bool suggestiveContent;
  final String? reason;
  final List<String> flaggedElements; // e.g., ['caption', 'hashtags', 'video_frames']

  ContentModerationResult({
    required this.severity,
    required this.action,
    required this.sexualScore,
    this.nudityDetected = false,
    this.explicitActivity = false,
    this.suggestiveContent = false,
    this.reason,
    this.flaggedElements = const [],
  });

  bool get isBlocked => action == ModerationAction.block;
  bool get isRestricted => action == ModerationAction.restrict;
  bool get hasRestrictions => action == ModerationAction.allowWithRestrictions;
}

class UserStrikeRecord {
  final String userId;
  final int policyStrikes;
  final String? lastViolation;
  final DateTime? lastViolationDate;
  final bool isRestricted;
  final bool isSuspended;

  UserStrikeRecord({
    required this.userId,
    this.policyStrikes = 0,
    this.lastViolation,
    this.lastViolationDate,
    this.isRestricted = false,
    this.isSuspended = false,
  });

  UserStrikeRecord copyWith({
    String? userId,
    int? policyStrikes,
    String? lastViolation,
    DateTime? lastViolationDate,
    bool? isRestricted,
    bool? isSuspended,
  }) {
    return UserStrikeRecord(
      userId: userId ?? this.userId,
      policyStrikes: policyStrikes ?? this.policyStrikes,
      lastViolation: lastViolation ?? this.lastViolation,
      lastViolationDate: lastViolationDate ?? this.lastViolationDate,
      isRestricted: isRestricted ?? this.isRestricted,
      isSuspended: isSuspended ?? this.isSuspended,
    );
  }
}

class ContentReport {
  final String id;
  final String reelId;
  final String reporterUserId;
  final String reportType; // 'sexual_content', 'inappropriate', etc.
  final String? reason;
  final DateTime reportedAt;
  final bool isReviewed;
  final bool isResolved;

  ContentReport({
    required this.id,
    required this.reelId,
    required this.reporterUserId,
    required this.reportType,
    this.reason,
    required this.reportedAt,
    this.isReviewed = false,
    this.isResolved = false,
  });
}
