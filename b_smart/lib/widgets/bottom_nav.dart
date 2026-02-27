import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/design_tokens.dart';

class BottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({Key? key, required this.currentIndex, required this.onTap}) : super(key: key);

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  bool _rotating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final activeColor = DesignTokens.instaPink;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, LucideIcons.house, 'Home', isActive: widget.currentIndex == 0),
              _buildNavItem(context, 1, LucideIcons.target, 'Ads', isActive: widget.currentIndex == 1),
              _buildCreateButton(context),
              _buildNavItem(context, 3, LucideIcons.megaphone, 'Promote', isActive: widget.currentIndex == 3),
              _buildNavItem(context, 4, LucideIcons.clapperboard, 'Reels', isActive: widget.currentIndex == 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label, {required bool isActive}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => widget.onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: Icon(
          icon,
          size: 26,
          color: isActive ? DesignTokens.instaPink : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    final theme = Theme.of(context);
    return Transform.translate(
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF09433),
                Color(0xFFDC2743),
                Color(0xFFBC1888),
              ],
            ),
            boxShadow: const [
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
  }
}
