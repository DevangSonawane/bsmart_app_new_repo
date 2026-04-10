import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/vendors_api.dart';
import '../models/ad_model.dart';
import '../services/ads_service.dart';
import '../widgets/ad_cta_buttons.dart';
import 'external_link_screen.dart';

class VendorPublicProfileScreen extends StatefulWidget {
  final String userId;

  const VendorPublicProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<VendorPublicProfileScreen> createState() =>
      _VendorPublicProfileScreenState();
}

class _VendorPublicProfileScreenState extends State<VendorPublicProfileScreen>
    with SingleTickerProviderStateMixin {
  final VendorsApi _vendorsApi = VendorsApi();
  final AdsService _adsService = AdsService();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  late final TabController _tabController;

  // Ads tab state
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
    _tabController.dispose();
    super.dispose();
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
    });

    try {
      final data = await _vendorsApi.getVendorPublicProfile(uid);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      unawaited(_loadAds());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load vendor profile.';
        _loading = false;
      });
    }
  }

  Future<void> _loadAds() async {
    if (_adsLoading) return;
    final uid = widget.userId.trim();
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

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e?.toString() ?? '').where((s) => s.trim().isNotEmpty).toList();
    }
    return const <String>[];
  }

  String _companyName(Map<String, dynamic> data) {
    final companyDetails = _map(data['company_details']);
    final v = (companyDetails['company_name'] ??
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
    final url = (data['avatar_url'] ?? user['avatar_url'] ?? '').toString().trim();
    return url.isEmpty ? null : url;
  }

  String? _websiteUrl(Map<String, dynamic> data) {
    final online = _map(data['online_presence']);
    final url = (online['website_url'] ?? '').toString().trim();
    return url.isEmpty ? null : url;
  }

  List<String> _coverUrls(Map<String, dynamic> data) {
    final urls = _stringList(data['cover_image_urls']);
    return urls;
  }

  Widget _pill(String label, {IconData? icon}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141414) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F7),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
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
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _load,
                    child: const Text('Retry'),
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
    final coverUrls = _coverUrls(data);
    final websiteUrl = _websiteUrl(data);

    final businessDetails = _map(data['business_details']);
    final companyDetails = _map(data['company_details']);
    final industry = (companyDetails['industry'] ?? businessDetails['industry_category'] ?? '').toString().trim();
    final coverage = (businessDetails['service_coverage'] ?? '').toString().trim();
    final country = (businessDetails['country'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF7F7F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Cover + back
            SizedBox(
              height: 220,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: coverUrls.isEmpty
                        ? Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF09433), Color(0xFFDC2743), Color(0xFFBC1888)],
                              ),
                            ),
                          )
                        : PageView.builder(
                            itemCount: coverUrls.length,
                            itemBuilder: (_, i) => Image.network(
                              coverUrls[i],
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Identity row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.10),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl == null
                        ? Center(
                            child: Text(
                              companyName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          )
                        : Image.network(avatarUrl, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                companyName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (verified) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0095F6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, size: 14, color: Colors.white),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (industry.isNotEmpty) _pill(industry, icon: Icons.local_offer_outlined),
                            if (coverage.isNotEmpty) _pill(coverage, icon: Icons.place_outlined),
                            if (country.isNotEmpty) _pill(country),
                            if (verified) _pill('Verified Business', icon: Icons.verified_outlined),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (websiteUrl != null) ...[
                    const SizedBox(width: 8),
                    AdGradientCtaButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ExternalLinkScreen(
                              url: websiteUrl,
                              title: 'Website',
                            ),
                          ),
                        );
                      },
                      icon: Icons.open_in_new,
                      label: 'Visit Website',
                      boxShadow: const [],
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ],
                ],
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111111) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF09433), Color(0xFFDC2743), Color(0xFFBC1888)],
                  ),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.70),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                tabs: const [
                  Tab(text: 'Info'),
                  Tab(text: 'Ads'),
                  Tab(text: 'Contact'),
                ],
              ),
            ),

            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _InfoTab(data: data),
                  _AdsTab(
                    loading: _adsLoading,
                    error: _adsError,
                    ads: _ads,
                    onRetry: _loadAds,
                  ),
                  _ContactTab(data: data),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InfoTab({required this.data});

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String _pick(dynamic value) => value?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final company = _map(data['company_details']);
    final business = _map(data['business_details']);

    final about = _pick(company['about'] ?? business['about'] ?? data['bio'] ?? data['description']);
    final since = _pick(company['established_year'] ?? company['founded'] ?? business['founded']);
    final services = _pick(business['services'] ?? business['service_offerings']);

    Widget card(String title, String body, {IconData? icon}) {
      if (body.trim().isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: const Color(0xFFDC2743)),
                  const SizedBox(width: 8),
                ],
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 2, bottom: 18),
      children: [
        card('About', about, icon: Icons.info_outline),
        card('Established', since, icon: Icons.calendar_month_outlined),
        card('Services', services, icon: Icons.work_outline),
        if (about.trim().isEmpty && services.trim().isEmpty && since.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No information available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _AdsTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<Ad> ads;
  final VoidCallback onRetry;

  const _AdsTab({
    required this.loading,
    required this.error,
    required this.ads,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (ads.isEmpty) {
      return Center(
        child: Text(
          'No ads yet',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 18),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: ads.length,
      itemBuilder: (context, index) {
        final ad = ads[index];
        final thumb = (ad.imageUrl ?? '').trim().isNotEmpty ? ad.imageUrl! : null;
        return InkWell(
          onTap: () => Navigator.of(context).pushNamed('/ads/${ad.id}/details'),
          child: Container(
            color: isDark ? const Color(0xFF121212) : Colors.grey.shade200,
            child: thumb == null
                ? const Center(child: Icon(Icons.shopping_bag_outlined))
                : Image.network(thumb, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}

class _ContactTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ContactTab({required this.data});

  Map<String, dynamic> _map(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const <String, dynamic>{};
  }

  String _pick(dynamic value) => value?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final online = _map(data['online_presence']);

    final website = _pick(online['website_url']);
    final email = _pick(online['company_email']);
    final phone = _pick(online['phone_number']);
    final address = _pick(online['address'] ?? online['company_address']);

    final items = <_ContactItem>[
      if (website.isNotEmpty)
        _ContactItem(
          label: 'Website',
          value: website,
          icon: Icons.public,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ExternalLinkScreen(url: website, title: 'Website'),
            ),
          ),
        ),
    ];

    if (items.isEmpty && email.isEmpty && phone.isEmpty && address.isEmpty) {
      return Center(
        child: Text(
          'No contact info available.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
      children: [
        ...items.map((i) => _ContactTile(item: i, isDark: isDark)),
        if (email.isNotEmpty)
          _ContactTile(
            isDark: isDark,
            item: _ContactItem(
              label: 'Email',
              value: email,
              icon: Icons.email_outlined,
              onTap: () => _copyAndToast(context, email),
            ),
          ),
        if (phone.isNotEmpty)
          _ContactTile(
            isDark: isDark,
            item: _ContactItem(
              label: 'Phone',
              value: phone,
              icon: Icons.phone_outlined,
              onTap: () => _copyAndToast(context, phone),
            ),
          ),
        if (address.isNotEmpty)
          _ContactTile(
            isDark: isDark,
            item: _ContactItem(
              label: 'Address',
              value: address,
              icon: Icons.place_outlined,
              onTap: () => _copyAndToast(context, address),
            ),
          ),
      ],
    );
  }

  static void _copyAndToast(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }
}

class _ContactItem {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _ContactItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
}

class _ContactTile extends StatelessWidget {
  final _ContactItem item;
  final bool isDark;
  const _ContactTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F0F) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: ListTile(
        onTap: item.onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFFDC2743).withValues(alpha: 0.12),
          ),
          child: Icon(item.icon, color: const Color(0xFFDC2743), size: 18),
        ),
        title: Text(
          item.label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            letterSpacing: 1.0,
          ),
        ),
        subtitle: Text(
          item.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
        trailing: Icon(Icons.open_in_new, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
      ),
    );
  }
}
