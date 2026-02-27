import 'package:flutter/material.dart';
import '../models/boost_model.dart';
import '../services/boost_service.dart';

class BoostAnalyticsScreen extends StatelessWidget {
  final String boostId;

  const BoostAnalyticsScreen({
    super.key,
    required this.boostId,
  });

  @override
  Widget build(BuildContext context) {
    final boostService = BoostService();
    final boost = boostService.getBoost(boostId);
    final analytics = boostService.getBoostAnalytics(boostId);

    if (boost == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Boost Analytics')),
        body: const Center(child: Text('Boost not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boost Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor(boost.status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(boost.status),
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          boost.status.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (boost.remainingDuration != null)
                          Text(
                            '${boost.remainingDuration!.inHours}h ${(boost.remainingDuration!.inMinutes % 60)}m remaining',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Metrics
            const Text(
              'Performance Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Impressions',
                    '${analytics?.impressions ?? boost.actualImpressions}',
                    Icons.visibility,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Views',
                    '${analytics?.views ?? 0}',
                    Icons.play_arrow,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Likes',
                    '${analytics?.likes ?? 0}',
                    Icons.favorite,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Comments',
                    '${analytics?.comments ?? 0}',
                    Icons.comment,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Shares',
                    '${analytics?.shares ?? 0}',
                    Icons.share,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    'Engagement',
                    '${((analytics?.engagementRate ?? 0) * 100).toStringAsFixed(1)}%',
                    Icons.trending_up,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Boost Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Boost Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Duration', '${boost.duration.hours} hours'),
                    _buildDetailRow('Cost', '\$${boost.cost.toStringAsFixed(2)}'),
                    _buildDetailRow('Payment Status', boost.paymentStatus.name.toUpperCase()),
                    _buildDetailRow(
                      'Started',
                      _formatDateTime(boost.startTime),
                    ),
                    if (boost.endTime != null)
                      _buildDetailRow(
                        'Ends',
                        _formatDateTime(boost.endTime!),
                      ),
                    if (boost.pauseReason != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Paused: ${boost.pauseReason}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (boost.cancellationReason != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cancel, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cancelled: ${boost.cancellationReason}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Last Updated
            if (analytics != null) ...[
              const SizedBox(height: 16),
              Text(
                'Last updated: ${_formatDateTime(analytics.lastUpdated)}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
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

  Color _getStatusColor(BoostStatus status) {
    switch (status) {
      case BoostStatus.active:
        return Colors.green;
      case BoostStatus.pending:
        return Colors.orange;
      case BoostStatus.paused:
        return Colors.amber;
      case BoostStatus.completed:
        return Colors.blue;
      case BoostStatus.cancelled:
        return Colors.red;
      case BoostStatus.refunded:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(BoostStatus status) {
    switch (status) {
      case BoostStatus.active:
        return Icons.trending_up;
      case BoostStatus.pending:
        return Icons.hourglass_empty;
      case BoostStatus.paused:
        return Icons.pause_circle;
      case BoostStatus.completed:
        return Icons.check_circle;
      case BoostStatus.cancelled:
        return Icons.cancel;
      case BoostStatus.refunded:
        return Icons.refresh;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
