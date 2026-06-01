import 'package:flutter/material.dart';

import '../chat_bubble_theme.dart';

class VideoMessageContent extends StatelessWidget {
  final Widget thumbnail;
  final String caption;
  final bool isOutgoing;

  const VideoMessageContent({
    super.key,
    required this.thumbnail,
    required this.caption,
    required this.isOutgoing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChatBubbleTheme.of(context);
    final fg = isOutgoing ? theme.colors.outgoingText : theme.colors.incomingText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: thumbnail,
        ),
        if (caption.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            caption.trim(),
            style: theme.typography.message.copyWith(color: fg),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ],
      ],
    );
  }
}

