import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:showcaseview/showcaseview.dart';
import '../theme/design_tokens.dart';
import '../services/home_onboarding_service.dart';
import 'showcase_tooltip_actions.dart';

class BottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final HomeOnboardingStep? homeStep;
  final HomeOnboardingStep? adsStep;
  final HomeOnboardingStep? createStep;
  final HomeOnboardingStep? rocketStep;
  final HomeOnboardingStep? reelsStep;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.homeStep,
    this.adsStep,
    this.createStep,
    this.rocketStep,
    this.reelsStep,
  });

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  bool _rotating = false;
  static const double _navIconBoxSize = 34;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 42,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BottomNavShapePainter(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  borderColor: borderColor,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShowcaseNavItem(
                  context,
                  step: widget.homeStep,
                  index: 0,
                  icon: LucideIcons.house,
                  isActive: widget.currentIndex == 0,
                ),
                _buildShowcaseNavItem(
                  context,
                  step: widget.adsStep,
                  index: 1,
                  icon: LucideIcons.badgeDollarSign,
                  isActive: widget.currentIndex == 1,
                  customIcon: _buildSpotlightIcon(
                    context,
                    isActive: widget.currentIndex == 1,
                  ),
                ),
                _buildShowcaseCreateButton(context),
                _buildShowcaseNavItem(
                  context,
                  step: widget.rocketStep,
                  index: 3,
                  icon: LucideIcons.rocket,
                  isActive: widget.currentIndex == 3,
                ),
                _buildShowcaseNavItem(
                  context,
                  step: widget.reelsStep,
                  index: 4,
                  icon: LucideIcons.clapperboard,
                  isActive: widget.currentIndex == 4,
                  customIcon: _buildBSparksIcon(
                    context,
                    isActive: widget.currentIndex == 4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShowcaseNavItem(
    BuildContext context, {
    required HomeOnboardingStep? step,
    required int index,
    required IconData icon,
    required bool isActive,
    Widget? customIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final child = InkWell(
      onTap: () => widget.onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: SizedBox(
          width: _navIconBoxSize,
          height: _navIconBoxSize,
          child: Center(
            child: customIcon ??
                Icon(
                  icon,
                  size: 30,
                  color: isActive
                      ? DesignTokens.instaPink
                      : (isDark ? Colors.white : Colors.black),
                ),
          ),
        ),
      ),
    );

    return _wrapShowcase(
      context,
      step: step,
      isPrimary: false,
      child: child,
      targetShapeBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      targetPadding: const EdgeInsets.all(4),
    );
  }

  Widget _buildShowcaseCreateButton(BuildContext context) {
    final button = Transform.translate(
      offset: const Offset(0, -8),
      child: GestureDetector(
        onTap: () {
          setState(() => _rotating = true);
          widget.onTap(2);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _rotating = false);
          });
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF09433),
                Color(0xFFDC2743),
                Color(0xFFBC1888),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: AnimatedRotation(
              turns: _rotating ? 1 / 8 : 0, // 45 degrees
              duration: const Duration(milliseconds: 300),
              child: SvgPicture.string(
                '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-plus"><path d="M5 12h14"></path><path d="M12 5v14"></path></svg>',
                width: 32,
                height: 32,
              ),
            ),
          ),
        ),
      ),
    );

    return _wrapShowcase(
      context,
      step: widget.createStep,
      isPrimary: true,
      child: button,
      targetShapeBorder: const CircleBorder(),
      targetPadding: const EdgeInsets.all(8),
    );
  }

  Widget _wrapShowcase(
    BuildContext context, {
    required HomeOnboardingStep? step,
    required Widget child,
    required ShapeBorder targetShapeBorder,
    required EdgeInsets targetPadding,
    required bool isPrimary,
  }) {
    if (step == null) return child;

    final theme = Theme.of(context);
    const overlayColor = Colors.black;
    final tooltipBackgroundColor = theme.cardColor;
    final titleStyle = GoogleFonts.montserrat(
      fontSize: isPrimary ? 18 : 16,
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurface,
      height: 1.2,
    );
    final descStyle = GoogleFonts.montserrat(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Showcase(
      key: step.key,
      title: step.title,
      description: step.description,
      tooltipActions: buildOnboardingTooltipActions(),
      showArrow: false,
      tooltipPosition: step.tooltipPosition,
      titleTextStyle: titleStyle,
      descTextStyle: descStyle,
      tooltipBackgroundColor: tooltipBackgroundColor,
      tooltipBorderRadius: BorderRadius.circular(isPrimary ? 28 : 24),
      overlayColor: overlayColor,
      overlayOpacity: isPrimary ? 0.72 : 0.72,
      blurValue: isPrimary ? 1.8 : 1.6,
      targetShapeBorder: targetShapeBorder,
      targetPadding: targetPadding,
      targetTooltipGap: isPrimary ? 18 : 12,
      toolTipMargin: isPrimary ? 20 : 14,
      disableBarrierInteraction: true,
      enableAutoScroll: false,
      scrollAlignment: 0.45,
      child: child,
    );
  }

  Widget _buildSpotlightIcon(
    BuildContext context, {
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isActive
        ? DesignTokens.instaPink
        : (isDark ? Colors.white : Colors.black);

    return Icon(
      LucideIcons.circlePlay,
      size: 30,
      color: color,
    );
  }

  Widget _buildBSparksIcon(
    BuildContext context, {
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isActive
        ? DesignTokens.instaPink
        : (isDark ? Colors.white : Colors.black);

    return Icon(
      LucideIcons.zap,
      size: 30,
      color: color,
    );
  }

}

class _BottomNavShapePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;

  const _BottomNavShapePainter({
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = _buildPath(size);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  Path _buildPath(Size size) {
    const notchWidth = 86.0;
    const notchDepth = 36.0;
    const shoulderWidth = 20.0;
    final centerX = size.width / 2;
    final notchLeft = centerX - notchWidth / 2;
    final notchRight = centerX + notchWidth / 2;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(notchLeft - shoulderWidth, 0)
      ..cubicTo(
        notchLeft + 2,
        0,
        centerX - 28,
        notchDepth,
        centerX,
        notchDepth,
      )
      ..cubicTo(
        centerX + 28,
        notchDepth,
        notchRight - 2,
        0,
        notchRight + shoulderWidth,
        0,
      )
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _BottomNavShapePainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}
