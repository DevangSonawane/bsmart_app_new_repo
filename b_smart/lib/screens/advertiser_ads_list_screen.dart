import 'package:flutter/material.dart';
import '../services/advertiser_service.dart';
import 'advertiser_analytics_screen.dart';

class AdvertiserAdsListScreen extends StatelessWidget {
  const AdvertiserAdsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final advertiserService = AdvertiserService();
    final ads = advertiserService.getAdvertiserAds('advertiser-1');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Ads'),
      ),
      body: ads.isEmpty
          ? const Center(
              child: Text('No ads created yet'),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ads.length,
              itemBuilder: (context, index) {
                final ad = ads[index];
                final analytics = advertiserService.getAdAnalytics(ad.id);
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
                      child: const Icon(Icons.video_library),
                    ),
                    title: Text(ad.companyName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Category: ${ad.category.name}'),
                        Text('Status: ${ad.status.name}'),
                        if (analytics != null)
                          Text(
                            'Impressions: ${analytics.totalImpressions} | Views: ${analytics.totalViews}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => AdvertiserAnalyticsScreen(adId: ad.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
