import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../services/auth/auth_service.dart';
import '../services/ui_prefs.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_scope.dart';
import 'account_details_screen.dart';
import 'account_upgrade_screen.dart';
import 'advertiser_ads_list_screen.dart';
import 'advertiser_dashboard_screen.dart';
import 'advertiser_wallet_screen.dart';
import 'auth/login/login_screen.dart';
import 'content_settings_screen.dart';
import 'messaging_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_screen.dart';
import 'security_screen.dart';
import 'wallet_screen.dart';

/// Profile settings hub for account, privacy, security, notifications, and more.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loggingOut = false;
  bool _deletingAccount = false;
  bool _clearingCache = false;
  bool _loadingContext = true;
  String? _accountRole;
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    setState(() => _loadingContext = true);
    try {
      final results = await Future.wait([
        PackageInfo.fromPlatform(),
        _loadAccountRole(),
      ]);
      if (!mounted) return;
      setState(() {
        _packageInfo = results.first as PackageInfo;
        _accountRole = results.last as String?;
        _loadingContext = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingContext = false);
    }
  }

  Future<String?> _loadAccountRole() async {
    try {
      final meRaw = await AuthApi().me();
      final me = _normalizeMe(meRaw);
      final role = (me['role'] ?? me['userRole'] ?? me['user_role'])
              ?.toString()
              .trim()
              .toLowerCase() ??
          '';
      return role.isEmpty ? null : role;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _normalizeMe(dynamic raw) {
    if (raw is! Map) return const <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    if (map['user'] is Map) {
      return Map<String, dynamic>.from(map['user'] as Map);
    }
    if (map['data'] is Map) {
      final data = Map<String, dynamic>.from(map['data'] as Map);
      if (data['user'] is Map) {
        return Map<String, dynamic>.from(data['user'] as Map);
      }
      return data;
    }
    return map;
  }

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

  Future<void> _clearCache() async {
    if (_clearingCache) return;
    setState(() => _clearingCache = true);
    try {
      await DefaultCacheManager().emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear cache: $e')),
      );
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _openMailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@bsmart.app',
      queryParameters: {
        'subject': 'bSmart support request',
      },
    );
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support email is not available yet.')),
      );
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    if (_deletingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This build does not yet have a live delete-account API wired up. '
            'You can still review the flow here and we can connect the backend next.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deletingAccount = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete account flow is not connected yet.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  void _push(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  bool get _isCreator => _accountRole == 'creator';
  bool get _isVendor => _accountRole == 'vendor';
  PackageInfo? get _info => _packageInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeScope.of(context).isDark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: theme.appBarTheme.foregroundColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: theme.appBarTheme.foregroundColor,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
        children: [
          _headerCard(theme, isDark),
          const SizedBox(height: 20),
          _sectionTitle('Account'),
          _settingTile(
            icon: Icons.account_circle_outlined,
            label: 'Account',
            subLabel: 'Profile, email, phone, and payment details',
            onTap: () => _push(const AccountDetailsScreen()),
          ),
          _settingTile(
            icon: LucideIcons.shield,
            label: 'Privacy',
            subLabel: 'Private account and follow requests',
            onTap: () => _push(const PrivacyScreen()),
          ),
          _settingTile(
            icon: LucideIcons.lockKeyhole,
            label: 'Security',
            subLabel: 'Password, verification, and 2FA',
            onTap: () => _push(const SecurityScreen()),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Notifications'),
          _settingTile(
            icon: LucideIcons.bell,
            label: 'Notifications',
            subLabel: 'Push and delivery preferences',
            onTap: () => _push(const NotificationSettingsScreen()),
          ),
          _settingTile(
            icon: LucideIcons.messageSquareMore,
            label: 'Messaging',
            subLabel: 'Chats, requests, and conversation settings',
            onTap: () => _push(const MessagingScreen()),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Preferences'),
          _settingTile(
            icon: isDark ? LucideIcons.moon : LucideIcons.sunMedium,
            label: 'Appearance',
            subLabel: isDark ? 'Dark mode is on' : 'Light mode is on',
            trailing: Switch(
              value: isDark,
              onChanged: (_) => ThemeScope.of(context).toggle(),
            ),
            onTap: () => ThemeScope.of(context).toggle(),
          ),
          _floatingMessageTile(theme),
          _settingTile(
            icon: LucideIcons.slidersHorizontal,
            label: 'Content Preferences',
            subLabel: 'Age, restrictions, and feed controls',
            onTap: () => _push(const ContentSettingsScreen()),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Rewards'),
          _settingTile(
            icon: LucideIcons.wallet,
            label: 'Rewards & Wallet',
            subLabel: 'Coins, history, and balances',
            onTap: () => _push(const WalletScreen()),
          ),
          if (_isCreator) ...[
            _settingTile(
              icon: LucideIcons.sparkles,
              label: 'Creator Center',
              subLabel: 'Creator tools, earnings, and analytics',
              onTap: () => _push(const _CreatorCenterScreen()),
            ),
          ],
          if (_isVendor) ...[
            _settingTile(
              icon: LucideIcons.store,
              label: 'Vendor Center',
              subLabel: 'Campaigns, ads, and business wallet',
              onTap: () => _push(const _VendorCenterScreen()),
            ),
          ],
          const SizedBox(height: 20),
          _sectionTitle('Safety'),
          _settingTile(
            icon: LucideIcons.userX,
            label: 'Blocked & Restricted Accounts',
            subLabel: 'Manage blocks and view account limitations',
            onTap: () => _push(const _BlockedRestrictedScreen()),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Data'),
          _settingTile(
            icon: LucideIcons.databaseZap,
            label: 'Storage & Data',
            subLabel: 'Cache, downloads, and local app storage',
            onTap: () => _push(_StorageDataScreen(onClearCache: _clearCache)),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Support'),
          _settingTile(
            icon: Icons.help_outline,
            label: 'Help & Support',
            subLabel: 'Contact us and get help',
            onTap: () => _push(_HelpSupportScreen(onContactSupport: _openMailSupport)),
          ),
          _settingTile(
            icon: Icons.article_outlined,
            label: 'Legal & Compliance',
            subLabel: 'Policies, terms, and guidelines',
            onTap: () => _push(const _LegalComplianceScreen()),
          ),
          const SizedBox(height: 20),
          _sectionTitle('About'),
          _settingTile(
            icon: Icons.info_outline,
            label: 'About bSmart',
            subLabel: _aboutSubtitle,
            onTap: () => _push(_AboutScreen(packageInfo: _info)),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Actions'),
          _destructiveActionCard(
            icon: LucideIcons.logOut,
            title: _loggingOut ? 'Logging out...' : 'Logout',
            subtitle: 'Sign out of your account on this device',
            loading: _loggingOut,
            onTap: _loggingOut ? null : _logout,
          ),
          const SizedBox(height: 12),
          _destructiveActionCard(
            icon: LucideIcons.trash2,
            title: _deletingAccount ? 'Preparing delete flow...' : 'Delete Account',
            subtitle: 'Request permanent account removal',
            loading: _deletingAccount,
            onTap: _deletingAccount ? null : _showDeleteAccountDialog,
            danger: true,
          ),
          if (_loadingContext) ...[
            const SizedBox(height: 16),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _aboutSubtitle {
    final info = _packageInfo;
    if (info == null) return 'Version information loading...';
    return 'Version ${info.version} (${info.buildNumber})';
  }

  Widget _headerCard(ThemeData theme, bool isDark) {
    final role = _accountRole;
    final roleLabel = _loadingContext
        ? 'Loading account...'
        : role == null || role.isEmpty
            ? 'Member account'
            : '${role[0].toUpperCase()}${role.substring(1)} account';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: DesignTokens.instaGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
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
              color: Colors.white.withOpacity(0.16),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: const Icon(
              LucideIcons.settings2,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your account, privacy, content, data, and support in one place.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip(roleLabel),
                    _chip(_aboutSubtitle),
                    if (_isCreator) _chip('Creator tools enabled'),
                    if (_isVendor) _chip('Vendor tools enabled'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
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

  Widget _settingTile({
    required IconData icon,
    required String label,
    String? subLabel,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: DesignTokens.instaPink.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: DesignTokens.instaPink, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      if (subLabel != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subLabel,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: theme.textTheme.bodyMedium?.color ??
                                Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing else Icon(
                  LucideIcons.chevronRight,
                  color: theme.iconTheme.color ?? Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _floatingMessageTile(ThemeData theme) {
    return ValueListenableBuilder<bool>(
      valueListenable: UiPrefs.showFloatingMessage,
      builder: (context, show, _) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () => UiPrefs.showFloatingMessage.value = !show,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: DesignTokens.instaPink.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.messageCircle,
                        color: DesignTokens.instaPink,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Floating messages',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            show ? 'Shown on main tabs' : 'Hidden',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodyMedium?.color ??
                                  Colors.grey.shade600,
                            ),
                          ),
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

  Widget _destructiveActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool loading = false,
    bool danger = false,
  }) {
    final theme = Theme.of(context);
    final color = danger ? Colors.red.shade700 : Colors.red.shade600;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    : Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color ??
                            Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreatorCenterScreen extends StatelessWidget {
  const _CreatorCenterScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creator Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            context,
            title: 'Creator tools',
            subtitle: 'This space is ready for creator analytics, earnings, and content tools.',
            icon: LucideIcons.sparkles,
          ),
          const SizedBox(height: 12),
          _centerTile(
            context,
            icon: Icons.insights,
            title: 'Creator dashboard',
            subtitle: 'Views, reach, and content performance',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdvertiserDashboardScreen()),
            ),
          ),
          _centerTile(
            context,
            icon: Icons.account_balance_wallet,
            title: 'Earnings & wallet',
            subtitle: 'Coins, payouts, and history',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalletScreen()),
            ),
          ),
          _centerTile(
            context,
            icon: Icons.verified,
            title: 'Creator onboarding',
            subtitle: 'Upgrade and verification guidance',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountUpgradeScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorCenterScreen extends StatelessWidget {
  const _VendorCenterScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            context,
            title: 'Vendor tools',
            subtitle: 'Manage ads, wallet, and campaign analytics from this hub.',
            icon: LucideIcons.store,
          ),
          const SizedBox(height: 12),
          _centerTile(
            context,
            icon: LucideIcons.layoutDashboard,
            title: 'Vendor dashboard',
            subtitle: 'Topline metrics and campaign overview',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdvertiserDashboardScreen()),
            ),
          ),
          _centerTile(
            context,
            icon: LucideIcons.megaphone,
            title: 'Ad manager',
            subtitle: 'Campaigns, creatives, and performance',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdvertiserAdsListScreen()),
            ),
          ),
          _centerTile(
            context,
            icon: LucideIcons.wallet,
            title: 'Business wallet',
            subtitle: 'Coin balance, spending, and activity',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdvertiserWalletScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedRestrictedScreen extends StatelessWidget {
  const _BlockedRestrictedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked & Restricted Accounts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            context,
            title: 'Account safety',
            subtitle: 'This area will hold blocked users, account restrictions, and moderation history.',
            icon: Icons.block,
          ),
          const SizedBox(height: 12),
          _centerTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Review privacy',
            subtitle: 'Make your account private and manage follow requests',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyScreen()),
            ),
          ),
          _centerTile(
            context,
            icon: Icons.report_gmailerrorred_outlined,
            title: 'Content restrictions',
            subtitle: 'See moderation and restricted-content controls',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContentSettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageDataScreen extends StatelessWidget {
  final Future<void> Function() onClearCache;

  const _StorageDataScreen({required this.onClearCache});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storage & Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            context,
            title: 'Local storage',
            subtitle: 'Clear cached media and review app data usage from this screen.',
            icon: LucideIcons.databaseZap,
          ),
          const SizedBox(height: 12),
          _centerTile(
            context,
            icon: LucideIcons.wandSparkles,
            title: 'Clear cache',
            subtitle: 'Remove cached images and downloaded assets',
            onTap: () async {
              await onClearCache();
            },
          ),
          _centerTile(
            context,
            icon: LucideIcons.messageSquareMore,
            title: 'Floating message bubble',
            subtitle: 'Toggle the persistent message shortcut from the main app',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _HelpSupportScreen extends StatelessWidget {
  final Future<void> Function() onContactSupport;

  const _HelpSupportScreen({required this.onContactSupport});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            context,
            title: 'Need help?',
            subtitle: 'Start here for support requests, feedback, and troubleshooting guidance.',
            icon: Icons.help_outline,
          ),
          const SizedBox(height: 12),
          _centerTile(
            context,
            icon: Icons.mail_outline,
            title: 'Contact support',
            subtitle: 'Send a message to the support inbox',
            onTap: () async {
              await onContactSupport();
            },
          ),
          _centerTile(
            context,
            icon: Icons.bug_report_outlined,
            title: 'Report a problem',
            subtitle: 'Share bugs, crashes, or unexpected behavior',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report flow will be connected next.')),
              );
            },
          ),
          _centerTile(
            context,
            icon: Icons.quiz_outlined,
            title: 'FAQ',
            subtitle: 'Common questions and account guidance',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('FAQ page is coming soon.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LegalComplianceScreen extends StatelessWidget {
  const _LegalComplianceScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legal & Compliance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            context,
            title: 'Policies and rules',
            subtitle: 'Keep your account aligned with bSmart privacy, terms, and moderation rules.',
            icon: Icons.gavel,
          ),
          const SizedBox(height: 12),
          _centerTile(
            context,
            icon: Icons.privacy_tip,
            title: 'Privacy policy',
            subtitle: 'How data is collected and used',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy page is coming soon.')),
              );
            },
          ),
          _centerTile(
            context,
            icon: Icons.article_outlined,
            title: 'Terms of service',
            subtitle: 'Rules for using bSmart',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terms page is coming soon.')),
              );
            },
          ),
          _centerTile(
            context,
            icon: Icons.rule_outlined,
            title: 'Community guidelines',
            subtitle: 'Content and behavior standards',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Guidelines page is coming soon.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AboutScreen extends StatelessWidget {
  final PackageInfo? packageInfo;

  const _AboutScreen({required this.packageInfo});

  @override
  Widget build(BuildContext context) {
    final versionText = packageInfo == null
        ? 'Version information loading...'
        : 'Version ${packageInfo!.version} (${packageInfo!.buildNumber})';
    return Scaffold(
      appBar: AppBar(title: const Text('About bSmart')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            context,
            title: 'bSmart',
            subtitle: 'Social, creator, and vendor experiences in one app.',
            icon: Icons.apps_outlined,
          ),
          const SizedBox(height: 12),
          _centerTile(
            context,
            icon: LucideIcons.info,
            title: 'App version',
            subtitle: versionText,
            onTap: () {},
          ),
          _centerTile(
            context,
            icon: LucideIcons.sparkles,
            title: 'What is bSmart?',
            subtitle: 'A short product overview and roadmap can live here.',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

Widget _infoCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
}) {
  final theme = Theme.of(context);
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: theme.dividerColor.withOpacity(0.25),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: DesignTokens.instaPink.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: DesignTokens.instaPink, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: theme.textTheme.bodyMedium?.color ??
                      Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _centerTile(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DesignTokens.instaPink.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: DesignTokens.instaPink, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: theme.textTheme.bodyMedium?.color ??
                            Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                color: theme.iconTheme.color ?? Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
