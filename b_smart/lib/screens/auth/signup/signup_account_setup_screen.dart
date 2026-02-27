import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../theme/instagram_theme.dart';
import '../../../widgets/clay_container.dart';
import '../../../models/auth/signup_session_model.dart';
import '../../../utils/validators.dart';
import '../../../utils/constants.dart';
import '../../../services/auth/auth_service.dart';
import 'signup_age_verification_screen.dart';

class SignupAccountSetupScreen extends StatefulWidget {
  final SignupSession session;

  const SignupAccountSetupScreen({
    super.key,
    required this.session,
  });

  @override
  State<SignupAccountSetupScreen> createState() =>
      _SignupAccountSetupScreenState();
}

class _SignupAccountSetupScreenState extends State<SignupAccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  PasswordStrength _passwordStrength = PasswordStrength.weak;

  late final bool _isGoogleSignup;

  @override
  void initState() {
    super.initState();
    _isGoogleSignup = widget.session.identifierType == IdentifierType.google;
    _usernameController.addListener(_checkUsernameAvailability);
    if (!_isGoogleSignup) {
      _passwordController.addListener(_updatePasswordStrength);
    } else {
      // Pre-fill full name for Google signup
      final fullName = widget.session.metadata['full_name'];
      if (fullName != null) {
        _fullNameController.text = fullName;
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkUsernameAvailability() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty || username.length < AuthConstants.minUsernameLength) {
      setState(() {
        _isUsernameAvailable = false;
      });
      return;
    }

    // Validate format first
    final validationError = Validators.validateUsername(username);
    if (validationError != null) {
      setState(() {
        _isUsernameAvailable = false;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    try {
      // Debounce check
      await Future.delayed(const Duration(milliseconds: 500));
      if (_usernameController.text.trim() != username) {
        return; // Username changed, ignore this result
      }

      // Check username availability in mock storage
      final authService = AuthService();
      final available = await authService.checkUsernameAvailability(username);
      if (mounted) {
        setState(() {
          _isUsernameAvailable = available;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingUsername = false);
      }
    }
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    setState(() {
      _passwordStrength = Validators.getPasswordStrength(password);
    });
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isUsernameAvailable && _usernameController.text.trim().isNotEmpty) {
      _showError('Username is not available');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Store data in session metadata (will be used in completeSignup)
      final metadata = {
        'full_name': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'password': _isGoogleSignup ? null : _passwordController.text,
      };

      // Update signup session
      final authService = AuthService();
      await authService.updateSignupSession(
        widget.session.sessionToken,
        {
          'metadata': metadata,
          'step': 4,
        },
      );

      // Create updated session
      final updatedSession = SignupSession(
        id: widget.session.id,
        sessionToken: widget.session.sessionToken,
        identifierType: widget.session.identifierType,
        identifierValue: widget.session.identifierValue,
        otpCode: widget.session.otpCode,
        otpExpiresAt: widget.session.otpExpiresAt,
        verificationStatus: widget.session.verificationStatus,
        step: 4,
        metadata: metadata,
        createdAt: widget.session.createdAt,
        expiresAt: widget.session.expiresAt,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                SignupAgeVerificationScreen(session: updatedSession),
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
                    Text(
                      'Create Your Account',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a username and password',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 48),

                    // Full Name (Optional)
                    TextFormField(
                      controller: _fullNameController,
                      style: const TextStyle(color: InstagramTheme.textBlack),
                      decoration: InputDecoration(
                        labelText: 'Full Name (Optional)',
                        prefixIcon: Icon(LucideIcons.user),
                      ),
                      validator: (value) =>
                          Validators.validateFullName(value, required: false),
                    ),
                    const SizedBox(height: 20),

                    // Username
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: InstagramTheme.textBlack),
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(LucideIcons.mail),
                        suffixIcon: _isCheckingUsername
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _usernameController.text.trim().isNotEmpty
                                ? Icon(
                                    _isUsernameAvailable
                                        ? LucideIcons.circleCheck                                        : LucideIcons.x,
                                    color: _isUsernameAvailable
                                        ? InstagramTheme.successGreen
                                        : InstagramTheme.errorRed,
                                  )
                                : null,
                      ),
                      validator: (value) {
                        final error = Validators.validateUsername(value);
                        if (error != null) return error;
                        if (!_isUsernameAvailable && value != null && value.isNotEmpty) {
                          return 'Username is not available';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Password (skip for Google signup)
                    if (!_isGoogleSignup) ...[
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        style: const TextStyle(color: InstagramTheme.textBlack),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(LucideIcons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? LucideIcons.eye                                  : LucideIcons.eyeOff,
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
                      const SizedBox(height: 12),
                      // Password Strength Indicator
                      if (_passwordController.text.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password Strength: ${_passwordStrength.label}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: _passwordStrength.progress,
                              backgroundColor: InstagramTheme.dividerGrey,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _passwordStrength == PasswordStrength.strong
                                    ? InstagramTheme.successGreen
                                    : _passwordStrength == PasswordStrength.medium
                                        ? Colors.orange
                                        : InstagramTheme.errorRed,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                    ],

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

