import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Small pin badge shown on pinned posts (profile grid, feed card header).
/// See `docs/pinned-posts.md`.
class PinnedBadge extends StatelessWidget {
  /// `overlay` = dark pill for drawing on top of media (grid tiles);
  /// otherwise a plain inline icon tinted with [color].
  final bool overlay;
  final Color? color;
  final double size;

  const PinnedBadge({
    super.key,
    this.overlay = false,
    this.color,
    this.size = 13,
  });

  @override
  Widget build(BuildContext context) {
    final icon = Transform.rotate(
      angle: 0.6,
      child: Icon(
        LucideIcons.pin,
        size: size,
        color: overlay ? Colors.white : (color ?? Colors.white70),
      ),
    );
    final child = Semantics(label: 'Pinned post', child: icon);
    if (!overlay) return child;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}
