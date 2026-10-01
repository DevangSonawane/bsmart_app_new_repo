import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/ui_prefs.dart';
import '../../widgets/draggable_floating_bubble.dart';
import 'store_models.dart';
import 'store_theme.dart';

/// Draggable floating cart bubble for the store shell.
///
/// Same interaction model as the messenger floater: drag it anywhere, drop it
/// on the trash zone to dismiss. [DraggableFloatingBubble] persists the
/// position and the dismissed state; re-enable it from Settings > Messaging >
/// Floating Messages.
///
/// The bubble is offset above the store footer nav via
/// [footerNavClearance] so it never covers the navigation bar.
class StoreFloatingCartButton extends StatelessWidget {
  final VoidCallback? onTap;

  /// Height of the store footer nav plus its own padding, reserved at the
  /// bottom of the store shell so the bubble floats above it.
  static const double footerNavClearance = 80;

  const StoreFloatingCartButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return const SizedBox.shrink();

    return DraggableFloatingBubble(
      visible: UiPrefs.showFloatingCart,
      persistenceKey: 'floating_store_cart',
      onTap: onTap,
      bottomChromeInset: footerNavClearance,
      backgroundColor: BStoreColors.primary,
      foregroundColor: Colors.white,
      shadowAlpha: 0.18,
      icon: const Icon(LucideIcons.shoppingCart),
      badge: AnimatedBuilder(
        animation: StoreMockState.instance,
        builder: (context, _) {
          final count = StoreMockState.instance.cartCount;
          if (count <= 0) return const SizedBox.shrink();
          return Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: BStoreColors.primary, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: BStoreColors.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}