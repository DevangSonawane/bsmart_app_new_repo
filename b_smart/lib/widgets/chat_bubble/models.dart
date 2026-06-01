import 'package:flutter/material.dart';

enum ChatMessageType {
  text,
  image,
  voice,
  video,
  document,
  location,
  unknown,
}

enum ChatDeliveryStatus {
  sending,
  sent,
  delivered,
  read,
}

enum ChatBubbleGroupPosition {
  single,
  top,
  middle,
  bottom,
}

@immutable
class ChatReaction {
  final String emoji;
  final int count;
  final bool isMine;

  const ChatReaction({
    required this.emoji,
    required this.count,
    this.isMine = false,
  });

  String get label => count <= 1 ? emoji : '$emoji $count';
}

@immutable
class ChatReplyPreview {
  final String senderLabel;
  final String text;
  final ChatMessageType type;

  const ChatReplyPreview({
    required this.senderLabel,
    required this.text,
    this.type = ChatMessageType.text,
  });
}

