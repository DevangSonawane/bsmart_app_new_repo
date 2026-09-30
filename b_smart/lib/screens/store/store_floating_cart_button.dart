import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../services/ui_prefs.dart';
import 'store_models.dart';
import 'store_theme.dart';

/// Draggable floating cart bubble for the store shell.
///
/// Mirrors the interaction model of [FloatingMessageOverlay]: drag it
/// anywhere, and drop it on the trash zone that appears while dragging to
/// dismiss. Visibility is persisted so it stays hidden across app restarts.
class StoreFloatingCartButton extends StatefulWidget {
  final VoidCallback? onTap;

  const StoreFloatingCartButton({super.key, this.onTap});

  @override
  State<StoreFloatingCartButton> createState() =>
      _StoreFloatingCartButtonState();
}

class _StoreFloatingCartButtonState extends State<StoreFloatingCartButton>
    with SingleTickerProviderStateMixin {
  static const double _iconSize = 56;
  static const double _margin = 16;

  Offset _offset = Offset.zero;
  bool _hasPosition = false;
  bool _isDragging = false;
  bool _isNearTrash = false;

  late final AnimationController _trashAnimController;
  late final Animation<double> _trashScaleAnim;

  @override
  void initState() {
    super.initState();
    _trashAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _trashScaleAnim = CurvedAnimation(
      parent: _trashAnimController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _trashAnimController.dispose();
    super.dispose();
  }

  Offset _clampOffset(Offset next, Size maxSize, EdgeInsets padding) {
    final maxX = maxSize.width - _iconSize - _margin;
    final maxY = maxSize.height - _iconSize - _margin - padding.bottom;
    return Offset(
      next.dx.clamp(_margin, maxX.clamp(_margin, double.infinity)),
      next.dy.clamp(_margin + padding.top, maxY.clamp(0.0, double.infinity)),
    );
  }

  static bool _checkNearTrash(Offset iconOffset, Rect trashRect) {
    final center = Offset(
      iconOffset.dx + _iconSize / 2,
      iconOffset.dy + _iconSize / 2,
    );
    return (center - trashRect.center).distance < 72;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: UiPrefs.showFloatingCart,
      builder: (context, isVisible, _) {
        if (!isVisible) return const SizedBox.shrink();

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            if (size.isEmpty) return const SizedBox.shrink();

            final padding = MediaQuery.of(context).padding;
            final defaultOffset = Offset(
              size.width - _iconSize - _margin,
              size.height - _iconSize - _margin - padding.bottom,
            );

            if (!_hasPosition) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _offset = _clampOffset(defaultOffset, size, padding);
                  _hasPosition = true;
                });
              });
            }

            final effectiveOffset = _hasPosition
                ? _offset
                : _clampOffset(defaultOffset, size, padding);

            const trashSize = 68.0;
            final trashBottom = padding.bottom + 24.0;
            final trashLeft = (size.width - trashSize) / 2;
            final trashTop = size.height - trashBottom - trashSize;
            final trashRect =
                Rect.fromLTWH(trashLeft, trashTop, trashSize, trashSize);

            // Snap toward the trash while hovered so the drop feels deliberate.
            final displayOffset = _isNearTrash
                ? Offset(
                    trashRect.center.dx - _iconSize / 2,
                    trashRect.center.dy - _iconSize / 2,
                  )
                : effectiveOffset;

            return Stack(
              children: [
                if (_isDragging)
                  Positioned(
                    left: trashLeft,
                    top: trashTop,
                    child: ScaleTransition(
                      scale: _trashScaleAnim,
                      child: Container(
                        width: trashSize,
                        height: trashSize,
                        decoration: BoxDecoration(
                          color: _isNearTrash
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _isNearTrash
                                ? Colors.red.withValues(alpha: 0.6)
                                : BStoreColors.border,
                            width: _isNearTrash ? 1.5 : 1,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.trash2,
                          color: _isNearTrash
                              ? Colors.red
                              : BStoreColors.textSecondary,
                          size: 30,
                        ),
                      ),
                    ),
                  ),

                AnimatedPositioned(
                  duration: _isNearTrash
                      ? const Duration(milliseconds: 200)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  left: displayOffset.dx,
                  top: displayOffset.dy,
                  child: GestureDetector(
                    onTap: _isDragging ? null : widget.onTap,
                    onPanStart: (_) {
                      setState(() => _isDragging = true);
                      _trashAnimController.forward();
                    },
                    onPanUpdate: (details) {
                      if (_isNearTrash) return;
                      final next = _offset + details.delta;
                      final clamped = _clampOffset(next, size, padding);
                      final nearTrash = _checkNearTrash(clamped, trashRect);
                      setState(() {
                        _offset = clamped;
                        _hasPosition = true;
                        _isNearTrash = nearTrash;
                      });
                    },
                    onPanEnd: (_) {
                      if (_isNearTrash) {
                        UiPrefs.showFloatingCart.value = false;
                      }
                      _trashAnimController.reverse();
                      if (mounted) {
                        setState(() {
                          _isDragging = false;
                          _isNearTrash = false;
                        });
                      }
                    },
                    onPanCancel: () {
                      _trashAnimController.reverse();
                      if (mounted) {
                        setState(() {
                          _isDragging = false;
                          _isNearTrash = false;
                        });
                      }
                    },
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutBack,
                      scale: _isNearTrash ? 0.85 : 1.0,
                      child: AnimatedBuilder(
                        animation: StoreMockState.instance,
                        builder: (context, _) {
                          final count = StoreMockState.instance.cartCount;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: _iconSize,
                                height: _iconSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isNearTrash
                                      ? Colors.red.withValues(alpha: 0.15)
                                      : BStoreColors.primary,
                                  border: _isNearTrash
                                      ? Border.all(
                                          color: Colors.red.withValues(
                                              alpha: 0.5),
                                          width: 1.5,
                                        )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: 0.18),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  LucideIcons.shoppingCart,
                                  color: _isNearTrash
                                      ? Colors.red
                                      : Colors.white,
                                  size: 26,
                                ),
                              ),
                              if (count > 0 && !_isNearTrash)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    constraints: const BoxConstraints(
                                        minWidth: 22, minHeight: 22),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: BStoreColors.primary,
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                              alpha: 0.12),
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
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}