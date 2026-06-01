import 'package:flutter/material.dart';

@immutable
class ChatBubbleColors {
  final Color incomingBubble;
  final Color outgoingBubble;
  final Color incomingText;
  final Color outgoingText;
  final Color incomingMeta;
  final Color outgoingMeta;
  final Color selection;
  final Color senderName;
  final Color reactionBg;
  final Color reactionFg;

  const ChatBubbleColors({
    required this.incomingBubble,
    required this.outgoingBubble,
    required this.incomingText,
    required this.outgoingText,
    required this.incomingMeta,
    required this.outgoingMeta,
    required this.selection,
    required this.senderName,
    required this.reactionBg,
    required this.reactionFg,
  });
}

@immutable
class ChatBubbleTypography {
  final TextStyle message;
  final TextStyle sender;
  final TextStyle timestamp;
  final TextStyle replySender;
  final TextStyle replyText;
  final TextStyle reaction;

  const ChatBubbleTypography({
    required this.message,
    required this.sender,
    required this.timestamp,
    required this.replySender,
    required this.replyText,
    required this.reaction,
  });
}

@immutable
class ChatBubbleThemeData {
  final ChatBubbleColors colors;
  final ChatBubbleTypography typography;

  const ChatBubbleThemeData({
    required this.colors,
    required this.typography,
  });

  static ChatBubbleThemeData light() {
    return ChatBubbleThemeData(
      colors: const ChatBubbleColors(
        incomingBubble: Color(0xFFFFFFFF),
        outgoingBubble: Color(0xFF7C3AED), // App theme (purple)
        incomingText: Color(0xFF111827),
        outgoingText: Color(0xFFFFFFFF),
        incomingMeta: Color(0xFF6B7280),
        outgoingMeta: Color(0xFFE5E7EB),
        selection: Color(0xFF1D4ED8),
        senderName: Color(0xFF0EA5E9),
        reactionBg: Color(0xFFF3F4F6),
        reactionFg: Color(0xFF111827),
      ),
      typography: const ChatBubbleTypography(
        message: TextStyle(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w500,
        ),
        sender: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
        timestamp: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        replySender: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        replyText: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        reaction: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }

  static ChatBubbleThemeData dark() {
    return ChatBubbleThemeData(
      colors: const ChatBubbleColors(
        incomingBubble: Color(0xFF1F2C34),
        outgoingBubble: Color(0xFF7C3AED), // App theme (purple)
        incomingText: Color(0xFFE5E7EB),
        outgoingText: Color(0xFFFFFFFF),
        incomingMeta: Color(0xFF9CA3AF),
        outgoingMeta: Color(0xFFE5E7EB),
        selection: Color(0xFF60A5FA),
        senderName: Color(0xFF38BDF8),
        reactionBg: Color(0xFF0B141A),
        reactionFg: Color(0xFFE5E7EB),
      ),
      typography: light().typography,
    );
  }
}

class ChatBubbleTheme extends InheritedWidget {
  final ChatBubbleThemeData data;

  const ChatBubbleTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static ChatBubbleThemeData of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<ChatBubbleTheme>();
    if (inherited != null) return inherited.data;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? ChatBubbleThemeData.dark() : ChatBubbleThemeData.light();
  }

  @override
  bool updateShouldNotify(ChatBubbleTheme oldWidget) => data != oldWidget.data;
}
