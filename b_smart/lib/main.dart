import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/auth/login/login_screen.dart';
import 'screens/home_dashboard.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'theme/theme_scope.dart';
import 'state/store.dart';
import 'state/app_state.dart';
import 'state/feed_actions.dart';
import 'config/api_config.dart';
import 'api/api.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'theme/design_tokens.dart';
import 'routes.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/ad_detail_screen.dart';
import 'utils/system_ui.dart';
import 'widgets/profile_setup_gate.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Forward Flutter framework errors to the current zone handler so they
    // don't bring down the app during debug/testing of plugin failures.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      Zone.current.handleUncaughtError(
          details.exception, details.stack ?? StackTrace.current);
    };
    // Catch asynchronous engine/platform errors that don't go through FlutterError
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('PlatformDispatcher.onError: $error');
      debugPrint(stack.toString());
      return true; // handled
    };
    // Render a friendly error widget instead of a hard crash
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: DesignTokens.instaPink, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Something went wrong',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details.exceptionAsString(),
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    };

    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('Error loading .env: $e');
      // ignore - .env may be absent in some environments
    }

    {
      String? apiBaseUrl;
      try {
        apiBaseUrl = dotenv.env['API_BASE_URL'];
      } catch (_) {}
      ApiConfig.init(baseUrl: apiBaseUrl);
    }

    // In development, proactively clear the image cache so hot-reload does not
    // show stale media from disk cache while URLs stay the same on the server.
    const clearCache = bool.fromEnvironment('CLEAR_CACHE', defaultValue: false);
    if (clearCache) {
      try {
        await DefaultCacheManager().emptyCache();
      } catch (e) {
        debugPrint('Cache clear failed: $e');
      }
    }

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    try {
      // Keep Android system bars visible.
      await applyAndroidEdgeToEdge();
    } catch (e) {
      debugPrint('System UI mode update failed: $e');
    }

    final store = createStore();
    setGlobalStore(store);

    ThemeNotifier themeNotifier;
    try {
      themeNotifier = await ThemeNotifier.create();
    } catch (e) {
      debugPrint('Error initializing ThemeNotifier: $e');
      themeNotifier = ThemeNotifier(initialDark: false);
    }

    runApp(StoreProvider<AppState>(
      store: store,
      child: ThemeScope(
        notifier: themeNotifier,
        child: const BSmartApp(),
      ),
    ));
  }, (error, stack) {
    if (error.toString().contains('VideoError') ||
        error.toString().contains('ExoPlaybackException')) {
      // Ignore asynchronous native ExoPlayer source errors getting thrown out-of-band.
      // DynamicMediaWidget handles these gracefully on the Dart side.
      return;
    }
    debugPrint('Uncaught error in main: $error');
    debugPrint(stack.toString());
  });
}

class BSmartApp extends StatefulWidget {
  const BSmartApp({super.key});

  @override
  State<BSmartApp> createState() => _BSmartAppState();
}

class _BSmartAppState extends State<BSmartApp> with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  int _routeVersion = 0;
  late final _RouteChangeObserver _routeObserver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeObserver = _RouteChangeObserver(() {
      if (!mounted) return;
      setState(() {
        _routeVersion++;
      });
    });
    _checkAuthStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ensure Android system bars stay visible when returning to the app.
      unawaited(applyAndroidEdgeToEdge());
    }
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
      // ✅ Clear stale feed from previous session before rendering home
      if (authed) {
        final store = StoreProvider.of<AppState>(context);
        store.dispatch(SetFeedPosts(const []));
      }
      setState(() {
        _isAuthenticated = authed;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
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
      ..remove('/profile') // ← CRITICAL: must not be in static map
      ..remove('/post'); // ← CRITICAL: must not be in static map

    final isDark = ThemeScope.of(context).isDark;

    return MaterialApp(
      title: 'b Smart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: _isAuthenticated ? const HomeDashboard() : const LoginScreen(),
      routes: staticRoutes,
      navigatorObservers: [_routeObserver, appRouteObserver],
      builder: (context, child) {
        return ProfileSetupGate(
          routeVersion: _routeVersion,
          child: child ?? const SizedBox.shrink(),
        );
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        final uri = Uri.parse(name);
        final segments = uri.pathSegments;

        // /ad/:adId
        if (segments.length == 2 && segments[0] == 'ad') {
          final adId = segments[1];
          debugPrint('[Router] → AdDetailScreen adId=$adId');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (ctx) => AdDetailScreen(adId: adId),
          );
        }

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

class _RouteChangeObserver extends NavigatorObserver {
  final VoidCallback onRouteChanged;

  _RouteChangeObserver(this.onRouteChanged);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onRouteChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onRouteChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onRouteChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    onRouteChanged();
  }
}
