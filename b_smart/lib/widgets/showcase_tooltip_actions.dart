import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

List<TooltipActionButton> buildOnboardingTooltipActions() {
  return [
    TooltipActionButton.custom(
      button: _GradientActionButton(
        label: 'Skip',
        onTap: () => ShowcaseView.get().dismiss(),
      ),
    ),
    TooltipActionButton.custom(
      button: _GradientActionButton(
        label: 'Next',
        onTap: () => ShowcaseView.get().next(),
      ),
    ),
  ];
}

class _GradientActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFF59E0B),
                Color(0xFFF97316),
                Color(0xFFFB7185),
              ],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
