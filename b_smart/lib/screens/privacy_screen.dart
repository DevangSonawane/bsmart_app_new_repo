import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api.dart';
import '../theme/design_tokens.dart';
import '../widgets/safe_network_image.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final FollowRequestsApi _followApi = FollowRequestsApi();
  final PrivacyApi _privacyApi = PrivacyApi();

  bool _loading = true;
  bool _toggling = false;
  bool _saving = false;
  bool _showRequests = false;
  bool _loadingRequests = false;

  bool _isPrivate = false;
  int _pendingCount = 0;

  PrivacySettingsData _settings = PrivacySettingsData.defaults();
  PrivacySettingsData _snapshot = PrivacySettingsData.defaults();

  List<Map<String, dynamic>> _requests = const <Map<String, dynamic>>[];
  final Map<String, String> _actionLoading = <String, String>{};

  String? _saveError;

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  bool get _isDirty => !_settings.equals(_snapshot);

  String _id(Map<String, dynamic> r) =>
      (r['_id'] ?? r['id'] ?? r['requestId'] ?? '').toString().trim();

  String _username(Map<String, dynamic> r) =>
      (r['username'] ?? r['handle'] ?? r['full_name'] ?? r['name'] ?? '')
          .toString()
          .trim();

  String? _bio(Map<String, dynamic> r) =>
      (r['bio'] ?? r['about'] ?? r['title'])?.toString().trim();

  String? _avatar(Map<String, dynamic> r) => (r['profilePicture'] ??
          r['profile_pic'] ??
          r['profilePic'] ??
          r['avatar_url'] ??
          r['avatarUrl'])
      ?.toString()
      .trim();

  String _followersCountText(Map<String, dynamic> r) {
    final raw = r['followers_count'] ?? r['followersCount'] ?? 0;
    final count = raw is num
        ? raw.toInt()
        : int.tryParse(raw.toString().trim()) ?? 0;
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M followers';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k followers';
    }
    return '$count follower${count == 1 ? '' : 's'}';
  }

  String _initials(String username) {
    final clean = username.trim();
    if (clean.isEmpty) return 'U';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final first = parts.isNotEmpty ? parts.first : clean;
    final second = parts.length > 1 ? parts[1] : '';
    final a = first.isNotEmpty ? first[0].toUpperCase() : 'U';
    final b = second.isNotEmpty ? second[0].toUpperCase() : '';
    final result = (a + b).trim();
    return result.isEmpty ? 'U' : result;
  }

  String _labelForVisibility(String value) {
    return kPrivacyVisibilityLabels[value] ?? value;
  }

  String _errorMessage(Object error, String fallback) {
    if (error is ApiException) {
      final body = error.body;
      final bodyMessage = body?['message'] ?? body?['error'] ?? body?['msg'];
      if (bodyMessage is String && bodyMessage.trim().isNotEmpty) {
        return bodyMessage.trim();
      }
      if (error.message.trim().isNotEmpty) return error.message.trim();
    }
    return fallback;
  }

  Future<T?> _safe<T>(Future<T?> future) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadEverything() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _saveError = null;
    });

    final statusFuture = _safe<FollowPrivacyStatus>(
      _followApi.getPrivacyStatus(),
    );
    final settingsFuture = _safe<PrivacySettingsData>(
      _privacyApi.getPrivacySettings(),
    );
    final status = await statusFuture;
    final settings = await settingsFuture;

    if (!mounted) return;

    setState(() {
      _isPrivate = status?.isPrivate ?? false;
      _pendingCount = status?.pendingRequestsCount ?? 0;
      _settings = settings ?? PrivacySettingsData.defaults();
      _snapshot = _settings.copyWith(
        profileVisibility: _settings.profileVisibility,
        activityStatus: _settings.activityStatus,
        followSettings: _settings.followSettings,
        messagingPrivacy: _settings.messagingPrivacy,
        searchDiscovery: _settings.searchDiscovery,
      );
      _loading = false;
    });
  }

  Future<void> _togglePrivacy() async {
    if (_loading || _toggling) return;
    setState(() => _toggling = true);
    try {
      final desired = !_isPrivate;
      final res = await _followApi.setAccountPrivacy(isPrivate: desired);
      if (!mounted) return;

      final raw = res['data'] is Map
          ? Map<String, dynamic>.from(res['data'] as Map)
          : res;
      final nextPrivateRaw = raw['isPrivate'] ?? raw['is_private'];
      final nextPrivate = nextPrivateRaw == true ||
          (nextPrivateRaw is String && nextPrivateRaw.toLowerCase() == 'true');
      final message = (raw['message'] ?? raw['msg'])?.toString().trim();

      setState(() {
        _isPrivate = nextPrivate;
        if (!nextPrivate) {
          _pendingCount = 0;
          _requests = const <Map<String, dynamic>>[];
          _showRequests = false;
        }
      });

      if (message != null && message.isNotEmpty && mounted) {
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

  Future<void> _toggleRequests() async {
    if (_showRequests) {
      setState(() => _showRequests = false);
      return;
    }
    await _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (_loadingRequests) return;
    setState(() {
      _showRequests = true;
      _loadingRequests = true;
    });
    try {
      final page = await _followApi.getFollowRequests();
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

  Future<void> _accept(String requesterId) async {
    final id = requesterId.trim();
    if (id.isEmpty || _actionLoading.containsKey(id)) return;
    setState(() => _actionLoading[id] = 'accept');
    try {
      await _followApi.acceptFollowRequest(id);
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
    if (id.isEmpty || _actionLoading.containsKey(id)) return;
    setState(() => _actionLoading[id] = 'decline');
    try {
      await _followApi.declineFollowRequest(id);
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

  void _updateProfileVisibility(String key, String value) {
    setState(() {
      _settings = _settings.copyWith(
        profileVisibility: <String, dynamic>{
          ..._settings.profileVisibility,
          key: value,
        },
      );
      _saveError = null;
    });
  }

  void _updateActivityStatus(String key, bool value) {
    setState(() {
      _settings = _settings.copyWith(
        activityStatus: <String, dynamic>{
          ..._settings.activityStatus,
          key: value,
        },
      );
      _saveError = null;
    });
  }

  void _updateFollowSettings(String key, bool value) {
    setState(() {
      _settings = _settings.copyWith(
        followSettings: <String, dynamic>{
          ..._settings.followSettings,
          key: value,
        },
      );
      _saveError = null;
    });
  }

  void _updateMessagingPrivacy(String value) {
    setState(() {
      _settings = _settings.copyWith(messagingPrivacy: value);
      _saveError = null;
    });
  }

  void _updateSearchDiscovery(String key, bool value) {
    setState(() {
      _settings = _settings.copyWith(
        searchDiscovery: <String, dynamic>{
          ..._settings.searchDiscovery,
          key: value,
        },
      );
      _saveError = null;
    });
  }

  void _discardChanges() {
    setState(() {
      _settings = _snapshot.copyWith(
        profileVisibility: _snapshot.profileVisibility,
        activityStatus: _snapshot.activityStatus,
        followSettings: _snapshot.followSettings,
        messagingPrivacy: _snapshot.messagingPrivacy,
        searchDiscovery: _snapshot.searchDiscovery,
      );
      _saveError = null;
    });
  }

  Future<void> _saveChanges() async {
    if (!_isDirty || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await Future.wait([
        _privacyApi.updateProfileVisibility(_settings.profileVisibility),
        _privacyApi.updateActivityStatus(_settings.activityStatus),
        _privacyApi.updateFollowSettings(_settings.followSettings),
        _privacyApi.updateMessagingPrivacy(_settings.messagingPrivacy),
        _privacyApi.updateSearchDiscovery(_settings.searchDiscovery),
      ]);
      if (!mounted) return;
      setState(() {
        _snapshot = _settings.copyWith(
          profileVisibility: _settings.profileVisibility,
          activityStatus: _settings.activityStatus,
          followSettings: _settings.followSettings,
          messagingPrivacy: _settings.messagingPrivacy,
          searchDiscovery: _settings.searchDiscovery,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Privacy settings saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saveError = _errorMessage(
          e,
          'Failed to save privacy settings. Try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _showPrivacyPicker({
    required String title,
    required String currentValue,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                ...kPrivacyVisibilityValues.map((value) {
                  final label = _labelForVisibility(value);
                  final selected = value == currentValue;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(label),
                    trailing: selected
                        ? Icon(
                            LucideIcons.check,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(ctx).pop(value),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: Color(0xFFFA3F5E),
        ),
      ),
    );
  }

  Widget _cardShell({
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFA3F5E).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: const Color(0xFFFA3F5E),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _privacyToggleRow() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitle = _loading
        ? 'Loading…'
        : _isPrivate
            ? 'Only approved followers can see your posts'
            : 'Anyone can see your posts';

    return Padding(
      padding: const EdgeInsets.all(16),
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
          if (_toggling)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF9CA3AF),
              ),
            )
          else
            _toggleSwitch(
              value: _isPrivate,
              enabled: !_loading && !_saving,
              onChanged: (_) => _togglePrivacy(),
            ),
        ],
      ),
    );
  }

  Widget _followRequestsCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06);

    return _cardShell(
      child: Column(
        children: [
          InkWell(
            onTap: _toggleRequests,
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                    turns: _showRequests ? 0.25 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showRequests)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
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
                                border: Border(top: BorderSide(color: borderColor)),
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
                                        color: (isDark ? Colors.white : Colors.black)
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
                                                  color: theme.colorScheme.onSurface
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
                                          username.isNotEmpty ? username : 'user',
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
                                        const SizedBox(height: 2),
                                        Text(
                                          _followersCountText(r),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color:
                                                theme.colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 11,
                                          ),
                                        ),
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
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
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
                                                  child: CircularProgressIndicator(
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
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
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
                                                  child: CircularProgressIndicator(
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

  Widget _dropdownRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final selected = _labelForVisibility(value);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFA3F5E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFA3F5E).withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selected,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: const Color(0xFFFA3F5E),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 12,
                    color: const Color(0xFFFA3F5E)
                        .withValues(alpha: 0.9),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow({
    required String label,
    required String sublabel,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: InkWell(
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _toggleSwitch(
                value: value,
                enabled: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleSwitch({
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveThumbColor =
        isDark ? const Color(0xFFE5E7EB) : const Color(0xFF4B5563);
    final inactiveTrackColor =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);

    return Switch.adaptive(
      value: value,
      activeThumbColor: DesignTokens.instaPink,
      activeTrackColor: DesignTokens.instaPink.withValues(alpha: 0.35),
      inactiveThumbColor: inactiveThumbColor,
      inactiveTrackColor: inactiveTrackColor,
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _profileVisibilityCard() {
    return _cardShell(
      child: Column(
        children: [
          _sectionHeader(
            icon: LucideIcons.eye,
            description:
                'Choose who can see each section of your profile',
          ),
          Container(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          _dropdownRow(
            label: 'Profile',
            value: (_settings.profileVisibility['profile'] ?? 'everyone')
                .toString(),
            onTap: _loading || _saving
                ? () {}
                : () async {
                    final next = await _showPrivacyPicker(
                      title: 'Profile',
                      currentValue: (_settings.profileVisibility['profile'] ??
                              'everyone')
                          .toString(),
                    );
                    if (next != null && mounted) {
                      _updateProfileVisibility('profile', next);
                    }
                  },
          ),
          _divider(),
          _dropdownRow(
            label: 'Posts',
            value: (_settings.profileVisibility['posts'] ?? 'everyone')
                .toString(),
            onTap: _loading || _saving
                ? () {}
                : () async {
                    final next = await _showPrivacyPicker(
                      title: 'Posts',
                      currentValue:
                          (_settings.profileVisibility['posts'] ?? 'everyone')
                              .toString(),
                    );
                    if (next != null && mounted) {
                      _updateProfileVisibility('posts', next);
                    }
                  },
          ),
          _divider(),
          _dropdownRow(
            label: 'Stories',
            value: (_settings.profileVisibility['stories'] ?? 'everyone')
                .toString(),
            onTap: _loading || _saving
                ? () {}
                : () async {
                    final next = await _showPrivacyPicker(
                      title: 'Stories',
                      currentValue:
                          (_settings.profileVisibility['stories'] ?? 'everyone')
                              .toString(),
                    );
                    if (next != null && mounted) {
                      _updateProfileVisibility('stories', next);
                    }
                  },
          ),
          _divider(),
          _dropdownRow(
            label: 'Pulse',
            value: (_settings.profileVisibility['pulse'] ?? 'everyone')
                .toString(),
            onTap: _loading || _saving
                ? () {}
                : () async {
                    final next = await _showPrivacyPicker(
                      title: 'Pulse',
                      currentValue:
                          (_settings.profileVisibility['pulse'] ?? 'everyone')
                              .toString(),
                    );
                    if (next != null && mounted) {
                      _updateProfileVisibility('pulse', next);
                    }
                  },
          ),
          _divider(),
          _dropdownRow(
            label: 'Followers List',
            value: (_settings.profileVisibility['followers_list'] ?? 'everyone')
                .toString(),
            onTap: _loading || _saving
                ? () {}
                : () async {
                    final next = await _showPrivacyPicker(
                      title: 'Followers List',
                      currentValue: (_settings.profileVisibility['followers_list'] ??
                              'everyone')
                          .toString(),
                    );
                    if (next != null && mounted) {
                      _updateProfileVisibility('followers_list', next);
                    }
                  },
          ),
          _divider(),
          _dropdownRow(
            label: 'Following List',
            value: (_settings.profileVisibility['following_list'] ?? 'everyone')
                .toString(),
            onTap: _loading || _saving
                ? () {}
                : () async {
                    final next = await _showPrivacyPicker(
                      title: 'Following List',
                      currentValue: (_settings.profileVisibility['following_list'] ??
                              'everyone')
                          .toString(),
                    );
                    if (next != null && mounted) {
                      _updateProfileVisibility('following_list', next);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _activityStatusCard() {
    return _cardShell(
      child: Column(
        children: [
          _sectionHeader(
            icon: LucideIcons.activity,
            description:
                'Others can see the green dot when you\'re active',
          ),
          Container(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          _toggleRow(
            label: 'Show Online Status',
            sublabel: 'Others can see the green dot when you\'re active',
            value: (_settings.activityStatus['show_online_status'] ?? true)
                as bool,
            onChanged: (value) =>
                _updateActivityStatus('show_online_status', value),
            enabled: !_loading && !_saving,
          ),
          _divider(),
          _toggleRow(
            label: 'Show Last Seen',
            sublabel: 'Others can see when you were last active',
            value: (_settings.activityStatus['show_last_seen'] ?? true)
                as bool,
            onChanged: (value) => _updateActivityStatus('show_last_seen', value),
            enabled: !_loading && !_saving,
          ),
          _divider(),
          _toggleRow(
            label: 'Show Read Receipts',
            sublabel: 'Others can see when you\'ve read their messages',
            value: (_settings.activityStatus['show_read_receipts'] ?? true)
                as bool,
            onChanged: (value) =>
                _updateActivityStatus('show_read_receipts', value),
            enabled: !_loading && !_saving,
          ),
        ],
      ),
    );
  }

  Widget _followSettingsCard() {
    final allowFollowRequests =
        (_settings.followSettings['allow_follow_requests'] ?? true) as bool;
    final autoApprove =
        (_settings.followSettings['auto_approve_follow_requests'] ?? false)
            as bool;

    return _cardShell(
      child: Column(
        children: [
          _sectionHeader(
            icon: LucideIcons.users,
            description:
                'Let people send follow requests and auto-approve them when desired',
          ),
          Container(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          _toggleRow(
            label: 'Allow Follow Requests',
            sublabel: 'Let people send you follow requests',
            value: allowFollowRequests,
            onChanged: (value) =>
                _updateFollowSettings('allow_follow_requests', value),
            enabled: !_loading && !_saving,
          ),
          _divider(),
          _toggleRow(
            label: 'Auto Approve Follow Requests',
            sublabel: 'Automatically accept all incoming follow requests',
            value: autoApprove,
            onChanged: (value) =>
                _updateFollowSettings('auto_approve_follow_requests', value),
            enabled: allowFollowRequests && !_loading && !_saving,
          ),
        ],
      ),
    );
  }

  Widget _messagingPrivacyCard() {
    return _cardShell(
      child: Column(
        children: [
          _sectionHeader(
            icon: LucideIcons.messageCircle,
            description: 'Who can send you direct messages',
          ),
          Container(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          _dropdownRow(
            label: 'Allow Messages From',
            value: _settings.messagingPrivacy,
            onTap: _loading || _saving
                ? () {}
                : () async {
                    final next = await _showPrivacyPicker(
                      title: 'Allow Messages From',
                      currentValue: _settings.messagingPrivacy,
                    );
                    if (next != null && mounted) {
                      _updateMessagingPrivacy(next);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _searchDiscoveryCard() {
    return _cardShell(
      child: Column(
        children: [
          _sectionHeader(
            icon: LucideIcons.search,
            description:
                'Control how other people can find your account',
          ),
          Container(
            height: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          _toggleRow(
            label: 'Allow Search by Username',
            sublabel: 'Let people search for you by username',
            value: (_settings.searchDiscovery['allow_search_by_username'] ??
                true) as bool,
            onChanged: (value) =>
                _updateSearchDiscovery('allow_search_by_username', value),
            enabled: !_loading && !_saving,
          ),
          _divider(),
          _toggleRow(
            label: 'Allow Search by Email',
            sublabel: 'Let people search for you by email address',
            value: (_settings.searchDiscovery['allow_search_by_email'] ??
                false) as bool,
            onChanged: (value) =>
                _updateSearchDiscovery('allow_search_by_email', value),
            enabled: !_loading && !_saving,
          ),
          _divider(),
          _toggleRow(
            label: 'Allow Search by Phone',
            sublabel: 'Let people search for you by phone number',
            value: (_settings.searchDiscovery['allow_search_by_phone'] ??
                false) as bool,
            onChanged: (value) =>
                _updateSearchDiscovery('allow_search_by_phone', value),
            enabled: !_loading && !_saving,
          ),
          _divider(),
          _toggleRow(
            label: 'Appear in Suggestions',
            sublabel: 'Show up in people you may know suggestions',
            value: (_settings.searchDiscovery['appear_in_suggestions'] ??
                true) as bool,
            onChanged: (value) =>
                _updateSearchDiscovery('appear_in_suggestions', value),
            enabled: !_loading && !_saving,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Privacy'),
        centerTitle: true,
        actions: [
          if (_isDirty)
            TextButton(
              onPressed: _saving ? null : _discardChanges,
              child: Text(
                'Discard',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (_isDirty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _saving ? null : _saveChanges,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFA3F5E),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: _saving
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Saving…'),
                        ],
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          if (!_isDirty) const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadEverything,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            if (_saveError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.circleAlert,
                      size: 16,
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _saveError!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _sectionTitle('Account Privacy'),
            _cardShell(child: _privacyToggleRow()),
            const SizedBox(height: 12),
            if (_isPrivate) ...[
              _sectionTitle('Follow Requests'),
              _followRequestsCard(),
              const SizedBox(height: 12),
            ],
            _sectionTitle('Profile Visibility'),
            _profileVisibilityCard(),
            const SizedBox(height: 12),
            _sectionTitle('Activity Status'),
            _activityStatusCard(),
            const SizedBox(height: 12),
            _sectionTitle('Follow Settings'),
            _followSettingsCard(),
            const SizedBox(height: 12),
            _sectionTitle('Messaging Privacy'),
            _messagingPrivacyCard(),
            const SizedBox(height: 12),
            _sectionTitle('Search & Discovery'),
            _searchDiscoveryCard(),
          ],
        ),
      ),
    );
  }
}
