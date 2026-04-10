import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/ui_prefs.dart';

class FloatingMessageOverlay extends StatefulWidget {
  final VoidCallback? onTap;
  final bool enabled;

  const FloatingMessageOverlay({
    super.key,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<FloatingMessageOverlay> createState() =>
      _FloatingMessageOverlayState();
}

class _FloatingMessageOverlayState extends State<FloatingMessageOverlay>
    with SingleTickerProviderStateMixin {
  static const double _iconSize = 56;
  static const double _margin = 16;

  Offset _offset = Offset.zero;
  bool _hasPosition = false;
  bool _isDragging = false;
  bool _isNearTrash = false;

  late AnimationController _trashAnimController;
  late Animation<double> _trashScaleAnim;

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
    final minX = _margin;
    final minY = _margin + padding.top;
    return Offset(
      next.dx.clamp(minX, maxX),
      next.dy.clamp(minY, maxY),
    );
  }

  bool _checkNearTrash(Offset iconOffset, Rect trashRect) {
    final center = Offset(
      iconOffset.dx + _iconSize / 2,
      iconOffset.dy + _iconSize / 2,
    );
    // Generous proximity radius so snapping feels natural
    final trashCenter = trashRect.center;
    final distance = (center - trashCenter).distance;
    return distance < 72;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0xFF111827) : Colors.white;
    final iconFg = isDark ? Colors.white : const Color(0xFF111827);
    final trashBg = isDark
        ? Colors.black.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.9);
    final trashBorder =
        isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.12);

    return ValueListenableBuilder<bool>(
      valueListenable: UiPrefs.showFloatingMessage,
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

            final effectiveOffset =
                _hasPosition ? _offset : _clampOffset(defaultOffset, size, padding);

            const trashSize = 68.0;
            final trashBottom = padding.bottom + 24.0;
            final trashLeft = (size.width - trashSize) / 2;
            final trashTop = size.height - trashBottom - trashSize;
            final trashRect =
                Rect.fromLTWH(trashLeft, trashTop, trashSize, trashSize);

            // Snap icon toward trash center when close
            final displayOffset = _isNearTrash
                ? Offset(
                    trashRect.center.dx - _iconSize / 2,
                    trashRect.center.dy - _iconSize / 2,
                  )
                : effectiveOffset;

            return Stack(
              children: [
                // Trash zone — only visible while dragging
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
                              : trashBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _isNearTrash
                                ? Colors.red.withValues(alpha: 0.6)
                                : trashBorder,
                            width: _isNearTrash ? 1.5 : 1,
                          ),
                        ),
                        child: Icon(
                          _isNearTrash
                              ? LucideIcons.trash2
                              : LucideIcons.trash2,
                          color: _isNearTrash
                              ? Colors.red
                              : (isDark ? Colors.white : const Color(0xFF111827)),
                          size: _isNearTrash ? 32 : 28,
                        ),
                      ),
                    ),
                  ),

                // Floating button
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
                      if (_isNearTrash) return; // locked to snap position

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
                        // Dismiss
                        UiPrefs.showFloatingMessage.value = false;
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
                      child: Container(
                        width: _iconSize,
                        height: _iconSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isNearTrash ? Colors.red.withValues(alpha: 0.15) : iconBg,
                          border: _isNearTrash
                              ? Border.all(
                                  color: Colors.red.withValues(alpha: 0.5),
                                  width: 1.5,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          LucideIcons.messageCircle,
                          color: _isNearTrash ? Colors.red : iconFg,
                          size: 26,
                        ),
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