import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chat_bubble_theme.dart';

class DocumentMessageContent extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isOutgoing;
  final VoidCallback? onTap;

  const DocumentMessageContent({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isOutgoing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChatBubbleTheme.of(context);
    final colors = theme.colors;
    final fg = isOutgoing ? colors.outgoingText : colors.incomingText;
    final meta = isOutgoing ? colors.outgoingMeta : colors.incomingMeta;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.fileText, size: 18, color: fg),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.trim().isEmpty ? 'Document' : title.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.typography.message.copyWith(color: fg),
                    textScaler: MediaQuery.textScalerOf(context),
                  ),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.timestamp.copyWith(color: meta),
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

