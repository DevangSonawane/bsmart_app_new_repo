import 'package:flutter/material.dart';

import '../chat_bubble_theme.dart';

class TextMessageContent extends StatelessWidget {
  final String text;
  final bool isOutgoing;
  final Widget? leading;

  const TextMessageContent({
    super.key,
    required this.text,
    required this.isOutgoing,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChatBubbleTheme.of(context);
    final colors = theme.colors;
    final typography = theme.typography;
    final fg = isOutgoing ? colors.outgoingText : colors.incomingText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          leading!,
          if (text.trim().isNotEmpty) const SizedBox(height: 8),
        ],
        if (text.trim().isNotEmpty)
          Text(
            text,
            style: typography.message.copyWith(color: fg),
            textScaler: MediaQuery.textScalerOf(context),
          ),
      ],
    );
  }
}

