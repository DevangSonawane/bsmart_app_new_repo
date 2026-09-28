import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../models/auth/auth_user_model.dart';
import '../../services/auth/auth_service.dart';
import 'store_models.dart';
import 'store_role_setup_screen.dart';
import 'store_theme.dart';

/// Opens the marketplace role switcher.
///
/// Returns true when the role actually changed, so callers can refresh.
/// Uses `PATCH /api/users/:id/role` (Phase 2 md):
/// - member: one tap, `{role: member}`
/// - influencer: opens [StoreRoleSetupScreen] (all 5 fields required)
Future<bool> showStoreRoleSwitchSheet(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BStoreColors.surface,
    builder: (sheetContext) => Theme(
      data: BStoreTheme.data(sheetContext),
      child: const _RoleSwitchSheet(),
    ),
  );
  return changed == true;
}

class _RoleSwitchSheet extends StatefulWidget {
  const _RoleSwitchSheet();

  @override
  State<_RoleSwitchSheet> createState() => _RoleSwitchSheetState();
}

class _RoleSwitchSheetState extends State<_RoleSwitchSheet> {
  late Future<AuthUser?> _userFuture;
  bool _switching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userFuture = AuthService().fetchCurrentUser();
  }

  void _reloadUser() {
    setState(() {
      _error = null;
      _userFuture = AuthService().fetchCurrentUser();
    });
  }

  Future<void> _switchToMember(AuthUser user) async {
    final userId = user.id;
    if (userId.isEmpty) {
      setState(() => _error = 'Please sign in again to switch roles.');
      return;
    }
    setState(() {
      _switching = true;
      _error = null;
    });
    try {
      await Phase2StoreApi().switchUserRole(
        userId: userId,
        body: const {'role': 'member'},
      );
      await StoreMockState.instance.refreshMarketplace();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switched to Member.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyRoleError(e));
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _openInfluencerSetup(AuthUser? user) async {
    final upgraded = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StoreRoleSetupScreen(user: user),
      ),
    );
    if (upgraded == true && mounted) {
      await StoreMockState.instance.refreshMarketplace();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else if (mounted) {
      _reloadUser();
    }
  }

  static String _friendlyRoleError(Object e) {
    final text = e.toString();
    if (text.contains('403')) {
      return "You can't change another user's role (admin only).";
    }
    if (text.contains('404')) return 'User not found. Please sign in again.';
    if (text.contains('400')) return 'Invalid role change: $e';
    return 'Could not switch role: $e';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            18,
      ),
      child: FutureBuilder<AuthUser?>(
        future: _userFuture,
        builder: (context, snapshot) {
          final loading =
              snapshot.connectionState != ConnectionState.done;
          final user = snapshot.data;
          final role =
              (user?.role ?? '').trim().toLowerCase();
          final roleLabel = role.isEmpty
              ? 'Unknown'
              : role[0].toUpperCase() + role.substring(1);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE1E5EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Switch role',
                style: TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                loading
                    ? 'Loading your role...'
                    : 'Marketplace role: $roleLabel',
                style: const TextStyle(
                  color: Color(0xFF29304D),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                _RoleOption(
                  icon: LucideIcons.userRound,
                  title: 'Member',
                  subtitle: 'Shop products and book services',
                  selected: role == 'member',
                  busy: _switching,
                  actionLabel:
                      role == 'member' ? 'Current role' : 'Switch to Member',
                  onAction: role == 'member' || user == null
                      ? null
                      : () => _switchToMember(user),
                ),
                const SizedBox(height: 10),
                _RoleOption(
                  icon: LucideIcons.store,
                  title: 'Influencer',
                  subtitle: 'Sell products and offer services',
                  selected: role == 'influencer',
                  busy: false,
                  actionLabel: role == 'influencer'
                      ? 'Edit store profile'
                      : 'Become an influencer',
                  onAction: () => _openInfluencerSetup(user),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool busy;
  final String actionLabel;
  final VoidCallback? onAction;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.busy,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF7F6) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? const Color(0xFF078D92)
              : const Color(0xFFE1E5EA),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF078D92)
                  : const Color(0xFFF1F4F8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: selected ? Colors.white : const Color(0xFF060D35),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF29304D),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: busy ? null : onAction,
            style: FilledButton.styleFrom(
              backgroundColor: selected
                  ? const Color(0xFF060D35)
                  : const Color(0xFF078D92),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
