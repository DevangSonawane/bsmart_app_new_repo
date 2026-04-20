import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/design_tokens.dart';
import '../widgets/safe_network_image.dart';

class GroupChatInfoScreen extends StatelessWidget {
  final String title;
  final String? groupAvatarUrl;
  final String currentUserId;
  final List<Map<String, dynamic>> participants;
  final VoidCallback onEdit;
  final VoidCallback onShowMembers;

  const GroupChatInfoScreen({
    super.key,
    required this.title,
    required this.groupAvatarUrl,
    required this.currentUserId,
    required this.participants,
    required this.onEdit,
    required this.onShowMembers,
  });

  String _labelForUser(Map<String, dynamic>? u) {
    if (u == null) return 'User';
    return (u['full_name'] ??
            u['fullName'] ??
            u['name'] ??
            u['username'] ??
            'User')
        .toString()
        .trim();
  }

  String _handleForUser(Map<String, dynamic>? u) {
    if (u == null) return '';
    final raw = (u['username'] ?? u['handle'] ?? '').toString().trim();
    if (raw.isEmpty) return '';
    return raw.startsWith('@') ? raw : '@$raw';
  }

  String? _avatarUrlForUser(Map<String, dynamic>? u) {
    if (u == null) return null;
    final raw = (u['avatar_url'] ??
            u['avatarUrl'] ??
            u['profile_pic'] ??
            u['profilePic'])
        ?.toString()
        .trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  List<Map<String, dynamic>> _twoParticipants() {
    final uid = currentUserId.trim();
    final others = participants
        .where((p) => (p['_id'] ?? p['id'])?.toString().trim() != uid)
        .take(2)
        .toList();

    while (others.length < 2 && participants.length > others.length) {
      final extra = participants.firstWhere(
        (p) => !others.contains(p),
        orElse: () => const <String, dynamic>{},
      );
      if (extra.isEmpty) break;
      others.add(extra);
    }
    return others;
  }

  Widget _avatarCircle(
    BuildContext context,
    Map<String, dynamic> user, {
    required double size,
    required double borderWidth,
  }) {
    final borderColor = Theme.of(context).scaffoldBackgroundColor;
    final url = _avatarUrlForUser(user);
    final label = _labelForUser(user);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipOval(
        child: (url != null && url.isNotEmpty)
            ? SafeNetworkImage(
                url: url, width: size, height: size, fit: BoxFit.cover)
            : CircleAvatar(
                radius: size / 2,
                backgroundColor: DesignTokens.instaPink,
                child: Text(
                  label.isNotEmpty ? label.characters.first.toUpperCase() : 'G',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: size * 0.32,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _diagonalAvatars(BuildContext context) {
    final others = _twoParticipants();
    final bg = groupAvatarUrl?.trim();
    if (bg != null && bg.isNotEmpty) {
      return Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).scaffoldBackgroundColor,
            width: 3,
          ),
        ),
        child: ClipOval(
          child: SafeNetworkImage(
            url: bg,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final a = others.isNotEmpty ? others[0] : const <String, dynamic>{};
    final b = others.length >= 2 ? others[1] : a;

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: _avatarCircle(
              context,
              b,
              size: 68,
              borderWidth: 3,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: _avatarCircle(
              context,
              a,
              size: 68,
              borderWidth: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required BuildContext context,
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.onSurface.withValues(alpha: 0.10),
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withValues(alpha: 0.55);

    final handles = participants
        .where((p) =>
            (p['_id'] ?? p['id'])?.toString().trim() != currentUserId.trim())
        .map(_handleForUser)
        .where((h) => h.isNotEmpty)
        .take(3)
        .toList();
    final peopleSubtitle = handles.isEmpty
        ? '${max(0, participants.length - 1)} people'
        : handles.join(', ');

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Center(child: _diagonalAvatars(context)),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton(
              onPressed: onEdit,
              child: const Text(
                'Change name and image',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A90D9),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _quickAction(
                  context: context,
                  icon:
                      Icon(LucideIcons.userPlus, size: 22, color: cs.onSurface),
                  label: 'Add',
                  onTap: onShowMembers,
                ),
                _quickAction(
                  context: context,
                  icon: Icon(LucideIcons.search, size: 22, color: cs.onSurface),
                  label: 'Search',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  ),
                ),
                _quickAction(
                  context: context,
                  icon:
                      Icon(LucideIcons.bellOff, size: 22, color: cs.onSurface),
                  label: 'Mute',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  ),
                ),
                _quickAction(
                  context: context,
                  icon:
                      Icon(LucideIcons.ellipsis, size: 22, color: cs.onSurface),
                  label: 'Options',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7B2FF7), Color(0xFFB44AFF)],
                ),
              ),
            ),
            title: const Text('Theme'),
            subtitle: Text('Default', style: TextStyle(color: muted)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            ),
          ),
          const Divider(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(LucideIcons.link2, color: cs.onSurface),
            title: const Text('Invitation link'),
            subtitle: Text('Coming soon', style: TextStyle(color: muted)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            ),
          ),
          const Divider(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(LucideIcons.users, color: cs.onSurface),
            title: const Text('People'),
            subtitle: Text(peopleSubtitle, style: TextStyle(color: muted)),
            trailing: const Icon(Icons.chevron_right),
            onTap: onShowMembers,
          ),
        ],
      ),
    );
  }
}
