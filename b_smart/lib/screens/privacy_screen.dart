import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/follow_requests_api.dart';
import '../theme/design_tokens.dart';
import '../widgets/safe_network_image.dart';

/// Matches the React web app "Account Privacy" screen.
///
/// Endpoints (React parity):
/// - PATCH /follow/privacy/set { isPrivate }
/// - GET   /follow/privacy/status -> { isPrivate, pendingRequestsCount }
/// - GET   /follow/requests -> { count, requests: [...] }
/// - POST  /follow/requests/:requesterId/accept
/// - POST  /follow/requests/:requesterId/decline
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _api = FollowRequestsApi();

  bool _loading = true;
  bool _toggling = false;
  bool _isPrivate = false;
  int _pendingCount = 0;

  bool _showRequests = false;
  bool _loadingRequests = false;
  List<Map<String, dynamic>> _requests = const [];
  final Map<String, String> _actionLoading = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _id(Map<String, dynamic> r) =>
      (r['_id'] ?? r['id'] ?? r['requestId'] ?? '').toString().trim();

  String _username(Map<String, dynamic> r) =>
      (r['username'] ?? r['handle'] ?? '').toString().trim();

  String? _bio(Map<String, dynamic> r) =>
      (r['bio'] ?? r['about'] ?? r['title'])?.toString().trim();

  String? _avatar(Map<String, dynamic> r) => (r['profilePicture'] ??
          r['profile_pic'] ??
          r['profilePic'] ??
          r['avatar_url'] ??
          r['avatarUrl'])
      ?.toString()
      .trim();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await _api.getPrivacyStatus();
      if (!mounted) return;
      setState(() {
        _isPrivate = status?.isPrivate ?? false;
        _pendingCount = status?.pendingRequestsCount ?? 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _togglePrivacy() async {
    if (_loading || _toggling) return;
    setState(() => _toggling = true);
    try {
      final desired = !_isPrivate;
      final res = await _api.setAccountPrivacy(isPrivate: desired);
      if (!mounted) return;

      Map<String, dynamic>? payload;
      if (res['data'] is Map) payload = Map<String, dynamic>.from(res['data']);
      payload ??= res;

      final nextPrivateRaw = payload['isPrivate'] ?? payload['is_private'];
      final nextPrivate = nextPrivateRaw == true ||
          (nextPrivateRaw is String && nextPrivateRaw.toLowerCase() == 'true');

      final message = (payload['message'] ?? payload['msg'])?.toString().trim();

      setState(() {
        _isPrivate = nextPrivate;
        if (!nextPrivate) {
          // React parity: going public auto-accepts pending.
          _pendingCount = 0;
          _requests = const [];
          _showRequests = false;
        }
      });

      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update privacy settings.')),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _loadRequests() async {
    if (_loadingRequests) return;
    setState(() {
      _showRequests = true;
      _loadingRequests = true;
    });
    try {
      final page = await _api.getFollowRequests();
      if (!mounted) return;
      setState(() {
        _requests = page.requests;
        _pendingCount = page.count;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load follow requests.')),
      );
    } finally {
      if (mounted) setState(() => _loadingRequests = false);
    }
  }

  Future<void> _toggleRequests() async {
    if (_showRequests) {
      setState(() => _showRequests = false);
      return;
    }
    await _loadRequests();
  }

  String _initials(String username) {
    final u = username.trim();
    if (u.isEmpty) return 'U';
    final parts = u.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final first = parts.isNotEmpty ? parts.first : u;
    final second = parts.length > 1 ? parts[1] : '';
    final a = first.characters.first.toUpperCase();
    final b = second.isNotEmpty ? second.characters.first.toUpperCase() : '';
    return (a + b).trim().isEmpty ? 'U' : (a + b);
  }

  Future<void> _accept(String requesterId) async {
    final id = requesterId.trim();
    if (id.isEmpty) return;
    if (_actionLoading.containsKey(id)) return;
    setState(() => _actionLoading[id] = 'accept');
    try {
      await _api.acceptFollowRequest(id);
      if (!mounted) return;
      setState(() {
        _requests = _requests.where((r) => _id(r) != id).toList();
        _pendingCount = (_pendingCount - 1).clamp(0, 1 << 30);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow request accepted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept request.')),
      );
    } finally {
      if (mounted) setState(() => _actionLoading.remove(id));
    }
  }

  Future<void> _decline(String requesterId) async {
    final id = requesterId.trim();
    if (id.isEmpty) return;
    if (_actionLoading.containsKey(id)) return;
    setState(() => _actionLoading[id] = 'decline');
    try {
      await _api.declineFollowRequest(id);
      if (!mounted) return;
      setState(() {
        _requests = _requests.where((r) => _id(r) != id).toList();
        _pendingCount = (_pendingCount - 1).clamp(0, 1 << 30);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow request declined.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to decline request.')),
      );
    } finally {
      if (mounted) setState(() => _actionLoading.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Account Privacy'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _privacyToggleCard(theme, isDark),
            const SizedBox(height: 12),
            _explanationCard(theme, isDark),
            const SizedBox(height: 12),
            if (_isPrivate) _followRequestsCard(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _privacyToggleCard(ThemeData theme, bool isDark) {
    final subtitle = _loading
        ? 'Loading…'
        : _isPrivate
            ? 'Only approved followers can see your posts'
            : 'Anyone can follow and see your posts';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFFCE7F3),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.lock, color: Color(0xFFFA3F5E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Private Account',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _privacyToggleSwitch(
            isDark: isDark,
            value: _isPrivate,
            disabled: _loading || _toggling,
            loading: _toggling,
            onTap: _togglePrivacy,
          ),
        ],
      ),
    );
  }

  Widget _privacyToggleSwitch({
    required bool isDark,
    required bool value,
    required bool disabled,
    required bool loading,
    required VoidCallback onTap,
  }) {
    final trackOn = const Color(0xFFFA3F5E);
    final trackOff = isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB);

    return Semantics(
      label: 'Private account',
      value: value ? 'On' : 'Off',
      button: true,
      enabled: !disabled,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 44,
          height: 24,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? trackOn : trackOff,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(4),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF9CA3AF),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _explanationCard(ThemeData theme, bool isDark) {
    Widget row({
      required IconData icon,
      required String title,
      required String body,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          row(
            icon: LucideIcons.users,
            title: 'When your account is public',
            body:
                'Your profile and posts can be seen by anyone. Anyone can follow you without approval.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
            ),
          ),
          row(
            icon: LucideIcons.lock,
            title: 'When your account is private',
            body:
                'Only followers you approve can see your photos and videos. Existing followers won’t be affected.',
          ),
        ],
      ),
    );
  }

  Widget _followRequestsCard(ThemeData theme, bool isDark) {
    final chevronTurns = _showRequests ? 0.25 : 0.0; // 90 degrees

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggleRequests,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFFCE7F3),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(LucideIcons.clock, color: Color(0xFFFA3F5E)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Follow Requests',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _pendingCount > 0
                              ? '$_pendingCount pending request${_pendingCount > 1 ? 's' : ''}'
                              : 'No pending requests',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_pendingCount > 0)
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFA3F5E),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _pendingCount > 9 ? '9+' : '$_pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: chevronTurns,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showRequests)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: _loadingRequests
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DesignTokens.instaPink,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Loading requests…',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _requests.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 20, 14, 22),
                          child: Column(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1F2937)
                                      : const Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LucideIcons.userCheck,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No pending requests',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Follow requests will appear here',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: _requests.map((r) {
                            final id = _id(r);
                            final username = _username(r);
                            final avatar = _avatar(r);
                            final bio = _bio(r);
                            final acting = _actionLoading[id];
                            return Container(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: 0.06),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFE5E7EB),
                                          Color(0xFFCBD5E1),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: (isDark
                                                ? Colors.white
                                                : Colors.black)
                                            .withValues(alpha: 0.06),
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: avatar != null && avatar.isNotEmpty
                                          ? SafeNetworkImage(
                                              url: avatar,
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                            )
                                          : Center(
                                              child: Text(
                                                _initials(username),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: theme
                                                      .colorScheme.onSurface
                                                      .withValues(alpha: 0.65),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          username.isNotEmpty
                                              ? username
                                              : 'user',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        if (bio != null && bio.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            bio,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Row(
                                    children: [
                                      SizedBox(
                                        height: 32,
                                        child: ElevatedButton.icon(
                                          onPressed: acting != null
                                              ? null
                                              : () => unawaited(_accept(id)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          icon: acting == 'accept'
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(LucideIcons.check,
                                                  size: 14),
                                          label: const Text('Confirm'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 32,
                                        child: ElevatedButton.icon(
                                          onPressed: acting != null
                                              ? null
                                              : () => unawaited(_decline(id)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isDark
                                                ? const Color(0xFF374151)
                                                : const Color(0xFFE5E7EB),
                                            foregroundColor: isDark
                                                ? Colors.white
                                                : const Color(0xFF374151),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 8),
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          icon: acting == 'decline'
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(LucideIcons.x,
                                                  size: 14),
                                          label: const Text('Delete'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
            ),
        ],
      ),
    );
  }
}
