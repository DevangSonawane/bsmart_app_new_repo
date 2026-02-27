import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../api/auth_api.dart';
import '../../services/auth/auth_service.dart';
import '../../config/api_config.dart';
import '../../theme/instagram_theme.dart';
import '../../screens/home_dashboard.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../widgets/clay_container.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

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
  final _authService = AuthService();

  Future<void> _signup() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmController.text;

    if (name.isEmpty || username.isEmpty || email.isEmpty || phone.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AuthApi().register(
        email: email,
        password: pass,
        username: username,
        fullName: name,
        phone: phone,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeDashboard()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignup() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final base = ApiConfig.baseUrl;
      final redirect = 'bsmart://auth/google/success';
      final url =
          '$base/auth/google'
          '?scope=${Uri.encodeComponent('email profile')}'
          '&redirect_uri=${Uri.encodeComponent(redirect)}'
          '&redirect=${Uri.encodeComponent(redirect)}'
          '&callback=${Uri.encodeComponent(redirect)}';
      String result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: 'bsmart',
      );
      final uri = Uri.parse(result);
      String? token =
          uri.queryParameters['token'] ??
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
      if (token != null && token.isNotEmpty) {
        await AuthApi().saveExternalToken(token);
        final user = await _authService.fetchCurrentUser();
        if (user != null) {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomeDashboard()),
              (route) => false,
            );
          }
          return;
        }
      }
      setState(() => _error = 'Google authentication failed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
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
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'John Doe',
                        prefixIcon: Icon(LucideIcons.user),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'johndoe',
                        prefixIcon: Icon(LucideIcons.user),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'john@example.com',
                        prefixIcon: Icon(LucideIcons.mail),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+1 234 567 890',
                        prefixIcon: Icon(LucideIcons.phone),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        hintText: '••••••••',
                        prefixIcon: Icon(LucideIcons.lock),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'At least 6 chars' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: '••••••••',
                        prefixIcon: Icon(LucideIcons.lock),
                      ),
                      validator: (v) => (v != _passwordController.text) ? 'Does not match' : null,
                    ),
                    const SizedBox(height: 12),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 56,
                      child: ClayButton(
                        onPressed: _loading
                            ? null
                            : () {
                                if (_formKey.currentState?.validate() != true) return;
                                _signup();
                              },
                        child: _loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(InstagramTheme.textWhite),
                                ),
                              )
                            : const Text('SIGN UP'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: InstagramTheme.dividerGrey)),
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
                        Expanded(child: Divider(color: InstagramTheme.dividerGrey)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _googleSignup,
                        icon: SvgPicture.asset('assets/images/google_logo.svg', width: 24, height: 24),
                        label: const Text('Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: InstagramTheme.borderGrey),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                          child: const Text('Log In'),
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
    );
  }
}
