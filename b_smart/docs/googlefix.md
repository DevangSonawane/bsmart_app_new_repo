Let me read the frontend design skill first, then give you everything.Here is the complete step-by-step guide:

---

## Step 1: `pubspec.yaml` — Add dependency

```yaml
dependencies:
  google_sign_in: ^6.2.1
```

Then run:
```bash
flutter pub get
```

---

## Step 2: `android/app/src/main/res/values/strings.xml` — Create this file

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="default_web_client_id">832065490130-951s4duefbauqlf26nkmgi69numkj563.apps.googleusercontent.com</string>
</resources>
```

---

## Step 3: `lib/api/auth_api.dart` — Add new method

Add this method inside your existing `AuthApi` class:

```dart
/// Login with Google ID token (native sign-in flow).
Future<Map<String, dynamic>> loginWithGoogle({required String idToken}) async {
  final res = await _client.post('/auth/google/token', body: {
    'id_token': idToken,
  });
  final data = res as Map<String, dynamic>;
  final token = data['token'] as String?;
  if (token != null) await _client.saveToken(token);
  return data;
}
```

---

## Step 4: Replace `lib/screens/auth/google_oauth_webview.dart` entirely

```dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../api/auth_api.dart';
import '../../services/auth/auth_service.dart';
import '../home_dashboard.dart';

class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final _authApi = AuthApi();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Trigger native Google sign-in
      final account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled
        setState(() => _loading = false);
        return;
      }

      // Get auth tokens
      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        throw Exception('Google sign-in failed: no ID token received');
      }

      // Send to your backend
      await _authApi.loginWithGoogle(idToken: idToken);

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
                : Image.asset(
                    'assets/images/google_logo.png', // add this asset or use an icon
                    height: 22,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.g_mobiledata, size: 24),
                  ),
            label: const Text('Continue with Google'),
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
```

---

## Step 5: Update wherever you used `GoogleOAuthWebView`

Replace:
```dart
Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => const GoogleOAuthWebView()),
);
```

With just drop the widget directly in your login screen:
```dart
const GoogleSignInButton()
```

---

## Step 6: Backend — Add new endpoint

**If your backend is Node.js/Express:**
```javascript
const { OAuth2Client } = require('google-auth-library');
const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

app.post('/auth/google/token', async (req, res) => {
  try {
    const { id_token } = req.body;

    // Verify the token with Google
    const ticket = await client.verifyIdToken({
      idToken: id_token,
      audience: process.env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    const { email, name, picture, sub: googleId } = payload;

    // Find or create user in your DB
    let user = await User.findOne({ email });
    if (!user) {
      user = await User.create({
        email,
        full_name: name,
        avatar_url: picture,
        google_id: googleId,
        username: email.split('@')[0] + '_' + Math.random().toString(36).slice(2, 6),
        is_active: true,
      });
    }

    // Issue your own JWT
    const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, {
      expiresIn: '30d',
    });

    res.json({ token, user });
  } catch (e) {
    res.status(401).json({ message: 'Invalid Google token' });
  }
});
```

Set this env variable on your server:
```
GOOGLE_CLIENT_ID=832065490130-951s4duefbauqlf26nkmgi69numkj563.apps.googleusercontent.com
```

---

## Step 7: Clean and rebuild

```bash
flutter clean
flutter pub get
flutter build apk
```

---

## Summary of what changed

| Before | After |
|---|---|
| WebView opened browser OAuth | Native Google sign-in sheet |
| Google blocked it on release | ✅ Officially supported |
| Depended on redirect URL interception | ✅ Gets `idToken` directly |
| Fragile, breaks without warning | ✅ Stable |
