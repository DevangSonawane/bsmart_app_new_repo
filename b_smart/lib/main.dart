import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart';
import 'package:showcaseview/showcaseview.dart';
import 'firebase_options.dart';
import 'screens/auth/login/login_screen.dart';
import 'screens/home_dashboard.dart';
import 'theme/app_theme.dart';
import 'theme/theme_notifier.dart';
import 'theme/theme_scope.dart';
import 'state/store.dart';
import 'state/app_state.dart';
import 'state/auth_actions.dart';
import 'config/api_config.dart';
import 'api/api.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'theme/design_tokens.dart';
import 'routes.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/ad_detail_screen.dart';
import 'screens/ad_public_detail_screen.dart';
import 'screens/reels_screen.dart';
import 'screens/vendor_public_profile_react_screen.dart';
import 'utils/system_ui.dart';
import 'widgets/profile_setup_gate.dart';
import 'utils/app_navigator.dart';
import 'services/push_service.dart';
import 'services/home_onboarding_service.dart';
import 'services/session_reset_service.dart';
import 'utils/timezone_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await EasyLocalization.ensureInitialized();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await PushService().initialize();
    // Forward Flutter framework errors to the current zone handler so they
    // don't bring down the app during debug/testing of plugin failures.
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      final message = details.exceptionAsString();
      final isRenderFlexOverflow =
          message.contains('A RenderFlex overflowed by');
      if (isRenderFlexOverflow) {
        // Layout overflow warnings are common during development and should not
        // be promoted to "uncaught errors" (they otherwise spam `flutter logs`).
        return;
      }
      Zone.current.handleUncaughtError(
        details.exception,
        details.stack ?? StackTrace.current,
      );
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
        scrollBehavior: const _NoGlowScrollBehavior(),
        home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: DesignTokens.instaPink,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Something went wrong',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            details.exceptionAsString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                            maxLines: 12,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    };

    // Tune decoded image cache for reels/feed to reduce churn and re-decoding jank.
    PaintingBinding.instance.imageCache.maximumSize = 200; // max 200 images
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        150 * 1024 * 1024; // 150MB

    // Non-sensitive API base URL is configured in `ApiConfig` defaults.
    ApiConfig.init();
    unawaited(TimezoneService.instance.captureDeviceTimezone());

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
      themeNotifier = ThemeNotifier(initialThemeMode: ThemeMode.system);
    }

    runApp(StoreProvider<AppState>(
      store: store,
      child: EasyLocalization(
        supportedLocales: const [
          Locale('en'),
          Locale('hi'),
          Locale('ta'),
          Locale('te'),
          Locale('kn'),
          Locale('pa'),
          Locale('bn'),
          Locale('gu'),
          Locale('mr'),
        ],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        saveLocale: true,
        useOnlyLangCode: true,
        child: ThemeScope(
          notifier: themeNotifier,
          child: ShowCaseWidget(
            builder: (context) => const BSmartApp(),
            enableAutoScroll: false,
            disableBarrierInteraction: true,
            disableScaleAnimation: false,
            disableMovingAnimation: false,
            blurValue: 1.5,
            scrollDuration: const Duration(milliseconds: 320),
            onFinish: () {
              HomeOnboardingService.instance.handleFinished();
            },
            onDismiss: (_) {
              HomeOnboardingService.instance.handleDismissed();
            },
          ),
        ),
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
  bool _routeVersionUpdateQueued = false;
  bool _skipFirstRouteObserverEvent = true;
  late final _RouteChangeObserver _routeObserver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _routeObserver = _RouteChangeObserver(() {
      if (!mounted) return;
      if (_skipFirstRouteObserverEvent) {
        _skipFirstRouteObserverEvent = false;
        return;
      }
      if (_routeVersionUpdateQueued) return;
      _routeVersionUpdateQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _routeVersionUpdateQueued = false;
        setState(() {
          _routeVersion++;
        });
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
    Map<String, dynamic>? currentUser;
    if (hasToken) {
      try {
        currentUser = await AuthApi().me();
        authed = true;
      } catch (_) {
        await client.clearToken();
        await SessionResetService.instance.clearUserSessionState();
        authed = false;
      }
    }
    if (mounted) {
      if (authed) {
        await SessionResetService.instance.clearUserSessionState();
        final userId =
            (currentUser?['id'] ?? currentUser?['_id'])?.toString().trim() ??
                '';
        if (userId.isNotEmpty) {
          globalStore.dispatch(SetAuthenticated(userId));
        }
      }
      setState(() {
        _isAuthenticated = authed;
        _isInitialized = true;
      });
      if (authed) {
        unawaited(PushService().syncTokenWithBackend());
        unawaited(PushService().replayPendingNavigationIfAny());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        scrollBehavior: _NoGlowScrollBehavior(),
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

    final themeNotifier = ThemeScope.of(context);
    final themeMode = themeNotifier.themeMode;
    final lightTheme =
        themeNotifier.highContrastMode ? AppTheme.highContrastTheme() : AppTheme.theme;
    final darkTheme = themeNotifier.highContrastMode
        ? AppTheme.highContrastDarkTheme()
        : AppTheme.darkTheme;

    return MaterialApp(
      title: 'app_name'.tr(),
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _NoGlowScrollBehavior(),
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      navigatorKey: AppNavigator.key,
      home: _isAuthenticated ? const HomeDashboard() : const LoginScreen(),
      routes: staticRoutes,
      navigatorObservers: [_routeObserver, appRouteObserver],
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(themeNotifier.fontScale),
            accessibleNavigation: themeNotifier.reduceMotion,
          ),
          child: ProfileSetupGate(
            routeVersion: _routeVersion,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        final uri = Uri.parse(name);
        final segments = uri.pathSegments;

        // React parity: /vendor/:userId/public → VendorPublicProfileReactScreen(userId)
        if (segments.length == 3 &&
            segments[0] == 'vendor' &&
            segments[2] == 'public') {
          final userId = segments[1];
          debugPrint(
              '[Router] → VendorPublicProfileReactScreen userId=$userId');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (ctx) => VendorPublicProfileReactScreen(userId: userId),
          );
        }

        // React parity: /ads/:adId/details → AdPublicDetailScreen(adId)
        if (segments.length == 3 &&
            segments[0] == 'ads' &&
            segments[2] == 'details') {
          final adId = segments[1];
          debugPrint('[Router] → AdPublicDetailScreen adId=$adId');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (ctx) => AdPublicDetailScreen(adId: adId),
          );
        }

        // /ad/:adId
        if (segments.length == 2 && segments[0] == 'ad') {
          final adId = segments[1];
          debugPrint('[Router] → AdDetailScreen adId=$adId');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (ctx) => AdDetailScreen(adId: adId),
          );
        }

        // React parity: /vendor/ads-management/:adId → AdDetailScreen(adId)
        if (segments.length == 3 &&
            segments[0] == 'vendor' &&
            segments[1] == 'ads-management') {
          final adId = segments[2];
          debugPrint(
              '[Router] → AdDetailScreen (vendor ads-management) adId=$adId');
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
          final type = (uri.queryParameters['type'] ?? '').toLowerCase().trim();
          final isTweet = type == 'tweet';
          debugPrint('[Router] → PostDetailScreen postId=$postId');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (ctx) => PostDetailScreen(
              postId: postId,
              isTweet: isTweet,
            ),
          );
        }

        // React parity: /posts/:postId → PostDetailScreen(postId)
        if (segments.length == 2 && segments[0] == 'posts') {
          final postId = segments[1];
          debugPrint('[Router] → PostDetailScreen (posts) postId=$postId');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (ctx) => PostDetailScreen(postId: postId),
          );
        }

        // React parity: /reels/:reelId → ReelsScreen(initialReelId)
        if (segments.length == 2 && segments[0] == 'reels') {
          final reelId = segments[1];
          debugPrint('[Router] → ReelsScreen initialReelId=$reelId');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (ctx) => ReelsScreen(initialReelId: reelId),
          );
        }

        // Let Flutter handle anything else (404, etc.)
        debugPrint('[Router] No match for: $name');
        return null;
      },
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
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
