import 'package:flutter/material.dart';
import '../services/advertiser_service.dart';

class AdvertiserAnalyticsScreen extends StatefulWidget {
  final String adId;
  final String? timeFilter; // 'today', 'daily', 'weekly', 'monthly', 'lifetime'

  const AdvertiserAnalyticsScreen({
    super.key,
    required this.adId,
    this.timeFilter,
  });

  @override
  State<AdvertiserAnalyticsScreen> createState() => _AdvertiserAnalyticsScreenState();
}

class _AdvertiserAnalyticsScreenState extends State<AdvertiserAnalyticsScreen> {
  final AdvertiserService _advertiserService = AdvertiserService();
  String _selectedTimeFilter = 'lifetime';

  @override
  void initState() {
    super.initState();
    _selectedTimeFilter = widget.timeFilter ?? 'lifetime';
  }

  @override
  Widget build(BuildContext context) {
    final analytics = _advertiserService.getAdAnalytics(widget.adId);
    _advertiserService.getAdvertiserAds('advertiser-1')
        .firstWhere((a) => a.id == widget.adId, orElse: () => throw Exception('Ad not found'));

    if (analytics == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: const Center(child: Text('Analytics not available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Analytics'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedTimeFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'today', child: Text('Today')),
              const PopupMenuItem(value: 'daily', child: Text('Daily')),
              const PopupMenuItem(value: 'weekly', child: Text('Weekly')),
              const PopupMenuItem(value: 'monthly', child: Text('Monthly')),
              const PopupMenuItem(value: 'lifetime', child: Text('Lifetime')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_selectedTimeFilter.toUpperCase()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reach & Exposure
            _buildSection(
              'Reach & Exposure',
              [
                _buildMetricRow('Total Impressions', _formatNumber(analytics.totalImpressions)),
                _buildMetricRow('Unique Viewers', _formatNumber(analytics.uniqueViewers)),
                _buildMetricRow('Repeat Viewers', _formatNumber(analytics.repeatViewers)),
                if (analytics.reachByGeography.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('By Geography:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...analytics.reachByGeography.entries.map((e) =>
                    _buildMetricRow('  ${e.key}', _formatNumber(e.value)),
                  ),
                ],
                if (analytics.reachByLanguage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('By Language:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...analytics.reachByLanguage.entries.map((e) =>
                    _buildMetricRow('  ${e.key}', _formatNumber(e.value)),
                  ),
                ],
              ],
            ),

            // Engagement Metrics
            _buildSection(
              'Engagement Metrics',
              [
                _buildMetricRow('Total Views', _formatNumber(analytics.totalViews)),
                _buildMetricRow('Valid Views (Rewarded)', _formatNumber(analytics.validViews)),
                _buildMetricRow('View-Through Rate (VTR)', '${(analytics.viewThroughRate * 100).toStringAsFixed(1)}%'),
                _buildMetricRow('Avg Watch Duration', '${analytics.averageWatchDuration.toStringAsFixed(1)}s'),
                _buildMetricRow('Completion Rate', '${(analytics.completionRate * 100).toStringAsFixed(1)}%'),
                if (analytics.dropOffPoints.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Drop-off Points:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...analytics.dropOffPoints.entries.map((e) =>
                    _buildMetricRow('  ${e.key}', _formatNumber(e.value)),
                  ),
                ],
              ],
            ),

            // Watch Time Analytics
            _buildSection(
              'Watch Time Analytics',
              [
                _buildMetricRow('Total Watch Hours', analytics.totalWatchHours.toStringAsFixed(2)),
                _buildMetricRow('Avg Watch Time/View', '${analytics.averageWatchTimePerView.toStringAsFixed(1)}s'),
              ],
            ),

            // Audience Demographics
            _buildSection(
              'Audience Demographics',
              [
                if (analytics.genderSplit.isNotEmpty) ...[
                  const Text('Gender Split:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...analytics.genderSplit.entries.map((e) =>
                    _buildMetricRow('  ${e.key}', _formatNumber(e.value)),
                  ),
                  const SizedBox(height: 8),
                ],
                if (analytics.ageGroups.isNotEmpty) ...[
                  const Text('Age Groups:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...analytics.ageGroups.entries.map((e) =>
                    _buildMetricRow('  ${e.key}', _formatNumber(e.value)),
                  ),
                ],
              ],
            ),

            // Reward & Cost Metrics
            _buildSection(
              'Reward & Cost Metrics',
              [
                _buildMetricRow('Coins Allocated', _formatNumber(analytics.totalCoinsAllocated)),
                _buildMetricRow('Coins Consumed', _formatNumber(analytics.coinsConsumed)),
                _buildMetricRow('Coins Remaining', _formatNumber(analytics.coinsRemaining)),
                _buildMetricRow('Rewards Issued', _formatNumber(analytics.rewardsIssued)),
                _buildMetricRow('Avg Coins/User', analytics.averageCoinsPerUser.toStringAsFixed(1)),
                _buildMetricRow('Cost per Valid Reward', '₹${analytics.costPerValidReward.toStringAsFixed(2)}'),
                _buildMetricRow('Cost per Watch Minute', '₹${analytics.costPerWatchMinute.toStringAsFixed(2)}'),
              ],
            ),

            // Conversion Metrics
            _buildSection(
              'Conversion & Interaction',
              [
                _buildMetricRow('Click-Through Rate', '${analytics.clickThroughRate}'),
                _buildMetricRow('Profile Visits', _formatNumber(analytics.profileVisits)),
                _buildMetricRow('Company Page Opens', _formatNumber(analytics.companyPageOpens)),
                _buildMetricRow('External Link Clicks', _formatNumber(analytics.externalLinkClicks)),
                _buildMetricRow('Follow Actions', _formatNumber(analytics.followActions)),
              ],
            ),

            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report download feature coming soon')),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Report'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 0),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
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
