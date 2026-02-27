import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import '../utils/current_user.dart';
import '../models/ad_model.dart';
import '../models/ad_category_model.dart';
import '../services/ad_category_service.dart';
import '../services/ad_eligibility_service.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';
import '../models/notification_model.dart';
import 'ad_company_detail_screen.dart';
import '../theme/instagram_theme.dart';
import '../widgets/clay_container.dart';

class AdsPageScreen extends StatefulWidget {
  const AdsPageScreen({super.key});

  @override
  State<AdsPageScreen> createState() => _AdsPageScreenState();
}

class _AdsPageScreenState extends State<AdsPageScreen>
    with WidgetsBindingObserver {
  final AdCategoryService _categoryService = AdCategoryService();
  final AdEligibilityService _eligibilityService = AdEligibilityService();
  final WalletService _walletService = WalletService();
  final NotificationService _notificationService = NotificationService();
  String _userId = 'user-1';

  List<AdCategory> _categories = [];
  String _selectedCategoryId = 'all';
  List<Ad> _ads = [];
  Ad? _currentAd;
  AdWatchSession? _watchSession;
  Timer? _watchTimer;
  
  bool _isLoading = true;
  bool _isPaused = false;
  bool _isMuted = false;
  int _pauseCount = 0;
  int _totalPauseDuration = 0;
  DateTime? _pauseStartTime;
  bool _isInForeground = true;
  int _views = 0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final uid = await CurrentUser.id;
    if (mounted && uid != null) {
      setState(() => _userId = uid);
    }
    _loadCategoriesAndAds();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final wasInForeground = _isInForeground;
    _isInForeground = state == AppLifecycleState.resumed;
    if (!_isInForeground && _watchSession != null) {
      _pauseAd();
    } else if (_isInForeground && !wasInForeground && _watchSession != null && _isPaused) {
      _resumeAd();
    }
  }

  void _loadCategoriesAndAds() {
    setState(() {
      _isLoading = true;
    });

    _categories = _categoryService.getCategories();
    _ads = _categoryService.getAdsByCategory(
      categoryId: _selectedCategoryId,
      userLanguages: ['en'],
      userPreferences: ['technology', 'fashion'],
      userLocation: 'US',
    );

    if (_ads.isNotEmpty) {
      _currentAd = _ads[0];
      _loadAdDetails();
      _startWatchingAd();
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _loadAdDetails() {
    if (_currentAd == null) return;
    
    // Load ad engagement data (dummy)
    setState(() {
      _views = _currentAd!.currentViews + 100;
      _isLiked = false;
    });
  }

  void _onCategorySelected(String categoryId) {
    if (_selectedCategoryId == categoryId) return;

    _watchTimer?.cancel();
    setState(() {
      _selectedCategoryId = categoryId;
      _isPaused = false;
      _pauseCount = 0;
      _totalPauseDuration = 0;
    });

    _loadCategoriesAndAds();
  }

  void _startWatchingAd() {
    if (_currentAd == null) return;

    final eligibility = _eligibilityService.checkEligibility(_userId, _currentAd!);
    if (!eligibility.isEligible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eligibility.reason ?? 'Not eligible'),
          backgroundColor: InstagramTheme.surfaceWhite,
        ),
      );
      return;
    }

    setState(() {
      _watchSession = AdWatchSession(
        adId: _currentAd!.id,
        startTime: DateTime.now(),
        totalDuration: _currentAd!.watchDurationSeconds,
      );
      _isPaused = false;
      _isInForeground = true;
    });

    _startWatchTimer();
  }

  void _startWatchTimer() {
    _watchTimer?.cancel();
    int watchedSeconds = 0;

    _watchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused || !_isInForeground) {
        return;
      }

      watchedSeconds++;
      final percentage = (watchedSeconds / (_currentAd?.watchDurationSeconds ?? 1)) * 100;

      setState(() {
        if (_watchSession != null) {
          _watchSession = _watchSession!.copyWith(
            watchedDuration: watchedSeconds,
            watchPercentage: percentage,
            isMuted: _isMuted,
            pauseCount: _pauseCount,
            totalPauseDuration: _totalPauseDuration,
            isInForeground: _isInForeground,
          );
        }
      });

      if (watchedSeconds >= (_currentAd?.watchDurationSeconds ?? 0)) {
        _completeAdWatch();
        timer.cancel();
      }
    });
  }

  void _pauseAd() {
    if (_isPaused) return;
    
    if (_pauseCount >= AdEligibilityService.maxPauseCount) {
      return;
    }

    _watchTimer?.cancel();
    setState(() {
      _isPaused = true;
      _pauseCount++;
      _pauseStartTime = DateTime.now();
    });
  }

  void _resumeAd() {
    if (!_isPaused) return;

    if (_pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!).inSeconds;
      _totalPauseDuration += pauseDuration;
      _pauseStartTime = null;
    }

    setState(() {
      _isPaused = false;
    });
    _startWatchTimer();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
    });
  }

  void _handleComment() {
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
            Text(
              'Comments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              style: const TextStyle(color: InstagramTheme.textBlack),
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(color: InstagramTheme.textGrey),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ClayButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Comment added'),
                      backgroundColor: InstagramTheme.surfaceWhite,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                child: const Text('Post Comment'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _handleShare() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon')),
    );
  }

  Future<void> _completeAdWatch() async {
    if (_currentAd == null || _watchSession == null) return;

    final watchPercentage = _watchSession!.watchPercentage;
    if (watchPercentage < AdEligibilityService.minWatchPercentage * 100) {
      return;
    }

    if (_pauseCount > AdEligibilityService.maxPauseCount ||
        _totalPauseDuration > AdEligibilityService.maxTotalPauseDuration) {
      return;
    }

    if (!_isInForeground) {
      return;
    }

    final eligibility = _eligibilityService.checkEligibility(_userId, _currentAd!);
    if (!eligibility.isEligible) {
      return;
    }

    final success = await _walletService.addCoinsViaLedger(
      amount: _currentAd!.coinReward,
      description: 'Watched Ad: ${_currentAd!.title}',
      adId: _currentAd!.id,
      metadata: {
        'watchPercentage': watchPercentage,
        'watchDuration': _watchSession!.watchedDuration,
        'pauseCount': _pauseCount,
      },
    );

    if (success) {
      _eligibilityService.recordAdWatch(_userId, _currentAd!.id, _currentAd!.coinReward);

      _notificationService.addNotification(
        NotificationItem(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
          type: NotificationType.activity,
          title: 'Coins Earned',
          message: 'You earned ${_currentAd!.coinReward} coins by watching an ad',
          timestamp: DateTime.now(),
          isRead: false,
        ),
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          barrierColor: InstagramTheme.backgroundWhite.withValues(alpha: 0.7),
          builder: (context) => AlertDialog(
            backgroundColor: InstagramTheme.surfaceWhite,
            title: Text(
              'Success!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            content: Text(
              'You earned ${_currentAd!.coinReward} coins!',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _loadNextAd();
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _loadNextAd() {
    final nextAd = _categoryService.getNextEligibleAd(
      currentAdId: _currentAd?.id ?? '',
      categoryId: _selectedCategoryId,
      userLanguages: ['en'],
      userPreferences: ['technology', 'fashion'],
      userLocation: 'US',
    );

    if (nextAd != null) {
      _watchTimer?.cancel();
      setState(() {
        _currentAd = nextAd;
        _isPaused = false;
        _pauseCount = 0;
        _totalPauseDuration = 0;
        _isLiked = false;
      });
      _loadAdDetails();
      _startWatchingAd();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No more ads available')),
      );
    }
  }

  void _loadPreviousAd() {
    final previousAd = _categoryService.getPreviousAd(
      currentAdId: _currentAd?.id ?? '',
      categoryId: _selectedCategoryId,
      userLanguages: ['en'],
      userPreferences: ['technology', 'fashion'],
      userLocation: 'US',
    );

    if (previousAd != null) {
      _watchTimer?.cancel();
      setState(() {
        _currentAd = previousAd;
        _isPaused = false;
        _pauseCount = 0;
        _totalPauseDuration = 0;
        _isLiked = false;
      });
      _loadAdDetails();
      _startWatchingAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InstagramTheme.backgroundWhite,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(InstagramTheme.primaryPink),
              ),
            )
          : _currentAd == null
              ? _buildEmptyState()
              : GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! < -500) {
                        // Swipe up
                        _loadNextAd();
                      } else if (details.primaryVelocity! > 500) {
                        // Swipe down
                        _loadPreviousAd();
                      }
                    }
                  },
                  onHorizontalDragEnd: (details) {
                    // Horizontal swipe for tab navigation
                    // This will be handled by the parent HomeDashboard
                    // For now, we'll just pause the ad
                    if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 500) {
                      _pauseAd();
                    }
                  },
                  child: Column(
                    children: [
                      // Video Player Section
                      Expanded(
                        flex: 7,
                        child: Stack(
                          children: [
                            _buildVideoPlayer(),
                            _buildRightOverlay(),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: SafeArea(
                                bottom: false,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        InstagramTheme.backgroundWhite,
                                        InstagramTheme.backgroundWhite.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: _buildCategoryHeader(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Information Section
                      Flexible(
                        flex: 4,
                        child: _buildInformationSection(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildCategoryHeader() {
    return Container(
      height: 56,
      color: InstagramTheme.backgroundWhite,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategoryId == category.id;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _onCategorySelected(category.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? InstagramTheme.primaryPink : InstagramTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? InstagramTheme.primaryPink : InstagramTheme.borderGrey,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      color: isSelected ? InstagramTheme.backgroundWhite : InstagramTheme.textBlack,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_currentAd == null) return const SizedBox();

    final progress = ((_watchSession?.watchPercentage ?? 0.0) / 100).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      color: InstagramTheme.backgroundGrey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Ad Image/Video Display
          if (_currentAd!.imageUrl != null)
            Image.network(
              _currentAd!.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            )
          else if (_currentAd!.videoUrl != null)
            Container(
              color: InstagramTheme.backgroundGrey,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_filled,
                      size: 80,
                      color: InstagramTheme.primaryPink.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _currentAd!.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: InstagramTheme.textBlack,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            )
          else
            _buildPlaceholder(),
          
          // Progress bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: InstagramTheme.surfaceWhite.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(InstagramTheme.primaryPink),
              minHeight: 4,
            ),
          ),

          // Play/Pause overlay
          if (_isPaused)
            Container(
              color: InstagramTheme.backgroundWhite.withValues(alpha: 0.7),
              child: Center(
                child: Icon(
                  Icons.play_arrow,
                  size: 60,
                  color: InstagramTheme.primaryPink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: InstagramTheme.backgroundGrey,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.ads_click,
              size: 80,
              color: InstagramTheme.textGrey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            if (_currentAd != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _currentAd!.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: InstagramTheme.textBlack,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightOverlay() {
    return Positioned(
      right: 12,
      bottom: 100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Views Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: InstagramTheme.surfaceWhite.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: InstagramTheme.textBlack.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility, color: InstagramTheme.textBlack, size: 18),
                const SizedBox(height: 4),
                Text(
                  _formatViews(_views),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: InstagramTheme.textBlack,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Like Button
          _buildActionButton(
            icon: _isLiked ? Icons.favorite : Icons.favorite_border,
            color: _isLiked ? InstagramTheme.errorRed : InstagramTheme.textBlack,
            onPressed: _toggleLike,
          ),
          const SizedBox(height: 8),

          // Comment Button
          _buildActionButton(
            icon: Icons.comment_outlined,
            color: InstagramTheme.textBlack,
            onPressed: _handleComment,
          ),
          const SizedBox(height: 8),

          // Share Button
          _buildActionButton(
            icon: Icons.share_outlined,
            color: InstagramTheme.textBlack,
            onPressed: _handleShare,
          ),
          const SizedBox(height: 8),

          // Mute/Unmute Button
          _buildActionButton(
            icon: _isMuted ? Icons.volume_off : Icons.volume_up,
            color: InstagramTheme.textBlack,
            onPressed: _toggleMute,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: InstagramTheme.surfaceWhite.withValues(alpha: 0.95),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: InstagramTheme.textBlack.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color, size: 24),
        onPressed: onPressed,
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(),
      ),
    );
  }

  String _formatViews(int views) {
    if (views >= 1000000) {
      return '${(views / 1000000).toStringAsFixed(1)}M';
    } else if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K';
    }
    return views.toString();
  }

  Widget _buildInformationSection() {
    if (_currentAd == null) return const SizedBox();

    return Container(
      color: InstagramTheme.backgroundGrey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: InstagramTheme.cardDecoration(
                borderRadius: 16,
                hasBorder: true,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company Header
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => AdCompanyDetailScreen(
                              companyId: _currentAd!.companyId,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: InstagramTheme.backgroundGrey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: _currentAd!.companyLogo != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _currentAd!.companyLogo!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.business, color: InstagramTheme.primaryPink),
                                    ),
                                  )
                                : const Icon(Icons.business, color: InstagramTheme.primaryPink, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _currentAd!.companyName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: InstagramTheme.textBlack,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_currentAd!.isVerified) ...[
                                      const SizedBox(width: 6),
                                      const Icon(Icons.verified, size: 18, color: InstagramTheme.primaryPink),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to view company details',
                                  style: TextStyle(
                                    color: InstagramTheme.textGrey.withValues(alpha: 0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Coins and Timer Row
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(LucideIcons.coins, color: InstagramTheme.primaryPink, size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Earn ${_currentAd!.coinReward} coins',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: InstagramTheme.textBlack,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: InstagramTheme.backgroundGrey,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_watchSession?.watchedDuration ?? 0}s / ${_currentAd!.watchDurationSeconds}s',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: InstagramTheme.textBlack,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ((_watchSession?.watchPercentage ?? 0.0) / 100).clamp(0.0, 1.0),
                        backgroundColor: InstagramTheme.dividerGrey,
                        valueColor: const AlwaysStoppedAnimation<Color>(InstagramTheme.primaryPink),
                        minHeight: 6,
                      ),
                    ),
                    
                    // Description
                    if (_currentAd!.description.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _currentAd!.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: InstagramTheme.textBlack,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    // Categories
                    if (_currentAd!.targetCategories.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _currentAd!.targetCategories.take(6).map((cat) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: InstagramTheme.backgroundGrey,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: InstagramTheme.borderGrey,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              cat,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: InstagramTheme.textBlack,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.ads_click,
            size: 80,
            color: InstagramTheme.textGrey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No Ads Available',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Check back later for more ads',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
