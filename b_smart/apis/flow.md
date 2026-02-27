import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/media_model.dart';

/// The bottom-sheet that appears when the user taps "+" in the nav bar.
/// Shows Post / Reel / Story / Live options and handles the correct routing
/// for each:
///
///   Post  → picks media → pushes /create_post  (CreatePostScreen)
///   Reel  → picks video → pushes /create_reel  (CreateEditPreviewScreen)
///   Story → pushes /story-camera
///   Live  → shows "coming soon"
class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            // Prevent taps inside the sheet from dismissing it
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // ── Post
                  _CreateOption(
                    icon: Icons.grid_on_outlined,
                    label: 'Post',
                    subtitle: 'Share a photo or video',
                    onTap: () => _onPost(context),
                  ),

                  // ── Reel
                  _CreateOption(
                    icon: Icons.play_circle_outline,
                    label: 'Reel',
                    subtitle: 'Create a short video',
                    onTap: () => _onReel(context),
                  ),

                  // ── Story
                  _CreateOption(
                    icon: Icons.add_circle_outline,
                    label: 'Story',
                    subtitle: 'Share a photo or video',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed('/story-camera');
                    },
                  ),

                  // ── Live
                  _CreateOption(
                    icon: Icons.sensors_outlined,
                    label: 'Live',
                    subtitle: 'Broadcast to your followers',
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Live is coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Post: picks any media → opens CreatePostScreen (select→crop→edit→share)
  Future<void> _onPost(BuildContext context) async {
    Navigator.of(context).pop(); // close the sheet first

    // For Post we go straight to CreatePostScreen which has its own picker
    Navigator.of(context).pushNamed('/create_post');
  }

  // ── Reel: picks a video → opens CreateEditPreviewScreen
  Future<void> _onReel(BuildContext context) async {
    Navigator.of(context).pop(); // close the sheet first

    final picker = ImagePicker();
    final XFile? picked = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );

    if (picked == null) return; // user cancelled
    if (!context.mounted) return;

    final media = MediaItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filePath: picked.path,
      type: MediaType.video,
    );

    Navigator.of(context).pushNamed('/create_reel', arguments: media);
  }
}

// ── Individual option row ──────────────────────────────────────────────────
class _CreateOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}