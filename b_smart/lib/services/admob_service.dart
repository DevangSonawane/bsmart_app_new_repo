import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';

class AdMobService {
  AdMobService._();

  static final AdMobService instance = AdMobService._();

  bool _initialized = false;
  bool _loadingInterstitial = false;
  InterstitialAd? _interstitialAd;

  bool get _isMobileSupported {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return false;
    }
  }

  Future<void> initialize() async {
    if (!_isMobileSupported || _initialized) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
    } catch (e, st) {
      debugPrint('AdMob initialization failed: $e');
      debugPrint(st.toString());
      return;
    }
    preloadInterstitial();
  }

  void preloadInterstitial() {
    if (!_isMobileSupported ||
        _loadingInterstitial ||
        _interstitialAd != null) {
      return;
    }
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint('Interstitial ad showed.');
            },
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (_interstitialAd == ad) {
                _interstitialAd = null;
              }
              preloadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Interstitial failed to show: $error');
              ad.dispose();
              if (_interstitialAd == ad) {
                _interstitialAd = null;
              }
              preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _loadingInterstitial = false;
          debugPrint('Interstitial failed to load: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<void> showInterstitialAfterSuccessfulPublish() async {
    if (!_isMobileSupported) return;
    final ad = _interstitialAd;
    if (ad == null) {
      preloadInterstitial();
      return;
    }
    _interstitialAd = null;
    try {
      ad.show();
    } catch (e, st) {
      debugPrint('Interstitial show threw: $e');
      debugPrint(st.toString());
      ad.dispose();
      preloadInterstitial();
    }
  }

  Future<void> showInterstitialAfterPostPublish() async {
    await showInterstitialAfterSuccessfulPublish();
  }

  @Deprecated('Use showInterstitialAfterSuccessfulPublish')
  Future<void> recordSuccessfulPostAndMaybeShowInterstitial({
    required String userId,
  }) async {
    await showInterstitialAfterSuccessfulPublish();
  }
}