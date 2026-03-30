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

class _FloatingMessageOverlayState extends State<FloatingMessageOverlay> {
  static const double _iconSize = 56;
  static const double _margin = 16;

  Offset _offset = Offset.zero;
  bool _hasPosition = false;
  bool _deleteMode = false;

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

            final trashSize = 68.0;
            final trashBottom = padding.bottom + 24;
            final trashLeft = (size.width - trashSize) / 2;
            final trashTop = size.height - trashBottom - trashSize;
            final trashRect =
                Rect.fromLTWH(trashLeft, trashTop, trashSize, trashSize);

            return Stack(
              children: [
                if (_deleteMode)
                  Positioned(
                    left: trashLeft,
                    top: trashTop,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 160),
                      scale: _deleteMode ? 1 : 0.9,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: _deleteMode ? 1 : 0,
                        child: Container(
                          width: trashSize,
                          height: trashSize,
                          decoration: BoxDecoration(
                            color: trashBg,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: trashBorder),
                          ),
                          child: Icon(
                            LucideIcons.trash2,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: effectiveOffset.dx,
                  top: effectiveOffset.dy,
                  child: GestureDetector(
                    onTap: _deleteMode ? null : widget.onTap,
                    onLongPressStart: (_) {
                      setState(() => _deleteMode = true);
                    },
                    onLongPressEnd: (_) {
                      if (mounted) {
                        setState(() => _deleteMode = false);
                      }
                    },
                    onPanUpdate: (details) {
                      final next = _offset + details.delta;
                      setState(() {
                        _offset = _clampOffset(next, size, padding);
                        _hasPosition = true;
                      });
                    },
                    onPanEnd: (_) {
                      if (_deleteMode) {
                        final center = Offset(
                          _offset.dx + _iconSize / 2,
                          _offset.dy + _iconSize / 2,
                        );
                        if (trashRect.contains(center)) {
                          UiPrefs.showFloatingMessage.value = false;
                        }
                      }
                      if (mounted) {
                        setState(() => _deleteMode = false);
                      }
                    },
                    child: Container(
                      width: _iconSize,
                      height: _iconSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: iconBg,
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
                        color: iconFg,
                        size: 26,
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
