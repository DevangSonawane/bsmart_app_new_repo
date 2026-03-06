import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'dart:math' as math;
import '../models/ad_model.dart';
import '../models/ad_category_model.dart';
import '../services/ads_service.dart';
import '../widgets/comments_sheet.dart';

class AdsPageScreen extends StatefulWidget {
  const AdsPageScreen({super.key});

  @override
  State<AdsPageScreen> createState() => _AdsPageScreenState();
}

class _AdsPageScreenState extends State<AdsPageScreen> {
  final AdsService _adsService = AdsService();

  List<AdCategory> _categories = [];
  String _selectedCategoryId = 'All';
  List<Ad> _ads = [];
  
  bool _isLoading = true;
  String? _error;
  final PageController _pageController = PageController();
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadCategoriesAndAds();
  }

  Future<void> _loadCategoriesAndAds() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = _adsService.getCategories();
      final ads = await _adsService.fetchAds(category: _selectedCategoryId);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _ads = ads;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categories = _adsService.getCategories();
        _ads = [];
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onCategorySelected(String categoryId) async {
    if (_selectedCategoryId == categoryId) return;

    setState(() {
      _selectedCategoryId = categoryId;
      _focusedIndex = 0;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    await _loadCategoriesAndAds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Layer 1: Main Content (Video Feed)
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : _error != null
                  ? _buildErrorState()
                  : _ads.isEmpty
                  ? _buildEmptyState()
                  : PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      onPageChanged: (index) {
                        setState(() {
                          _focusedIndex = index;
                        });
                      },
                      itemCount: _ads.length,
                      itemBuilder: (context, index) {
                        return AdVideoItem(
                          ad: _ads[index],
                          isActive: index == _focusedIndex,
                          onOpenComments: () async {
                            await CommentsSheet.show(context, _ads[index].id);
                            if (!mounted) return;
                            await _loadCategoriesAndAds();
                          },
                        );
                      },
                    ),

          // Layer 2: Top Navigation Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildTopBar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          
          // Categories List
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    children: _categories.map((c) => _buildCategoryChip(c.id, c.name)).toList(),
                  ),
                ),
              ),

          // Search Button
          IconButton(
            icon: const Icon(LucideIcons.search, color: Colors.white, size: 24),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label) {
    final isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () => _onCategorySelected(id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.videoOff, color: Colors.white54, size: 64),
          const SizedBox(height: 16),
          Text(
            'No ads available in this category',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.circleAlert, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load ads',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadCategoriesAndAds,
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class AdVideoItem extends StatefulWidget {
  final Ad ad;
  final bool isActive;
  final Future<void> Function() onOpenComments;

  const AdVideoItem({
    super.key,
    required this.ad,
    required this.isActive,
    required this.onOpenComments,
  });

  @override
  State<AdVideoItem> createState() => _AdVideoItemState();
}

class _AdVideoItemState extends State<AdVideoItem> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  final AdsService _adsService = AdsService();
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isMuted = true;
  bool _isLikeLoading = false;
  int _likesCount = 0;
  
  // Animation for music disc
  late AnimationController _discController;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.ad.isLikedByMe;
    _likesCount = widget.ad.likesCount;
    _discController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    if (widget.isActive) _discController.repeat();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(AdVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.id != widget.ad.id) {
      _isLiked = widget.ad.isLikedByMe;
      _likesCount = widget.ad.likesCount;
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller?.play();
        _discController.repeat();
      } else {
        _controller?.pause();
        _discController.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _discController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final url = widget.ad.videoUrl;
    if (url != null && url.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await _controller!.initialize();
        await _controller!.setLooping(true);
        if (widget.isActive) {
          await _controller!.play();
        }
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      } catch (e) {
        debugPrint('Error initializing video: $e');
      }
    }
  }

  void _togglePlay() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _discController.stop();
      } else {
        _controller!.play();
        _discController.repeat();
      }
    });
  }

  Future<void> _toggleLike() async {
    if (_isLikeLoading || widget.ad.id.isEmpty) return;

    final previousLiked = _isLiked;
    final previousLikes = _likesCount;
    final nextLiked = !previousLiked;
    final nextLikes = nextLiked ? previousLikes + 1 : (previousLikes > 0 ? previousLikes - 1 : 0);

    setState(() {
      _isLikeLoading = true;
      _isLiked = nextLiked;
      _likesCount = nextLikes;
    });

    try {
      if (nextLiked) {
        await _adsService.likeAd(widget.ad.id);
      } else {
        await _adsService.dislikeAd(widget.ad.id);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = previousLiked;
          _likesCount = previousLikes;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLikeLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video Player
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            color: Colors.black,
            child: _isInitialized && _controller != null
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : widget.ad.imageUrl != null
                    ? Image.network(
                        widget.ad.imageUrl!,
                        fit: BoxFit.cover,
                      )
                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
        ),

        // Gradient Overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),
        ),
 
        // 2. Progress Bar (Top)
        if (_isInitialized && _controller != null)
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: false,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
              padding: EdgeInsets.zero,
            ),
          ),

        // 3. Right Side Actions
        Positioned(
          right: 8,
          bottom: 160,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGlassAction(
                icon: _isLiked ? Icons.favorite : LucideIcons.heart,
                label: _formatCount(_likesCount),
                iconColor: _isLiked ? Colors.red : Colors.white,
                fillColor: _isLiked ? Colors.red : null,
                onTap: _toggleLike,
              ),
              const SizedBox(height: 16),
              _buildGlassAction(
                icon: LucideIcons.messageCircle,
                label: _formatCount(widget.ad.commentsCount),
                onTap: () => unawaited(widget.onOpenComments()),
              ),
              const SizedBox(height: 16),
              _buildGlassAction(
                icon: LucideIcons.send,
                label: _formatCount(widget.ad.sharesCount),
                onTap: () {},
                rotate: -0.2, // ~12 degrees
              ),
              const SizedBox(height: 16),
              _buildGlassAction(
                icon: _isSaved ? LucideIcons.bookmark : LucideIcons.bookmark,
                label: 'Save',
                iconColor: _isSaved ? Colors.amber : Colors.white,
                fillColor: _isSaved ? Colors.amber : null,
                onTap: () => setState(() => _isSaved = !_isSaved),
              ),
              const SizedBox(height: 16),
              _buildGlassAction(
                icon: Icons.more_horiz,
                label: '',
                onTap: () {},
              ),
              const SizedBox(height: 24),
              // Spinning Disc
              _buildMusicDisc(),
            ],
          ),
        ),

        // 4. Mute Button (Floating)
        Positioned(
          right: 60,
          bottom: 140,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isMuted = !_isMuted;
                _controller?.setVolume(_isMuted ? 0 : 1);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),

        // 5. Bottom Info Overlay
        Positioned(
          left: 16,
          right: 80,
          bottom: 84,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // User/Company Info
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: (widget.ad.userAvatarUrl ?? widget.ad.companyLogo) != null
                          ? NetworkImage(widget.ad.userAvatarUrl ?? widget.ad.companyLogo!)
                          : null,
                      child: (widget.ad.userAvatarUrl ?? widget.ad.companyLogo) == null
                          ? Text(
                              (widget.ad.vendorBusinessName ?? widget.ad.userName ?? widget.ad.companyName)[0],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.ad.vendorBusinessName ?? widget.ad.userName ?? widget.ad.companyName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.ad.totalBudgetCoins > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              border: Border.all(color: Colors.amber.withOpacity(0.4)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.coins, color: Colors.amber, size: 10),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCount(widget.ad.totalBudgetCoins),
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            border: Border.all(color: Colors.white.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Follow',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Description
              Text(
                (widget.ad.caption ?? widget.ad.description).isNotEmpty
                    ? (widget.ad.caption ?? widget.ad.description)
                    : 'Sponsored',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 4),
              
              // Category
              if ((widget.ad.category ?? '').isNotEmpty || widget.ad.targetCategories.isNotEmpty)
                Text(
                  widget.ad.category ?? widget.ad.targetCategories.first,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Music/Audio
              Row(
                children: [
                  const Icon(LucideIcons.music2, color: Colors.white70, size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SizedBox(
                      height: 20,
                      child: MarqueeWidget(
                        text:
                            '${widget.ad.targetLocations.isEmpty ? 'Global' : widget.ad.targetLocations.join(', ')}'
                            ' · '
                            '${widget.ad.targetLanguages.isEmpty ? 'All Languages' : widget.ad.targetLanguages.join(', ')}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    Color? fillColor,
    double rotate = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.transparent), // React has border but it's subtle
            ),
            child: Transform.rotate(
              angle: rotate,
              child: Icon(
                icon,
                color: iconColor,
                size: 22,
                // fill: fillColor, // IconData doesn't support fill property directly in standard Icon widget usually, unless using specific icon set that supports it or fill property. LucideIcons are outline by default.
              ),
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(color: Colors.black45, offset: Offset(0, 1), blurRadius: 2),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMusicDisc() {
    return AnimatedBuilder(
      animation: _discController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _discController.value * 2 * math.pi,
          child: child,
        );
      },
      child: Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black87,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 8),
        ),
        child: CircleAvatar(
          backgroundImage: widget.ad.companyLogo != null
              ? NetworkImage(widget.ad.companyLogo!)
              : null,
          backgroundColor: Colors.grey[800],
        ),
      ),
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

class MarqueeWidget extends StatefulWidget {
  final String text;
  final TextStyle style;

  const MarqueeWidget({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_animationController);

    _animationController.addListener(() {
      if (_scrollController.hasClients) {
        if (_scrollController.position.maxScrollExtent > 0) {
           double maxScroll = _scrollController.position.maxScrollExtent;
           _scrollController.jumpTo(_animation.value * maxScroll);
        }
      }
    });

    // Start animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animationController.repeat();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(widget.text, style: widget.style),
          const SizedBox(width: 30),
          Text(widget.text, style: widget.style), // Duplicate for smooth loop effect (simplified)
          const SizedBox(width: 30),
          Text(widget.text, style: widget.style),
        ],
      ),
    );
  }
}
