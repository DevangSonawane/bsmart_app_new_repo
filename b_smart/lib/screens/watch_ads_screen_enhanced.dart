import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';
import '../services/ad_service.dart';
import '../services/ad_eligibility_service.dart';
import '../models/ad_model.dart';
import '../models/notification_model.dart';
import 'ad_company_detail_screen.dart';

class WatchAdsScreenEnhanced extends StatefulWidget {
  const WatchAdsScreenEnhanced({super.key});

  @override
  State<WatchAdsScreenEnhanced> createState() => _WatchAdsScreenEnhancedState();
}

class _WatchAdsScreenEnhancedState extends State<WatchAdsScreenEnhanced>
    with WidgetsBindingObserver {
  final WalletService _walletService = WalletService();
  final NotificationService _notificationService = NotificationService();
  final AdService _adService = AdService();
  final AdEligibilityService _eligibilityService = AdEligibilityService();

  List<Ad> _availableAds = [];
  bool _isLoading = true;
  Ad? _currentAd;
  AdWatchSession? _watchSession;
  Timer? _watchTimer;
  bool _isPaused = false;
  bool _isMuted = false;
  int _pauseCount = 0;
  int _totalPauseDuration = 0;
  DateTime? _pauseStartTime;
  bool _isInForeground = true;
  final String _userId = 'user-1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAds();
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
    _isInForeground = state == AppLifecycleState.resumed;
    if (_watchSession != null && !_isInForeground) {
      // App went to background - this should disqualify reward
      _handleAdAbandoned('App moved to background');
    }
  }

  void _loadAds() {
    setState(() {
      _isLoading = true;
    });

    // Get targeted ads based on user profile
    final targetedAds = _adService.getTargetedAds(
      userLanguages: ['en'],
      userPreferences: ['technology', 'fashion'],
      userLocation: 'US',
    );

    setState(() {
      _availableAds = targetedAds;
      _isLoading = false;
    });
  }

  Future<void> _startWatchingAd(Ad ad) async {
    // Check eligibility
    final eligibility = _eligibilityService.checkEligibility(_userId, ad);
    if (!eligibility.isEligible) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eligibility.reason ?? 'Not eligible to watch this ad'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show daily capacity
    final capacity = _eligibilityService.getDailyCapacity(_userId);
    if (capacity.remainingCoins < ad.coinReward) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Daily earning cap reached. You can earn ${capacity.remainingCoins} more coins today.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _currentAd = ad;
      _watchSession = AdWatchSession(
        adId: ad.id,
        startTime: DateTime.now(),
        totalDuration: ad.watchDurationSeconds,
      );
      _isPaused = false;
      _isMuted = false;
      _pauseCount = 0;
      _totalPauseDuration = 0;
      _isInForeground = true;
    });

    _startWatchTimer();
  }

  void _startWatchTimer() {
    _watchTimer?.cancel();
    int watchedSeconds = 0;

    _watchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused || !_isInForeground) {
        return; // Don't count paused or background time
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

      // Check if ad is complete
      if (watchedSeconds >= (_currentAd?.watchDurationSeconds ?? 0)) {
        _completeAdWatch();
        timer.cancel();
      }
    });
  }

  void _togglePause() {
    if (_isPaused) {
      // Resume
      if (_pauseStartTime != null) {
        final pauseDuration = DateTime.now().difference(_pauseStartTime!).inSeconds;
        _totalPauseDuration += pauseDuration;
        _pauseStartTime = null;
      }
      setState(() {
        _isPaused = false;
      });
      _startWatchTimer();
    } else {
      // Pause
      if (_pauseCount >= AdEligibilityService.maxPauseCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum pause limit reached'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      _watchTimer?.cancel();
      setState(() {
        _isPaused = true;
        _pauseCount++;
        _pauseStartTime = DateTime.now();
      });
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_watchSession != null) {
        _watchSession = _watchSession!.copyWith(isMuted: _isMuted);
      }
    });
  }

  void _handleAdAbandoned(String reason) {
    _watchTimer?.cancel();
    setState(() {
      _currentAd = null;
      _watchSession = null;
      _isPaused = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ad watch cancelled: $reason'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<void> _completeAdWatch() async {
    if (_currentAd == null || _watchSession == null) return;

    // Validate watch completion
    final watchPercentage = _watchSession!.watchPercentage;
    if (watchPercentage < AdEligibilityService.minWatchPercentage * 100) {
      _handleAdAbandoned(
        'Minimum watch time not met (${(AdEligibilityService.minWatchPercentage * 100).toInt()}% required)',
      );
      return;
    }

    // Check pause limits
    if (_pauseCount > AdEligibilityService.maxPauseCount ||
        _totalPauseDuration > AdEligibilityService.maxTotalPauseDuration) {
      _handleAdAbandoned('Pause limits exceeded');
      return;
    }

    // Check if still in foreground
    if (!_isInForeground) {
      _handleAdAbandoned('App was in background');
      return;
    }

    // Re-validate eligibility
    final eligibility = _eligibilityService.checkEligibility(_userId, _currentAd!);
    if (!eligibility.isEligible) {
      _handleAdAbandoned(eligibility.reason ?? 'Eligibility check failed');
      return;
    }

    // Credit coins via ledger
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
      // Record in eligibility service
      _eligibilityService.recordAdWatch(_userId, _currentAd!.id, _currentAd!.coinReward);

      // Send notification
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

      // Show success
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Success!'),
            content: Text('You earned ${_currentAd!.coinReward} coins!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _currentAd = null;
                    _watchSession = null;
                    _isPaused = false;
                    _isMuted = false;
                    _pauseCount = 0;
                    _totalPauseDuration = 0;
                  });
                  _loadAds(); // Reload to update available ads
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } else {
      _handleAdAbandoned('Failed to credit coins');
    }
  }

  void _handleLike() {
    // Log engagement (doesn't affect reward)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ad liked'), duration: Duration(seconds: 1)),
    );
  }

  void _handleComment() {
    // Show comment dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comment on Ad'),
        content: const TextField(
          decoration: InputDecoration(hintText: 'Enter your comment'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Comment submitted')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _handleShare() {
    // Share ad (doesn't affect reward)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share feature coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capacity = _eligibilityService.getDailyCapacity(_userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch Ads & Earn Coins'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Text(
                '${capacity.remainingCoins} coins left today',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: _currentAd != null && _watchSession != null
          ? _buildAdPlayer()
          : _buildAdsList(capacity),
    );
  }

  Widget _buildAdsList(DailyCapacity capacity) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableAds.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Daily capacity info
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            children: [
              Text(
                'Daily Capacity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCapacityItem('Coins', capacity.remainingCoins, capacity.earnedToday),
                  _buildCapacityItem('Ads', capacity.remainingAds, capacity.adsWatchedToday),
                ],
              ),
            ],
          ),
        ),

        // Ads list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _availableAds.length,
            itemBuilder: (context, index) {
              final ad = _availableAds[index];
              final eligibility = _eligibilityService.checkEligibility(_userId, ad);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.ads_click, color: Colors.blue),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ad.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ad.companyName,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.coins, size: 16, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '+${ad.coinReward}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(ad.description),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${ad.watchDurationSeconds}s',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                          const Spacer(),
                          if (!eligibility.isEligible)
                            Text(
                              eligibility.reason ?? 'Not eligible',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: eligibility.isEligible
                              ? () => _startWatchingAd(ad)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(eligibility.isEligible ? 'Watch & Earn ${ad.coinReward} Coins' : 'Not Available'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCapacityItem(String label, int remaining, int used) {
    return Column(
      children: [
        Text(
          '$remaining',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        Text(
          '$label remaining',
          style: TextStyle(color: Colors.blue[700], fontSize: 12),
        ),
        Text(
          '($used used today)',
          style: TextStyle(color: Colors.blue[600], fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildAdPlayer() {
    if (_currentAd == null || _watchSession == null) return const SizedBox();

    final progress = _watchSession!.watchPercentage / 100;

    return Column(
      children: [
        // Ad player area
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Placeholder for video
                const Icon(Icons.play_circle_outline, size: 100, color: Colors.white54),
                // Progress bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    minHeight: 4,
                  ),
                ),
                // Watch percentage
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_watchSession!.watchedDuration}s / ${_currentAd!.watchDurationSeconds}s',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Controls
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[900],
          child: Column(
            children: [
              // Ad info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentAd!.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AdCompanyDetailScreen(
                                  companyId: _currentAd!.companyId,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            'View ${_currentAd!.companyName}',
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.grey),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                    color: Colors.white,
                    onPressed: _toggleMute,
                    tooltip: _isMuted ? 'Unmute' : 'Mute',
                  ),
                  IconButton(
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                    color: Colors.white,
                    onPressed: _togglePause,
                    tooltip: _isPaused ? 'Resume' : 'Pause',
                  ),
                  IconButton(
                    icon: const Icon(Icons.favorite_border),
                    color: Colors.white,
                    onPressed: _handleLike,
                    tooltip: 'Like',
                  ),
                  IconButton(
                    icon: const Icon(Icons.comment_outlined),
                    color: Colors.white,
                    onPressed: _handleComment,
                    tooltip: 'Comment',
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    color: Colors.white,
                    onPressed: _handleShare,
                    tooltip: 'Share',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    onPressed: () => _handleAdAbandoned('User cancelled'),
                    tooltip: 'Cancel',
                  ),
                ],
              ),
              if (_pauseCount > 0 || _totalPauseDuration > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Pauses: $_pauseCount | Total pause time: ${_totalPauseDuration}s',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ads_click, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Ads Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for more ads',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
