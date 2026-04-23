import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/follow_requests_api.dart';
import '../theme/design_tokens.dart';
import '../widgets/safe_network_image.dart';

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({super.key});

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen> {
  final _api = FollowRequestsApi();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = const [];
  final Set<String> _accepting = <String>{};
  final Set<String> _rejecting = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _id(Map<String, dynamic> r) =>
      (r['_id'] ?? r['id'] ?? r['requestId'] ?? '').toString().trim();

  Map<String, dynamic> _user(Map<String, dynamic> r) {
    final u = r['user'] ?? r['from'] ?? r['requester'] ?? r['sender'];
    return u is Map ? Map<String, dynamic>.from(u) : r;
  }

  String _userId(Map<String, dynamic> r) =>
      (_user(r)['_id'] ?? _user(r)['id'] ?? _user(r)['user_id'] ?? '')
          .toString()
          .trim();

  String _name(Map<String, dynamic> r) {
    final u = _user(r);
    final fullName =
        (u['full_name'] ?? u['fullName'] ?? u['name'])?.toString().trim();
    final username = (u['username'] ?? u['handle'])?.toString().trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;
    if (username != null && username.isNotEmpty) return username;
    return 'User';
  }

  String _username(Map<String, dynamic> r) {
    final u = _user(r);
    final username = (u['username'] ?? u['handle'])?.toString().trim();
    if (username != null && username.isNotEmpty) return '@$username';
    final id = _userId(r);
    return id.isNotEmpty ? '@$id' : '@user';
  }

  String? _avatar(Map<String, dynamic> r) {
    final u = _user(r);
    return (u['avatar_url'] ??
            u['avatarUrl'] ??
            u['profile_pic'] ??
            u['profilePic'] ??
            u['profilePicture'])
        ?.toString()
        .trim();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _api.getFollowRequests();
      if (!mounted) return;
      setState(() {
        _requests = page.requests;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load follow requests';
        _loading = false;
      });
    }
  }

  Future<void> _accept(Map<String, dynamic> r) async {
    final requesterId = _id(r);
    final key = requesterId;
    if (key.isEmpty || _accepting.contains(key)) return;
    setState(() => _accepting.add(key));
    try {
      await _api.acceptFollowRequest(requesterId);
      if (!mounted) return;
      setState(() {
        _requests = _requests.where((e) => _id(e) != key).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept request')),
      );
    } finally {
      if (mounted) setState(() => _accepting.remove(key));
    }
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    final requesterId = _id(r);
    final key = requesterId;
    if (key.isEmpty || _rejecting.contains(key)) return;
    setState(() => _rejecting.add(key));
    try {
      await _api.declineFollowRequest(requesterId);
      if (!mounted) return;
      setState(() {
        _requests = _requests.where((e) => _id(e) != key).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to reject request')),
      );
    } finally {
      if (mounted) setState(() => _rejecting.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Follow requests'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: DesignTokens.instaPink),
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Icon(LucideIcons.circleAlert,
                          color: Colors.redAccent),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(LucideIcons.refreshCw, size: 16),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : _requests.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 64, 16, 24),
                        children: [
                          Icon(LucideIcons.userPlus,
                              size: 48,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35)),
                          const SizedBox(height: 10),
                          Text(
                            'No follow requests',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'When someone requests to follow you, they’ll appear here.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final r = _requests[index];
                          final avatar = _avatar(r);
                          final name = _name(r);
                          final username = _username(r);
                          final key = _id(r);
                          final accepting = _accepting.contains(key);
                          final rejecting = _rejecting.contains(key);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF111827)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (avatar != null && avatar.isNotEmpty)
                                  ClipOval(
                                    child: SafeNetworkImage(
                                      url: avatar,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: DesignTokens.instaPink,
                                    child: Text(
                                      name.characters.first.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
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
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        username,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  children: [
                                    SizedBox(
                                      width: 92,
                                      height: 34,
                                      child: ElevatedButton(
                                        onPressed: accepting || rejecting
                                            ? null
                                            : () => unawaited(_accept(r)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          textStyle: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: accepting
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text('Accept'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: 92,
                                      height: 34,
                                      child: ElevatedButton(
                                        onPressed: accepting || rejecting
                                            ? null
                                            : () => unawaited(_reject(r)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark
                                              ? const Color(0xFF374151)
                                              : const Color(0xFF4B5563),
                                          foregroundColor: Colors.white,
                                          textStyle: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: rejecting
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text('Reject'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
