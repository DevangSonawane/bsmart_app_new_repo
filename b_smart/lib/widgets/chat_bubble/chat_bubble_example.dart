import 'package:flutter/material.dart';

import 'chat_bubble_shell.dart';
import 'models.dart';
import 'content/text_message_content.dart';
import 'content/image_message_content.dart';
import 'content/voice_message_content.dart';

class ChatBubbleExample extends StatelessWidget {
  const ChatBubbleExample({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ChatBubbleShell(
          isOutgoing: false,
          isGroup: true,
          senderName: 'Aman',
          timestampText: '9:41 PM',
          deliveryStatus: null,
          groupPosition: ChatBubbleGroupPosition.single,
          child: TextMessageContent(
            text: 'Hello 👋',
            isOutgoing: false,
          ),
        ),
        SizedBox(height: 8),
        ChatBubbleShell(
          isOutgoing: true,
          timestampText: '9:42 PM',
          deliveryStatus: ChatDeliveryStatus.read,
          groupPosition: ChatBubbleGroupPosition.single,
          child: TextMessageContent(
            text: 'Hey! This matches WhatsApp-style bubbles.',
            isOutgoing: true,
          ),
        ),
        SizedBox(height: 8),
        ChatBubbleShell(
          isOutgoing: false,
          timestampText: '9:43 PM',
          deliveryStatus: null,
          groupPosition: ChatBubbleGroupPosition.single,
          child: ImageMessageContent(
            urls: ['https://picsum.photos/600/900'],
            caption: 'Nice view',
            isOutgoing: false,
          ),
        ),
        SizedBox(height: 8),
        ChatBubbleShell(
          isOutgoing: true,
          timestampText: '9:44 PM',
          deliveryStatus: ChatDeliveryStatus.sent,
          groupPosition: ChatBubbleGroupPosition.single,
          child: VoiceMessageContent(
            audioUrl: '',
            totalDurationSeconds: 42,
            isOutgoing: true,
          ),
        ),
      ],
    );
  }
}
