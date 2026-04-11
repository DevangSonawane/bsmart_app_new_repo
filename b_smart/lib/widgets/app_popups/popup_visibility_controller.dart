import 'dart:math' as math;
import 'package:flutter/foundation.dart';

class PopupVisibilityController extends ValueNotifier<int> {
  PopupVisibilityController() : super(0);

  bool get isVisible => value > 0;

  void push() => value = value + 1;

  void pop() => value = math.max(0, value - 1);
}

