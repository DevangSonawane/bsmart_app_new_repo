import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api.dart';
import '../utils/app_error_handler.dart';

class ContentReportSheet extends StatefulWidget {
  final String contentType;
  final String contentId;

  const ContentReportSheet({
    super.key,
    required this.contentType,
    required this.contentId,
  });

  static Future<void> show(
    BuildContext context, {
    required String contentType,
    required String contentId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ContentReportSheet(
        contentType: contentType,
        contentId: contentId,
      ),
    );
  }

  @override
  State<ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends State<ContentReportSheet> {
  final ContentReportsApi _api = ContentReportsApi();
  final TextEditingController _detailsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<String> _reasons = const [];
  String? _selectedReason;
  bool _loadingReasons = true;
  bool _submitting = false;

  static const List<String> _fallbackReasons = [
    "I just don't like it",
    'Bullying or unwanted contact',
    'Suicide, self-injury or eating disorders',
    'Violence, hate or exploitation',
    'Selling or promoting restricted items',
    'Nudity or sexual activity',
    'Scam, fraud or spam',
    'False information',
  ];

  String _labelForContentType(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'post':
        return 'post';
      case 'reel':
        return 'reel';
      case 'story':
        return 'story';
      case 'ad':
        return 'ad';
      case 'tweet':
        return 'tweet';
      case 'comment':
        return 'comment';
      default:
        return 'content';
    }
  }

  bool _isSpamReason(String reason) {
    final value = reason.toLowerCase();
    return value.contains('spam') || value.contains('scam');
  }

  bool _isAlreadyReportedResponse(Map<String, dynamic>? body, String message) {
    final lower = message.toLowerCase();
    final bodyFlag = body != null &&
        const [
          'already_reported',
          'alreadyReported',
          'is_already_reported',
          'duplicate',
          'conflict',
        ].any((key) => body[key] == true);

    return bodyFlag ||
        lower.contains('already reported') ||
        lower.contains('already submitted') ||
        lower.contains('duplicate') ||
        lower.contains('conflict');
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
    String buttonText = 'OK',
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadReasons());
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadReasons() async {
    try {
      final reasons = await _api.getReasons();
      if (!mounted) return;
      setState(() {
        _reasons = reasons.isNotEmpty ? reasons : _fallbackReasons;
        _selectedReason = _reasons.isNotEmpty ? _reasons.first : null;
        _loadingReasons = false;
      });
    } catch (e, st) {
      AppErrorHandler.logError('content-report-load-reasons', e, st);
      if (!mounted) return;
      setState(() {
        _reasons = _fallbackReasons;
        _selectedReason = _reasons.first;
        _loadingReasons = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final reason = (_selectedReason ?? '').trim();
    if (reason.isEmpty) {
      await _showInfoDialog(
        title: 'Select a reason',
        message: 'Please select a reason before submitting your report.',
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? true)) return;

    setState(() {
      _submitting = true;
    });

    try {
      final res = await _api.submitReport(
        contentType: widget.contentType,
        contentId: widget.contentId,
        reason: reason,
        details: _detailsController.text.trim(),
      );
      if (!mounted) return;
      final body = res;
      final message = (body['message'] ?? body['error'] ?? '').toString();
      final alreadyReported = (body['success'] == false &&
              _isAlreadyReportedResponse(body, message)) ||
          _isAlreadyReportedResponse(body, message);

      Navigator.of(context, rootNavigator: true).pop();
      await _showInfoDialog(
        title: alreadyReported ? 'Already Reported' : 'Report Submitted',
        message: alreadyReported
            ? 'This ${_labelForContentType(widget.contentType)} has already been reported.'
            : 'Your report was submitted successfully.',
      );
    } catch (e, st) {
      AppErrorHandler.logError('content-report-submit', e, st);
      if (!mounted) return;
      final alreadyReported = e is ApiException &&
          _isAlreadyReportedResponse(e.body, e.message) &&
          (e.statusCode == 409 || e.statusCode == 400);
      if (alreadyReported) {
        Navigator.of(context, rootNavigator: true).pop();
        await _showInfoDialog(
          title: 'Already Reported',
          message:
              'This ${_labelForContentType(widget.contentType)} has already been reported.',
        );
        return;
      }
      setState(() {
        _submitting = false;
      });
      await _showInfoDialog(
        title: 'Report Failed',
        message: AppErrorHandler.userMessage(
          e,
          fallback: 'Failed to submit report. Please try again.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.10);
    final label = _labelForContentType(widget.contentType);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Report $label',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _submitting
                                ? null
                                : () =>
                                    Navigator.of(context, rootNavigator: true)
                                        .pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Why are you reporting this $label?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_loadingReasons)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 22),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _selectedReason,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Reason',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.black.withValues(alpha: 0.25),
                                width: 1.2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.black.withValues(alpha: 0.25),
                                width: 1.2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: theme.colorScheme.error,
                                width: 1.6,
                              ),
                            ),
                          ),
                          items: _reasons
                              .map(
                                (reason) => DropdownMenuItem<String>(
                                  value: reason,
                                  child: Row(
                                    children: [
                                      if (_isSpamReason(reason)) ...[
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 18,
                                          color: theme.colorScheme.error,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Expanded(
                                        child: Text(
                                          reason,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: _isSpamReason(reason)
                                                ? FontWeight.w800
                                                : FontWeight.w500,
                                            color: _isSpamReason(reason)
                                                ? theme.colorScheme.error
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _submitting
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedReason = value;
                                  });
                                },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Select a reason';
                            }
                            return null;
                          },
                        ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _detailsController,
                        maxLines: 4,
                        textInputAction: TextInputAction.newline,
                        cursorColor: theme.colorScheme.error,
                        decoration: InputDecoration(
                          labelText: 'Details (optional)',
                          hintText:
                              'Add anything that helps us review this report',
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.black.withValues(alpha: 0.28),
                              width: 1.4,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.black.withValues(alpha: 0.28),
                              width: 1.4,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.error,
                              width: 1.8,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.error,
                              width: 1.4,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: theme.colorScheme.error,
                              width: 1.8,
                            ),
                          ),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Submit Report',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
