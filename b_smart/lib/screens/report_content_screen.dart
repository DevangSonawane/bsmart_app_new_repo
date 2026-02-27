import 'package:flutter/material.dart';
import '../services/content_moderation_service.dart';
import '../theme/instagram_theme.dart';

class ReportContentScreen extends StatefulWidget {
  final String reelId;

  const ReportContentScreen({
    super.key,
    required this.reelId,
  });

  @override
  State<ReportContentScreen> createState() => _ReportContentScreenState();
}

class _ReportContentScreenState extends State<ReportContentScreen> {
  final ContentModerationService _moderationService = ContentModerationService();
  String? _selectedReportType;
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _reportTypes = [
    {'id': 'sexual_content', 'title': 'Sexual Content', 'icon': Icons.block},
    {'id': 'inappropriate', 'title': 'Inappropriate', 'icon': Icons.warning},
    {'id': 'spam', 'title': 'Spam', 'icon': Icons.report},
    {'id': 'violence', 'title': 'Violence', 'icon': Icons.dangerous},
    {'id': 'harassment', 'title': 'Harassment', 'icon': Icons.person_off},
    {'id': 'other', 'title': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReportType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a report type')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await _moderationService.reportContent(
      reelId: widget.reelId,
      reportType: _selectedReportType!,
      reason: _reasonController.text.trim().isNotEmpty
          ? _reasonController.text.trim()
          : null,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. We will review this content.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit report. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Content'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Why are you reporting this content?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your report will be reviewed by our moderation team.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Report Type Selection
            ..._reportTypes.map((type) {
              final isSelected = _selectedReportType == type['id'];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: isSelected ? Colors.blue[50] : null,
                child: ListTile(
                  leading: Icon(
                    type['icon'] as IconData,
                    color: isSelected ? Colors.blue : Colors.grey,
                  ),
                  title: Text(type['title']!),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedReportType = type['id'];
                    });
                  },
                ),
              );
            }),

            const SizedBox(height: 24),

            // Additional Details
            const Text(
              'Additional Details (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Provide more details about your report...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),

            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'False reports may result in account restrictions.',
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
