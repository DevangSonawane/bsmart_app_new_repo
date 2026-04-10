import 'dart:ui';

import 'package:flutter/material.dart';

class AdGlassCtaButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  const AdGlassCtaButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.backgroundColor = const Color(0x99000000),
    this.borderColor = const Color(0x4DFFFFFF),
    this.foregroundColor = Colors.white,
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Padding(
                padding: padding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: foregroundColor,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdGradientCtaButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final Gradient gradient;
  final List<BoxShadow>? boxShadow;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  const AdGradientCtaButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.gradient = const LinearGradient(
      colors: [Color(0xFFF09433), Color(0xFFDC2743), Color(0xFFBC1888)],
    ),
    this.boxShadow,
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: borderRadius,
          boxShadow: boxShadow ??
              [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 10),
                ),
              ],
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
