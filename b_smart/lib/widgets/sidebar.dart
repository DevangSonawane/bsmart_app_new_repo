import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_scope.dart';

/// Desktop sidebar matching React: collapsible on hover, nav items, Create dropdown.
class Sidebar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback? onCreatePost;
  final VoidCallback? onUploadReel;

  const Sidebar({
    Key? key,
    required this.currentIndex,
    required this.onNavTap,
    this.onCreatePost,
    this.onUploadReel,
  }) : super(key: key);

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _hovered = false;
  bool _createDropdownOpen = false;

  static const double _narrowWidth = 80;
  static const double _wideWidth = 256;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.grey.shade200 : Colors.grey.shade800;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _createDropdownOpen = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _hovered ? _wideWidth : _narrowWidth,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(right: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: _hovered
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: DesignTokens.instaGradient,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: const Center(child: Text('b', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                        ),
                        const SizedBox(width: 8),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [DesignTokens.instaPurple, DesignTokens.instaPink, DesignTokens.instaOrange],
                          ).createShader(bounds),
                          child: const Text('B-Smart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'cursive')),
                        ),
                      ],
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: DesignTokens.instaGradient,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Center(child: Text('b', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                    ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _NavItem(icon: LucideIcons.house, label: 'Home', index: 0, currentIndex: widget.currentIndex, hovered: _hovered, onTap: () => widget.onNavTap(0), inactiveColor: inactiveColor),
                  _NavItem(icon: LucideIcons.target, label: 'Ads', index: 1, currentIndex: widget.currentIndex, hovered: _hovered, onTap: () => widget.onNavTap(1), inactiveColor: inactiveColor),
                  _CreateItem(
                    currentIndex: widget.currentIndex,
                    hovered: _hovered,
                    dropdownOpen: _createDropdownOpen,
                    onTap: () => setState(() => _createDropdownOpen = !_createDropdownOpen),
                    onDismiss: () => setState(() => _createDropdownOpen = false),
                    onCreatePost: () {
                      setState(() => _createDropdownOpen = false);
                      widget.onCreatePost?.call();
                    },
                    onUploadReel: () {
                      setState(() => _createDropdownOpen = false);
                      widget.onUploadReel?.call();
                    },
                  ),
                  _NavItem(icon: LucideIcons.megaphone, label: 'Promote', index: 3, currentIndex: widget.currentIndex, hovered: _hovered, onTap: () => widget.onNavTap(3), inactiveColor: inactiveColor),
                  _NavItem(icon: LucideIcons.clapperboard, label: 'Reels', index: 4, currentIndex: widget.currentIndex, hovered: _hovered, onTap: () => widget.onNavTap(4), inactiveColor: inactiveColor),
                  _NavItem(icon: LucideIcons.user, label: 'Profile', index: 5, currentIndex: widget.currentIndex, hovered: _hovered, onTap: () => widget.onNavTap(5), inactiveColor: inactiveColor),
                  const SizedBox(height: 16),
                  _NavItem(icon: LucideIcons.menu, label: 'More', index: -1, currentIndex: -2, hovered: _hovered, onTap: () {}, inactiveColor: inactiveColor),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => ThemeScope.of(context).toggle(),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisAlignment: _hovered ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        Icon(isDark ? LucideIcons.moon : LucideIcons.sun, size: 22, color: inactiveColor),
                        if (_hovered) ...[
                          const SizedBox(width: 12),
                          Text('Appearance', style: TextStyle(color: inactiveColor, fontWeight: FontWeight.w500)),
                          const Spacer(),
                          Switch(
                            value: isDark,
                            onChanged: (_) => ThemeScope.of(context).toggle(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final bool hovered;
  final VoidCallback onTap;
  final Color inactiveColor;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.hovered,
    required this.onTap,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final active = currentIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: active ? DesignTokens.instaPink.withAlpha(25) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 24, color: active ? DesignTokens.instaPink : inactiveColor),
                if (hovered) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                        color: active ? DesignTokens.instaPink : inactiveColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateItem extends StatelessWidget {
  final int currentIndex;
  final bool hovered;
  final bool dropdownOpen;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final VoidCallback? onCreatePost;
  final VoidCallback? onUploadReel;

  const _CreateItem({
    required this.currentIndex,
    required this.hovered,
    required this.dropdownOpen,
    required this.onTap,
    required this.onDismiss,
    this.onCreatePost,
    this.onUploadReel,
  });

  @override
  Widget build(BuildContext context) {
    final active = dropdownOpen;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: active ? DesignTokens.instaPink.withAlpha(25) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(LucideIcons.squarePlus, size: 24, color: active ? DesignTokens.instaPink : Colors.grey.shade800),
                    if (hovered) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Create',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: active ? FontWeight.bold : FontWeight.w500,
                            color: active ? DesignTokens.instaPink : Colors.grey.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (dropdownOpen)
            Positioned(
              left: hovered ? 0 : 56,
              top: 48,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 192,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                            color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(LucideIcons.image, size: 20),
                        title: const Text('Create Post', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        onTap: onCreatePost,
                      ),
                      ListTile(
                        leading: Icon(LucideIcons.video, size: 20),
                        title: const Text('Upload Reel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        onTap: onUploadReel,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
