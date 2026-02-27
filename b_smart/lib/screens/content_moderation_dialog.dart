import 'package:flutter/material.dart';
import '../models/content_moderation_model.dart';

class ContentModerationDialog extends StatelessWidget {
  final ContentModerationResult result;
  final VoidCallback? onAppeal;
  final VoidCallback? onDismiss;

  const ContentModerationDialog({
    super.key,
    required this.result,
    this.onAppeal,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getIcon(),
            color: _getColor(),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getTitle(),
              style: TextStyle(
                color: _getColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.reason ?? 'Content moderation check failed.',
            style: const TextStyle(fontSize: 14),
          ),
          if (result.flaggedElements.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Flagged elements:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.flaggedElements.map((element) {
                return Chip(
                  label: Text(element),
                  backgroundColor: Colors.orange[100],
                  labelStyle: const TextStyle(fontSize: 11),
                );
              }).toList(),
            ),
          ],
          if (result.severity == ContentSeverity.explicit) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Text(
                'This content violates our community guidelines and cannot be published.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onAppeal != null && result.isBlocked)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onAppeal?.call();
            },
            child: const Text('Appeal'),
          ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: Text(result.isBlocked ? 'Close' : 'OK'),
        ),
        if (result.isBlocked)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Open content policy
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Content Policy'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'Our content policy prohibits explicit sexual content, nudity, and pornographic material. '
                      'Sexualized content may be restricted. Sponsored content must be completely free of sexual or suggestive elements.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('View Policy'),
          ),
      ],
    );
  }

  IconData _getIcon() {
    switch (result.action) {
      case ModerationAction.block:
        return Icons.block;
      case ModerationAction.restrict:
        return Icons.visibility_off;
      case ModerationAction.allowWithRestrictions:
        return Icons.info_outline;
      case ModerationAction.allow:
        return Icons.check_circle;
    }
  }

  String _getTitle() {
    switch (result.action) {
      case ModerationAction.block:
        return 'Content Blocked';
      case ModerationAction.restrict:
        return 'Content Restricted';
      case ModerationAction.allowWithRestrictions:
        return 'Content Published with Restrictions';
      case ModerationAction.allow:
        return 'Content Approved';
    }
  }

  Color _getColor() {
    switch (result.action) {
      case ModerationAction.block:
        return Colors.red;
      case ModerationAction.restrict:
        return Colors.orange;
      case ModerationAction.allowWithRestrictions:
        return Colors.amber;
      case ModerationAction.allow:
        return Colors.green;
    }
  }
}
