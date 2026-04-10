import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../api/ads_api.dart';
import '../models/ad_model.dart';
import '../services/ads_service.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import '../widgets/ad_cta_buttons.dart';
import 'external_link_screen.dart';

class AdPublicDetailScreen extends StatefulWidget {
  final String adId;

  const AdPublicDetailScreen({
    super.key,
    required this.adId,
  });

  @override
  State<AdPublicDetailScreen> createState() => _AdPublicDetailScreenState();
}

class _AdPublicDetailScreenState extends State<AdPublicDetailScreen> {
  final AdsApi _adsApi = AdsApi();
  final AdsService _adsService = AdsService();

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _raw;
  Ad? _ad;

  bool _isMuted = true;
  VideoPlayerController? _controller;
  bool _isVideoReady = false;

  bool _liked = false;
  int _likesCount = 0;
  bool _likeLoading = false;

  List<Ad> _vendorAds = const [];
  bool _vendorAdsLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  Future<void> _load() async {
    final id = widget.adId.trim();
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Invalid ad id';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final raw = await _adsApi.getAdById(id);
      final ad = raw == null ? null : Ad.fromApi(raw);
      if (!mounted) return;
      setState(() {
        _raw = raw;
        _ad = ad;
        _liked = ad?.isLikedByMe ?? false;
        _likesCount = ad?.likesCount ?? 0;
        _loading = false;
      });
      await _setupVideoIfNeeded();
      unawaited(_loadVendorAds());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load ad.';
        _loading = false;
      });
    }
  }

  Future<void> _setupVideoIfNeeded() async {
    final ad = _ad;
    if (ad == null) return;
    final url = (ad.videoUrl ?? '').trim();
    if (url.isEmpty) return;

    _controller?.dispose();
    _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.setVolume(_isMuted ? 0 : 1);
      if (!mounted) return;
      setState(() {
        _isVideoReady = true;
      });
      unawaited(_controller!.play());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVideoReady = false;
      });
    }
  }

  String? _vendorUserId(Map<String, dynamic> raw) {
    final user = _map(raw['user_id']);
    final vendor = _map(raw['vendor_id']);
    final uid = (user['_id'] ??
            user['id'] ??
            vendor['_id'] ??
            vendor['id'] ??
            raw['user_id'] ??
            raw['vendor_id'])
        ?.toString()
        .trim();
    if (uid == null || uid.isEmpty || uid == 'null') return null;
    return uid;
  }

  Future<void> _loadVendorAds() async {
    if (_vendorAdsLoading) return;
    final raw = _raw;
    if (raw == null) return;
    final uid = _vendorUserId(raw);
    if (uid == null) return;

    setState(() {
      _vendorAdsLoading = true;
    });
    try {
      final list = await _adsService.fetchUserAds(userId: uid);
      if (!mounted) return;
      setState(() {
        _vendorAds = list.where((a) => a.id != widget.adId).take(6).toList();
        _vendorAdsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vendorAds = const [];
        _vendorAdsLoading = false;
      });
    }
  }

  Future<void> _trackClick() async {
    try {
      await _adsService.recordAdClick(adId: widget.adId);
    } catch (_) {}
  }

  Map<String, dynamic> _cta(Map<String, dynamic> raw) => _map(raw['cta']);

  String _compactCount(int value) {
    if (value < 1000) return value.toString();
    if (value < 1000000) {
      final v = value / 1000;
      final s = v.toStringAsFixed(v >= 10 ? 0 : 1);
      return '${s}K';
    }
    final v = value / 1000000;
    final s = v.toStringAsFixed(v >= 10 ? 0 : 1);
    return '${s}M';
  }

  String _titleCaseWords(String value) {
    final s = value.trim();
    if (s.isEmpty) return s;
    final parts =
        s.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
    return parts
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  String _ctaLabel(String type) {
    switch (type) {
      case 'view_site':
        return 'Visit Website';
      case 'call_now':
        return 'Call Now';
      case 'install_app':
        return 'Install App';
      case 'book_now':
        return 'Book Now';
      case 'contact_info':
        return 'Contact Us';
      case 'learn_more':
      default:
        return 'Learn More';
    }
  }

  Future<void> _handleCtaTap() async {
    final raw = _raw;
    if (raw == null) return;
    final cta = _cta(raw);
    final type = (cta['type'] ?? '').toString().trim();
    if (type.isEmpty) return;

    await _trackClick();

    if (type == 'call_now') {
      final phone = (cta['phone_number'] ?? '').toString().trim();
      if (phone.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: phone));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone copied')),
        );
      }
      return;
    }
    if (type == 'contact_info') {
      final email = (cta['email'] ?? '').toString().trim();
      if (email.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: email));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email copied')),
        );
      }
      return;
    }

    final url = UrlHelper.absoluteUrl(
      (cta['url'] ?? cta['deep_link'] ?? '').toString().trim(),
    );
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExternalLinkScreen(
          url: url,
          title: _ctaLabel(type),
        ),
      ),
    );
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    final ad = _ad;
    if (ad == null) return;
    final userId = await CurrentUser.id;
    if (userId == null || userId.trim().isEmpty) return;

    final prevLiked = _liked;
    setState(() {
      _likeLoading = true;
      _liked = !prevLiked;
      _likesCount =
          prevLiked ? (_likesCount - 1).clamp(0, 1 << 30) : _likesCount + 1;
    });
    try {
      if (!prevLiked) {
        await _adsService.likeAd(adId: ad.id, userId: userId);
      } else {
        await _adsService.dislikeAd(adId: ad.id, userId: userId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = prevLiked;
        _likesCount = ad.likesCount;
      });
    } finally {
      if (mounted) {
        setState(() {
          _likeLoading = false;
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null || !_isVideoReady) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _isMuted = !_isMuted);
    try {
      await controller.setVolume(_isMuted ? 0 : 1);
    } catch (_) {}
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : const Color(0xFFF7F7F7);
    final foregroundColor = isDark ? Colors.white : const Color(0xFF111111);
    final mutedForegroundColor = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : Colors.black.withValues(alpha: 0.70);
    final glassFill = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.10);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null || _ad == null || _raw == null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F7),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error ?? 'Ad not found.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final raw = _raw!;
    final ad = _ad!;
    final uid = _vendorUserId(raw);
    final businessName = (ad.vendorBusinessName ?? ad.companyName).trim();
    final cta = _cta(raw);
    final ctaType = (cta['type'] ?? '').toString().trim();
    final displayName = (ad.userName ?? '').trim().isNotEmpty
        ? (ad.userName ?? '').trim()
        : (businessName.isNotEmpty ? businessName : 'Vendor');
    final statusRaw = (raw['status'] ?? '').toString().trim();
    final statusKey = statusRaw.isEmpty
        ? (ad.isActive ? 'active' : 'inactive')
        : statusRaw.toLowerCase();
    final statusLabel = _titleCaseWords(statusKey.replaceAll('_', ' '));
    final statusIsActive = statusKey == 'active';
    final caption = (ad.caption ?? '').trim();
    final captionPreview = caption.isEmpty
        ? ''
        : caption.split('\n').take(4).join('\n').trimRight();

    final hasVideo = (ad.videoUrl ?? '').trim().isNotEmpty;
    final mediaWidget = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Stack(
          children: [
            Positioned.fill(
              child: hasVideo
                  ? ColoredBox(
                      color: Colors.black,
                      child: _isVideoReady && _controller != null
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
                          : ad.imageUrl == null
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : Image.network(ad.imageUrl!, fit: BoxFit.cover),
                    )
                  : (ad.imageUrl == null
                      ? const ColoredBox(color: Colors.black)
                      : Image.network(ad.imageUrl!, fit: BoxFit.cover)),
            ),
            if (hasVideo)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _togglePlayPause,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: const Text(
                  'Ad',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasVideo)
                    InkWell(
                      onTap: _toggleMute,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (hasVideo && _controller != null && _isVideoReady)
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: Colors.white.withValues(alpha: 0.92),
                      bufferedColor: Colors.white.withValues(alpha: 0.25),
                      backgroundColor: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),
            if (hasVideo && _controller != null && _isVideoReady)
              AnimatedOpacity(
                opacity: _controller!.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back,
                        color: foregroundColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: glassFill,
                          backgroundImage:
                              (ad.userAvatarUrl ?? '').trim().isEmpty
                                  ? null
                                  : NetworkImage(ad.userAvatarUrl!),
                          child: (ad.userAvatarUrl ?? '').trim().isEmpty
                              ? Text(
                                  displayName.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: foregroundColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foregroundColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (ad.isVerified) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0095F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.verified,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusIsActive
                          ? (isDark
                              ? const Color(0xFF0B2A1E)
                              : const Color(0xFFE7F9F1))
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: statusIsActive
                            ? (isDark
                                ? const Color(0xFF0E3A28)
                                : const Color(0xFFBDE9D4))
                            : glassBorder,
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusIsActive
                            ? (isDark
                                ? const Color(0xFF53E3A6)
                                : const Color(0xFF0F8F5E))
                            : mutedForegroundColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                children: [
                  mediaWidget,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      InkWell(
                        onTap: _likeLoading ? null : _toggleLike,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _liked ? Icons.favorite : Icons.favorite_border,
                                color: _liked ? Colors.red : foregroundColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _compactCount(_likesCount),
                                style: TextStyle(
                                  color: mutedForegroundColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      InkWell(
                        onTap: () => _showComingSoon('Comments'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.mode_comment_outlined,
                                color: foregroundColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _compactCount(ad.commentsCount),
                                style: TextStyle(
                                  color: mutedForegroundColor,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            color: foregroundColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _compactCount(ad.currentViews),
                            style: TextStyle(
                              color: mutedForegroundColor,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _VendorRow(
                    uid: uid,
                    vendorName: businessName.isNotEmpty
                        ? businessName
                        : (ad.companyName.trim().isNotEmpty
                            ? ad.companyName.trim()
                            : displayName),
                    username: (ad.userName ?? '').trim().isNotEmpty
                        ? (ad.userName ?? '').trim()
                        : 'vendor',
                    avatarUrl: (ad.userAvatarUrl ?? '').trim(),
                    isVerified: ad.isVerified,
                    foregroundColor: foregroundColor,
                    mutedForegroundColor: mutedForegroundColor,
                    borderColor: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.12),
                    onViewProfile: uid == null
                        ? null
                        : () {
                            unawaited(_trackClick());
                            Navigator.of(context)
                                .pushNamed('/vendor/$uid/public');
                          },
                  ),
                  const SizedBox(height: 14),
                  if (ad.title.trim().isNotEmpty)
                    Text(
                      ad.title.trim(),
                      style: TextStyle(
                        color: foregroundColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        height: 1.15,
                      ),
                    ),
                  if (ad.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      ad.description.trim(),
                      style: TextStyle(
                        color: mutedForegroundColor,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (ctaType.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: AdGradientCtaButton(
                        onPressed: _handleCtaTap,
                        icon: ctaType == 'call_now'
                            ? Icons.phone_in_talk_outlined
                            : ctaType == 'contact_info'
                                ? Icons.mail_outline
                                : Icons.open_in_new,
                        label: _ctaLabel(ctaType),
                        boxShadow: const [],
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 14),
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  if ((cta['whatsapp_number'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty ||
                      (cta['phone_number'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty ||
                      (cta['email'] ?? '').toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if ((cta['whatsapp_number'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          _ActionChip(
                            icon: Icons.chat_bubble_outline,
                            label: 'WhatsApp',
                            tint: const Color(0xFF16C784),
                            onTap: () {
                              final digits = (cta['whatsapp_number'] ?? '')
                                  .toString()
                                  .replaceAll(RegExp(r'\D'), '')
                                  .trim();
                              if (digits.isEmpty) return;
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ExternalLinkScreen(
                                    url: 'https://wa.me/$digits',
                                    title: 'WhatsApp',
                                  ),
                                ),
                              );
                            },
                          ),
                        if ((cta['phone_number'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          _ActionChip(
                            icon: Icons.phone_outlined,
                            label: 'Call',
                            tint: const Color(0xFF1D9BF0),
                            onTap: () async {
                              final phone =
                                  (cta['phone_number'] ?? '').toString().trim();
                              if (phone.isEmpty) return;
                              await Clipboard.setData(
                                ClipboardData(text: phone),
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Phone copied')),
                              );
                            },
                          ),
                        if ((cta['email'] ?? '').toString().trim().isNotEmpty)
                          _ActionChip(
                            icon: Icons.mail_outline,
                            label: 'Email',
                            tint: const Color(0xFF8B5CF6),
                            onTap: () async {
                              final email =
                                  (cta['email'] ?? '').toString().trim();
                              if (email.isEmpty) return;
                              await Clipboard.setData(
                                ClipboardData(text: email),
                              );
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Email copied')),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  _HighlightsSection(
                    isDark: isDark,
                    mutedForegroundColor: mutedForegroundColor,
                    raw: raw,
                    fallbackStatus: statusKey,
                  ),
                  const SizedBox(height: 14),
                  if (captionPreview.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CAPTION',
                            style: TextStyle(
                              color: mutedForegroundColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            captionPreview,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : Colors.black.withValues(alpha: 0.80),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _TagsSection(
                    isDark: isDark,
                    raw: raw,
                    fallbackTags: ad.hashtags,
                  ),
                  const SizedBox(height: 18),
                  if (_vendorAdsLoading || _vendorAds.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'More from ${displayName.trim()}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foregroundColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: uid == null
                              ? null
                              : () {
                                  unawaited(_trackClick());
                                  Navigator.of(context)
                                      .pushNamed('/vendor/$uid/public');
                                },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFEC4899),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'See all',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_vendorAdsLoading)
                      _VendorAdsSkeleton(isDark: isDark)
                    else
                      _VendorAdsGrid(
                        ads: _vendorAds,
                        onTap: (id) => Navigator.of(context)
                            .pushReplacementNamed('/ads/$id/details'),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill =
        isDark ? tint.withValues(alpha: 0.16) : tint.withValues(alpha: 0.10);
    final border =
        isDark ? tint.withValues(alpha: 0.28) : tint.withValues(alpha: 0.30);
    final fg =
        isDark ? tint.withValues(alpha: 0.95) : tint.withValues(alpha: 0.90);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightsSection extends StatelessWidget {
  final bool isDark;
  final Color mutedForegroundColor;
  final Map<String, dynamic> raw;
  final String fallbackStatus;

  const _HighlightsSection({
    required this.isDark,
    required this.mutedForegroundColor,
    required this.raw,
    required this.fallbackStatus,
  });

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }

  String _titleCaseWords(String value) {
    final s = value.trim();
    if (s.isEmpty) return s;
    final parts =
        s.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
    return parts
        .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final category = (raw['category'] ?? '').toString().trim();
    final location = (raw['location'] ?? '').toString().trim();
    final type = (raw['ad_type'] ?? raw['type'] ?? '').toString().trim();
    final langs = _stringList(raw['target_language']);
    final statusKey = (raw['status'] ?? '').toString().trim().isEmpty
        ? fallbackStatus
        : (raw['status'] ?? '').toString().trim().toLowerCase();
    final statusLabel = _titleCaseWords(statusKey.replaceAll('_', ' '));
    final typeLabel = _titleCaseWords(type.replaceAll('_', ' '));

    final items = <_HighlightItem>[
      if (category.isNotEmpty)
        _HighlightItem(
          label: 'Category',
          value: category,
          icon: Icons.local_offer_outlined,
          tint: const Color(0xFF8B5CF6),
        ),
      if (location.isNotEmpty)
        _HighlightItem(
          label: 'Location',
          value: location,
          icon: Icons.place_outlined,
          tint: const Color(0xFFFB7185),
        ),
      if (type.isNotEmpty)
        _HighlightItem(
          label: 'Type',
          value: typeLabel,
          icon: Icons.play_circle_outline,
          tint: const Color(0xFFF59E0B),
        ),
      if (langs.isNotEmpty)
        _HighlightItem(
          label: 'Language',
          value: langs.take(2).join(', '),
          icon: Icons.public_outlined,
          tint: const Color(0xFF3B82F6),
        ),
      if (statusLabel.isNotEmpty)
        _HighlightItem(
          label: 'Status',
          value: statusLabel,
          icon: Icons.verified_outlined,
          tint: const Color(0xFF10B981),
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 520 ? 3 : 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOP HIGHLIGHTS',
              style: TextStyle(
                color: mutedForegroundColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                // Slightly taller to avoid minor render overflows on small devices.
                childAspectRatio: 2.05,
              ),
              itemBuilder: (_, i) => _HighlightCard(
                item: items[i],
                isDark: isDark,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HighlightItem {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  const _HighlightItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
  });
}

class _HighlightCard extends StatelessWidget {
  final _HighlightItem item;
  final bool isDark;

  const _HighlightCard({
    required this.item,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fill = isDark
        ? item.tint.withValues(alpha: 0.14)
        : item.tint.withValues(alpha: 0.08);
    final border = isDark
        ? item.tint.withValues(alpha: 0.22)
        : item.tint.withValues(alpha: 0.20);
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.45);
    final valueColor = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.80);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 16, color: item.tint.withValues(alpha: 0.9)),
          const SizedBox(height: 4),
          Text(
            item.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              fontSize: 9,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagsSection extends StatelessWidget {
  final bool isDark;
  final Map<String, dynamic> raw;
  final List<String> fallbackTags;

  const _TagsSection({
    required this.isDark,
    required this.raw,
    required this.fallbackTags,
  });

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final tags = _stringList(raw['tags']);
    final hashtags = _stringList(raw['hashtags']);
    final list = (tags.isNotEmpty
            ? tags
            : (hashtags.isNotEmpty ? hashtags : fallbackTags))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();

    final chipFill = isDark ? const Color(0xFF3B1023) : const Color(0xFFFFE4EF);
    final chipFg = isDark ? const Color(0xFFF472B6) : const Color(0xFFEC4899);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: list.take(16).map((h) {
        final text = h.startsWith('#') ? h : '#$h';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipFill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: chipFg,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _VendorAdsSkeleton extends StatelessWidget {
  final bool isDark;
  const _VendorAdsSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 9 / 16,
      ),
      itemBuilder: (_, __) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(color: base),
      ),
    );
  }
}

class _VendorAdsGrid extends StatelessWidget {
  final List<Ad> ads;
  final void Function(String id) onTap;

  const _VendorAdsGrid({
    required this.ads,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 720 ? 6 : (width >= 520 ? 4 : 3);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ads.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 9 / 16,
          ),
          itemBuilder: (_, i) {
            final ad = ads[i];
            final thumb = (ad.imageUrl ?? '').trim();
            final isVideo = (ad.videoUrl ?? '').trim().isNotEmpty;
            return InkWell(
              onTap: () => onTap(ad.id),
              borderRadius: BorderRadius.circular(14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: thumb.isEmpty
                          ? ColoredBox(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                            )
                          : Image.network(thumb, fit: BoxFit.cover),
                    ),
                    if (isVideo)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _VendorRow extends StatelessWidget {
  final String? uid;
  final String vendorName;
  final String username;
  final String avatarUrl;
  final bool isVerified;
  final Color foregroundColor;
  final Color mutedForegroundColor;
  final Color borderColor;
  final VoidCallback? onViewProfile;

  const _VendorRow({
    required this.uid,
    required this.vendorName,
    required this.username,
    required this.avatarUrl,
    required this.isVerified,
    required this.foregroundColor,
    required this.mutedForegroundColor,
    required this.borderColor,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final canNavigate = onViewProfile != null;
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: canNavigate ? onViewProfile : null,
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFB923C),
                        Color(0xFFEC4899),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: avatarUrl.isNotEmpty
                        ? Image.network(avatarUrl, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              vendorName.trim().isEmpty
                                  ? 'V'
                                  : vendorName
                                      .trim()
                                      .substring(0, 1)
                                      .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              vendorName.trim().isEmpty
                                  ? 'Vendor'
                                  : vendorName.trim(),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: foregroundColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0095F6),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.verified,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedForegroundColor.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: onViewProfile,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            side: BorderSide(color: borderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: Text(
            'View Profile',
            style: TextStyle(
              color: mutedForegroundColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
