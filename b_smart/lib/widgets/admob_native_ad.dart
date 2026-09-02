import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';

class AdMobNativeAd extends StatefulWidget {
  final EdgeInsetsGeometry margin;

  const AdMobNativeAd({
    super.key,
    this.margin = const EdgeInsets.fromLTRB(12, 8, 12, 8),
  });

  @override
  State<AdMobNativeAd> createState() => _AdMobNativeAdState();
}

class _AdMobNativeAdState extends State<AdMobNativeAd> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _hasError = false;

  bool get _supportsAds {
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

  @override
  void initState() {
    super.initState();
    if (_supportsAds) {
      _loadAd();
    }
  }

  void _loadAd() {
    final nativeAd = NativeAd(
      adUnitId: AdConfig.nativeAdUnitId,
      factoryId: AdConfig.nativeAdFactoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoaded = true;
            _hasError = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _nativeAd = null;
            _isLoaded = false;
            _hasError = true;
          });
          debugPrint('Native ad failed to load: $error');
        },
      ),
    );
    nativeAd.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsAds) return const SizedBox.shrink();
    if (_hasError) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final outline = theme.colorScheme.outlineVariant.withValues(alpha: 0.7);
    final ad = _nativeAd;

    return Padding(
      padding: widget.margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Text(
                    'Sponsored',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (!_isLoaded)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (ad != null)
              SizedBox(
                height: 400,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                  child: AdWidget(ad: ad),
                ),
              )
            else
              const SizedBox(height: 220),
          ],
        ),
      ),
    );
  }
}