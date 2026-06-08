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
  bool _deactivatingAccount = false;
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
          title: const Text('Delete Account Permanently'),
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

  Future<void> _showDeactivateAccountDialog() async {
    if (_deactivatingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Deactivate Account'),
          content: const Text(
            'This build does not yet have a live deactivate-account API wired up. '
            'We can connect it later, but for now this will only show the flow.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
              ),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deactivatingAccount = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deactivate account flow is not connected yet.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _deactivatingAccount = false);
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
            onTap: () => Navigator.of(context).pushNamed('/wallet'),
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
          _sectionTitle('Account Actions'),
          _sectionTitle('Session Controls'),
          _destructiveActionCard(
            icon: LucideIcons.logOut,
            title: _loggingOut ? 'Logging out...' : 'Logout',
            subtitle: 'Sign out of your account on this device',
            loading: _loggingOut,
            onTap: _loggingOut ? null : _logout,
          ),
          const SizedBox(height: 20),
          _sectionTitle('Account Controls'),
          _destructiveActionCard(
            icon: LucideIcons.userX,
            title: _deactivatingAccount
                ? 'Preparing deactivate flow...'
                : 'Deactivate Account',
            subtitle: 'Temporarily disable your account',
            loading: _deactivatingAccount,
            onTap: _deactivatingAccount ? null : _showDeactivateAccountDialog,
            danger: false,
          ),
          const SizedBox(height: 12),
          _destructiveActionCard(
            icon: LucideIcons.trash2,
            title: _deletingAccount
                ? 'Preparing delete flow...'
                : 'Delete Account Permanently',
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

class _StorageDataScreen extends StatefulWidget {
  final Future<void> Function() onClearCache;

  const _StorageDataScreen({required this.onClearCache});

  @override
  State<_StorageDataScreen> createState() => _StorageDataScreenState();
}

class _StorageDataScreenState extends State<_StorageDataScreen> {
  bool _mobileDataSaver = false;
  bool _wifiOnlyDownloads = true;
  final int _cachedImagesMb = 184;
  final int _cachedVideosMb = 512;
  final int _cachedDocumentsMb = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalStorage = _cachedImagesMb + _cachedVideosMb + _cachedDocumentsMb;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Storage & Data'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _storageHeader(isDark, totalStorage),
            const SizedBox(height: 20),
            _sectionTitle('Storage'),
            _settingsCard(
              children: [
                _actionRow(
                  icon: LucideIcons.wandSparkles,
                  title: 'Clear Cache',
                  subtitle: 'Remove cached images and downloaded assets.',
                  onTap: _clearCache,
                  trailing: const Text(
                    'Recommended',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const Divider(height: 1),
                _actionRow(
                  icon: LucideIcons.download,
                  title: 'Downloaded Media',
                  subtitle: 'Manage files saved for offline access.',
                  onTap: () => _showUnavailable('Downloaded Media'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Data Usage'),
            _settingsCard(
              children: [
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text('Mobile Data Saver'),
                  subtitle: const Text('Reduce data usage when on cellular data.'),
                  value: _mobileDataSaver,
                  activeThumbColor: DesignTokens.instaPink,
                  activeTrackColor:
                      DesignTokens.instaPink.withValues(alpha: 0.35),
                  inactiveThumbColor:
                      isDark ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563),
                  inactiveTrackColor:
                      isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                  onChanged: (value) {
                    setState(() => _mobileDataSaver = value);
                    _showUnavailable(
                      'Mobile Data Saver is local-only in this build.',
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text('Wi-Fi Only Downloads'),
                  subtitle:
                      const Text('Only download media when connected to Wi-Fi.'),
                  value: _wifiOnlyDownloads,
                  activeThumbColor: DesignTokens.instaPink,
                  activeTrackColor:
                      DesignTokens.instaPink.withValues(alpha: 0.35),
                  inactiveThumbColor:
                      isDark ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563),
                  inactiveTrackColor:
                      isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                  onChanged: (value) {
                    setState(() => _wifiOnlyDownloads = value);
                    _showUnavailable(
                      'Wi-Fi Only Downloads is local-only in this build.',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Storage Breakdown'),
            _settingsCard(
              children: [
                _breakdownRow(
                  label: 'Images',
                  valueMb: _cachedImagesMb,
                  color: DesignTokens.instaPink,
                ),
                const Divider(height: 1),
                _breakdownRow(
                  label: 'Videos',
                  valueMb: _cachedVideosMb,
                  color: DesignTokens.instaOrange,
                ),
                const Divider(height: 1),
                _breakdownRow(
                  label: 'Documents',
                  valueMb: _cachedDocumentsMb,
                  color: DesignTokens.instaPurple,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoCard(isDark, totalStorage),
          ],
        ),
      ),
    );
  }

  Widget _storageHeader(bool isDark, int totalStorage) {
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
              Icons.storage_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Storage & data',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalStorage MB cached locally',
                  style: const TextStyle(color: Colors.white, height: 1.3),
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

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
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
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing,
            ],
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: hintColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow({
    required String label,
    required int valueMb,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final total = (_cachedImagesMb + _cachedVideosMb + _cachedDocumentsMb).clamp(1, 999999);
    final percent = valueMb / total;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.circle, color: color, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: percent,
                    backgroundColor: hintColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$valueMb MB',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: hintColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(bool isDark, int totalStorage) {
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
              'Clear cache is the only action that connects to a real local cleanup right now. '
              'Downloaded Media, Data Usage, and the breakdown rows represent about $totalStorage MB of cached content right now, and can be connected later if a backend endpoint is added.',
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

  Future<void> _clearCache() async {
    await widget.onClearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared')),
    );
  }

  void _showUnavailable(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No API exists yet for $label.')),
    );
  }
}

class _HelpSupportScreen extends StatelessWidget {
  final Future<void> Function() onContactSupport;

  const _HelpSupportScreen({required this.onContactSupport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Help & Support'),
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
            _sectionTitle('Support'),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.mail_outline,
                  title: 'Contact Support',
                  subtitle: 'Email the support inbox for account help and troubleshooting.',
                  onTap: () async {
                    await onContactSupport();
                  },
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.confirmation_num_outlined,
                  title: 'Raise a Ticket',
                  subtitle: 'Create a support request for follow-up.',
                  onTap: () => _showUnavailable(context, 'Raise a Ticket'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.chat_bubble_outline,
                  title: 'Live Chat',
                  subtitle: 'Chat with support in real time.',
                  onTap: () => _showUnavailable(context, 'Live Chat'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Resources'),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.quiz_outlined,
                  title: 'FAQs',
                  subtitle: 'Common questions and quick answers.',
                  onTap: () => _showUnavailable(context, 'FAQs'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.video_library_outlined,
                  title: 'Tutorials',
                  subtitle: 'Step-by-step walkthroughs and how-to videos.',
                  onTap: () => _showUnavailable(context, 'Tutorials'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.menu_book_outlined,
                  title: 'User Guide',
                  subtitle: 'Learn how to use bSmart features and tools.',
                  onTap: () => _showUnavailable(context, 'User Guide'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Reports'),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.bug_report_outlined,
                  title: 'Report a Bug',
                  subtitle: 'Flag crashes, layout issues, or broken flows.',
                  onTap: () => _showUnavailable(context, 'Report a Bug'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.flag_outlined,
                  title: 'Report Content',
                  subtitle: 'Report posts, reels, or ads that violate rules.',
                  onTap: () => _showUnavailable(context, 'Report Content'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.person_off_outlined,
                  title: 'Report a User',
                  subtitle: 'Report harassment, spam, or abuse.',
                  onTap: () => _showUnavailable(context, 'Report a User'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoCard(
              context,
              title: 'Help hub',
              subtitle:
                  'Contact Support is wired to email right now. The rest of the help items are shown in the new hub layout and will show a snackbar until their flows are connected.',
              icon: Icons.support_agent,
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
              Icons.help_outline,
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
                  'Help & support',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Support, resources, and reporting tools in one place.',
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

  Widget _settingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
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

  Widget _actionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: hintColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No API exists yet for $label.')),
    );
  }
}

class _LegalComplianceScreen extends StatelessWidget {
  const _LegalComplianceScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Legal & Compliance'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _legalHeader(isDark),
            const SizedBox(height: 20),
            _sectionTitle('Legal Documents'),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.article_outlined,
                  title: 'Terms & Conditions',
                  subtitle: 'Rules for using bSmart.',
                  onTap: () => _showUnavailable(context, 'Terms & Conditions'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How your data is collected and used.',
                  onTap: () => _showUnavailable(context, 'Privacy Policy'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.receipt_long_outlined,
                  title: 'Refund Policy',
                  subtitle: 'Refund rules for purchases and services.',
                  onTap: () => _showUnavailable(context, 'Refund Policy'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.rule_outlined,
                  title: 'Community Guidelines',
                  subtitle: 'Content and behavior standards.',
                  onTap: () => _showUnavailable(context, 'Community Guidelines'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Data Controls'),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.download_outlined,
                  title: 'Download My Data',
                  subtitle: 'Export your account data.',
                  onTap: () => _showUnavailable(context, 'Download My Data'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.delete_outline,
                  title: 'Delete My Data',
                  subtitle: 'Request permanent deletion of stored data.',
                  onTap: () => _showUnavailable(context, 'Delete My Data'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Consent Management'),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.tune_outlined,
                  title: 'Manage Consent Preferences',
                  subtitle: 'Control optional data and communication consent.',
                  onTap: () => _showUnavailable(
                    context,
                    'Manage Consent Preferences',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('DPDP Compliance'),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.manage_search_outlined,
                  title: 'Data Access Request',
                  subtitle: 'Request a copy of your personal data.',
                  onTap: () => _showUnavailable(context, 'Data Access Request'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.edit_outlined,
                  title: 'Data Correction Request',
                  subtitle: 'Request a correction to inaccurate data.',
                  onTap: () =>
                      _showUnavailable(context, 'Data Correction Request'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.delete_sweep_outlined,
                  title: 'Data Deletion Request',
                  subtitle: 'Request deletion under applicable law.',
                  onTap: () =>
                      _showUnavailable(context, 'Data Deletion Request'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoCard(
              context,
              title: 'Legal hub',
              subtitle:
                  'This page is organized to match the rest of settings. The listed legal/data requests are visible here, but they will show a snackbar until a dedicated backend flow is added.',
              icon: Icons.gavel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _legalHeader(bool isDark) {
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
              Icons.gavel_outlined,
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
                  'Legal & compliance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Documents, data controls, consent, and DPDP request tools.',
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

  Widget _settingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
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

  Widget _actionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: hintColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No API exists yet for $label.')),
    );
  }
}

class _AboutScreen extends StatelessWidget {
  final PackageInfo? packageInfo;

  const _AboutScreen({required this.packageInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final versionText = packageInfo == null
        ? 'Version information loading...'
        : 'Version ${packageInfo!.version}';
    final buildText = packageInfo == null
        ? 'Build information loading...'
        : 'Build ${packageInfo!.buildNumber}';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('About bSmart'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _aboutHeader(isDark),
            const SizedBox(height: 20),
            _sectionTitle('Application Information'),
            _settingsCard(
              context,
              children: [
                _detailRow(
                  context,
                  icon: Icons.apps_outlined,
                  title: 'App Version',
                  subtitle: versionText,
                ),
                const Divider(height: 1),
                _detailRow(
                  context,
                  icon: Icons.tag_outlined,
                  title: 'Build Number',
                  subtitle: buildText,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Company Information'),
            _settingsCard(
              context,
              children: [
                _detailRow(
                  context,
                  icon: Icons.business_outlined,
                  title: 'RuVees IT Solution Pvt Ltd',
                  subtitle: 'Built and maintained by the bSmart team.',
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Links'),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: LucideIcons.globe,
                  title: 'Website',
                  subtitle: 'Visit the official website.',
                  onTap: () => _showUnavailable(context, 'Website'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: LucideIcons.linkedin,
                  title: 'LinkedIn',
                  subtitle: 'Follow company updates and hiring news.',
                  onTap: () => _showUnavailable(context, 'LinkedIn'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: LucideIcons.youtube,
                  title: 'YouTube',
                  subtitle: 'Watch tutorials, updates, and announcements.',
                  onTap: () => _showUnavailable(context, 'YouTube'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoCard(
              context,
              title: 'About bSmart',
              subtitle:
                  'bSmart brings social, creator, and vendor experiences together in one app. The layout here now matches the rest of the settings flow.',
              icon: Icons.info_outline,
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutHeader(bool isDark) {
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
              Icons.apps_outlined,
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
                  'About bSmart',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Application details, company info, and official links.',
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

  Widget _settingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
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

  Widget _detailRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF242424) : const Color(0xFFF6F7F9);
    final border = isDark ? const Color(0xFF444444) : const Color(0xFFD7DCE3);
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
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
        ],
      ),
    );
  }

  Widget _actionRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
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
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: hintColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No API exists yet for $label.')),
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
