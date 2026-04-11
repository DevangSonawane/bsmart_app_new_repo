import 'dart:async';
import 'package:flutter/material.dart';

import '../../utils/app_navigator.dart';
import 'popup_visibility_controller.dart';

typedef AppPopupBuilder = Widget Function(
  BuildContext dialogContext,
  VoidCallback close,
);

class AppModalPopup {
  static Future<T?> show<T>({
    BuildContext? context,
    required AppPopupBuilder builder,
    bool barrierDismissible = true,
    Color barrierColor = const Color(0xB3000000),
    Duration transitionDuration = const Duration(milliseconds: 220),
    PopupVisibilityController? visibility,
    bool useRootNavigator = true,
  }) {
    return () async {
      BuildContext? popupContext = context;
      if (popupContext is Element && !popupContext.mounted) {
        popupContext = null;
      }
      popupContext ??= AppNavigator.state?.overlay?.context;
      popupContext ??= AppNavigator.context;
      if (popupContext == null) return null;

      // Avoid pushing routes while the framework is in the middle of a frame.
      await WidgetsBinding.instance.endOfFrame;

      visibility?.push();
      try {
        return await showGeneralDialog<T>(
          context: popupContext,
          useRootNavigator: useRootNavigator,
          barrierDismissible: barrierDismissible,
          barrierLabel: 'popup',
          barrierColor: barrierColor,
          transitionDuration: transitionDuration,
          pageBuilder: (dialogContext, _, __) {
            var closed = false;
            void close() {
              if (closed) return;
              closed = true;
              final route = ModalRoute.of(dialogContext);
              if (route?.isCurrent != true) return;
              Navigator.of(dialogContext, rootNavigator: useRootNavigator)
                  .pop<T>();
            }

            return SafeArea(
              child: Center(
                child: builder(dialogContext, close),
              ),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeIn,
            );
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: curved, child: child),
            );
          },
        );
      } finally {
        visibility?.pop();
      }
    }();
  }
}
