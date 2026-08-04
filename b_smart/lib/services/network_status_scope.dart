import 'package:flutter/material.dart';

import 'network_status_notifier.dart';

class NetworkStatusScope extends InheritedNotifier<NetworkStatusNotifier> {
  const NetworkStatusScope({
    super.key,
    required NetworkStatusNotifier super.notifier,
    required super.child,
  });

  static NetworkStatusNotifier of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<NetworkStatusScope>();
    assert(scope != null, 'NetworkStatusScope not found.');
    return scope!.notifier!;
  }
}
