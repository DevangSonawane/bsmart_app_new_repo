import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api.dart';
import '../theme/design_tokens.dart';
import '../utils/app_error_handler.dart';

class ReportContentScreen extends StatefulWidget {
  const ReportContentScreen({super.key});

  @override
  State<ReportContentScreen> createState() => _ReportContentScreenState();
}

class _ReportContentScreenState extends State<ReportContentScreen> {
  final ContentReportsApi _contentReportsApi = ContentReportsApi();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = const [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  String _typeLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'post':
        return 'Post';
      case 'reel':
        return 'Reel';
      case 'story':
        return 'Story';
      case 'ad':
        return 'Ad';
      case 'tweet':
        return 'Tweet';
      case 'comment':
        return 'Comment';
      default:
        return raw.trim().isEmpty ? 'Content' : raw.trim();
    }
  }

  String _statusLabel(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'reviewing':
        return 'Reviewing';
      case 'resolved':
      case 'closed':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      default:
        return raw.trim().isEmpty ? 'Pending' : raw.trim();
    }
  }

  Color _statusColor(String raw, ThemeData theme) {
    switch (raw.trim().toLowerCase()) {
      case 'resolved':
      case 'closed':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      case 'reviewing':
        return Colors.orange;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _formatDate(dynamic raw) {
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is String) {
      dt = DateTime.tryParse(raw);
    } else if (raw is num) {
      dt = DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (dt == null) return '';
    final local = dt.toLocal();
    final month = _monthName(local.month);
    return '${local.day} $month ${local.year}';
  }

  String _monthName(int month) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month < 1 || month > months.length) return '';
    return months[month - 1];
  }

  Future<void> _loadReports({bool showLoading = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoading) _loading = true;
      _error = null;
    });
    try {
      final reports = await _contentReportsApi.getMyReports();
      if (!mounted) return;
      reports.sort((a, b) {
        final aRaw = a['createdAt'] ?? a['created_at'] ?? a['updatedAt'];
        final bRaw = b['createdAt'] ?? b['created_at'] ?? b['updatedAt'];
        final aDt = DateTime.tryParse(aRaw?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDt = DateTime.tryParse(bRaw?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDt.compareTo(aDt);
      });
      setState(() {
        _reports = reports;
      });
    } catch (e, st) {
      AppErrorHandler.logError('content-reports-load', e, st);
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to load your reports right now.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildReportTile(Map<String, dynamic> report, ThemeData theme) {
    final type = _typeLabel((report['content_type'] ?? '').toString());
    final reason = (report['reason'] ?? '').toString().trim();
    final status = (report['status'] ?? '').toString();
    final details = (report['details'] ?? '').toString().trim();
    final contentId = (report['content_id'] ?? '').toString().trim();
    final createdAt = _formatDate(report['createdAt'] ?? report['created_at']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(status, theme).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: _statusColor(status, theme),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reason.isNotEmpty ? reason : 'Report',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
          if (contentId.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Content ID: $contentId',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (createdAt.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              createdAt,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('settings_report_content'.tr()),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loading ? null : () => _loadReports(showLoading: false),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadReports(showLoading: false),
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
                          onPressed: () => _loadReports(),
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
                        padding: const EdgeInsets.all(16),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Reports',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Reports you submitted from posts, reels, stories, ads, tweets, and comments.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_reports.isEmpty)
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
                                Icons.flag_outlined,
                                size: 36,
                                color: DesignTokens.instaPink,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No reports yet',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your submitted content reports will show up here.',
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
                        ..._reports.map(
                          (report) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildReportTile(report, theme),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
