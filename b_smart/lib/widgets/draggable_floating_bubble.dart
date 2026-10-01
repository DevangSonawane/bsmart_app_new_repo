import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared implementation behind every draggable floating bubble in the app
/// (messenger floater, store cart floater).
///
/// Interaction model: press and drag the bubble anywhere on screen. A trash
/// zone appears at the bottom while dragging; release over it to dismiss the
/// bubble. Released anywhere else the bubble stays where it was dropped.
///
/// Both the resolved position and the hidden state are persisted to
/// [SharedPreferences] under [persistenceKey], so a bubble keeps its spot
/// across restarts and a dismissed bubble stays hidden until its `visible`
/// notifier is flipped back on.
class DraggableFloatingBubble extends StatefulWidget {
  /// Icon rendered inside the bubble. Badges belong in [badge].
  final Widget icon;

  /// Optional overlay drawn outside the bubble circle, e.g. a count pill or an
  /// unread dot.
  final Widget? badge;

  /// Fired when the bubble is tapped without being dragged.
  final VoidCallback? onTap;

  /// Drives visibility and receives `false` when the bubble is dropped on the
  /// trash zone. When false the bubble renders nothing.
  final ValueNotifier<bool> visible;

  /// Clearance kept between the bubble and the screen edges.
  final EdgeInsets edgeMargin;

  /// Extra bottom inset that keeps the bubble clear of persistent chrome such
  /// as a bottom navigation bar, on top of the system safe area.
  final double bottomChromeInset;

  final Color backgroundColor;
  final Color foregroundColor;

  /// Opacity of the drop shadow behind the bubble.
  final double shadowAlpha;

  /// SharedPreferences key prefix for the persisted position and hidden flag.
  final String persistenceKey;

  const DraggableFloatingBubble({
    super.key,
    required this.icon,
    required this.visible,
    required this.persistenceKey,
    this.badge,
    this.onTap,
    this.edgeMargin = const EdgeInsets.all(16),
    this.bottomChromeInset = 0,
    this.backgroundColor = Colors.white,
    this.foregroundColor = const Color(0xFF111827),
    this.shadowAlpha = 0.35,
  });

  /// Diameter of the circular bubble.
  static const double bubbleSize = 56;

  @override
  State<DraggableFloatingBubble> createState() =>
      _DraggableFloatingBubbleState();
}

class _DraggableFloatingBubbleState extends State<DraggableFloatingBubble>
    with SingleTickerProviderStateMixin {
  static const double _trashSize = 68;
  static const double _trashHitRadius = 72;
  static const double _trashGap = 24;

  Offset _offset = Offset.zero;
  bool _hasPosition = false;
  bool _isDragging = false;
  bool _isNearTrash = false;

  late final AnimationController _trashAnimController;
  late final Animation<double> _trashScaleAnim;

  String get _prefsPosKey => '${widget.persistenceKey}.pos';
  String get _prefsHiddenKey => '${widget.persistenceKey}.hidden';
  String get _prefsXKey => '$_prefsPosKey.x';
  String get _prefsYKey => '$_prefsPosKey.y';

  @override
  void initState() {
    super.initState();
    _trashAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..value = 0;
    _trashScaleAnim = CurvedAnimation(
      parent: _trashAnimController,
      curve: Curves.easeOutBack,
    );
    widget.visible.addListener(_persistHidden);
    _restore();
  }

  @override
  void didUpdateWidget(covariant DraggableFloatingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) {
      oldWidget.visible.removeListener(_persistHidden);
      widget.visible.addListener(_persistHidden);
    }
    if (oldWidget.persistenceKey != widget.persistenceKey) {
      _hasPosition = false;
      _restore();
    }
  }

  @override
  void dispose() {
    widget.visible.removeListener(_persistHidden);
    _trashAnimController.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool(_prefsHiddenKey) ?? false) {
      widget.visible.value = false;
    }
    final x = prefs.getDouble(_prefsXKey);
    final y = prefs.getDouble(_prefsYKey);
    if (x == null || y == null) return;
    // Ignore a stored position from a different screen size; _clampOffset
    // fixes it on the next layout either way.
    setState(() {
      _offset = Offset(x, y);
      _hasPosition = true;
    });
  }

  void _persistPosition() {
    if (!_hasPosition) return;
    final x = _offset.dx;
    final y = _offset.dy;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(_prefsXKey, x);
      prefs.setDouble(_prefsYKey, y);
    });
  }

  void _persistHidden() {
    final hidden = !widget.visible.value;
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_prefsHiddenKey, hidden));
  }

  Offset _clampOffset(Offset next, Size size, EdgeInsets padding) {
    final margin = widget.edgeMargin;
    final minX = margin.left;
    final maxX = (size.width - DraggableFloatingBubble.bubbleSize - margin.right)
        .clamp(minX, double.infinity);
    final minY = margin.top + padding.top;
    final maxY = (size.height -
            DraggableFloatingBubble.bubbleSize -
            margin.bottom -
            padding.bottom -
            widget.bottomChromeInset)
        .clamp(minY, double.infinity);
    return Offset(next.dx.clamp(minX, maxX), next.dy.clamp(minY, maxY));
  }

  bool _checkNearTrash(Offset iconOffset, Rect trashRect) {
    final center = Offset(
      iconOffset.dx + DraggableFloatingBubble.bubbleSize / 2,
      iconOffset.dy + DraggableFloatingBubble.bubbleSize / 2,
    );
    return (center - trashRect.center).distance < _trashHitRadius;
  }

  void _handleDragEnd() {
    if (_isNearTrash) {
      widget.visible.value = false;
    } else {
      _persistPosition();
    }
    _trashAnimController.reverse();
    if (!mounted) return;
    setState(() {
      _isDragging = false;
      _isNearTrash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.visible,
      builder: (context, isVisible, _) {
        if (!isVisible) return const SizedBox.shrink();

        return LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            if (size.isEmpty) return const SizedBox.shrink();

            final padding = MediaQuery.of(context).padding;
            final margin = widget.edgeMargin;
            final defaultOffset = Offset(
              size.width - DraggableFloatingBubble.bubbleSize - margin.right,
              size.height -
                  DraggableFloatingBubble.bubbleSize -
                  margin.bottom -
                  padding.bottom -
                  widget.bottomChromeInset,
            );

            if (!_hasPosition) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _hasPosition) return;
                setState(() {
                  _offset = _clampOffset(defaultOffset, size, padding);
                  _hasPosition = true;
                });
                _persistPosition();
              });
            }

            // Clamp on every layout so a position restored from disk, or one
            // held over a rotated / resized screen, stays reachable.
            final effectiveOffset = _hasPosition
                ? _clampOffset(_offset, size, padding)
                : _clampOffset(defaultOffset, size, padding);

            final trashBottom = padding.bottom +
                widget.bottomChromeInset +
                _trashGap;
            final trashLeft = (size.width - _trashSize) / 2;
            final trashTop = size.height - trashBottom - _trashSize;
            final trashRect =
                Rect.fromLTWH(trashLeft, trashTop, _trashSize, _trashSize);

            // Lock onto the trash center while hovering so the drop reads as
            // deliberate rather than accidental.
            final displayOffset = _isNearTrash
                ? Offset(
                    trashRect.center.dx -
                        DraggableFloatingBubble.bubbleSize / 2,
                    trashRect.center.dy -
                        DraggableFloatingBubble.bubbleSize / 2,
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
                        width: _trashSize,
                        height: _trashSize,
                        decoration: BoxDecoration(
                          color: _isNearTrash
                              ? Colors.red.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _isNearTrash
                                ? Colors.red.withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.12),
                            width: _isNearTrash ? 1.5 : 1,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.trash2,
                          color: _isNearTrash
                              ? Colors.red
                              : const Color(0xFF111827),
                          size: _isNearTrash ? 32 : 28,
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
                    behavior: HitTestBehavior.opaque,
                    onTap: _isDragging ? null : widget.onTap,
                    onPanStart: (_) {
                      setState(() => _isDragging = true);
                      _trashAnimController.forward();
                    },
                    onPanUpdate: (details) {
                      if (_isNearTrash) return;
                      final clamped = _clampOffset(
                        _offset + details.delta,
                        size,
                        padding,
                      );
                      final nearTrash = _checkNearTrash(clamped, trashRect);
                      setState(() {
                        _offset = clamped;
                        _hasPosition = true;
                        _isNearTrash = nearTrash;
                      });
                    },
                    onPanEnd: (_) => _handleDragEnd(),
                    onPanCancel: () => _handleDragEnd(),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutBack,
                      scale: _isNearTrash ? 0.85 : 1.0,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: DraggableFloatingBubble.bubbleSize,
                            height: DraggableFloatingBubble.bubbleSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isNearTrash
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : widget.backgroundColor,
                              border: _isNearTrash
                                  ? Border.all(
                                      color: Colors.red.withValues(alpha: 0.5),
                                      width: 1.5,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: widget.shadowAlpha,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: IconTheme(
                              data: IconThemeData(
                                color: _isNearTrash
                                    ? Colors.red
                                    : widget.foregroundColor,
                                size: 26,
                              ),
                              child: widget.icon,
                            ),
                          ),
                          if (!_isNearTrash && widget.badge != null)
                            widget.badge!,
                        ],
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