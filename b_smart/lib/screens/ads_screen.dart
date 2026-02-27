import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'product_detail_screen.dart';
import 'advertiser_create_ad_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/design_tokens.dart';

class AdsScreen extends StatefulWidget {
  const AdsScreen({Key? key}) : super(key: key);

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  final SupabaseService _svc = SupabaseService();
  List<Map<String, dynamic>> _ads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    final items = await _svc.fetchAds(limit: 50);
    if (mounted) {
      setState(() {
        _ads = items;
        _loading = false;
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ads center - when empty show a centered CTA similar to the reference screenshot
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ads.isEmpty
              ? SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [DesignTokens.instaPurple, DesignTokens.instaPink, DesignTokens.instaOrange],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(bounds),
                            child: const Text(
                              'Ads Center',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48.0),
                            child: Text(
                              'Create and manage your ad campaigns here. Reach more people and grow your audience.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                            ),
                          ),
                          const SizedBox(height: 28),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdvertiserCreateAdScreen())),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: DesignTokens.instaGradient,
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                              child: const Text('Create Ad', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _ads.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ad = _ads[index];
                    final company = (ad['company'] as Map<String, dynamic>?)?['name'] ?? ad['ad_company_name'] ?? 'Advertiser';
                    final img = (ad['creative_url'] as String?) ?? (ad['image_url'] as String?);
                    return ListTile(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: ad['product_id']?.toString() ?? ''))),
                      contentPadding: const EdgeInsets.all(12),
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      leading: img != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: img, width: 64, height: 64, fit: BoxFit.cover)) : null,
                      title: Text(ad['ad_title'] ?? ad['title'] ?? 'Sponsored'),
                      subtitle: Text(company),
                      trailing: Text(ad['cta_text'] ?? 'Learn'),
                    );
                  },
                ),
    );
  }
}

