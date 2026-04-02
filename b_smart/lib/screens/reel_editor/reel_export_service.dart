import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../../features/reel_timeline/reel_timeline_models.dart';
import '../../features/reel_timeline/reel_timeline_renderer.dart';
import 'reel_caption_screen.dart';

class ReelExportService {
  Future<String?> export({
    required List<ReelClip> clips,
    required String? audioPath,
    required double audioVolume,
    required String? voicePath,
    required double voiceVolume,
    required double originalVolume,
    List<ReelCaption> captions = const [],
    Size outputSize = const Size(1080, 1920),
  }) async {
    final renderer = ReelTimelineRenderer(outputSize: outputSize);
    final videoPath = await renderer.renderTimeline(clips);
    if (videoPath == null) return null;

    String currentPath = videoPath;

    if (captions.isNotEmpty) {
      final srt = _buildSrt(captions);
      final srtPath =
          '${Directory.systemTemp.path}/reel_caps_${DateTime.now().millisecondsSinceEpoch}.srt';
      await File(srtPath).writeAsString(srt, flush: true);
      final capOut =
          '${Directory.systemTemp.path}/reel_caps_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final capArgs = [
        '-y',
        '-i', currentPath,
        '-vf', "subtitles=$srtPath",
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        '-crf', '23',
        '-pix_fmt', 'yuv420p',
        '-c:a', 'copy',
        capOut,
      ];
      final capSession = await FFmpegKit.executeWithArguments(capArgs);
      final capRc = await capSession.getReturnCode();
      if (!ReturnCode.isSuccess(capRc)) return null;
      currentPath = capOut;
    }

    if (audioPath == null && voicePath == null) return currentPath;

    final outPath =
        '${Directory.systemTemp.path}/reel_audio_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final args = <String>[
      '-y',
      '-i', currentPath,
    ];
    if (audioPath != null) {
      args.addAll(['-i', audioPath]);
    }
    if (voicePath != null) {
      args.addAll(['-i', voicePath]);
    }

    final filterParts = <String>[];
    filterParts.add('[0:a]volume=${originalVolume.toStringAsFixed(3)}[a0]');
    int inputIndex = 1;
    if (audioPath != null) {
      filterParts.add(
          '[$inputIndex:a]volume=${audioVolume.toStringAsFixed(3)}[a1]');
      inputIndex += 1;
    }
    if (voicePath != null) {
      filterParts.add(
          '[$inputIndex:a]volume=${voiceVolume.toStringAsFixed(3)}[a2]');
    }

    final amixInputs = <String>['[a0]'];
    if (audioPath != null) amixInputs.add('[a1]');
    if (voicePath != null) amixInputs.add('[a2]');
    filterParts.add('${amixInputs.join()}amix=inputs=${amixInputs.length}[aout]');

    args.addAll([
      '-filter_complex',
      filterParts.join(';'),
      '-map', '0:v',
      '-map', '[aout]',
      '-c:v', 'copy',
      '-c:a', 'aac',
      '-movflags', '+faststart',
      outPath,
    ]);

    final session = await FFmpegKit.executeWithArguments(args);
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) return null;
    return outPath;
  }

  String _buildSrt(List<ReelCaption> captions) {
    String fmt(int ms) {
      final d = Duration(milliseconds: ms);
      final h = d.inHours.toString().padLeft(2, '0');
      final m = (d.inMinutes % 60).toString().padLeft(2, '0');
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      final msPart = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
      return '$h:$m:$s,$msPart';
    }

    final buf = StringBuffer();
    for (int i = 0; i < captions.length; i++) {
      final c = captions[i];
      buf.writeln('${i + 1}');
      buf.writeln('${fmt(c.startMs.toInt())} --> ${fmt(c.endMs.toInt())}');
      buf.writeln(c.text);
      buf.writeln();
    }
    return buf.toString();
  }
}
