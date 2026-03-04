import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../api/auth_api.dart';
import '../../services/auth/auth_service.dart';
import '../home_dashboard.dart';

class GoogleSignInButton extends StatefulWidget {
  final String label;
  const GoogleSignInButton({super.key, this.label = 'Continue with Google'});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  final _authApi = AuthApi();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  Future<void> _handleGoogleSignIn() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      print('🚀 Button tapped - starting Google sign in...');
      final token = await _authService.loginWithGoogle();
      if (token == null) {
        print('❌ Token is null - user may have cancelled');
        setState(() => _error = 'Sign in cancelled or failed');
        return;
      }

      print('✅ Got token, fetching user...');
      // Token is already saved in loginWithGoogle

      // Fetch user
      final user = await _authService.fetchCurrentUser();

      if (!mounted) return;

      if (user != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
          (route) => false,
        );
      } else {
        setState(() => _error = 'Authentication failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        print('❌ Error: $e');
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _handleGoogleSignIn,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : SvgPicture.asset(
                    'assets/images/google_logo.svg', // add this asset or use an icon
                    height: 22,
                    // SvgPicture does not have errorBuilder, so removing it
                  ),
            label: Text(widget.label),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
