import 'dart:async';
import 'package:flutter/material.dart';

import '../../utils/app_navigator.dart';
import 'popup_visibility_controller.dart';

class AppToast {
  static OverlayEntry? _entry;
  static Timer? _timer;
  static PopupVisibilityController? _visibility;
  static bool _visibilityPushed = false;

  static void _hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
    if (_visibilityPushed) {
      _visibility?.pop();
    }
    _visibilityPushed = false;
    _visibility = null;
  }

  static Future<void> show({
    BuildContext? context,
    required Widget child,
    Duration duration = const Duration(seconds: 3),
    PopupVisibilityController? visibility,
  }) async {
    final overlayContext = context ??
        AppNavigator.state?.overlay?.context ??
        AppNavigator.context;
    if (overlayContext == null) return;

    // Ensure we don't push an OverlayEntry during build.
    await WidgetsBinding.instance.endOfFrame;

    final overlay = Overlay.of(overlayContext, rootOverlay: true);
    if (overlay == null) return;

    _hide();
    _visibility = visibility;
    if (visibility != null) {
      visibility.push();
      _visibilityPushed = true;
    }

    final entry = OverlayEntry(
      builder: (_) {
        return _ToastHost(
          onDismissed: () {
            _hide();
          },
          child: child,
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(duration, () {
      _hide();
    });
  }

  static Future<void> showCoinEarned({
    BuildContext? context,
    required int amount,
    PopupVisibilityController? visibility,
  }) {
    return show(
      context: context,
      duration: const Duration(seconds: 3),
      visibility: visibility,
      child: _CoinEarnedToast(amount: amount),
    );
  }
}

class _ToastHost extends StatefulWidget {
  final VoidCallback onDismissed;
  final Widget child;

  const _ToastHost({
    required this.onDismissed,
    required this.child,
  });

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onDismissed,
          behavior: HitTestBehavior.translucent,
          child: Center(
            child: FadeTransition(
              opacity: _controller,
              child: ScaleTransition(
                scale: curved,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinEarnedToast extends StatelessWidget {
  final int amount;

  const _CoinEarnedToast({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFCD34D),
            ),
            alignment: Alignment.center,
            child: const Text(
              'B',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7C2D12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+$amount Coins Earned!',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
