import 'package:flutter/material.dart';
import '../services/ad_service.dart';
import '../theme/instagram_theme.dart';

class AdCompanyDetailScreen extends StatelessWidget {
  final String companyId;

  const AdCompanyDetailScreen({super.key, required this.companyId});

  @override
  Widget build(BuildContext context) {
    final adService = AdService();
    final company = adService.getCompanyById(companyId);

    if (company == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Company Details'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Company not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Details'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                company.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (company.isVerified) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.verified, color: Colors.blue, size: 20),
                              ],
                            ],
                          ),
                          if (company.websiteUrl != null)
                            Text(
                              company.websiteUrl!,
                              style: TextStyle(
                                color: Colors.blue,
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
            const SizedBox(height: 16),

            // Business Description
            const Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              company.description,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),

            // Active Ads
            const Text(
              'Active Ads',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (company.activeAds.isEmpty)
              const Text('No active ads')
            else
              ...company.activeAds.map((ad) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.ads_click, color: Colors.blue),
                      title: Text(ad.title),
                      subtitle: Text(ad.description),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+${ad.coinReward}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
