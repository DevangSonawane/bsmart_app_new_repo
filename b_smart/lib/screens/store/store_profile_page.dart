import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/store_profile.dart';
import '../../utils/current_user.dart';
import 'store_profile_state.dart';
import 'store_theme.dart';

/// Storefront profile viewer/editor.
///
/// Read-only when viewing another seller; editable when [ownerUserId] is the
/// signed-in user. Saved with `PATCH /api/users/me/store-profile`.
class StoreProfilePage extends StatefulWidget {
  final String? ownerUserId;

  const StoreProfilePage({super.key, this.ownerUserId});

  @override
  State<StoreProfilePage> createState() => _StoreProfilePageState();
}

class _StoreProfilePageState extends State<StoreProfilePage> {
  String? _selfId;
  bool _isSelf = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveSelf());
    unawaited(StoreProfileState.instance.ensureLoaded(widget.ownerUserId));
  }

  Future<void> _resolveSelf() async {
    final id = await CurrentUser.id;
    if (!mounted) return;
    StoreProfileState.instance.setSelfId(id);
    setState(() {
      _selfId = id;
      _isSelf = id != null && id == widget.ownerUserId?.trim();
    });
  }

  void _openEditor(StoreProfile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreProfileEditPage(initial: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = widget.ownerUserId;
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: StoreProfileState.instance,
            builder: (context, _) {
              final state = StoreProfileState.instance;
              final profile = state.profileFor(ownerId);
              final isSelf =
                  state.isSelf(ownerId) || (_isSelf && _selfId != null);
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        8,
                        MediaQuery.of(context).padding.top + 6,
                        12,
                        0,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(LucideIcons.arrowLeft, size: 24),
                            color: BStoreColors.textPrimary,
                          ),
                          const Expanded(
                            child: Text(
                              'Store profile',
                              style: BStoreTypography.screenTitle,
                            ),
                          ),
                          if (isSelf && profile != null)
                            TextButton(
                              onPressed: () => _openEditor(profile),
                              child: const Text('Edit'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (state.isLoading(ownerId))
                    const SliverToBoxAdapter(child: _ProfileSkeleton())
                  else if (state.hasError(ownerId))
                    SliverToBoxAdapter(
                      child: _ProfileNotice(
                        title: "Couldn't load store profile",
                        body: state.errorMessage(ownerId) ??
                            'Please try again.',
                        actionLabel: 'Retry',
                        onAction: () => state.load(ownerId!, force: true),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: _ProfileBody(
                        profile: profile,
                        isSelf: isSelf,
                        onEdit: profile == null
                            ? null
                            : () => _openEditor(profile),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final StoreProfile? profile;
  final bool isSelf;
  final VoidCallback? onEdit;

  const _ProfileBody({
    required this.profile,
    required this.isSelf,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    if (profile == null || profile.isEmpty) {
      return _ProfileNotice(
        title: isSelf ? 'Set up your store' : 'No store details yet',
        body: isSelf
            ? 'Add a store type, the areas you serve and your languages so '
                'customers know what you offer.'
            : 'This seller has not added a store profile yet.',
        actionLabel: isSelf ? 'Add details' : null,
        onAction: isSelf
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const StoreProfileEditPage(),
                  ),
                )
            : null,
      );
    }

    final badges = profile.trustBadges;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BStoreDecorations.card(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.storeName.isEmpty ? 'Store' : profile.storeName,
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (profile.storeType.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.storeType,
                    style: const TextStyle(
                      color: BStoreColors.accentPurple,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                if (profile.about.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(profile.about, style: BStoreTypography.body),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Products',
                  value: '${profile.productCount}',
                  icon: LucideIcons.package,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Services',
                  value: '${profile.serviceCount}',
                  icon: LucideIcons.briefcaseBusiness,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: 'Followers',
                  value: '${profile.followersCount}',
                  icon: LucideIcons.users,
                ),
              ),
            ],
          ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Trust badges',
              style: BStoreTypography.sectionTitle,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final badge in badges) _TrustBadge(label: badge),
              ],
            ),
          ],
          if (profile.serviceAreas.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Service areas', style: BStoreTypography.sectionTitle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final area in profile.serviceAreas)
                  _TagChip(icon: LucideIcons.mapPin, label: area),
              ],
            ),
          ],
          if (profile.languages.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Languages', style: BStoreTypography.sectionTitle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final language in profile.languages)
                  _TagChip(icon: LucideIcons.languages, label: language),
              ],
            ),
          ],
          if (profile.memberSince.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(
                  LucideIcons.calendarDays,
                  color: BStoreColors.textMuted,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Member since ${profile.memberSince}',
                    style: const TextStyle(
                      color: BStoreColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isSelf && onEdit != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.pencil, size: 16),
                label: const Text('Edit store profile'),
                style: BStoreButtons.outlined(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      decoration: BStoreDecorations.card(radius: 12),
      child: Column(
        children: [
          Icon(icon, color: BStoreColors.primary, size: 18),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BStoreColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final String label;

  const _TrustBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BStoreColors.accentPurpleSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.badgeCheck,
            color: BStoreColors.accentPurple,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: BStoreColors.accentPurple,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TagChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: BStoreColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: BStoreColors.primary, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: BStoreColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BStoreDecorations.card(radius: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Expanded(
                  child: Container(
                    height: 76,
                    decoration: BStoreDecorations.card(radius: 12),
                  ),
                ),
                if (i != 2) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileNotice extends StatelessWidget {
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ProfileNotice({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
        decoration: BStoreDecorations.card(radius: 16),
        child: Column(
          children: [
            const Icon(
              LucideIcons.store,
              color: BStoreColors.primary,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BStoreColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: BStoreColors.textMuted,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(LucideIcons.pencil, size: 16),
                label: Text(actionLabel!),
                style: BStoreButtons.filled(radius: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Editor for the signed-in seller's storefront profile.
class StoreProfileEditPage extends StatefulWidget {
  final StoreProfile? initial;

  const StoreProfileEditPage({super.key, this.initial});

  @override
  State<StoreProfileEditPage> createState() => _StoreProfileEditPageState();
}

class _StoreProfileEditPageState extends State<StoreProfileEditPage> {
  late final TextEditingController _storeType;
  late List<String> _serviceAreas;
  late List<String> _languages;
  late List<String> _trustBadges;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _storeType = TextEditingController(text: initial?.storeType ?? '');
    _serviceAreas = [...?initial?.serviceAreas];
    _languages = [...?initial?.languages];
    _trustBadges = [...?initial?.trustBadges];
  }

  @override
  void dispose() {
    _storeType.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await StoreProfileState.instance.updateSelf(
        storeType: _storeType.text.trim(),
        serviceAreas: _serviceAreas,
        languages: _languages,
        trustBadges: _trustBadges,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store profile updated.')),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            StoreProfileState.instance.errorMessage(await CurrentUser.id) ??
                'Could not update the store profile.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 6,
              16,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(LucideIcons.arrowLeft, size: 24),
                    color: BStoreColors.textPrimary,
                  ),
                  const Expanded(
                    child: Text(
                      'Edit store profile',
                      style: BStoreTypography.screenTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LabeledField(
                controller: _storeType,
                label: 'Store type',
                hint: 'e.g. Personal Store',
              ),
              const SizedBox(height: 18),
              _ListEditor(
                title: 'Service areas',
                hint: 'Add an area, then press enter',
                values: _serviceAreas,
                suggestions: const ['Mumbai', 'Delhi', 'Online', 'Remote'],
                onChanged: (v) => setState(() => _serviceAreas = v),
              ),
              const SizedBox(height: 18),
              _ListEditor(
                title: 'Languages',
                hint: 'Add a language, then press enter',
                values: _languages,
                suggestions: const ['English', 'Hindi', 'Marathi', 'Tamil'],
                onChanged: (v) => setState(() => _languages = v),
              ),
              const SizedBox(height: 18),
              _ListEditor(
                title: 'Trust badges',
                hint: 'Add a badge, then press enter',
                values: _trustBadges,
                suggestions: const [
                  'Professional',
                  'Trusted',
                  'Reliable',
                  'Verified',
                ],
                onChanged: (v) => setState(() => _trustBadges = v),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: BStoreButtons.filled(radius: 10),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save changes',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _LabeledField({
    required this.controller,
    required this.label,
    this.hint = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: BStoreTypography.sectionTitle),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(
            color: BStoreColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: BStoreColors.textMuted),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: BStoreColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: BStoreColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: BStoreColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip-style editor for a list of short strings (areas, languages, badges).
class _ListEditor extends StatefulWidget {
  final String title;
  final String hint;
  final List<String> values;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;

  const _ListEditor({
    required this.title,
    required this.hint,
    required this.values,
    required this.onChanged,
    this.suggestions = const [],
  });

  @override
  State<_ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<_ListEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add([String? raw]) {
    final value = (raw ?? _controller.text).trim();
    if (value.isEmpty) return;
    if (!widget.values.any((v) => v.toLowerCase() == value.toLowerCase())) {
      widget.onChanged([...widget.values, value]);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: BStoreTypography.sectionTitle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                onSubmitted: _add,
                style: const TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(color: BStoreColors.textMuted),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: BStoreColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: BStoreColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: BStoreColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: _add,
                style: BStoreButtons.filled(radius: 10),
                child: const Icon(LucideIcons.plus, size: 18),
              ),
            ),
          ],
        ),
        if (widget.suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final suggestion in widget.suggestions)
                if (!widget.values
                    .any((v) => v.toLowerCase() == suggestion.toLowerCase()))
                  GestureDetector(
                    onTap: () => _add(suggestion),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: BStoreColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: BStoreColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.plus,
                            color: BStoreColors.textMuted,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            suggestion,
                            style: const TextStyle(
                              color: BStoreColors.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ],
        if (widget.values.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final value in widget.values)
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(11, 6, 5, 6),
                  decoration: BoxDecoration(
                    color: BStoreColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          color: BStoreColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 3),
                      GestureDetector(
                        onTap: () => widget.onChanged(
                          widget.values.where((v) => v != value).toList(),
                        ),
                        child: const Icon(
                          LucideIcons.x,
                          color: BStoreColors.primary,
                          size: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
