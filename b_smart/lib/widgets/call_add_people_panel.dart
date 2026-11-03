import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/follows_api.dart';
import '../utils/current_user.dart';
import 'safe_network_image.dart';

/// Full-screen people picker shown inside the call overlay to add people to
/// an ongoing call (1:1 escalation or a group-call invite).
class CallAddPeoplePanel extends StatefulWidget {
  const CallAddPeoplePanel({
    super.key,
    required this.excludeIds,
    required this.onCancel,
    required this.onSubmit,
  });

  final Set<String> excludeIds;
  final VoidCallback onCancel;
  final void Function(List<String> userIds) onSubmit;

  @override
  State<CallAddPeoplePanel> createState() => _CallAddPeoplePanelState();
}

class _CallAddPeoplePanelState extends State<CallAddPeoplePanel> {
  final _search = TextEditingController();
  final _selected = <String, Map<String, dynamic>>{};
  List<Map<String, dynamic>> _suggested = const [];
  bool _loading = true;
  String? _selfId;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onQuery);
    _loadSuggested();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Mirrors the web AddCallPeopleModal: the people you follow, from the paged
  /// endpoint (`{ users: [...], total }`), filtered client-side as you type.
  Future<void> _loadSuggested() async {
    try {
      _selfId = await CurrentUser.id;
      final id = _selfId;
      final users = <Map<String, dynamic>>[];
      if (id != null && id.isNotEmpty) {
        final page = await FollowsApi().getFollowingPage(id, limit: 100);
        final raw = page['users'];
        if (raw is List) {
          users.addAll(raw.whereType<Map>().map((u) => _unwrap(Map<String, dynamic>.from(u))));
        }
      }
      if (!mounted) return;
      setState(() {
        _suggested = users;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQuery() => setState(() {});

  static Map<String, dynamic> _unwrap(Map<String, dynamic> m) {
    for (final key in const ['user', 'following', 'following_id']) {
      final v = m[key];
      if (v is Map) return Map<String, dynamic>.from(v);
    }
    return m;
  }

  static String _id(Map<String, dynamic> u) =>
      (u['_id'] ?? u['id'] ?? u['user_id'] ?? '').toString();
  static String _name(Map<String, dynamic> u) =>
      (u['full_name'] ?? u['name'] ?? u['username'] ?? 'User').toString();
  static String? _avatar(Map<String, dynamic> u) =>
      (u['avatar_url'] ?? u['avatarUrl'] ?? u['profile_pic'])?.toString();

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final users = _suggested.where((u) {
      final id = _id(u);
      if (id.isEmpty || id == _selfId || widget.excludeIds.contains(id)) return false;
      if (query.isEmpty) return true;
      return _name(u).toLowerCase().contains(query) || (u['username']?.toString().toLowerCase().contains(query) ?? false);
    }).toList();
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(children: [
          Row(children: [
            IconButton(onPressed: widget.onCancel, icon: const Icon(Icons.close)),
            const Expanded(child: Text('Add people', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            TextButton(
              onPressed: _selected.isEmpty ? null : () => widget.onSubmit(_selected.keys.toList()),
              child: Text(_selected.isEmpty ? 'Add' : 'Add (${_selected.length})'),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search people you follow…',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                isDense: true,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final u in _selected.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(_name(u)),
                        onDeleted: () => setState(() => _selected.remove(_id(u))),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading && users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? const Center(child: Text('No one else to add.'))
                    : ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (_, i) {
                          final u = users[i];
                          final id = _id(u);
                          final avatar = _avatar(u);
                          final name = _name(u);
                          return CheckboxListTile(
                            value: _selected.containsKey(id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected[id] = u;
                              } else {
                                _selected.remove(id);
                              }
                            }),
                            secondary: avatar != null && avatar.isNotEmpty
                                ? ClipOval(child: SafeNetworkImage(url: avatar, width: 40, height: 40, fit: BoxFit.cover))
                                : CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
                            title: Text(name),
                            subtitle: u['username'] != null ? Text('@${u['username']}') : null,
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
