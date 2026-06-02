import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../../api/auth_api.dart';
import '../../services/auth/auth_service.dart';
import '../../services/session_reset_service.dart';
import '../../state/app_state.dart';
import '../../state/auth_actions.dart';
import './home_dashboard.dart';

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  final AuthApi _authApi = AuthApi();
  final AuthService _authService = AuthService();
  String _message = 'Authenticating...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      final uri = Uri.base;
      String? token = uri.queryParameters['token'] ??
          uri.queryParameters['access_token'] ??
          uri.queryParameters['id_token'];
      if (token == null || token.isEmpty) {
        final frag = uri.fragment;
        if (frag.isNotEmpty) {
          final fragParams = Uri.splitQueryString(frag);
          token = fragParams['token'] ??
              fragParams['access_token'] ??
              fragParams['id_token'];
        }
      }
      if (token == null || token.isEmpty) {
        setState(() {
          _message = 'No token received';
          _loading = false;
        });
        return;
      }
      await _authApi.saveExternalToken(token);
      final user = await _authService.fetchCurrentUser();
      if (!mounted) return;
      if (user != null) {
        await SessionResetService.instance.clearUserSessionState();
        if (user.id.isNotEmpty) {
          StoreProvider.of<AppState>(context).dispatch(SetAuthenticated(user.id));
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
          (route) => false,
        );
      } else {
        setState(() {
          _message = 'Authentication failed';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Authentication failed';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Text(_message),
      ),
    );
  }
}
