import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

enum PipCorner { topLeft, topRight, bottomLeft, bottomRight }

/// A draggable floating box (call self-view, minimized call tile) that feels
/// like FaceTime/Instagram: it follows the finger 1:1, keeps momentum when
/// flung, and springs into the nearest corner.
///
/// Drag frames only move a [Transform] — [child] is never rebuilt while
/// dragging, so live video stays smooth. Fill a [Stack] with it (it lays out
/// over the whole area but only the box itself takes touches).
class FloatingPip extends StatefulWidget {
  const FloatingPip({
    super.key,
    required this.size,
    required this.child,
    this.onTap,
    this.margin = const EdgeInsets.all(12),
    this.initialCorner = PipCorner.topRight,
    this.borderRadius = 14,
  });

  final Size size;
  final Widget child;
  final VoidCallback? onTap;

  /// Distance the box keeps from each edge of the available area.
  final EdgeInsets margin;
  final PipCorner initialCorner;
  final double borderRadius;

  @override
  State<FloatingPip> createState() => _FloatingPipState();
}

class _FloatingPipState extends State<FloatingPip> with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(mass: 1, stiffness: 420, damping: 32);

  late final AnimationController _snap = AnimationController.unbounded(vsync: this)..addListener(_onSnapTick);
  final ValueNotifier<Offset> _pos = ValueNotifier(Offset.zero);
  final ValueNotifier<bool> _dragging = ValueNotifier(false);
  late PipCorner _corner = widget.initialCorner;
  Offset _snapFrom = Offset.zero;
  Offset _snapTo = Offset.zero;
  Size _area = Size.zero;
  bool _placed = false;

  @override
  void dispose() {
    _snap.dispose();
    _pos.dispose();
    _dragging.dispose();
    super.dispose();
  }

  Offset _cornerOffset(PipCorner c) {
    final m = widget.margin;
    final maxX = _area.width - widget.size.width - m.right;
    final maxY = _area.height - widget.size.height - m.bottom;
    final left = c == PipCorner.topLeft || c == PipCorner.bottomLeft;
    final top = c == PipCorner.topLeft || c == PipCorner.topRight;
    return Offset(left ? m.left : maxX, top ? m.top : maxY);
  }

  void _onSnapTick() {
    final t = _snap.value;
    _pos.value = Offset.lerp(_snapFrom, _snapTo, t)!;
  }

  void _onPanStart(DragStartDetails _) {
    _snap.stop();
    _dragging.value = true;
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final m = widget.margin;
    final p = _pos.value + d.delta;
    // Allow slight overscroll past the margins, with resistance.
    _pos.value = Offset(
      _rubber(p.dx, m.left - 24, _area.width - widget.size.width - m.right + 24),
      _rubber(p.dy, m.top - 24, _area.height - widget.size.height - m.bottom + 24),
    );
  }

  static double _rubber(double v, double min, double max) {
    if (max < min) return min;
    if (v < min) return min - (min - v) * .35;
    if (v > max) return max + (v - max) * .35;
    return v;
  }

  void _onPanEnd(DragEndDetails d) {
    _dragging.value = false;
    final v = d.velocity.pixelsPerSecond;
    // Project where a fling would carry the box, then pick the nearest corner.
    final projected = _pos.value + v * .18 + widget.size.center(Offset.zero);
    final left = projected.dx < _area.width / 2;
    final top = projected.dy < _area.height / 2;
    final next = top ? (left ? PipCorner.topLeft : PipCorner.topRight) : (left ? PipCorner.bottomLeft : PipCorner.bottomRight);
    if (next != _corner) HapticFeedback.lightImpact();
    _corner = next;
    _animateTo(_cornerOffset(next), velocity: v);
  }

  void _animateTo(Offset target, {Offset velocity = Offset.zero}) {
    _snapFrom = _pos.value;
    _snapTo = target;
    final distance = (target - _snapFrom).distance;
    if (distance < .5) {
      _pos.value = target;
      return;
    }
    // Spring runs 0 → 1 along the from→to line; feed in the fling speed
    // projected onto that line so the hand-off from finger feels continuous.
    final dir = (target - _snapFrom) / distance;
    final along = (velocity.dx * dir.dx + velocity.dy * dir.dy) / distance;
    _snap.animateWith(SpringSimulation(_spring, 0, 1, along));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final area = constraints.biggest;
      if (area != _area) {
        _area = area;
        // First layout or rotation: sit in the current corner.
        if (!_placed || !_snap.isAnimating) {
          _pos.value = _cornerOffset(_corner);
          _placed = true;
        }
      }
      final box = GestureDetector(
        onTap: widget.onTap,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: RepaintBoundary(child: SizedBox.fromSize(size: widget.size, child: widget.child)),
      );
      return Stack(children: [
        ValueListenableBuilder<Offset>(
          valueListenable: _pos,
          builder: (context, pos, child) => Positioned(
            left: pos.dx,
            top: pos.dy,
            width: widget.size.width,
            height: widget.size.height,
            child: child!,
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: _dragging,
            builder: (context, dragging, child) => AnimatedScale(
              scale: dragging ? 1.05 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dragging ? .55 : .35),
                      blurRadius: dragging ? 22 : 12,
                      offset: Offset(0, dragging ? 10 : 4),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
            child: box,
          ),
        ),
      ]);
    });
  }
}
