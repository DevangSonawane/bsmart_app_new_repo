import 'package:flutter/foundation.dart';

class AdConfig {
  static const String androidAppId = 'ca-app-pub-6848080783292385~6565575168';
  static const String iosAppId = 'ca-app-pub-6848080783292385~9100696019';

  static const String _bannerTestAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _bannerIosTestAdUnitId =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _interstitialTestAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _interstitialIosTestAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _nativeTestAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _nativeIosTestAdUnitId =
      'ca-app-pub-3940256099942544/3986624511';

  static const String _bannerProductionAdUnitId =
      'ca-app-pub-6848080783292385/7997699035';
  static const String _bannerIosProductionAdUnitId =
      'ca-app-pub-6848080783292385/2085072970';
  static const String _interstitialProductionAdUnitId =
      'ca-app-pub-6848080783292385/5739578658';
  static const String _interstitialIosProductionAdUnitId =
      'ca-app-pub-6848080783292385/1603630749';
  static const String _nativeProductionAdUnitId =
      'ca-app-pub-6848080783292385/7115862201';
  static const String _nativeIosProductionAdUnitId =
      'ca-app-pub-6848080783292385/9667672221';

  static const String nativeAdFactoryId = 'bsmart_native_ad_factory';

  static bool get useProductionAds => kReleaseMode;

  static String get bannerAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return useProductionAds
            ? _bannerIosProductionAdUnitId
            : _bannerIosTestAdUnitId;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return useProductionAds
            ? _bannerProductionAdUnitId
            : _bannerTestAdUnitId;
    }
  }

  static String get interstitialAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return useProductionAds
            ? _interstitialIosProductionAdUnitId
            : _interstitialIosTestAdUnitId;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return useProductionAds
            ? _interstitialProductionAdUnitId
            : _interstitialTestAdUnitId;
    }
  }

  static String get nativeAdUnitId {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return useProductionAds
            ? _nativeIosProductionAdUnitId
            : _nativeIosTestAdUnitId;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return useProductionAds
            ? _nativeProductionAdUnitId
            : _nativeTestAdUnitId;
    }
  }
}