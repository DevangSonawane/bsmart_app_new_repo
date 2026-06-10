import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/theme_scope.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ThemeScope.of(context);
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('appearance_title'.tr()),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            _sectionTitle('appearance_theme_section'.tr()),
            _settingsCard(
              context,
              children: [
                _themeOption(
                  context,
                  title: 'appearance_light_mode'.tr(),
                  subtitle: 'appearance_light_mode_subtitle'.tr(),
                  icon: Icons.sunny,
                  selected: themeNotifier.themeMode == ThemeMode.light,
                  onTap: () => themeNotifier.setThemeMode(ThemeMode.light),
                ),
                const Divider(height: 1),
                _themeOption(
                  context,
                  title: 'appearance_dark_mode'.tr(),
                  subtitle: 'appearance_dark_mode_subtitle'.tr(),
                  icon: Icons.dark_mode,
                  selected: themeNotifier.themeMode == ThemeMode.dark,
                  onTap: () => themeNotifier.setThemeMode(ThemeMode.dark),
                ),
                const Divider(height: 1),
                _themeOption(
                  context,
                  title: 'appearance_system_default'.tr(),
                  subtitle: 'appearance_system_default_subtitle'.tr(),
                  icon: Icons.computer,
                  selected: themeNotifier.themeMode == ThemeMode.system,
                  onTap: () => themeNotifier.setThemeMode(ThemeMode.system),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('appearance_accessibility_section'.tr()),
            _settingsCard(
              context,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: DesignTokens.instaPink.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.text_fields,
                              color: DesignTokens.instaPink,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'appearance_font_size'.tr(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'appearance_font_size_subtitle'.tr(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${(themeNotifier.fontScale * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Slider(
                        value: themeNotifier.fontScale,
                        min: 0.85,
                        max: 1.3,
                        divisions: 9,
                        activeColor: DesignTokens.instaPink,
                        onChanged: (value) => themeNotifier.setFontScale(value),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _switchRow(
                  context,
                  icon: Icons.contrast,
                  title: 'appearance_high_contrast'.tr(),
                  subtitle: 'appearance_high_contrast_subtitle'.tr(),
                  value: themeNotifier.highContrastMode,
                  onChanged: themeNotifier.setHighContrastMode,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('appearance_motion_section'.tr()),
            _settingsCard(
              context,
              children: [
                _switchRow(
                  context,
                  icon: Icons.speed,
                  title: 'appearance_reduce_motion'.tr(),
                  subtitle: 'appearance_reduce_motion_subtitle'.tr(),
                  value: themeNotifier.reduceMotion,
                  onChanged: themeNotifier.setReduceMotion,
                ),
                const Divider(height: 1),
                _switchRow(
                  context,
                  icon: Icons.play_circle_outline,
                  title: 'appearance_disable_auto_play'.tr(),
                  subtitle: 'appearance_disable_auto_play_subtitle'.tr(),
                  value: themeNotifier.disableAutoPlay,
                  onChanged: themeNotifier.setDisableAutoPlay,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: DesignTokens.instaPink,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _settingsCard(BuildContext context, {required List<Widget> children}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  Widget _themeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DesignTokens.instaPink.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: DesignTokens.instaPink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: hintColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? DesignTokens.instaPink : hintColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final inactiveThumbColor =
        isDark ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563);
    final inactiveTrackColor =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DesignTokens.instaPink.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: DesignTokens.instaPink, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: hintColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            activeThumbColor: DesignTokens.instaPink,
            activeTrackColor: DesignTokens.instaPink.withValues(alpha: 0.35),
            inactiveThumbColor: inactiveThumbColor,
            inactiveTrackColor: inactiveTrackColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
