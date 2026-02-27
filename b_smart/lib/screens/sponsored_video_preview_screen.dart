import 'package:flutter/material.dart';
import '../models/user_account_model.dart';
import '../services/sponsored_video_service.dart';

class SponsoredVideoPreviewScreen extends StatelessWidget {
  final String videoId;

  const SponsoredVideoPreviewScreen({
    super.key,
    required this.videoId,
  });

  @override
  Widget build(BuildContext context) {
    final videoService = SponsoredVideoService();

    return FutureBuilder<SponsoredVideo?>(
      future: videoService.getVideo(videoId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final video = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Submission Status'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card
                Card(
                  color: _getStatusColor(video.status),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(video.status),
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getStatusLabel(video.status),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (video.submittedAt != null)
                                Text(
                                  'Submitted: ${_formatDate(video.submittedAt!)}',
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
                ),
                const SizedBox(height: 24),

                // Video Preview
                if (video.videoUrl != null) ...[
                  const Text(
                    'Video Preview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.play_circle_outline, size: 60, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                ],

                // Product Details
                const Text(
                  'Product Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.productName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(video.productDescription),
                        const SizedBox(height: 8),
                        if (video.price != null)
                          Text(
                            '${video.currency ?? 'USD'} ${video.price!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text('Brand: ${video.brandName}'),
                        if (video.productCategory != null) ...[
                          const SizedBox(height: 4),
                          Text('Category: ${video.productCategory}'),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Product URL: ${video.productUrl}',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Rejection Reason
                if (video.status == SponsoredVideoStatus.rejected && video.rejectionReason != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Rejection Reason',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(video.rejectionReason!),
                      ],
                    ),
                  ),
                ],

                // Next Steps
                if (video.status == SponsoredVideoStatus.underReview) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'What happens next?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('• Your video is being reviewed by our moderation team'),
                        const Text('• Content policy scan is in progress'),
                        const Text('• Product validation is being performed'),
                        const Text('• You will be notified once the review is complete'),
                      ],
                    ),
                  ),
                ],

                if (video.status == SponsoredVideoStatus.approved) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Approved!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Your sponsored video has been approved and will appear in:'),
                        const SizedBox(height: 4),
                        const Text('• Sponsored Feed'),
                        const Text('• Play / Video Feed (interleaved)'),
                        const Text('• Category-based filtered feeds'),
                        if (video.campaignId != null) ...[
                          const SizedBox(height: 8),
                          Text('Campaign ID: ${video.campaignId}'),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(SponsoredVideoStatus status) {
    switch (status) {
      case SponsoredVideoStatus.draft:
        return Colors.grey;
      case SponsoredVideoStatus.underReview:
        return Colors.orange;
      case SponsoredVideoStatus.approved:
        return Colors.green;
      case SponsoredVideoStatus.rejected:
        return Colors.red;
      case SponsoredVideoStatus.live:
        return Colors.blue;
      case SponsoredVideoStatus.paused:
        return Colors.amber;
    }
  }

  IconData _getStatusIcon(SponsoredVideoStatus status) {
    switch (status) {
      case SponsoredVideoStatus.draft:
        return Icons.edit;
      case SponsoredVideoStatus.underReview:
        return Icons.hourglass_empty;
      case SponsoredVideoStatus.approved:
        return Icons.check_circle;
      case SponsoredVideoStatus.rejected:
        return Icons.cancel;
      case SponsoredVideoStatus.live:
        return Icons.play_circle;
      case SponsoredVideoStatus.paused:
        return Icons.pause_circle;
    }
  }

  String _getStatusLabel(SponsoredVideoStatus status) {
    switch (status) {
      case SponsoredVideoStatus.draft:
        return 'Draft';
      case SponsoredVideoStatus.underReview:
        return 'Under Review';
      case SponsoredVideoStatus.approved:
        return 'Approved';
      case SponsoredVideoStatus.rejected:
        return 'Rejected';
      case SponsoredVideoStatus.live:
        return 'Live';
      case SponsoredVideoStatus.paused:
        return 'Paused';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
