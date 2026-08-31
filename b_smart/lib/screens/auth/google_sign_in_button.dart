import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../../api/auth_api.dart';
import '../../services/auth/auth_service.dart';
import '../../services/session_reset_service.dart';
import '../../services/push_service.dart';
import '../../utils/app_error_handler.dart';
import '../../state/app_state.dart';
import '../../state/auth_actions.dart';
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
        await PushService().syncTokenWithBackend();
        await SessionResetService.instance.clearUserSessionState();
        if (mounted && user.id.isNotEmpty) {
          StoreProvider.of<AppState>(context)
              .dispatch(SetAuthenticated(user.id));
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
          (route) => false,
        );
      } else {
        setState(() => _error = 'Authentication failed. Please try again.');
      }
    } catch (e, st) {
      if (mounted) {
        AppErrorHandler.logError('google-sign-in', e, st);
        setState(() => _error = AppErrorHandler.userMessage(
              e,
              fallback: 'Google sign-in failed. Please try again.',
            ));
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
          height: 56,
          child: Semantics(
            label: widget.label,
            button: true,
            enabled: !_loading,
            child: OutlinedButton(
              onPressed: _loading ? null : _handleGoogleSignIn,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: _loading ? 0 : 1,
                    child: SvgPicture.asset(
                      'assets/images/google_logo.svg',
                      height: 22,
                      width: 22,
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
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
