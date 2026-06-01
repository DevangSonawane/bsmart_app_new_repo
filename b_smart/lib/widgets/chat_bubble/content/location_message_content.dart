import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../chat_bubble_theme.dart';

class LocationMessageContent extends StatelessWidget {
  final String label;
  final bool isOutgoing;
  final VoidCallback? onTap;

  const LocationMessageContent({
    super.key,
    required this.label,
    required this.isOutgoing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChatBubbleTheme.of(context);
    final fg =
        isOutgoing ? theme.colors.outgoingText : theme.colors.incomingText;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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
            child: Icon(LucideIcons.mapPin, size: 18, color: fg),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label.trim().isEmpty ? 'Location' : label.trim(),
              style: theme.typography.message.copyWith(color: fg),
              textScaler: MediaQuery.textScalerOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

