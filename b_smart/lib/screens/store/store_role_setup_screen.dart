import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../models/auth/auth_user_model.dart';
import '../../services/auth/auth_service.dart';
import 'shared/store_shared_widgets.dart';
import 'store_theme.dart';

class StoreRoleGate {
  const StoreRoleGate._();

  static Future<bool> ensureInfluencer(BuildContext context) async {
    final user = await AuthService().fetchCurrentUser();
    if (!context.mounted) return false;
    if ((user?.role ?? '').toLowerCase() == 'influencer') return true;

    final upgraded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StoreRoleSetupScreen(user: user),
      ),
    );
    return upgraded == true;
  }
}

/// Sliver gate for influencer-only seller screens (my products/services,
/// seller orders/bookings, dashboard — per Phase 2 md, these endpoints
/// require the influencer role / ownership and 403 otherwise).
///
/// Shows the child for influencers, otherwise a prompt that opens the
/// creator setup instead of surfacing raw 403 errors.
class StoreRoleGateSliver extends StatefulWidget {
  final Widget child;

  const StoreRoleGateSliver({super.key, required this.child});

  @override
  State<StoreRoleGateSliver> createState() => _StoreRoleGateSliverState();
}

class _StoreRoleGateSliverState extends State<StoreRoleGateSliver> {
  late Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _loadRole();
  }

  static Future<String> _loadRole() async {
    try {
      final user = await AuthService().fetchCurrentUser();
      return (user?.role ?? '').trim().toLowerCase();
    } catch (_) {
      return '';
    }
  }

  Future<void> _openSetup() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const StoreRoleSetupScreen(),
      ),
    );
    if (!mounted) return;
    setState(() => _roleFuture = _loadRole());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 40, 18, 0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snapshot.data == 'influencer') return widget.child;
        final role = (snapshot.data ?? '').isEmpty
            ? 'member'
            : snapshot.data!;
        final label = role[0].toUpperCase() + role.substring(1);
        return SliverList.list(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                MediaQuery.of(context).padding.top + 24,
                18,
                0,
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: storeSoftCardDecoration(radius: 16),
                child: Column(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2EDF9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.store,
                        color: Color(0xFF684AC8),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Creator access needed',
                      style: TextStyle(
                        color: BStoreColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You are browsing as $label. Switch to an Influencer store to manage products, services, orders and bookings.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BStoreColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _openSetup,
                        style: BStoreButtons.filled(radius: 9),
                        icon: const Icon(LucideIcons.store, size: 18),
                        label: const Text('Enable creator mode'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class StoreRoleSetupScreen extends StatefulWidget {
  final AuthUser? user;

  const StoreRoleSetupScreen({super.key, this.user});

  @override
  State<StoreRoleSetupScreen> createState() => _StoreRoleSetupScreenState();
}

class _StoreRoleSetupScreenState extends State<StoreRoleSetupScreen> {
  final _businessTypeController = TextEditingController(text: 'Fashion');
  final _storeNameController = TextEditingController();
  final _storeDescriptionController = TextEditingController();
  final _productController = TextEditingController();
  final _serviceController = TextEditingController();
  final _products = <String>['clothing'];
  final _services = <String>['styling consultation'];

  bool _creatorMode = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final name = widget.user?.fullName ?? widget.user?.username;
    _storeNameController.text = name == null || name.trim().isEmpty
        ? 'My B-Smart Store'
        : "$name's Store";
    _storeDescriptionController.text =
        'Curated products and services from my B-Smart store.';
  }

  @override
  void dispose() {
    _businessTypeController.dispose();
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _productController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(onBack: () => Navigator.of(context).maybePop(false)),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    _HeroCard(creatorMode: _creatorMode),
                    const SizedBox(height: 14),
                    _CreatorSwitch(
                      value: _creatorMode,
                      onChanged: (value) =>
                          setState(() => _creatorMode = value),
                    ),
                    const SizedBox(height: 14),
                    _FormPanel(
                      children: [
                        _Input(
                          label: 'Business type',
                          hint: 'Fashion, Home Services, Education...',
                          controller: _businessTypeController,
                        ),
                        const SizedBox(height: 12),
                        _Input(
                          label: 'Store name',
                          hint: 'Your store name',
                          controller: _storeNameController,
                        ),
                        const SizedBox(height: 12),
                        _Input(
                          label: 'Store description',
                          hint: 'Tell customers what you offer',
                          controller: _storeDescriptionController,
                          maxLines: 4,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ChipPanel(
                      title: 'Product types',
                      controller: _productController,
                      values: _products,
                      hint: 'Add product type',
                      onAdd: () => _addChip(_productController, _products),
                      onRemove: (value) =>
                          setState(() => _products.remove(value)),
                    ),
                    const SizedBox(height: 14),
                    _ChipPanel(
                      title: 'Service types',
                      controller: _serviceController,
                      values: _services,
                      hint: 'Add service type',
                      onAdd: () => _addChip(_serviceController, _services),
                      onRemove: (value) =>
                          setState(() => _services.remove(value)),
                    ),
                  ],
                ),
              ),
              _Footer(
                saving: _saving,
                creatorMode: _creatorMode,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addChip(TextEditingController controller, List<String> target) {
    final value = controller.text.trim();
    if (value.isEmpty || target.contains(value)) return;
    setState(() {
      target.add(value);
      controller.clear();
    });
  }

  Future<void> _submit() async {
    final user = widget.user ?? await AuthService().fetchCurrentUser();
    if (!mounted) return;
    final userId = user?.id;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again to set up store.')),
      );
      return;
    }

    if (!_creatorMode) {
      setState(() => _saving = true);
      try {
        await Phase2StoreApi().switchUserRole(
          userId: userId,
          body: const {'role': 'member'},
        );
        if (!mounted) return;
        Navigator.of(context).pop(false);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch role: $e')),
        );
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    final businessType = _businessTypeController.text.trim();
    final storeName = _storeNameController.text.trim();
    final description = _storeDescriptionController.text.trim();
    if (businessType.isEmpty ||
        storeName.isEmpty ||
        description.isEmpty ||
        _products.isEmpty ||
        _services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complete all store setup fields.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await Phase2StoreApi().switchUserRole(
        userId: userId,
        body: {
          'role': 'influencer',
          'business_type': businessType,
          'store_name': storeName,
          'store_description': description,
          'products_type': _products,
          'service_type': _services,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creator mode enabled.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Store setup failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        MediaQuery.of(context).padding.top + 10,
        16,
        6,
      ),
      child: SizedBox(
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(LucideIcons.chevronLeft, size: 24),
                color: BStoreColors.textPrimary,
              ),
            ),
            const StoreBsmartWordmark(),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final bool creatorMode;

  const _HeroCard({required this.creatorMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: storeSoftCardDecoration(radius: 16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFE5F5F3),
            child: Icon(LucideIcons.store, color: Color(0xFF078D92), size: 29),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creatorMode ? 'Set up creator mode' : 'Member mode',
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  creatorMode
                      ? 'Enable selling access for products and services.'
                      : 'Switch off selling access and continue as a buyer.',
                  style: const TextStyle(
                    color: BStoreColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _CreatorSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CreatorSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: storeSoftCardDecoration(radius: 12),
      child: Row(
        children: [
          const Icon(LucideIcons.badgeCheck, color: Color(0xFF684AC8)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Creator mode',
              style: TextStyle(
                color: BStoreColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF078D92),
          ),
        ],
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final List<Widget> children;

  const _FormPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: storeSoftCardDecoration(radius: 12),
      child: Column(children: children),
    );
  }
}

class _Input extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  const _Input({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    // Store UI is light-only: pin explicit light colors so fields stay
    // readable even when this screen is opened from a dark-mode context.
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: BStoreColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: BStoreColors.textMuted),
        hintText: hint,
        hintStyle: const TextStyle(color: BStoreColors.textMuted),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD5DEE4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF078D92)),
        ),
      ),
    );
  }
}

class _ChipPanel extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final List<String> values;
  final String hint;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _ChipPanel({
    required this.title,
    required this.controller,
    required this.values,
    required this.hint,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: storeSoftCardDecoration(radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: BStoreColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(
                    color: BStoreColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                        color: BStoreColors.textMuted),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFFD5DEE4)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Color(0xFF078D92)),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: onAdd,
                  style: BStoreButtons.filled(radius: 8),
                  child: const Icon(LucideIcons.plus, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                InputChip(
                  label: Text(
                    value,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD5DEE4)),
                  deleteIconColor: BStoreColors.textSecondary,
                  onDeleted: () => onRemove(value),
                  deleteIcon: const Icon(LucideIcons.x, size: 14),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool saving;
  final bool creatorMode;
  final VoidCallback onSubmit;

  const _Footer({
    required this.saving,
    required this.creatorMode,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BStoreColors.background,
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      child: SizedBox(
        height: 50,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: saving ? null : onSubmit,
          style: BStoreButtons.filled(radius: 10),
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(creatorMode ? LucideIcons.store : LucideIcons.userRound),
          label: Text(
            saving
                ? 'Saving...'
                : creatorMode
                    ? 'Enable Creator Mode'
                    : 'Switch to Member',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}
