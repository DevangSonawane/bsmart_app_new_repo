import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../api/auth_api.dart';
import '../../api/users_api.dart';
import '../../theme/instagram_theme.dart';
import '../../screens/home_dashboard.dart';
import '../../widgets/clay_container.dart';
import '../../utils/validators.dart';
import '../../utils/app_error_handler.dart';
import '../../utils/timezone_service.dart';
import 'apple_sign_in_button.dart';
import 'google_sign_in_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

  final UsersApi _usersApi = UsersApi();

  Timer? _emailDebounce;
  Timer? _usernameDebounce;
  Timer? _phoneDebounce;

  bool _checkingEmail = false;
  bool _checkingUsername = false;
  bool _checkingPhone = false;

  bool? _emailAvailable;
  bool? _usernameAvailable;
  bool? _phoneAvailable;

  String _emailCheckedValue = '';
  String _usernameCheckedValue = '';
  String _phoneCheckedValue = '';

  String? _emailAvailabilityMessage;
  String? _usernameAvailabilityMessage;
  String? _phoneAvailabilityMessage;

  Color _cardBackground(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
        : Colors.white.withValues(alpha: 0.96);
  }

  Color _cardBorder(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.outlineVariant
        : InstagramTheme.borderGrey;
  }

  Color _cardShadowColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.06);
  }

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_scheduleEmailCheck);
    _usernameController.addListener(_scheduleUsernameCheck);
    _phoneController.addListener(_schedulePhoneCheck);
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _usernameDebounce?.cancel();
    _phoneDebounce?.cancel();
    _emailController.removeListener(_scheduleEmailCheck);
    _usernameController.removeListener(_scheduleUsernameCheck);
    _phoneController.removeListener(_schedulePhoneCheck);
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _scheduleEmailCheck() {
    _emailDebounce?.cancel();
    final value = _emailController.text.trim();
    setState(() {
      if (value.isEmpty || Validators.validateEmail(value) != null) {
        _checkingEmail = false;
        _emailAvailable = null;
        _emailAvailabilityMessage = null;
        _emailCheckedValue = '';
      }
    });
    if (value.isEmpty || Validators.validateEmail(value) != null) return;
    _checkingEmail = true;
    _emailDebounce = Timer(const Duration(milliseconds: 450), () {
      _checkEmailAvailability(value);
    });
    if (mounted) setState(() {});
  }

  void _scheduleUsernameCheck() {
    _usernameDebounce?.cancel();
    final value = _usernameController.text.trim();
    setState(() {
      if (value.isEmpty || Validators.validateUsername(value) != null) {
        _checkingUsername = false;
        _usernameAvailable = null;
        _usernameAvailabilityMessage = null;
        _usernameCheckedValue = '';
      }
    });
    if (value.isEmpty || Validators.validateUsername(value) != null) return;
    _checkingUsername = true;
    _usernameDebounce = Timer(const Duration(milliseconds: 450), () {
      _checkUsernameAvailability(value);
    });
    if (mounted) setState(() {});
  }

  void _schedulePhoneCheck() {
    _phoneDebounce?.cancel();
    final value = _phoneController.text.trim();
    setState(() {
      if (value.isEmpty || Validators.validatePhone(value) != null) {
        _checkingPhone = false;
        _phoneAvailable = null;
        _phoneAvailabilityMessage = null;
        _phoneCheckedValue = '';
      }
    });
    if (value.isEmpty || Validators.validatePhone(value) != null) return;
    _checkingPhone = true;
    _phoneDebounce = Timer(const Duration(milliseconds: 450), () {
      _checkPhoneAvailability(value);
    });
    if (mounted) setState(() {});
  }

  Future<void> _checkEmailAvailability(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty || Validators.validateEmail(normalized) != null)
      return;
    try {
      final result = await _usersApi.checkEmailAvailability(normalized);
      if (!mounted || _emailController.text.trim() != normalized) return;
      setState(() {
        _checkingEmail = false;
        _emailAvailable = result.available;
        _emailAvailabilityMessage = result.message;
        _emailCheckedValue = normalized;
      });
    } catch (e, st) {
      AppErrorHandler.logError('signup-email-check', e, st);
      if (!mounted || _emailController.text.trim() != normalized) return;
      setState(() {
        _checkingEmail = false;
        _emailAvailable = false;
        _emailAvailabilityMessage = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to check email availability right now.',
        );
        _emailCheckedValue = normalized;
      });
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    final normalized = username.trim();
    if (normalized.isEmpty || Validators.validateUsername(normalized) != null)
      return;
    try {
      final result = await _usersApi.checkUsernameAvailability(normalized);
      if (!mounted || _usernameController.text.trim() != normalized) return;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = result.available;
        _usernameAvailabilityMessage = result.message;
        _usernameCheckedValue = normalized;
      });
    } catch (e, st) {
      AppErrorHandler.logError('signup-username-check', e, st);
      if (!mounted || _usernameController.text.trim() != normalized) return;
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = false;
        _usernameAvailabilityMessage = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to check username availability right now.',
        );
        _usernameCheckedValue = normalized;
      });
    }
  }

  Future<void> _checkPhoneAvailability(String phone) async {
    final normalized = phone.trim();
    if (normalized.isEmpty || Validators.validatePhone(normalized) != null)
      return;
    try {
      final result = await _usersApi.checkPhoneAvailability(normalized);
      if (!mounted || _phoneController.text.trim() != normalized) return;
      setState(() {
        _checkingPhone = false;
        _phoneAvailable = result.available;
        _phoneAvailabilityMessage = result.message;
        _phoneCheckedValue = normalized;
      });
    } catch (e, st) {
      AppErrorHandler.logError('signup-phone-check', e, st);
      if (!mounted || _phoneController.text.trim() != normalized) return;
      setState(() {
        _checkingPhone = false;
        _phoneAvailable = false;
        _phoneAvailabilityMessage = AppErrorHandler.userMessage(
          e,
          fallback: 'Unable to check phone availability right now.',
        );
        _phoneCheckedValue = normalized;
      });
    }
  }

  Future<void> _ensureAvailabilityChecks() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final phone = _phoneController.text.trim();

    final futures = <Future<void>>[];
    if (email.isNotEmpty &&
        Validators.validateEmail(email) == null &&
        _emailCheckedValue != email) {
      futures.add(_checkEmailAvailability(email));
    }
    if (username.isNotEmpty &&
        Validators.validateUsername(username) == null &&
        _usernameCheckedValue != username) {
      futures.add(_checkUsernameAvailability(username));
    }
    if (phone.isNotEmpty &&
        Validators.validatePhone(phone) == null &&
        _phoneCheckedValue != phone) {
      futures.add(_checkPhoneAvailability(phone));
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String labelText,
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
    String? helperText,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
        : Colors.white;
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(color: mutedColor),
      hintStyle: TextStyle(color: mutedColor),
      prefixIcon: Icon(icon, color: mutedColor),
      suffixIcon: suffixIcon,
      helperText: helperText,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: InstagramTheme.borderGrey,
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: InstagramTheme.borderGrey,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: InstagramTheme.accentBlue,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: InstagramTheme.errorRed,
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: InstagramTheme.errorRed,
          width: 1.6,
        ),
      ),
    );
  }

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        pass.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    await _ensureAvailabilityChecks();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final timezone = await TimezoneService.instance.captureDeviceTimezone();
      await AuthApi().register(
        email: email,
        password: pass,
        username: username,
        fullName: name,
        phone: phone,
        clientTimezoneName: timezone.name,
        clientTimezoneOffsetMinutes: timezone.offsetMinutes,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
          (route) => false,
        );
      }
    } catch (e, st) {
      AppErrorHandler.logError('signup-submit', e, st);
      setState(() => _error = AppErrorHandler.userMessage(
            e,
            fallback: 'Unable to create your account. Please try again.',
          ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isTablet = size.width > 600;
    final maxWidth = isTablet ? 540.0 : size.width;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24 + bottomInset,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  color: _cardBackground(context),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _cardBorder(context)),
                  boxShadow: [
                    BoxShadow(
                      color: _cardShadowColor(context),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Create Account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up to get started.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: _fieldDecoration(
                          context,
                          labelText: 'Full Name',
                          hintText: 'John Doe',
                          icon: LucideIcons.user,
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: _fieldDecoration(
                          context,
                          labelText: 'Email Address',
                          hintText: 'john@example.com',
                          icon: LucideIcons.mail,
                          suffixIcon: _checkingEmail
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : _emailCheckedValue ==
                                          _emailController.text.trim() &&
                                      _emailAvailable != null
                                  ? Icon(
                                      _emailAvailable!
                                          ? LucideIcons.circleCheck
                                          : LucideIcons.x,
                                      color: _emailAvailable!
                                          ? InstagramTheme.successGreen
                                          : InstagramTheme.errorRed,
                                    )
                                  : null,
                          helperText: _emailCheckedValue ==
                                      _emailController.text.trim() &&
                                  _emailAvailabilityMessage != null
                              ? _emailAvailabilityMessage
                              : null,
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          final error = Validators.validateEmail(value);
                          if (error != null) return error;
                          if (_emailCheckedValue == value &&
                              _emailAvailable == false) {
                            return _emailAvailabilityMessage ??
                                'Email is already registered';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: _fieldDecoration(
                          context,
                          labelText: 'Phone Number',
                          hintText: '+1 234 567 890',
                          icon: LucideIcons.phone,
                          suffixIcon: _checkingPhone
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : _phoneCheckedValue ==
                                          _phoneController.text.trim() &&
                                      _phoneAvailable != null
                                  ? Icon(
                                      _phoneAvailable!
                                          ? LucideIcons.circleCheck
                                          : LucideIcons.x,
                                      color: _phoneAvailable!
                                          ? InstagramTheme.successGreen
                                          : InstagramTheme.errorRed,
                                    )
                                  : null,
                          helperText: _phoneCheckedValue ==
                                      _phoneController.text.trim() &&
                                  _phoneAvailabilityMessage != null
                              ? _phoneAvailabilityMessage
                              : null,
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          final error = Validators.validatePhone(value);
                          if (error != null) return error;
                          if (_phoneCheckedValue == value &&
                              _phoneAvailable == false) {
                            return _phoneAvailabilityMessage ??
                                'Phone number is already registered';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _usernameController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: _fieldDecoration(
                          context,
                          labelText: 'Username',
                          hintText: 'johndoe',
                          icon: LucideIcons.atSign,
                          suffixIcon: _checkingUsername
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : _usernameCheckedValue ==
                                          _usernameController.text.trim() &&
                                      _usernameAvailable != null
                                  ? Icon(
                                      _usernameAvailable!
                                          ? LucideIcons.circleCheck
                                          : LucideIcons.x,
                                      color: _usernameAvailable!
                                          ? InstagramTheme.successGreen
                                          : InstagramTheme.errorRed,
                                    )
                                  : null,
                          helperText: _usernameCheckedValue ==
                                      _usernameController.text.trim() &&
                                  _usernameAvailabilityMessage != null
                              ? _usernameAvailabilityMessage
                              : null,
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          final error = Validators.validateUsername(value);
                          if (error != null) return error;
                          if (_usernameCheckedValue == value &&
                              _usernameAvailable == false) {
                            return _usernameAvailabilityMessage ??
                                'Username is already taken';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: _fieldDecoration(
                          context,
                          labelText: 'Password',
                          hintText: '••••••••',
                          icon: LucideIcons.keyRound,
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'At least 6 chars'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: _fieldDecoration(
                          context,
                          labelText: 'Confirm Password',
                          hintText: '••••••••',
                          icon: LucideIcons.keyRound,
                        ),
                        validator: (v) => (v != _passwordController.text)
                            ? 'Does not match'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      if (_error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Text(_error!,
                              style: TextStyle(color: Colors.red.shade800)),
                        ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 56,
                        child: ClayButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  if (_formKey.currentState?.validate() != true)
                                    return;
                                  _signup();
                                },
                          child: _loading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        InstagramTheme.textWhite),
                                  ),
                                )
                              : const Text('SIGN UP'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(
                              child:
                                  Divider(color: InstagramTheme.dividerGrey)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                          ),
                          const Expanded(
                              child:
                                  Divider(color: InstagramTheme.dividerGrey)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: const [
                          Expanded(
                            child: GoogleSignInButton(
                              label: 'Sign up with Google',
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: AppleAuthButton(
                              label: 'Sign up with Apple',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context)
                                .pushReplacementNamed('/login'),
                            child: const Text('Log In'),
                          ),
                        ],
                      ),
                      SizedBox(height: isTablet ? 24 : 8),
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
