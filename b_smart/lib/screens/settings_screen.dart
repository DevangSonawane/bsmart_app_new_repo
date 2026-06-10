import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../services/auth/auth_service.dart';
import '../theme/design_tokens.dart';
import '../theme/theme_scope.dart';
import 'account_details_screen.dart';
import 'account_upgrade_screen.dart';
import 'appearance_settings_screen.dart';
import 'advertiser_ads_list_screen.dart';
import 'advertiser_dashboard_screen.dart';
import 'advertiser_wallet_screen.dart';
import 'auth/login/login_screen.dart';
import 'content_settings_screen.dart';
import 'messaging_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'privacy_screen.dart';
import 'security_screen.dart';
import 'wallet_screen.dart';

String _trFallback(String key, String fallback) {
  final value = key.tr();
  return value == key ? fallback : value;
}

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
          title: Text('settings_delete_account_permanently'.tr()),
          content: Text('settings_delete_account_dialog_body'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('common_cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
              child: Text('common_continue'.tr()),
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
          title: Text('settings_deactivate_account'.tr()),
          content: Text('settings_deactivate_account_dialog_body'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('common_cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
              ),
              child: Text('common_continue'.tr()),
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
          'settings_profile_settings'.tr(),
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
          _sectionTitle('settings_section_account'.tr()),
          _settingTile(
            icon: Icons.account_circle_outlined,
            label: 'settings_account'.tr(),
            subLabel: 'settings_account_subtitle'.tr(),
            onTap: () => _push(const AccountDetailsScreen()),
          ),
          _settingTile(
            icon: LucideIcons.shield,
            label: 'settings_privacy'.tr(),
            subLabel: 'settings_privacy_subtitle'.tr(),
            onTap: () => _push(const PrivacyScreen()),
          ),
          _settingTile(
            icon: LucideIcons.lockKeyhole,
            label: 'settings_security'.tr(),
            subLabel: 'settings_security_subtitle'.tr(),
            onTap: () => _push(const SecurityScreen()),
          ),
          const SizedBox(height: 20),
          _sectionTitle('settings_section_notifications'.tr()),
          _settingTile(
            icon: LucideIcons.bell,
            label: 'settings_notifications'.tr(),
            subLabel: 'settings_notifications_subtitle'.tr(),
            onTap: () => _push(const NotificationSettingsScreen()),
          ),
          _settingTile(
            icon: LucideIcons.messageSquareMore,
            label: 'settings_messaging'.tr(),
            subLabel: 'settings_messaging_subtitle'.tr(),
            onTap: () => _push(const MessagingSettingsScreen()),
          ),
          const SizedBox(height: 20),
          _sectionTitle('settings_section_preferences'.tr()),
          _settingTile(
            icon: isDark ? LucideIcons.moon : LucideIcons.sunMedium,
            label: 'settings_appearance'.tr(),
            subLabel: 'settings_appearance_subtitle'.tr(),
            trailing: Icon(
              LucideIcons.chevronRight,
              color: theme.iconTheme.color ?? Colors.grey.shade400,
              size: 20,
            ),
            onTap: () => _push(const AppearanceSettingsScreen()),
          ),
          _settingTile(
            icon: LucideIcons.slidersHorizontal,
            label: 'settings_content_preferences'.tr(),
            subLabel: 'settings_content_preferences_subtitle'.tr(),
            onTap: () => _push(const ContentSettingsScreen()),
          ),
          const SizedBox(height: 20),
          _sectionTitle('settings_section_rewards'.tr()),
          _settingTile(
            icon: LucideIcons.wallet,
            label: 'settings_rewards_wallet'.tr(),
            subLabel: 'settings_rewards_wallet_subtitle'.tr(),
            onTap: () => Navigator.of(context).pushNamed('/wallet'),
          ),
          if (_isCreator) ...[
            _settingTile(
              icon: LucideIcons.sparkles,
              label: 'settings_creator_center'.tr(),
              subLabel: 'settings_creator_center_subtitle'.tr(),
              onTap: () => _push(const _CreatorCenterScreen()),
            ),
          ],
          if (_isVendor) ...[
            _settingTile(
              icon: LucideIcons.store,
              label: 'settings_vendor_center'.tr(),
              subLabel: 'settings_vendor_center_subtitle'.tr(),
              onTap: () => _push(const _VendorCenterScreen()),
            ),
          ],
          const SizedBox(height: 20),
          _sectionTitle('settings_section_safety'.tr()),
          _settingTile(
            icon: LucideIcons.userX,
            label: 'settings_blocked_accounts'.tr(),
            subLabel: 'settings_blocked_accounts_subtitle'.tr(),
            onTap: () => _push(const _BlockedRestrictedScreen()),
          ),
          const SizedBox(height: 20),
          _sectionTitle('settings_section_data'.tr()),
          _settingTile(
            icon: LucideIcons.databaseZap,
            label: 'settings_storage_data'.tr(),
            subLabel: 'settings_storage_data_subtitle'.tr(),
            onTap: () => _push(_StorageDataScreen(onClearCache: _clearCache)),
          ),
          const SizedBox(height: 20),
          _sectionTitle('settings_section_support'.tr()),
          _settingTile(
            icon: Icons.help_outline,
            label: 'settings_help_support'.tr(),
            subLabel: 'settings_help_support_subtitle'.tr(),
            onTap: () => _push(_HelpSupportScreen(onContactSupport: _openMailSupport)),
          ),
          _settingTile(
            icon: Icons.article_outlined,
            label: 'settings_legal_compliance'.tr(),
            subLabel: 'settings_legal_compliance_subtitle'.tr(),
            onTap: () => _push(const _LegalComplianceScreen()),
          ),
          const SizedBox(height: 20),
          _sectionTitle('settings_section_about'.tr()),
          _settingTile(
            icon: Icons.info_outline,
            label: 'settings_about_bsmart'.tr(),
            subLabel: _aboutSubtitle,
            onTap: () => _push(_AboutScreen(packageInfo: _info)),
          ),
          const SizedBox(height: 20),
          _sectionTitle('settings_section_account_actions'.tr()),
          _settingTile(
            icon: LucideIcons.logOut,
            label: _trFallback('settings_section_account_actions', 'Account Actions'),
            subLabel: _trFallback(
              'settings_account_actions_subtitle',
              'Open logout, deactivate, and delete options',
            ),
            onTap: () => _push(
              _AccountActionsScreen(
                loggingOut: _loggingOut,
                deactivatingAccount: _deactivatingAccount,
                deletingAccount: _deletingAccount,
                onLogout: _logout,
                onDeactivateAccount: _showDeactivateAccountDialog,
                onDeleteAccount: _showDeleteAccountDialog,
              ),
            ),
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

  String _appearanceModeLabel() {
    final mode = ThemeScope.of(context).themeMode;
    switch (mode) {
      case ThemeMode.light:
        return 'appearance_light_mode';
      case ThemeMode.dark:
        return 'appearance_dark_mode';
      case ThemeMode.system:
        return 'appearance_system_default';
    }
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
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
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
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
                Text(
                  'settings_profile_settings'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'settings_profile_settings_subtitle'.tr(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
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
                    if (_isCreator) _chip('settings_creator_tools_enabled'.tr()),
                    if (_isVendor) _chip('settings_vendor_tools_enabled'.tr()),
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
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
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
                    color: DesignTokens.instaPink.withValues(alpha: 0.12),
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

}

class _CreatorCenterScreen extends StatelessWidget {
  const _CreatorCenterScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('settings_creator_center'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            context,
            title: 'settings_creator_tools_title'.tr(),
            subtitle: 'settings_creator_tools_subtitle'.tr(),
            icon: LucideIcons.sparkles,
          ),
          const SizedBox(height: 12),
          _centerTile(
            context,
            icon: Icons.insights,
            title: 'settings_creator_dashboard'.tr(),
            subtitle: 'settings_creator_dashboard_subtitle'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdvertiserDashboardScreen()),
            ),
          ),
          _centerTile(
            context,
            icon: Icons.account_balance_wallet,
            title: 'settings_creator_earnings_wallet'.tr(),
            subtitle: 'settings_creator_earnings_wallet_subtitle'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WalletScreen()),
            ),
          ),
          _centerTile(
            context,
            icon: Icons.verified,
            title: 'settings_creator_onboarding'.tr(),
            subtitle: 'settings_creator_onboarding_subtitle'.tr(),
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
      appBar: AppBar(title: Text('settings_vendor_center'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            context,
            title: 'settings_vendor_tools_title'.tr(),
            subtitle: 'settings_vendor_tools_subtitle'.tr(),
            icon: LucideIcons.store,
          ),
          const SizedBox(height: 12),
          _centerTile(
            context,
            icon: LucideIcons.layoutDashboard,
            title: 'settings_vendor_dashboard'.tr(),
            subtitle: 'settings_vendor_dashboard_subtitle'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdvertiserDashboardScreen()),
            ),
          ),
          _centerTile(
            context,
            icon: LucideIcons.megaphone,
            title: 'settings_vendor_ad_manager'.tr(),
            subtitle: 'settings_vendor_ad_manager_subtitle'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdvertiserAdsListScreen()),
            ),
          ),
          _centerTile(
            context,
            icon: LucideIcons.wallet,
            title: 'settings_vendor_business_wallet'.tr(),
            subtitle: 'settings_vendor_business_wallet_subtitle'.tr(),
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
      appBar: AppBar(title: Text('settings_blocked_accounts'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            context,
            title: 'settings_account_safety_title'.tr(),
            subtitle: 'settings_account_safety_subtitle'.tr(),
            icon: Icons.block,
          ),
          const SizedBox(height: 12),
          _centerTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'settings_review_privacy'.tr(),
            subtitle: 'settings_review_privacy_subtitle'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyScreen()),
            ),
          ),
          _centerTile(
            context,
            icon: Icons.report_gmailerrorred_outlined,
            title: 'settings_content_restrictions'.tr(),
            subtitle: 'settings_content_restrictions_subtitle'.tr(),
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final totalStorage = _cachedImagesMb + _cachedVideosMb + _cachedDocumentsMb;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('settings_storage_data'.tr()),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            _sectionTitle('settings_storage_section_storage'.tr()),
            _settingsCard(
              children: [
                _actionRow(
                  icon: LucideIcons.wandSparkles,
                  title: 'settings_clear_cache'.tr(),
                  subtitle: 'settings_clear_cache_subtitle'.tr(),
                  onTap: _clearCache,
                  trailing: Text(
                    'settings_recommended'.tr(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const Divider(height: 1),
                _actionRow(
                  icon: LucideIcons.download,
                  title: 'settings_downloaded_media'.tr(),
                  subtitle: 'settings_downloaded_media_subtitle'.tr(),
                  onTap: () => _showUnavailable('settings_downloaded_media'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('settings_storage_section_data_usage'.tr()),
            _settingsCard(
              children: [
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text('settings_mobile_data_saver'.tr()),
                  subtitle: Text('settings_mobile_data_saver_subtitle'.tr()),
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
                    _showUnavailable('settings_mobile_data_saver_local_only'.tr());
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text('settings_wifi_only_downloads'.tr()),
                  subtitle: Text('settings_wifi_only_downloads_subtitle'.tr()),
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
                    _showUnavailable('settings_wifi_only_downloads_local_only'.tr());
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('settings_storage_breakdown'.tr()),
            _settingsCard(
              children: [
                _breakdownRow(
                  label: 'settings_images'.tr(),
                  valueMb: _cachedImagesMb,
                  color: DesignTokens.instaPink,
                ),
                const Divider(height: 1),
                _breakdownRow(
                  label: 'settings_videos'.tr(),
                  valueMb: _cachedVideosMb,
                  color: DesignTokens.instaOrange,
                ),
                const Divider(height: 1),
                _breakdownRow(
                  label: 'settings_documents'.tr(),
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
              'settings_storage_info_text'.tr(args: ['$totalStorage']),
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
      SnackBar(content: Text('settings_cache_cleared'.tr())),
    );
  }

  void _showUnavailable(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings_no_api_exists_yet'.tr(args: [label]))),
    );
  }
}

class _HelpSupportScreen extends StatelessWidget {
  final Future<void> Function() onContactSupport;

  const _HelpSupportScreen({required this.onContactSupport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('settings_help_support'.tr()),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            _sectionTitle('settings_help_section_support'.tr()),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.mail_outline,
                  title: 'settings_contact_support'.tr(),
                  subtitle: 'settings_contact_support_subtitle'.tr(),
                  onTap: () async {
                    await onContactSupport();
                  },
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.confirmation_num_outlined,
                  title: 'settings_raise_ticket'.tr(),
                  subtitle: 'settings_raise_ticket_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_raise_ticket'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.chat_bubble_outline,
                  title: 'settings_live_chat'.tr(),
                  subtitle: 'settings_live_chat_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_live_chat'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('settings_help_section_resources'.tr()),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.quiz_outlined,
                  title: 'settings_faqs'.tr(),
                  subtitle: 'settings_faqs_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_faqs'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.video_library_outlined,
                  title: 'settings_tutorials'.tr(),
                  subtitle: 'settings_tutorials_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_tutorials'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.menu_book_outlined,
                  title: 'settings_user_guide'.tr(),
                  subtitle: 'settings_user_guide_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_user_guide'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('settings_help_section_reports'.tr()),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.bug_report_outlined,
                  title: 'settings_report_bug'.tr(),
                  subtitle: 'settings_report_bug_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_report_bug'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.flag_outlined,
                  title: 'settings_report_content'.tr(),
                  subtitle: 'settings_report_content_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_report_content'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.person_off_outlined,
                  title: 'settings_report_user'.tr(),
                  subtitle: 'settings_report_user_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_report_user'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoCard(
              context,
              title: 'settings_help_hub'.tr(),
              subtitle: 'settings_help_hub_subtitle'.tr(),
              icon: Icons.support_agent,
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
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
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
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: hintColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings_no_api_exists_yet'.tr(args: [label]))),
    );
  }
}

class _LegalComplianceScreen extends StatelessWidget {
  const _LegalComplianceScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('settings_legal_compliance'.tr()),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            _sectionTitle('settings_legal_section_documents'.tr()),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.article_outlined,
                  title: 'settings_terms_conditions'.tr(),
                  subtitle: 'settings_terms_conditions_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_terms_conditions'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: 'settings_privacy_policy'.tr(),
                  subtitle: 'settings_privacy_policy_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_privacy_policy'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.receipt_long_outlined,
                  title: 'settings_refund_policy'.tr(),
                  subtitle: 'settings_refund_policy_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_refund_policy'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.rule_outlined,
                  title: 'settings_community_guidelines'.tr(),
                  subtitle: 'settings_community_guidelines_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_community_guidelines'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('settings_legal_section_data_controls'.tr()),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.download_outlined,
                  title: 'settings_download_my_data'.tr(),
                  subtitle: 'settings_download_my_data_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_download_my_data'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.delete_outline,
                  title: 'settings_delete_my_data'.tr(),
                  subtitle: 'settings_delete_my_data_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_delete_my_data'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('settings_legal_section_consent_management'.tr()),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.tune_outlined,
                  title: 'settings_manage_consent_preferences'.tr(),
                  subtitle: 'settings_manage_consent_preferences_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_manage_consent_preferences'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('settings_legal_section_dpdp'.tr()),
            _settingsCard(
              context,
              children: [
                _actionRow(
                  context,
                  icon: Icons.manage_search_outlined,
                  title: 'settings_data_access_request'.tr(),
                  subtitle: 'settings_data_access_request_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_data_access_request'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.edit_outlined,
                  title: 'settings_data_correction_request'.tr(),
                  subtitle: 'settings_data_correction_request_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_data_correction_request'.tr()),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.delete_sweep_outlined,
                  title: 'settings_data_deletion_request'.tr(),
                  subtitle: 'settings_data_deletion_request_subtitle'.tr(),
                  onTap: () => _showUnavailable(context, 'settings_data_deletion_request'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoCard(
              context,
              title: 'settings_legal_hub'.tr(),
              subtitle: 'settings_legal_hub_subtitle'.tr(),
              icon: Icons.gavel,
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
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignTokens.instaPink.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: DesignTokens.instaPink, size: 20),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
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
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: hintColor, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings_no_api_exists_yet'.tr(args: [label]))),
    );
  }
}

class _AboutScreen extends StatelessWidget {
  final PackageInfo? packageInfo;

  const _AboutScreen({required this.packageInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
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
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
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
                  icon: Icons.language_outlined,
                  title: 'Website',
                  subtitle: 'Visit the official website.',
                  onTap: () => _showUnavailable(context, 'Website'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.work_outline,
                  title: 'LinkedIn',
                  subtitle: 'Follow company updates and hiring news.',
                  onTap: () => _showUnavailable(context, 'LinkedIn'),
                ),
                const Divider(height: 1),
                _actionRow(
                  context,
                  icon: Icons.play_circle_outline,
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
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
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
          ],
        ),
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
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignTokens.instaPink.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: DesignTokens.instaPink, size: 20),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
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
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right, color: hintColor, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnavailable(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings_no_api_exists_yet'.tr(args: [label]))),
    );
  }
}

class _AccountActionsScreen extends StatelessWidget {
  final bool loggingOut;
  final bool deactivatingAccount;
  final bool deletingAccount;
  final Future<void> Function() onLogout;
  final Future<void> Function() onDeactivateAccount;
  final Future<void> Function() onDeleteAccount;

  const _AccountActionsScreen({
    required this.loggingOut,
    required this.deactivatingAccount,
    required this.deletingAccount,
    required this.onLogout,
    required this.onDeactivateAccount,
    required this.onDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

      return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_trFallback('settings_section_account_actions', 'Account Actions')),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pill('Support'),
                _pill('About'),
                _pill('Security'),
                _pill('Policies'),
              ],
            ),
            const SizedBox(height: 5),
            _sectionTitle('settings_section_session_controls'.tr()),
            _settingsCard(
              context,
              children: [
                _destructiveActionCard(
                  context,
                  icon: LucideIcons.logOut,
                  title: loggingOut
                      ? 'settings_logging_out'.tr()
                      : 'settings_logout'.tr(),
                  subtitle: 'settings_logout_subtitle'.tr(),
                  loading: loggingOut,
                  onTap: loggingOut ? null : () async => onLogout(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('settings_section_account_controls'.tr()),
            _settingsCard(
              context,
              children: [
                _destructiveActionCard(
                  context,
                  icon: LucideIcons.userX,
                  title: deactivatingAccount
                      ? 'settings_preparing_deactivate'.tr()
                      : 'settings_deactivate_account'.tr(),
                  subtitle: 'settings_deactivate_account_subtitle'.tr(),
                  loading: deactivatingAccount,
                  onTap:
                      deactivatingAccount ? null : () async => onDeactivateAccount(),
                  danger: false,
                ),
                const Divider(height: 1),
                _destructiveActionCard(
                  context,
                  icon: LucideIcons.trash2,
                  title: deletingAccount
                      ? 'settings_preparing_delete'.tr()
                      : 'settings_delete_account_permanently'.tr(),
                  subtitle: 'settings_delete_account_subtitle'.tr(),
                  loading: deletingAccount,
                  onTap: deletingAccount ? null : () async => onDeleteAccount(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
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

  Widget _destructiveActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool loading = false,
    bool danger = true,
  }) {
    final theme = Theme.of(context);
    final color = danger ? Colors.red.shade700 : Colors.red.shade600;
    return Material(
      color: theme.cardColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
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
        color: theme.dividerColor.withValues(alpha: 0.25),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: DesignTokens.instaPink.withValues(alpha: 0.12),
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
                  color: DesignTokens.instaPink.withValues(alpha: 0.12),
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
