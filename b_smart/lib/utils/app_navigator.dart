import 'package:flutter/material.dart';

class AppNavigator {
  static final GlobalKey<NavigatorState> key =
      GlobalKey<NavigatorState>(debugLabel: 'app-navigator');

  static BuildContext? get context => key.currentContext;
  static NavigatorState? get state => key.currentState;
}

