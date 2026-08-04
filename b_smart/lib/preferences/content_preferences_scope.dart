import 'package:flutter/material.dart';

import 'content_preferences_notifier.dart';

class ContentPreferencesScope
    extends InheritedNotifier<ContentPreferencesNotifier> {
  const ContentPreferencesScope({
    super.key,
    required ContentPreferencesNotifier super.notifier,
    required super.child,
  });

  static ContentPreferencesNotifier of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ContentPreferencesScope>();
    assert(scope != null, 'ContentPreferencesScope not found.');
    return scope!.notifier!;
  }
}
