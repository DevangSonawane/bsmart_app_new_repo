import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/store_profile.dart';
import '../../utils/current_user.dart';
import 'store_profile_state.dart';
import 'store_theme.dart';
import 'store_subscription_card.dart';

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
    final ownerId = _effectiveOwnerId(id);
    if (ownerId != null) {
      unawaited(StoreProfileState.instance.ensureLoaded(ownerId));
    }
    setState(() {
      _selfId = id;
      _isSelf = id != null && id == ownerId;
    });
  }

  String? _effectiveOwnerId([String? selfId]) {
    final ownerId = widget.ownerUserId?.trim();
    if (ownerId != null && ownerId.isNotEmpty) return ownerId;
    return selfId ?? _selfId;
  }

  void _openEditor(StoreProfile? profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreProfileEditPage(initial: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerId = _effectiveOwnerId();
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: StoreProfileState.instance,
            builder: (context, _) {
              final state = StoreProfileState.instance;
              final profile = state.profileFor(ownerId);
              final isSelf =
                  state.isSelf(ownerId) || (_isSelf && _selfId != null);
              return Column(
                children: [
                  _StorefrontTopBar(
                    title: 'Storefront',
                    onBack: () => Navigator.of(context).maybePop(),
                    trailing: isSelf
                        ? _TopBarTextAction(
                            label: 'Edit',
                            onPressed: () => _openEditor(profile),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: BStoreColors.background,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          if (state.isLoading(ownerId))
                            const SliverToBoxAdapter(child: _ProfileSkeleton())
                          else if (state.hasError(ownerId))
                            SliverToBoxAdapter(
                              child: _ProfileNotice(
                                title: "Couldn't load store profile",
                                body: state.errorMessage(ownerId) ??
                                    'Please try again.',
                                actionLabel: 'Retry',
                                onAction: () =>
                                    state.load(ownerId!, force: true),
                              ),
                            )
                          else
                            SliverToBoxAdapter(
                              child: _ProfileBody(
                                profile: profile,
                                isSelf: isSelf,
                              ),
                            ),
                          if (isSelf)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                                child: StoreSubscriptionCard(),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height:
                                  MediaQuery.viewPaddingOf(context).bottom + 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// White title bar that sits above the rounded storefront panel.
class _StorefrontTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  const _StorefrontTopBar({
    required this.title,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              LucideIcons.chevronLeft,
              size: 26,
              color: BStoreColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BStoreColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _TopBarTextAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TopBarTextAction({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: BStoreColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: Text(label),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final StoreProfile? profile;
  final bool isSelf;

  const _ProfileBody({
    required this.profile,
    required this.isSelf,
  });

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    if (profile == null || profile.isEmpty) {
      return _ProfileNotice(
        title: isSelf ? 'Set up your store' : 'No store details yet',
        body: isSelf
            ? 'Tap Edit in the top right to add a store type, the areas you '
                'serve and your languages so customers know what you offer.'
            : 'This seller has not added a store profile yet.',
      );
    }

    final hasDetails = profile.storeType.isNotEmpty ||
        profile.serviceAreas.isNotEmpty ||
        profile.languages.isNotEmpty ||
        profile.trustBadges.isNotEmpty ||
        profile.memberSince.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StorefrontHeader(profile: profile),
          const SizedBox(height: 24),
          _StoreStatsGrid(profile: profile),
          if (hasDetails) ...[
            const SizedBox(height: 24),
            _StoreDetailsCard(profile: profile),
          ],
        ],
      ),
    );
  }
}

/// Centered avatar + name + tagline, mirroring the Trumarkz account header.
class _StorefrontHeader extends StatelessWidget {
  final StoreProfile profile;

  const _StorefrontHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final hasBadges = profile.trustBadges.isNotEmpty;
    final name =
        profile.storeName.trim().isEmpty ? 'Store' : profile.storeName.trim();

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: BStoreColors.primarySoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                LucideIcons.store,
                size: 34,
                color: BStoreColors.primary,
              ),
            ),
            if (hasBadges)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    LucideIcons.badgeCheck,
                    size: 15,
                    color: BStoreColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: BStoreColors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            height: 1.25,
          ),
        ),
        if (profile.storeType.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: BStoreColors.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              profile.storeType.toUpperCase(),
              style: const TextStyle(
                color: BStoreColors.primary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
        if (profile.about.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              profile.about,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BStoreColors.textSecondary,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (hasBadges) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: BStoreColors.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.badgeCheck,
                  size: 14,
                  color: BStoreColors.primary,
                ),
                SizedBox(width: 5),
                Text(
                  'Trusted store',
                  style: TextStyle(
                    color: BStoreColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Two-by-two action grid (products, services, followers, following).
class _StoreStatsGrid extends StatelessWidget {
  final StoreProfile profile;

  const _StoreStatsGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _StoreStatCard(
        icon: LucideIcons.package,
        value: '${profile.productCount}',
        label: 'Products',
      ),
      _StoreStatCard(
        icon: LucideIcons.briefcaseBusiness,
        value: '${profile.serviceCount}',
        label: 'Services',
      ),
      _StoreStatCard(
        icon: LucideIcons.users,
        value: '${profile.followersCount}',
        label: 'Followers',
      ),
      _StoreStatCard(
        icon: LucideIcons.userPlus,
        value: '${profile.followingCount}',
        label: 'Following',
      ),
    ];

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }
}

class _StoreStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StoreStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: BStoreColors.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: BStoreColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: BStoreColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Store details" card: one row per profile attribute.
class _StoreDetailsCard extends StatelessWidget {
  final StoreProfile profile;

  const _StoreDetailsCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    void add(Widget row) {
      if (rows.isNotEmpty) {
        rows.add(
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
        );
      }
      rows.add(row);
    }

    if (profile.storeType.isNotEmpty) {
      add(
        _StoreDetailRow(
          icon: LucideIcons.store,
          label: 'Store type',
          value: profile.storeType,
        ),
      );
    }
    if (profile.serviceAreas.isNotEmpty) {
      add(
        _StoreDetailRow(
          icon: LucideIcons.mapPin,
          label: 'Service areas',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final area in profile.serviceAreas)
                _ProfileChip(icon: LucideIcons.mapPin, label: area),
            ],
          ),
        ),
      );
    }
    if (profile.languages.isNotEmpty) {
      add(
        _StoreDetailRow(
          icon: LucideIcons.languages,
          label: 'Languages',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final language in profile.languages)
                _ProfileChip(icon: LucideIcons.languages, label: language),
            ],
          ),
        ),
      );
    }
    if (profile.trustBadges.isNotEmpty) {
      add(
        _StoreDetailRow(
          icon: LucideIcons.shieldCheck,
          label: 'Trust badges',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final badge in profile.trustBadges)
                _ProfileChip(icon: LucideIcons.badgeCheck, label: badge),
            ],
          ),
        ),
      );
    }
    if (profile.memberSince.isNotEmpty) {
      add(
        _StoreDetailRow(
          icon: LucideIcons.calendarDays,
          label: 'Member since',
          value: profile.memberSince,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 12),
          child: Text(
            'Store details',
            style: TextStyle(
              color: BStoreColors.textMuted,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _StoreDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? child;

  const _StoreDetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: BStoreColors.primarySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: BStoreColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: BStoreColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                child ??
                    Text(
                      value ?? '',
                      style: const TextStyle(
                        color: BStoreColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ProfileChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: BStoreColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: BStoreColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: BStoreColors.primary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
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
    Widget bar({required double width, required double height}) {
      return Container(
        width: width,
        height: height,
        decoration: BStoreDecorations.card(radius: 6),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 0),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: BStoreColors.primarySoft,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 16),
          bar(width: 150, height: 18),
          const SizedBox(height: 10),
          bar(width: 90, height: 12),
          const SizedBox(height: 26),
          for (var row = 0; row < 2; row++) ...[
            Row(
              children: [
                for (var i = 0; i < 2; i++) ...[
                  Expanded(
                    child: Container(
                      height: 118,
                      decoration: BStoreDecorations.card(radius: 20),
                    ),
                  ),
                  if (i == 0) const SizedBox(width: 12),
                ],
              ],
            ),
            if (row == 0) const SizedBox(height: 12),
          ],
          const SizedBox(height: 24),
          Container(
            height: 170,
            decoration: BStoreDecorations.card(radius: 16),
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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
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
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _StorefrontTopBar(
                title: 'Edit storefront',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: BStoreColors.background,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      20,
                      16,
                      MediaQuery.viewPaddingOf(context).bottom + 24,
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Update what customers see on your storefront. '
                              'Only the fields you change are saved.',
                              style: TextStyle(
                                color: BStoreColors.textMuted,
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _LabeledField(
                              controller: _storeType,
                              label: 'Store type',
                              hint: 'e.g. Personal Store',
                              icon: LucideIcons.store,
                              enabled: !_saving,
                            ),
                            const SizedBox(height: 22),
                            _ListEditor(
                              title: 'Service areas',
                              hint: 'Add an area, then press enter',
                              icon: LucideIcons.mapPin,
                              values: _serviceAreas,
                              suggestions: const [
                                'Mumbai',
                                'Delhi',
                                'Online',
                                'Remote',
                              ],
                              enabled: !_saving,
                              onChanged: (v) =>
                                  setState(() => _serviceAreas = v),
                            ),
                            const SizedBox(height: 22),
                            _ListEditor(
                              title: 'Languages',
                              hint: 'Add a language, then press enter',
                              icon: LucideIcons.languages,
                              values: _languages,
                              suggestions: const [
                                'English',
                                'Hindi',
                                'Marathi',
                                'Tamil',
                              ],
                              enabled: !_saving,
                              onChanged: (v) => setState(() => _languages = v),
                            ),
                            const SizedBox(height: 22),
                            _ListEditor(
                              title: 'Trust badges',
                              hint: 'Add a badge, then press enter',
                              icon: LucideIcons.shieldCheck,
                              values: _trustBadges,
                              suggestions: const [
                                'Professional',
                                'Trusted',
                                'Reliable',
                                'Verified',
                              ],
                              enabled: !_saving,
                              onChanged: (v) =>
                                  setState(() => _trustBadges = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: BStoreButtons.filled(radius: 14),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.check, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Save changes',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
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

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FieldLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: BStoreColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: BStoreColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool enabled;

  const _LabeledField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint = '',
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(icon: icon, label: label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          style: const TextStyle(
            color: BStoreColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration(hint),
        ),
      ],
    );
  }
}

InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: BStoreColors.textMuted,
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFEDF1F5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: BStoreColors.primary, width: 1.5),
    ),
  );
}

/// Chip-style editor for a list of short strings (areas, languages, badges).
class _ListEditor extends StatefulWidget {
  final String title;
  final String hint;
  final IconData icon;
  final List<String> values;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  const _ListEditor({
    required this.title,
    required this.hint,
    required this.icon,
    required this.values,
    required this.onChanged,
    this.suggestions = const [],
    this.enabled = true,
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
    if (!widget.enabled) return;
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
        _FieldLabel(icon: widget.icon, label: widget.title),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          textInputAction: TextInputAction.done,
          onSubmitted: _add,
          style: const TextStyle(
            color: BStoreColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: _fieldDecoration(widget.hint),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: widget.enabled ? _add : null,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Add'),
            style: OutlinedButton.styleFrom(
              foregroundColor: BStoreColors.primary,
              side: const BorderSide(color: BStoreColors.primary),
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (widget.suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final suggestion in widget.suggestions)
                if (!widget.values
                    .any((v) => v.toLowerCase() == suggestion.toLowerCase()))
                  GestureDetector(
                    onTap: widget.enabled ? () => _add(suggestion) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  padding: const EdgeInsets.fromLTRB(11, 6, 5, 6),
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
                        onTap: widget.enabled
                            ? () => widget.onChanged(
                                  widget.values
                                      .where((v) => v != value)
                                      .toList(),
                                )
                            : null,
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
