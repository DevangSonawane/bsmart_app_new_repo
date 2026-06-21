import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../api/email_api.dart';
import '../../utils/app_error_handler.dart';
import '../../theme/design_tokens.dart';
import '../home_dashboard.dart';

/// Signup email verification; accepts optional email from route args.
class VerifyOtpScreen extends StatefulWidget {
  final String? email;

  const VerifyOtpScreen({super.key, this.email});

  @override
  State<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> {
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  bool _sending = false;
  bool _autoSent = false;
  int _cooldown = 0;
  String _message = '';
  String _error = '';

  static const String _purposeEmailVerification = 'email_verification';

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({bool showMessage = true}) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email is required.');
      return;
    }

    setState(() {
      _sending = true;
      _error = '';
      if (showMessage) _message = '';
    });
    try {
      await EmailApi().sendOtp(
        email: email,
        purpose: _purposeEmailVerification,
      );
      if (!mounted) return;
      setState(() {
        if (showMessage) {
          _message = 'Verification code sent. Check your email.';
        }
        _cooldown = 60;
      });
      _tickCooldown();
    } catch (e, st) {
      AppErrorHandler.logError('verify-otp-send', e, st);
      if (!mounted) return;
      setState(() => _error = AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to send the verification code. Please try again.',
          ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _tickCooldown() {
    if (_cooldown <= 0) return;
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_cooldown <= 0) return;
      setState(() => _cooldown -= 1);
      _tickCooldown();
    });
  }

  Future<void> _verify() async {
    setState(() {
      _error = '';
      _message = '';
      _loading = true;
    });
    try {
      final email = _emailController.text.trim();
      final otp = _otpController.text.trim();
      if (email.isEmpty) throw Exception('Email is required.');
      if (otp.length < 6) throw Exception('Enter the 6-digit code.');

      await EmailApi().verifyOtp(
        email: email,
        otp: otp,
        purpose: _purposeEmailVerification,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
          (route) => false,
        );
      }
    } catch (e, st) {
      AppErrorHandler.logError('verify-otp-verify', e, st);
      setState(() {
        _error = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to verify the code. Please try again.',
        );
        _loading = false;
      });
    }
  }

  Future<void> _resend() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _resending = true;
      _error = '';
      _message = '';
    });
    await _sendOtp(showMessage: false);
    if (!mounted) return;
    setState(() {
      if (_error.isEmpty) _message = 'Verification code resent successfully!';
      _resending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final emailFromArgs = ModalRoute.of(context)?.settings.arguments as String?;
    if (emailFromArgs != null && _emailController.text != emailFromArgs) {
      _emailController.text = emailFromArgs;
    }

    final effectiveEmail = _emailController.text.trim();
    if (!_autoSent && effectiveEmail.isNotEmpty) {
      _autoSent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _sendOtp(showMessage: false);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/signup'),
                icon: const Icon(LucideIcons.arrowLeft, size: 20),
                label: const Text('Back to Signup'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
              ),
              const SizedBox(height: 32),
              const Spacer(),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: DesignTokens.instaPink.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(LucideIcons.shieldCheck, size: 32, color: DesignTokens.instaPink),
              ),
              const SizedBox(height: 24),
              const Text('Verify your email', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Please enter the verification code sent to\n${_emailController.text.isEmpty ? "your email" : _emailController.text}', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 32),
              if (_message.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade100)),
                  child: Text(_message, style: TextStyle(color: Colors.green.shade800, fontSize: 13)),
                ),
              if (_error.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                  child: Text(_error, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                ),
              if (widget.email == null && emailFromArgs == null) ...[
                const Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              OutlinedButton.icon(
                onPressed: (_sending || _cooldown > 0)
                    ? null
                    : () {
                        _sendOtp();
                      },
                icon: _sending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.mail, size: 18),
                label: Text(_cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Send code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.instaPink,
                  side: BorderSide(color: DesignTokens.instaPink.withValues(alpha: 0.35)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Verification Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, letterSpacing: 6, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading
                    ? null
                    : () {
                        _verify();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.instaPink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Verify Email'),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text.rich(
                  TextSpan(
                    text: "Didn't receive the code? ",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: TextButton(
                          onPressed: (_resending ||
                                  _sending ||
                                  _cooldown > 0 ||
                                  _emailController.text.trim().isEmpty)
                              ? null
                              : () {
                                  _resend();
                                },
                          style: TextButton.styleFrom(foregroundColor: DesignTokens.instaPink, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          child: Text(_resending ? 'Sending...' : 'Resend'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
