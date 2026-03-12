import 'package:flutter/material.dart';
import '../models/ad_category_model.dart';
import '../models/ad_model.dart';
import '../services/ads_service.dart';
import '../services/advertiser_service.dart';
import '../utils/current_user.dart';
import 'advertiser_analytics_screen.dart';

class AdvertiserAdsListScreen extends StatefulWidget {
  const AdvertiserAdsListScreen({super.key});

  @override
  State<AdvertiserAdsListScreen> createState() => _AdvertiserAdsListScreenState();
}

class _AdvertiserAdsListScreenState extends State<AdvertiserAdsListScreen> {
  final AdvertiserService _advertiserService = AdvertiserService();
  final AdsService _adsService = AdsService();

  List<AdCategory> _categories = [AdCategory(id: 'All', name: 'All')];
  String _selectedCategory = 'All';
  List<Ad> _ads = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = await CurrentUser.id;
      final categories = await _adsService.fetchCategories();
      final hasSelected = categories.any((c) => c.id == _selectedCategory);
      final selected = hasSelected ? _selectedCategory : 'All';

      List<Ad> ads = const [];
      if (userId != null && userId.trim().isNotEmpty) {
        ads = await _adsService.fetchUserAds(
          userId: userId,
          category: selected,
        );
      } else {
        ads = _loadLocalFallbackAds();
      }

      if (!mounted) return;
      setState(() {
        _categories = categories.isEmpty
            ? [AdCategory(id: 'All', name: 'All')]
            : categories;
        _selectedCategory = selected;
        _ads = ads;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categories = _adsService.getFallbackCategories();
        _ads = _loadLocalFallbackAds();
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onCategorySelected(String categoryId) async {
    if (_selectedCategory == categoryId) return;
    setState(() {
      _selectedCategory = categoryId;
    });
    await _load();
  }

  Future<void> _deleteAd(Ad ad) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ad?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _adsService.deleteAd(ad.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad deleted successfully.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete ad: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ads'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        children: _categories
                            .map((c) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(c.name),
                                    selected: _selectedCategory == c.id,
                                    onSelected: (_) => _onCategorySelected(c.id),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    Expanded(
                      child: _ads.isEmpty
                          ? const Center(child: Text('No ads created yet'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _ads.length,
                              itemBuilder: (context, index) {
                                final ad = _ads[index];
                                final analytics = _advertiserService.getAdAnalytics(ad.id);
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ListTile(
                                    leading: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: ad.imageUrl != null && ad.imageUrl!.isNotEmpty
                                          ? Image.network(ad.imageUrl!, fit: BoxFit.cover)
                                          : const Icon(Icons.video_library),
                                    ),
                                    title: Text(ad.title),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Category: ${ad.category ?? 'Uncategorized'}'),
                                        Text('Likes: ${ad.likesCount} | Comments: ${ad.commentsCount}'),
                                        if (analytics != null)
                                          Text(
                                            'Impressions: ${analytics.totalImpressions} | Views: ${analytics.totalViews}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                      ],
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'analytics') {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => AdvertiserAnalyticsScreen(adId: ad.id),
                                            ),
                                          );
                                          return;
                                        }
                                        if (value == 'delete') {
                                          _deleteAd(ad);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem<String>(
                                          value: 'analytics',
                                          child: Text('View analytics'),
                                        ),
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text('Delete ad'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            const Text('Failed to load your ads'),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  List<Ad> _loadLocalFallbackAds() {
    final advertiserAds = _advertiserService.getAdvertiserAds('advertiser-1');
    return advertiserAds
        .map((a) => Ad(
              id: a.id,
              companyId: a.advertiserId,
              companyName: a.companyName,
              title: a.companyName,
              description: a.companyDescription ?? '',
              category: a.category.name,
              videoUrl: a.videoUrl,
              imageUrl: a.bannerUrl,
              likesCount: 0,
              commentsCount: 0,
              sharesCount: 0,
              coinReward: 0,
              watchDurationSeconds: a.category.durationSeconds,
              maxRewardableViews: 0,
              createdAt: a.createdAt,
              isActive: a.status.name == 'active',
            ))
        .toList();
  }
}
