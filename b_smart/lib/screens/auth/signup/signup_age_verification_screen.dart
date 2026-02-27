import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../theme/instagram_theme.dart';
import '../../../widgets/clay_container.dart';
import '../../../services/auth/auth_service.dart';
import '../../../models/auth/signup_session_model.dart';
import '../../../utils/validators.dart';
import '../../../utils/constants.dart';
import 'signup_success_screen.dart';

class SignupAgeVerificationScreen extends StatefulWidget {
  final SignupSession session;

  const SignupAgeVerificationScreen({
    super.key,
    required this.session,
  });

  @override
  State<SignupAgeVerificationScreen> createState() =>
      _SignupAgeVerificationScreenState();
}

class _SignupAgeVerificationScreenState
    extends State<SignupAgeVerificationScreen> {
  DateTime? _selectedDate;
  bool _isLoading = false;
  int? _calculatedAge;

  final AuthService _authService = AuthService();

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 100); // 100 years ago
    final DateTime lastDate = now; // Today

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year - 18),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select your date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: InstagramTheme.primaryPink,
              onPrimary: InstagramTheme.textWhite,
              surface: InstagramTheme.surfaceWhite,
              onSurface: InstagramTheme.textBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _calculatedAge = Validators.calculateAge(picked);
      });
    }
  }

  Future<void> _handleContinue() async {
    if (_selectedDate == null) {
      _showError('Please select your date of birth');
      return;
    }

    final validationError = Validators.validateDateOfBirth(_selectedDate);
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get metadata from session (already a Map in SignupSession model)
      final metadata = widget.session.metadata;

      // Complete signup
      final user = await _authService.completeSignup(
        widget.session.sessionToken,
        metadata['username'] as String,
        metadata['full_name'] as String?,
        metadata['password'] as String?,
        _selectedDate!,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SignupSuccessScreen(user: user),
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

    final isUnder18 = _calculatedAge != null && _calculatedAge! < AuthConstants.restrictedAge;
    final isUnder13 = _calculatedAge != null && _calculatedAge! < AuthConstants.minimumAge;

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
                          LucideIcons.cake,
                          size: 48,
                          color: InstagramTheme.primaryPink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'When\'s your birthday?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You need to enter your date of birth',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 48),

                  // Date Picker Button
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: InstagramTheme.backgroundGrey,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: InstagramTheme.borderGrey,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.calendar,
                            color: InstagramTheme.textGrey,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? 'Select Date of Birth'
                                  : DateFormat('MMMM dd, yyyy').format(_selectedDate!),
                              style: TextStyle(
                                color: _selectedDate == null
                                    ? InstagramTheme.textGrey
                                    : InstagramTheme.textBlack,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 16,
                            color: InstagramTheme.textGrey,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Age Display
                  if (_calculatedAge != null) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'You are $_calculatedAge years old',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: InstagramTheme.primaryPink,
                            ),
                      ),
                    ),
                  ],

                  // Age Restrictions Warning
                  if (isUnder18 && !isUnder13) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.info,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Some features may be restricted for users under 18.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.orange.shade900,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (isUnder13) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: InstagramTheme.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: InstagramTheme.errorRed,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.circleAlert,
                            color: InstagramTheme.errorRed,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You must be at least 13 years old to create an account.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: InstagramTheme.errorRed,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  // Continue Button
                  SizedBox(
                    height: 56,
                    child: ClayButton(
                      onPressed: (_isLoading || _selectedDate == null || isUnder13)
                          ? null
                          : _handleContinue,
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
    );
  }
}
