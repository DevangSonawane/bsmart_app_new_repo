import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api.dart';
import '../theme/design_tokens.dart';
import '../utils/app_error_handler.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final SupportQueriesApi _supportQueriesApi = SupportQueriesApi();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String _statusFilter = 'all';
  List<Map<String, dynamic>> _queries = const [];

  @override
  void initState() {
    super.initState();
    _loadQueries();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQueries({bool showLoading = true}) async {
    if (_refreshing) return;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      _refreshing = true;
    }

    try {
      final data = await _supportQueriesApi.getMySupportQueries(
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      if (!mounted) return;
      setState(() => _queries = data);
    } catch (e, st) {
      AppErrorHandler.logError('contact-support-load', e, st);
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to load support queries right now.',
        );
      });
    } finally {
      if (mounted) {
        if (showLoading) {
          setState(() => _loading = false);
        } else {
          _refreshing = false;
        }
      }
    }
  }

  List<Map<String, dynamic>> _filteredQueries() {
    var list = List<Map<String, dynamic>>.from(_queries);
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((q) => _searchText(q).contains(query)).toList();
    }
    list.sort((a, b) => _readAt(b).compareTo(_readAt(a)));
    return list;
  }

  String _searchText(Map<String, dynamic> query) {
    final subject = (query['subject'] ?? '').toString();
    final message = (query['message'] ?? '').toString();
    final category = (query['category'] ?? '').toString();
    final status = (query['status'] ?? '').toString();
    return '$subject $message $category $status'.toLowerCase();
  }

  DateTime _readAt(Map<String, dynamic> query) {
    final raw = query['createdAt'] ??
        query['created_at'] ??
        query['updatedAt'] ??
        query['updated_at'];
    if (raw is DateTime) return raw;
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _status(Map<String, dynamic> query) {
    return (query['status'] ?? '').toString().trim().toLowerCase();
  }

  Future<void> _openCreateQuerySheet() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CreateSupportQuerySheet(),
    );
    if (created == null || !mounted) return;
    await _loadQueries(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Support query submitted')),
    );
  }

  Future<void> _showQueryDetails(Map<String, dynamic> query) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SupportQueryChatScreen(queryId: _queryId(query)),
      ),
    );
  }

  Future<void> _deleteQuery(Map<String, dynamic> query) async {
    final id = _queryId(query);
    if (id.isEmpty) return;
    final subject = (query['subject'] ?? 'this query').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete query?'),
          content: Text(
            'Delete "$subject"? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    try {
      await _supportQueriesApi.deleteMySupportQuery(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Query deleted successfully')),
      );
      await _loadQueries();
    } catch (e, st) {
      AppErrorHandler.logError('support-query-delete', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorHandler.userMessage(e))),
      );
    }
  }

  String _queryId(Map<String, dynamic> query) {
    return (query['_id'] ?? query['id'] ?? query['queryId'] ?? query['query_id'])
        .toString()
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final queries = _filteredQueries();
    final openCount = _queries.where((q) => _status(q) == 'open').length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Contact Support'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'New support query',
            icon: const Icon(LucideIcons.plus),
            onPressed: _openCreateQuerySheet,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadQueries(showLoading: false),
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 240),
                  Center(
                    child: CircularProgressIndicator(
                      color: DesignTokens.instaPink,
                    ),
                  ),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      const SizedBox(height: 48),
                      const Icon(
                        LucideIcons.circleAlert,
                        color: Colors.redAccent,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () => _loadQueries(),
                          icon: const Icon(LucideIcons.refreshCw, size: 16),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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
                          children: [
                            Icon(
                              LucideIcons.search,
                              size: 18,
                              color:
                                  theme.iconTheme.color?.withValues(alpha: 0.72),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search queries',
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                            if (_searchController.text.trim().isNotEmpty)
                              InkWell(
                                onTap: _searchController.clear,
                                borderRadius: BorderRadius.circular(999),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(LucideIcons.x, size: 16),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: _statusFilter == 'all',
                              onTap: () {
                                setState(() => _statusFilter = 'all');
                                unawaited(_loadQueries());
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Open',
                              selected: _statusFilter == 'open',
                              badgeCount: openCount,
                              onTap: () {
                                setState(() => _statusFilter = 'open');
                                unawaited(_loadQueries());
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'In Progress',
                              selected: _statusFilter == 'in_progress',
                              onTap: () {
                                setState(() => _statusFilter = 'in_progress');
                                unawaited(_loadQueries());
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Resolved',
                              selected: _statusFilter == 'resolved',
                              onTap: () {
                                setState(() => _statusFilter = 'resolved');
                                unawaited(_loadQueries());
                              },
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Closed',
                              selected: _statusFilter == 'closed',
                              onTap: () {
                                setState(() => _statusFilter = 'closed');
                                unawaited(_loadQueries());
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'My Queries',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (queries.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color:
                                isDark ? const Color(0xFF111827) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.06),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                LucideIcons.messageSquare,
                                size: 36,
                                color: DesignTokens.instaPink,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _statusFilter == 'all'
                                    ? 'No support queries yet'
                                    : 'No ${_statusFilter.replaceAll('_', ' ')} queries',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap + to submit a new support request.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...queries.map(
                          (query) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SupportQueryTile(
                              query: query,
                              onTap: () => _showQueryDetails(query),
                              onLongPress: () => _deleteQuery(query),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? DesignTokens.instaPink : theme.cardColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: (theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black)
                .withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    selected ? Colors.white : theme.textTheme.bodyMedium?.color,
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFF43F5E),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeCount! > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SupportQueryTile extends StatelessWidget {
  final Map<String, dynamic> query;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SupportQueryTile({
    required this.query,
    required this.onTap,
    required this.onLongPress,
  });

  String _status(Map<String, dynamic> query) {
    return (query['status'] ?? '').toString().trim().toLowerCase();
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return value.isEmpty ? 'Open' : value;
    }
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'open':
        return const Color(0xFFEA580C);
      case 'in_progress':
        return const Color(0xFF2563EB);
      case 'resolved':
        return const Color(0xFF16A34A);
      case 'closed':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFFEA580C);
    }
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    if (now.difference(dt).inDays >= 1) {
      return '${dt.month}/${dt.day}';
    }
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _categoryLabel(String value) {
    switch (value.trim().toLowerCase()) {
      case 'payment':
        return 'Payment';
      case 'account':
        return 'Account';
      case 'technical':
        return 'Technical';
      case 'billing':
        return 'Billing';
      case 'other':
        return 'Other';
      default:
        return value.isEmpty ? 'Other' : value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final status = _status(query);
    final subject = (query['subject'] ?? '').toString().trim();
    final message = (query['message'] ?? '').toString().trim();
    final category = (query['category'] ?? '').toString().trim();
    final replies = query['replies'];
    final replyCount = replies is List ? replies.length : 0;

    return Material(
      color: isDark ? const Color(0xFF111827) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.isEmpty ? 'Support query' : subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(query['createdAt']?.toString()),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _preview(message),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color ?? Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TagChip(
                    label: _categoryLabel(category),
                    color: DesignTokens.instaPink,
                  ),
                  _TagChip(
                    label: _statusLabel(status),
                    color: _statusColor(status),
                  ),
                  _TagChip(
                    label: '$replyCount reply${replyCount == 1 ? '' : 'ies'}',
                    color: const Color(0xFF2563EB),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _preview(String message) {
    if (message.isEmpty) return 'No message';
    if (message.length <= 110) return message;
    return '${message.substring(0, 107)}...';
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SupportQueryChatScreen extends StatefulWidget {
  final String queryId;

  const _SupportQueryChatScreen({
    required this.queryId,
  });

  @override
  State<_SupportQueryChatScreen> createState() =>
      _SupportQueryChatScreenState();
}

class _SupportQueryChatScreenState extends State<_SupportQueryChatScreen> {
  final SupportQueriesApi _supportQueriesApi = SupportQueriesApi();
  final TextEditingController _replyController = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Map<String, dynamic>? _query;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  String _status(String value) {
    switch (value.trim().toLowerCase()) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return value.isEmpty ? 'Open' : value;
    }
  }

  String _category(String value) {
    switch (value.trim().toLowerCase()) {
      case 'payment':
        return 'Payment';
      case 'account':
        return 'Account';
      case 'technical':
        return 'Technical';
      case 'billing':
        return 'Billing';
      case 'other':
        return 'Other';
      default:
        return value.isEmpty ? 'Other' : value;
    }
  }

  String _time(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    if (now.difference(dt).inDays >= 1) {
      return '${dt.month}/${dt.day}';
    }
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _senderName(Map<String, dynamic> reply) {
    final senderType = (reply['sender_type'] ?? '').toString().toLowerCase();
    final sender = reply['sender_id'];
    if (sender is Map) {
      final map = Map<String, dynamic>.from(sender);
      final name = (map['full_name'] ?? map['name'] ?? map['username'])
          ?.toString()
          .trim();
      if (name != null && name.isNotEmpty) return name;
    }
    if (senderType == 'admin') return 'Support';
    return 'You';
  }

  String _senderInitial(Map<String, dynamic> reply) {
    final name = _senderName(reply).trim();
    if (name.isEmpty) return 'S';
    return name.characters.first.toUpperCase();
  }

  bool get _isClosed =>
      (_query?['status'] ?? '').toString().trim().toLowerCase() == 'closed';

  List<Map<String, dynamic>> _threadEntries() {
    final entries = <Map<String, dynamic>>[];
    final query = _query;
    if (query != null) {
      final body = (query['message'] ?? '').toString().trim();
      if (body.isNotEmpty) {
        entries.add(<String, dynamic>{
          'message': body,
          'createdAt': query['createdAt'],
          'sender_type': 'user',
          'sender_id': <String, dynamic>{
            'full_name': 'You',
            'username': 'You',
          },
        });
      }
    }

    final replies = query?['replies'];
    if (replies is List) {
      entries.addAll(
        replies
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e)),
      );
    }

    return entries;
  }

  Widget _buildThreadBubble(
    Map<String, dynamic> reply,
    ThemeData theme,
    bool isDark,
  ) {
    final body = (reply['message'] ?? reply['text'] ?? '').toString().trim();
    final senderName = _senderName(reply);
    final senderType = (reply['sender_type'] ?? '').toString().toLowerCase();
    final mine = senderType == 'user';
    final alignment = mine ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = mine
        ? DesignTokens.instaPink.withValues(alpha: 0.14)
        : isDark
            ? const Color(0xFF111827)
            : const Color(0xFFF8FAFC);
    final textColor = theme.colorScheme.onSurface;
    final accentColor = mine ? DesignTokens.instaPink : const Color(0xFF2563EB);

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine) ...[
              CircleAvatar(
                radius: 15,
                backgroundColor: accentColor,
                child: Text(
                  _senderInitial(reply),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 6),
                    bottomRight: Radius.circular(mine ? 6 : 18),
                  ),
                  border: Border.all(
                    color: (mine ? DesignTokens.instaPink : Colors.black)
                        .withValues(alpha: mine ? 0.10 : 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.14 : 0.04,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          senderName,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                            fontSize: 12,
                          ),
                        ),
                        if (!mine) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Support',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body.isEmpty ? 'Reply' : body,
                      style: TextStyle(
                        color: textColor,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _time(reply['createdAt']?.toString()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (mine) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 15,
                backgroundColor: accentColor,
                child: Text(
                  _senderInitial(reply),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context, ThemeData theme, bool isDark) {
    if (_isClosed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'This query is closed, so replies are disabled.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendReply(),
                  decoration: const InputDecoration(
                    hintText: 'Write a reply...',
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: DesignTokens.instaGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _sending ? null : _sendReply,
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Center(
                        child: _sending
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                LucideIcons.send,
                                color: Colors.white,
                                size: 18,
                              ),
                      ),
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

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty || _sending || _isClosed) return;
    setState(() => _sending = true);
    try {
      await _supportQueriesApi.replyToMySupportQuery(
        id: widget.queryId,
        message: message,
      );
      _replyController.clear();
      await _load();
    } catch (e, st) {
      AppErrorHandler.logError('support-query-reply', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorHandler.userMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _supportQueriesApi.getMySupportQuery(widget.queryId);
      if (!mounted) return;
      setState(() => _query = data);
    } catch (e, st) {
      AppErrorHandler.logError('support-query-details', e, st);
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to load support query details right now.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final query = _query;
    final subject = (query?['subject'] ?? '').toString().trim();
    final category = (query?['category'] ?? '').toString().trim();
    final status = (query?['status'] ?? '').toString().trim();
    final threadEntries = _threadEntries();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject.isEmpty ? 'Support chat' : subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (category.isNotEmpty || status.isNotEmpty)
              Text(
                [
                  if (category.isNotEmpty) _category(category),
                  if (status.isNotEmpty) _status(status),
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(LucideIcons.refreshCw),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: DesignTokens.instaPink,
                ),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          itemCount: threadEntries.isEmpty ? 1 : threadEntries.length,
                          separatorBuilder: (_, __) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 56),
                            child: Divider(
                              height: 24,
                              thickness: 1,
                              color: theme.dividerColor.withValues(
                                alpha: isDark ? 0.35 : 0.85,
                              ),
                            ),
                          ),
                          itemBuilder: (context, index) {
                            if (threadEntries.isEmpty) {
                              return Text(
                                'No messages yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              );
                            }
                            return _buildThreadBubble(
                              threadEntries[index],
                              theme,
                              isDark,
                            );
                          },
                        ),
                      ),
                      _buildComposer(context, theme, isDark),
                    ],
                  ),
      ),
    );
  }
}

class _CreateSupportQuerySheet extends StatefulWidget {
  const _CreateSupportQuerySheet();

  @override
  State<_CreateSupportQuerySheet> createState() =>
      _CreateSupportQuerySheetState();
}

class _CreateSupportQuerySheetState extends State<_CreateSupportQuerySheet> {
  final _formKey = GlobalKey<FormState>();
  final _supportQueriesApi = SupportQueriesApi();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  String _category = 'payment';
  bool _submitting = false;

  static const Map<String, String> _categories = <String, String>{
    'payment': 'Payment',
    'account': 'Account',
    'technical': 'Technical',
    'billing': 'Billing',
    'other': 'Other',
  };

  InputDecoration _fieldDecoration(
    ThemeData theme, {
    required String label,
    required String hint,
    bool multiline = false,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = (isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.09);
    final fillColor = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: fillColor,
      alignLabelWithHint: multiline,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: multiline ? 16 : 14,
      ),
      labelStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: DesignTokens.instaPink,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade400, width: 1.4),
      ),
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _submitting) return;
    setState(() => _submitting = true);
    try {
      final query = await _supportQueriesApi.submitSupportQuery(
        subject: _subjectController.text,
        message: _messageController.text,
        category: _category,
      );
      if (!mounted) return;
      Navigator.of(context).pop(query);
    } catch (e, st) {
      AppErrorHandler.logError('support-query-submit', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorHandler.userMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.62,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1220) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'New support query',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(LucideIcons.x),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        Text(
                          'Tell us what happened',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pick a category, then describe the issue and submit the ticket.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF111827)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  gradient: DesignTokens.instaGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  LucideIcons.tags,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _category,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  icon: Icon(
                                    LucideIcons.chevronDown,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  items: _categories.entries
                                      .map(
                                        (entry) => DropdownMenuItem<String>(
                                          value: entry.key,
                                          child: Text(entry.value),
                                        ),
                                      )
                                      .toList(),
                                  selectedItemBuilder: (context) {
                                    return _categories.entries.map((entry) {
                                      return Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          entry.value,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      );
                                    }).toList();
                                  },
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() => _category = value);
                                  },
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Category is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _subjectController,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          decoration: _fieldDecoration(
                            theme,
                            label: 'Subject',
                            hint: 'Payment not received',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Subject is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _messageController,
                          minLines: 5,
                          maxLines: 8,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          decoration: _fieldDecoration(
                            theme,
                            label: 'Message',
                            hint:
                                'I made a payment 2 days ago but it is not reflecting in my wallet.',
                            multiline: true,
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Message is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        Container(
                          decoration: BoxDecoration(
                            gradient: DesignTokens.instaGradient,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: DesignTokens.instaPink
                                    .withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _submitting ? null : _submit,
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: Center(
                                  child: _submitting
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Submit query',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This will send a support ticket with app_source set to bsmart.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
