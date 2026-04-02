import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'reel_timeline_models.dart';
import 'reel_timeline_overlay_renderer.dart';

class ReelTimelineRenderer {
  final Size outputSize;
  final int fps;
  ReelTimelineRenderer({
    required this.outputSize,
    this.fps = 30,
  });

  Future<String?> renderTimeline(List<ReelClip> clips) async {
    if (clips.isEmpty) return null;
    final tmpDir = await Directory.systemTemp.createTemp('bsmart_reel_timeline_');
    final segmentPaths = <String>[];

    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      final overlayPath = await ReelTimelineOverlayRenderer.renderOverlayPng(
        size: outputSize,
        textOverlays: clip.textOverlays,
        stickerOverlays: clip.stickerOverlays,
      );
      final segPath = '${tmpDir.path}/seg_$i.mp4';
      final ok = await _renderClipSegment(clip, segPath, overlayPath);
      if (ok) segmentPaths.add(segPath);
    }
    if (segmentPaths.isEmpty) return null;

    final listPath = '${tmpDir.path}/concat.txt';
    final listFile = File(listPath);
    final buf = StringBuffer();
    for (final p in segmentPaths) {
      buf.writeln("file '$p'");
    }
    await listFile.writeAsString(buf.toString(), flush: true);

    final outPath = '${tmpDir.path}/reel_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final args = [
      '-y',
      '-f', 'concat',
      '-safe', '0',
      '-i', listPath,
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      '-crf', '23',
      '-pix_fmt', 'yuv420p',
      '-r', '$fps',
      '-movflags', '+faststart',
      outPath,
    ];
    final session = await FFmpegKit.executeWithArguments(args);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      return null;
    }
    return outPath;
  }

  Future<bool> _renderClipSegment(
    ReelClip clip,
    String outPath,
    String? overlayPath,
  ) async {
    final w = outputSize.width.toInt();
    final h = outputSize.height.toInt();
    final filters = <String>[];

    // Base scale/pad to 1080x1920 with aspect-fit
    filters.add('scale=$w:$h:force_original_aspect_ratio=decrease');
    filters.add('pad=$w:$h:(ow-iw)/2:(oh-ih)/2:color=black');

    // Color matrix via lutrgb
    final matrix = clip.colorMatrix;
    if (matrix != null && matrix.length >= 20) {
      final rExpr = _lutExpr(matrix[0], matrix[1], matrix[2], matrix[4]);
      final gExpr = _lutExpr(matrix[5], matrix[6], matrix[7], matrix[9]);
      final bExpr = _lutExpr(matrix[10], matrix[11], matrix[12], matrix[14]);
      filters.add("lutrgb=r='$rExpr':g='$gExpr':b='$bExpr'");
    }

    String? filterChain = filters.isEmpty ? null : filters.join(',');
    final args = <String>['-y'];

    if (clip.type == ReelClipType.image) {
      args.addAll(['-loop', '1']);
    }

    args.addAll(['-i', clip.path]);

    if (overlayPath != null) {
      args.addAll(['-i', overlayPath]);
    }

    if (clip.trimStart != null) {
      args.addAll(['-ss', (clip.trimStart!.inMilliseconds / 1000).toStringAsFixed(3)]);
    }
    if (clip.trimEnd != null && clip.trimEnd! > Duration.zero) {
      final durMs = clip.trimEnd!.inMilliseconds -
          (clip.trimStart?.inMilliseconds ?? 0);
      if (durMs > 0) {
        args.addAll(['-t', (durMs / 1000).toStringAsFixed(3)]);
      }
    } else if (clip.type == ReelClipType.image) {
      args.addAll(['-t', (clip.duration.inMilliseconds / 1000).toStringAsFixed(3)]);
    }

    if (overlayPath != null) {
      final chain = filterChain ?? 'null';
      final filterComplex =
          "[0:v]$chain[v0];[v0][1:v]overlay=0:0:format=auto[v]";
      args.addAll(['-filter_complex', filterComplex, '-map', '[v]']);
    } else if (filterChain != null) {
      args.addAll(['-vf', filterChain]);
    }

    args.addAll([
      '-c:v', 'libx264',
      '-preset', 'ultrafast',
      '-crf', '23',
      '-pix_fmt', 'yuv420p',
      '-r', '$fps',
      '-movflags', '+faststart',
      outPath,
    ]);

    final session = await FFmpegKit.executeWithArguments(args);
    final rc = await session.getReturnCode();
    return ReturnCode.isSuccess(rc);
  }

  String _lutExpr(double m00, double m01, double m02, double b) {
    String term(double m, String ch) {
      if (m == 0) return '';
      final sign = m >= 0 ? '+' : '';
      return '$sign${m.toStringAsFixed(6)}*$ch';
    }

    final bias = b != 0 ? (b >= 0 ? '+' : '') + b.toStringAsFixed(6) : '';
    final expr = '${term(m00, "r")}${term(m01, "g")}${term(m02, "b")}$bias';
    return "clip($expr,0,255)";
  }
}
