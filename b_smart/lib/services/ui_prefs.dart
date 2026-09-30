import 'package:flutter/foundation.dart';

class UiPrefs {
  static final ValueNotifier<bool> showFloatingMessage =
      ValueNotifier<bool>(true);

  /// Store-shell cart bubble. Dismissed by dragging it onto the trash zone.
  static final ValueNotifier<bool> showFloatingCart =
      ValueNotifier<bool>(true);
}
