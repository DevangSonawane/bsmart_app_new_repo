import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

/// Shared configuration for one onboarding step.
///
/// The widget that owns the actual target keeps the [GlobalKey], while this
/// config keeps the text and presentation metadata close to the onboarding
/// flow itself.
class HomeOnboardingStep {
  final GlobalKey<State<StatefulWidget>> key;
  final String title;
  final String description;
  final bool isPrimaryAction;
  final TooltipPosition? tooltipPosition;

  const HomeOnboardingStep({
    required this.key,
    required this.title,
    required this.description,
    this.isPrimaryAction = false,
    this.tooltipPosition,
  });
}

/// Lightweight persistence and lifecycle bridge for the Home Screen tour.
///
/// This keeps SharedPreferences access isolated from the UI widgets and gives
/// tests a single reset entry point.
class HomeOnboardingService {
  HomeOnboardingService._();

  static final HomeOnboardingService instance = HomeOnboardingService._();

  static const String _completedKey = 'home_onboarding_completed_v1';

  VoidCallback? _onFinished;
  VoidCallback? _onDismissed;

  void bindCallbacks({
    VoidCallback? onFinished,
    VoidCallback? onDismissed,
  }) {
    _onFinished = onFinished;
    _onDismissed = onDismissed;
  }

  void clearCallbacks() {
    _onFinished = null;
    _onDismissed = null;
  }

  void handleFinished() {
    _onFinished?.call();
  }

  void handleDismissed() {
    _onDismissed?.call();
  }

  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, true);
  }

  /// Resets the onboarding state so the walkthrough can be tested again.
  Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completedKey);
  }
}
