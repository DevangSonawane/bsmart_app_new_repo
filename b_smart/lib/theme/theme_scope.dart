import 'package:flutter/material.dart';
import 'theme_notifier.dart';

/// Provides [ThemeNotifier] to the widget tree.
class ThemeScope extends InheritedNotifier<ThemeNotifier> {
  const ThemeScope({
    super.key,
    required ThemeNotifier super.notifier,
    required super.child,
  });

  static ThemeNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found. Wrap app with ThemeScope.');
    return scope!.notifier!;
  }
}
