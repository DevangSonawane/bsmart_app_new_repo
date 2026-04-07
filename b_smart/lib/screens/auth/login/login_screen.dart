import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/instagram_theme.dart';
import '../../../widgets/clay_container.dart';
import '../../../services/auth/auth_service.dart';
import '../../home_dashboard.dart';
import '../google_sign_in_button.dart';
// Using native GoogleSignIn / secure browser flows; no embedded WebView

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isVerifyingOtp = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final identifier = _identifierController.text.trim();
      final password = _passwordController.text;
      final outcome = await _authService.login(
        identifier: identifier,
        password: password,
      );

      if (outcome.requires2fa) {
        if (!mounted) return;
        await _showOtpDialog(
          identifier: identifier,
          password: password,
          email: outcome.email ?? identifier,
          message: outcome.message,
        );
      } else {
        _navigateToHome();
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showOtpDialog({
    required String identifier,
    required String password,
    required String email,
    String? message,
  }) async {
    final otpController = TextEditingController();
    String? localError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isVerifyingOtp,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            Future<void> verify() async {
              final otp = otpController.text.trim();
              if (otp.length < 6) {
                setLocalState(() => localError = 'Enter the 6-digit OTP.');
                return;
              }
              setState(() => _isVerifyingOtp = true);
              setLocalState(() => localError = null);
              try {
                final result = await _authService.login(
                  identifier: identifier,
                  password: password,
                  otp: otp,
                );
                if (!mounted) return;
                if (result.requires2fa) {
                  setLocalState(() => localError = 'Invalid OTP. Try again.');
                  return;
                }
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                _navigateToHome();
              } catch (e) {
                setLocalState(() {
                  localError = e.toString().replaceAll('Exception: ', '');
                });
              } finally {
                if (mounted) setState(() => _isVerifyingOtp = false);
              }
            }

            return AlertDialog(
              title: const Text('Enter OTP'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'We sent a 6-digit verification code to $email.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (message != null && message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(message, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      errorText: localError,
                    ),
                    onChanged: (v) {
                      final digits = v.replaceAll(RegExp(r'\\D'), '');
                      if (digits != v) otpController.text = digits;
                      if (digits.length > 6) {
                        otpController.text = digits.substring(0, 6);
                      }
                      otpController.selection = TextSelection.fromPosition(
                        TextPosition(offset: otpController.text.length),
                      );
                    },
                    onSubmitted: (_) => verify(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _isVerifyingOtp ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _isVerifyingOtp ? null : verify,
                  child: _isVerifyingOtp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );

    otpController.dispose();
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeDashboard(),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final maxWidth = isTablet ? 500.0 : size.width;
    final successMessage = ModalRoute.of(context)?.settings.arguments as String?;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: InstagramTheme.responsivePadding(context),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      if (successMessage != null && successMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade100),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.circleCheck, color: Colors.green.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(child: Text(successMessage, style: TextStyle(color: Colors.green.shade800, fontSize: 13))),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                      Text(
                        'Log In',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter your credentials to access your account.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _identifierController,
                        style: const TextStyle(color: InstagramTheme.textBlack),
                        decoration: const InputDecoration(
                          labelText: 'Identity',
                          hintText: 'Email, Phone, or Username',
                          prefixIcon: Icon(LucideIcons.user),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email, phone, or username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: const TextStyle(color: InstagramTheme.textBlack),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(LucideIcons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? LucideIcons.eye
                                  : LucideIcons.eyeOff,
                              color: InstagramTheme.textGrey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/forgot-password');
                          },
                          child: const Text('Forgot Password?'),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Login Button
                      SizedBox(
                        height: 56,
                        child: ClayButton(
                          onPressed: _isLoading ? null : _handleLogin,
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
                              : const Text('LOGIN'),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Divider
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: InstagramTheme.dividerGrey),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 12,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: InstagramTheme.dividerGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Google Sign In Button
                      const GoogleSignInButton(),
                      const SizedBox(height: 32),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pushNamed('/signup'),
                            child: const Text('Sign Up'),
                          ),
                        ],
                      ),
                      SizedBox(height: isTablet ? 40 : 20),
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
