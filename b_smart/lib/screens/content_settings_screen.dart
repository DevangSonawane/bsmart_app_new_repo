import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/design_tokens.dart';

class ContentSettingsScreen extends StatefulWidget {
  const ContentSettingsScreen({super.key});

  @override
  State<ContentSettingsScreen> createState() => _ContentSettingsScreenState();
}

class _ContentSettingsScreenState extends State<ContentSettingsScreen> {
  final Set<String> _selectedInterests = <String>{'Tech', 'Travel'};
  final Set<String> _followTopics = <String>{'Creativity', 'Business'};

  bool _sensitiveContentFilter = true;
  bool _adultContentFilter = true;
  bool _politicalContentFilter = false;

  bool _autoPlayVideos = true;
  bool _autoPlayPulse = false;

  String _appLanguage = 'English';
  String _defaultLanguage = 'English';
  final List<String> _optionalLanguages = <String>['Hindi', 'Spanish'];
  bool _autoTranslation = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;

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
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            _headerCard(isDark),
            const SizedBox(height: 20),
            _sectionTitle('Feed Preferences'),
            _settingsCard(
              children: [
                _actionRow(
                  icon: LucideIcons.sparkles,
                  title: 'Select Interests',
                  subtitle:
                      _selectedInterests.isEmpty
                          ? 'Choose topics you want more of'
                          : _selectedInterests.join(' • '),
                  trailing: Text(
                    '${_selectedInterests.length} selected',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  onTap: () => _editSelection(
                    title: 'Select Interests',
                    options: const [
                      'Tech',
                      'Travel',
                      'Food',
                      'Fashion',
                      'Sports',
                      'Music',
                      'Business',
                      'Fitness',
                      'Art',
                      'Gaming',
                    ],
                    initial: _selectedInterests,
                    onSaved: (next) => setState(() {
                      _selectedInterests
                        ..clear()
                        ..addAll(next);
                    }),
                  ),
                ),
                const Divider(height: 1),
                _actionRow(
                  icon: LucideIcons.hash,
                  title: 'Follow Topics',
                  subtitle: _followTopics.isEmpty
                      ? 'Choose topics and creators to follow'
                      : _followTopics.join(' • '),
                  trailing: Text(
                    '${_followTopics.length} followed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  onTap: () => _editSelection(
                    title: 'Follow Topics',
                    options: const [
                      'Creativity',
                      'Business',
                      'Lifestyle',
                      'Design',
                      'Marketing',
                      'News',
                      'Learning',
                      'Photography',
                      'Comedy',
                      'Cooking',
                    ],
                    initial: _followTopics,
                    onSaved: (next) => setState(() {
                      _followTopics
                        ..clear()
                        ..addAll(next);
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Content Controls'),
            _settingsCard(
              children: [
                _toggleRow(
                  icon: LucideIcons.shieldAlert,
                  title: 'Sensitive Content Filter',
                  subtitle: 'Reduce posts flagged as sensitive.',
                  value: _sensitiveContentFilter,
                  onChanged: (value) =>
                      setState(() => _sensitiveContentFilter = value),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.badgeAlert,
                  title: 'Adult Content Filter',
                  subtitle: 'Block 18+ content from your feed.',
                  value: _adultContentFilter,
                  onChanged: (value) =>
                      setState(() => _adultContentFilter = value),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.gavel,
                  title: 'Political Content Filter',
                  subtitle: 'Limit political content in recommendations.',
                  value: _politicalContentFilter,
                  onChanged: (value) =>
                      setState(() => _politicalContentFilter = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Video Preferences'),
            _settingsCard(
              children: [
                _toggleRow(
                  icon: LucideIcons.play,
                  title: 'Auto Play Videos',
                  subtitle: 'Play videos automatically while scrolling.',
                  value: _autoPlayVideos,
                  onChanged: (value) => setState(() => _autoPlayVideos = value),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.circleDot,
                  title: 'Auto Play Pulse',
                  subtitle: 'Auto-play short pulse previews in the feed.',
                  value: _autoPlayPulse,
                  onChanged: (value) => setState(() => _autoPlayPulse = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Language Preferences'),
            _settingsCard(
              children: [
                _actionRow(
                  icon: LucideIcons.languages,
                  title: 'App Language',
                  subtitle: 'Select the language used throughout the app',
                  trailing: Text(
                    _appLanguage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  onTap: () => _pickFromList(
                    title: 'Select Language',
                    options: const [
                      'English',
                      'Hindi',
                      'Spanish',
                      'French',
                      'Portuguese',
                      'German',
                    ],
                    current: _appLanguage,
                    onSelected: (value) => setState(() => _appLanguage = value),
                  ),
                ),
                const Divider(height: 1),
                _actionRow(
                  icon: LucideIcons.bookOpen,
                  title: 'Default Language',
                  subtitle: 'Primary language for content and labels',
                  trailing: Text(
                    _defaultLanguage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  onTap: () => _pickFromList(
                    title: 'Default Language',
                    options: const [
                      'English',
                      'Hindi',
                      'Spanish',
                      'French',
                      'Portuguese',
                      'German',
                    ],
                    current: _defaultLanguage,
                    onSelected: (value) =>
                        setState(() => _defaultLanguage = value),
                  ),
                ),
                const Divider(height: 1),
                _actionRow(
                  icon: LucideIcons.listChecks,
                  title: 'Optional Languages',
                  subtitle:
                      '${_optionalLanguages.length} saved extra languages',
                  trailing: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  onTap: () => _editSelection(
                    title: 'Optional Languages',
                    options: const [
                      'English',
                      'Hindi',
                      'Spanish',
                      'French',
                      'Portuguese',
                      'German',
                      'Arabic',
                      'Bengali',
                    ],
                    initial: _optionalLanguages.toSet(),
                    onSaved: (next) => setState(() {
                      _optionalLanguages
                        ..clear()
                        ..addAll(next);
                    }),
                  ),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.languages,
                  title: 'Auto Translation',
                  subtitle:
                      'Translate content into your selected language automatically.',
                  value: _autoTranslation,
                  onChanged: (value) => setState(() => _autoTranslation = value),
                ),
              ],
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
              LucideIcons.slidersHorizontal,
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
                  'Tune your feed, content filters, video playback, and languages in one place.',
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
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing,
              ],
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: hintColor, size: 20),
            ],
          ),
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
              'This page now follows the same card and spacing style as Messaging. The filters here are kept local for now, but the UI is ready for backend wiring later.',
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

  Future<void> _pickFromList({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              for (final option in options)
                ListTile(
                  title: Text(option),
                  trailing: option == current
                      ? const Icon(Icons.check_circle,
                          color: DesignTokens.instaPink)
                      : null,
                  onTap: () => Navigator.pop(ctx, option),
                ),
            ],
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    onSelected(selected);
  }

  Future<void> _editSelection({
    required String title,
    required List<String> options,
    required Set<String> initial,
    required ValueChanged<Set<String>> onSaved,
  }) async {
    final next = Set<String>.from(initial);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final option in options)
                          FilterChip(
                            label: Text(option),
                            selected: next.contains(option),
                            onSelected: (selected) {
                              setLocal(() {
                                if (selected) {
                                  next.add(option);
                                } else {
                                  next.remove(option);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: DesignTokens.instaPink,
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || saved != true) return;
    onSaved(next);
  }
}
