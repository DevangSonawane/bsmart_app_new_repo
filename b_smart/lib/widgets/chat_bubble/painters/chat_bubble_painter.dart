import 'package:flutter/material.dart';

import '../models.dart';

class ChatBubblePainter extends CustomPainter {
  final Color color;
  final bool isOutgoing;
  final bool showTail;
  final ChatBubbleGroupPosition groupPosition;
  final Color? borderColor;
  final double borderWidth;

  const ChatBubblePainter({
    required this.color,
    required this.isOutgoing,
    required this.showTail,
    required this.groupPosition,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final rBig = 18.0;
    final rSmall = 6.0;

    final tl = (groupPosition == ChatBubbleGroupPosition.middle ||
            groupPosition == ChatBubbleGroupPosition.bottom)
        ? rSmall
        : rBig;
    final tr = (groupPosition == ChatBubbleGroupPosition.middle ||
            groupPosition == ChatBubbleGroupPosition.bottom)
        ? rSmall
        : rBig;
    final bl = (groupPosition == ChatBubbleGroupPosition.middle ||
            groupPosition == ChatBubbleGroupPosition.top)
        ? rSmall
        : rBig;
    final br = (groupPosition == ChatBubbleGroupPosition.middle ||
            groupPosition == ChatBubbleGroupPosition.top)
        ? rSmall
        : rBig;

    final tailW = showTail ? 10.0 : 0.0;
    final tailH = showTail ? 14.0 : 0.0;

    final rect = isOutgoing
        ? Rect.fromLTWH(0, 0, size.width - tailW, size.height)
        : Rect.fromLTWH(tailW, 0, size.width - tailW, size.height);

    final rr = RRect.fromRectAndCorners(
      rect,
      topLeft: Radius.circular(tl),
      topRight: Radius.circular(tr),
      bottomLeft: Radius.circular(bl),
      bottomRight: Radius.circular(br),
    );

    final path = Path()..addRRect(rr);

    if (showTail) {
      // Modern WhatsApp-like "integrated" tail using curves (not a triangle).
      if (isOutgoing) {
        final x = rect.right;
        final y = rect.bottom - 16;
        path
          ..moveTo(x, y)
          ..cubicTo(x + 2, y + 2, x + 7, y + 7, x + tailW, y + 10)
          ..cubicTo(x + 6, y + 12, x + 2, y + 12, x, y + 8)
          ..close();
      } else {
        final x = rect.left;
        final y = rect.bottom - 16;
        path
          ..moveTo(x, y)
          ..cubicTo(x - 2, y + 2, x - 7, y + 7, x - tailW, y + 10)
          ..cubicTo(x - 6, y + 12, x - 2, y + 12, x, y + 8)
          ..close();
      }
    }

    canvas.drawPath(path, paint);

    final bc = borderColor;
    if (bc != null && borderWidth > 0) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..color = bc;
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant ChatBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isOutgoing != isOutgoing ||
        oldDelegate.showTail != showTail ||
        oldDelegate.groupPosition != groupPosition ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

