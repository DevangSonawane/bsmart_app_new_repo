import 'package:flutter/material.dart';
import '../models/reel_model.dart';
import '../theme/instagram_theme.dart';
import 'create_screen.dart';

class ReelRemixScreen extends StatelessWidget {
  final Reel reel;
  final bool useAudioOnly;

  const ReelRemixScreen({
    super.key,
    required this.reel,
    this.useAudioOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(useAudioOnly ? 'Use This Audio' : 'Remix Reel'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Original Reel Preview
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_library, size: 60, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Original Reel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (useAudioOnly) ...[
              // Audio Info
              Card(
                child: ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(reel.audioTitle ?? 'Unknown Audio'),
                  subtitle: Text(reel.audioArtist ?? 'Unknown Artist'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Record your video or upload images using this audio',
                style: TextStyle(fontSize: 16),
              ),
            ] else ...[
              // Remix Modes
              const Text(
                'Choose Remix Mode:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildRemixModeCard(
                context,
                title: 'Side-by-Side',
                description: 'Your video appears next to the original',
                icon: Icons.view_column,
              ),
              const SizedBox(height: 12),
              _buildRemixModeCard(
                context,
                title: 'Picture-in-Picture',
                description: 'Your video overlays the original',
                icon: Icons.picture_in_picture,
              ),
              const SizedBox(height: 12),
              _buildRemixModeCard(
                context,
                title: 'After Original',
                description: 'Your video plays after the original ends',
                icon: Icons.queue_play_next,
              ),
            ],

            const SizedBox(height: 24),

            // Attribution
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      useAudioOnly
                          ? 'Audio credit: ${reel.audioTitle} by ${reel.audioArtist}'
                          : 'Remixed from @${reel.userName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Start Creating Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const CreateScreen(),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        useAudioOnly
                            ? 'Audio selected! Start creating your reel'
                            : 'Remix mode selected! Start creating',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                ),
                child: const Text(
                  'Start Creating',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemixModeCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const CreateScreen(),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title mode selected')),
          );
        },
      ),
    );
  }
}
