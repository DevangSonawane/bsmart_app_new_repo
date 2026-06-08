import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/design_tokens.dart';

class ContentSettingsScreen extends StatefulWidget {
  const ContentSettingsScreen({super.key});

  @override
  State<ContentSettingsScreen> createState() => _ContentSettingsScreenState();
}

class _ContentSettingsScreenState extends State<ContentSettingsScreen> {
  static const String _defaultLanguagePrefsKey = 'content_default_language';
  static const String _optionalLanguagesPrefsKey =
      'content_optional_languages';

  final Set<String> _selectedInterests = <String>{'Tech', 'Travel'};
  final Set<String> _followTopics = <String>{'Creativity', 'Business'};

  bool _sensitiveContentFilter = true;
  bool _adultContentFilter = true;
  bool _politicalContentFilter = false;

  bool _autoPlayVideos = true;
  bool _autoPlayPulse = false;

  String _defaultLanguage = 'English';
  final List<String> _optionalLanguages = <String>['Hindi', 'Tamil'];
  bool _autoTranslation = false;

  static const List<String> _availableLanguages = <String>[
    'English',
    'Hindi',
    'Tamil',
    'Telugu',
    'Kannada',
    'Punjabi',
    'Bengali',
    'Gujarati',
    'Marathi',
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreferences());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final appLanguage = _languageLabelForLocale(context.locale);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('content_preferences_title'.tr()),
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
            _sectionTitle('content_preferences_feed_preferences'.tr()),
            _settingsCard(
              children: [
                _actionRow(
                  icon: LucideIcons.sparkles,
                  title: 'content_preferences_select_interests'.tr(),
                  subtitle: _selectedInterests.isEmpty
                      ? 'content_preferences_select_interests_subtitle'.tr()
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
                    title: 'content_preferences_select_interests'.tr(),
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
                  title: 'content_preferences_follow_topics'.tr(),
                  subtitle: _followTopics.isEmpty
                      ? 'content_preferences_follow_topics_subtitle'.tr()
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
                    title: 'content_preferences_follow_topics'.tr(),
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
            _sectionTitle('content_preferences_content_controls'.tr()),
            _settingsCard(
              children: [
                _toggleRow(
                  icon: LucideIcons.shieldAlert,
                  title: 'content_preferences_sensitive_content_filter'.tr(),
                  subtitle:
                      'content_preferences_sensitive_content_filter_subtitle'
                          .tr(),
                  value: _sensitiveContentFilter,
                  onChanged: (value) =>
                      setState(() => _sensitiveContentFilter = value),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.badgeAlert,
                  title: 'content_preferences_adult_content_filter'.tr(),
                  subtitle:
                      'content_preferences_adult_content_filter_subtitle'.tr(),
                  value: _adultContentFilter,
                  onChanged: (value) =>
                      setState(() => _adultContentFilter = value),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.gavel,
                  title: 'content_preferences_political_content_filter'.tr(),
                  subtitle:
                      'content_preferences_political_content_filter_subtitle'
                          .tr(),
                  value: _politicalContentFilter,
                  onChanged: (value) =>
                      setState(() => _politicalContentFilter = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('content_preferences_video_preferences'.tr()),
            _settingsCard(
              children: [
                _toggleRow(
                  icon: LucideIcons.play,
                  title: 'content_preferences_auto_play_videos'.tr(),
                  subtitle:
                      'content_preferences_auto_play_videos_subtitle'.tr(),
                  value: _autoPlayVideos,
                  onChanged: (value) => setState(() => _autoPlayVideos = value),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.circleDot,
                  title: 'content_preferences_auto_play_pulse'.tr(),
                  subtitle:
                      'content_preferences_auto_play_pulse_subtitle'.tr(),
                  value: _autoPlayPulse,
                  onChanged: (value) => setState(() => _autoPlayPulse = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('content_preferences_language_preferences'.tr()),
            _settingsCard(
              children: [
                _actionRow(
                  icon: LucideIcons.languages,
                  title: 'content_preferences_app_language'.tr(),
                  subtitle: 'content_preferences_app_language_subtitle'.tr(),
                  trailing: Text(
                    appLanguage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  onTap: () => _pickFromList(
                    title: 'content_preferences_select_language'.tr(),
                    options: const [
                      'English',
                      'Hindi',
                      'Tamil',
                      'Telugu',
                      'Kannada',
                      'Punjabi',
                      'Bengali',
                      'Gujarati',
                      'Marathi',
                    ],
                    current: appLanguage,
                    onSelected: (value) => unawaited(_setAppLanguage(value)),
                  ),
                ),
                const Divider(height: 1),
                _actionRow(
                  icon: LucideIcons.bookOpen,
                  title: 'content_preferences_default_language'.tr(),
                  subtitle:
                      '$_defaultLanguage • ${"content_preferences_default_language_subtitle".tr()}',
                  trailing: Text(
                    _defaultLanguage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  onTap: () => _pickFromList(
                    title: 'content_preferences_default_language'.tr(),
                    options: _availableLanguages,
                    current: _defaultLanguage,
                    onSelected: (value) => unawaited(_setDefaultLanguage(value)),
                  ),
                ),
                const Divider(height: 1),
                _actionRow(
                  icon: LucideIcons.listChecks,
                  title: 'content_preferences_optional_languages'.tr(),
                  subtitle:
                      '${_optionalLanguages.length} ${"content_preferences_optional_languages_saved".tr()} • ${_optionalLanguages.join(", ")}',
                  trailing: Text(
                    'content_preferences_edit'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  onTap: () => _editSelection(
                    title: 'content_preferences_optional_languages'.tr(),
                    options: _availableLanguages
                        .where((language) => language != _defaultLanguage)
                        .toList(),
                    initial: _optionalLanguages.toSet(),
                    onSaved: (next) => _setOptionalLanguages(next),
                  ),
                ),
                const Divider(height: 1),
                _toggleRow(
                  icon: LucideIcons.languages,
                  title: 'content_preferences_auto_translation'.tr(),
                  subtitle:
                      'content_preferences_auto_translation_subtitle'.tr(),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'content_preferences_header_title'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'content_preferences_header_subtitle'.tr(),
                  style: const TextStyle(
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
              _languagePreferenceSummary(),
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

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDefaultLanguage =
        prefs.getString(_defaultLanguagePrefsKey) ?? _defaultLanguage;
    final storedOptionalLanguages =
        prefs.getStringList(_optionalLanguagesPrefsKey) ?? const <String>[];
    final normalizedOptionalLanguages =
        _normalizeLanguages(storedOptionalLanguages.toSet(), exclude: storedDefaultLanguage);

    if (!mounted) return;
    setState(() {
      _defaultLanguage = storedDefaultLanguage;
      _optionalLanguages
        ..clear()
        ..addAll(normalizedOptionalLanguages);
    });
    await _saveOptionalLanguages(_optionalLanguages.toSet());
  }

  Future<void> _setAppLanguage(String language) async {
    final locale = _localeForLanguage(language);
    await context.setLocale(locale);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setDefaultLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultLanguagePrefsKey, language);
    if (!mounted) return;
    final updatedOptionalLanguages =
        _normalizeLanguages(_optionalLanguages.toSet(), exclude: language);
    final locale = _localeForLanguage(language);
    await context.setLocale(locale);
    setState(() {
      _defaultLanguage = language;
      _optionalLanguages
        ..clear()
        ..addAll(updatedOptionalLanguages);
    });
    await _saveOptionalLanguages(_optionalLanguages.toSet());
  }

  Future<void> _setOptionalLanguages(Set<String> languages) async {
    final normalized = _normalizeLanguages(languages, exclude: _defaultLanguage);
    if (!mounted) return;
    setState(() {
      _optionalLanguages
        ..clear()
        ..addAll(normalized);
    });
    await _saveOptionalLanguages(_optionalLanguages.toSet());
  }

  Future<void> _saveOptionalLanguages(Set<String> languages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_optionalLanguagesPrefsKey, languages.toList());
  }

  List<String> _normalizeLanguages(
    Set<String> languages, {
    required String exclude,
  }) {
    final normalized = <String>[];
    for (final language in languages) {
      if (language == exclude) continue;
      if (normalized.contains(language)) continue;
      normalized.add(language);
    }
    return normalized;
  }

  Locale _localeForLanguage(String language) {
    switch (language) {
      case 'Hindi':
        return const Locale('hi');
      case 'Tamil':
        return const Locale('ta');
      case 'Telugu':
        return const Locale('te');
      case 'Kannada':
        return const Locale('kn');
      case 'Punjabi':
        return const Locale('pa');
      case 'Bengali':
        return const Locale('bn');
      case 'Gujarati':
        return const Locale('gu');
      case 'Marathi':
        return const Locale('mr');
      default:
        return const Locale('en');
    }
  }

  String _languageLabelForLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'hi':
        return 'Hindi';
      case 'ta':
        return 'Tamil';
      case 'te':
        return 'Telugu';
      case 'kn':
        return 'Kannada';
      case 'pa':
        return 'Punjabi';
      case 'bn':
        return 'Bengali';
      case 'gu':
        return 'Gujarati';
      case 'mr':
        return 'Marathi';
      default:
        return 'English';
    }
  }

  String _languagePreferenceSummary() {
    final optionalSummary =
        _optionalLanguages.isEmpty ? 'none' : _optionalLanguages.join(', ');
    return 'Default language: $_defaultLanguage. Optional languages: $optionalSummary. Auto translation will prefer the default language.';
  }
}
