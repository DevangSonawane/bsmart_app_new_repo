import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_redux/flutter_redux.dart';

import '../../models/auth/apple_authentication_result.dart';
import '../../services/auth/apple_auth_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/push_service.dart';
import '../../services/session_reset_service.dart';
import '../../state/app_state.dart';
import '../../state/auth_actions.dart';
import '../home_dashboard.dart';
import '../../theme/instagram_theme.dart';
import '../../utils/app_error_handler.dart';

class AppleAuthButton extends StatefulWidget {
  final String label;
  final Future<void> Function(AppleAuthenticationResult result)?
      onAuthenticated;

  const AppleAuthButton({
    super.key,
    this.label = 'Continue with Apple',
    this.onAuthenticated,
  });

  @override
  State<AppleAuthButton> createState() => _AppleAuthButtonState();
}

class _AppleAuthButtonState extends State<AppleAuthButton> {
  final AppleAuthService _appleAuthService = AppleAuthService();
  final AuthService _authService = AuthService();
  bool _loading = false;
  String? _error;

  bool get _supportsAppleSignIn {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
  }

  Color get _spinnerColor {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }

  Color get _buttonBackground {
    return Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;
  }

  Color get _buttonForeground {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;
  }

  Color get _buttonBorder {
    return Theme.of(context).brightness == Brightness.dark
        ? Theme.of(context).colorScheme.outlineVariant
        : InstagramTheme.borderGrey;
  }

  Future<void> _handleAppleSignIn() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _appleAuthService.authenticate();
      if (result == null) {
        return;
      }

      if (!mounted) return;

      if (widget.onAuthenticated != null) {
        await widget.onAuthenticated!(result);
        return;
      } else {
        final user = await _authService.loginWithApple(result);
        if (!mounted) return;
        if (user.id.isEmpty) {
          throw Exception(
            'Apple backend login succeeded but no user profile was returned.',
          );
        }

        await PushService().syncTokenWithBackend();
        await SessionResetService.instance.clearUserSessionState();
        if (mounted) {
          StoreProvider.of<AppState>(context)
              .dispatch(SetAuthenticated(user.id));
        }
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
          (route) => false,
        );
      }
    } catch (e, st) {
      AppErrorHandler.logError('apple-sign-in', e, st);
      if (!mounted) return;
      setState(() {
        _error = AppErrorHandler.userMessage(
          e,
          fallback: 'Apple sign-in failed. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsAppleSignIn) {
      return const SizedBox.shrink();
    }

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
              onPressed: _loading ? null : _handleAppleSignIn,
              style: OutlinedButton.styleFrom(
                backgroundColor: _buttonBackground,
                foregroundColor: _buttonForeground,
                side: BorderSide(color: _buttonBorder, width: 1),
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
                      'assets/images/apple-logo-svgrepo-com.svg',
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(
                        _buttonForeground,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  if (_loading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_spinnerColor),
                      ),
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
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}
