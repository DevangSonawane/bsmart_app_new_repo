import 'package:flutter/material.dart';

import 'storage_preferences_notifier.dart';

class StoragePreferencesScope
    extends InheritedNotifier<StoragePreferencesNotifier> {
  const StoragePreferencesScope({
    super.key,
    required StoragePreferencesNotifier super.notifier,
    required super.child,
  });

  static StoragePreferencesNotifier of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<StoragePreferencesScope>();
    assert(scope != null, 'StoragePreferencesScope not found.');
    return scope!.notifier!;
  }
}
