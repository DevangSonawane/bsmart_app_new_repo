import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/vendors_api.dart';
import '../api/notification_preferences_api.dart';
import '../models/ad_model.dart';
import '../services/ads_service.dart';
import '../utils/url_helper.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../widgets/ad_cta_buttons.dart';
import 'external_link_screen.dart';

class VendorPublicProfileReactScreen extends StatefulWidget {
  final String userId;

  const VendorPublicProfileReactScreen({
    super.key,
    required this.userId,
  });

  @override
  State<VendorPublicProfileReactScreen> createState() =>
      _VendorPublicProfileReactScreenState();
}

class _VendorPublicProfileReactScreenState
    extends State<VendorPublicProfileReactScreen>
    with SingleTickerProviderStateMixin {
  final VendorsApi _vendorsApi = VendorsApi();
  final AdsService _adsService = AdsService();
  final NotificationPreferencesApi _prefsApi = NotificationPreferencesApi();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  String? _vendorUserId;

  late final TabController _tabController;

  final PageController _coverController = PageController();
  Timer? _coverAutoplayTimer;
  int _coverIndex = 0;

  bool _adsLoading = false;
  String? _adsError;
  List<Ad> _ads = const [];

  bool _galleryLoading = false;
  String? _galleryError;
  List<String> _galleryUrls = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _coverAutoplayTimer?.cancel();
    _coverController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) return [raw.trim()];
    return const <String>[];
  }

  int? _tryParseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  int _readCount(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      if (data.containsKey(k)) {
        final v = _tryParseInt(data[k]);
        if (v != null) return v;
      }
    }
    return 0;
  }

  Future<void> _load() async {
    final uid = widget.userId.trim();
    if (uid.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Invalid vendor id';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
      _vendorUserId = null;
    });

    try {
      final data = await _vendorsApi.getVendorPublicProfile(uid);
      if (!mounted) return;
      final vendor = _map(data['vendor']);
      final user = _map(
        data['user_id'] ??
            data['userId'] ??
            data['user'] ??
            data['vendor_user'] ??
            data['vendorUser'] ??
            vendor['user_id'] ??
            vendor['userId'] ??
            vendor['user'],
      );
      final rawUserId = data['user_id'] ??
          data['userId'] ??
          vendor['user_id'] ??
          vendor['userId'];
      final vendorUserId = (user['_id'] ??
              user['id'] ??
              ((rawUserId is String || rawUserId is num) ? rawUserId : null) ??
              uid)
          .toString()
          .trim();
      setState(() {
        _data = data;
        _vendorUserId = vendorUserId.isEmpty ? uid : vendorUserId;
        _loading = false;
      });
      _startCoverAutoplayIfNeeded();
      unawaited(_loadAds());
      unawaited(_loadGallery());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load vendor profile. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _loadGallery() async {
    if (_galleryLoading) return;
    setState(() {
      _galleryLoading = true;
      _galleryError = null;
    });

    try {
      final items = await _adsService.fetchGalleryItems();
      final urls = <String>[];
      for (final item in items) {
        final raw = (item['link'] ?? item['fileUrl'] ?? item['url'] ?? '')
            .toString()
            .trim();
        final url = UrlHelper.normalizeUrl(raw);
        if (url.isNotEmpty) urls.add(url);
      }

      final deduped = <String>[];
      final seen = <String>{};
      for (final url in urls) {
        if (seen.add(url)) deduped.add(url);
      }

      if (!mounted) return;
      setState(() {
        _galleryUrls = deduped;
        _galleryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _galleryError = 'Could not load gallery images.';
        _galleryUrls = const [];
        _galleryLoading = false;
      });
    }
  }

  Future<void> _loadAds() async {
    if (_adsLoading) return;
    final primary = (_vendorUserId ?? '').trim();
    final secondary = widget.userId.trim();
    final candidates = <String>{
      if (primary.isNotEmpty) primary,
      if (secondary.isNotEmpty) secondary,
    }.toList();
    if (candidates.isEmpty) return;
    setState(() {
      _adsLoading = true;
      _adsError = null;
    });
    try {
      List<Ad> list = const [];
      var hadSuccess = false;
      for (final id in candidates) {
        try {
          list = await _adsService.fetchUserAds(userId: id);
          hadSuccess = true;
          if (list.isNotEmpty) break;
        } catch (e) {
          // keep trying other id candidates
        }
      }
      if (!mounted) return;
      setState(() {
        _ads = list;
        _adsError = hadSuccess ? null : 'Could not load ads.';
        _adsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adsError = 'Could not load ads.';
        _ads = const [];
        _adsLoading = false;
      });
    }
  }

  void _showMoreActions({
    required String companyName,
    required String vendorId,
  }) {
    final id = vendorId.trim();
    if (id.isEmpty) return;

    bool started = false;
    bool loading = true;
    bool toggling = false;
    bool? enabled;
    String? error;

    Future<void> loadStatus(StateSetter setSheetState) async {
      try {
        enabled = await _prefsApi.vendorStatus(id);
        error = null;
      } catch (_) {
        error = 'Could not load notification status';
      } finally {
        loading = false;
        if (mounted) setSheetState(() {});
      }
    }

    Future<void> toggle(
        BuildContext sheetCtx, StateSetter setSheetState) async {
      if (toggling) return;
      toggling = true;
      error = null;
      setSheetState(() {});
      try {
        final res = await _prefsApi.toggleVendor(id);
        enabled = (res['enabled'] as bool?) ?? enabled ?? false;
        final message = (res['message'] as String?)?.trim();
        if (message != null && message.isNotEmpty && mounted) {
          Navigator.of(sheetCtx).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          return;
        }
      } catch (_) {
        error = 'Failed to update notification setting';
      } finally {
        toggling = false;
        if (mounted) setSheetState(() {});
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            if (!started) {
              started = true;
              unawaited(loadStatus(setSheetState));
            }

            final notifTitle = enabled == true
                ? 'Turn off notifications'
                : 'Turn on notifications';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(notifTitle),
                  subtitle: loading
                      ? const Text('Checking status…')
                      : (error != null ? Text(error!) : null),
                  trailing: toggling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: loading ? null : () => toggle(sheetCtx, setSheetState),
                ),
                ListTile(
                  leading: const Icon(Icons.report_outlined),
                  title: const Text('Report vendor'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report submitted')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(LucideIcons.userX),
                  title: Text('Block $companyName'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vendor blocked')),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  void _startCoverAutoplayIfNeeded() {
    _coverAutoplayTimer?.cancel();
    final data = _data;
    if (data == null) return;
    final covers = _stringList(data['cover_image_urls']);
    if (covers.length < 2) return;
    _coverAutoplayTimer =
        Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (!mounted) return;
      if (!_coverController.hasClients) return;
      final next = (_coverIndex + 1) % covers.length;
      _coverController.animateToPage(
        next,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOut,
      );
    });
  }

  String _companyName(Map<String, dynamic> data) {
    final company = _map(data['company_details']);
    final v = (company['company_name'] ??
            data['business_name'] ??
            data['vendor_name'] ??
            data['name'] ??
            '')
        .toString()
        .trim();
    return v.isEmpty ? 'Vendor' : v;
  }

  bool _isVerified(Map<String, dynamic> data) {
    final v = data['validated'];
    if (v is bool) return v;
    return v?.toString().toLowerCase() == 'true';
  }

  String? _avatarUrl(Map<String, dynamic> data) {
    final user = _map(data['user_id']);
    final url =
        (data['avatar_url'] ?? user['avatar_url'] ?? '').toString().trim();
    return url.isEmpty ? null : url;
  }

  String? _websiteUrl(Map<String, dynamic> data) {
    final online = _map(data['online_presence']);
    final url = (online['website_url'] ?? '').toString().trim();
    return url.isEmpty ? null : url;
  }

  String? _industry(Map<String, dynamic> data) {
    final company = _map(data['company_details']);
    final business = _map(data['business_details']);
    final v = (company['industry'] ?? business['industry_category'] ?? '')
        .toString()
        .trim();
    return v.isEmpty ? null : v;
  }

  String? _serviceCoverage(Map<String, dynamic> data) {
    final business = _map(data['business_details']);
    final v = (business['service_coverage'] ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  String? _country(Map<String, dynamic> data) {
    final business = _map(data['business_details']);
    final v = (business['country'] ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  void _showAvatarLightbox({
    required bool isDark,
    required String name,
    required String? avatarUrl,
  }) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'avatar',
      barrierColor: Colors.black.withValues(alpha: 0.80),
      pageBuilder: (context, _, __) {
        return SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox.expand(),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: avatarUrl == null
                                ? DecoratedBox(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFFB923C),
                                          Color(0xFFEC4899),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isEmpty
                                            ? 'V'
                                            : name
                                                .substring(0, 1)
                                                .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 72,
                                        ),
                                      ),
                                    ),
                                  )
                                : Image.network(avatarUrl, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 180),
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? Colors.black : const Color(0xFFF9FAFB);
    final surface = isDark ? const Color(0xFF0B0B0B) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final text = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : Colors.black.withValues(alpha: 0.55);

    if (_loading) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading profile…',
                style: TextStyle(color: muted, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade300, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text(
                      '← Go Back',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final data = _data ?? const <String, dynamic>{};
    final companyName = _companyName(data);
    final verified = _isVerified(data);
    final avatarUrl = _avatarUrl(data);
    final coverUrls = _stringList(data['cover_image_urls']);
    final industry = _industry(data);
    final user = _map(data['user_id']);
    final stats = _map(data['stats']);
    final vendor = _map(data['vendor']);
    final vendorUser = _map(data['user'] ?? data['userId'] ?? data['user_id']);

    final followersCount = _readCount(
      stats.isNotEmpty ? stats : data,
      const [
        'followers_count',
        'followersCount',
        'followers',
        'followerCount',
      ],
    );
    final followingCount = _readCount(
      stats.isNotEmpty ? stats : data,
      const [
        'following_count',
        'followingCount',
        'following',
        'followingCountTotal',
      ],
    );

    final categoryLabel = (industry ??
            (vendor['category'] ?? vendorUser['category'])?.toString().trim())
        ?.trim();
    final vendorDocId = (data['_id'] ?? data['id'])?.toString().trim() ?? '';
    final notificationTargetId =
        vendorDocId.isNotEmpty ? vendorDocId : (_vendorUserId ?? widget.userId);

    return Scaffold(
      backgroundColor: background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) {
          return [
            SliverToBoxAdapter(
              child: _VendorHeader(
                isDark: isDark,
                background: background,
                surface: surface,
                border: border,
                text: text,
                muted: muted,
                coverController: _coverController,
                coverUrls: coverUrls,
                coverIndex: _coverIndex,
                onCoverChanged: (i) => setState(() => _coverIndex = i),
                onBack: () => Navigator.of(context).maybePop(),
                companyName: companyName,
                verified: verified,
                avatarUrl: avatarUrl,
                onAvatarTap: () => _showAvatarLightbox(
                  isDark: isDark,
                  name: companyName,
                  avatarUrl: avatarUrl,
                ),
                followersCount: followersCount,
                followingCount: followingCount,
                categoryLabel: categoryLabel,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabHeaderDelegate(
                background: isDark
                    ? Colors.black.withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.95),
                border: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                tabBar: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFEC4899),
                  labelColor: const Color(0xFFEC4899),
                  unselectedLabelColor: muted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  physics: const BouncingScrollPhysics(),
                  onTap: (index) {
                    if (_tabController.index == index) return;
                    _tabController.animateTo(index);
                  },
                  tabs: const [
                    Tab(text: 'About'),
                    Tab(text: 'Products'),
                    Tab(text: 'Gallery'),
                    Tab(text: 'Spotlights'),
                    Tab(text: 'Events'),
                    Tab(text: 'Locations'),
                    Tab(text: 'Contact'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _InformationTab(
              data: data,
              isDark: isDark,
            ),
            _ProductsTab(isDark: isDark),
            _GalleryTab(
              isDark: isDark,
              loading: _galleryLoading,
              error: _galleryError,
              imageUrls: _galleryUrls,
            ),
            _AdsTab(
              isDark: isDark,
              loading: _adsLoading,
              error: _adsError,
              ads: _ads,
            ),
            _EventsTab(isDark: isDark),
            _LocationsTab(
              isDark: isDark,
              data: data,
            ),
            _ContactTabReact(
              data: data,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorHeader extends StatelessWidget {
  final bool isDark;
  final Color background;
  final Color surface;
  final Color border;
  final Color text;
  final Color muted;
  final PageController coverController;
  final List<String> coverUrls;
  final int coverIndex;
  final ValueChanged<int> onCoverChanged;
  final VoidCallback onBack;
  final String companyName;
  final bool verified;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;
  final int followersCount;
  final int followingCount;
  final String? categoryLabel;

  const _VendorHeader({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.coverController,
    required this.coverUrls,
    required this.coverIndex,
    required this.onCoverChanged,
    required this.onBack,
    required this.companyName,
    required this.verified,
    required this.avatarUrl,
    required this.onAvatarTap,
    required this.followersCount,
    required this.followingCount,
    required this.categoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final coverHeight = MediaQuery.sizeOf(context).width >= 600 ? 288.0 : 220.0;
    final safeTop = MediaQuery.paddingOf(context).top;
    final avatarSize = MediaQuery.sizeOf(context).width >= 600 ? 112.0 : 96.0;
    final category =
        (categoryLabel ?? '').trim().isEmpty ? null : categoryLabel!.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(builder: (context) {
          final infoHeight =
              MediaQuery.sizeOf(context).width >= 600 ? 148.0 : 132.0;
          return SizedBox(
            height: coverHeight + infoHeight,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: coverHeight,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    child: coverUrls.isEmpty
                        ? DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFB923C),
                                  Color(0xFFEC4899),
                                  Color(0xFF9333EA),
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 56,
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                          )
                        : PageView.builder(
                            controller: coverController,
                            itemCount: coverUrls.length,
                            onPageChanged: onCoverChanged,
                            itemBuilder: (_, i) => Image.network(
                              coverUrls[i],
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  top: safeTop + 12,
                  left: 8,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white,
                      splashRadius: 22,
                      tooltip: 'Back',
                    ),
                  ),
                ),
                if (coverUrls.length > 1)
                  Positioned(
                    right: 14,
                    bottom: infoHeight + 14,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(coverUrls.length, (i) {
                        final active = i == coverIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(
                              alpha: active ? 0.95 : 0.45,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        );
                      }),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: coverHeight,
                  height: infoHeight,
                  child: Container(
                    color: surface,
                    padding:
                        EdgeInsets.fromLTRB(16 + avatarSize + 16, 14, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                companyName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: text,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 8),
                              const _VerifiedBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '$followersCount followers',
                              style: TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            Text('•',
                                style: TextStyle(
                                    color: muted,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12)),
                            Text(
                              '$followingCount following',
                              style: TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            if (category != null) ...[
                              Text('•',
                                  style: TextStyle(
                                      color: muted,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12)),
                              Text(
                                category,
                                style: TextStyle(
                                  color: muted,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Welcome to the $companyName channel',
                          style: TextStyle(
                            color: text,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 1,
                          color: border,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: coverHeight + 12,
                  child: InkWell(
                    onTap: onAvatarTap,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: surface,
                        border: Border.all(
                          width: 4,
                          color:
                              isDark ? const Color(0xFF0B0B0B) : Colors.white,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: avatarUrl == null
                            ? DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFFB923C),
                                      Color(0xFFEC4899),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 34,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                ),
                              )
                            : Image.network(
                                avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 34,
                                    color: muted,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Color(0xFF0095F6),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(
          Icons.verified,
          size: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color border;
  final Color fill;

  const _MetaPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.border,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Color background;
  final Color border;
  final TabBar tabBar;

  _TabHeaderDelegate({
    required this.background,
    required this.border,
    required this.tabBar,
  });

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: background,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: border),
          ),
        ),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) {
    return oldDelegate.background != background ||
        oldDelegate.border != border ||
        oldDelegate.tabBar != tabBar;
  }
}

class _InformationTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;

  const _InformationTab({
    required this.data,
    required this.isDark,
  });

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String _pick(dynamic value) => value?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final company = _map(data['company_details']);
    final business = _map(data['business_details']);

    final companyDescription = _pick(data['company_description']);
    final industry = _pick(company['industry']).isNotEmpty
        ? _pick(company['industry'])
        : _pick(business['industry_category']);
    final nature = _pick(business['business_nature']);
    final coverage = _pick(business['service_coverage']);
    final yearEstablished = _pick(company['year_established']);
    final country = _pick(business['country']);
    final companyType = _pick(company['company_type']);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (companyDescription.isNotEmpty)
          Text(
            companyDescription,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.82)
                  : Colors.black.withValues(alpha: 0.78),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 1),
        _StatGrid(
          isDark: isDark,
          industry: industry,
          nature: nature,
          coverage: coverage,
          yearEstablished: yearEstablished,
          country: country,
          companyType: companyType,
        ),
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final bool isDark;
  final String title;
  final String emptyMessage;
  final bool showTitle;

  const _PlaceholderTab({
    required this.isDark,
    required this.title,
    required this.emptyMessage,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : Colors.black.withValues(alpha: 0.55);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showTitle) ...[
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          emptyMessage,
          style: TextStyle(color: muted, height: 1.35),
        ),
      ],
    );
  }
}

class _ProductsTab extends StatelessWidget {
  final bool isDark;

  const _ProductsTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final text = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : Colors.black.withValues(alpha: 0.55);

    const products = [
      (
        name: 'Wireless Headphones',
        subtitle: 'Noise cancelling • Bluetooth 5.3',
        price: '₹4,999',
        image:
            'https://images.unsplash.com/photo-1518441314036-5b2f6d64c77d?w=1200&q=80',
      ),
      (
        name: 'Running Shoes',
        subtitle: 'Lightweight • Breathable',
        price: '₹2,799',
        image:
            'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=1200&q=80',
      ),
      (
        name: 'Laptop',
        subtitle: '16GB RAM • 512GB SSD',
        price: '₹59,999',
        image:
            'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=1200&q=80',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      children: [
        const SizedBox(height: 28),
        ...products.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0B0B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(16)),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: Image.network(
                      p.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                        child: Icon(Icons.image_not_supported_outlined,
                            color: muted),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            color: text,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.subtitle,
                          style: TextStyle(
                              color: muted, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.price,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF34D399)
                                : const Color(0xFF059669),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          );
        }),
        Text(
          'Demo products for now.',
          style: TextStyle(color: muted, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _GalleryTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<String> imageUrls;
  final bool isDark;

  const _GalleryTab({
    required this.isDark,
    required this.loading,
    required this.error,
    required this.imageUrls,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : Colors.black.withValues(alpha: 0.55);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && error!.trim().isNotEmpty) {
      return Center(child: Text(error!, style: TextStyle(color: muted)));
    }
    if (imageUrls.isEmpty) {
      return _PlaceholderTab(
        isDark: isDark,
        title: 'Gallery',
        emptyMessage: 'No gallery images yet.',
        showTitle: false,
      );
    }

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: SizedBox(height: 42),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final url = imageUrls[index];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => showFullscreenImageViewer(
                    context,
                    imageUrl: url,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child:
                              Icon(Icons.broken_image_outlined, color: muted),
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: imageUrls.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventsTab extends StatelessWidget {
  final bool isDark;

  const _EventsTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final text = isDark ? Colors.white : const Color(0xFF111827);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : Colors.black.withValues(alpha: 0.55);

    const items = [
      (
        title: 'New Collection Launch',
        subtitle: 'This Friday • 6:00 PM',
      ),
      (
        title: 'Weekend Sale',
        subtitle: 'Sat–Sun • Up to 30% off',
      ),
      (
        title: 'Live Demo',
        subtitle: 'Next week • Online',
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      children: [
        const SizedBox(height: 28),
        ...items.map(
          (e) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B0B0B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              title: Text(e.title,
                  style: TextStyle(color: text, fontWeight: FontWeight.w900)),
              subtitle: Text(e.subtitle,
                  style: TextStyle(color: muted, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        Text(
          'Demo events for now.',
          style: TextStyle(color: muted, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LocationsTab extends StatelessWidget {
  final bool isDark;
  final Map<String, dynamic> data;

  const _LocationsTab({
    required this.isDark,
    required this.data,
  });

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String _pick(dynamic value) => value?.toString().trim() ?? '';

  String _formatAddress(Map<String, dynamic> address) {
    final parts = <String>[
      _pick(address['address_line1'] ?? address['addressLine1']),
      _pick(address['address_line2'] ?? address['addressLine2']),
      _pick(address['city']),
      _pick(address['state']),
      _pick(address['pincode']),
      _pick(address['country']),
    ].where((v) => v.isNotEmpty).toList();
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final company = _map(data['company_details']);
    final business = _map(data['business_details']);
    final online = _map(data['online_presence']);
    final address = _map(
      online['address'] ?? company['address'] ?? business['address'],
    );
    final addressText = _formatAddress(address);
    final companyAddressText = addressText.isNotEmpty
        ? addressText
        : _pick(online['company_address'] ?? company['company_address']);
    final displayAddress = companyAddressText.isNotEmpty
        ? companyAddressText
        : 'No company address available.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      children: [
        const SizedBox(height: 28),
        Text(
          displayAddress,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  final bool isDark;
  final String industry;
  final String nature;
  final String coverage;
  final String yearEstablished;
  final String country;
  final String companyType;

  const _StatGrid({
    required this.isDark,
    required this.industry,
    required this.nature,
    required this.coverage,
    required this.yearEstablished,
    required this.country,
    required this.companyType,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (industry.trim().isNotEmpty)
        const _StatChip(
          label: 'Industry',
          icon: Icons.local_offer_outlined,
          tint: Color(0xFF8B5CF6),
        ).withValue(industry.trim()),
      if (nature.trim().isNotEmpty)
        const _StatChip(
          label: 'Nature',
          icon: Icons.work_outline,
          tint: Color(0xFF3B82F6),
        ).withValue(nature.trim()),
      if (coverage.trim().isNotEmpty)
        const _StatChip(
          label: 'Coverage',
          icon: Icons.public_outlined,
          tint: Color(0xFF14B8A6),
        ).withValue(coverage.trim()),
      if (yearEstablished.trim().isNotEmpty)
        _YearChip(
          year: yearEstablished.trim(),
          isDark: isDark,
        ),
      if (country.trim().isNotEmpty)
        const _StatChip(
          label: 'Country',
          icon: Icons.place_outlined,
          tint: Color(0xFFFB7185),
        ).withValue(country.trim()),
      if (companyType.trim().isNotEmpty)
        const _StatChip(
          label: 'Company Type',
          icon: Icons.business_outlined,
          tint: Color(0xFF64748B),
        ).withValue(companyType.trim()),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (_, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 720 ? 3 : 2;
        final ts = MediaQuery.textScaleFactorOf(context);
        final clampedTs = ts < 1 ? 1.0 : (ts > 1.2 ? 1.2 : ts);
        final mainAxisExtent = 118.0 * clampedTs;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: mainAxisExtent,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => items[i],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  const _StatChip({
    required this.label,
    required this.icon,
    required this.tint,
    this.value = '',
  });

  _StatChip withValue(String v) => _StatChip(
        label: label,
        value: v,
        icon: icon,
        tint: tint,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill =
        isDark ? tint.withValues(alpha: 0.14) : tint.withValues(alpha: 0.08);
    final border =
        isDark ? tint.withValues(alpha: 0.22) : tint.withValues(alpha: 0.18);
    final labelColor =
        isDark ? tint.withValues(alpha: 0.90) : tint.withValues(alpha: 0.95);
    final valueColor = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.78);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: labelColor, size: 18),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              fontSize: 10,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  final String year;
  final bool isDark;

  const _YearChip({required this.year, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? const Color(0x332A1B00) : const Color(0xFFFFFBEB);
    final border = isDark ? const Color(0x334B2A00) : const Color(0xFFFDE68A);
    const tint = Color(0xFFF59E0B);
    final valueColor = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.80);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.calendar_today_outlined, color: tint, size: 18),
          const SizedBox(height: 10),
          const Text(
            'EST.',
            style: TextStyle(
              color: tint,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              fontSize: 10,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            year,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;

  const _KeyValue({
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.45);
    final text = isDark
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.80);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
              color: muted, fontWeight: FontWeight.w700, fontSize: 10),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: text,
            fontWeight: FontWeight.w900,
            fontFamily: mono ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final String url;
  final IconData icon;
  final Color tint;

  const _SocialButton({
    required this.label,
    required this.url,
    required this.icon,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill =
        isDark ? tint.withValues(alpha: 0.16) : tint.withValues(alpha: 0.10);
    final border =
        isDark ? tint.withValues(alpha: 0.22) : tint.withValues(alpha: 0.26);
    final fg =
        isDark ? tint.withValues(alpha: 0.95) : tint.withValues(alpha: 0.95);
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ExternalLinkScreen(url: url, title: label),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
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

class _AdsTab extends StatelessWidget {
  final bool isDark;
  final bool loading;
  final String? error;
  final List<Ad> ads;

  const _AdsTab({
    required this.isDark,
    required this.loading,
    required this.error,
    required this.ads,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.60)
        : Colors.black.withValues(alpha: 0.55);

    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 12),
            Text(
              'Loading spotlights…',
              style: TextStyle(color: muted, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x331F0A0A) : const Color(0xFFFFEEF2),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0x33221111) : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade300, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error!,
                  style: TextStyle(
                      color: Colors.red.shade300, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (ads.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 44),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.black.withValues(alpha: 0.10),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.campaign_outlined, size: 42, color: muted),
              const SizedBox(height: 10),
              Text(
                'No spotlights yet',
                style: TextStyle(color: muted, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 42, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1,
      ),
      itemCount: ads.length,
      itemBuilder: (_, i) => _VendorAdTile(ad: ads[i]),
    );
  }
}

class _VendorAdTile extends StatelessWidget {
  final Ad ad;

  const _VendorAdTile({required this.ad});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thumb = (ad.imageUrl ?? '').trim();
    final isVideo = (ad.videoUrl ?? '').trim().isNotEmpty;
    final category = (ad.category ?? '').trim().isNotEmpty
        ? (ad.category ?? '').trim()
        : (ad.title.trim().isNotEmpty ? ad.title.trim() : null);

    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/ads/${ad.id}/details'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: thumb.isEmpty
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFFEDD5),
                            Color(0xFFFFE4E6),
                          ],
                        ),
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                      child: const Center(
                        child: Icon(Icons.shopping_bag_outlined, size: 22),
                      ),
                    )
                  : Image.network(thumb, fit: BoxFit.cover),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xB3000000),
                      Color(0x22000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
            if (isVideo)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            if (category != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  category,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.90),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.6,
                    height: 1.15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactTabReact extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;

  const _ContactTabReact({
    required this.data,
    required this.isDark,
  });

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String _pick(dynamic value) => value?.toString().trim() ?? '';

  static Future<void> _copyAndToast(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : Colors.black.withValues(alpha: 0.55);
    final online = _map(data['online_presence']);
    final social = _map(data['social_media_links']);
    final user = _map(data['user_id']);

    final companyEmail = _pick(online['company_email']);
    final phone = _pick(online['phone_number']);
    final website = _pick(online['website_url']);
    final accountEmail = _pick(user['email']);
    final instagram = _pick(social['instagram']);
    final facebook = _pick(social['facebook']);
    final linkedin = _pick(social['linkedin']);
    final twitter = _pick(social['twitter']);

    final hasSocial = instagram.isNotEmpty ||
        facebook.isNotEmpty ||
        linkedin.isNotEmpty ||
        twitter.isNotEmpty;

    final items = <_ContactItemReact>[
      if (companyEmail.isNotEmpty)
        _ContactItemReact(
          label: 'Email',
          value: companyEmail,
          icon: Icons.mail_outline,
          tint: const Color(0xFFF97316),
          onTap: () => _copyAndToast(context, companyEmail),
        ),
      if (phone.isNotEmpty)
        _ContactItemReact(
          label: 'Phone',
          value: phone,
          icon: Icons.phone_outlined,
          tint: const Color(0xFF10B981),
          onTap: () => _copyAndToast(context, phone),
        ),
      if (website.isNotEmpty)
        _ContactItemReact(
          label: 'Website',
          value: website,
          icon: Icons.public_outlined,
          tint: const Color(0xFF3B82F6),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ExternalLinkScreen(url: website, title: 'Website'),
            ),
          ),
        ),
      if (accountEmail.isNotEmpty)
        _ContactItemReact(
          label: 'Account Email',
          value: accountEmail,
          icon: Icons.alternate_email,
          tint: const Color(0xFFFB923C),
          onTap: () => _copyAndToast(context, accountEmail),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (items.isEmpty && !hasSocial)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 44),
            child: Center(
              child: Text(
                'No contact info available.',
                style: TextStyle(color: muted, fontWeight: FontWeight.w700),
              ),
            ),
          )
        else ...[
          ...items.map((i) => _ContactTileReact(item: i, isDark: isDark)),
          if (hasSocial) ...[
            const SizedBox(height: 14),
            Text(
              'SOCIAL MEDIA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: muted,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SocialButton(
                  label: 'Instagram',
                  url: instagram,
                  icon: LucideIcons.instagram,
                  tint: const Color(0xFFEC4899),
                ),
                _SocialButton(
                  label: 'Facebook',
                  url: facebook,
                  icon: LucideIcons.facebook,
                  tint: const Color(0xFF2563EB),
                ),
                _SocialButton(
                  label: 'LinkedIn',
                  url: linkedin,
                  icon: LucideIcons.linkedin,
                  tint: const Color(0xFF0EA5E9),
                ),
                _SocialButton(
                  label: 'Twitter',
                  url: twitter,
                  icon: LucideIcons.twitter,
                  tint: const Color(0xFF1D9BF0),
                ),
              ],
            ),
          ],
          if (companyEmail.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (companyEmail.isNotEmpty)
                  Expanded(
                    child: AdGradientCtaButton(
                      onPressed: () => _copyAndToast(context, companyEmail),
                      icon: Icons.mail_outline,
                      label: 'Send Email',
                      boxShadow: const [],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      borderRadius: const BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                if (companyEmail.isNotEmpty && phone.isNotEmpty)
                  const SizedBox(width: 12),
                if (phone.isNotEmpty)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _copyAndToast(context, phone),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.14)
                              : Colors.black.withValues(alpha: 0.14),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        'Call Now',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _ContactItemReact {
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  const _ContactItemReact({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.onTap,
  });
}

class _ContactTileReact extends StatelessWidget {
  final _ContactItemReact item;
  final bool isDark;
  const _ContactTileReact({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fill = isDark
        ? item.tint.withValues(alpha: 0.16)
        : item.tint.withValues(alpha: 0.10);
    final border = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.06);
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.45);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F10) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: ListTile(
        onTap: item.onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(item.icon, color: item.tint, size: 18),
        ),
        title: Text(
          item.label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: labelColor,
          ),
        ),
        subtitle: Text(
          item.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: item.tint,
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: Icon(
          Icons.open_in_new,
          size: 16,
          color: isDark
              ? Colors.white.withValues(alpha: 0.30)
              : Colors.black.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
