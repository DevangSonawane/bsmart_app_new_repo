import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/api.dart';
import '../services/auth/auth_service.dart';
import '../utils/app_error_handler.dart';
import '../utils/timezone_service.dart';
import '../theme/design_tokens.dart';

const _accent = Color(0xFFFA3F5E);
const _darkCard = Color(0xFF111827);
const _darkBorder = Color(0xFF1F2937);
const _lightMuted = Color(0xFF6B7280);
const _darkMuted = Color(0xFF9CA3AF);

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  static const _accent = Color(0xFFFA3F5E);
  static const _lightBg = Color(0xFFF9FAFB);
  static const _lightBorder = Color(0xFFF3F4F6);
  static const _topBarBorder = Color(0xFFE5E7EB);
  static const _darkCard = Color(0xFF111827);
  static const _darkBorder = Color(0xFF1F2937);
  static const _lightMuted = Color(0xFF6B7280);
  static const _darkMuted = Color(0xFF9CA3AF);
  static const _lightPink50 = Color(0xFFFDF2F8);
  static const _green100 = Color(0xFFD1FAE5);
  static const _green600 = Color(0xFF059669);
  static const _green90020 = Color(0x3322C55E);
  static const _gray300 = Color(0xFFD1D5DB);
  static const _gray700 = Color(0xFF374151);
  static const _orange50 = Color(0xFFFFF7ED);
  static const _blue50 = Color(0xFFEFF6FF);
  static const _purple50 = Color(0xFFF5F3FF);
  static const _red50 = Color(0xFFFEF2F2);

  bool _loading = true;
  String? _error;

  String? _userId;
  String _email = '';
  String _phone = '';
  bool _twoFAEnabled = false;
  String _twoFAMethod = 'email';
  String _savedMethod = 'email';
  bool _isEditing = false;
  bool _showChangePassword = false;
  bool _pwdLoading = false;
  String? _pwdSuccess;
  String? _pwdError;
  String? _currentPwdError;
  String? _newPwdError;
  String? _confirmPwdError;
  bool _showCurrentPwd = false;
  bool _showNewPwd = false;
  bool _showConfirmPwd = false;
  bool _showActivity = false;
  bool _showHistory = false;
  bool _sessionsLoading = false;
  bool _logoutAllLoading = false;
  String? _toastMessage;
  Timer? _toastTimer;

  final _currentPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();

  List<Map<String, dynamic>> _sessions = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _loginHistory = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _currentPwd.dispose();
    _newPwd.dispose();
    _confirmPwd.dispose();
    super.dispose();
  }

  Map<String, dynamic> _normalizeMe(dynamic raw) {
    if (raw is! Map) return const <String, dynamic>{};
    final map = Map<String, dynamic>.from(raw);
    if (map['user'] is Map) {
      return Map<String, dynamic>.from(map['user'] as Map);
    }
    if (map['data'] is Map) {
      final data = Map<String, dynamic>.from(map['data'] as Map);
      if (data['user'] is Map) {
        return Map<String, dynamic>.from(data['user'] as Map);
      }
      return data;
    }
    return map;
  }

  String _stripExceptionPrefix(Object e) {
    return AppErrorHandler.userMessage(e);
  }

  void _showToast(String message, {bool error = false}) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
    if (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '—';
    final formatted = TimezoneService.instance.formatDateTime(raw);
    return formatted.isEmpty ? '—' : formatted;
  }

  String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'your mobile number';
    if (digits.length <= 4) return digits;
    final head =
        digits.substring(0, digits.length - 4).replaceAll(RegExp(r'\d'), '•');
    return '$head${digits.substring(digits.length - 4)}';
  }

  String _maskEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) return 'your email';
    return value;
  }

  Future<void> _loadMe() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await SecurityApi().getMe();
      final me = _normalizeMe(raw);
      final id = (me['id'] ?? me['_id'] ?? me['user_id'])?.toString();
      final email = (me['email'] ?? '').toString();
      final phone =
          (me['phone'] ?? me['phone_number'] ?? me['mobile'] ?? '').toString();
      final twoFA = me['twoFA'];
      final enabled = twoFA is Map ? twoFA['enabled'] == true : false;
      final method = (twoFA is Map ? twoFA['method'] : null)?.toString().trim();
      if (!mounted) return;
      setState(() {
        _userId = id;
        _email = email;
        _phone = phone;
        _twoFAEnabled = enabled;
        _twoFAMethod = (method == null || method.isEmpty) ? 'email' : method;
        _savedMethod = _twoFAMethod;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _stripExceptionPrefix(e);
        _loading = false;
      });
    }
  }

  void _cancelEdit() {
    setState(() {
      _twoFAMethod = _savedMethod;
      _isEditing = false;
    });
  }

  Future<void> _saveEdit() async {
    final userId = _userId?.trim();
    if (userId == null || userId.isEmpty) return;
    try {
      await SecurityApi().updateTwoFAMethod(
        userId: userId,
        method: _twoFAMethod,
      );
      if (!mounted) return;
      setState(() {
        _savedMethod = _twoFAMethod;
        _isEditing = false;
      });
      _showToast('Security settings saved.');
    } catch (e) {
      if (!mounted) return;
      _showToast(_stripExceptionPrefix(e), error: true);
    }
  }

  Future<void> _toggleTwoFa(bool enable) async {
    final email = _email.trim();
    final userId = _userId?.trim();
    if (userId == null || userId.isEmpty || email.isEmpty) {
      _showToast('Unable to load your account details.', error: true);
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _TwoFAModal(
          mode: enable ? 'enable' : 'disable',
          method: _twoFAMethod,
          email: email,
          phone: _phone,
          userId: userId,
          onDone: (enabled) async {
            if (!mounted) return;
            setState(() {
              _twoFAEnabled = enabled;
            });
            await _loadMe();
          },
          onClose: () => Navigator.of(ctx).pop(),
        );
      },
    );
  }

  Future<void> _loadSessions() async {
    if (_showActivity) {
      setState(() => _showActivity = false);
      return;
    }
    setState(() {
      _showActivity = true;
      _sessionsLoading = true;
    });
    try {
      final sessions = await SecurityApi().getActiveSessions();
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sessions = const <Map<String, dynamic>>[]);
    } finally {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  Future<void> _loadHistory() async {
    if (_showHistory) {
      setState(() => _showHistory = false);
      return;
    }
    setState(() => _showHistory = true);
    try {
      final history = await SecurityApi().getLoginHistory();
      if (!mounted) return;
      setState(() => _loginHistory = history);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loginHistory = const <Map<String, dynamic>>[]);
    }
  }

  Future<void> _changePassword() async {
    final userId = _userId?.trim();
    if (userId == null || userId.isEmpty) return;

    setState(() {
      _pwdError = null;
      _pwdSuccess = null;
      _currentPwdError = null;
      _newPwdError = null;
      _confirmPwdError = null;
    });

    final current = _currentPwd.text.trim();
    final next = _newPwd.text;
    final confirm = _confirmPwd.text;
    if (current.isEmpty) {
      setState(() => _currentPwdError = 'Please enter your current password.');
      return;
    }
    if (next.length < 6) {
      setState(
          () => _newPwdError = 'New password must be at least 6 characters.');
      return;
    }
    if (next != confirm) {
      setState(
        () => _confirmPwdError = 'Passwords do not match.',
      );
      return;
    }

    setState(() => _pwdLoading = true);
    try {
      await AuthApi().changePassword(
        userId: userId,
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      setState(() {
        _pwdSuccess = 'Password updated!';
        _currentPwd.clear();
        _newPwd.clear();
        _confirmPwd.clear();
        _currentPwdError = null;
        _newPwdError = null;
        _confirmPwdError = null;
      });
      _showToast('Password updated!');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 400 || e.statusCode == 401) {
          _currentPwdError = 'Current password is incorrect.';
        } else {
          _pwdError = 'Unable to update password. Please try again.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _pwdError = 'Unable to update password. Please try again.');
    } finally {
      if (mounted) setState(() => _pwdLoading = false);
    }
  }

  Future<void> _logoutAllDevices() async {
    setState(() => _logoutAllLoading = true);
    try {
      await SecurityApi().logoutAllDevices();
      if (!mounted) return;
      setState(() {
        _showActivity = false;
        _sessions = const <Map<String, dynamic>>[];
      });
      _showToast('Logged out from all other devices.');
      await AuthService().logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      _showToast('Failed to logout from all devices.', error: true);
    } finally {
      if (mounted) setState(() => _logoutAllLoading = false);
    }
  }

  Future<void> _removeSession(String sessionId) async {
    try {
      await SecurityApi().removeSession(sessionId);
      if (!mounted) return;
      setState(() {
        _sessions = _sessions
            .where((s) => (s['_id'] ?? s['id'] ?? '').toString() != sessionId)
            .toList();
      });
      _showToast('Session removed.');
    } catch (e) {
      if (!mounted) return;
      _showToast('Failed to remove session.', error: true);
    }
  }

  Future<void> _openResetPassword() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _ResetPasswordModal(
          email: _email,
          onClose: () => Navigator.of(ctx).pop(),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _accent,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _card({
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _divider() {
    final theme = Theme.of(context);
    return Divider(
      height: 1,
      thickness: 1,
      color: theme.dividerColor,
    );
  }

  Widget _rowCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool titleRed = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = titleRed
        ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
        : (isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937));
    final hintColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _changePasswordCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor =
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return _card(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () =>
                setState(() => _showChangePassword = !_showChangePassword),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: DesignTokens.instaPink.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(LucideIcons.lock, color: _accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Update your current password',
                            style: TextStyle(fontSize: 12, color: hintColor)),
                      ],
                    ),
                  ),
                  Icon(
                    _showChangePassword
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 18,
                    color: hintColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showChangePassword)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                if (_pwdSuccess != null) ...[
                  _banner(
                    message: _pwdSuccess!,
                    success: true,
                  ),
                  const SizedBox(height: 10),
                ],
                if (_pwdError != null) ...[
                  _banner(
                    message: _pwdError!,
                    success: false,
                  ),
                  const SizedBox(height: 10),
                ],
                _passwordField(
                  controller: _currentPwd,
                  label: 'Current Password',
                  errorText: _currentPwdError,
                  obscureText: !_showCurrentPwd,
                  onToggleVisibility: () {
                    setState(() => _showCurrentPwd = !_showCurrentPwd);
                  },
                ),
                const SizedBox(height: 10),
                _passwordField(
                  controller: _newPwd,
                  label: 'New Password',
                  errorText: _newPwdError,
                  obscureText: !_showNewPwd,
                  onToggleVisibility: () {
                    setState(() => _showNewPwd = !_showNewPwd);
                  },
                ),
                const SizedBox(height: 10),
                _passwordField(
                  controller: _confirmPwd,
                  label: 'Confirm New Password',
                  errorText: _confirmPwdError,
                  obscureText: !_showConfirmPwd,
                  onToggleVisibility: () {
                    setState(() => _showConfirmPwd = !_showConfirmPwd);
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _pwdLoading ? null : _changePassword,
                    style: FilledButton.styleFrom(backgroundColor: _accent),
                    child: _pwdLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update Password'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    String? errorText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? theme.cardColor : const Color(0xFFFFF3F8);
    final borderColor = isDark ? theme.dividerColor : const Color(0xFFF6CFE0);
    final textColor =
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintColor),
        errorText: errorText,
        filled: true,
        fillColor: fillColor,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText ? LucideIcons.eye : LucideIcons.eyeOff,
            size: 18,
            color: _accent,
          ),
          splashRadius: 18,
        ),
      ),
    );
  }

  Widget _banner({
    required String message,
    required bool success,
  }) {
    final bg = success
        ? Colors.green.withValues(alpha: 0.08)
        : Colors.red.withValues(alpha: 0.08);
    final border = success
        ? Colors.green.withValues(alpha: 0.22)
        : Colors.red.withValues(alpha: 0.22);
    final fg = success ? const Color(0xFF166534) : const Color(0xFFB91C1C);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _resetPasswordTile() {
    return _card(
      children: [
        _rowCard(
          icon: LucideIcons.keyRound,
          iconColor: _accent,
          iconBg: DesignTokens.instaPink.withValues(alpha: 0.12),
          title: 'Reset Password',
          subtitle: 'Send a reset link to your email',
          onTap: _openResetPassword,
          trailing: Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  Widget _twoFaCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor =
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final statusBg = _twoFAEnabled
        ? (isDark ? const Color(0x1A22C55E) : _green100)
        : (isDark
            ? theme.dividerColor.withValues(alpha: 0.28)
            : const Color(0xFFF3F4F6));
    final statusFg = _twoFAEnabled
        ? (isDark ? const Color(0xFF34D399) : _green600)
        : hintColor;
    final methods = <Map<String, dynamic>>[
      <String, dynamic>{
        'key': 'email',
        'label': 'Email OTP',
        'sublabel': 'Code sent to ${_maskEmail(_email)}',
        'icon': LucideIcons.mail,
        'available': true,
      },
      <String, dynamic>{
        'key': 'sms',
        'label': 'SMS OTP',
        'sublabel': _phone.isNotEmpty
            ? 'Code sent to ${_formatPhone(_phone)}'
            : 'No phone number added',
        'icon': LucideIcons.messageSquare,
        'available': _phone.isNotEmpty,
      },
      <String, dynamic>{
        'key': 'app',
        'label': 'Authenticator App',
        'sublabel': 'Coming soon — Google/Microsoft Authenticator',
        'icon': LucideIcons.smartphone,
        'available': false,
      },
    ];

    return _card(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleTwoFa(!_twoFAEnabled),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: DesignTokens.instaPink.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(LucideIcons.shieldCheck,
                        color: _accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Two-Factor Authentication',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Require a code at every login',
                            style: TextStyle(fontSize: 12, color: hintColor)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _twoFAEnabled ? 'ON' : 'OFF',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusFg,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _TwoFaToggle(
                        value: _twoFAEnabled,
                        accent: _accent,
                        offColor: isDark
                            ? theme.dividerColor.withValues(alpha: 0.7)
                            : _gray300,
                        onChanged: _toggleTwoFa,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Authentication Method ${_isEditing ? '' : '— tap Edit to change'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _isEditing ? _accent : hintColor,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 10),
              ...methods.map((item) {
                final key = item['key'] as String;
                final label = item['label'] as String;
                final sublabel = item['sublabel'] as String;
                final icon = item['icon'] as IconData;
                final available = item['available'] as bool;
                final selected = _twoFAMethod == key && _twoFAEnabled;
                final enabled = available && _twoFAEnabled && _isEditing;
                final canSelect = available && _twoFAEnabled && _isEditing;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: canSelect
                          ? () => setState(() => _twoFAMethod = key)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? _accent : theme.dividerColor,
                          ),
                          color: selected
                              ? _accent.withValues(alpha: 0.05)
                              : theme.cardColor,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: selected
                                    ? _accent.withValues(alpha: 0.10)
                                    : theme.dividerColor
                                        .withValues(alpha: 0.25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                size: 15,
                                color: selected ? _accent : hintColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: enabled || selected
                                          ? labelColor
                                          : hintColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(sublabel,
                                      style: TextStyle(
                                          fontSize: 11, color: hintColor)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? _accent
                                      : (isDark ? hintColor : _gray300),
                                  width: 2,
                                ),
                              ),
                              child: selected
                                  ? Center(
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: _accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (_isEditing)
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _cancelEdit,
                      icon: const Icon(LucideIcons.x, size: 13),
                      label: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saveEdit,
                      style: FilledButton.styleFrom(backgroundColor: _accent),
                      icon: const Icon(LucideIcons.check, size: 13),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              if (_twoFAEnabled) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x1A22C55E)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x3322C55E)
                          : const Color(0xFFD1FAE5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.shieldCheck,
                        size: 13,
                        color: isDark ? const Color(0xFF34D399) : _green600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '2FA active - a code will be required at each login.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF34D399)
                                : const Color(0xFF047857),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_twoFAMethod == 'sms' && _phone.isEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x1AFFA500)
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x33FFA500)
                          : const Color(0xFFFCD34D),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.circleAlert,
                        size: 13,
                        color: isDark
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFF97316),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No phone number on your account. Add one in Profile settings to use SMS OTP.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFB45309),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _loginActivityCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor =
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return _card(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loadSessions,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.dividerColor.withValues(alpha: 0.25)
                          : _blue50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.monitor,
                        color: Color(0xFF3B82F6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Devices',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Devices currently logged in',
                            style: TextStyle(fontSize: 12, color: hintColor)),
                      ],
                    ),
                  ),
                  Icon(
                    _showActivity
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 18,
                    color: hintColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showActivity)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: _sessionsLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Loading…'),
                        ],
                      ),
                    ),
                  )
                : _sessions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No active sessions found.'),
                        ),
                      )
                    : Column(
                        children: _sessions.map((session) {
                          final sessionId =
                              (session['_id'] ?? session['id'] ?? '')
                                  .toString();
                          final isCurrent = session['isCurrent'] == true ||
                              session['is_current'] == true;
                          final deviceName = (session['deviceName'] ??
                                  session['device'] ??
                                  session['user_agent'] ??
                                  'Unknown Device')
                              .toString();
                          final deviceType = (session['deviceType'] ??
                                  session['device_type'] ??
                                  'desktop')
                              .toString();
                          final location =
                              (session['location'] ?? '').toString();
                          final ip = (session['ip'] ?? '').toString();
                          final lastActive = session['lastActive'] ??
                              session['last_active'] ??
                              session['created_at'];
                          final deviceIcon =
                              deviceType == 'mobile' || deviceType == 'tablet'
                                  ? LucideIcons.smartphone
                                  : LucideIcons.monitor;
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: theme.dividerColor),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? (isDark
                                              ? const Color(0x1A22C55E)
                                              : const Color(0xFFECFDF5))
                                          : (isDark
                                              ? theme.dividerColor
                                                  .withValues(alpha: 0.25)
                                              : _gray300.withValues(
                                                  alpha: 0.45)),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      deviceIcon,
                                      size: 16,
                                      color: isCurrent
                                          ? (isDark
                                              ? const Color(0xFF34D399)
                                              : _green600)
                                          : hintColor,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                deviceName,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: labelColor,
                                                ),
                                              ),
                                            ),
                                            if (isCurrent)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0x1A22C55E)
                                                      : const Color(0xFFECFDF5),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: Text(
                                                  'Current',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF34D399)
                                                        : _green600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [location, ip]
                                                  .where((v) =>
                                                      v.trim().isNotEmpty)
                                                  .join(' · ')
                                                  .isNotEmpty
                                              ? [location, ip]
                                                  .where((v) =>
                                                      v.trim().isNotEmpty)
                                                  .join(' · ')
                                              : '—',
                                          style: TextStyle(
                                              fontSize: 12, color: hintColor),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatDate(lastActive),
                                          style: TextStyle(
                                              fontSize: 12, color: hintColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isCurrent && sessionId.isNotEmpty)
                                    IconButton(
                                      onPressed: () =>
                                          _removeSession(sessionId),
                                      icon: Icon(
                                        LucideIcons.x,
                                        size: 14,
                                        color: hintColor,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loadHistory,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.dividerColor.withValues(alpha: 0.25)
                          : _purple50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.clock,
                        color: Color(0xFF8B5CF6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Login History',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Recent login activity',
                            style: TextStyle(fontSize: 12, color: hintColor)),
                      ],
                    ),
                  ),
                  Icon(
                    _showHistory
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 18,
                    color: hintColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showHistory)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: _loginHistory.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No login history available.')),
                  )
                : Column(
                    children: _loginHistory.take(20).map((history) {
                      final deviceName = (history['deviceName'] ??
                              history['device'] ??
                              'Unknown Device')
                          .toString();
                      final ip = (history['ip'] ?? '—').toString();
                      final location = (history['location'] ?? '').toString();
                      final timestamp = history['loginAt'] ??
                          history['created_at'] ??
                          history['timestamp'];
                      final ok = history['status'] == 'success' ||
                          history['status'] == 'ok';
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: theme.dividerColor),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: ok ? Colors.green : Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deviceName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: labelColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [ip, location]
                                              .where((v) =>
                                                  v.trim().isNotEmpty &&
                                                  v.trim() != '—')
                                              .join(' · ')
                                              .isNotEmpty
                                          ? [ip, location]
                                              .where((v) =>
                                                  v.trim().isNotEmpty &&
                                                  v.trim() != '—')
                                              .join(' · ')
                                          : ip,
                                      style: TextStyle(
                                          fontSize: 12, color: hintColor),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(timestamp),
                                      style: TextStyle(
                                          fontSize: 12, color: hintColor),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: ok
                                      ? (isDark
                                          ? const Color(0x1A22C55E)
                                          : const Color(0xFFECFDF5))
                                      : (isDark
                                          ? const Color(0x1AF87171)
                                          : const Color(0xFFFEE2E2)),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  ok ? 'OK' : 'Failed',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: ok
                                        ? (isDark
                                            ? const Color(0xFF34D399)
                                            : _green600)
                                        : (isDark
                                            ? const Color(0xFFFCA5A5)
                                            : const Color(0xFFDC2626)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
      ],
    );
  }

  Widget _securityControlsCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return _card(
      children: [
        _rowCard(
          icon: LucideIcons.logOut,
          iconColor: const Color(0xFFF97316),
          iconBg:
              isDark ? theme.dividerColor.withValues(alpha: 0.25) : _orange50,
          title: 'Logout from This Device',
          subtitle: 'End the current session',
          onTap: () async {
            await AuthService().logout();
            if (!mounted) return;
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/login', (route) => false);
          },
        ),
        _divider(),
        _rowCard(
          icon: LucideIcons.trash2,
          iconColor: const Color(0xFFEF4444),
          iconBg: isDark ? theme.dividerColor.withValues(alpha: 0.25) : _red50,
          title: 'Logout from All Devices',
          subtitle: 'Remove all active sessions everywhere',
          titleRed: true,
          onTap: _logoutAllDevices,
          trailing: _logoutAllLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: const Color(0xFF9CA3AF),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Security',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: theme.dividerColor,
          ),
        ),
        actions: const [],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (_toastMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0x1A22C55E)
                          : Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isDark
                              ? const Color(0x3322C55E)
                              : Colors.green.withValues(alpha: 0.18)),
                    ),
                    child: Text(
                      _toastMessage!,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF166534),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (_isEditing) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: _accent.withValues(alpha: 0.20)),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.pencil, size: 12, color: _accent),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Editing - tap Save when you're done",
                            style: TextStyle(
                              color: _accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _sectionTitle('Password'),
                _changePasswordCard(),
                const SizedBox(height: 12),
                _resetPasswordTile(),
                const SizedBox(height: 20),
                _sectionTitle('Login Security'),
                _twoFaCard(),
                const SizedBox(height: 20),
                _sectionTitle('Login Activity'),
                _loginActivityCard(),
                const SizedBox(height: 20),
                _sectionTitle('Security Controls'),
                _securityControlsCard(),
              ],
            ),
    );
  }
}

class _TwoFAModal extends StatefulWidget {
  final String mode;
  final String method;
  final String email;
  final String phone;
  final String userId;
  final Future<void> Function(bool enabled) onDone;
  final VoidCallback onClose;

  const _TwoFAModal({
    required this.mode,
    required this.method,
    required this.email,
    required this.phone,
    required this.userId,
    required this.onDone,
    required this.onClose,
  });

  @override
  State<_TwoFAModal> createState() => _TwoFAModalState();
}

class _TwoFAModalState extends State<_TwoFAModal> {
  int _step = 1;
  bool _loading = false;
  String? _error;
  String? _success;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _startCooldown() async {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldown = 0);
        return;
      }
      if (mounted) setState(() => _cooldown -= 1);
    });
  }

  Future<void> _sendOtp() async {
    setState(() {
      _error = null;
      _loading = true;
      _success = null;
    });
    try {
      if (_isSms()) {
        final phone = widget.phone.trim();
        if (phone.isEmpty) {
          throw Exception('A mobile number is required for SMS verification.');
        }
        await SmsApi().sendOtp(phone: phone, purpose: 'two_factor');
      } else {
        final email = widget.email.trim();
        if (email.isEmpty) {
          throw Exception(
              'An email address is required for email verification.');
        }
        await EmailApi().sendOtp(email: email, purpose: 'two_factor');
      }
      if (!mounted) return;
      setState(() => _step = 2);
      await _startCooldown();
    } catch (e, st) {
      AppErrorHandler.logError('security-twofa-send', e, st);
      if (!mounted) return;
      setState(() => _error = AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to send the code right now.',
          ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join().trim();
    if (otp.length < 6) {
      setState(() => _error = 'Please enter all 6 digits.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
      _success = null;
    });
    try {
      if (_isSms()) {
        final phone = widget.phone.trim();
        if (phone.isEmpty) {
          throw Exception('A mobile number is required for SMS verification.');
        }
        await SmsApi().verifyOtp(
          phone: phone,
          otp: otp,
          purpose: 'two_factor',
        );
      } else {
        final email = widget.email.trim();
        if (email.isEmpty) {
          throw Exception(
              'An email address is required for email verification.');
        }
        await EmailApi().verifyOtp(
          email: email,
          otp: otp,
          purpose: 'two_factor',
        );
      }
      await SecurityApi().updateTwoFA(
        userId: widget.userId,
        enabled: widget.mode == 'enable',
        method: widget.method,
      );
      if (!mounted) return;
      setState(() {
        _success = widget.mode == 'enable'
            ? '2FA enabled successfully!'
            : '2FA disabled successfully!';
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      await widget.onDone(widget.mode == 'enable');
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      AppErrorHandler.logError('security-twofa-verify', e, st);
      if (!mounted) return;
      setState(() => _error = AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to verify the code right now.',
          ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isSms() => widget.method == 'sms';

  @override
  Widget build(BuildContext context) {
    final isEnable = widget.mode == 'enable';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor =
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final maxDialogWidth = MediaQuery.sizeOf(context).width - 32;
    final dialogWidth = maxDialogWidth < 360 ? maxDialogWidth : 360.0;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isEnable
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.shield,
                    color: isEnable
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnable ? 'Enable 2FA' : 'Disable 2FA',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: labelColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isSms() ? widget.phone : widget.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: hintColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : widget.onClose,
                  icon: const Icon(LucideIcons.x, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_success != null) ...[
              _modalBanner(_success!, success: true),
              const SizedBox(height: 10),
            ],
            if (_error != null) ...[
              _modalBanner(_error!, success: false),
              const SizedBox(height: 10),
            ],
            if (_step == 1) ...[
              Text(
                isEnable
                    ? 'We\'ll send a verification code to your email to confirm enabling two-factor authentication.'
                    : 'To disable 2FA, we need to verify your identity first. A code will be sent to your email.',
                style: TextStyle(fontSize: 12, color: hintColor, height: 1.35),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _sendOtp,
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  child: _loading
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 8),
                            Text('Sending…'),
                          ],
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.mail, size: 14),
                            SizedBox(width: 8),
                            Text('Send Verification Code'),
                          ],
                        ),
                ),
              ),
            ] else ...[
              Text(
                'Enter the 6-digit code sent to your ${_isSms() ? 'phone' : 'email'}',
                style: TextStyle(fontSize: 12, color: hintColor, height: 1.35),
              ),
              const SizedBox(height: 12),
              _otpBoxes(),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _verifyOtp,
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  child: _loading
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 8),
                            Text('Verifying…'),
                          ],
                        )
                      : const Text('Verify & Confirm'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_cooldown > 0 || _loading) ? null : _sendOtp,
                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                  label: Text(
                      _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _otpBoxes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 4,
                  right: index == 5 ? 0 : 4,
                ),
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _otpControllers[index],
                    focusNode: _otpFocusNodes[index],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '0',
                    ),
                    onChanged: (value) {
                      final digits = value.replaceAll(RegExp(r'\D'), '');
                      final cleaned =
                          digits.isEmpty ? '' : digits.substring(0, 1);
                      if (cleaned != value) {
                        _otpControllers[index].text = cleaned;
                        _otpControllers[index].selection =
                            TextSelection.fromPosition(
                          TextPosition(
                              offset: _otpControllers[index].text.length),
                        );
                      }
                      if (cleaned.isNotEmpty && index < 5) {
                        _otpFocusNodes[index + 1].requestFocus();
                      }
                      if (cleaned.isEmpty && index > 0 && value.isEmpty) {
                        _otpFocusNodes[index - 1].requestFocus();
                      }
                    },
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _modalBanner(String message, {required bool success}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = success
        ? (isDark ? const Color(0x1A22C55E) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0x1AF87171) : const Color(0xFFFEE2E2));
    final border = success
        ? (isDark ? const Color(0x3322C55E) : const Color(0xFFD1FAE5))
        : (isDark ? const Color(0x33F87171) : const Color(0xFFFECACA));
    final fg = success
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
        : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _ResetPasswordModal extends StatefulWidget {
  final String email;
  final VoidCallback onClose;

  const _ResetPasswordModal({
    required this.email,
    required this.onClose,
  });

  @override
  State<_ResetPasswordModal> createState() => _ResetPasswordModalState();
}

class _ResetPasswordModalState extends State<_ResetPasswordModal> {
  int _step = 1;
  String? _error;
  bool _loading = false;
  final _token = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    _newPwd.dispose();
    _confirmPwd.dispose();
    super.dispose();
  }

  Future<void> _sendLink() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await EmailApi().forgotPassword(email: widget.email);
      if (!mounted) return;
      setState(() => _step = 2);
    } catch (e, st) {
      AppErrorHandler.logError('security-reset', e, st);
      if (!mounted) return;
      setState(() => _error = AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to reset your password right now.',
          ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_token.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the reset token.');
      return;
    }
    if (_newPwd.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_newPwd.text != _confirmPwd.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await EmailApi().resetPassword(
        token: _token.text.trim(),
        newPassword: _newPwd.text,
      );
      if (!mounted) return;
      setState(() => _step = 3);
    } catch (e, st) {
      AppErrorHandler.logError('security-reset', e, st);
      if (!mounted) return;
      setState(() => _error = AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to reset your password right now.',
          ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _banner(String message, {required bool success}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = success
        ? (isDark ? const Color(0x1A22C55E) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0x1AF87171) : const Color(0xFFFEE2E2));
    final border = success
        ? (isDark ? const Color(0x3322C55E) : const Color(0xFFD1FAE5))
        : (isDark ? const Color(0x33F87171) : const Color(0xFFFECACA));
    final fg = success
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
        : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor =
        isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1F2937);
    final hintColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.keyRound,
                      color: _accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset Password',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: labelColor),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'via email link',
                        style: TextStyle(fontSize: 12, color: hintColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : widget.onClose,
                  icon: const Icon(LucideIcons.x, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              _banner(_error!, success: false),
              const SizedBox(height: 10),
            ],
            if (_step == 1) ...[
              Text(
                'A reset link will be sent to:',
                style: TextStyle(fontSize: 12, color: _lightMuted),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.dividerColor.withValues(alpha: 0.25)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  widget.email,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: labelColor),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _sendLink,
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  child: _loading
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 8),
                            Text('Sending…'),
                          ],
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.mail, size: 14),
                            SizedBox(width: 8),
                            Text('Send Reset Link'),
                          ],
                        ),
                ),
              ),
            ] else if (_step == 2) ...[
              Text(
                'Check your email for the reset token, paste it below and set a new password.',
                style: TextStyle(fontSize: 12, color: hintColor, height: 1.35),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _token,
                decoration: InputDecoration(
                  hintText: 'Paste reset token',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _newPwd,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'New Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmPwd,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Confirm New Password',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _resetPassword,
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                  child: _loading
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                            SizedBox(width: 8),
                            Text('Resetting…'),
                          ],
                        )
                      : const Text('Reset Password'),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFFAF3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.circleCheck,
                          color: Color(0xFF22C55E), size: 24),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Password Reset!',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1F2937)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your password has been updated successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: _lightMuted),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: widget.onClose,
                      style: FilledButton.styleFrom(backgroundColor: _accent),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TwoFaToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;
  final Color offColor;

  const _TwoFaToggle({
    required this.value,
    required this.onChanged,
    required this.accent,
    required this.offColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 40,
          height: 20,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? accent : offColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
