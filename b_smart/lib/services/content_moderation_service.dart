import '../models/content_moderation_model.dart';
import '../models/reel_model.dart';
import '../models/media_model.dart';

class ContentModerationService {
  static final ContentModerationService _instance = ContentModerationService._internal();
  factory ContentModerationService() => _instance;

  final Map<String, UserStrikeRecord> _userStrikes = {};
  final Map<String, ContentModerationResult> _moderationCache = {};
  final String _currentUserId = 'user-1';

  // Thresholds
  static const double _safeThreshold = 0.2;
  static const double _mildThreshold = 0.5;
  static const double _sexualizedThreshold = 0.7;
  static const double _explicitThreshold = 0.9;

  ContentModerationService._internal() {
    _initializeUserStrikes();
  }

  void _initializeUserStrikes() {
    _userStrikes[_currentUserId] = UserStrikeRecord(userId: _currentUserId);
  }

  // Main moderation check for reels
  Future<ContentModerationResult> moderateReel({
    required Reel reel,
    bool isSponsored = false,
  }) async {
    // Check cache first
    if (_moderationCache.containsKey(reel.id)) {
      return _moderationCache[reel.id]!;
    }

    // Simulate AI/ML analysis delay
    await Future.delayed(const Duration(milliseconds: 500));

    double sexualScore = 0.0;
    bool nudityDetected = false;
    bool explicitActivity = false;
    bool suggestiveContent = false;
    List<String> flaggedElements = [];

    // Check caption
    if (reel.caption != null) {
      final captionScore = _analyzeText(reel.caption!);
      if (captionScore > 0) {
        sexualScore += captionScore * 0.3;
        flaggedElements.add('caption');
      }
    }

    // Check hashtags
    for (final hashtag in reel.hashtags) {
      final hashtagScore = _analyzeText(hashtag);
      if (hashtagScore > 0) {
        sexualScore += hashtagScore * 0.2;
        flaggedElements.add('hashtags');
        break;
      }
    }

    // Simulate video frame analysis (dummy)
    // In real app, this would analyze video frames
    if (reel.isSponsored) {
      // Stricter rules for sponsored content
      sexualScore += 0.1; // Add penalty for sponsored content
    }

    // Simulate audio analysis
    if (reel.audioTitle != null) {
      final audioScore = _analyzeText(reel.audioTitle!);
      if (audioScore > 0) {
        sexualScore += audioScore * 0.2;
        flaggedElements.add('audio');
      }
    }

    // Determine severity
    ContentSeverity severity;
    ModerationAction action;

    if (sexualScore >= _explicitThreshold) {
      severity = ContentSeverity.explicit;
      action = ModerationAction.block;
      nudityDetected = true;
      explicitActivity = true;
    } else if (sexualScore >= _sexualizedThreshold) {
      severity = ContentSeverity.sexualized;
      action = ModerationAction.restrict;
      suggestiveContent = true;
    } else if (sexualScore >= _mildThreshold) {
      severity = ContentSeverity.mildSuggestive;
      action = ModerationAction.allowWithRestrictions;
      suggestiveContent = true;
    } else {
      severity = ContentSeverity.safe;
      action = ModerationAction.allow;
    }

    // Stricter rules for sponsored content
    if (isSponsored && sexualScore > _safeThreshold) {
      action = ModerationAction.block;
      severity = ContentSeverity.explicit;
    }

    final result = ContentModerationResult(
      severity: severity,
      action: action,
      sexualScore: sexualScore.clamp(0.0, 1.0),
      nudityDetected: nudityDetected,
      explicitActivity: explicitActivity,
      suggestiveContent: suggestiveContent,
      reason: _getReason(severity, action),
      flaggedElements: flaggedElements,
    );

    // Cache result
    _moderationCache[reel.id] = result;

    return result;
  }

  // Moderate media upload (for Create screen)
  Future<ContentModerationResult> moderateMedia({
    required MediaItem media,
    String? caption,
    List<String>? hashtags,
    bool isSponsored = false,
  }) async {
    // Simulate analysis delay
    await Future.delayed(const Duration(milliseconds: 500));

    double sexualScore = 0.0;
    bool nudityDetected = false;
    bool explicitActivity = false;
    bool suggestiveContent = false;
    List<String> flaggedElements = [];

    // Check caption
    if (caption != null && caption.isNotEmpty) {
      final captionScore = _analyzeText(caption);
      if (captionScore > 0) {
        sexualScore += captionScore * 0.3;
        flaggedElements.add('caption');
      }
    }

    // Check hashtags
    if (hashtags != null) {
      for (final hashtag in hashtags) {
        final hashtagScore = _analyzeText(hashtag);
        if (hashtagScore > 0) {
          sexualScore += hashtagScore * 0.2;
          flaggedElements.add('hashtags');
          break;
        }
      }
    }

    // Simulate video/image analysis
    // In real app, this would analyze actual media frames
    if (media.type == MediaType.video) {
      // Simulate video frame analysis
      sexualScore += 0.05; // Dummy value
    }

    // Determine severity
    ContentSeverity severity;
    ModerationAction action;

    if (sexualScore >= _explicitThreshold) {
      severity = ContentSeverity.explicit;
      action = ModerationAction.block;
      nudityDetected = true;
      explicitActivity = true;
    } else if (sexualScore >= _sexualizedThreshold) {
      severity = ContentSeverity.sexualized;
      action = ModerationAction.restrict;
      suggestiveContent = true;
    } else if (sexualScore >= _mildThreshold) {
      severity = ContentSeverity.mildSuggestive;
      action = ModerationAction.allowWithRestrictions;
      suggestiveContent = true;
    } else {
      severity = ContentSeverity.safe;
      action = ModerationAction.allow;
    }

    // Stricter rules for sponsored content
    if (isSponsored && sexualScore > _safeThreshold) {
      action = ModerationAction.block;
      severity = ContentSeverity.explicit;
    }

    return ContentModerationResult(
      severity: severity,
      action: action,
      sexualScore: sexualScore.clamp(0.0, 1.0),
      nudityDetected: nudityDetected,
      explicitActivity: explicitActivity,
      suggestiveContent: suggestiveContent,
      reason: _getReason(severity, action),
      flaggedElements: flaggedElements,
    );
  }

  // Text analysis (simplified - in real app would use ML/NLP)
  double _analyzeText(String text) {
    final lowerText = text.toLowerCase();
    
    // Explicit terms (high score)
    final explicitTerms = ['explicit', 'nude', 'nudity', 'porn', 'xxx', 'sex'];
    for (final term in explicitTerms) {
      if (lowerText.contains(term)) {
        return 0.9;
      }
    }

    // Suggestive terms (medium score)
    final suggestiveTerms = ['sexy', 'hot', 'seductive', 'provocative', 'erotic'];
    for (final term in suggestiveTerms) {
      if (lowerText.contains(term)) {
        return 0.6;
      }
    }

    // Mild terms (low score)
    final mildTerms = ['fitness', 'beach', 'swimwear', 'dance'];
    for (final term in mildTerms) {
      if (lowerText.contains(term)) {
        return 0.3;
      }
    }

    return 0.0;
  }

  String _getReason(ContentSeverity severity, ModerationAction action) {
    switch (action) {
      case ModerationAction.block:
        return 'Your content violates our sexual content guidelines and cannot be published.';
      case ModerationAction.restrict:
        return 'Your content has been restricted due to sexualized content. It will not appear in recommendations.';
      case ModerationAction.allowWithRestrictions:
        return 'Your content has been published but with limited reach due to suggestive content.';
      case ModerationAction.allow:
        return 'Content approved.';
    }
  }

  // Check if user can post (based on strikes)
  bool canUserPost(String userId) {
    final strikeRecord = _userStrikes[userId];
    if (strikeRecord == null) return true;
    
    if (strikeRecord.isSuspended) return false;
    if (strikeRecord.policyStrikes >= 3) return false;
    
    return true;
  }

  // Add strike to user
  void addStrike(String userId, String violationType) {
    final current = _userStrikes[userId] ?? UserStrikeRecord(userId: userId);
    
    _userStrikes[userId] = current.copyWith(
      policyStrikes: current.policyStrikes + 1,
      lastViolation: violationType,
      lastViolationDate: DateTime.now(),
      isRestricted: current.policyStrikes >= 2,
      isSuspended: current.policyStrikes >= 3,
    );
  }

  // Get user strike record
  UserStrikeRecord? getUserStrikes(String userId) {
    return _userStrikes[userId];
  }

  // Report content
  Future<bool> reportContent({
    required String reelId,
    required String reportType,
    String? reason,
  }) async {
    // Simulate report submission
    await Future.delayed(const Duration(milliseconds: 300));
    
    // In real app, this would trigger backend re-scan
    // For now, just return success
    return true;
  }

  // Check if content should be shown to user (age gating)
  bool shouldShowContent({
    required ContentModerationResult moderationResult,
    required int userAge,
  }) {
    if (moderationResult.severity == ContentSeverity.explicit) {
      return false; // Never show explicit content
    }
    
    if (moderationResult.severity == ContentSeverity.sexualized) {
      return userAge >= 18; // Age-gated
    }
    
    return true; // Safe and mild suggestive can be shown
  }

  // Clear cache (for testing)
  void clearCache() {
    _moderationCache.clear();
  }
}
