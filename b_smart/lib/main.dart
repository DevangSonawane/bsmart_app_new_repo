import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/auth/login/login_screen.dart';
import 'screens/home_dashboard.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'theme/theme_scope.dart';
import 'state/store.dart';
import 'state/app_state.dart';
import 'config/api_config.dart';
import 'api/api.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'theme/design_tokens.dart';
import 'routes.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // ignore - .env may be absent in some environments
  }

  {
    String? apiBaseUrl;
    try {
      apiBaseUrl = dotenv.env['API_BASE_URL'];
    } catch (_) {}
    ApiConfig.init(baseUrl: apiBaseUrl);
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final store = createStore();
  setGlobalStore(store);
  final themeNotifier = await ThemeNotifier.create();

  runApp(StoreProvider<AppState>(
    store: store,
    child: ThemeScope(
      notifier: themeNotifier,
      child: const BSmartApp(),
    ),
  ));
}

class BSmartApp extends StatefulWidget {
  const BSmartApp({super.key});

  @override
  State<BSmartApp> createState() => _BSmartAppState();
}

class _BSmartAppState extends State<BSmartApp> {
  bool _isInitialized = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final client = ApiClient();
    final hasToken = await client.hasToken;
    bool authed = false;
    if (hasToken) {
      try {
        await AuthApi().me();
        authed = true;
      } catch (_) {
        await client.clearToken();
        authed = false;
      }
    }
    if (mounted) {
      setState(() {
        _isAuthenticated = authed;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: DesignTokens.instaPink,
            ),
          ),
        ),
      );
    }

    // Remove any static entries that would shadow onGenerateRoute.
    // Static routes ALWAYS win over onGenerateRoute for exact matches,
    // so '/profile' in the map would intercept '/profile/someId' and
    // hand it to the wrong screen (or crash with a missing argument).
    final staticRoutes = Map<String, WidgetBuilder>.from(appRoutes)
      ..remove('/')
      ..remove('/profile')   // ← CRITICAL: must not be in static map
      ..remove('/post');     // ← CRITICAL: must not be in static map

    final isDark = ThemeScope.of(context).isDark;

    return MaterialApp(
      title: 'b Smart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: _isAuthenticated ? const HomeDashboard() : const LoginScreen(),
      routes: staticRoutes,
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        final uri = Uri.parse(name);
        final segments = uri.pathSegments;

        // /profile/:userId
        if (segments.length == 2 && segments[0] == 'profile') {
          final userId = segments[1];
          debugPrint('[Router] → ProfileScreen userId=$userId');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (ctx) => ProfileScreen(userId: userId),
          );
        }

        // /post/:postId
        if (segments.length == 2 && segments[0] == 'post') {
          final postId = segments[1];
          debugPrint('[Router] → PostDetailScreen postId=$postId');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (ctx) => PostDetailScreen(postId: postId),
          );
        }

        // Let Flutter handle anything else (404, etc.)
        debugPrint('[Router] No match for: $name');
        return null;
      },
    );
  }
}