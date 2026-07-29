import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/notification_settings_api.dart';
import '../services/push_service.dart';
import '../theme/design_tokens.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationSettingsApi _api = NotificationSettingsApi();

  NotificationSettingsData _prefs = NotificationSettingsData.defaults();
  bool _loading = true;
  String? _pageError;
  String? _saveError;
  String? _savingKey;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() {
      _loading = true;
      _pageError = null;
      _saveError = null;
    });
    try {
      final prefs = await _api.getSettings();
      if (!mounted) return;
      setState(() {
        _prefs = prefs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pageError = 'Failed to load notification settings.';
      });
    }
  }

  Future<void> _toggleSetting(String key, bool value) async {
    if (_savingKey != null) return;

    final previous = _prefs;
    setState(() {
      _prefs = _prefs.copyWithValue(key, value);
      _savingKey = key;
      _saveError = null;
    });

    try {
      final saved = await _api.updateSetting(key, value);
      if (!mounted) return;
      setState(() {
        _prefs = saved;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _prefs = previous;
        _saveError = 'Failed to save. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _savingKey = null);
      }
    }

    if (!mounted) return;
    if (key == 'push_notifications') {
      try {
        if (value) {
          await PushService().syncTokenWithBackend();
        } else {
          await PushService().unregisterFromBackend();
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update device push registration.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadPrefs,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: _loading
            ? const Center(
                child: Text(
                  'Loading notification settings...',
                  style: TextStyle(fontSize: 13),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (_pageError != null) ...[
                    _errorBanner(
                      context,
                      message: _pageError!,
                      actionLabel: 'Retry',
                      onAction: _loadPrefs,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_saveError != null) ...[
                    _errorBanner(
                      context,
                      message: _saveError!,
                      actionLabel: 'Dismiss',
                      onAction: () => setState(() => _saveError = null),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _summaryCard(),
                  const SizedBox(height: 20),
                  _sectionTitle('General'),
                  _settingsCard(
                    children: [
                      _toggleRow(
                        icon: Icons.notifications_active_outlined,
                        title: 'Push Notifications',
                        subtitle: 'Receive push notifications on this device.',
                        value: _prefs.value('push_notifications'),
                        onChanged: (value) =>
                            _toggleSetting('push_notifications', value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Moments & Comments'),
                  _settingsCard(
                    children: [
                      _liveToggle(
                        icon: Icons.favorite_outline,
                        title: 'Likes',
                        subtitle: 'Someone likes your post or comment.',
                        keyName: 'likes',
                      ),
                      const Divider(height: 1),
                      _liveToggle(
                        icon: Icons.mode_comment_outlined,
                        title: 'Comments',
                        subtitle: 'Someone comments on your post.',
                        keyName: 'comments',
                      ),
                      const Divider(height: 1),
                      _liveToggle(
                        icon: Icons.reply_outlined,
                        title: 'Replies',
                        subtitle: 'Someone replies to your comment.',
                        keyName: 'replies',
                      ),
                      const Divider(height: 1),
                      _liveToggle(
                        icon: Icons.alternate_email,
                        title: 'Mentions',
                        subtitle: 'Someone mentions you in a post or comment.',
                        keyName: 'mentions',
                      ),
                      const Divider(height: 1),
                      _liveToggle(
                        icon: Icons.label_outline,
                        title: 'Tags',
                        subtitle: 'Someone tags you in a post or photo.',
                        keyName: 'tags',
                      ),
                      const Divider(height: 1),
                      _liveToggle(
                        icon: Icons.share_outlined,
                        title: 'Shares',
                        subtitle: 'Someone shares your post.',
                        keyName: 'shares',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Followers'),
                  _settingsCard(
                    children: [
                      _liveToggle(
                        icon: Icons.person_add_alt_1_outlined,
                        title: 'New Followers',
                        subtitle: 'Someone follows you.',
                        keyName: 'new_followers',
                      ),
                      const Divider(height: 1),
                      _liveToggle(
                        icon: Icons.group_add_outlined,
                        title: 'Follow Requests',
                        subtitle: 'Someone sends you a follow request.',
                        keyName: 'follow_requests',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Messages'),
                  _settingsCard(
                    children: [
                      _liveToggle(
                        icon: Icons.mail_outline,
                        title: 'New Messages',
                        subtitle: 'Someone sends you a direct message.',
                        keyName: 'new_messages',
                      ),
                      const Divider(height: 1),
                      _liveToggle(
                        icon: Icons.mark_chat_unread_outlined,
                        title: 'Message Requests',
                        subtitle: 'Requests from people you do not follow.',
                        keyName: 'message_requests',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
      ),
    );
  }

  Widget _summaryCard() {
    final enabled = _prefs.enabledCount;
    final total = _prefs.totalCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
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
            child: const Icon(
              LucideIcons.bell,
              color: DesignTokens.instaPink,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$enabled of $total enabled',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Manage what notifications you receive',
                  style: TextStyle(fontSize: 12, height: 1.35),
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

  Widget _liveToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required String keyName,
  }) {
    return _toggleRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: _prefs.value(keyName),
      onChanged: (value) => _toggleSetting(keyName, value),
    );
  }

  Widget _toggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor =
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (trailing != null) ...[
                trailing,
                const SizedBox(height: 8),
              ],
              Switch.adaptive(
                value: value,
                activeThumbColor: DesignTokens.instaPink,
                activeTrackColor:
                    DesignTokens.instaPink.withValues(alpha: 0.35),
                inactiveThumbColor: inactiveThumbColor,
                inactiveTrackColor: inactiveTrackColor,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
