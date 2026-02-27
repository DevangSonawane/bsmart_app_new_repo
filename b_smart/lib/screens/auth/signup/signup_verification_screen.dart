import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/instagram_theme.dart';
import '../../../widgets/clay_container.dart';
import '../../../services/auth/auth_service.dart';
import '../../../services/auth/otp_service.dart';
import '../../../models/auth/signup_session_model.dart';
import '../../../utils/validators.dart';
import '../../../utils/constants.dart';
import 'signup_account_setup_screen.dart';

class SignupVerificationScreen extends StatefulWidget {
  final SignupSession session;

  const SignupVerificationScreen({
    super.key,
    required this.session,
  });

  @override
  State<SignupVerificationScreen> createState() =>
      _SignupVerificationScreenState();
}

class _SignupVerificationScreenState extends State<SignupVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  DateTime? _lastResendTime;

  final AuthService _authService = AuthService();
  final OTPService _otpService = OTPService();

  @override
  void initState() {
    super.initState();
    _lastResendTime = DateTime.now();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final verifiedSession =
          await _authService.verifyOTP(widget.session.sessionToken, _otpController.text.trim());

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                SignupAccountSetupScreen(session: verifiedSession),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResendOTP() async {
    final now = DateTime.now();
    if (_lastResendTime != null) {
      final timeSinceLastResend = now.difference(_lastResendTime!);
      if (timeSinceLastResend < AuthConstants.otpResendCooldown) {
        final remainingSeconds =
            (AuthConstants.otpResendCooldown - timeSinceLastResend).inSeconds;
        _showError('Please wait $remainingSeconds seconds before resending');
        return;
      }
    }

    setState(() => _isResending = true);

    try {
      await _otpService.resendOTP(widget.session.sessionToken);
      _lastResendTime = DateTime.now();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OTP sent successfully!'),
            backgroundColor: InstagramTheme.primaryPink,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: InstagramTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getIdentifierDisplay() {
    final value = widget.session.identifierValue;
    if (widget.session.identifierType == IdentifierType.email) {
      return value;
    } else if (widget.session.identifierType == IdentifierType.phone) {
      // Mask phone number
      if (value.length > 4) {
        return '${value.substring(0, 2)}****${value.substring(value.length - 2)}';
      }
      return value;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final maxWidth = isTablet ? 500.0 : size.width;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: InstagramTheme.responsivePadding(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Icon
                    Center(
                      child: ClayContainer(
                        width: 100,
                        height: 100,
                        borderRadius: 50,
                        child: Center(
                          child: Icon(
                            widget.session.identifierType == IdentifierType.email
                                ? LucideIcons.mail                                : LucideIcons.phone,
                            size: 48,
                            color: InstagramTheme.primaryPink,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Verify ${widget.session.identifierType == IdentifierType.email ? "Email" : "Phone"}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'We sent a verification code to',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getIdentifierDisplay(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: InstagramTheme.primaryPink,
                          ),
                    ),
                    const SizedBox(height: 48),

                    // OTP Input
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: InstagramTheme.textBlack,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'Enter OTP',
                        hintText: '000000',
                        counterText: '',
                        prefixIcon: Icon(LucideIcons.lock),
                      ),
                      validator: Validators.validateOTP,
                      onChanged: (value) {
                        if (value.length == 6) {
                          // Auto-submit when 6 digits entered
                          _handleVerify();
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Verify Button
                    SizedBox(
                      height: 56,
                      child: ClayButton(
                        onPressed: _isLoading ? null : _handleVerify,
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      InstagramTheme.textWhite),
                                ),
                              )
                            : const Text('VERIFY'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Resend OTP
                    Center(
                      child: TextButton(
                        onPressed: _isResending ? null : _handleResendOTP,
                        child: _isResending
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Resend OTP'),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
