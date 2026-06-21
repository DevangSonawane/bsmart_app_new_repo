import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import '../models/media_model.dart';
import '../services/dummy_data_service.dart';

class CreateService {
  static final CreateService _instance = CreateService._internal();
  factory CreateService() => _instance;

  CreateService._internal();

  static const int maxVideoDurationSeconds = 60;
  static const int maxImageUploadBytes = 4 * 1024 * 1024;

  // Get available filters
  List<Filter> getFilters() {
    return [
      Filter(id: 'none', name: 'Original'),
      Filter(id: 'vintage', name: 'Vintage'),
      Filter(id: 'black_white', name: 'Black & White'),
      Filter(id: 'warm', name: 'Warm'),
      Filter(id: 'cool', name: 'Cool'),
      Filter(id: 'dramatic', name: 'Dramatic'),
      Filter(id: 'beauty', name: 'Beauty'),
      Filter(id: 'ar_effect_1', name: 'AR Effect 1'),
      Filter(id: 'ar_effect_2', name: 'AR Effect 2'),
    ];
  }

  // Get trending music tracks
  List<MusicTrack> getTrendingMusic() {
    return [
      MusicTrack(
        id: 'music-1',
        title: 'Trending Sound 1',
        artist: 'Artist Name',
        duration: const Duration(seconds: 30),
      ),
      MusicTrack(
        id: 'music-2',
        title: 'Trending Sound 2',
        artist: 'Another Artist',
        duration: const Duration(seconds: 45),
      ),
      MusicTrack(
        id: 'music-3',
        title: 'Popular Track',
        artist: 'Famous Artist',
        duration: const Duration(seconds: 60),
      ),
    ];
  }

  // Simulate AI caption suggestion
  String? suggestCaption(MediaItem media) {
    // In real app, this would use AI/ML
    return 'Check out this amazing content! #amazing #trending';
  }

  // Simulate AI hashtag suggestion
  List<String> suggestHashtags(MediaItem media) {
    // In real app, this would use AI/ML
    return ['trending', 'viral', 'amazing', 'love', 'instagood'];
  }

  // Get users for tagging
  List<String> getUsersForTagging() {
    final users = DummyDataService().getOnlineUsers();
    return users.map((user) => user.name).toList();
  }

  // Validate media
  bool validateMedia(MediaItem media) {
    if (media.type == MediaType.video && media.duration != null) {
      return media.duration!.inSeconds <= maxVideoDurationSeconds;
    }
    return true;
  }

  Future<String?> trimVideoForUpload({
    required String inputPath,
    Duration? trimStart,
    Duration? trimEnd,
    Duration? videoDuration,
  }) async {
    final baseName = inputPath.split(Platform.pathSeparator).last.toLowerCase();
    if (baseName.startsWith('edited_') ||
        baseName.startsWith('trimmed_') ||
        baseName.startsWith('bsmart_trim_') ||
        baseName.startsWith('bsmart_post_')) {
      return inputPath;
    }

    final start = trimStart ?? Duration.zero;
    final resolvedEnd = trimEnd ?? videoDuration;

    if (resolvedEnd == null) {
      return inputPath;
    }

    if (start <= Duration.zero && resolvedEnd >= (videoDuration ?? resolvedEnd)) {
      return inputPath;
    }

    final clipDuration = resolvedEnd - start;
    if (clipDuration <= Duration.zero) {
      return inputPath;
    }

    final tmpDir = await Directory.systemTemp.createTemp('bsmart_trim_');
    final outputPath =
        '${tmpDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final args = [
      '-y',
      '-i',
      inputPath,
      '-ss',
      (start.inMilliseconds / 1000.0).toStringAsFixed(3),
      '-t',
      (clipDuration.inMilliseconds / 1000.0).toStringAsFixed(3),
      '-c:v',
      'libx264',
      '-preset',
      'ultrafast',
      '-crf',
      '25',
      '-pix_fmt',
      'yuv420p',
      '-c:a',
      'aac',
      '-movflags',
      '+faststart',
      outputPath,
    ];

    final session = await FFmpegKit.executeWithArguments(args);
    final rc = await session.getReturnCode();
    if (ReturnCode.isSuccess(rc)) {
      return outputPath;
    }
    return null;
  }

  // Process AI enhancement (simulated)
  Future<MediaItem> processAIEnhancement({
    required MediaItem media,
    required String enhancementType,
  }) async {
    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));
    
    // In real app, this would process the media
    return media;
  }
}
