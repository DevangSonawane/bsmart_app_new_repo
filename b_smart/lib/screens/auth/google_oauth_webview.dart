import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/api_config.dart';
import '../../api/auth_api.dart';
import '../../services/auth/auth_service.dart';
import '../home_dashboard.dart';

class GoogleOAuthWebView extends StatefulWidget {
  const GoogleOAuthWebView({super.key});

  @override
  State<GoogleOAuthWebView> createState() => _GoogleOAuthWebViewState();
}

class _GoogleOAuthWebViewState extends State<GoogleOAuthWebView> {
  final AuthApi _authApi = AuthApi();
  final AuthService _authService = AuthService();
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final base = ApiConfig.baseUrl;
    final url = '$base/auth/google?scope=email%20profile';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (NavigationRequest req) {
            final uri = Uri.parse(req.url);
            if (uri.path.contains('/auth/google/success')) {
              final token = uri.queryParameters['token'];
              if (token != null && token.isNotEmpty) {
                _handleToken(token);
                return NavigationDecision.prevent;
              }
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _error = error.description);
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  Future<void> _handleToken(String token) async {
    try {
      await _authApi.saveExternalToken(token);
      final user = await _authService.fetchCurrentUser();
      if (!mounted) return;
      if (user != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
          (route) => false,
        );
      } else {
        setState(() => _error = 'Authentication failed');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Continue with Google')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
