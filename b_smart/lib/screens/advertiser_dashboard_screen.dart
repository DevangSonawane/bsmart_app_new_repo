import 'package:flutter/material.dart';
import '../services/advertiser_service.dart';
import 'advertiser_analytics_screen.dart';
import 'advertiser_create_ad_screen.dart';
import 'advertiser_wallet_screen.dart';
import 'advertiser_ads_list_screen.dart';

class AdvertiserDashboardScreen extends StatelessWidget {
  const AdvertiserDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final advertiserService = AdvertiserService();
    final account = advertiserService.getCurrentAccount();
    final metrics = advertiserService.getDashboardMetrics(account.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertiser Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & Support')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Summary Card
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business, size: 32, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.companyName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (account.currentPlan != null)
                                Text(
                                  '${account.currentPlan!.name.toUpperCase()} Plan',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Core Metrics
            const Text(
              'Core Metrics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard('Total Ads', '${metrics.totalAdsCreated}'),
                _buildMetricCard('Active Ads', '${metrics.activeAds}'),
                _buildMetricCard('Ads Remaining', '${metrics.adsRemainingInPlan}'),
                _buildMetricCard('Total Impressions', _formatNumber(metrics.totalImpressions)),
                _buildMetricCard('Rewarded Users', _formatNumber(metrics.totalRewardedUsers)),
                _buildMetricCard('Watch Hours', metrics.totalWatchHours.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 24),

            // Coins Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Coins Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Total Purchased', _formatNumber(metrics.totalCoinsPurchased)),
                    _buildDetailRow('Available', _formatNumber(metrics.coinsAvailable)),
                    _buildDetailRow('Consumed', _formatNumber(metrics.coinsConsumed)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: metrics.totalCoinsPurchased > 0
                          ? metrics.coinsConsumed / metrics.totalCoinsPurchased
                          : 0.0,
                      backgroundColor: Colors.grey[300],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Insights
            const Text(
              'Quick Insights',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (metrics.bestPerformingAd != null)
              Card(
                color: Colors.green[50],
                child: ListTile(
                  leading: const Icon(Icons.trending_up, color: Colors.green),
                  title: const Text('Best Performing Ad'),
                  subtitle: Text(metrics.bestPerformingAd!.companyName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AdvertiserAnalyticsScreen(
                          adId: metrics.bestPerformingAd!.id,
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (metrics.lowestPerformingAd != null)
              Card(
                color: Colors.orange[50],
                child: ListTile(
                  leading: const Icon(Icons.trending_down, color: Colors.orange),
                  title: const Text('Lowest Performing Ad'),
                  subtitle: Text(metrics.lowestPerformingAd!.companyName),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AdvertiserAnalyticsScreen(
                          adId: metrics.lowestPerformingAd!.id,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AdvertiserCreateAdScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Ad'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AdvertiserAdsListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list),
                    label: const Text('View Ads'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AdvertiserWalletScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.account_balance_wallet),
                    label: const Text('Wallet'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Contact: ${account.salesOfficerContact ?? 'sales@bsmart.com'}')),
                      );
                    },
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Support'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
