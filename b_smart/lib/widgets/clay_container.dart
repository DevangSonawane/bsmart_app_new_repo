import 'package:flutter/material.dart';
import '../theme/instagram_theme.dart';

class ClayContainer extends StatelessWidget {
  final Widget? child;
  final double? width;
  final double? height;
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const ClayContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.color,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget container = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: InstagramTheme.cardDecoration(
        color: color ?? InstagramTheme.surfaceWhite,
        borderRadius: borderRadius,
        hasBorder: true,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }

    return container;
  }
}

class ClayButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final double? width;
  final double? height;

  const ClayButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.width,
    this.height,
  });

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.identity()
          ..scaleByDouble(
            _isPressed ? 0.98 : 1.0,
            _isPressed ? 0.98 : 1.0,
            1.0,
            1.0,
          ),
        width: widget.width,
        height: widget.height,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: InstagramTheme.gradientDecoration(
          borderRadius: 16,
        ),
        child: Center(
          child: DefaultTextStyle(
            style: const TextStyle(
              color: InstagramTheme.textWhite,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
