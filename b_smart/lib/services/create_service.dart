import '../models/media_model.dart';
import '../services/dummy_data_service.dart';

class CreateService {
  static final CreateService _instance = CreateService._internal();
  factory CreateService() => _instance;

  CreateService._internal();

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
      // Max video duration: 60 seconds
      return media.duration!.inSeconds <= 60;
    }
    return true;
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
