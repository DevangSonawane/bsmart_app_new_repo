import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth_api.dart';
import '../api/chat_api.dart';
import '../api/follow_requests_api.dart';
import '../models/notification_model.dart';
import 'chat_conversation_screen.dart';
import 'contact_support_screen.dart';
import 'messaging_screen.dart';
import '../services/notification_service.dart';
import '../utils/timezone_service.dart';
import 'follow_requests_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final FollowRequestsApi _followRequestsApi = FollowRequestsApi();
  List<NotificationItem> _notifications = const [];
  bool _isLoading = true;
  String? _error;
  int _unreadCount = 0;
  int _followRequestsCount = 0;
  bool _isPrivateAccount = false;
  bool _followRequestsLoading = false;
  int _page = 1;
  int _total = 0;
  String _activeTab = 'all';
  bool _markingAll = false;
  bool _isVendor = false;
  final Map<String, String> _followRequestActionState = <String, String>{};
  StreamSubscription<List<NotificationItem>>? _notificationSub;
  Timer? _pollTimer;
  final String _wsStatus = 'polling';

  static const int _limit = 15;

  @override
  void initState() {
    super.initState();
    _notificationSub = _notificationService.getNotificationsStream().listen(
      (_) {
        if (!mounted) return;
        unawaited(_loadNotifications(force: false, showLoading: false));
      },
    );
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _notificationSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadRole();
    await _loadNotifications();
    unawaited(_loadFollowRequestsCount());
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadNotifications(force: true);
      _loadFollowRequestsCount();
    });
  }

  Future<void> _loadFollowRequestsCount() async {
    if (_followRequestsLoading) return;
    setState(() => _followRequestsLoading = true);
    try {
      final status = await _followRequestsApi.getPrivacyStatus();
      if (status != null) {
        if (!mounted) return;
        setState(() => _followRequestsCount = status.pendingRequestsCount);
        setState(() => _isPrivateAccount = status.isPrivate);
        return;
      }

      final page = await _followRequestsApi.getFollowRequests();
      if (!mounted) return;
      setState(() => _followRequestsCount = page.count);
    } catch (_) {
      // ignore; keep previous count
    } finally {
      if (mounted) setState(() => _followRequestsLoading = false);
    }
  }

  Future<void> _loadRole() async {
    try {
      final me = await AuthApi().me();
      final role = (me['role'] ?? '').toString().toLowerCase();
      if (!mounted) return;
      setState(() {
        _isVendor = role == 'vendor';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVendor = false;
      });
    }
  }

  Future<void> _loadNotifications({
    bool force = true,
    bool showLoading = true,
  }) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }

    try {
      final page = await _notificationService.getNotifications(
        forceRefresh: force,
        page: _page,
        limit: _limit,
        typeFilter: _activeTab,
      );
      final unreadCount = await _notificationService.getUnreadCount();
      if (!mounted) return;
      setState(() {
        _notifications = page.items;
        _total = page.total;
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load notifications';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
  }

  Future<void> _markAllAsRead() async {
    setState(() => _markingAll = true);
    await _notificationService.markAllAsRead();
    if (mounted) setState(() => _markingAll = false);
  }

  Future<void> _deleteNotification(String notificationId) async {
    await _notificationService.deleteNotification(notificationId);
  }

  bool _isMessageNotification(NotificationItem notification) {
    final type = notification.typeKey.trim().toLowerCase();
    return type.contains('message') ||
        type.contains('chat') ||
        type.contains('dm');
  }

  bool _isSupportNotification(NotificationItem notification) {
    final type = notification.typeKey.trim().toLowerCase();
    if (type.contains('support') ||
        type.contains('help') ||
        type.contains('query')) {
      return true;
    }
    final metadata = notification.metadata ?? const <String, dynamic>{};
    final hasSupportQueryId = _stringFromMap(metadata, const [
      'queryId',
      'query_id',
      'supportQueryId',
      'support_query_id',
      'supportTicketId',
      'support_ticket_id',
    ]);
    if (hasSupportQueryId.isNotEmpty) return true;
    final link = notification.link?.trim() ?? '';
    return link.contains('contact-support') || link.contains('support');
  }

  String _stringFromMap(
    Map<String, dynamic>? map,
    List<String> keys,
  ) {
    if (map == null) return '';
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _conversationIdFromNotification(NotificationItem notification) {
    return _stringFromMap(notification.metadata, const [
      'conversationId',
      'conversation_id',
      'chatId',
      'chat_id',
      'threadId',
      'thread_id',
      'messageThreadId',
      'message_thread_id',
    ]);
  }

  String _supportQueryIdFromNotification(NotificationItem notification) {
    final fromMetadata = _stringFromMap(notification.metadata, const [
      'queryId',
      'query_id',
      'supportQueryId',
      'support_query_id',
      'supportTicketId',
      'support_ticket_id',
      'threadId',
      'thread_id',
      'conversationId',
      'conversation_id',
      'relatedId',
      'related_id',
    ]);
    if (fromMetadata.isNotEmpty) return fromMetadata;

    final relatedId = notification.relatedId?.trim() ?? '';
    if (relatedId.isNotEmpty) return relatedId;

    final link = notification.link?.trim() ?? '';
    if (link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      final lastSegment = uri != null && uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last.trim()
          : '';
      if (lastSegment.isNotEmpty) return lastSegment;
    }

    return '';
  }

  String _participantIdFromNotification(NotificationItem notification) {
    final sender = notification.sender ?? const <String, dynamic>{};
    final fromSender = _stringFromMap(sender, const [
      '_id',
      'id',
      'user_id',
      'userId',
    ]);
    if (fromSender.isNotEmpty) return fromSender;

    final fromMetadata = _stringFromMap(notification.metadata, const [
      'participantId',
      'participant_id',
      'senderId',
      'sender_id',
      'fromUserId',
      'from_user_id',
      'userId',
      'user_id',
    ]);
    if (fromMetadata.isNotEmpty) return fromMetadata;

    return notification.relatedId?.trim() ?? '';
  }

  Future<void> _openMessageNotification(NotificationItem notification) async {
    final conversationId = _conversationIdFromNotification(notification);
    if (conversationId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            conversationId: conversationId,
          ),
        ),
      );
      return;
    }

    final participantId = _participantIdFromNotification(notification);
    if (participantId.isNotEmpty) {
      try {
        final conversation = await ChatApi()
            .createOrGetConversation(participantId: participantId);
        if (!mounted) return;
        final id =
            (conversation['_id'] ?? conversation['id'])?.toString().trim() ??
                '';
        if (id.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatConversationScreen(
                conversationId: id,
                initialConversation: Map<String, dynamic>.from(conversation),
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // Fall through to the messaging inbox below.
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MessagingScreen()),
    );
  }

  Future<void> _openSupportNotification(NotificationItem notification) async {
    final queryId = _supportQueryIdFromNotification(notification);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactSupportScreen(
            initialQueryId: queryId.isEmpty ? null : queryId),
      ),
    );
  }

  String _requesterIdOf(NotificationItem notification) {
    final sender = notification.sender ?? const <String, dynamic>{};
    final fromSender =
        (sender['_id'] ?? sender['id'] ?? sender['user_id'])?.toString().trim();
    if (fromSender != null && fromSender.isNotEmpty) return fromSender;
    return notification.relatedId?.trim() ?? '';
  }

  Future<void> _handleFollowRequestDecision(
    NotificationItem notification,
    String decision,
  ) async {
    final notificationId = notification.id.trim();
    final requesterId = _requesterIdOf(notification);
    if (notificationId.isEmpty || requesterId.isEmpty) return;
    if (_followRequestActionState.containsKey(notificationId)) return;
    setState(() => _followRequestActionState[notificationId] = decision);
    try {
      if (decision == 'accept') {
        await _followRequestsApi.acceptFollowRequest(requesterId);
      } else {
        await _followRequestsApi.declineFollowRequest(requesterId);
      }
      await _deleteNotification(notificationId);
      if (!mounted) return;
      await _loadNotifications(force: false, showLoading: false);
      await _loadFollowRequestsCount();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'accept'
                ? 'Failed to accept follow request.'
                : 'Failed to decline follow request.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _followRequestActionState.remove(notificationId));
      }
    }
  }

  void _handleTabChange(String tab) {
    setState(() {
      _activeTab = tab;
      _page = 1;
    });
    _loadNotifications();
  }

  Future<void> _handleNotificationTap(NotificationItem notification) async {
    if (!notification.isRead) {
      await _markAsRead(notification.id);
    }
    if (!mounted) return;

    if (_isMessageNotification(notification)) {
      await _openMessageNotification(notification);
      return;
    }

    if (_isSupportNotification(notification)) {
      await _openSupportNotification(notification);
      return;
    }

    final link = notification.link?.trim();
    if (link != null && link.isNotEmpty) {
      Navigator.of(context).pushNamed(link);
      return;
    }

    final relatedId = notification.relatedId?.trim();
    if (relatedId != null && relatedId.isNotEmpty) {
      if (notification.typeKey.contains('reel')) {
        Navigator.of(context)
            .pushNamed('/reels', arguments: {'initialReelId': relatedId});
        return;
      }
      if (notification.typeKey.contains('post')) {
        Navigator.of(context).pushNamed('/post/$relatedId');
        return;
      }
      if (notification.typeKey.contains('ad')) {
        Navigator.of(context).pushNamed('/ad/$relatedId');
        return;
      }
    }
  }

  _TypeConfig _getTypeConfig(String typeKey) {
    if (_isVendor) return _vendorTypeConfig[typeKey] ?? _vendorFallback;
    return _memberTypeConfig[typeKey] ?? _memberFallback;
  }

  List<_TabItem> _tabs() {
    if (_isVendor) {
      return const [
        _TabItem('all', 'All'),
        _TabItem('unread', 'Unread', emoji: '🔵'),
        _TabItem('ad_approved', 'Approvals', emoji: '✅'),
        _TabItem('ad_rejected', 'Rejections', emoji: '❌'),
        _TabItem('ad_like', 'Engagement', emoji: '❤️'),
        _TabItem('wallet_credit', 'Credits', emoji: '💰'),
        _TabItem('ad_spend', 'Spend', emoji: '💸'),
      ];
    }
    return const [
      _TabItem('all', 'All'),
      _TabItem('unread', 'Unread'),
      _TabItem('like', '❤️ Likes'),
      _TabItem('comment', '💬 Comments'),
      _TabItem('follow', '👤 Follows'),
      _TabItem('mention', '@ Mentions'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_total / _limit).ceil();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _page = 1);
            await _loadNotifications(force: true);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _buildHeader(isDark),
              ),
              const SizedBox(height: 14),
              if (_isPrivateAccount)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildFollowRequestsTile(isDark),
                ),
              const SizedBox(height: 16),
              _buildTabs(isDark),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildCard(isDark, totalPages),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowRequestsTile(bool isDark) {
    final theme = Theme.of(context);
    final border =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08);
    final bg = isDark ? const Color(0xFF111827) : Colors.white;
    final secondary = theme.colorScheme.onSurfaceVariant
        .withValues(alpha: isDark ? 0.9 : 1.0);
    final count = _followRequestsCount;

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FollowRequestsScreen()),
        );
        if (!mounted) return;
        unawaited(_loadFollowRequestsCount());
        unawaited(_loadNotifications(force: true));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
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
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                ),
              ),
              child: const Icon(
                LucideIcons.userPlus,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Follow requests',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _followRequestsLoading
                        ? 'Checking…'
                        : (count == 0
                            ? 'No pending requests'
                            : '$count pending'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0 && !_followRequestsLoading)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final title = _isVendor ? 'Vendor Notifications' : 'Notifications';
    final iconBg = _isVendor
        ? const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: iconBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            _isVendor ? LucideIcons.megaphone : LucideIcons.bell,
            color: Colors.white,
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
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (_isVendor)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Vendor',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$_unreadCount unread',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB)),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _WsIndicator(status: _wsStatus),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            if (_unreadCount > 0)
              TextButton.icon(
                onPressed: _markingAll ? null : _markAllAsRead,
                icon: _markingAll
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.checkCheck, size: 14),
                label: const Text('Mark all read'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _isVendor
                      ? const Color(0xFFF97316)
                      : const Color(0xFF2563EB),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _tabs().map((tab) {
            final active = _activeTab == tab.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _handleTabChange(tab.key),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: active
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark ? const Color(0xFF1F2937) : Colors.white),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active
                          ? Colors.transparent
                          : (isDark
                              ? const Color(0xFF374151)
                              : const Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Text(
                    '${tab.emoji ?? ''}${tab.emoji != null ? ' ' : ''}${tab.label}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, int totalPages) {
    final dividerColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06);

    return Column(
      children: [
        Container(height: 1, color: dividerColor),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Icon(LucideIcons.circleAlert, color: Colors.redAccent),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadNotifications,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_notifications.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _isVendor ? LucideIcons.megaphone : LucideIcons.bell,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                if (_activeTab != 'all')
                  TextButton(
                    onPressed: () => _handleTabChange('all'),
                    child: const Text('View all'),
                  ),
              ],
            ),
          )
        else
          Column(
            children: _notifications
                .map(
                  (n) => _NotificationRow(
                    notification: n,
                    config: _getTypeConfig(n.typeKey),
                    onTap: () => _handleNotificationTap(n),
                    onDelete: () => _deleteNotification(n.id),
                    onMarkRead: n.isRead ? null : () => _markAsRead(n.id),
                    onFollowDecision: (n.typeKey == 'follow_request')
                        ? (decision) =>
                            _handleFollowRequestDecision(n, decision)
                        : null,
                    followRequestActionState:
                        _followRequestActionState[n.id.trim()],
                  ),
                )
                .toList(),
          ),
        if (totalPages > 1 && !_isLoading)
          _PaginationBar(
            page: _page,
            totalPages: totalPages,
            total: _total,
            onPrev: _page == 1 ? null : () => _setPage(_page - 1),
            onNext: _page == totalPages ? null : () => _setPage(_page + 1),
            onSelect: (p) => _setPage(p),
          ),
      ],
    );
  }

  void _setPage(int page) {
    setState(() => _page = page);
    _loadNotifications();
  }
}

class _NotificationRow extends StatelessWidget {
  final NotificationItem notification;
  final _TypeConfig config;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onMarkRead;
  final void Function(String decision)? onFollowDecision;
  final String? followRequestActionState;

  const _NotificationRow({
    required this.notification,
    required this.config,
    required this.onTap,
    required this.onDelete,
    required this.onMarkRead,
    required this.onFollowDecision,
    required this.followRequestActionState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUnread = !notification.isRead;
    final sender = notification.sender ?? const <String, dynamic>{};
    final name =
        (sender['full_name'] ?? sender['username'] ?? 'Someone').toString();
    final avatar = sender['avatar_url']?.toString();
    final isFollowRequest = notification.typeKey == 'follow_request';
    final isActing = followRequestActionState != null;
    final thumbnailUrl = (notification.metadata?['thumbnail_url'] ??
            notification.metadata?['thumbnailUrl'] ??
            notification.metadata?['image_url'] ??
            notification.metadata?['imageUrl'] ??
            notification.metadata?['media_url'] ??
            notification.metadata?['mediaUrl'])
        ?.toString();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark ? const Color(0xFF0B2239) : const Color(0xFFEFF6FF))
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(right: 6),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 8),
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: avatar != null && avatar.isNotEmpty
                      ? NetworkImage(avatar)
                      : null,
                  child: avatar == null || avatar.isEmpty
                      ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U')
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: config.bgColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF0B0B0F) : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(config.icon, size: 11, color: config.iconColor),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message.isNotEmpty
                        ? notification.message
                        : notification.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                      color: isDark
                          ? Colors.white
                          : (isUnread ? Colors.black : Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: config.bgColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          config.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: config.iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(notification.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (notification.metadata?['adTitle'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '📢 ${notification.metadata?['adTitle']}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFF97316)),
                      ),
                    ),
                  if (isFollowRequest) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            onPressed: isActing
                                ? null
                                : () => onFollowDecision?.call('accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child:
                                isActing && followRequestActionState == 'accept'
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Confirm'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 30,
                          child: ElevatedButton(
                            onPressed: isActing
                                ? null
                                : () => onFollowDecision?.call('decline'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? const Color(0xFF1F2937)
                                  : const Color(0xFFF3F4F6),
                              foregroundColor:
                                  isDark ? Colors.white : Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isActing &&
                                    followRequestActionState == 'decline'
                                ? SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  )
                                : const Text('Delete'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isFollowRequest)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          thumbnailUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (onMarkRead != null)
                    IconButton(
                      onPressed: onMarkRead,
                      icon: const Icon(
                        LucideIcons.checkCheck,
                        size: 18,
                        color: Color(0xFF3B82F6),
                      ),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      splashRadius: 20,
                    ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(
                      LucideIcons.trash2,
                      size: 18,
                      color: Color(0xFFF87171),
                    ),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    splashRadius: 20,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WsIndicator extends StatelessWidget {
  final String status;
  const _WsIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'open') {
      return const Text('Live',
          style: TextStyle(
              fontSize: 10,
              color: Color(0xFF16A34A),
              fontWeight: FontWeight.w700));
    }
    if (status == 'polling') {
      return const Text('Polling',
          style: TextStyle(
              fontSize: 10,
              color: Color(0xFFF59E0B),
              fontWeight: FontWeight.w700));
    }
    return const Text('Connecting…',
        style: TextStyle(
            fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700));
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final void Function(int page) onSelect;

  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final pages = _pageNumbers(page, totalPages);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Page $page of $totalPages · $total total',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Row(
            children: [
              IconButton(
                onPressed: onPrev,
                icon: const Icon(LucideIcons.chevronLeft, size: 16),
              ),
              ...pages.map((p) {
                final active = p == page;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => onSelect(p),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? Colors.black : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              IconButton(
                onPressed: onNext,
                icon: const Icon(LucideIcons.chevronRight, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static List<int> _pageNumbers(int page, int total) {
    final width = total < 5 ? total : 5;
    int start = page - (width ~/ 2);
    if (start < 1) start = 1;
    int end = start + width - 1;
    if (end > total) {
      end = total;
      start = (end - width + 1).clamp(1, end);
    }
    return [for (int i = start; i <= end; i++) i];
  }
}

class _TabItem {
  final String key;
  final String label;
  final String? emoji;
  const _TabItem(this.key, this.label, {this.emoji});
}

class _TypeConfig {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final String label;

  const _TypeConfig({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.label,
  });
}

const _memberFallback = _TypeConfig(
  icon: LucideIcons.bell,
  bgColor: Color(0xFFF3F4F6),
  iconColor: Color(0xFF9CA3AF),
  label: 'Notification',
);

const _vendorFallback = _TypeConfig(
  icon: LucideIcons.bell,
  bgColor: Color(0xFFF3F4F6),
  iconColor: Color(0xFF9CA3AF),
  label: 'Notification',
);

const _memberTypeConfig = {
  'like': _TypeConfig(
    icon: LucideIcons.heart,
    bgColor: Color(0xFFFCE7F3),
    iconColor: Color(0xFFEC4899),
    label: 'Like',
  ),
  'comment': _TypeConfig(
    icon: LucideIcons.messageCircle,
    bgColor: Color(0xFFFFEDD5),
    iconColor: Color(0xFFF97316),
    label: 'Comment',
  ),
  'follow': _TypeConfig(
    icon: LucideIcons.userPlus,
    bgColor: Color(0xFFDBEAFE),
    iconColor: Color(0xFF3B82F6),
    label: 'Follow',
  ),
  'mention': _TypeConfig(
    icon: LucideIcons.atSign,
    bgColor: Color(0xFFEDE9FE),
    iconColor: Color(0xFF8B5CF6),
    label: 'Mention',
  ),
  'save': _TypeConfig(
    icon: LucideIcons.bookmark,
    bgColor: Color(0xFFCCFBF1),
    iconColor: Color(0xFF0F766E),
    label: 'Save',
  ),
  'reward': _TypeConfig(
    icon: LucideIcons.star,
    bgColor: Color(0xFFFEF3C7),
    iconColor: Color(0xFFF59E0B),
    label: 'Reward',
  ),
  'ad': _TypeConfig(
    icon: LucideIcons.megaphone,
    bgColor: Color(0xFFEFF6FF),
    iconColor: Color(0xFF2563EB),
    label: 'Spotlights',
  ),
  'post_posted': _TypeConfig(
    icon: LucideIcons.image,
    bgColor: Color(0xFFECFDF5),
    iconColor: Color(0xFF16A34A),
    label: 'Moments',
  ),
  'reel_posted': _TypeConfig(
    icon: LucideIcons.video,
    bgColor: Color(0xFFFDF2F8),
    iconColor: Color(0xFFEC4899),
    label: 'bSparks',
  ),
};

const _vendorTypeConfig = {
  'ad_approved': _TypeConfig(
    icon: LucideIcons.badgeCheck,
    bgColor: Color(0xFFDCFCE7),
    iconColor: Color(0xFF16A34A),
    label: 'Spotlights Approved',
  ),
  'ad_rejected': _TypeConfig(
    icon: LucideIcons.circleX,
    bgColor: Color(0xFFFEE2E2),
    iconColor: Color(0xFFDC2626),
    label: 'Spotlights Rejected',
  ),
  'ad_submitted': _TypeConfig(
    icon: LucideIcons.megaphone,
    bgColor: Color(0xFFDBEAFE),
    iconColor: Color(0xFF3B82F6),
    label: 'Spotlights Submitted',
  ),
  'ad_expired': _TypeConfig(
    icon: LucideIcons.circleX,
    bgColor: Color(0xFFF3F4F6),
    iconColor: Color(0xFF6B7280),
    label: 'Spotlights Expired',
  ),
  'ad_like': _TypeConfig(
    icon: LucideIcons.heart,
    bgColor: Color(0xFFFCE7F3),
    iconColor: Color(0xFFEC4899),
    label: 'Spotlights Like',
  ),
  'ad_comment': _TypeConfig(
    icon: LucideIcons.messageCircle,
    bgColor: Color(0xFFFFEDD5),
    iconColor: Color(0xFFF97316),
    label: 'Spotlights Comment',
  ),
  'ad_view': _TypeConfig(
    icon: LucideIcons.target,
    bgColor: Color(0xFFE0F2FE),
    iconColor: Color(0xFF0EA5E9),
    label: 'Spotlights View',
  ),
  'wallet_credit': _TypeConfig(
    icon: LucideIcons.trendingUp,
    bgColor: Color(0xFFDCFCE7),
    iconColor: Color(0xFF16A34A),
    label: 'Vault Credit',
  ),
  'wallet_debit': _TypeConfig(
    icon: LucideIcons.trendingDown,
    bgColor: Color(0xFFFEE2E2),
    iconColor: Color(0xFFDC2626),
    label: 'Vault Debit',
  ),
  'ad_spend': _TypeConfig(
    icon: LucideIcons.receipt,
    bgColor: Color(0xFFFEF3C7),
    iconColor: Color(0xFFF59E0B),
    label: 'Spotlights Spend',
  ),
  'post_posted': _TypeConfig(
    icon: LucideIcons.image,
    bgColor: Color(0xFFECFDF5),
    iconColor: Color(0xFF16A34A),
    label: 'Moments',
  ),
  'reel_posted': _TypeConfig(
    icon: LucideIcons.video,
    bgColor: Color(0xFFFDF2F8),
    iconColor: Color(0xFFEC4899),
    label: 'bSparks',
  ),
  'refund': _TypeConfig(
    icon: LucideIcons.wallet,
    bgColor: Color(0xFFCCFBF1),
    iconColor: Color(0xFF0F766E),
    label: 'Refund',
  ),
  'campaign': _TypeConfig(
    icon: LucideIcons.zap,
    bgColor: Color(0xFFEDE9FE),
    iconColor: Color(0xFF8B5CF6),
    label: 'Campaigns',
  ),
  'follow': _TypeConfig(
    icon: LucideIcons.userPlus,
    bgColor: Color(0xFFDBEAFE),
    iconColor: Color(0xFF3B82F6),
    label: 'Follow',
  ),
};

String _timeAgo(DateTime date) {
  return TimezoneService.instance.relativeTime(date);
}
