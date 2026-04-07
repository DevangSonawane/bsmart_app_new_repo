import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth_api.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationItem> _notifications = const [];
  bool _isLoading = true;
  String? _error;
  int _unreadCount = 0;
  int _page = 1;
  int _total = 0;
  String _activeTab = 'all';
  bool _markingAll = false;
  bool _isVendor = false;
  Timer? _pollTimer;
  String _wsStatus = 'polling';

  static const int _limit = 15;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadRole();
    await _loadNotifications();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadNotifications(force: true);
    });
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

  Future<void> _loadNotifications({bool force = true}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

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
    await _loadNotifications();
  }

  Future<void> _markAllAsRead() async {
    setState(() => _markingAll = true);
    await _notificationService.markAllAsRead();
    await _loadNotifications();
    if (mounted) setState(() => _markingAll = false);
  }

  Future<void> _deleteNotification(String notificationId) async {
    await _notificationService.deleteNotification(notificationId);
    await _loadNotifications();
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

    final link = notification.link?.trim();
    if (link != null && link.isNotEmpty) {
      Navigator.of(context).pushNamed(link);
      return;
    }

    final relatedId = notification.relatedId?.trim();
    if (relatedId != null && relatedId.isNotEmpty) {
      if (notification.typeKey.contains('reel')) {
        Navigator.of(context).pushNamed('/reels',
            arguments: {'initialReelId': relatedId});
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
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7FA),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _page = 1);
            await _loadNotifications(force: true);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                      child: _buildHeader(isDark),
                    ),
                    const SizedBox(height: 16),
                    _buildTabs(isDark),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: _buildCard(isDark, totalPages),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          tooltip: 'Back',
        ),
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
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (_isVendor)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabs(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _tabs().map((tab) {
          final active = _activeTab == tab.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _handleTabChange(tab.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? (isDark ? Colors.white : Colors.black)
                      : (isDark ? const Color(0xFF1F2937) : Colors.white),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active
                        ? Colors.transparent
                        : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
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
    );
  }

  Widget _buildCard(bool isDark, int totalPages) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B0B0F) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
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
                  Icon(LucideIcons.circleAlert, color: Colors.redAccent),
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _loadNotifications, child: const Text('Retry')),
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
                      color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isVendor ? LucideIcons.megaphone : LucideIcons.bell,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isVendor ? 'No notifications' : 'No notifications here',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
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
                  .map((n) => _NotificationRow(
                        notification: n,
                        config: _getTypeConfig(n.typeKey),
                        onTap: () => _handleNotificationTap(n),
                        onDelete: () => _deleteNotification(n.id),
                        onMarkRead: n.isRead ? null : () => _markAsRead(n.id),
                      ))
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
      ),
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

  const _NotificationRow({
    required this.notification,
    required this.config,
    required this.onTap,
    required this.onDelete,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final sender = notification.sender ?? const <String, dynamic>{};
    final name = (sender['full_name'] ?? sender['username'] ?? 'Someone').toString();
    final avatar = sender['avatar_url']?.toString();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isUnread ? const Color(0xFFEFF6FF) : Colors.transparent,
          border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.04))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUnread)
              Container(
                margin: const EdgeInsets.only(top: 6, right: 8),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 14),
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
                      border: Border.all(color: Colors.white, width: 2),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                      color: isUnread ? Colors.black : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (notification.metadata?['adTitle'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '📢 ${notification.metadata?['adTitle']}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFF97316)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                if (onMarkRead != null)
                  IconButton(
                    onPressed: onMarkRead,
                    icon: const Icon(LucideIcons.checkCheck, size: 16, color: Color(0xFF3B82F6)),
                  ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(LucideIcons.trash2, size: 16, color: Color(0xFFF87171)),
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
      return const Text('Live', style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w700));
    }
    if (status == 'polling') {
      return const Text('Polling', style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B), fontWeight: FontWeight.w700));
    }
    return const Text('Connecting…', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700));
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
        border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
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
                        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
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
    label: 'Ad',
  ),
};

const _vendorTypeConfig = {
  'ad_approved': _TypeConfig(
    icon: LucideIcons.badgeCheck,
    bgColor: Color(0xFFDCFCE7),
    iconColor: Color(0xFF16A34A),
    label: 'Ad Approved',
  ),
  'ad_rejected': _TypeConfig(
    icon: LucideIcons.circleX,
    bgColor: Color(0xFFFEE2E2),
    iconColor: Color(0xFFDC2626),
    label: 'Ad Rejected',
  ),
  'ad_submitted': _TypeConfig(
    icon: LucideIcons.megaphone,
    bgColor: Color(0xFFDBEAFE),
    iconColor: Color(0xFF3B82F6),
    label: 'Ad Submitted',
  ),
  'ad_expired': _TypeConfig(
    icon: LucideIcons.circleX,
    bgColor: Color(0xFFF3F4F6),
    iconColor: Color(0xFF6B7280),
    label: 'Ad Expired',
  ),
  'ad_like': _TypeConfig(
    icon: LucideIcons.heart,
    bgColor: Color(0xFFFCE7F3),
    iconColor: Color(0xFFEC4899),
    label: 'Ad Like',
  ),
  'ad_comment': _TypeConfig(
    icon: LucideIcons.messageCircle,
    bgColor: Color(0xFFFFEDD5),
    iconColor: Color(0xFFF97316),
    label: 'Ad Comment',
  ),
  'ad_view': _TypeConfig(
    icon: LucideIcons.target,
    bgColor: Color(0xFFE0F2FE),
    iconColor: Color(0xFF0EA5E9),
    label: 'Ad View',
  ),
  'wallet_credit': _TypeConfig(
    icon: LucideIcons.trendingUp,
    bgColor: Color(0xFFDCFCE7),
    iconColor: Color(0xFF16A34A),
    label: 'Wallet Credit',
  ),
  'wallet_debit': _TypeConfig(
    icon: LucideIcons.trendingDown,
    bgColor: Color(0xFFFEE2E2),
    iconColor: Color(0xFFDC2626),
    label: 'Wallet Debit',
  ),
  'ad_spend': _TypeConfig(
    icon: LucideIcons.receipt,
    bgColor: Color(0xFFFEF3C7),
    iconColor: Color(0xFFF59E0B),
    label: 'Ad Spend',
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
    label: 'Campaign',
  ),
  'follow': _TypeConfig(
    icon: LucideIcons.userPlus,
    bgColor: Color(0xFFDBEAFE),
    iconColor: Color(0xFF3B82F6),
    label: 'Follow',
  ),
};

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
