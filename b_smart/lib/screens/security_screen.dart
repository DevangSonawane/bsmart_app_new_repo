import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/auth_api.dart';
import '../api/email_api.dart';
import '../api/users_api.dart';
import '../theme/theme_scope.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  static const _kAccent = Color(0xFFFA3F5E); // React: text-[#fa3f5e]
  static const _kLightBg = Color(0xFFF9FAFB); // Tailwind gray-50
  static const _kLightBorder = Color(0xFFF3F4F6); // Tailwind gray-100
  static const _kTopBarBorder = Color(0xFFE5E7EB); // Tailwind gray-200
  static const _kDarkCard = Color(0xFF111827); // Tailwind gray-900
  static const _kDarkBorder = Color(0xFF1F2937); // Tailwind gray-800
  static const _kLightMuted = Color(0xFF6B7280); // Tailwind gray-500
  static const _kDarkMuted = Color(0xFF9CA3AF); // Tailwind gray-400
  static const _kLightPink50 = Color(0xFFFDF2F8); // Tailwind pink-50
  static const _kGreen100 = Color(0xFFD1FAE5); // emerald-100-ish
  static const _kGreen600 = Color(0xFF059669); // emerald-600
  static const _kGreen900_20 = Color(0x3322C55E); // green-500 @ ~20%
  static const _kGray300 = Color(0xFFD1D5DB); // gray-300
  static const _kGray700 = Color(0xFF374151); // gray-700

  bool _loading = true;
  String? _error;

  String? _userId;
  String? _email;
  bool _twoFAEnabled = false;

  bool _showChangePassword = false;
  bool _pwdLoading = false;
  String? _pwdSuccess;
  String? _pwdError;
  final _currentPwd = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMe();
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

  @override
  void dispose() {
    _currentPwd.dispose();
    _newPwd.dispose();
    _confirmPwd.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await AuthApi().me();
      final me = _normalizeMe(raw);
      final id = (me['id'] ?? me['_id'] ?? me['user_id'])?.toString();
      final email = me['email']?.toString();
      final twoFA = me['twoFA'];
      final enabled = (twoFA is Map) ? (twoFA['enabled'] == true) : false;
      if (!mounted) return;
      setState(() {
        _userId = id;
        _email = email;
        _twoFAEnabled = enabled;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _toggleTwoFa(bool enable) async {
    final email = _email?.trim();
    final userId = _userId?.trim();
    if (email == null || email.isEmpty || userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load your account details.')),
      );
      return;
    }

    int step = 1;
    int cooldown = 0;
    Timer? cooldownTimer;
    StateSetter? setDialogState;
    bool loading = false;
    String? error;
    String? success;
    final otpController = TextEditingController();

    Future<void> startCooldown() async {
      cooldownTimer?.cancel();
      setDialogState?.call(() => cooldown = 60);
      cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (cooldown <= 1) {
          t.cancel();
          setDialogState?.call(() => cooldown = 0);
          return;
        }
        setDialogState?.call(() => cooldown -= 1);
      });
    }

    Future<void> sendOtp(StateSetter setLocal) async {
      setLocal(() {
        loading = true;
        error = null;
        success = null;
      });
      try {
        await EmailApi().sendOtp(email: email, purpose: 'two_factor');
        setLocal(() => step = 2);
        await startCooldown();
      } catch (e) {
        setLocal(() => error = e.toString().replaceAll('Exception: ', ''));
      } finally {
        setLocal(() => loading = false);
      }
    }

    Future<void> verifyOtp(StateSetter setLocal) async {
      final otp = otpController.text.trim();
      if (otp.length < 6) {
        setLocal(() => error = 'Enter the 6-digit code.');
        return;
      }
      setLocal(() {
        loading = true;
        error = null;
        success = null;
      });
      try {
        await EmailApi().verifyOtp(email: email, otp: otp, purpose: 'two_factor');
        await UsersApi().updateUser(userId, twoFAEnabled: enable);
        setLocal(() => success = enable ? '2FA enabled!' : '2FA disabled!');
        if (!mounted) return;
        setState(() => _twoFAEnabled = enable);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        setLocal(() => error = e.toString().replaceAll('Exception: ', ''));
      } finally {
        setLocal(() => loading = false);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            setDialogState = setLocal;
            return AlertDialog(
              title: Text(enable ? 'Enable 2FA' : 'Disable 2FA'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (success != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(success!, style: const TextStyle(color: Colors.green)),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                    ),
                  if (step == 1)
                    Text(
                      enable
                          ? 'A verification code will be sent to your email to confirm enabling 2FA.'
                          : 'We need to verify your identity before disabling 2FA.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (step == 2) ...[
                    Text(
                      'Enter the 6-digit code sent to your email',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '000000',
                        counterText: '',
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                if (step == 1)
                  FilledButton.icon(
                    onPressed: loading ? null : () => sendOtp(setLocal),
                    icon: loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.mail, size: 14),
                    label: Text(loading ? 'Sending…' : 'Send Code'),
                    style: FilledButton.styleFrom(backgroundColor: _kAccent),
                  )
                else ...[
                  TextButton.icon(
                    onPressed: (loading || cooldown > 0) ? null : () => sendOtp(setLocal),
                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                    label: Text(cooldown > 0 ? 'Resend in ${cooldown}s' : 'Resend'),
                  ),
                  FilledButton(
                    onPressed: loading ? null : () => verifyOtp(setLocal),
                    style: FilledButton.styleFrom(backgroundColor: _kAccent),
                    child: loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify'),
                  ),
                ],
              ],
            );
          },
        );
      },
    );

    cooldownTimer?.cancel();
    otpController.dispose();
  }

  Future<void> _changePassword() async {
    final userId = _userId?.trim();
    if (userId == null || userId.isEmpty) return;
    setState(() {
      _pwdError = null;
      _pwdSuccess = null;
    });
    final current = _currentPwd.text;
    final next = _newPwd.text;
    final confirm = _confirmPwd.text;
    if (current.trim().isEmpty) {
      setState(() => _pwdError = 'Current password is required.');
      return;
    }
    if (next.length < 6) {
      setState(() => _pwdError = 'New password must be at least 6 characters.');
      return;
    }
    if (next != confirm) {
      setState(() => _pwdError = 'Passwords do not match.');
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _pwdError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _pwdLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeScope.of(context).isDark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : _kLightBg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
        surfaceTintColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Security',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: isDark ? _kDarkBorder : _kTopBarBorder,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                _twoFaCard(isDark),
                const SizedBox(height: 12),
                _changePasswordCard(isDark),
                const SizedBox(height: 12),
                _resetPasswordTile(isDark),
              ],
            ),
    );
  }

  Widget _twoFaCard(bool isDark) {
    final statusBg = _twoFAEnabled
        ? (isDark ? _kGreen900_20 : _kGreen100)
        : (isDark ? _kDarkBorder : const Color(0xFFF3F4F6));
    final statusFg = _twoFAEnabled
        ? (isDark ? const Color(0xFF34D399) : _kGreen600)
        : (isDark ? _kDarkMuted : const Color(0xFF6B7280));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleTwoFa(!_twoFAEnabled),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? _kDarkCard : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? _kDarkBorder : _kLightBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? _kDarkBorder : _kLightPink50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(LucideIcons.shieldCheck, color: _kAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Two-Factor Authentication',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Extra security via email OTP on login',
                      style: TextStyle(fontSize: 12, color: isDark ? _kDarkMuted : _kLightMuted),
                    ),
                    if (_twoFAEnabled) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x1A22C55E) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0x3322C55E) : const Color(0xFFD1FAE5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.smartphone,
                              size: 14,
                              color: isDark ? const Color(0xFF34D399) : _kGreen600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '2FA is active — email OTP required at each login.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
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
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    onChanged: (v) => _toggleTwoFa(v),
                    accent: _kAccent,
                    offColor: isDark ? _kGray700 : _kGray300,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _changePasswordCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _kDarkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _kDarkBorder : _kLightBorder),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _showChangePassword = !_showChangePassword),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? _kDarkBorder : _kLightPink50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.lock, color: _kAccent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          'Update your current password',
                          style: TextStyle(fontSize: 12, color: isDark ? _kDarkMuted : _kLightMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showChangePassword ? LucideIcons.chevronDown : LucideIcons.chevronRight,
                    size: 18,
                    color: isDark ? _kDarkMuted : const Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ),
          ),
          if (_showChangePassword)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  if (_pwdSuccess != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_pwdSuccess!, style: const TextStyle(color: Colors.green)),
                    ),
                  if (_pwdError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_pwdError!, style: const TextStyle(color: Colors.red)),
                    ),
                  TextField(
                    controller: _currentPwd,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Current Password'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _newPwd,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'New Password'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _confirmPwd,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm New Password'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _pwdLoading ? null : _changePassword,
                      style: FilledButton.styleFrom(backgroundColor: _kAccent),
                      child: _pwdLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _resetPasswordTile(bool isDark) {
    return Material(
      color: isDark ? _kDarkCard : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pushNamed('/forgot-password', arguments: _email),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? _kDarkBorder : _kLightBorder),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? _kDarkBorder : _kLightPink50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.keyRound, color: _kAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      'Send a reset link to your email',
                      style: TextStyle(fontSize: 12, color: isDark ? _kDarkMuted : _kLightMuted),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: isDark ? _kDarkMuted : const Color(0xFF9CA3AF)),
            ],
          ),
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
    final trackColor = value ? accent : offColor;
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
            color: trackColor,
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
