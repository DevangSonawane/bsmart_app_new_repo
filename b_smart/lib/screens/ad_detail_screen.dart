import 'package:flutter/material.dart';
import '../models/ad_model.dart';
import '../services/ads_service.dart';
import '../utils/current_user.dart';
import 'ads_page_screen.dart';

class AdDetailScreen extends StatefulWidget {
  final String adId;

  const AdDetailScreen({super.key, required this.adId});

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  final AdsService _adsService = AdsService();
  final ValueNotifier<bool> _viewPopupVisible = ValueNotifier<bool>(false);
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
    _viewPopupVisible.dispose();
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
    return Scaffold(
      backgroundColor: Colors.black,
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
                  viewPopupVisibleListenable: _viewPopupVisible,
                  onCompletedView: _recordView,
                  onOpenComments: _openComments,
                  onAutoNext: () {},
                )),
    );
  }
}
