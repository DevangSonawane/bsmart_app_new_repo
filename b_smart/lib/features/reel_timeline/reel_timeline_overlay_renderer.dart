import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../instagram_overlay/overlay_clippers.dart';
import '../../instagram_text_editor/instagram_text_result.dart';
import 'reel_timeline_models.dart';

class ReelTimelineOverlayRenderer {
  static Future<String?> renderOverlayPng({
    required Size size,
    required List<ReelTextOverlay> textOverlays,
    required List<ReelStickerOverlay> stickerOverlays,
  }) async {
    if (textOverlays.isEmpty && stickerOverlays.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);

    // Transparent background
    final paint = Paint()..color = const Color(0x00000000);
    canvas.drawRect(Offset.zero & size, paint);

    // Stickers
    for (final sticker in stickerOverlays) {
      final file = File(sticker.imagePath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final img = await _decodeImage(bytes);
      if (img == null) continue;
      final pos = Offset(
        sticker.normalizedPosition.dx * size.width,
        sticker.normalizedPosition.dy * size.height,
      );
      final baseSize = sticker.baseSize * sticker.scale;
      final rect = Rect.fromLTWH(0, 0, baseSize, baseSize);
      final clipper = overlayClipperFor(sticker.shape);
      final clipPath = clipper.getClip(rect.size);

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.translate(baseSize / 2, baseSize / 2);
      canvas.rotate(sticker.rotation);
      canvas.translate(-baseSize / 2, -baseSize / 2);
      canvas.clipPath(clipPath);
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, baseSize, baseSize),
        image: img,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
      canvas.restore();
    }

    // Text overlays
    for (final text in textOverlays) {
      final pos = Offset(
        text.normalizedPosition.dx * size.width,
        text.normalizedPosition.dy * size.height,
      );
      final baseStyle = text.style.copyWith(
        color: text.textColor,
        fontSize: text.fontSize,
      );

      final textPainter = TextPainter(
        text: TextSpan(text: text.text, style: baseStyle),
        textAlign: text.alignment,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);

      final textSize = textPainter.size;
      final padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
      final bgRect = Rect.fromLTWH(
        0,
        0,
        textSize.width + padding.horizontal,
        textSize.height + padding.vertical,
      );

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.translate(bgRect.width / 2, bgRect.height / 2);
      canvas.rotate(text.rotation);
      canvas.scale(text.scale);
      canvas.translate(-bgRect.width / 2, -bgRect.height / 2);

      if (text.backgroundStyle == BackgroundStyle.perChar) {
        double x = 0;
        for (final rune in text.text.runes) {
          final ch = String.fromCharCode(rune);
          final charPainter = TextPainter(
            text: TextSpan(
              text: ch,
              style: baseStyle,
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final rect = Rect.fromLTWH(
            x,
            0,
            charPainter.size.width,
            charPainter.size.height,
          );
          final bg = Paint()
            ..color = text.textColor.withValues(alpha: 0.2);
          canvas.drawRect(rect, bg);
          charPainter.paint(canvas, Offset(x, 0));
          x += charPainter.size.width;
        }
      } else if (text.backgroundStyle == BackgroundStyle.solid ||
          text.backgroundStyle == BackgroundStyle.transparent) {
        final bgColor = text.backgroundStyle == BackgroundStyle.solid
            ? text.textColor.withValues(alpha: 0.9)
            : text.textColor.withValues(alpha: 0.35);
        final fgColor = text.backgroundStyle == BackgroundStyle.solid
            ? Colors.black
            : text.textColor;
        final rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(10));
        canvas.drawRRect(rrect, Paint()..color = bgColor);
        final fgPainter = TextPainter(
          text: TextSpan(text: text.text, style: baseStyle.copyWith(color: fgColor)),
          textAlign: text.alignment,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width);
        fgPainter.paint(
          canvas,
          Offset(padding.left, padding.top),
        );
      } else {
        textPainter.paint(canvas, Offset(0, 0));
      }

      canvas.restore();
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    final outPath =
        '${Directory.systemTemp.path}/reel_overlay_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(outPath).writeAsBytes(Uint8List.view(data.buffer), flush: true);
    return outPath;
  }

  static Future<ui.Image?> _decodeImage(Uint8List bytes) async {
    final completer = Completer<ui.Image>();
    try {
      ui.decodeImageFromList(bytes, completer.complete);
      return completer.future;
    } catch (_) {
      return null;
    }
  }
}
