import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../api/api_client.dart';
import '../models/ad_model.dart';
import '../services/ads_service.dart';
import '../utils/current_user.dart';
import '../utils/timezone_service.dart';
import '../utils/url_helper.dart';
import 'ads_page_screen.dart';

class AdDetailScreen extends StatefulWidget {
  final String adId;

  const AdDetailScreen({super.key, required this.adId});

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  final AdsService _adsService = AdsService();
  Ad? _ad;
  bool _loading = true;
  bool _viewRecorded = false;
  Map<String, String>? _mediaHeaders;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final adId = widget.adId.trim();
    if (adId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      await _loadMediaHeaders();
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

  Future<void> _loadMediaHeaders() async {
    if (_mediaHeaders != null) return;
    final token = await ApiClient().getToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      setState(() {
        _mediaHeaders = {'Authorization': 'Bearer $token'};
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
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Ad Details'),
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
              : _AdDetailBody(
                  ad: _ad!,
                  mediaHeaders: _mediaHeaders,
                  onRecordView: _recordView,
                  onOpenComments: _openComments,
                )),
    );
  }
}

class _AdDetailBody extends StatelessWidget {
  final Ad ad;
  final Map<String, String>? mediaHeaders;
  final Future<void> Function() onRecordView;
  final Future<void> Function() onOpenComments;

  const _AdDetailBody({
    required this.ad,
    required this.mediaHeaders,
    required this.onRecordView,
    required this.onOpenComments,
  });

  @override
  Widget build(BuildContext context) {
    final createdAt = ad.createdAt;
    final createdText = TimezoneService.instance.formatDate(createdAt);

    final caption = (ad.caption ?? ad.description).trim();
    final title = ad.title.trim();
    final vendor = (ad.vendorBusinessName ?? ad.companyName).trim();

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdPreviewCard(
              ad: ad,
              mediaHeaders: mediaHeaders,
              onRecordView: onRecordView,
            ),
            const SizedBox(height: 14),
            if (vendor.isNotEmpty)
              Text(
                vendor,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (vendor.isNotEmpty) const SizedBox(height: 6),
            if (title.isNotEmpty)
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                _MetaPill(
                  icon: Icons.schedule,
                  text: createdText,
                ),
                const SizedBox(width: 8),
                _MetaPill(
                  icon: Icons.monetization_on_outlined,
                  text: '${ad.coinReward} coins',
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => onOpenComments(),
                  icon: const Icon(Icons.chat_bubble_outline),
                  color: Colors.white.withValues(alpha: 0.85),
                  tooltip: 'Comments',
                ),
              ],
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                caption,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
            if (ad.hashtags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ad.hashtags
                    .where((t) => t.trim().isNotEmpty)
                    .take(12)
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '#${tag.trim().replaceAll('#', '')}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdPreviewCard extends StatefulWidget {
  final Ad ad;
  final Map<String, String>? mediaHeaders;
  final Future<void> Function() onRecordView;

  const _AdPreviewCard({
    required this.ad,
    required this.mediaHeaders,
    required this.onRecordView,
  });

  @override
  State<_AdPreviewCard> createState() => _AdPreviewCardState();
}

class _AdPreviewCardState extends State<_AdPreviewCard> {
  static const _radius = 18.0;
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _muted = true;

  bool get _isVideoAd {
    final url = widget.ad.videoUrl?.trim() ?? '';
    return url.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _initVideoIfNeeded();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Count opening the detail page as a view; feed gating (if any) still applies elsewhere.
      widget.onRecordView();
    });
  }

  @override
  void didUpdateWidget(covariant _AdPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.id != widget.ad.id ||
        oldWidget.ad.videoUrl != widget.ad.videoUrl) {
      _disposeController();
      _ready = false;
      _failed = false;
      _muted = true;
      _initVideoIfNeeded();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onTick);
      unawaited(controller.dispose());
    }
  }

  VideoFormat? _videoFormatHintForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return VideoFormat.hls;
    if (lower.contains('.mpd')) return VideoFormat.dash;
    return null;
  }

  Future<void> _initVideoIfNeeded() async {
    if (!_isVideoAd) return;
    final url = widget.ad.videoUrl?.trim() ?? '';
    if (url.isEmpty) return;

    try {
      final needsAuth = UrlHelper.shouldAttachAuthHeader(url);
      final headers = needsAuth
          ? (widget.mediaHeaders ?? const <String, String>{})
          : const <String, String>{};

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
        formatHint: _videoFormatHintForUrl(url),
      );
      _controller = controller;
      await controller.initialize();
      controller.addListener(_onTick);
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _onTick() {
    // Keep this lightweight; the preview is small and doesn't need extra UI updates.
    // This exists to avoid some platform players stalling without a listener.
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_muted;
    setState(() => _muted = next);
    try {
      await controller.setVolume(next ? 0 : 1);
    } catch (_) {}
  }

  Widget _buildImageFallback() {
    final urls = widget.ad.imageUrls;
    final fallback = widget.ad.imageUrl?.trim();
    final hasFallback = fallback != null && fallback.isNotEmpty;
    final hasUrls = urls.isNotEmpty;

    if (!hasUrls && !hasFallback) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    Map<String, String>? headersFor(String url) {
      if (!UrlHelper.shouldAttachAuthHeader(url)) return null;
      return widget.mediaHeaders ?? const {};
    }

    final fallbackUrl =
        (fallback != null && fallback.isNotEmpty) ? fallback : null;
    final url = fallbackUrl ?? urls.first;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      httpHeaders: headersFor(url),
      placeholder: (context, _) => const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      errorWidget: (context, _, __) => const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.broken_image, color: Colors.white54),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = _isVideoAd
        ? (_ready && _controller != null
            ? ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            : (_failed
                ? _buildImageFallback()
                : const ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )))
        : _buildImageFallback();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const targetAspect = 2.7; // more horizontal like the screenshot
            final width = constraints.maxWidth;
            final height = (width / targetAspect).clamp(120.0, 200.0);

            return SizedBox(
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  media,
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: const Text(
                        'Ad',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (_isVideoAd)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleMute,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              _muted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white.withValues(alpha: 0.9),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
