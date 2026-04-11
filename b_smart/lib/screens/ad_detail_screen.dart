import 'package:flutter/material.dart';
import '../models/ad_model.dart';
import '../services/ads_service.dart';
import '../utils/current_user.dart';
import '../widgets/app_popups/popup_visibility_controller.dart';
import 'ads_page_screen.dart';

class AdDetailScreen extends StatefulWidget {
  final String adId;

  const AdDetailScreen({super.key, required this.adId});

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  final AdsService _adsService = AdsService();
  final PopupVisibilityController _popupVisibility = PopupVisibilityController();
  Ad? _ad;
  bool _loading = true;
  bool _viewRecorded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _popupVisibility.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final adId = widget.adId.trim();
    if (adId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final ad = await _adsService.fetchAdById(adId);
      if (!mounted) return;
      setState(() {
        _ad = ad;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ad = null;
        _loading = false;
      });
    }
  }

  Future<void> _recordView() async {
    if (_viewRecorded) return;
    final ad = _ad;
    if (ad == null || ad.id.isEmpty) return;
    final userId = await CurrentUser.id;
    if (userId == null || userId.trim().isEmpty) return;
    _viewRecorded = true;
    try {
      await _adsService.recordAdView(adId: ad.id, userId: userId);
    } catch (_) {
      _viewRecorded = false;
    }
  }

  Future<void> _openComments() async {
    final ad = _ad;
    if (ad == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: AdCommentsSheet(adId: ad.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final devicePixelRatio = view.devicePixelRatio;
    final viewPaddingBottom = view.padding.bottom / devicePixelRatio;
    final mq = MediaQuery.of(context);
    final mqViewPaddingBottom = mq.viewPadding.bottom;
    final mqPaddingBottom = mq.padding.bottom;
    double bottomSystemInset = viewPaddingBottom;
    if (mqViewPaddingBottom > bottomSystemInset) {
      bottomSystemInset = mqViewPaddingBottom;
    }
    if (mqPaddingBottom > bottomSystemInset) {
      bottomSystemInset = mqPaddingBottom;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Ad'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : (_ad == null
              ? const Center(
                  child: Text(
                    'Ad not found',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : AdVideoItem(
                  ad: _ad!,
                  isActive: true,
                  bottomInset: bottomSystemInset,
                  popupVisibility: _popupVisibility,
                  onCompletedView: _recordView,
                  onOpenComments: _openComments,
                  onAutoNext: () {},
                )),
    );
  }
}
