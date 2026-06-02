import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_scope.dart';
import 'auth/login/login_screen.dart';
import '../services/ui_prefs.dart';
import '../services/auth/auth_service.dart';
import '../services/push_service.dart';

/// Settings: Preferences, Account, About sections + Log out.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await AuthService().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loggingOut = false);
      }
    }
  }

  Future<void> _showPushDebug() async {
    final push = PushService();
    await push.syncTokenWithBackend();
    // If needed, use `flutter run --dart-define=PUSH_LOG_TOKENS=true` to log it.
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Push Debug'),
          content: const Text(
            'Actions:\n'
            '• Force re-register token with backend\n'
            '• Clear local last-registered token\n\n'
            'Check Logcat/`flutter logs` for [PushService] lines.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await push.clearLastRegisteredToken();
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
              child: const Text('Clear Local'),
            ),
            TextButton(
              onPressed: () async {
                await push.forceRegisterWithBackend();
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
              },
              child: const Text('Force Register'),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(
                  const ClipboardData(text: '[PushService]'),
                );
                Navigator.of(ctx).pop();
              },
              child: const Text('Copy Tag'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeScope.of(context).isDark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft,
              color: theme.appBarTheme.foregroundColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Settings',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: theme.appBarTheme.foregroundColor)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Preferences'),
          _darkModeTile(context, isDark),
          _floatingMessageTile(),
          _settingTile(
              icon: LucideIcons.globe,
              label: 'Language / Region',
              subLabel: 'Default: English',
              onTap: () {}),
          _settingTile(
              icon: LucideIcons.bell,
              label: 'Notifications',
              subLabel: 'Manage notifications',
              onTap: () {}),
          if (!kReleaseMode)
            _settingTile(
              icon: LucideIcons.bug,
              label: 'Push Debug',
              subLabel: 'FCM token + backend register',
              onTap: _showPushDebug,
            ),
          const SizedBox(height: 24),
          _sectionTitle('Account'),
          _settingTile(
            icon: LucideIcons.shield,
            label: 'Privacy',
            subLabel: 'Account privacy & follow requests',
            onTap: () => Navigator.of(context).pushNamed('/privacy'),
          ),
          _settingTile(
            icon: LucideIcons.lock,
            label: 'Security',
            subLabel: 'Password, 2FA',
            onTap: () => Navigator.of(context).pushNamed('/security'),
          ),
          _settingTile(
              icon: LucideIcons.slidersHorizontal,
              label: 'Content Settings',
              subLabel: 'Moderation & restrictions',
              onTap: () {}),
          const SizedBox(height: 24),
          _sectionTitle('About'),
          _settingTile(
              icon: LucideIcons.info,
              label: 'About b Smart',
              subLabel: 'Version 1.0.0',
              onTap: () {}),
          _settingTile(
              icon: LucideIcons.info,
              label: 'Help & Support',
              subLabel: 'Contact support',
              onTap: () {}),
          const SizedBox(height: 24),
          _sectionTitle('Actions'),
          Material(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _loggingOut ? null : _logout,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: Colors.red.shade50, shape: BoxShape.circle),
                      child: _loggingOut
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.red.shade700))
                          : Icon(LucideIcons.logOut,
                              color: Colors.red.shade700, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_loggingOut ? 'Logging out...' : 'Log Out',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700)),
                          const SizedBox(height: 2),
                          Text('Sign out of your account',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodyMedium?.color ??
                                      Colors.grey.shade600)),
                        ],
                      ),
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DesignTokens.instaPink,
              letterSpacing: 0.5)),
    );
  }

  Widget _darkModeTile(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => ThemeScope.of(context).toggle(),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: DesignTokens.instaPink.withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: Icon(isDark ? LucideIcons.moon : LucideIcons.sun,
                      color: DesignTokens.instaPink, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dark mode',
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyLarge?.color)),
                      const SizedBox(height: 2),
                      Text(isDark ? 'On' : 'Off',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodyMedium?.color ??
                                  Colors.grey.shade600)),
                    ],
                  ),
                ),
                Switch(
                  value: isDark,
                  onChanged: (_) => ThemeScope.of(context).toggle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _floatingMessageTile() {
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: UiPrefs.showFloatingMessage,
      builder: (context, show, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => UiPrefs.showFloatingMessage.value = !show,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: DesignTokens.instaPink.withOpacity(0.12),
                          shape: BoxShape.circle),
                      child: const Icon(LucideIcons.messageCircle,
                          color: DesignTokens.instaPink, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Floating messages',
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: theme.textTheme.bodyLarge?.color)),
                          const SizedBox(height: 2),
                          Text(show ? 'Shown on main tabs' : 'Hidden',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodyMedium?.color ??
                                      Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Switch(
                      value: show,
                      onChanged: (v) => UiPrefs.showFloatingMessage.value = v,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _settingTile(
      {required IconData icon,
      required String label,
      String? subLabel,
      VoidCallback? onTap}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: DesignTokens.instaPink.withOpacity(0.12),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: DesignTokens.instaPink, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyLarge?.color)),
                      if (subLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(subLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodyMedium?.color ??
                                    Colors.grey.shade600)),
                      ],
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight,
                    color: theme.iconTheme.color ?? Colors.grey.shade400,
                    size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
