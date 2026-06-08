import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/ui_prefs.dart';
import '../theme/design_tokens.dart';

class MessagingSettingsScreen extends StatefulWidget {
  const MessagingSettingsScreen({super.key});

  @override
  State<MessagingSettingsScreen> createState() =>
      _MessagingSettingsScreenState();
}

class _MessagingSettingsScreenState extends State<MessagingSettingsScreen> {
  bool _readReceipts = true;
  bool _lastSeen = true;
  bool _messageRequests = true;

  bool _autoDownloadImages = false;
  bool _autoDownloadVideos = false;
  bool _autoDownloadDocuments = false;

  bool _dataSaverMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Messaging'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            _headerCard(isDark),
            const SizedBox(height: 20),
            _sectionTitle('Chat Settings'),
            _settingsCard(
              children: [
                _toggleRow(
                  icon: LucideIcons.checkCheck,
                  title: 'Read Receipts',
                  subtitle: 'Let others see when you have read their messages.',
                  value: _readReceipts,
                  onChanged: (value) => setState(() => _readReceipts = value),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.eye,
                  title: 'Last Seen',
                  subtitle: 'Show when you were last active in chat.',
                  value: _lastSeen,
                  onChanged: (value) => setState(() => _lastSeen = value),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.messageSquareMore,
                  title: 'Message Requests',
                  subtitle:
                      'Receive chats from people you do not follow in requests.',
                  value: _messageRequests,
                  onChanged: (value) => setState(() => _messageRequests = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Media Settings'),
            _settingsCard(
              children: [
                _toggleRow(
                  icon: LucideIcons.image,
                  title: 'Auto Download Images',
                  subtitle: 'Download images automatically on mobile data or Wi-Fi.',
                  value: _autoDownloadImages,
                  onChanged: (value) =>
                      setState(() => _autoDownloadImages = value),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.video,
                  title: 'Auto Download Videos',
                  subtitle: 'Download video attachments automatically.',
                  value: _autoDownloadVideos,
                  onChanged: (value) =>
                      setState(() => _autoDownloadVideos = value),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.fileText,
                  title: 'Auto Download Documents',
                  subtitle: 'Download document attachments automatically.',
                  value: _autoDownloadDocuments,
                  onChanged: (value) =>
                      setState(() => _autoDownloadDocuments = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Data Usage'),
            _settingsCard(
              children: [
                _toggleRow(
                  icon: LucideIcons.wifiOff,
                  title: 'Data Saver Mode',
                  subtitle: 'Reduce media loading and limit heavy downloads.',
                  value: _dataSaverMode,
                  onChanged: (value) => setState(() => _dataSaverMode = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Floating Messages'),
            ValueListenableBuilder<bool>(
              valueListenable: UiPrefs.showFloatingMessage,
              builder: (context, showFloatingMessage, _) {
                return _settingsCard(
                  children: [
                    _toggleRow(
                      icon: LucideIcons.messageCircle,
                      title: 'Show Floating Message on Home',
                      subtitle:
                          'Display a floating message button on the home page.',
                      value: showFloatingMessage,
                      onChanged: (value) =>
                          UiPrefs.showFloatingMessage.value = value,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _infoCard(isDark),
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
              LucideIcons.messageSquareMore,
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
                  'Messaging preferences',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Control chat behavior, media downloads, data usage, and floating messages.',
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
              'Messaging preferences are organized here so the floating message option stays with chat settings. '
              'If backend support is added later, we can connect these toggles to saved preferences.',
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
}
