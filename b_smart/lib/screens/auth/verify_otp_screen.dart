import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../theme/design_tokens.dart';
import 'login/login_screen.dart';
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
  String _message = '';
  String _error = '';

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

  Future<void> _verify() async {
    setState(() {
      _error = '';
      _message = '';
      _loading = true;
    });
    try {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
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
    try {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() {
        _message = 'Verification code resent successfully!';
        _resending = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _resending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailFromArgs = ModalRoute.of(context)?.settings.arguments as String?;
    if (emailFromArgs != null && _emailController.text != emailFromArgs) {
      _emailController.text = emailFromArgs;
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
                icon: Icon(LucideIcons.arrowLeft, size: 20),
                label: const Text('Back to Signup'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
              ),
              const SizedBox(height: 32),
              const Spacer(),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: DesignTokens.instaPink.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(LucideIcons.shieldCheck, size: 32, color: DesignTokens.instaPink),
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
                onPressed: _loading ? null : _verify,
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
                          onPressed: (_resending || _emailController.text.trim().isEmpty) ? null : _resend,
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
