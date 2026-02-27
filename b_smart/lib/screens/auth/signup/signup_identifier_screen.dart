import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/instagram_theme.dart';
import '../../../widgets/clay_container.dart';
import '../../../services/auth/auth_service.dart';
import '../../../models/auth/signup_session_model.dart';
import '../../../utils/validators.dart';
import 'signup_verification_screen.dart';
import 'signup_account_setup_screen.dart';

class SignupIdentifierScreen extends StatefulWidget {
  const SignupIdentifierScreen({super.key});

  @override
  State<SignupIdentifierScreen> createState() => _SignupIdentifierScreenState();
}

class _SignupIdentifierScreenState extends State<SignupIdentifierScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  IdentifierType _selectedMethod = IdentifierType.email;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
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
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      SignupSession session;

      if (_selectedMethod == IdentifierType.email) {
        final email = _emailController.text.trim();
        final password = _passwordController.text;
        session = await _authService.signupWithEmail(email, password);
      } else if (_selectedMethod == IdentifierType.phone) {
        final phone = _phoneController.text.trim();
        session = await _authService.signupWithPhone(phone);
      } else {
        session = await _authService.signupWithGoogle();
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SignupAccountSetupScreen(session: session),
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SignupAccountSetupScreen(session: session),
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

  Future<void> _handleGoogleSignup() async {
    setState(() => _isLoading = true);

    try {
      final session = await _authService.signupWithGoogle();
      print('session> $session');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SignupAccountSetupScreen(session: session),
          ),
        );
      }
    } catch (e) {
      print('error -.> $e');
      if (mounted) {
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final maxWidth = isTablet ? 500.0 : size.width;

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
                      // Logo
                      Center(
                        child: ClayContainer(
                          width: 100,
                          height: 100,
                          borderRadius: 50,
                          child: Center(
                            child: Icon(
                              LucideIcons.bot,
                              size: 48,
                              color: InstagramTheme.primaryPink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up to get started',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 48),

                      // Method Selection Tabs
                      Row(
                        children: [
                          Expanded(
                            child: _buildMethodTab(
                              'Email',
                              IdentifierType.email,
                              LucideIcons.mail,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMethodTab(
                              'Phone',
                              IdentifierType.phone,
                              Icons.phone_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Email/Phone Input
                      if (_selectedMethod == IdentifierType.email) ...[
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: InstagramTheme.textBlack),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            prefixIcon: Icon(LucideIcons.mail),
                          ),
                          validator: Validators.validateEmail,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(color: InstagramTheme.textBlack),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Create a password',
                            prefixIcon: Icon(LucideIcons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? LucideIcons.eye                                    : LucideIcons.eyeOff,
                                color: InstagramTheme.textGrey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          validator: Validators.validatePassword,
                        ),
                      ] else if (_selectedMethod == IdentifierType.phone) ...[
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: InstagramTheme.textBlack),
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: '+1234567890',
                            prefixIcon: Icon(LucideIcons.phone),
                          ),
                          validator: Validators.validatePhone,
                        ),
                      ],
                      const SizedBox(height: 32),

                      // Continue Button
                      SizedBox(
                        height: 56,
                        child: ClayButton(
                          onPressed: _isLoading ? null : _handleContinue,
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
                              : const Text('CONTINUE'),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Divider
                      Row(
                        children: [
                          Expanded(
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
                          Expanded(
                            child: Divider(color: InstagramTheme.dividerGrey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Google Sign In Button
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleGoogleSignup,
                          icon: SvgPicture.asset(
                            'assets/images/google_logo.svg',
                            width: 24,
                            height: 24,
                          ),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: InstagramTheme.borderGrey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Login'),
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

  Widget _buildMethodTab(String label, IdentifierType type, IconData icon) {
    final isSelected = _selectedMethod == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? InstagramTheme.primaryPink.withValues(alpha: 0.1)
              : InstagramTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? InstagramTheme.primaryPink
                : InstagramTheme.borderGrey,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? InstagramTheme.primaryPink
                  : InstagramTheme.textGrey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? InstagramTheme.primaryPink
                    : InstagramTheme.textGrey,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
