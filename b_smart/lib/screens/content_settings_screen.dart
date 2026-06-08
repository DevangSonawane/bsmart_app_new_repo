import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/content_moderation_service.dart';
import '../theme/design_tokens.dart';

class ContentSettingsScreen extends StatefulWidget {
  const ContentSettingsScreen({super.key});

  @override
  State<ContentSettingsScreen> createState() => _ContentSettingsScreenState();
}

class _ContentSettingsScreenState extends State<ContentSettingsScreen> {
  final ContentModerationService _moderationService =
      ContentModerationService();
  final String _currentUserId = 'user-1';

  bool _showRestrictedContent = false;
  int _userAge = 18;
  String _language = 'English (Default)';
  String _region = 'Not set';

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  void _loadUserSettings() {
    setState(() {
      _userAge = 18;
      _showRestrictedContent = false;
      _language = 'English (Default)';
      _region = 'Not set';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strikeRecord = _moderationService.getUserStrikes(_currentUserId);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Content Preferences'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _headerCard(isDark),
            const SizedBox(height: 20),
            _sectionTitle('Account Status'),
            _statusCard(strikeRecord),
            const SizedBox(height: 20),
            _sectionTitle('Content Preferences'),
            _settingsCard(
              children: [
                _actionRow(
                  icon: Icons.cake_outlined,
                  title: 'Your Age',
                  subtitle: '$_userAge years old',
                  onTap: _showAgeDialog,
                  trailing: Text(
                    _userAge >= 18 ? 'Adult' : 'Minor',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: Icons.visibility_outlined,
                  title: 'Show Restricted Content',
                  subtitle: 'Allow sexualized content (18+ only).',
                  value: _showRestrictedContent,
                  onChanged: _handleRestrictedToggle,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('App Settings'),
            _settingsCard(
              children: [
                _actionRow(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  subtitle: _language,
                  onTap: _showLanguageDialog,
                ),
                const Divider(height: 1),
                _actionRow(
                  icon: Icons.place_outlined,
                  title: 'Region / Address',
                  subtitle: _region,
                  onTap: _showAddressDialog,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoCard(isDark),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _resetDefaults,
              icon: const Icon(Icons.restart_alt_outlined),
              label: const Text('Reset Preferences'),
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.instaPink,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: DesignTokens.instaGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(
              Icons.tune_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Content preferences',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Control age gating, restricted content, language, and region in one place.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _settingsCard({required List<Widget> children}) {
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

  Widget _statusCard(dynamic strikeRecord) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.cardColor;
    final border = theme.dividerColor.withValues(alpha: 0.08);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final int strikes = strikeRecord?.policyStrikes ?? 0;
    final bool suspended = strikeRecord?.isSuspended ?? false;
    final bool restricted = strikeRecord?.isRestricted ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
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
                  LucideIcons.shieldAlert,
                  color: DesignTokens.instaPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Account safety',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (strikeRecord != null && strikes > 0) ...[
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: strikes >= 3 ? Colors.red : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Policy Violations: $strikes',
                    style: TextStyle(
                      color: strikes >= 3 ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              suspended
                  ? 'Your account is suspended due to policy violations.'
                  : restricted
                      ? 'Your posting is restricted due to policy violations.'
                      : '${3 - strikes} strikes remaining before restrictions.',
              style: TextStyle(color: hintColor),
            ),
          ] else
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'No policy violations',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF242424) : const Color(0xFFF6F7F9);
    final border = isDark ? const Color(0xFF444444) : const Color(0xFFD7DCE3);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
        ),
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
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing,
            ],
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: hintColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF242424) : const Color(0xFFF6F7F9);
    final border = isDark ? const Color(0xFF444444) : const Color(0xFFD7DCE3);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      tileColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: BorderSide(color: border),
      ),
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: DesignTokens.instaPink.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: DesignTokens.instaPink, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: labelColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          height: 1.35,
          color: hintColor,
        ),
      ),
      value: value,
      activeThumbColor: DesignTokens.instaPink,
      activeTrackColor: DesignTokens.instaPink.withValues(alpha: 0.35),
      inactiveThumbColor: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563),
      inactiveTrackColor: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
      onChanged: onChanged,
    );
  }

  Widget _infoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.info,
            color: DesignTokens.instaPink,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'These settings are matched to the current backend support. Age, language, and region stay local for now, while restricted content uses the age gate.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAgeDialog() async {
    var tempAge = _userAge;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Set Your Age'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Age: $tempAge'),
                  Slider(
                    value: tempAge.toDouble(),
                    min: 13,
                    max: 100,
                    divisions: 87,
                    label: '$tempAge',
                    onChanged: (value) {
                      setLocal(() => tempAge = value.toInt());
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, tempAge),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() {
      _userAge = selected;
      if (_userAge < 18) {
        _showRestrictedContent = false;
      }
    });
  }

  Future<void> _showLanguageDialog() async {
    final options = ['English (Default)', 'Spanish', 'French'];
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Select Language'),
          children: [
            for (final option in options)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, option),
                child: Text(option),
              ),
          ],
        );
      },
    );

    if (!mounted || selected == null) return;
    setState(() => _language = selected);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Language set to $selected')),
    );
  }

  Future<void> _showAddressDialog() async {
    final streetController = TextEditingController();
    final cityController = TextEditingController();
    final postalController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Update Address'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: streetController,
                  decoration: const InputDecoration(labelText: 'Street Address'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: postalController,
                  decoration: const InputDecoration(labelText: 'Postal Code'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || saved != true) return;
    final parts = <String>[
      streetController.text.trim(),
      cityController.text.trim(),
      postalController.text.trim(),
    ].where((e) => e.isNotEmpty).toList();

    setState(() {
      _region = parts.isEmpty ? 'Not set' : parts.join(', ');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address updated')),
    );
  }

  void _handleRestrictedToggle(bool value) {
    if (_userAge < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be 18+ to view restricted content'),
        ),
      );
      return;
    }
    setState(() => _showRestrictedContent = value);
  }

  void _resetDefaults() {
    setState(() {
      _userAge = 18;
      _showRestrictedContent = false;
      _language = 'English (Default)';
      _region = 'Not set';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Content preferences reset')),
    );
  }
}
