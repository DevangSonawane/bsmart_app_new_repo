import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../api/api.dart';
import '../theme/design_tokens.dart';

class LegalComplianceScreen extends StatelessWidget {
  const LegalComplianceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('settings_legal_compliance'.tr()),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        bottom: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
          children: [
            _sectionTitle('settings_legal_section_documents'.tr()),
            _settingsCard(
              context,
              children: [
                _legalRow(
                  context,
                  doc: LegalPolicyDoc(
                    icon: Icons.article_outlined,
                    iconColor: const Color(0xFF3B82F6),
                    iconBg: const Color(0xFFEFF6FF),
                    label: 'settings_terms_conditions'.tr(),
                    subtitle: 'settings_terms_conditions_subtitle'.tr(),
                    policyType: 'terms',
                  ),
                ),
                const Divider(height: 1),
                _legalRow(
                  context,
                  doc: LegalPolicyDoc(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: DesignTokens.instaPink,
                    iconBg: const Color(0xFFFFF1F5),
                    label: 'settings_privacy_policy'.tr(),
                    subtitle: 'settings_privacy_policy_subtitle'.tr(),
                    policyType: 'privacy',
                  ),
                ),
                const Divider(height: 1),
                _legalRow(
                  context,
                  doc: LegalPolicyDoc(
                    icon: Icons.receipt_long_outlined,
                    iconColor: const Color(0xFFF97316),
                    iconBg: const Color(0xFFFFF7ED),
                    label: 'settings_refund_policy'.tr(),
                    subtitle: 'settings_refund_policy_subtitle'.tr(),
                    policyType: 'refund',
                  ),
                ),
                const Divider(height: 1),
                _legalRow(
                  context,
                  doc: LegalPolicyDoc(
                    icon: Icons.rule_outlined,
                    iconColor: const Color(0xFF14B8A6),
                    iconBg: const Color(0xFFF0FDFA),
                    label: 'settings_community_guidelines'.tr(),
                    subtitle: 'settings_community_guidelines_subtitle'.tr(),
                    policyType: 'community_guidelines',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('settings_legal_section_data_controls'.tr()),
            _settingsCard(
              context,
              children: [
                _dataRow(
                  context,
                  icon: Icons.download_outlined,
                  iconColor: const Color(0xFF22C55E),
                  iconBg: const Color(0xFFF0FDF4),
                  label: 'settings_download_my_data'.tr(),
                  subtitle: 'settings_download_my_data_subtitle'.tr(),
                  onTap: () => _showUnavailable(
                    context,
                    'settings_download_my_data'.tr(),
                  ),
                ),
                const Divider(height: 1),
                _dataRow(
                  context,
                  icon: Icons.delete_outline,
                  iconColor: const Color(0xFFEF4444),
                  iconBg: const Color(0xFFFEF2F2),
                  label: 'settings_delete_my_data'.tr(),
                  subtitle: 'settings_delete_my_data_subtitle'.tr(),
                  onTap: () => _showUnavailable(
                    context,
                    'settings_delete_my_data'.tr(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle(
              'settings_legal_section_consent_management'.tr(),
            ),
            _settingsCard(
              context,
              children: [
                _dataRow(
                  context,
                  icon: Icons.tune_outlined,
                  iconColor: const Color(0xFF6366F1),
                  iconBg: const Color(0xFFEEF2FF),
                  label: 'settings_manage_consent_preferences'.tr(),
                  subtitle: 'settings_manage_consent_preferences_subtitle'.tr(),
                  onTap: () => _showUnavailable(
                    context,
                    'settings_manage_consent_preferences'.tr(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('settings_legal_section_dpdp'.tr()),
            _settingsCard(
              context,
              children: [
                _dataRow(
                  context,
                  icon: Icons.manage_search_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  iconBg: const Color(0xFFEFF6FF),
                  label: 'settings_data_access_request'.tr(),
                  subtitle: 'settings_data_access_request_subtitle'.tr(),
                  onTap: () => _showUnavailable(
                    context,
                    'settings_data_access_request'.tr(),
                  ),
                ),
                const Divider(height: 1),
                _dataRow(
                  context,
                  icon: Icons.edit_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  iconBg: const Color(0xFFFFFBEB),
                  label: 'settings_data_correction_request'.tr(),
                  subtitle: 'settings_data_correction_request_subtitle'.tr(),
                  onTap: () => _showUnavailable(
                    context,
                    'settings_data_correction_request'.tr(),
                  ),
                ),
                const Divider(height: 1),
                _dataRow(
                  context,
                  icon: Icons.delete_sweep_outlined,
                  iconColor: const Color(0xFFEF4444),
                  iconBg: const Color(0xFFFEF2F2),
                  label: 'settings_data_deletion_request'.tr(),
                  subtitle: 'settings_data_deletion_request_subtitle'.tr(),
                  onTap: () => _showUnavailable(
                    context,
                    'settings_data_deletion_request'.tr(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoCard(
              context,
              title: 'settings_legal_hub'.tr(),
              subtitle: 'settings_legal_hub_subtitle'.tr(),
              icon: Icons.gavel,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: DesignTokens.instaPink,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _settingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  Widget _legalRow(
    BuildContext context, {
    required LegalPolicyDoc doc,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PolicyDocumentScreen(doc: doc),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: doc.iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(doc.icon, color: doc.iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      doc.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: Theme.of(context).hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dataRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: Theme.of(context).hintColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            DesignTokens.instaPink.withValues(alpha: 0.10),
            DesignTokens.instaOrange.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: DesignTokens.instaPink.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: DesignTokens.instaPink, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUnavailable(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('settings_no_api_exists_yet'.tr(args: [label]))),
    );
  }
}

class PolicyDocumentScreen extends StatefulWidget {
  final LegalPolicyDoc doc;

  const PolicyDocumentScreen({super.key, required this.doc});

  @override
  State<PolicyDocumentScreen> createState() => _PolicyDocumentScreenState();
}

class _PolicyDocumentScreenState extends State<PolicyDocumentScreen> {
  final PolicyApi _policyApi = PolicyApi();
  bool _loading = true;
  bool _loadingHtml = true;
  String? _error;
  String _title = '';
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadingHtml = true;
      _error = null;
      _title = widget.doc.label;
      _controller = null;
    });

    try {
      final policy = await _policyApi.getPolicyByType(widget.doc.policyType);
      if (!mounted) return;
      final html = _wrapPolicyHtml(context, policy.content);
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.disabled)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (!mounted) return;
              setState(() => _loadingHtml = false);
            },
            onWebResourceError: (_) {
              if (!mounted) return;
              setState(() {
                _error = 'Failed to load policy content.';
                _loadingHtml = false;
              });
            },
          ),
        )
        ..loadHtmlString(html);

      setState(() {
        _title = policy.title;
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _policyErrorMessage(e);
        _loading = false;
        _loadingHtml = false;
      });
    }
  }

  String _policyErrorMessage(Object error) {
    if (error is ApiException) {
      final bodyMessage = error.body?['message'] ?? error.body?['error'];
      if (bodyMessage is String && bodyMessage.trim().isNotEmpty) {
        return bodyMessage.trim();
      }
      if (error.message.trim().isNotEmpty) {
        return error.message.trim();
      }
    }
    return 'Failed to load policy.';
  }

  String _wrapPolicyHtml(BuildContext context, String content) {
    final trimmed = content.trim();
    final body = trimmed.isEmpty
        ? '<p>Policy content is unavailable right now.</p>'
        : _looksLikeHtml(trimmed)
            ? trimmed
            : '<p>${const HtmlEscape().convert(trimmed).replaceAll('\n', '<br>')}</p>';
    const pink = '#FA3F5E';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? '#E5E7EB' : '#111827';
    final lineColor = isDark ? '#374151' : '#E5E7EB';

    return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
      html, body {
        margin: 0;
        padding: 0;
        background: transparent;
      }
      body {
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
        color: $textColor;
        line-height: 1.65;
        font-size: 15px;
      }
      .policy-content {
        padding: 6px 2px 28px;
      }
      .policy-content h1 {
        font-size: 1.3rem;
        font-weight: 800;
        margin: 0 0 0.65rem;
        color: inherit;
      }
      .policy-content h2 {
        font-size: 1rem;
        font-weight: 800;
        margin: 1.25rem 0 0.45rem;
        color: inherit;
      }
      .policy-content p,
      .policy-content .LegalBody,
      .policy-content .SmallNote {
        font-size: 0.95rem;
        line-height: 1.7;
        margin: 0 0 0.75rem;
        color: inherit;
      }
      .policy-content .SmallNote {
        opacity: 0.72;
        font-size: 0.85rem;
      }
      .policy-content ul,
      .policy-content ol {
        padding-left: 1.2rem;
        margin: 0 0 0.8rem;
      }
      .policy-content li {
        margin-bottom: 0.35rem;
      }
      .policy-content table {
        width: 100%;
        border-collapse: collapse;
        margin-bottom: 0.9rem;
      }
      .policy-content th,
      .policy-content td {
        border: 1px solid $lineColor;
        padding: 0.55rem 0.65rem;
        vertical-align: top;
      }
      .policy-content a {
        color: $pink;
      }
      .policy-content img {
        max-width: 100%;
        height: auto;
      }
    </style>
  </head>
  <body>
    <div class="policy-content">$body</div>
  </body>
</html>
''';
  }

  bool _looksLikeHtml(String source) {
    final trimmed = source.trimLeft();
    if (trimmed.isEmpty) return false;
    return trimmed.startsWith('<!DOCTYPE html') ||
        trimmed.startsWith('<html') ||
        trimmed.contains('<body') ||
        trimmed.contains('<p') ||
        trimmed.contains('<div') ||
        trimmed.contains('<h1') ||
        trimmed.contains('<h2');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_title.isEmpty ? widget.doc.label : _title),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadPolicy,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: theme.cardColor,
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.doc.iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.doc.icon,
                        color: widget.doc.iconColor,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title.isEmpty ? widget.doc.label : _title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.doc.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _loading
                      ? _buildLoading(context)
                      : _error != null
                          ? _buildError(context)
                          : _buildWebView(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Container(
      key: const ValueKey('policy-loading'),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(height: 12),
            Text('Loading policy...'),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('policy-error'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _error ?? 'Failed to load policy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _loadPolicy,
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.instaPink,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      key: const ValueKey('policy-webview'),
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          if (_controller != null)
            Positioned.fill(
              child: WebViewWidget(controller: _controller!),
            ),
          if (_loadingHtml)
            Positioned.fill(
              child: Container(
                color: theme.scaffoldBackgroundColor.withValues(alpha: 0.72),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LegalPolicyDoc {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final String policyType;

  const LegalPolicyDoc({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.policyType,
  });
}
