import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/email_api.dart';
import '../../utils/app_error_handler.dart';
import '../../theme/design_tokens.dart';

/// Mobile reset flow aligned with the React web app:
/// 1. Find account by email
/// 2. Verify code/token
/// 3. Set a new password
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1;
  bool _loading = false;
  String _error = '';
  String _message = '';

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _findAccount({bool sendEmail = true}) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email is required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _message = '';
    });

    try {
      if (sendEmail) {
        await EmailApi().forgotPassword(email: email);
      }

      if (!mounted) return;
      setState(() {
        _step = 2;
        _message = 'Reset code sent. Paste the code from your email below.';
      });
    } catch (e, st) {
      AppErrorHandler.logError('forgot-password-find', e, st);
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to send reset instructions. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (code.isEmpty) {
      setState(() => _error = 'Please enter the reset code.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _message = '';
    });

    try {
      await EmailApi().resetPassword(token: code, newPassword: password);
      if (!mounted) return;
      setState(() => _step = 3);
    } catch (e, st) {
      AppErrorHandler.logError('forgot-password-reset', e, st);
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to reset the password. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_emailController.text.trim().isEmpty) return;
    await _findAccount(sendEmail: true);
  }

  @override
  Widget build(BuildContext context) {
    final emailFromArgs = ModalRoute.of(context)?.settings.arguments as String?;
    if (emailFromArgs != null &&
        emailFromArgs.isNotEmpty &&
        _emailController.text.isEmpty) {
      _emailController.text = emailFromArgs;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacementNamed('/login'),
                          icon: const Icon(LucideIcons.arrowLeft, size: 20),
                          splashRadius: 22,
                        ),
                        const SizedBox(width: 2),
                        const Expanded(
                          child: Text(
                            'Forgot Password',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _step / 3,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          DesignTokens.instaPink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error.isNotEmpty)
                      _Banner(
                        color: Colors.red.shade50,
                        borderColor: Colors.red.shade100,
                        iconColor: Colors.red.shade700,
                        icon: LucideIcons.circleAlert,
                        text: _error,
                      ),
                    if (_message.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _Banner(
                        color: Colors.green.shade50,
                        borderColor: Colors.green.shade100,
                        iconColor: Colors.green.shade700,
                        icon: LucideIcons.circleCheck,
                        text: _message,
                      ),
                    ],
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _step == 1
                          ? _buildStep1()
                          : _step == 2
                              ? _buildStep2()
                              : _buildStep3(),
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

  Widget _buildStep1() {
    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Find Your Account',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your email address to search for your account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 22),
        _FieldLabel('Email Address'),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          decoration: _inputDecoration(
            hintText: 'Enter your email',
            icon: LucideIcons.mail,
          ),
          onSubmitted: (_) => _loading ? null : _findAccount(),
        ),
        const SizedBox(height: 20),
        _gradientButton(
          label: _loading ? 'Searching...' : 'Find Account',
          icon: _loading ? null : LucideIcons.search,
          onPressed: _loading ? null : _findAccount,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final email = _emailController.text.trim();

    return Column(
      key: const ValueKey('step2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        const _StepIcon(icon: LucideIcons.shieldCheck),
        const SizedBox(height: 14),
        const Text(
          "Verify it's you",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a code to $email',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 18),
        _FieldLabel('Verification Code'),
        const SizedBox(height: 8),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          textAlign: TextAlign.center,
          decoration: _inputDecoration(
            hintText: 'Paste code',
            icon: LucideIcons.keyRound,
            centered: true,
          ),
        ),
        const SizedBox(height: 16),
        _FieldLabel('New Password'),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: true,
          textInputAction: TextInputAction.next,
          decoration: _inputDecoration(
            hintText: 'New password',
            icon: LucideIcons.lock,
          ),
        ),
        const SizedBox(height: 16),
        _FieldLabel('Confirm Password'),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          textInputAction: TextInputAction.done,
          decoration: _inputDecoration(
            hintText: 'Confirm new password',
            icon: LucideIcons.lockKeyhole,
          ),
          onSubmitted: (_) => _loading ? null : _resetPassword(),
        ),
        const SizedBox(height: 20),
        _gradientButton(
          label: _loading ? 'Resetting...' : 'Verify & Confirm',
          icon: _loading ? null : LucideIcons.checkCheck,
          onPressed: _loading ? null : _resetPassword,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _loading ? null : _resendCode,
          child: Text(
            'Resend Code',
            style: TextStyle(
              color: _loading ? Colors.grey.shade400 : DesignTokens.instaPink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      key: const ValueKey('step3'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const _StepIcon(icon: LucideIcons.circleCheck),
        const SizedBox(height: 14),
        const Text(
          'Password Updated',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Your password has been updated successfully. Please log in again.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
        ),
        const SizedBox(height: 22),
        _gradientButton(
          label: 'Done',
          icon: LucideIcons.arrowRight,
          onPressed: () => Navigator.of(context).pushReplacementNamed(
            '/login',
            arguments: 'Password updated successfully! Please log in.',
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    bool centered = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: centered
          ? null
          : Icon(icon, color: Colors.grey.shade500, size: 20),
      hintStyle: TextStyle(color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFF8F8FB),
      contentPadding: EdgeInsets.symmetric(
        horizontal: centered ? 18 : 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: DesignTokens.instaPink, width: 1.4),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44),
    );
  }

  Widget _gradientButton({
    required String label,
    IconData? icon,
    required Future<void> Function()? onPressed,
  }) {
    final disabled = onPressed == null;
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: disabled
              ? null
              : const LinearGradient(
                  colors: [
                    DesignTokens.instaOrange,
                    DesignTokens.instaPink,
                  ],
                ),
          color: disabled ? Colors.grey.shade300 : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: disabled ? null : () async => onPressed(),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final Color iconColor;
  final IconData icon;
  final String text;

  const _Banner({
    required this.color,
    required this.borderColor,
    required this.iconColor,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: iconColor,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  final IconData icon;
  const _StepIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDF3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 36, color: DesignTokens.instaPink),
      ),
    );
  }
}
