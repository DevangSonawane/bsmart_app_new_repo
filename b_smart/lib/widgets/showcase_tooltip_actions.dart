import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

List<TooltipActionButton> buildOnboardingTooltipActions() {
  return [
    TooltipActionButton.custom(
      button: _ArrowActionButton(
        icon: Icons.arrow_back_rounded,
        onTap: () => ShowcaseView.get().dismiss(),
      ),
    ),
    TooltipActionButton.custom(
      button: _ArrowActionButton(
        icon: Icons.arrow_forward_rounded,
        onTap: () => ShowcaseView.get().next(),
      ),
    ),
  ];
}

class _ArrowActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ArrowActionButton({
    required this.icon,
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
          width: 38,
          height: 38,
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
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
