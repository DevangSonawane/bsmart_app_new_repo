import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/call_controller.dart';
import '../services/call_service.dart';
import '../services/group_call_controller.dart';
import '../services/group_call_service.dart';
import '../utils/current_user.dart';
import 'safe_network_image.dart';

/// One row of the merged call feed — either a 1:1 `CallLog` or a `GroupCall`.
class _CallEntry {
  _CallEntry({
    required this.isGroup,
    required this.title,
    required this.avatar,
    required this.callType,
    required this.at,
    required this.outgoing,
    required this.missed,
    required this.durationSeconds,
    this.peerId,
    this.conversationId,
  });
  final bool isGroup;
  final String title;
  final String? avatar;
  final String callType;
  final DateTime at;
  final bool outgoing;
  final bool missed;
  final int durationSeconds;
  final String? peerId;
  final String? conversationId;
}

/// Calls tab: fetches `/calls` and `/group-calls` and merges them client-side
/// into one date-grouped, newest-first feed (no backend cross-collection
/// endpoint exists).
class CallHistoryView extends StatefulWidget {
  const CallHistoryView({super.key});
  @override
  State<CallHistoryView> createState() => _CallHistoryViewState();
}

class _CallHistoryViewState extends State<CallHistoryView> {
  final _calls = CallService();
  final _groupCalls = GroupCallService();
  List<_CallEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final selfId = await CurrentUser.id ?? '';
      final results = await Future.wait([
        _calls.history(limit: 50).catchError((_) => <String, dynamic>{}),
        _groupCalls.history(limit: 50).catchError((_) => <String, dynamic>{}),
      ]);
      final entries = <_CallEntry>[
        for (final c in _list(results[0])) _oneToOne(c, selfId),
        for (final c in _list(results[1])) _group(c, selfId),
      ]..sort((a, b) => b.at.compareTo(a.at));
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load calls.';
        _loading = false;
      });
    }
  }

  static List<Map<String, dynamic>> _list(Map<String, dynamic> res) {
    final raw = res['calls'] ?? res['data'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static String _id(dynamic v) => v is Map ? (v['_id'] ?? v['id'] ?? '').toString() : (v ?? '').toString();
  static String _name(dynamic v) =>
      v is Map ? (v['full_name'] ?? v['name'] ?? v['username'] ?? 'User').toString() : 'User';
  static String? _avatar(dynamic v) => v is Map ? (v['avatar_url'] ?? v['avatarUrl'])?.toString() : null;
  static DateTime _date(Map<String, dynamic> c) =>
      DateTime.tryParse((c['started_at'] ?? c['createdAt'] ?? c['created_at'] ?? '').toString())?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  _CallEntry _oneToOne(Map<String, dynamic> c, String selfId) {
    final caller = c['caller_id'];
    final receiver = c['receiver_id'];
    final outgoing = _id(caller) == selfId;
    final other = outgoing ? receiver : caller;
    final status = (c['status'] ?? '').toString();
    return _CallEntry(
      isGroup: false,
      title: _name(other),
      avatar: _avatar(other),
      callType: (c['call_type'] ?? 'voice').toString(),
      at: _date(c),
      outgoing: outgoing,
      missed: !outgoing && (status == 'missed' || status == 'rejected'),
      durationSeconds: (c['duration_seconds'] as num?)?.toInt() ?? 0,
      peerId: _id(other),
    );
  }

  _CallEntry _group(Map<String, dynamic> c, String selfId) {
    final conv = c['conversation_id'];
    final participants = (c['participants'] as List?)?.whereType<Map>().toList() ?? const [];
    final me = participants.where((p) => _id(p['user_id']) == selfId).firstOrNull;
    final others = participants.where((p) => _id(p['user_id']) != selfId).map((p) => _name(p['user_id'])).toList();
    final title = conv is Map && (conv['groupName']?.toString().isNotEmpty ?? false)
        ? conv['groupName'].toString()
        : others.isEmpty
            ? 'Group call'
            : others.take(3).join(', ');
    final started = _date(c);
    final ended = DateTime.tryParse((c['ended_at'] ?? '').toString())?.toLocal();
    return _CallEntry(
      isGroup: true,
      title: title,
      avatar: conv is Map ? conv['groupAvatar']?.toString() : null,
      callType: (c['call_type'] ?? 'voice').toString(),
      at: started,
      outgoing: _id(c['initiator_id']) == selfId,
      missed: me != null && (me['status'] == 'missed' || me['status'] == 'declined'),
      durationSeconds: ended == null ? 0 : ended.difference(started).inSeconds,
      conversationId: conv is Map ? _id(conv) : (conv is String ? conv : null),
    );
  }

  void _callBack(_CallEntry e) {
    if (e.isGroup) {
      final convId = e.conversationId;
      if (convId == null || convId.isEmpty) return;
      GroupCallController.instance.start(conversationId: convId, callType: e.callType, title: e.title, avatar: e.avatar);
    } else if (e.peerId?.isNotEmpty == true) {
      CallController.instance.start(peer: CallPeer(id: e.peerId!, name: e.title, avatar: e.avatar), callType: e.callType);
    }
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat(d.year == now.year ? 'EEE, d MMM' : 'd MMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: .7);
    final items = <Widget>[];
    String? lastDay;
    for (final e in _entries) {
      final day = _dayLabel(e.at);
      if (day != lastDay) {
        lastDay = day;
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(day, style: TextStyle(fontWeight: FontWeight.w700, color: muted)),
        ));
      }
      final directionIcon = e.missed ? LucideIcons.phoneMissed : (e.outgoing ? LucideIcons.phoneOutgoing : LucideIcons.phoneIncoming);
      final duration = e.durationSeconds > 0
          ? ' · ${e.durationSeconds ~/ 60}:${(e.durationSeconds % 60).toString().padLeft(2, '0')}'
          : '';
      final canCallBack = e.isGroup ? (e.conversationId?.isNotEmpty ?? false) : (e.peerId?.isNotEmpty ?? false);
      items.add(ListTile(
        leading: e.avatar?.isNotEmpty == true
            ? ClipOval(child: SafeNetworkImage(url: e.avatar!, width: 44, height: 44, fit: BoxFit.cover))
            : CircleAvatar(radius: 22, child: e.isGroup ? const Icon(LucideIcons.users, size: 20) : Text(e.title.isNotEmpty ? e.title[0].toUpperCase() : '?')),
        title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: e.missed ? Colors.redAccent : null, fontWeight: FontWeight.w600)),
        subtitle: Row(children: [
          Icon(directionIcon, size: 14, color: e.missed ? Colors.redAccent : muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${e.isGroup ? 'Group ' : ''}${e.callType == 'video' ? 'video' : 'voice'} · ${DateFormat.jm().format(e.at)}$duration',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        trailing: canCallBack
            ? IconButton(
                icon: Icon(e.callType == 'video' ? LucideIcons.video : LucideIcons.phone),
                onPressed: () => _callBack(e),
              )
            : null,
      ));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: items.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
                  child: Center(child: Text(_error ?? 'No calls yet', style: TextStyle(color: muted, fontWeight: FontWeight.w600))),
                ),
              ]
            : items,
      ),
    );
  }
}
