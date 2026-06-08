import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
  bool _pushNotifications = true;
  bool _savingPush = false;

  final bool _likes = true;
  final bool _comments = true;
  final bool _replies = true;
  final bool _mentions = true;
  final bool _tags = true;
  final bool _shares = true;
  final bool _newFollowers = true;
  final bool _followRequests = true;

  final bool _newMessages = true;
  final bool _messageRequests = true;

  final bool _campaignInvites = false;
  final bool _collaborationRequests = false;
  final bool _earningsUpdates = false;

  final bool _productUpdates = false;
  final bool _promotions = false;
  final bool _marketingEmails = false;

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
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _headerCard(isDark),
            const SizedBox(height: 20),
            _sectionTitle('Delivery Methods'),
            _settingsCard(
              children: [
                _toggleRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Push Notifications',
                  subtitle: 'Receive real-time updates on this device.',
                  value: _pushNotifications,
                  onChanged: _togglePushNotifications,
                  trailing: _savingPush
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _pushNotifications
                  ? Column(
                      key: const ValueKey('expanded'),
                      children: [
                        _sectionTitle('Social Notifications'),
                        _settingsCard(
                          children: [
                            _toggleRow(
                              icon: Icons.favorite_outline,
                              title: 'Likes',
                              subtitle: 'People liking your posts.',
                              value: _likes,
                              onChanged: (value) =>
                                  _unsupportedToggle('Likes'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.mode_comment_outlined,
                              title: 'Comments',
                              subtitle: 'New comments on your posts.',
                              value: _comments,
                              onChanged: (value) =>
                                  _unsupportedToggle('Comments'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.reply_outlined,
                              title: 'Replies',
                              subtitle: 'Replies to your comments.',
                              value: _replies,
                              onChanged: (value) =>
                                  _unsupportedToggle('Replies'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.alternate_email,
                              title: 'Mentions',
                              subtitle: 'When someone mentions you.',
                              value: _mentions,
                              onChanged: (value) =>
                                  _unsupportedToggle('Mentions'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.label_outline,
                              title: 'Tags',
                              subtitle: 'When you are tagged in content.',
                              value: _tags,
                              onChanged: (value) => _unsupportedToggle('Tags'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.share_outlined,
                              title: 'Shares',
                              subtitle: 'When your content is shared.',
                              value: _shares,
                              onChanged: (value) =>
                                  _unsupportedToggle('Shares'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.person_add_alt_1_outlined,
                              title: 'New Followers',
                              subtitle: 'When someone follows you.',
                              value: _newFollowers,
                              onChanged: (value) =>
                                  _unsupportedToggle('New Followers'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.group_add_outlined,
                              title: 'Follow Requests',
                              subtitle:
                                  'Pending follow requests for private accounts.',
                              value: _followRequests,
                              onChanged: (value) =>
                                  _unsupportedToggle('Follow Requests'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle('Messaging Notifications'),
                        _settingsCard(
                          children: [
                            _toggleRow(
                              icon: Icons.mail_outline,
                              title: 'New Messages',
                              subtitle: 'Direct messages from other users.',
                              value: _newMessages,
                              onChanged: (value) =>
                                  _unsupportedToggle('New Messages'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.mark_chat_unread_outlined,
                              title: 'Message Requests',
                              subtitle:
                                  'Requests from users you do not follow.',
                              value: _messageRequests,
                              onChanged: (value) =>
                                  _unsupportedToggle('Message Requests'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle('Creator Notifications'),
                        _settingsCard(
                          children: [
                            _toggleRow(
                              icon: Icons.campaign_outlined,
                              title: 'Campaign Invitations',
                              subtitle: 'New campaign invites from brands.',
                              value: _campaignInvites,
                              onChanged: (value) =>
                                  _unsupportedToggle('Campaign Invitations'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.handshake_outlined,
                              title: 'Collaboration Requests',
                              subtitle:
                                  'Collab requests from creators and vendors.',
                              value: _collaborationRequests,
                              onChanged: (value) =>
                                  _unsupportedToggle('Collaboration Requests'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'Earnings Updates',
                              subtitle:
                                  'Wallet credits, payouts, and earnings activity.',
                              value: _earningsUpdates,
                              onChanged: (value) =>
                                  _unsupportedToggle('Earnings Updates'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _sectionTitle('Email Notifications'),
                        _settingsCard(
                          children: [
                            _toggleRow(
                              icon: Icons.newspaper_outlined,
                              title: 'Product Updates',
                              subtitle: 'App releases and feature updates.',
                              value: _productUpdates,
                              onChanged: (value) =>
                                  _unsupportedToggle('Product Updates'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.local_offer_outlined,
                              title: 'Promotions',
                              subtitle: 'Offers, deals, and announcements.',
                              value: _promotions,
                              onChanged: (value) =>
                                  _unsupportedToggle('Promotions'),
                            ),
                            const Divider(height: 1),
                            _toggleRow(
                              icon: Icons.mark_email_read_outlined,
                              title: 'Marketing Emails',
                              subtitle: 'Marketing and newsletter emails.',
                              value: _marketingEmails,
                              onChanged: (value) =>
                                  _unsupportedToggle('Marketing Emails'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _infoCard(isDark),
                      ],
                    )
                  : Column(
                      key: const ValueKey('collapsed'),
                      children: [
                        _collapsedCard(isDark),
                        const SizedBox(height: 20),
                        _infoCard(isDark),
                      ],
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
              Icons.notifications_none,
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
                  'Notification preferences',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Control how bSmart reaches you. Only supported settings are saved.',
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
    final labelColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final inactiveThumbColor = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563);
    final inactiveTrackColor = isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);

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
                activeTrackColor: DesignTokens.instaPink.withValues(alpha: 0.35),
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

  Widget _collapsedCard(bool isDark) {
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
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DesignTokens.instaPink.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              color: DesignTokens.instaPink,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Push notifications are off',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 3),
                Text(
                  'Turn push back on to expand and manage all notification categories.',
                  style: TextStyle(fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
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
              'Only Push Notifications are connected to a live backend action in this build. '
              'All other switches are UI-only for now and will show a snackbar.',
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

  Future<void> _togglePushNotifications(bool value) async {
    if (_savingPush) return;

    setState(() => _savingPush = true);
    try {
      if (value) {
        await PushService().syncTokenWithBackend();
      } else {
        await PushService().unregisterFromBackend();
      }

      if (!mounted) return;
      setState(() => _pushNotifications = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Push notifications enabled'
                : 'Push notifications disabled',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update push notifications: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingPush = false);
    }
  }

  void _unsupportedToggle(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No API exists yet for $label.'),
      ),
    );
  }
}
