import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../api/api.dart';
import '../theme/design_tokens.dart';
import '../utils/app_error_handler.dart';

class BugReportsScreen extends StatefulWidget {
  const BugReportsScreen({super.key});

  @override
  State<BugReportsScreen> createState() => _BugReportsScreenState();
}

class _BugReportsScreenState extends State<BugReportsScreen> {
  final BugReportsApi _bugReportsApi = BugReportsApi();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = const [];

  @override
  void initState() {
    super.initState();
    _loadReports();
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

  String _searchText(Map<String, dynamic> report) {
    return [
      report['ticket_id'],
      report['status'],
      report['priority'],
      report['category'],
      report['description'],
      report['subject'],
    ].whereType<Object>().map((e) => e.toString()).join(' ').toLowerCase();
  }

  DateTime _readAt(Map<String, dynamic> report) {
    final raw = report['createdAt'] ??
        report['created_at'] ??
        report['updatedAt'] ??
        report['updated_at'];
    if (raw is DateTime) return raw;
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (raw is num) return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _titleFor(Map<String, dynamic> report) {
    final category = (report['category'] ?? '').toString().trim();
    if (category.isNotEmpty) {
      return category
          .replaceAll('_', ' ')
          .split(' ')
          .where((p) => p.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
    }
    final ticket = (report['ticket_id'] ?? '').toString().trim();
    if (ticket.isNotEmpty) return ticket;
    return 'Bug report';
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'New';
      case 'in_progress':
        return 'In Progress';
      case 'fixed':
        return 'Fixed';
      case 'closed':
        return 'Closed';
      default:
        return status.isEmpty ? 'New' : status;
    }
  }

  Color _statusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'fixed':
        return Colors.green;
      case 'closed':
        return theme.colorScheme.onSurfaceVariant;
      case 'in_progress':
        return Colors.orange;
      default:
        return DesignTokens.instaPink;
    }
  }

  Future<void> _loadReports({bool showLoading = true}) async {
    if (!mounted) return;
    setState(() {
      if (showLoading) _loading = true;
      _error = null;
    });
    try {
      final reports = await _bugReportsApi.getMyBugReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
      });
    } catch (e, st) {
      AppErrorHandler.logError('bug-reports-load', e, st);
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to load bug reports right now.',
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

  List<Map<String, dynamic>> _filteredReports() {
    var list = List<Map<String, dynamic>>.from(_reports);
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list =
          list.where((report) => _searchText(report).contains(query)).toList();
    }
    list.sort((a, b) => _readAt(b).compareTo(_readAt(a)));
    return list;
  }

  Future<void> _openCreateReportSheet() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CreateBugReportSheet(),
    );
    if (created == null || !mounted) return;
    await _loadReports(showLoading: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bug report submitted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reports = _filteredReports();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('settings_report_bug'.tr()),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Report a bug',
            icon: const Icon(LucideIcons.plus),
            onPressed: _openCreateReportSheet,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF111827) : Colors.white,
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
                              color: theme.iconTheme.color
                                  ?.withValues(alpha: 0.72),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search bug reports',
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'My Bug Reports',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (reports.isEmpty)
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
                                LucideIcons.bug,
                                size: 36,
                                color: DesignTokens.instaPink,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No bug reports yet',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap + to submit a new bug report.',
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
                        ...reports.map(
                          (report) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BugReportTile(
                              report: report,
                              title: _titleFor(report),
                              statusLabel: _statusLabel(
                                (report['status'] ?? '').toString(),
                              ),
                              statusColor: _statusColor(
                                (report['status'] ?? '').toString(),
                                theme,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _BugReportTile extends StatelessWidget {
  final Map<String, dynamic> report;
  final String title;
  final String statusLabel;
  final Color statusColor;

  const _BugReportTile({
    required this.report,
    required this.title,
    required this.statusLabel,
    required this.statusColor,
  });

  String _dateText() {
    final raw = report['createdAt'] ??
        report['created_at'] ??
        report['updatedAt'] ??
        report['updated_at'];
    DateTime? dt;
    if (raw is DateTime) {
      dt = raw;
    } else if (raw is String) {
      dt = DateTime.tryParse(raw);
    } else if (raw is num) {
      dt = DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    if (dt == null) return '';
    return DateFormat('d MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111827) : Colors.white;
    final border =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06);
    final description =
        (report['description'] ?? report['message'] ?? '').toString().trim();
    final ticketId = (report['ticket_id'] ?? '').toString().trim();
    final dateText = _dateText();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (ticketId.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ticketId,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (dateText.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              dateText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickedAttachment {
  final Uint8List bytes;
  final String filename;

  const _PickedAttachment({
    required this.bytes,
    required this.filename,
  });
}

class _CreateBugReportSheet extends StatefulWidget {
  const _CreateBugReportSheet();

  @override
  State<_CreateBugReportSheet> createState() => _CreateBugReportSheetState();
}

class _CreateBugReportSheetState extends State<_CreateBugReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final BugReportsApi _bugReportsApi = BugReportsApi();
  final UploadApi _uploadApi = UploadApi();
  final ImagePicker _picker = ImagePicker();
  final List<_PickedAttachment> _attachments = <_PickedAttachment>[];

  bool _submitting = false;
  String _category = 'app_crash';

  static const _categories = <String, String>{
    'app_crash': 'App crash',
    'video_not_playing': 'Video not playing',
    'login_issue': 'Login issue',
    'payment_issue': 'Payment issue',
    'rewards_issue': 'Rewards issue',
    'upload_issue': 'Upload issue',
    'ui_problem': 'UI problem',
    'other': 'Other',
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;

    final items = <_PickedAttachment>[];
    for (final file in picked) {
      try {
        final bytes = await file.readAsBytes();
        final name = file.name.trim().isNotEmpty
            ? file.name.trim()
            : 'bug-${DateTime.now().millisecondsSinceEpoch}.jpg';
        items.add(_PickedAttachment(bytes: bytes, filename: name));
      } catch (e, st) {
        AppErrorHandler.logError('bug-report-pick-attachment', e, st);
      }
    }
    if (!mounted || items.isEmpty) return;
    setState(() => _attachments.addAll(items));
  }

  Future<Map<String, String>> _collectMetadata() async {
    final info = await PackageInfo.fromPlatform();
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    String networkType = 'unknown';
    if (results.contains(ConnectivityResult.none)) {
      networkType = 'none';
    } else if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      networkType = 'wifi';
    } else if (results.contains(ConnectivityResult.mobile)) {
      networkType = 'mobile';
    } else if (results.contains(ConnectivityResult.vpn)) {
      networkType = 'vpn';
    }

    String osType = 'unknown';
    String osVersion = Platform.operatingSystemVersion;
    String deviceModel = 'Unknown device';

    if (kIsWeb) {
      osType = 'web';
      osVersion = 'web';
      deviceModel = 'Web Browser';
    } else {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        osType = 'android';
        osVersion = androidInfo.version.release;
        deviceModel = androidInfo.model;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        osType = 'ios';
        osVersion = iosInfo.systemVersion;
        deviceModel = '${iosInfo.name} ${iosInfo.model}'.trim();
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macInfo = await deviceInfo.macOsInfo;
        osType = 'macos';
        osVersion = macInfo.osRelease;
        deviceModel = macInfo.model;
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        final winInfo = await deviceInfo.windowsInfo;
        osType = 'windows';
        osVersion = winInfo.computerName;
        deviceModel = winInfo.computerName;
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        osType = 'linux';
        osVersion = linuxInfo.versionId ?? Platform.operatingSystemVersion;
        deviceModel = linuxInfo.prettyName;
      } else {
        osType = Platform.operatingSystem;
      }
    }

    return <String, String>{
      'app_version': info.version,
      'os_type': osType,
      'os_version': osVersion,
      'device_model': deviceModel,
      'network_type': networkType,
    };
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final metadata = await _collectMetadata();
      final attachments = <Map<String, dynamic>>[];

      for (final attachment in _attachments) {
        try {
          final uploaded = await _uploadApi.uploadFileBytes(
            bytes: attachment.bytes,
            filename: attachment.filename,
          );
          final url = (uploaded['fileUrl'] ??
                  uploaded['file_url'] ??
                  uploaded['url'] ??
                  uploaded['avatar_url'])
              ?.toString()
              .trim();
          if (url != null && url.isNotEmpty) {
            attachments.add({'url': url, 'type': 'image'});
          }
        } catch (e, st) {
          AppErrorHandler.logError('bug-report-upload-attachment', e, st);
        }
      }

      final result = await _bugReportsApi.submitBugReport(
        category: _category,
        description: _descriptionController.text,
        attachments: attachments,
        appVersion: metadata['app_version'] ?? '',
        osType: metadata['os_type'] ?? '',
        osVersion: metadata['os_version'] ?? '',
        deviceModel: metadata['device_model'] ?? '',
        networkType: metadata['network_type'] ?? '',
      );

      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e, st) {
      AppErrorHandler.logError('bug-report-submit', e, st);
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
        initialChildSize: 0.82,
        minChildSize: 0.66,
        maxChildSize: 0.96,
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
                          'New bug report',
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
                          'Choose a category, describe the issue, and optionally attach screenshots.',
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
                                  LucideIcons.bug,
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
                          controller: _descriptionController,
                          minLines: 5,
                          maxLines: 8,
                          textInputAction: TextInputAction.newline,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText:
                                'App crashes when I open the wallet screen.',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF111827)
                                : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.9),
                                width: 1.4,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.9),
                                width: 1.4,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.55),
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: DesignTokens.instaPink,
                                width: 1.8,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Description is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 86,
                          child: InkWell(
                            onTap: _submitting ? null : _pickAttachments,
                            borderRadius: BorderRadius.circular(18),
                            child: CustomPaint(
                              painter: _DottedRectPainter(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.55),
                                radius: 18,
                                dashWidth: 6,
                                dashGap: 5,
                                strokeWidth: 1.4,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF111827)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        gradient: DesignTokens.instaGradient,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(
                                        LucideIcons.imagePlus,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Add screenshots',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Tap to attach images that show the issue.',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_attachments.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _attachments.map((attachment) {
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  color: Colors.black12,
                                  child: Image.memory(
                                    attachment.bytes,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 30),
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
                                          'Submit bug report',
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
                          'We will include app, OS, device, and network details automatically.',
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

class _DottedRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  const _DottedRectPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashGap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
