import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/media_model.dart';
import '../services/create_service.dart';
import 'create_edit_preview_screen.dart';

class CreateCameraScreen extends StatefulWidget {
  const CreateCameraScreen({super.key});

  @override
  State<CreateCameraScreen> createState() => _CreateCameraScreenState();
}

class _CreateCameraScreenState extends State<CreateCameraScreen> {
  final CreateService _createService = CreateService();
  final ImagePicker _picker = ImagePicker();
  bool _isFrontCamera = false;
  bool _isFlashOn = false;
  bool _isRecording = false;
  String? _selectedFilter;
  List<Filter> _filters = [];
  bool _showFilters = false;
  bool _showAIPanel = false;
  bool _showMusicPanel = false;

  @override
  void initState() {
    super.initState();
    _filters = _createService.getFilters();
    _selectedFilter = _filters.first.id;
  }

  void _toggleCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: _isFrontCamera ? CameraDevice.front : CameraDevice.rear,
      );
      
      if (file != null) {
        final media = MediaItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MediaType.image,
          filePath: file.path,
          createdAt: DateTime.now(),
        );

        _navigateToEdit(media);
      }
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    }
  }
  
  Future<void> _captureVideo() async {
     try {
      final XFile? file = await _picker.pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: _isFrontCamera ? CameraDevice.front : CameraDevice.rear,
        maxDuration: const Duration(seconds: 60),
      );
      
      if (file != null) {
        // Get video duration if possible (ImagePicker doesn't provide it directly, 
        // but CreateService.validateMedia checks it. 
        // For now we assume it's valid or rely on server/later checks)
        
        final media = MediaItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MediaType.video,
          filePath: file.path,
          createdAt: DateTime.now(),
        );

        _navigateToEdit(media);
      }
    } catch (e) {
      debugPrint('Error capturing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing video: $e')),
        );
      }
    }
  }

  void _startRecording() {
    // Legacy UI state
    setState(() {
      _isRecording = true;
    });
  }

  void _stopRecording() {
    // Legacy UI state
    setState(() {
      _isRecording = false;
    });
  }

  void _navigateToEdit(MediaItem media) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateEditPreviewScreen(
          media: media,
          selectedFilter: _selectedFilter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
          Navigator.of(context).pop();
        }
      },
      child: Stack(
        children: [
          // Camera Preview (Placeholder)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[900],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                    size: 80,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRecording ? 'Recording...' : 'Camera Preview',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),

          // Top Controls
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Camera Switch
                IconButton(
                  icon: Icon(
                    _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _toggleCamera,
                ),
                // Flash
                IconButton(
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _toggleFlash,
                ),
                // AI Features
                IconButton(
                  icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                  onPressed: () {
                    setState(() {
                      _showAIPanel = !_showAIPanel;
                      _showMusicPanel = false;
                      _showFilters = false;
                    });
                  },
                ),
                // Music
                IconButton(
                  icon: const Icon(Icons.music_note, color: Colors.white, size: 28),
                  onPressed: () {
                    setState(() {
                      _showMusicPanel = !_showMusicPanel;
                      _showAIPanel = false;
                      _showFilters = false;
                    });
                  },
                ),
              ],
            ),
          ),

          // AI Panel
          if (_showAIPanel) _buildAIPanel(),

          // Music Panel
          if (_showMusicPanel) _buildMusicPanel(),

          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Filters Strip
                if (_showFilters) _buildFiltersStrip(),

                // Capture Controls
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Gallery
                      IconButton(
                        icon: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.image, color: Colors.white),
                        ),
                        onPressed: () async {
                           try {
                             final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
                             if (file != null) {
                               final media = MediaItem(
                                 id: DateTime.now().millisecondsSinceEpoch.toString(),
                                 type: MediaType.image,
                                 filePath: file.path,
                                 createdAt: DateTime.now(),
                               );
                               if (!mounted) return;
                               _navigateToEdit(media);
                             }
                           } catch (e) {
                             if (!mounted) return;
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Error picking file: $e')),
                             );
                           }
                        },
                      ),

                      // Capture Button
                      GestureDetector(
                        onTap: _capturePhoto,
                        onLongPress: _captureVideo,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.grey, width: 4),
                          ),
                          child: _isRecording
                              ? Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red,
                                  ),
                                )
                              : null,
                        ),
                      ),

                      // Filters Toggle
                      IconButton(
                        icon: Icon(
                          _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () {
                          setState(() {
                            _showFilters = !_showFilters;
                            _showAIPanel = false;
                            _showMusicPanel = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersStrip() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter.id;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedFilter = filter.id;
              });
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[800],
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        filter.name[0],
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    filter.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAIPanel() {
    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'AI Features',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildAIFeatureButton('Background Removal', Icons.auto_fix_high),
                _buildAIFeatureButton('Face Enhancement', Icons.face),
                _buildAIFeatureButton('Auto Crop', Icons.crop),
                _buildAIFeatureButton('Object Detection', Icons.search),
                _buildAIFeatureButton('Caption Suggestion', Icons.text_fields),
                _buildAIFeatureButton('Video Stabilize', Icons.video_stable),
                _buildAIFeatureButton('Highlight Reel', Icons.movie),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIFeatureButton(String label, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label feature coming soon')),
        );
      },
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildMusicPanel() {
    final musicTracks = _createService.getTrendingMusic();

    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      bottom: 200,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Music / Sound',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: musicTracks.length + 2, // +2 for "Extract Audio" and "Record Audio"
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.audiotrack, color: Colors.white),
                      title: const Text('Extract Audio from Video', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Extract audio feature coming soon')),
                        );
                      },
                    );
                  }
                  if (index == 1) {
                    return ListTile(
                      leading: const Icon(Icons.mic, color: Colors.white),
                      title: const Text('Record Your Own Audio', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Record audio feature coming soon')),
                        );
                      },
                    );
                  }
                  final track = musicTracks[index - 2];
                  return ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white),
                    ),
                    title: Text(track.title, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      '${track.artist} • ${track.duration.inSeconds}s',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    trailing: const Icon(Icons.play_arrow, color: Colors.white),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selected: ${track.title}')),
                      );
                      setState(() {
                        _showMusicPanel = false;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
