import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/vendors_api.dart';
import '../models/ad_model.dart';
import '../services/ads_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final user = _map(data['user_id']);
      final vendorUserId = (user['_id'] ??
              user['id'] ??
              ((data['user_id'] is String || data['user_id'] is num)
                  ? data['user_id']
                  : null) ??
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load vendor profile. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _loadAds() async {
    if (_adsLoading) return;
    final uid = (_vendorUserId ?? widget.userId).trim();
    if (uid.isEmpty) return;
    setState(() {
      _adsLoading = true;
      _adsError = null;
    });
    try {
      final list = await _adsService.fetchUserAds(userId: uid);
      if (!mounted) return;
      setState(() {
        _ads = list;
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
    final websiteUrl = _websiteUrl(data);
    final industry = _industry(data);
    final coverage = _serviceCoverage(data);
    final country = _country(data);
    final user = _map(data['user_id']);
    final username = (user['username'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: background,
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
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
                  websiteUrl: websiteUrl,
                  industry: industry,
                  coverage: coverage,
                  country: country,
                  username: username,
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
                    tabs: const [
                      Tab(
                          icon: Icon(Icons.info_outline, size: 18),
                          text: 'Info'),
                      Tab(
                          icon: Icon(Icons.campaign_outlined, size: 18),
                          text: 'Ads'),
                      Tab(
                          icon: Icon(Icons.person_outline, size: 18),
                          text: 'Contact'),
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
              _AdsTab(
                isDark: isDark,
                loading: _adsLoading,
                error: _adsError,
                ads: _ads,
              ),
              _ContactTabReact(
                data: data,
                isDark: isDark,
              ),
            ],
          ),
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
  final String? websiteUrl;
  final String? industry;
  final String? coverage;
  final String? country;
  final String username;

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
    required this.websiteUrl,
    required this.industry,
    required this.coverage,
    required this.country,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    final coverHeight = MediaQuery.sizeOf(context).width >= 600 ? 288.0 : 220.0;
    final safeTop = MediaQuery.paddingOf(context).top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: coverHeight,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
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
              Positioned(
                top: safeTop + 12,
                left: 16,
                child: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Back',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (coverUrls.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(coverUrls.length, (i) {
                      final active = i == coverIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: active ? 0.85 : 0.35),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          // Pull the profile card upward to overlap the cover banner (React parity).
          // Keep layout + tab spacing tight (avoid large blank gap under the translated card).
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Transform.translate(
            offset: const Offset(0, -26),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 44),
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.35 : 0.10),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
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
                                          fontSize: 22,
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
                                if (username.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '@${username.trim()}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: muted,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (websiteUrl != null) ...[
                            const SizedBox(width: 12),
                            ConstrainedBox(
                              // Row gives non-flex children unbounded width constraints.
                              // Constrain the CTA so its internal `Row + Flexible` can layout.
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: AdGradientCtaButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ExternalLinkScreen(
                                        url: websiteUrl!,
                                        title: 'Visit Website',
                                      ),
                                    ),
                                  );
                                },
                                icon: Icons.public,
                                label: 'Visit Website',
                                boxShadow: const [],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(18),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (industry != null)
                            _MetaPill(
                              label: industry!,
                              icon: Icons.local_offer_outlined,
                              color: muted,
                              border: border,
                              fill: surface,
                            ),
                          if (coverage != null)
                            _MetaPill(
                              label: coverage!,
                              icon: Icons.place_outlined,
                              color: muted,
                              border: border,
                              fill: surface,
                            ),
                          if (country != null)
                            _MetaPill(
                              label: '🌏 ${country!}',
                              icon: null,
                              color: muted,
                              border: border,
                              fill: surface,
                            ),
                          if (verified)
                            _MetaPill(
                              label: 'Verified Business',
                              icon: Icons.verified_outlined,
                              color: isDark
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF059669),
                              border: isDark
                                  ? const Color(0xFF064E3B)
                                  : const Color(0xFFBDE9D4),
                              fill: isDark
                                  ? const Color(0xFF03251B)
                                  : const Color(0xFFE7F9F1),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  child: InkWell(
                    onTap: onAvatarTap,
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: surface,
                        border: Border.all(
                          width: 4,
                          color:
                              isDark ? const Color(0xFF0B0B0B) : Colors.white,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: avatarUrl == null
                            ? const DecoratedBox(
                                decoration: BoxDecoration(
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
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Image.network(avatarUrl!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                // Button is rendered next to username inside the card.
              ],
            ),
          ),
        ),
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
  double get minExtent => 54;

  @override
  double get maxExtent => 54;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
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
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.70)
        : Colors.black.withValues(alpha: 0.55);

    final company = _map(data['company_details']);
    final business = _map(data['business_details']);
    final online = _map(data['online_presence']);
    final social = _map(data['social_media_links']);
    final address = _map(online['address']);

    final companyDescription = _pick(data['company_description']);
    final industry = _pick(company['industry']).isNotEmpty
        ? _pick(company['industry'])
        : _pick(business['industry_category']);
    final nature = _pick(business['business_nature']);
    final coverage = _pick(business['service_coverage']);
    final yearEstablished = _pick(company['year_established']);
    final country = _pick(business['country']);
    final companyType = _pick(company['company_type']);
    final registrationNumber = _pick(company['registration_number']);
    final taxId = _pick(company['tax_id']);

    final addressParts = [
      _pick(address['address_line1']),
      _pick(address['address_line2']),
      _pick(address['city']),
      _pick(address['state']),
      _pick(address['pincode']),
      _pick(address['country']),
    ].where((e) => e.isNotEmpty).toList();
    final addressStr = addressParts.join(', ');

    final hasSocial = _pick(social['instagram']).isNotEmpty ||
        _pick(social['facebook']).isNotEmpty ||
        _pick(social['linkedin']).isNotEmpty ||
        _pick(social['twitter']).isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (companyDescription.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0x33210B00),
                        Color(0x331A0014),
                        Color(0x3315002B),
                      ]
                    : const [
                        Color(0xFFFFF7ED),
                        Color(0xFFFFF1F2),
                        Color(0xFFFAF5FF),
                      ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : const Color(0xFFFDE7DD),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x33F97316)
                            : const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.business_outlined,
                        size: 14,
                        color: Color(0xFFF97316),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'ABOUT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: Color(0xFFF97316),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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
              ],
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
        const SizedBox(height: 12),
        if (registrationNumber.isNotEmpty || taxId.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F10) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REGISTRATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 14,
                  children: [
                    if (registrationNumber.isNotEmpty)
                      _KeyValue(
                        label: 'Reg. Number',
                        value: registrationNumber,
                        mono: true,
                      ),
                    if (taxId.isNotEmpty)
                      _KeyValue(
                        label: 'Tax ID / GST',
                        value: taxId,
                        mono: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (addressStr.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F10) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0x33221212)
                        : const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.place_outlined,
                    color: Color(0xFFFB7185),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ADDRESS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        addressStr,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.82)
                              : Colors.black.withValues(alpha: 0.78),
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (hasSocial) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0F10) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      url: _pick(social['instagram']),
                      icon: LucideIcons.instagram,
                      tint: const Color(0xFFEC4899),
                    ),
                    _SocialButton(
                      label: 'Facebook',
                      url: _pick(social['facebook']),
                      icon: LucideIcons.facebook,
                      tint: const Color(0xFF2563EB),
                    ),
                    _SocialButton(
                      label: 'LinkedIn',
                      url: _pick(social['linkedin']),
                      icon: LucideIcons.linkedin,
                      tint: const Color(0xFF0EA5E9),
                    ),
                    _SocialButton(
                      label: 'Twitter',
                      url: _pick(social['twitter']),
                      icon: LucideIcons.twitter,
                      tint: const Color(0xFF1D9BF0),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: items,
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
              'Loading ads…',
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
                'No ads yet',
                style: TextStyle(color: muted, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
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
    final user = _map(data['user_id']);

    final companyEmail = _pick(online['company_email']);
    final phone = _pick(online['phone_number']);
    final website = _pick(online['website_url']);
    final accountEmail = _pick(user['email']);

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
        if (items.isEmpty)
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
