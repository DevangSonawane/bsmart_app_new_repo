import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../api/ads_api.dart';
import '../api/api_client.dart';
import '../models/ad_model.dart';
import '../services/ads_service.dart';
import '../services/supabase_service.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import '../widgets/ad_public_gallery_section.dart';
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
  final SupabaseService _supabase = SupabaseService();
  final Map<String, Map<String, dynamic>> _userCache =
      <String, Map<String, dynamic>>{};

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _raw;
  Ad? _ad;

  bool _isMuted = true;
  VideoPlayerController? _controller;
  bool _isVideoReady = false;
  Map<String, String>? _mediaHeaders;

  bool _liked = false;
  int _likesCount = 0;
  bool _likeLoading = false;

  List<Ad> _vendorAds = const [];
  bool _vendorAdsLoading = false;

  List<Map<String, dynamic>> _topComments = const [];
  bool _commentsLoading = false;

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

  List<String> _extractGalleryUrls(Map<String, dynamic> raw, Ad ad) {
    final candidates = <dynamic>[];
    final gallery = raw['gallery'];
    final detail = raw['detail'];
    if (gallery is List && gallery.isNotEmpty) {
      candidates.addAll(gallery);
    } else if (detail is List && detail.isNotEmpty) {
      candidates.addAll(detail);
    }

    final out = <String>[];
    for (final item in candidates) {
      if (item is String) {
        final normalized = UrlHelper.normalizeUrl(item);
        if (normalized.isNotEmpty) out.add(normalized);
        continue;
      }
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final normalized = UrlHelper.normalizeUrl(
          (map['link'] ??
                  map['fileUrl'] ??
                  map['file_url'] ??
                  map['url'] ??
                  map['fileName'] ??
                  map['filename'] ??
                  map['path'])
              ?.toString(),
        );
        if (normalized.isNotEmpty) out.add(normalized);
        continue;
      }
    }

    // Fallback to parsed model fields.
    if (out.isEmpty) {
      out.addAll(ad.imageUrls.map(UrlHelper.normalizeUrl));
      final single = UrlHelper.normalizeUrl(ad.imageUrl);
      if (single.isNotEmpty) out.add(single);
    }

    // Dedupe preserve order.
    final seen = <String>{};
    final deduped = <String>[];
    for (final url in out) {
      final value = url.trim();
      if (value.isEmpty) continue;
      if (seen.add(value)) deduped.add(value);
    }
    return deduped;
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
      unawaited(_loadMediaHeadersIfNeeded());
      await _setupVideoIfNeeded();
      unawaited(_loadVendorAds());
      unawaited(_loadTopComments());
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
    await _loadMediaHeadersIfNeeded();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: UrlHelper.shouldAttachAuthHeader(url)
          ? (_mediaHeaders ?? const {})
          : const {},
    );
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

  Future<void> _loadMediaHeadersIfNeeded() async {
    if (_mediaHeaders != null) return;
    final ad = _ad;
    if (ad == null) return;
    final urls = <String>[
      (ad.videoUrl ?? '').trim(),
      (ad.imageUrl ?? '').trim(),
      ...ad.imageUrls.map((e) => e.trim()),
    ].where((e) => e.isNotEmpty).toList();
    if (!urls.any(UrlHelper.shouldAttachAuthHeader)) return;

    try {
      final token = await ApiClient().getToken();
      if (token != null && token.isNotEmpty) {
        _mediaHeaders = {'Authorization': 'Bearer $token'};
        if (mounted) setState(() {});
      }
    } catch (_) {
      // Non-blocking.
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

  Future<void> _loadTopComments() async {
    if (_commentsLoading) return;
    setState(() => _commentsLoading = true);
    try {
      final list = await _adsService.fetchAdComments(widget.adId);
      if (!mounted) return;
      final normalized = list.map((e) => Map<String, dynamic>.from(e)).toList();
      final hydrated = await _hydrateUsersInComments(normalized);
      if (!mounted) return;
      setState(() {
        _topComments = hydrated.take(3).toList();
        _commentsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _topComments = const [];
        _commentsLoading = false;
      });
    }
  }

  String _extractUserId(Map<String, dynamic> c) {
    String? fromMap(dynamic value) {
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);
        final id =
            (m['_id'] ?? m['id'] ?? m['user_id'] ?? m['userId'])?.toString();
        if (id != null && id.trim().isNotEmpty) return id.trim();
      }
      return null;
    }

    final direct = (c['user_id'] ??
        c['userId'] ??
        c['uid'] ??
        c['author_id'] ??
        c['authorId']);
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    if (direct is num) return direct.toString();
    if (direct is Map) {
      final id = fromMap(direct);
      if (id != null) return id;
    }
    final user = c['user'] ?? c['users'] ?? c['author'] ?? c['posted_by'];
    final id = fromMap(user);
    return id ?? '';
  }

  bool _hasName(Map<String, dynamic> u) {
    final v = (u['username'] ??
            u['userName'] ??
            u['user_name'] ??
            u['full_name'] ??
            u['fullName'] ??
            u['name'] ??
            u['business_name'] ??
            u['company_name'])
        ?.toString()
        .trim();
    return v != null && v.isNotEmpty;
  }

  Future<void> _primeUsers(Iterable<String> userIds) async {
    final missing = userIds
        .where((id) => id.isNotEmpty && !_userCache.containsKey(id))
        .toList();
    if (missing.isEmpty) return;

    final futures = <Future<void>>[];
    for (final id in missing) {
      futures.add(() async {
        try {
          final u = await _supabase.getUserById(id);
          if (u == null) return;
          _userCache[id] = Map<String, dynamic>.from(u);
        } catch (_) {}
      }());
    }
    await Future.wait(futures);
  }

  Future<List<Map<String, dynamic>>> _hydrateUsersInComments(
      List<Map<String, dynamic>> list) async {
    final ids = <String>{};
    for (final c in list) {
      final id = _extractUserId(c);
      if (id.isNotEmpty) ids.add(id);
    }
    await _primeUsers(ids);

    return list.map((c) {
      final next = Map<String, dynamic>.from(c);
      final uid = _extractUserId(next);
      if (uid.isEmpty) return next;
      final cached = _userCache[uid];
      if (cached == null) return next;
      final current = next['user'];
      if (current is Map) {
        final merged = Map<String, dynamic>.from(cached);
        merged.addAll(Map<String, dynamic>.from(current));
        next['user'] = merged;
      } else if (!_hasName(next['user'] is Map
          ? Map<String, dynamic>.from(next['user'] as Map)
          : <String, dynamic>{})) {
        next['user'] = cached;
      } else {
        next['user'] = cached;
      }
      return next;
    }).toList();
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
    final galleryUrls = _extractGalleryUrls(raw, ad);

    final mediaWidget = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const targetAspect = 2.0; // a little taller for the preview hero
          final width = constraints.maxWidth;
          final height = (width / targetAspect).clamp(180.0, 300.0);

          return SizedBox(
            height: height,
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
                                  : CachedNetworkImage(
                                      imageUrl: ad.imageUrl!,
                                      fit: BoxFit.cover,
                                      httpHeaders:
                                          UrlHelper.shouldAttachAuthHeader(
                                                  ad.imageUrl!)
                                              ? (_mediaHeaders ?? const {})
                                              : null,
                                      placeholder: (context, _) => const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                      errorWidget: (context, _, __) =>
                                          const Icon(
                                        Icons.broken_image,
                                        color: Colors.white54,
                                      ),
                                    ),
                        )
                      : (ad.imageUrl == null
                          ? const ColoredBox(color: Colors.black)
                          : CachedNetworkImage(
                              imageUrl: ad.imageUrl!,
                              fit: BoxFit.cover,
                              httpHeaders:
                                  UrlHelper.shouldAttachAuthHeader(ad.imageUrl!)
                                      ? (_mediaHeaders ?? const {})
                                      : null,
                              placeholder: (context, _) => const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, _, __) => const Icon(
                                Icons.broken_image,
                                color: Colors.white54,
                              ),
                            )),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
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
          );
        },
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
                  // CTA link icon intentionally removed from header.
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                    child: Transform.translate(
                      offset: const Offset(0, -8),
                      child: mediaWidget,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        if (captionPreview.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            captionPreview,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : Colors.black.withValues(alpha: 0.80),
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        ],
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.chevron_right, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _vendorAdsLoading
                              ? _VendorAdsSkeleton(isDark: isDark)
                              : _VendorAdsGrid(
                                  ads: _vendorAds,
                                  onTap: (id) => Navigator.of(context)
                                      .pushReplacementNamed('/ads/$id/details'),
                                ),
                          const SizedBox(height: 18),
                        ],
                        if (galleryUrls.isNotEmpty) ...[
                          AdPublicGallerySection(
                            urls: galleryUrls,
                            httpHeaders: galleryUrls
                                    .any(UrlHelper.shouldAttachAuthHeader)
                                ? (_mediaHeaders ?? const {})
                                : null,
                          ),
                          const SizedBox(height: 18),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ratings & Comments',
                                style: TextStyle(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _likeLoading ? null : _toggleLike,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _liked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color:
                                          _liked ? Colors.red : foregroundColor,
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
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () => _showComingSoon('Comments'),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
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
                          ],
                        ),
                        const SizedBox(height: 10),
                        _TopCommentsSection(
                          isDark: isDark,
                          commentsLoading: _commentsLoading,
                          comments: _topComments,
                        ),
                        if (_commentsLoading || _topComments.isNotEmpty)
                          const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopCommentsSection extends StatelessWidget {
  final bool isDark;
  final bool commentsLoading;
  final List<Map<String, dynamic>> comments;

  const _TopCommentsSection({
    required this.isDark,
    required this.commentsLoading,
    required this.comments,
  });

  String _pickText(Map<String, dynamic> raw) {
    final candidates = [
      raw['text'],
      raw['comment'],
      raw['message'],
      raw['content'],
    ];
    for (final c in candidates) {
      final v = c?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  Map<String, dynamic> _pickUser(Map<String, dynamic> raw) {
    final user = raw['user'] ?? raw['user_id'] ?? raw['author'];
    if (user is Map<String, dynamic>) return user;
    if (user is Map) return Map<String, dynamic>.from(user);
    return const <String, dynamic>{};
  }

  String _pickAvatarUrl(Map<String, dynamic> raw) {
    final user = _pickUser(raw);
    final candidates = [
      user['avatar_url'],
      user['avatarUrl'],
      user['photo'],
      user['profile_picture'],
      user['profilePicture'],
      raw['avatar_url'],
      raw['avatarUrl'],
    ];
    for (final c in candidates) {
      final v = c?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  String _pickUsername(Map<String, dynamic> raw) {
    final user = _pickUser(raw);
    final candidates = [
      user['username'],
      user['handle'],
      user['user_name'],
      user['name'],
      user['full_name'],
      user['fullName'],
      raw['username'],
      raw['user_name'],
      raw['name'],
    ];
    for (final c in candidates) {
      final v = c?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    if (!commentsLoading && comments.isEmpty) {
      final fg = isDark
          ? Colors.white.withValues(alpha: 0.72)
          : Colors.black.withValues(alpha: 0.62);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Most Comments',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No comments yet!',
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    final dividerColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black12;
    final skeletonLine =
        isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black12;

    final items = commentsLoading
        ? List.generate(3, (i) => const <String, dynamic>{})
        : comments.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Most Comments',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(height: 18, color: dividerColor),
          itemBuilder: (context, index) {
            final raw = items[index];
            final avatarUrl =
                commentsLoading ? '' : _pickAvatarUrl(Map.from(raw));
            final username =
                commentsLoading ? '' : _pickUsername(Map.from(raw));
            final text = commentsLoading ? '' : _pickText(Map.from(raw));
            return _TopCommentRow(
              isDark: isDark,
              avatarUrl: avatarUrl,
              username: username,
              text: text,
              skeletonLine: skeletonLine,
              loading: commentsLoading,
            );
          },
        ),
      ],
    );
  }
}

class _TopCommentRow extends StatelessWidget {
  final bool isDark;
  final String avatarUrl;
  final String username;
  final String text;
  final Color skeletonLine;
  final bool loading;

  const _TopCommentRow({
    required this.isDark,
    required this.avatarUrl,
    required this.username,
    required this.text,
    required this.skeletonLine,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBorder =
        isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black12;
    final textColor = isDark
        ? Colors.white.withValues(alpha: 0.86)
        : Colors.black.withValues(alpha: 0.80);

    final name = (username.trim().isEmpty ? 'User' : username.trim());
    final initials = name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 38,
          height: 38,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: avatarBorder),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            child: ClipOval(
              child: !loading && avatarUrl.trim().isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox.expand(),
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: loading
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 10,
                      width: MediaQuery.of(context).size.width * 0.32,
                      decoration: BoxDecoration(
                        color: skeletonLine,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: skeletonLine,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: MediaQuery.of(context).size.width * 0.60,
                      decoration: BoxDecoration(
                        color: skeletonLine,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: MediaQuery.of(context).size.width * 0.72,
                      decoration: BoxDecoration(
                        color: skeletonLine,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                )
              : Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: name,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: text.trim().isEmpty ? '-' : text.trim(),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
        ),
      ],
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
