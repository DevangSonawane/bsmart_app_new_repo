import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:preload_page_view/preload_page_view.dart';
import '../models/reel_model.dart';
import '../services/reels_service.dart';
import '../services/user_account_service.dart';
import '../models/user_account_model.dart';
import '../theme/instagram_theme.dart';
import 'reel_comments_screen.dart';
import 'reel_remix_screen.dart';
import 'boost_post_screen.dart';
import 'report_content_screen.dart';
 

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final ReelsService _reelsService = ReelsService();
  final PageController _pageController = PageController();
  
  int _currentIndex = 0;
  bool _isMuted = false;
  bool _isPlaying = true;
  Timer? _viewTimer;
  List<Reel> _reels = [];
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, bool> _isInitializing = {};
  final Map<String, bool> _hasError = {};

  @override
  void initState() {
    super.initState();
    _loadReels();
    _startViewTracking();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _viewTimer?.cancel();
    _disposeAllControllers();
    super.dispose();
  }

  void _disposeAllControllers() {
    for (final c in _controllers.values) {
      _cleanupController(c);
    }
    _controllers.clear();
    _isInitializing.clear();
  }

  void _cleanupController(VideoPlayerController? c) {
    if (c == null) return;
    try {
      c.pause();
      c.setVolume(0);
      c.dispose();
    } catch (e) {
      debugPrint('Error disposing controller: $e');
    }
  }

  void _loadReels() {
    setState(() {
      _reels = _reelsService.getReels();
    });
    if (_reels.isNotEmpty) {
      _reelsService.incrementViews(_reels[_currentIndex].id);
      _ensureControllerForIndex(_currentIndex);
      _ensureControllerForIndex(_currentIndex + 1);
    }
  }

  Future<void> _ensureControllerForIndex(int index) async {
    if (index < 0 || index >= _reels.length) return;
    final reel = _reels[index];
    final url = reel.videoUrl;
    if (url.isEmpty) return;
    
    // If already initialized or initializing, skip
    if (_controllers.containsKey(reel.id)) {
      final c = _controllers[reel.id]!;
      if (c.value.isInitialized) {
        if (index == _currentIndex && _isPlaying) c.play();
        c.setVolume(_isMuted ? 0 : 1);
      }
      return;
    }
    if (_isInitializing[reel.id] == true) return;

    // Strict limit: only allow 2 controllers (current and next)
    if (_controllers.length >= 2 && index != _currentIndex) return;

    _isInitializing[reel.id] = true;
    _hasError[reel.id] = false;

    try {
      if (!mounted) return;

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      
      _controllers[reel.id] = controller;
      
      if (index == _currentIndex) {
        await controller.initialize();
        if (mounted && _currentIndex == index) {
          controller.setLooping(true);
          controller.setVolume(_isMuted ? 0 : 1);
          if (_isPlaying) await controller.play();
        }
      } else {
        // Initialize next reel in background
        unawaited(controller.initialize().then((_) {
          if (mounted) {
            controller.setLooping(true);
            controller.setVolume(_isMuted ? 0 : 1);
            setState(() {});
          }
        }).catchError((e) {
          debugPrint('Background init error: $e');
        }));
      }
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError[reel.id] = true;
          _controllers.remove(reel.id);
        });
      }
    } finally {
      _isInitializing[reel.id] = false;
    }
  }

  void _disposeControllerForIndex(int index) {
    if (index < 0 || index >= _reels.length) return;
    final id = _reels[index].id;
    final c = _controllers.remove(id);
    if (c != null) {
      _cleanupController(c);
    }
    _isInitializing.remove(id);
    _hasError.remove(id);
  }

  void _startViewTracking() {
    _viewTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_reels.isNotEmpty && _isPlaying) {
        _reelsService.incrementViews(_reels[_currentIndex].id);
      }
    });
  }

  void _onPageChanged(int index) {
    // 1. Pause previous immediately
    final prevId = _reels[_currentIndex].id;
    if (_controllers.containsKey(prevId)) {
      _controllers[prevId]?.pause();
    }

    setState(() {
      _currentIndex = index;
      _isPlaying = true;
    });

    if (index < _reels.length) {
      _reelsService.incrementViews(_reels[index].id);
      
      // 2. Aggressive Cleanup: Keep ONLY current and next
      final List<String> keepIds = [
        _reels[index].id,
        if (index + 1 < _reels.length) _reels[index + 1].id,
      ];

      final keysToRemove = _controllers.keys.where((id) => !keepIds.contains(id)).toList();
      for (final id in keysToRemove) {
        final c = _controllers.remove(id);
        _cleanupController(c);
        _isInitializing.remove(id);
        _hasError.remove(id);
      }

      // 3. Ensure current and next
      _ensureControllerForIndex(index);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _currentIndex == index) {
          _ensureControllerForIndex(index + 1);
        }
      });
    }
  }

  void _handleSwipeUp() {
    if (_currentIndex < _reels.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleSwipeDown() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    final currentId = _reels[_currentIndex].id;
    if (_controllers.containsKey(currentId)) {
      if (_isPlaying) {
        _controllers[currentId]?.play();
      } else {
        _controllers[currentId]?.pause();
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    
    // Apply mute/unmute to all initialized controllers
    for (final controller in _controllers.values) {
      if (controller.value.isInitialized) {
        controller.setVolume(_isMuted ? 0 : 1);
      }
    }
  }

  void _handleDoubleTap() {
    _reelsService.toggleLike(_reels[_currentIndex].id);
    setState(() {});
    
    // Show like animation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❤️'),
        duration: Duration(milliseconds: 500),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  void _handleLike() {
    _reelsService.toggleLike(_reels[_currentIndex].id);
    setState(() {});
  }

  void _handleComment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReelCommentsScreen(
          reel: _reels[_currentIndex],
        ),
      ),
    );
  }

  void _handleShare() {
    final messenger = ScaffoldMessenger.of(this.context);
    _reelsService.incrementShares(_reels[_currentIndex].id);
    setState(() {});
    
    showModalBottomSheet(
      context: context,
      backgroundColor: InstagramTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(LucideIcons.link, color: InstagramTheme.textBlack),
              title: Text(
                'Copy Link',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                messenger.showSnackBar(SnackBar(
                  content: const Text('Link copied to clipboard'),
                  backgroundColor: InstagramTheme.surfaceWhite,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ));
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.send, color: InstagramTheme.textBlack),
              title: Text(
                'Share via...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                messenger.showSnackBar(SnackBar(
                  content: const Text('Share sheet opened'),
                  backgroundColor: InstagramTheme.surfaceWhite,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _handleSave() {
    _reelsService.toggleSave(_reels[_currentIndex].id);
    setState(() {});
  }

  void _handleMore() {
    final reel = _reels[_currentIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: InstagramTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reel.isSponsored)
              ListTile(
                leading: Icon(LucideIcons.info, color: InstagramTheme.textBlack),
                title: Text(
                  'View Ad Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAdDetails(reel);
                },
              ),
            if (reel.remixEnabled)
              ListTile(
                leading: Icon(LucideIcons.shuffle, color: InstagramTheme.textBlack),
                title: Text(
                  'Remix this Reel',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleRemix(reel);
                },
              ),
            if (reel.audioReuseEnabled)
              ListTile(
                leading: Icon(LucideIcons.music2, color: InstagramTheme.textBlack),
                title: Text(
                  'Use this Audio',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleUseAudio(reel);
                },
              ),
            ListTile(
              leading: Icon(LucideIcons.trendingUp, color: InstagramTheme.textBlack),
              title: Text(
                'Boost Reel',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                final accountService = UserAccountService();
                final currentAccount = accountService.getCurrentAccount();
                if (currentAccount.accountType == AccountType.regular) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Only Creator and Business accounts can boost content'),
                      backgroundColor: InstagramTheme.errorRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BoostPostScreen(
                      postId: reel.id,
                      contentType: 'reel',
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.ban, color: InstagramTheme.textBlack),
              title: Text(
                'Not Interested',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('We\'ll show you less like this'),
                    backgroundColor: InstagramTheme.surfaceWhite,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.flag, color: InstagramTheme.errorRed),
              title: Text(
                'Report',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: InstagramTheme.errorRed,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleReport(reel);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAdDetails(Reel reel) {
    final messenger = ScaffoldMessenger.of(this.context);
    showDialog(
      context: context,
      barrierColor: InstagramTheme.backgroundWhite.withValues(alpha: 0.7),
      builder: (context) => AlertDialog(
        backgroundColor: InstagramTheme.surfaceWhite,
        title: Text(
          'Ad Details - ${reel.sponsorBrand}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Brand: ${reel.sponsorBrand ?? 'N/A'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (reel.productTags != null && reel.productTags!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Products:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...reel.productTags!.map((tag) => ListTile(
                leading: Icon(LucideIcons.shoppingBag, color: InstagramTheme.primaryPink),
                title: Text(
                  tag.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: tag.price != null
                    ? Text(
                        '${tag.currency ?? '\$'}${tag.price}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  messenger.showSnackBar(SnackBar(
                    content: Text('Opening ${tag.externalUrl}'),
                    backgroundColor: InstagramTheme.surfaceWhite,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ));
                },
              )),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleRemix(Reel reel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReelRemixScreen(reel: reel),
      ),
    );
  }

  void _handleUseAudio(Reel reel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReelRemixScreen(reel: reel, useAudioOnly: true),
      ),
    );
  }

  void _handleReport(Reel reel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReportContentScreen(reelId: reel.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_reels.isEmpty) {
      return const Scaffold(
        backgroundColor: InstagramTheme.backgroundWhite,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(InstagramTheme.primaryPink),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -500) {
              _handleSwipeUp();
            } else if (details.primaryVelocity! > 500) {
              _handleSwipeDown();
            }
          }
        },
        onTap: _togglePlayPause,
        onDoubleTap: _handleDoubleTap,
        onLongPressStart: (_) {
          setState(() {
            _isPlaying = false;
          });
          
          final currentId = _reels[_currentIndex].id;
          if (_controllers.containsKey(currentId)) {
            _controllers[currentId]?.pause();
          }
        },
        onLongPressEnd: (_) {
          setState(() {
            _isPlaying = true;
          });
          
          final currentId = _reels[_currentIndex].id;
          if (_controllers.containsKey(currentId)) {
            _controllers[currentId]?.play();
          }
        },
        child: Stack(
          children: [
            // Video Player (PageView)
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              itemCount: _reels.length,
              itemBuilder: (context, index) {
                final reel = _reels[index];
                return _buildReelPlayer(reel);
              },
            ),

            // Mute Button (Top Right)
            Positioned(
              top: 40,
              right: 16,
              child: SafeArea(
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            // Right Side Actions
            Positioned(
              right: 16,
              bottom: 40,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 5),
                child: _buildRightActions(),
              ),
            ),

            // Bottom Left Metadata
            Positioned(
              left: 16,
              bottom: 40,
              right: 100,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 5),
                child: _buildBottomMetadata(),
              ),
            ),

            // Product Tags (if sponsored)
            if (_reels[_currentIndex].isSponsored &&
                _reels[_currentIndex].productTags != null &&
                _reels[_currentIndex].productTags!.isNotEmpty)
              Positioned(
                bottom: 280,
                left: 16,
                child: _buildProductTags(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelPlayer(Reel reel) {
    final controller = _controllers[reel.id];
    final isInitialized = controller != null && controller.value.isInitialized;
    final hasError = _hasError[reel.id] ?? false;

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Thumbnail Placeholder
          if (reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: reel.thumbnailUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.black,
                child: const Center(child: Icon(LucideIcons.imageOff, color: Colors.white24)),
              ),
            )
          else
            Container(color: Colors.black),

          // 2. Video Player
          if (isInitialized)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),

          // 3. Error State
          if (hasError)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white70, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not load video',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _disposeControllerForIndex(_currentIndex);
                      _ensureControllerForIndex(_currentIndex);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: InstagramTheme.primaryPink,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),

          // 4. Loading Indicator (Only if not initialized and no error)
          if (!isInitialized && !hasError)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.5)),
                    ),
                  ),
                ],
              ),
            ),

          // 5. Pause Overlay
          if (!_isPlaying && isInitialized)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Icon(LucideIcons.pause, size: 60, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRightActions() {
    final reel = _reels[_currentIndex];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: LucideIcons.heart,
          label: _formatCount(reel.likes),
          color: reel.isLiked ? InstagramTheme.errorRed : Colors.white,
          onTap: _handleLike,
        ),
        const SizedBox(height: 24),
        _buildActionButton(
          icon: LucideIcons.messageCircle,
          label: _formatCount(reel.comments),
          onTap: _handleComment,
        ),
        const SizedBox(height: 24),
        _buildActionButton(
          icon: LucideIcons.send,
          label: _formatCount(reel.shares),
          onTap: _handleShare,
        ),
        const SizedBox(height: 24),
        _buildActionButton(
          icon: LucideIcons.bookmark,
          label: 'Save',
          color: reel.isSaved ? InstagramTheme.primaryPink : Colors.white,
          onTap: _handleSave,
        ),
        const SizedBox(height: 24),
        _buildActionButton(
          icon: LucideIcons.ellipsis,
          label: 'More',
          onTap: _handleMore,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color ?? Colors.white, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomMetadata() {
    final reel = _reels[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Creator Info
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).pushNamed('/profile/${reel.userId}');
              },
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[800],
                  backgroundImage: reel.userAvatarUrl != null ? CachedNetworkImageProvider(reel.userAvatarUrl!) : null,
                  child: reel.userAvatarUrl == null
                      ? Text(
                          reel.userName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pushNamed('/profile/${reel.userId}');
              },
              child: Text(
                reel.userName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            if (!reel.isFollowing) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  _reelsService.toggleFollow(reel.userId);
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white54),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Follow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Caption
        if (reel.caption != null && reel.caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              reel.caption!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        // Audio Info
        Row(
          children: [
            const Icon(LucideIcons.music2, color: Colors.white, size: 12),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  reel.audioTitle ?? 'Original Audio - ${reel.userName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProductTags() {
    final tags = _reels[_currentIndex].productTags!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tags.map((tag) {
        return GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening external product: ${tag.externalUrl}'),
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () {
                    // Open external URL
                  },
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: InstagramTheme.cardDecoration(
              color: InstagramTheme.surfaceWhite,
              borderRadius: 12,
              hasBorder: true,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: InstagramTheme.dividerGrey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                child: tag.imageUrl != null
                      ? CachedNetworkImage(imageUrl: tag.imageUrl!, width: 40, height: 40, fit: BoxFit.cover)
                      : Icon(LucideIcons.shoppingBag, color: InstagramTheme.textBlack),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: InstagramTheme.textBlack,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tag.price != null)
                      Text(
                        '${tag.currency ?? '\$'}${tag.price}',
                        style: TextStyle(
                          color: InstagramTheme.textGrey,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const Text(
                      'Opens external site',
                      style: TextStyle(
                        color: InstagramTheme.primaryPink,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
