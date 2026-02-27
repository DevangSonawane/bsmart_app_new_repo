import 'package:flutter/material.dart';
import '../theme/instagram_theme.dart';
import '../widgets/clay_container.dart';
import 'story_camera_screen.dart';
import 'create_upload_screen.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  int _selectedTab = 0; // 0 = Create New, 1 = Upload
  final PageController _tabController = PageController();

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedTab = index;
    });
    _tabController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InstagramTheme.backgroundWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Tabs
            _buildHeader(),
            
            // Tab Content
            Expanded(
              child: PageView(
                controller: _tabController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedTab = index;
                  });
                },
                children: const [
                  StoryCameraScreen(),
                  CreateUploadScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // Cancel Button
          TextButton(
            onPressed: () => _showDiscardDialog(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: InstagramTheme.textBlack,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Center(
              // Tab Selector
              child: ClayContainer(
                borderRadius: 20,
                color: InstagramTheme.surfaceWhite,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTabButton('Create New', 0),
                      _buildTabButton('Upload', 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Placeholder for symmetry
          const SizedBox(width: 60),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: isSelected
            ? InstagramTheme.gradientDecoration(
                borderRadius: 16,
              )
            : null,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? InstagramTheme.backgroundWhite : InstagramTheme.textGrey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      barrierColor: InstagramTheme.backgroundWhite.withValues(alpha: 0.7),
      builder: (context) => AlertDialog(
        backgroundColor: InstagramTheme.surfaceWhite,
        title: Text(
          'Discard Changes?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Are you sure you want to discard your changes?',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // If pushed, pop. If this is the main screen, maybe switch tab?
              // For now, assume it's part of navigation or modal.
              // If it's a tab in HomeDashboard, we can't 'pop' easily without context.
              // But 'Cancel' usually implies closing the creation mode.
              // Since this is likely a tab, maybe just reset state?
              // Or if it was opened as a full screen modal.
              // Let's assume modal for now or just close dialog.
            },
            style: TextButton.styleFrom(foregroundColor: InstagramTheme.errorRed),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}
