import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'chat_bubble_theme.dart';
import 'models.dart';
import 'painters/chat_bubble_painter.dart';

class ChatBubbleShell extends StatelessWidget {
  final bool isOutgoing;
  final bool isGroup;
  final String? senderName;
  final Color? senderColor;
  final ChatReplyPreview? reply;
  final bool isSelected;
  final bool bareContent;
  final bool showTail;
  final ChatBubbleGroupPosition groupPosition;
  final String? timestampText;
  final ChatDeliveryStatus? deliveryStatus;
  final List<ChatReaction> reactions;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final Widget child;

  const ChatBubbleShell({
    super.key,
    required this.isOutgoing,
    required this.child,
    this.isGroup = false,
    this.senderName,
    this.senderColor,
    this.reply,
    this.isSelected = false,
    this.bareContent = false,
    this.showTail = true,
    this.groupPosition = ChatBubbleGroupPosition.single,
    this.timestampText,
    this.deliveryStatus,
    this.reactions = const [],
    this.onLongPress,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChatBubbleTheme.of(context);
    final colors = theme.colors;
    final typography = theme.typography;

    final bubbleColor = isOutgoing ? colors.outgoingBubble : colors.incomingBubble;
    final textColor = isOutgoing ? colors.outgoingText : colors.incomingText;
    final metaColor = isOutgoing ? colors.outgoingMeta : colors.incomingMeta;
    final nameColor = senderColor ?? colors.senderName;

    final maxWidth = MediaQuery.sizeOf(context).width * 0.72;
    final hasMeta = (timestampText ?? '').trim().isNotEmpty;
    final metaReserveRight = hasMeta ? 68.0 : 0.0;
    final metaReserveBottom = hasMeta ? 16.0 : 0.0;

    final padding = EdgeInsets.fromLTRB(
      12,
      (isGroup && !isOutgoing && (senderName ?? '').trim().isNotEmpty) ? 8 : 10,
      12,
      18, // base reserve for timestamp/status
    );

    final border = isSelected ? colors.selection.withValues(alpha: 0.55) : null;

    final content = GestureDetector(
      onLongPress: onLongPress,
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: bareContent
            ? Stack(
                children: [
                  child,
                  if (hasMeta)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timestampText!.trim(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                textScaler: MediaQuery.textScalerOf(context),
                              ),
                              if (isOutgoing) ...[
                                const SizedBox(width: 4),
                                _DeliveryIcon(
                                  status: deliveryStatus,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : CustomPaint(
                painter: ChatBubblePainter(
                  color: bubbleColor,
                  isOutgoing: isOutgoing,
                  showTail: showTail,
                  groupPosition: groupPosition,
                  borderColor: border,
                  borderWidth: border == null ? 0 : 1,
                ),
                child: Padding(
                  padding: padding,
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          right: metaReserveRight,
                          bottom: metaReserveBottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isGroup &&
                                !isOutgoing &&
                                (senderName ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  senderName!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      typography.sender.copyWith(color: nameColor),
                                  textScaler: MediaQuery.textScalerOf(context),
                                ),
                              ),
                            if (reply != null) ...[
                              _ReplyPreviewChip(
                                reply: reply!,
                                isOutgoing: isOutgoing,
                              ),
                              const SizedBox(height: 6),
                            ],
                            DefaultTextStyle(
                              style: typography.message.copyWith(color: textColor),
                              child: child,
                            ),
                          ],
                        ),
                      ),
                      if (hasMeta)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timestampText!.trim(),
                                style: typography.timestamp.copyWith(color: metaColor),
                                textScaler: MediaQuery.textScalerOf(context),
                              ),
                              if (isOutgoing) ...[
                                const SizedBox(width: 4),
                                _DeliveryIcon(
                                  status: deliveryStatus,
                                  color: metaColor,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: content,
    );

    final reactionLabel =
        reactions.isEmpty ? null : reactions.first.label; // compact for now
    final reactionPill = reactionLabel == null
        ? null
        : Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.reactionBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.30)),
            ),
            child: Text(
              reactionLabel,
              style: typography.reaction.copyWith(color: colors.reactionFg),
              textScaler: MediaQuery.textScalerOf(context),
            ),
          );

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          bubble,
          if (reactionPill != null) reactionPill,
        ],
      ),
    );
  }
}

class _DeliveryIcon extends StatelessWidget {
  final ChatDeliveryStatus? status;
  final Color color;

  const _DeliveryIcon({
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final s = status ?? ChatDeliveryStatus.sent;
    if (s == ChatDeliveryStatus.sending) {
      return Icon(LucideIcons.clock3, size: 13, color: color);
    }
    if (s == ChatDeliveryStatus.sent) {
      return Icon(LucideIcons.check, size: 14, color: color);
    }
    if (s == ChatDeliveryStatus.delivered) {
      return Icon(LucideIcons.checkCheck, size: 14, color: color);
    }
    return Icon(LucideIcons.checkCheck, size: 14, color: const Color(0xFF34B7F1));
  }
}

class _ReplyPreviewChip extends StatelessWidget {
  final ChatReplyPreview reply;
  final bool isOutgoing;

  const _ReplyPreviewChip({
    required this.reply,
    required this.isOutgoing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ChatBubbleTheme.of(context);
    final colors = theme.colors;
    final fg = isOutgoing ? colors.outgoingText : colors.incomingText;
    final meta = isOutgoing ? colors.outgoingMeta : colors.incomingMeta;
    final bar = isOutgoing
        ? Colors.white.withValues(alpha: 0.30)
        : Colors.black.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: (isOutgoing ? Colors.white : Colors.black).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: bar,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reply.senderLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.replySender.copyWith(color: fg),
                  textScaler: MediaQuery.textScalerOf(context),
                ),
                const SizedBox(height: 2),
                Text(
                  reply.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.replyText.copyWith(color: meta),
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
