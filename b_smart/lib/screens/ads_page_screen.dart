import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/ads_api.dart';
import '../api/api_exceptions.dart';
import '../models/ad_model.dart';
import '../models/ad_category_model.dart';
import '../services/ads_service.dart';
import '../services/supabase_service.dart';
import '../state/feed_actions.dart';
import '../state/store.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import 'ad_company_detail_screen.dart';

String? _adProfileId(Ad ad) {
  final userId = ad.userId?.trim();
  if (userId != null && userId.isNotEmpty) return userId;
  final companyId = ad.companyId.trim();
  if (companyId.isNotEmpty) return companyId;
  return null;
}

class AdsPageScreen extends StatefulWidget {
  final bool isTabActive;
  const AdsPageScreen({super.key, this.isTabActive = true});

  @override
  State<AdsPageScreen> createState() => _AdsPageScreenState();
}

class _AdsPageScreenState extends State<AdsPageScreen> {
  final AdsService _adsService = AdsService();
  static final Set<String> _sessionViewedAdIds = <String>{};
  static const String _viewedAdIdsPrefsKey = 'ads_viewed_ad_ids_v1';
  static const int _maxRememberedViewedAds = 600;
  static final Set<String> _persistViewedAdIds = <String>{};
  static final List<String> _persistViewedAdIdsOrder = <String>[];
  static bool _persistViewedLoaded = false;
  static Future<void>? _persistViewedLoadFuture;
  Map<String, String>? _mediaHeaders;
  final ValueNotifier<bool> _viewPopupVisible = ValueNotifier<bool>(false);

  List<AdCategory> _categories = [];
  String _selectedCategoryId = 'All';
  String _searchQuery = '';
  String _searchInput = '';
  bool _searchOpen = false;
  bool _searchLoading = false;
  bool _searchDropdownVisible = false;
  List<_SearchUser> _searchUsers = [];
  List<Ad> _searchAds = [];
  _ViewRewardPopupData? _viewRewardPopup;
  _ViewRecordedPopupData? _viewRecordedPopup;
  Timer? _searchDebounce;
  int _searchEpoch = 0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'ads-search-focus');
  List<Ad> _ads = [];
  bool _categoriesExpanded = false;

  List<AdCategory> _ensureAllFirst(List<AdCategory> categories) {
    final allIndex = categories.indexWhere((c) {
      final id = c.id.trim().toLowerCase();
      final name = c.name.trim().toLowerCase();
      return id == 'all' ||
          name == 'all' ||
          (id.startsWith('all') && id.length <= 4) ||
          (name.startsWith('all') && name.length <= 4);
    });
    if (allIndex <= 0) return categories;

    final reordered = List<AdCategory>.from(categories);
    final allCategory = reordered.removeAt(allIndex);
    reordered.insert(0, allCategory);
    return reordered;
  }

  // Pagination state
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 10;

  bool _isLoading = true;
  String? _error;
  final PageController _pageController = PageController();
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'ads-feed-focus');
  int _focusedIndex = 0;
  double _cachedBottomInset = 0;

  @override
  void initState() {
    super.initState();
    // Cache the bottom inset from the window directly at init time.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final view = View.of(context);
      final inset = view.padding.bottom / view.devicePixelRatio;
      if (inset > 0 && inset != _cachedBottomInset) {
        setState(() {
          _cachedBottomInset = inset;
        });
      }
    });
    _init();
    _loadMediaHeaders();
    unawaited(_ensurePersistViewedLoaded());
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _pageController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _viewPopupVisible.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadCategoriesAndAds();
  }

  Future<void> _loadMediaHeaders() async {
    if (_mediaHeaders != null) return;
    final token = await ApiClient().getToken();
    if (!mounted) return;
    if (token != null && token.isNotEmpty) {
      setState(() {
        _mediaHeaders = {'Authorization': 'Bearer $token'};
      });
    }
  }

  Future<void> _loadCategoriesAndAds() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final categories = await _adsService.fetchCategories();
      final orderedCategories = _ensureAllFirst(categories);
      final hasSelectedCategory =
          orderedCategories.any((c) => c.id == _selectedCategoryId);
      final selectedCategory =
          hasSelectedCategory ? _selectedCategoryId : 'All';
      if (!mounted) return;
      setState(() {
        _categories = orderedCategories;
        _selectedCategoryId = selectedCategory;
        _focusedIndex = 0;
      });

      await _fetchAdsPage(reset: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categories = _adsService.getFallbackCategories();
        _ads = [];
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAdsPage({bool reset = false}) async {
    if (!mounted) return;
    if (!reset && (_isLoadingMore || !_hasMore)) return;

    if (reset) {
      _page = 1;
      _hasMore = true;
    }

    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _ads = [];
        _focusedIndex = 0;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final normalizedSearch = _searchQuery.trim();
      Map<String, dynamic> result = await _adsService.searchAds(
        q: normalizedSearch.isEmpty ? null : normalizedSearch,
        category: _selectedCategoryId == 'All' ? null : _selectedCategoryId,
        status: 'active',
        contentType: 'ad',
        page: _page,
        limit: _pageSize,
      );

      List<Ad> ads = (result['ads'] as List<Ad>? ?? const <Ad>[]);
      int totalPages = (result['totalPages'] as int?) ?? _page;
      if (reset && ads.isEmpty) {
        final fallback = await _adsService.searchAds(
          q: normalizedSearch.isEmpty ? null : normalizedSearch,
          category: _selectedCategoryId == 'All' ? null : _selectedCategoryId,
          status: 'active',
          page: _page,
          limit: _pageSize,
        );
        final fallbackAds = (fallback['ads'] as List<Ad>? ?? const <Ad>[]);
        if (fallbackAds.isNotEmpty) {
          result = fallback;
          ads = fallbackAds;
          totalPages = (fallback['totalPages'] as int?) ?? _page;
        }
      }

      if (!mounted) return;
      setState(() {
        if (reset) {
          _ads = ads;
        } else {
          _ads.addAll(ads);
        }
        _hasMore = ads.length >= _pageSize && _page < totalPages;
        _page += 1;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
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
    await _fetchAdsPage(reset: true);
  }

  void _openSearch() {
    setState(() {
      _searchOpen = true;
      _searchDropdownVisible = true;
    });
    _searchController.text = _searchInput;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    setState(() {
      _searchOpen = false;
      _searchDropdownVisible = false;
      _searchLoading = false;
      _searchInput = '';
      _searchUsers = [];
      _searchAds = [];
    });
    _searchController.clear();
  }

  void _onSearchChanged(String value) {
    final next = value.trim();
    setState(() {
      _searchInput = value;
    });
    _searchDebounce?.cancel();
    if (next.isEmpty) {
      setState(() {
        _searchUsers = [];
        _searchAds = [];
        _searchDropdownVisible = false;
        _searchLoading = false;
      });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_runSearch(next));
    });
  }

  Future<void> _runSearch(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      setState(() {
        _searchLoading = false;
        _searchUsers = [];
        _searchAds = [];
        _searchDropdownVisible = false;
      });
      return;
    }
    final epoch = ++_searchEpoch;
    setState(() {
      _searchLoading = true;
      _searchDropdownVisible = true;
    });
    try {
      final result = await _adsService.searchAds(
        q: normalized,
        status: 'active',
        page: 1,
        limit: 20,
      );
      if (!mounted || epoch != _searchEpoch) return;

      final users = (result['users'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((u) => _SearchUser.fromMap(Map<String, dynamic>.from(u)))
          .where((u) => u.id.isNotEmpty)
          .toList();
      final ads = (result['ads'] as List<Ad>? ?? const <Ad>[]);
      setState(() {
        _searchUsers = users;
        _searchAds = ads;
        _searchLoading = false;
        _searchDropdownVisible = true;
      });
    } catch (_) {
      if (!mounted || epoch != _searchEpoch) return;
      setState(() {
        _searchUsers = [];
        _searchAds = [];
        _searchLoading = false;
        _searchDropdownVisible = true;
      });
    }
  }

  void _handleSearchUserTap(_SearchUser user) {
    if (user.id.isEmpty) return;
    _closeSearch();
    Navigator.of(context).pushNamed('/profile/${user.id}');
  }

  void _handleSearchAdTap(Ad ad) {
    _closeSearch();
    final index = _ads.indexWhere((a) => a.id == ad.id);
    if (index >= 0) {
      _goToPage(index);
    }
  }

  void _handleSearchAdVendorTap(Ad ad) {
    final uid = _adProfileId(ad);
    if (uid == null || uid.isEmpty) return;
    _closeSearch();
    Navigator.of(context).pushNamed('/profile/$uid');
  }

  Future<void> _ensurePersistViewedLoaded() async {
    if (_persistViewedLoaded) return;
    _persistViewedLoadFuture ??= () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final list =
            prefs.getStringList(_viewedAdIdsPrefsKey) ?? const <String>[];
        _persistViewedAdIds.clear();
        _persistViewedAdIdsOrder.clear();
        for (final raw in list) {
          final id = raw.trim();
          if (id.isEmpty) continue;
          if (_persistViewedAdIds.add(id)) {
            _persistViewedAdIdsOrder.add(id);
          }
        }
      } catch (_) {
        // If prefs are unavailable, we still keep session-level protection.
      } finally {
        _persistViewedLoaded = true;
      }
    }();
    await _persistViewedLoadFuture;
  }

  Future<void> _rememberAdViewed(String adId) async {
    final id = adId.trim();
    if (id.isEmpty) return;
    await _ensurePersistViewedLoaded();
    if (_persistViewedAdIds.contains(id)) return;

    _persistViewedAdIds.add(id);
    _persistViewedAdIdsOrder.add(id);
    if (_persistViewedAdIdsOrder.length > _maxRememberedViewedAds) {
      final overflow =
          _persistViewedAdIdsOrder.length - _maxRememberedViewedAds;
      for (var i = 0; i < overflow; i++) {
        final removed = _persistViewedAdIdsOrder.removeAt(0);
        _persistViewedAdIds.remove(removed);
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_viewedAdIdsPrefsKey, _persistViewedAdIdsOrder);
    } catch (_) {
      // Ignore persistence failures; session-level guard still applies.
    }
  }

  bool _wasAdViewedPersisted(String adId) {
    final id = adId.trim();
    if (id.isEmpty) return false;
    if (!_persistViewedLoaded) return false;
    return _persistViewedAdIds.contains(id);
  }

  Future<void> _recordViewForAd(Ad ad) async {
    final adId = ad.id.trim();
    if (adId.isEmpty) return;
    if (_sessionViewedAdIds.contains(adId)) return;
    await _ensurePersistViewedLoaded();
    if (_wasAdViewedPersisted(adId)) return;

    final userId = await CurrentUser.id;
    if (userId == null || userId.trim().isEmpty) return;

    _sessionViewedAdIds.add(adId);
    try {
      final res = await _adsService.recordAdView(adId: adId, userId: userId);
      if (!mounted) return;
      _handleViewReward(res, ad);
    } catch (_) {
      _sessionViewedAdIds.remove(adId);
    }
  }

  void _handleViewReward(Map<String, dynamic> res, Ad ad) {
    final rewarded = res['rewarded'] == true;
    final coinsRaw = res['coins_rewarded'] ??
        res['coins'] ??
        res['reward'] ??
        (res['data'] is Map ? (res['data'] as Map)['coins_rewarded'] : null);
    final coins = coinsRaw is num
        ? coinsRaw.round()
        : int.tryParse(coinsRaw?.toString() ?? '');
    final viewCountRaw = res['view_count'] ??
        (res['data'] is Map ? (res['data'] as Map)['view_count'] : null);
    final viewCount = viewCountRaw is num
        ? viewCountRaw.round()
        : int.tryParse(viewCountRaw?.toString() ?? '');
    if (rewarded) {
      final reward = (coins ?? (ad.coinReward > 0 ? ad.coinReward : 10));
      unawaited(_rememberAdViewed(ad.id));
      _showViewRewardPopup(amount: reward);
      return;
    }
    if (res.containsKey('rewarded') || res.containsKey('view_count')) {
      _showViewRecordedPopup(viewCount: viewCount);
    }
  }

  void _showViewRewardPopup({required int amount}) {
    setState(() {
      _viewRewardPopup = _ViewRewardPopupData(
        id: DateTime.now().millisecondsSinceEpoch,
        amount: amount,
      );
      _viewRecordedPopup = null;
    });
    _viewPopupVisible.value = true;
  }

  void _showViewRecordedPopup({int? viewCount}) {
    setState(() {
      _viewRecordedPopup = _ViewRecordedPopupData(
        id: DateTime.now().millisecondsSinceEpoch,
        viewCount: viewCount,
      );
      _viewRewardPopup = null;
    });
    _viewPopupVisible.value = true;
  }

  void _hideViewRewardPopup() {
    setState(() {
      _viewRewardPopup = null;
    });
    _viewPopupVisible.value = false;
  }

  void _hideViewRecordedPopup() {
    setState(() {
      _viewRecordedPopup = null;
    });
    _viewPopupVisible.value = false;
  }

  Future<void> _openAdComments(Ad ad) async {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    if (isDesktop) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Comments',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, _, __) {
          return SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 360,
                height: MediaQuery.of(context).size.height * 0.78,
                margin: const EdgeInsets.only(right: 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                clipBehavior: Clip.antiAlias,
                child: AdCommentsSheet(adId: ad.id),
              ),
            ),
          );
        },
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: AdCommentsSheet(adId: ad.id),
      ),
    );
  }

  void _goToPage(int index) {
    if (_ads.isEmpty) return;
    final next = index.clamp(0, _ads.length - 1);
    if (next == _focusedIndex) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _handleKeyboard(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _goToPage(_focusedIndex + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _goToPage(_focusedIndex - 1);
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.scrollDelta.dy.abs() < 20) return;
    if (event.scrollDelta.dy > 0) {
      _goToPage(_focusedIndex + 1);
    } else {
      _goToPage(_focusedIndex - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    // Read from the raw View to bypass any MediaQuery manipulation.
    final view = View.of(context);
    final devicePixelRatio = view.devicePixelRatio;
    final viewPaddingBottom = view.padding.bottom / devicePixelRatio;
    final mq = MediaQuery.of(context);
    final mqViewPaddingBottom = mq.viewPadding.bottom;
    final mqPaddingBottom = mq.padding.bottom;

    double bottomSystemInset = viewPaddingBottom;
    if (mqViewPaddingBottom > bottomSystemInset) {
      bottomSystemInset = mqViewPaddingBottom;
    }
    if (mqPaddingBottom > bottomSystemInset) {
      bottomSystemInset = mqPaddingBottom;
    }
    if (_cachedBottomInset > bottomSystemInset) {
      bottomSystemInset = _cachedBottomInset;
    }
    assert(() {
      debugPrint(
        '[AdsPageScreen] bottomSystemInset=$bottomSystemInset '
        'viewPadding=${mq.viewPadding.bottom} padding=${mq.padding.bottom}',
      );
      return true;
    }());
    final clipFeedBottomInsetForAndroid = !isDesktop &&
        defaultTargetPlatform == TargetPlatform.android &&
        bottomSystemInset > 0;
    final feedView = KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyboard,
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: (index) {
            setState(() {
              _focusedIndex = index;
            });
            if (index >= 0 && index < _ads.length) {
              if (index >= _ads.length - 2) {
                unawaited(_fetchAdsPage());
              }
            }
          },
          itemCount: _ads.length,
          itemBuilder: (context, index) {
            final ad = _ads[index];
            return AdVideoItem(
              key: ValueKey('ad-video-${ad.id}'),
              ad: ad,
              isActive: widget.isTabActive && index == _focusedIndex,
              bottomInset:
                  clipFeedBottomInsetForAndroid ? 0 : bottomSystemInset,
              viewPopupVisibleListenable: _viewPopupVisible,
              onCompletedView: () => _recordViewForAd(ad),
              onAutoNext: () {
                if (index + 1 < _ads.length) {
                  _goToPage(index + 1);
                }
              },
              onOpenComments: () async {
                await _openAdComments(ad);
              },
            );
          },
        ),
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBody: true,
      backgroundColor: Colors.black,
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: Stack(
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
                        : isDesktop
                            ? Center(
                                child: Container(
                                  width: 360,
                                  height:
                                      MediaQuery.of(context).size.height * 0.9,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.12),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0xAA000000),
                                        blurRadius: 28,
                                        offset: Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: feedView,
                                ),
                              )
                            : (clipFeedBottomInsetForAndroid
                                ? Stack(
                                    children: [
                                      Positioned.fill(
                                        bottom: bottomSystemInset,
                                        child: feedView,
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        height: bottomSystemInset,
                                        child: const ColoredBox(
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  )
                                : feedView),

            // Layer 2: Top Navigation Overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: _buildTopBar(isDesktop: isDesktop),
              ),
            ),
            if (_searchOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeSearch,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),
            _buildSearchDropdown(isDesktop: isDesktop),
            if (_viewRewardPopup != null)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _viewRewardPopup == null,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child:
                              ScaleTransition(scale: animation, child: child),
                        );
                      },
                      child: _viewRewardPopup == null
                          ? const SizedBox.shrink()
                          : _ViewRewardPopupCard(
                              key: ValueKey<int>(_viewRewardPopup!.id),
                              data: _viewRewardPopup!,
                              onOk: _hideViewRewardPopup,
                            ),
                    ),
                  ),
                ),
              ),
            if (_viewRecordedPopup != null)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: _viewRecordedPopup == null,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child:
                              ScaleTransition(scale: animation, child: child),
                        );
                      },
                      child: _viewRecordedPopup == null
                          ? const SizedBox.shrink()
                          : _ViewRecordedPopupCard(
                              key: ValueKey<int>(_viewRecordedPopup!.id),
                              data: _viewRecordedPopup!,
                              onOk: _hideViewRecordedPopup,
                            ),
                    ),
                  ),
                ),
              ),
            if (!_isLoading && _error == null && _ads.isNotEmpty && isDesktop)
              Positioned(
                right: 20,
                top: MediaQuery.of(context).size.height * 0.45,
                child: Column(
                  children: [
                    _navButton(
                      icon: Icons.keyboard_arrow_up,
                      onTap: _focusedIndex > 0
                          ? () => _goToPage(_focusedIndex - 1)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    _navButton(
                      icon: Icons.keyboard_arrow_down,
                      onTap: _focusedIndex < _ads.length - 1
                          ? () => _goToPage(_focusedIndex + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            if (_isLoadingMore)
              Positioned(
                bottom: isDesktop ? 16 : (90.0 + bottomSystemInset),
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Loading more ads...',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _navButton({required IconData icon, VoidCallback? onTap}) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Icon(
          icon,
          color: disabled ? Colors.white38 : Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildTopBar({required bool isDesktop}) {
    final backIconColor = isDesktop ? Colors.white70 : Colors.white;
    final backIconSize = isDesktop ? 22.0 : 28.0;
    final searchIconColor = isDesktop ? Colors.white70 : Colors.white;
    final searchIconSize = isDesktop ? 20.0 : 24.0;

    Widget toggleButton() {
      return IconButton(
        onPressed: () =>
            setState(() => _categoriesExpanded = !_categoriesExpanded),
        icon: AnimatedRotation(
          turns: _categoriesExpanded ? 0.5 : 0.0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          child: Icon(LucideIcons.chevronLeft,
              color: backIconColor, size: backIconSize),
        ),
      );
    }

    Widget searchButton() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(LucideIcons.search,
                color: searchIconColor, size: searchIconSize),
            onPressed: _openSearch,
          ),
        ],
      );
    }

    Widget searchField() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.search,
                color: Colors.white.withValues(alpha: 0.8), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                onSubmitted: (value) => _runSearch(value.trim()),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Search ads, users…',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (_searchLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              )
            else if (_searchInput.trim().isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
                icon: Icon(LucideIcons.x,
                    color: Colors.white.withValues(alpha: 0.7), size: 16),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints.tightFor(width: 28, height: 28),
              ),
          ],
        ),
      );
    }

    Widget inlineCategories() {
      if (_categories.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: _categories
              .map((c) => _buildCategoryChip(c.id, c.name, isDesktop))
              .toList(),
        ),
      );
    }

    if (_searchOpen) {
      return Container(
        padding: EdgeInsets.symmetric(
          vertical: isDesktop ? 6 : 8,
          horizontal: 12,
        ),
        child: Row(
          children: [
            Expanded(child: searchField()),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _closeSearch,
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isDesktop ? 6 : 8,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide =
                  Tween<Offset>(begin: const Offset(0.18, 0), end: Offset.zero)
                      .animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: _categoriesExpanded
                ? Row(
                    key: const ValueKey('expanded'),
                    children: [
                      toggleButton(),
                      Expanded(child: inlineCategories()),
                      searchButton(),
                    ],
                  )
                : Row(
                    key: const ValueKey('collapsed'),
                    children: [
                      const Spacer(),
                      toggleButton(),
                      searchButton(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label, bool isDesktop) {
    final isSelected = _selectedCategoryId == id;
    return GestureDetector(
      onTap: () => _onCategorySelected(id),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 10 : 12,
          vertical: isDesktop ? 4 : 5,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: Colors.white, width: 1) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : Colors.white.withValues(alpha: isDesktop ? 0.75 : 0.9),
            fontWeight: FontWeight.w600,
            fontSize: isDesktop ? 11 : 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchDropdown({required bool isDesktop}) {
    if (!_searchOpen || !_searchDropdownVisible) {
      return const SizedBox.shrink();
    }

    final query = _searchInput.trim();
    final hasResults = _searchUsers.isNotEmpty || _searchAds.isNotEmpty;
    final maxHeight =
        isDesktop ? 320.0 : MediaQuery.of(context).size.height * 0.5;
    final maxWidth = isDesktop ? 340.0 : double.infinity;

    return Positioned(
      top: isDesktop ? 60 : 86,
      left: 12,
      right: 12,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Material(
                color: Colors.transparent,
                child: _searchLoading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        ),
                      )
                    : !hasResults && query.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 24, horizontal: 16),
                            child: Text(
                              'No results for "$query"',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : !hasResults
                            ? const SizedBox.shrink()
                            : ListView(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                children: [
                                  if (_searchUsers.isNotEmpty) ...[
                                    _buildSearchSectionHeader('People'),
                                    ..._searchUsers.map(_buildSearchUserTile),
                                  ],
                                  if (_searchAds.isNotEmpty) ...[
                                    _buildSearchSectionHeader('Ads'),
                                    ..._searchAds.map(_buildSearchAdTile),
                                  ],
                                ],
                              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildSearchUserTile(_SearchUser user) {
    return InkWell(
      onTap: () => _handleSearchUserTap(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildSearchAvatar(
              url: user.avatarUrl,
              fallback: user.initials,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (user.username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAdTile(Ad ad) {
    return InkWell(
      onTap: () => _handleSearchAdTap(ad),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildSearchAdThumb(ad),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (ad.caption ?? ad.description ?? 'Ad').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if ((ad.category ?? '').trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            ad.category!.trim(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: InkWell(
                          onTap: (ad.userId?.trim().isNotEmpty ?? false)
                              ? () => _handleSearchAdVendorTap(ad)
                              : null,
                          child: Text(
                            ad.vendorBusinessName ?? ad.userName ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAvatar({String? url, required String fallback}) {
    final child = url != null && url.trim().isNotEmpty
        ? ClipOval(
            child: Image.network(
              url,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          )
        : CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF1F2937),
            child: Text(
              fallback,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          );

    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(1.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFDE047), Color(0xFFF97316), Color(0xFFEC4899)],
        ),
      ),
      child: ClipOval(child: child),
    );
  }

  Widget _buildSearchAdThumb(Ad ad) {
    return _SearchAdThumb(
      ad: ad,
      mediaHeaders: _mediaHeaders,
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
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
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
            const Icon(LucideIcons.circleAlert,
                color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load ads',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
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
  final double bottomInset;
  final ValueListenable<bool> viewPopupVisibleListenable;
  final Future<void> Function() onCompletedView;
  final Future<void> Function() onOpenComments;
  final VoidCallback onAutoNext;

  const AdVideoItem({
    super.key,
    required this.ad,
    required this.isActive,
    required this.bottomInset,
    required this.viewPopupVisibleListenable,
    required this.onCompletedView,
    required this.onOpenComments,
    required this.onAutoNext,
  });

  @override
  State<AdVideoItem> createState() => _AdVideoItemState();
}

class _AdVideoItemState extends State<AdVideoItem>
    with SingleTickerProviderStateMixin {
  static const Duration _ctaRevealDelay = Duration(seconds: 5);
  VideoPlayerController? _controller;
  late final AnimationController _watchProgressController =
      AnimationController(vsync: this);
  final AdsService _adsService = AdsService();
  final SupabaseService _supabase = SupabaseService();
  bool _isInitialized = false;
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isFollowing = false;
  bool _isMuted = false;
  bool _isLikeLoading = false;
  bool _isFollowLoading = false;
  int _likesCount = 0;
  bool _userPaused = false;
  bool _resumeAttemptInFlight = false;
  bool _loopRestartInFlight = false;
  late bool _lastViewPopupVisible;
  Timer? _watchGateTimer;
  int _watchTotalMs = 15000;
  bool _watchProgressRunning = false;
  bool _captionExpanded = false;
  Map<String, String>? _mediaHeaders;
  bool _viewMarked = false;
  Timer? _likeRewardTimer;
  _LikeRewardPopupData? _likeRewardPopup;
  Timer? _ctaTimer;
  DateTime? _ctaCountdownStartedAt;
  Duration _ctaCountdownAccumulated = Duration.zero;
  bool _ctaVisible = false;

  // Compatibility accessors for hot-reload safety (older kernels referenced these).
  Timer? get _watchTimer => _watchGateTimer;
  set _watchTimer(Timer? value) => _watchGateTimer = value;

  double get _progress => _watchProgressController.value;
  set _progress(double value) =>
      _watchProgressController.value = value.clamp(0.0, 1.0);

  int get _watchedMs =>
      (_watchProgressController.value * _watchTotalMs).round();
  set _watchedMs(int value) {
    if (_watchTotalMs <= 0) return;
    _watchProgressController.value = (value / _watchTotalMs).clamp(0.0, 1.0);
  }

  Future<void> _safeSetVolume(double volume) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.setVolume(volume);
    } catch (_) {}
  }

  Future<void> _safePlay() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.play();
    } catch (_) {}
  }

  Future<void> _safePause() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.pause();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _isLiked = widget.ad.isLikedByMe;
    _isSaved = widget.ad.isSavedByMe;
    _likesCount = widget.ad.likesCount;
    _lastViewPopupVisible = widget.viewPopupVisibleListenable.value;
    widget.viewPopupVisibleListenable
        .addListener(_onViewPopupVisibilityChanged);
    _loadMediaHeaders();
    unawaited(_loadFollowState());
    _initializeVideo();
    _startOrStopProgress();
    _startOrStopCtaCountdown();
  }

  @override
  void didUpdateWidget(AdVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewPopupVisibleListenable !=
        widget.viewPopupVisibleListenable) {
      oldWidget.viewPopupVisibleListenable
          .removeListener(_onViewPopupVisibilityChanged);
      _lastViewPopupVisible = widget.viewPopupVisibleListenable.value;
      widget.viewPopupVisibleListenable
          .addListener(_onViewPopupVisibilityChanged);
    }
    if (oldWidget.ad.id != widget.ad.id) {
      _isLiked = widget.ad.isLikedByMe;
      _isSaved = widget.ad.isSavedByMe;
      _likesCount = widget.ad.likesCount;
      _captionExpanded = false;
      _isInitialized = false;
      _userPaused = false;
      _viewMarked = false;
      _resetCtaCountdown();
      _watchProgressController.value = 0;
      _watchProgressRunning = false;
      _watchProgressController.stop(canceled: true);
      _controller?.removeListener(_onVideoTick);
      unawaited(_controller?.dispose());
      _controller = null;
      unawaited(_loadFollowState());
      _initializeVideo();
      _startOrStopProgress();
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _userPaused = false;
        unawaited(_safeSetVolume(_isMuted ? 0 : 1));
        unawaited(_safePlay());
      } else {
        unawaited(_safeSetVolume(0));
        _userPaused = true;
        unawaited(_safePause());
      }
      _startOrStopProgress();
    }
    _startOrStopCtaCountdown();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    _watchGateTimer?.cancel();
    _watchProgressController.dispose();
    _likeRewardTimer?.cancel();
    _ctaTimer?.cancel();
    widget.viewPopupVisibleListenable
        .removeListener(_onViewPopupVisibilityChanged);
    super.dispose();
  }

  void _onViewPopupVisibilityChanged() {
    final visible = widget.viewPopupVisibleListenable.value;
    final dismissed = _lastViewPopupVisible && !visible;
    _lastViewPopupVisible = visible;
    if (!dismissed) return;
    if (!mounted || !widget.isActive) return;
    if (!_isVideoAd) return;
    if (_watchProgressController.value < 1) return;
    _resetWatchProgressForLoop();
  }

  void _resetWatchProgressForLoop() {
    if (_watchProgressController.isAnimating) {
      _watchProgressController.stop(canceled: false);
    }
    _watchProgressController.value = 0;
    _watchProgressRunning = false;
    _updateWatchProgressRunning();
  }

  void _showLikeRewardPopup({required bool isLike}) {
    _likeRewardTimer?.cancel();
    setState(() {
      _likeRewardPopup = _LikeRewardPopupData(
        id: DateTime.now().millisecondsSinceEpoch,
        amount: 10,
        isLike: isLike,
      );
    });
    _likeRewardTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      setState(() {
        _likeRewardPopup = null;
      });
    });
  }

  void _hideLikeRewardPopup() {
    _likeRewardTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _likeRewardPopup = null;
    });
  }

  Future<void> _initializeVideo() async {
    final url = widget.ad.videoUrl;
    if (url != null && url.isNotEmpty) {
      _controller?.removeListener(_onVideoTick);
      await _controller?.dispose();
      final headers = await _videoHeadersFor(url);
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
        formatHint: _videoFormatHintForUrl(url),
      );
      try {
        await _controller!.initialize();
        await _controller!.setLooping(true);
        await _controller!.setVolume(widget.isActive ? (_isMuted ? 0 : 1) : 0);
        _controller!.addListener(_onVideoTick);
        if (widget.isActive) {
          await _controller!.play();
        }
        _startOrStopProgress();
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

  Future<Map<String, String>> _videoHeadersFor(String url) async {
    if (_mediaHeaders != null && _mediaHeaders!.isNotEmpty)
      return _mediaHeaders!;
    if (!UrlHelper.shouldAttachAuthHeader(url)) return const {};
    await _loadMediaHeaders();
    return _mediaHeaders ?? const {};
  }

  VideoFormat? _videoFormatHintForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return VideoFormat.hls;
    if (lower.contains('.mpd')) return VideoFormat.dash;
    return null;
  }

  Future<void> _loadMediaHeaders() async {
    if (_mediaHeaders != null) return;
    final token = await ApiClient().getToken();
    if (token != null && token.isNotEmpty) {
      _mediaHeaders = {'Authorization': 'Bearer $token'};
      if (mounted) setState(() {});
    }
  }

  void _onVideoTick() {
    final controller = _controller;
    if (!mounted || controller == null || !widget.isActive || !_isInitialized) {
      return;
    }
    if (_userPaused) return;

    final value = controller.value;
    if (!value.isInitialized || value.hasError) return;
    _updateWatchProgressRunning();
    final duration = value.duration;
    final atEnd = value.isCompleted ||
        (duration > Duration.zero &&
            value.position >= duration - const Duration(milliseconds: 250));
    if (atEnd && !_loopRestartInFlight) {
      _loopRestartInFlight = true;
      if (_ctaVisible) {
        setState(() {
          _ctaVisible = false;
        });
      }
      _resetCtaCountdown();
      unawaited(() async {
        try {
          await controller.seekTo(Duration.zero);
          if (widget.isActive && !_userPaused) {
            await controller.play();
          }
        } catch (_) {
          // Ignore transient playback errors.
        } finally {
          _loopRestartInFlight = false;
          if (mounted) {
            _startOrStopCtaCountdown();
          }
        }
      }());
      return;
    }

    if (!value.isPlaying && !value.isBuffering && !_resumeAttemptInFlight) {
      _resumeAttemptInFlight = true;
      unawaited(() async {
        try {
          await controller.play();
        } catch (_) {
          // Ignore transient playback errors.
        } finally {
          _resumeAttemptInFlight = false;
        }
      }());
    }
  }

  bool get _isVideoAd => (widget.ad.videoUrl ?? '').trim().isNotEmpty;

  void _startOrStopProgress() {
    _watchGateTimer?.cancel();

    final totalSeconds = widget.ad.watchDurationSeconds > 0
        ? widget.ad.watchDurationSeconds
        : 15;
    _watchTotalMs = totalSeconds * 1000;
    _watchProgressController.duration = Duration(milliseconds: _watchTotalMs);

    _watchProgressController.removeStatusListener(_onWatchProgressStatus);
    _watchProgressController.addStatusListener(_onWatchProgressStatus);

    if (!widget.isActive) {
      _setWatchProgressRunning(false);
      return;
    }

    // If the previous ad finished, start fresh for the new ad.
    if (_watchProgressController.value >= 1) {
      _watchProgressController.value = 0;
    }

    _updateWatchProgressRunning();
    _watchGateTimer =
        Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted || !widget.isActive) {
        timer.cancel();
        return;
      }
      _updateWatchProgressRunning();
    });
  }

  void _onWatchProgressStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    if (!_viewMarked) {
      _viewMarked = true;
      unawaited(widget.onCompletedView());
    }
    if (_isVideoAd) {
      _setWatchProgressRunning(false);
      if (!widget.viewPopupVisibleListenable.value) {
        _resetWatchProgressForLoop();
      }
      return;
    }
    if (!_isVideoAd && widget.isActive) {
      widget.onAutoNext();
    }
  }

  void _updateWatchProgressRunning() {
    final allowAdvance =
        _isVideoAd ? _allowWatchProgressForVideo() : !_userPaused;
    _setWatchProgressRunning(allowAdvance);
    _startOrStopCtaCountdown();
  }

  bool _allowWatchProgressForVideo() {
    final controller = _controller;
    final value = controller?.value;
    return controller != null &&
        value != null &&
        value.isInitialized &&
        value.isPlaying &&
        !value.isBuffering &&
        !_userPaused;
  }

  void _setWatchProgressRunning(bool running) {
    if (_watchProgressRunning == running) return;
    _watchProgressRunning = running;

    if (!running) {
      if (_watchProgressController.isAnimating) {
        _watchProgressController.stop(canceled: false);
      }
      return;
    }

    if (_watchProgressController.value >= 1) return;
    final duration = _watchProgressController.duration;
    if (duration == null || duration == Duration.zero) return;
    _watchProgressController.forward();
  }

  void _togglePlay() {
    // Video ads: toggle actual playback.
    // Image ads: toggle the watch-progress timer (pauses auto-advance).
    final controller = _controller;
    if (_isVideoAd) {
      if (controller == null || !_isInitialized) return;
      setState(() {
        if (controller.value.isPlaying) {
          _userPaused = true;
          unawaited(_safePause());
        } else {
          _userPaused = false;
          unawaited(_safeSetVolume(_isMuted ? 0 : 1));
          unawaited(_safePlay());
        }
      });
      _updateWatchProgressRunning();
      _startOrStopCtaCountdown();
      return;
    }

    if (!widget.isActive) return;
    setState(() => _userPaused = !_userPaused);
    _updateWatchProgressRunning();
    _startOrStopCtaCountdown();
  }

  bool _shouldRunCtaCountdown() {
    if (_ctaVisible) return false;
    if (!widget.isActive) return false;
    if (_userPaused) return false;
    if (_isVideoAd) {
      final value = _controller?.value;
      if (value == null || !value.isInitialized) return false;
      if (!value.isPlaying) return false;
      if (value.isBuffering) return false;
    }
    return true;
  }

  void _resetCtaCountdown() {
    _ctaTimer?.cancel();
    _ctaTimer = null;
    _ctaCountdownStartedAt = null;
    _ctaCountdownAccumulated = Duration.zero;
    _ctaVisible = false;
  }

  void _stopCtaCountdown({bool accumulate = true}) {
    _ctaTimer?.cancel();
    _ctaTimer = null;
    final startedAt = _ctaCountdownStartedAt;
    if (startedAt != null && accumulate) {
      _ctaCountdownAccumulated += DateTime.now().difference(startedAt);
      if (_ctaCountdownAccumulated > _ctaRevealDelay) {
        _ctaCountdownAccumulated = _ctaRevealDelay;
      }
    }
    _ctaCountdownStartedAt = null;
  }

  void _startOrStopCtaCountdown() {
    if (_ctaVisible) {
      _stopCtaCountdown(accumulate: false);
      return;
    }

    if (!_shouldRunCtaCountdown()) {
      _stopCtaCountdown(accumulate: true);
      return;
    }

    if (_ctaTimer != null) return;
    if (_ctaCountdownStartedAt != null) return;

    final remaining = _ctaRevealDelay - _ctaCountdownAccumulated;
    if (remaining <= Duration.zero) {
      if (!mounted) return;
      setState(() {
        _ctaVisible = true;
      });
      _stopCtaCountdown(accumulate: false);
      return;
    }

    _ctaCountdownStartedAt = DateTime.now();
    _ctaTimer = Timer(remaining, () {
      if (!mounted) return;
      setState(() {
        _ctaVisible = true;
      });
      _stopCtaCountdown(accumulate: false);
    });
  }

  String _secondaryCtaLabel() {
    final url = (widget.ad.websiteUrl ?? '').trim().toLowerCase();
    if (url.isEmpty) return 'Company Details';
    if (url.contains('play.google.com') || url.contains('apps.apple.com')) {
      return 'Install';
    }
    if (url.contains('book') ||
        url.contains('booking') ||
        url.contains('reserve')) {
      return 'Book';
    }
    return 'Company Details';
  }

  void _openSecondaryCta() {
    final url = (widget.ad.websiteUrl ?? '').trim();
    if (url.isEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdCompanyDetailScreen(companyId: widget.ad.companyId),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _secondaryCtaLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  url,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: url));
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link copied')),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Copy Link'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AdCompanyDetailScreen(
                                companyId: widget.ad.companyId,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Company Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCtaButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/ad/${widget.ad.id}');
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.96),
              foregroundColor: Colors.black,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'View Ad Detail',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: _openSecondaryCta,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.96),
              foregroundColor: Colors.black,
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.35),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _secondaryCtaLabel(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleLike() async {
    if (_isLikeLoading || widget.ad.id.isEmpty) return;

    final previousLiked = _isLiked;
    final previousLikes = _likesCount;
    final nextLiked = !previousLiked;
    final nextLikes = nextLiked
        ? previousLikes + 1
        : (previousLikes > 0 ? previousLikes - 1 : 0);

    setState(() {
      _isLikeLoading = true;
      _isLiked = nextLiked;
      _likesCount = nextLikes;
    });

    try {
      final currentUserId = await CurrentUser.id;
      final userId = currentUserId?.trim();
      if (userId == null || userId.isEmpty) {
        throw Exception('Please log in to like ads');
      }

      bool? readBool(Map<String, dynamic> data, List<String> keys) {
        for (final key in keys) {
          final value = data[key];
          if (value is bool) return value;
          if (value is num) return value != 0;
          if (value is String) {
            final lower = value.trim().toLowerCase();
            if (lower == 'true' || lower == '1') return true;
            if (lower == 'false' || lower == '0') return false;
          }
        }
        return null;
      }

      int? readInt(Map<String, dynamic> data, List<String> keys) {
        for (final key in keys) {
          final value = data[key];
          if (value is int) return value;
          if (value is num) return value.toInt();
          if (value is String) {
            final parsed = int.tryParse(value);
            if (parsed != null) return parsed;
          }
        }
        return null;
      }

      if (nextLiked) {
        final res =
            await _adsService.likeAd(adId: widget.ad.id, userId: userId);
        final serverLikes = readInt(res, const ['likes_count', 'likesCount']);
        final serverLiked = readBool(
          res,
          const [
            'is_liked',
            'liked',
            'isLiked',
            'is_liked_by_me',
            'liked_by_me'
          ],
        );
        if (mounted) {
          setState(() {
            if (serverLikes != null) {
              _likesCount = serverLikes;
            }
            if (serverLiked != null) {
              _isLiked = serverLiked;
            }
          });
        }
        if (mounted) {
          _showLikeRewardPopup(isLike: true);
        }
      } else {
        final res =
            await _adsService.dislikeAd(adId: widget.ad.id, userId: userId);
        final serverLikes = readInt(res, const ['likes_count', 'likesCount']);
        final isDisliked =
            readBool(res, const ['is_disliked', 'disliked', 'isDisliked']);
        final serverLiked = readBool(
          res,
          const [
            'is_liked',
            'liked',
            'isLiked',
            'is_liked_by_me',
            'liked_by_me'
          ],
        );
        if (mounted) {
          setState(() {
            if (serverLikes != null) {
              _likesCount = serverLikes;
            }
            if (serverLiked != null) {
              _isLiked = serverLiked;
            }
            if (isDisliked is bool && isDisliked) {
              _isLiked = false;
            }
          });
        }
        if (mounted) {
          _showLikeRewardPopup(isLike: false);
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // Keep UI consistent with server semantics for common edge cases.
      if (nextLiked && e.statusCode == 409) {
        setState(() {
          _isLiked = true;
          if (_likesCount < previousLikes) {
            _likesCount = previousLikes;
          }
        });
      } else if (!nextLiked && e.statusCode == 400) {
        setState(() {
          _isLiked = false;
          _likesCount = previousLikes > 0 ? previousLikes - 1 : 0;
        });
      } else {
        setState(() {
          _isLiked = previousLiked;
          _likesCount = previousLikes;
        });
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

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;
    final targetUserId = widget.ad.userId?.trim() ?? '';
    if (targetUserId.isEmpty) return;
    final hasToken = await ApiClient().hasToken;
    if (!hasToken) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to follow users')),
        );
      }
      return;
    }

    final previous = _isFollowing;
    final next = !previous;
    setState(() {
      _isFollowLoading = true;
      _isFollowing = next;
    });
    globalStore.dispatch(UpdateUserFollowed(targetUserId, next));

    try {
      final ok = previous
          ? await _supabase.unfollowUser(targetUserId)
          : await _supabase.followUser(targetUserId);
      if (!ok) {
        throw Exception('follow_update_failed');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFollowing = previous;
      });
      globalStore.dispatch(UpdateUserFollowed(targetUserId, previous));
    } finally {
      if (mounted) {
        setState(() {
          _isFollowLoading = false;
        });
      }
    }
  }

  Future<void> _loadFollowState() async {
    final targetUserId = widget.ad.userId?.trim() ?? '';
    if (targetUserId.isEmpty) return;
    final meId = await CurrentUser.id;
    if (meId == null || meId.trim().isEmpty) return;

    try {
      final followed = await _supabase.getFollowedUserIds(meId);
      if (!mounted) return;
      setState(() {
        _isFollowing = followed.contains(targetUserId);
      });
    } catch (_) {}
  }

  Future<void> _toggleSaveAd() async {
    if (widget.ad.id.isEmpty) return;
    setState(() {
      _isSaved = !_isSaved;
    });
  }

  @override
  Widget build(BuildContext context) {
    const ctaBottomPadding = 10.0;
    const ctaHeightEstimate = 48.0;
    final ctaBottom = widget.bottomInset + ctaBottomPadding;
    final ctaTop = ctaBottom + ctaHeightEstimate;

    final actionsBottom = 82.0 + widget.bottomInset;
    final infoBottom = _ctaVisible ? (ctaTop + 10) : (6.0 + widget.bottomInset);
    final media = Container(
      color: Colors.black,
      child: _isInitialized && _controller != null && _isVideoAd
          ? ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          : widget.ad.imageUrl != null
              ? CachedNetworkImage(
                  imageUrl: widget.ad.imageUrl!,
                  fit: BoxFit.cover,
                  httpHeaders:
                      UrlHelper.shouldAttachAuthHeader(widget.ad.imageUrl!)
                          ? (_mediaHeaders ?? const {})
                          : null,
                  placeholder: (context, _) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, _, __) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
    );

    return ClipRect(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Solid black fill for the system nav bar zone — nothing renders here.
            if (widget.bottomInset > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: widget.bottomInset,
                child: const ColoredBox(color: Colors.black),
              ),

            // 1. Media — constrained to stop at bottomInset.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: widget.bottomInset,
              child: media,
            ),

            // Gradient Overlay (ignore pointers so it doesn't swallow taps).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: widget.bottomInset,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.0, 0.2, 0.8, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Tap-to-pause hint (shows when paused).
            if (_userPaused && widget.isActive)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: widget.bottomInset,
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: const Icon(
                        LucideIcons.play,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Progress Bar (ignore pointers so it doesn't swallow taps).
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.bottomInset,
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 4,
                    color: Colors.white.withValues(alpha: 0.22),
                    child: AnimatedBuilder(
                      animation: _watchProgressController,
                      builder: (context, _) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor:
                              _watchProgressController.value.clamp(0.0, 1.0),
                          child: Container(color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            if (widget.ad.coinReward > 0)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.coins,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '+${widget.ad.coinReward}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 3. Right Side Actions (always visible)
            Positioned(
              right: 8,
              bottom: actionsBottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildGlassAction(
                    icon: LucideIcons.eye,
                    label: _formatCount(widget.ad.currentViews),
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
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
                    label: '',
                    onTap: () {},
                    rotate: -0.2, // ~12 degrees
                  ),
                  const SizedBox(height: 16),
                  _buildGlassAction(
                    icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    label: '',
                    iconColor: Colors.white,
                    onTap: _toggleSaveAd,
                  ),
                  if (_isVideoAd) ...[
                    const SizedBox(height: 16),
                    _buildGlassAction(
                      icon:
                          _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                      label: '',
                      onTap: () {
                        setState(() {
                          _isMuted = !_isMuted;
                          unawaited(_safeSetVolume(_isMuted ? 0 : 1));
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            // 5. Bottom Info Overlay
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              left: 16,
              right: 80,
              bottom: infoBottom,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // User/Company Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          final uid = _adProfileId(widget.ad);
                          if (uid == null || uid.isEmpty) return;
                          Navigator.of(context).pushNamed('/profile/$uid');
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: _buildAdAvatarThumb(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: InkWell(
                                    onTap: () {
                                      final uid = _adProfileId(widget.ad);
                                      if (uid == null || uid.isEmpty) return;
                                      Navigator.of(context)
                                          .pushNamed('/profile/$uid');
                                    },
                                    child: Text(
                                      widget.ad.vendorBusinessName ??
                                          widget.ad.userName ??
                                          widget.ad.companyName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (widget.ad.totalBudgetCoins > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.amber.withValues(alpha: 0.2),
                                      border: Border.all(
                                          color: Colors.amber
                                              .withValues(alpha: 0.4)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(LucideIcons.coins,
                                            color: Colors.amber, size: 10),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatCount(
                                              widget.ad.totalBudgetCoins),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _isFollowing
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.1),
                                    border: Border.all(
                                        color: _isFollowing
                                            ? Colors.green
                                                .withValues(alpha: 0.45)
                                            : Colors.white
                                                .withValues(alpha: 0.4)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: GestureDetector(
                                    onTap:
                                        _isFollowLoading ? null : _toggleFollow,
                                    child: Text(
                                      _isFollowLoading
                                          ? '...'
                                          : (_isFollowing
                                              ? 'Following'
                                              : 'Follow'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sponsored',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!_ctaVisible)
                              Builder(builder: (context) {
                                final caption =
                                    (widget.ad.caption ?? widget.ad.description)
                                        .trim();
                                if (caption.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final words =
                                    caption.trim().split(RegExp(r'\s+'));
                                final isLong = words.length > 5;
                                final preview =
                                    isLong ? words.take(5).join(' ') : caption;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _captionExpanded || !isLong
                                              ? caption
                                              : preview,
                                        ),
                                        if (!_captionExpanded && isLong)
                                          WidgetSpan(
                                            alignment:
                                                PlaceholderAlignment.middle,
                                            child: GestureDetector(
                                              onTap: () => setState(
                                                () => _captionExpanded = true,
                                              ),
                                              child: const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 3),
                                                child: Text(
                                                  '... more',
                                                  style: TextStyle(
                                                    color: Color(0xCCFFFFFF),
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (_captionExpanded && isLong)
                                          WidgetSpan(
                                            alignment:
                                                PlaceholderAlignment.middle,
                                            child: GestureDetector(
                                              onTap: () => setState(
                                                () => _captionExpanded = false,
                                              ),
                                              child: const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 4),
                                                child: Text(
                                                  'less',
                                                  style: TextStyle(
                                                    color: Color(0xCCFFFFFF),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            if (!_ctaVisible &&
                                ((widget.ad.category ?? '').isNotEmpty ||
                                    widget.ad.targetCategories.isNotEmpty)) ...[
                              const SizedBox(height: 6),
                              Text(
                                widget.ad.targetCategories.isNotEmpty
                                    ? widget.ad.targetCategories.join(' • ')
                                    : (widget.ad.category ?? ''),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            if (!_ctaVisible &&
                                widget.ad.targetLanguages.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...widget.ad.targetLanguages.take(3).map(
                                        (lang) => _buildMetaPill(
                                          icon: Icons.language,
                                          label: lang,
                                        ),
                                      ),
                                  if (widget.ad.targetLanguages.length > 3)
                                    _buildMetaPill(
                                      label:
                                          '+${widget.ad.targetLanguages.length - 3}',
                                    ),
                                ],
                              ),
                            ],
                            if (!_ctaVisible &&
                                widget.ad.targetLocations.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ...widget.ad.targetLocations.take(2).map(
                                        (loc) => _buildMetaPill(
                                          icon: Icons.place,
                                          label: loc,
                                        ),
                                      ),
                                  if (widget.ad.targetLocations.length > 2)
                                    _buildMetaPill(
                                      label:
                                          '+${widget.ad.targetLocations.length - 2} more',
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // CTA buttons (full-width, end-to-end)
            Positioned(
              left: 16,
              right: 16,
              bottom: ctaBottom,
              child: IgnorePointer(
                ignoring: !_ctaVisible,
                child: AnimatedOpacity(
                  opacity: _ctaVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeInOutCubic,
                  child: _buildCtaButtons(),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: _likeRewardPopup == null,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      );
                    },
                    child: _likeRewardPopup == null
                        ? const SizedBox.shrink()
                        : _LikeRewardPopupCard(
                            key: ValueKey<int>(_likeRewardPopup!.id),
                            data: _likeRewardPopup!,
                            onOk: _hideLikeRewardPopup,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
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
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 0),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                      color: Colors.black45,
                      offset: Offset(0, 1),
                      blurRadius: 2),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaPill({IconData? icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdAvatarThumb() {
    final avatarUrl = widget.ad.userAvatarUrl ?? widget.ad.companyLogo;
    final name = (widget.ad.vendorBusinessName ??
            widget.ad.userName ??
            widget.ad.companyName)
        .trim();
    final ch = name.isEmpty ? 'A' : name[0].toUpperCase();

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white54, width: 1.4),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? Image.network(avatarUrl, fit: BoxFit.cover)
          : Container(
              color: const Color(0xFFF97316),
              alignment: Alignment.center,
              child: Text(
                ch,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
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

class _LikeRewardPopupData {
  final int id;
  final int amount;
  final bool isLike;

  const _LikeRewardPopupData({
    required this.id,
    required this.amount,
    required this.isLike,
  });
}

class _ViewRewardPopupData {
  final int id;
  final int amount;

  const _ViewRewardPopupData({
    required this.id,
    required this.amount,
  });
}

class _ViewRecordedPopupData {
  final int id;
  final int? viewCount;

  const _ViewRecordedPopupData({
    required this.id,
    required this.viewCount,
  });
}

class _LikeRewardPopupCard extends StatelessWidget {
  final _LikeRewardPopupData data;
  final VoidCallback onOk;

  const _LikeRewardPopupCard(
      {super.key, required this.data, required this.onOk});

  @override
  Widget build(BuildContext context) {
    final borderColor =
        data.isLike ? const Color(0xFFFCA5A5) : const Color(0xFFD1D5DB);
    final pillTextColor =
        data.isLike ? const Color(0xFFEF4444) : const Color(0xFF6B7280);
    final circleGradient = data.isLike
        ? const LinearGradient(
            colors: [Color(0xFFFB7185), Color(0xFFEC4899)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight)
        : const LinearGradient(
            colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);
    final buttonGradient = data.isLike
        ? const LinearGradient(
            colors: [Color(0xFFFB7185), Color(0xFFEC4899)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight)
        : const LinearGradient(
            colors: [Color(0xFF9CA3AF), Color(0xFF4B5563)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 30,
                  offset: Offset(0, 18)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, gradient: circleGradient),
                child: Icon(
                  data.isLike ? Icons.favorite : LucideIcons.circleX,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data.isLike ? '+${data.amount} Coins' : '-${data.amount} Coins',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: pillTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.isLike ? 'Thanks for liking!' : 'Dislike recorded',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: buttonGradient,
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 14,
                          offset: Offset(0, 10)),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onOk,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'Okay',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewRewardPopupCard extends StatelessWidget {
  final _ViewRewardPopupData data;
  final VoidCallback onOk;

  const _ViewRewardPopupCard({
    super.key,
    required this.data,
    required this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFFDE68A);
    const pillTextColor = Color(0xFFF59E0B);
    const circleGradient = LinearGradient(
      colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const buttonGradient = LinearGradient(
      colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 30,
                  offset: Offset(0, 18)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: circleGradient,
                ),
                child: const Icon(LucideIcons.coins,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 12),
              Text(
                '+${data.amount} Coins',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: pillTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Earned for watching the full ad',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: buttonGradient,
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 14,
                          offset: Offset(0, 10)),
                    ],
                  ),
                  child: TextButton(
                    onPressed: onOk,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Awesome!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewRecordedPopupCard extends StatelessWidget {
  final _ViewRecordedPopupData data;
  final VoidCallback onOk;

  const _ViewRecordedPopupCard({
    super.key,
    required this.data,
    required this.onOk,
  });

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E7EB);
    const circleGradient = LinearGradient(
      colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const buttonGradient = LinearGradient(
      colors: [Color(0xFF6B7280), Color(0xFF374151)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: borderColor),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 30,
                  offset: Offset(0, 18)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: circleGradient,
                ),
                child: const Icon(Icons.remove_red_eye,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(height: 12),
              const Text(
                'View Recorded',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (data.viewCount != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Total views: ${data.viewCount}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              const Text(
                'No coins rewarded for this view',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: buttonGradient,
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 14,
                          offset: Offset(0, 10)),
                    ],
                  ),
                  child: TextButton(
                    onPressed: onOk,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchUser {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  const _SearchUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
  });

  factory _SearchUser.fromMap(Map<String, dynamic> raw) {
    String pickString(dynamic value) {
      final v = value?.toString().trim();
      return v == null ? '' : v;
    }

    final id = pickString(raw['_id'] ?? raw['id'] ?? raw['user_id']);
    final username = pickString(raw['username']);
    final fullName = pickString(raw['full_name'] ?? raw['name']);
    final avatar =
        pickString(raw['avatar_url'] ?? raw['avatar'] ?? raw['photo']);

    return _SearchUser(
      id: id,
      username: username,
      fullName: fullName.isEmpty ? null : fullName,
      avatarUrl: avatar.isEmpty ? null : avatar,
    );
  }

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) return fullName!;
    if (username.trim().isNotEmpty) return username;
    return 'User';
  }

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return 'U';
    return name.substring(0, 1).toUpperCase();
  }
}

class _SearchAdThumb extends StatefulWidget {
  final Ad ad;
  final Map<String, String>? mediaHeaders;

  const _SearchAdThumb({
    required this.ad,
    required this.mediaHeaders,
  });

  @override
  State<_SearchAdThumb> createState() => _SearchAdThumbState();
}

class _SearchAdThumbState extends State<_SearchAdThumb> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _SearchAdThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.id != widget.ad.id ||
        oldWidget.ad.videoUrl != widget.ad.videoUrl) {
      _disposeController();
      _ready = false;
      _failed = false;
      _init();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      unawaited(c.dispose());
    }
  }

  VideoFormat? _videoFormatHintForUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return VideoFormat.hls;
    if (lower.contains('.mpd')) return VideoFormat.dash;
    return null;
  }

  Future<void> _init() async {
    final url = widget.ad.videoUrl?.trim() ?? '';
    if (url.isEmpty) return;
    try {
      final headers = UrlHelper.shouldAttachAuthHeader(url)
          ? (widget.mediaHeaders ?? const <String, String>{})
          : const <String, String>{};
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: headers,
        formatHint: _videoFormatHintForUrl(url),
      );
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) return;
      setState(() {
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = widget.ad.imageUrl?.trim();
    if (_ready && _controller != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      );
    }
    if (!_failed && thumbUrl != null && thumbUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: thumbUrl,
          httpHeaders: UrlHelper.shouldAttachAuthHeader(thumbUrl)
              ? (widget.mediaHeaders ?? const {})
              : null,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (context, _) => Container(
            color: Colors.white.withValues(alpha: 0.08),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, _, __) => Container(
            color: Colors.white.withValues(alpha: 0.08),
            alignment: Alignment.center,
            child: const Icon(Icons.image, color: Colors.white54, size: 16),
          ),
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.shopping_bag, color: Colors.white54, size: 18),
    );
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

class _MarqueeWidgetState extends State<MarqueeWidget>
    with SingleTickerProviderStateMixin {
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
          Text(widget.text,
              style: widget
                  .style), // Duplicate for smooth loop effect (simplified)
          const SizedBox(width: 30),
          Text(widget.text, style: widget.style),
        ],
      ),
    );
  }
}

class AdCommentsSheet extends StatefulWidget {
  final String adId;

  const AdCommentsSheet({super.key, required this.adId});

  @override
  State<AdCommentsSheet> createState() => _AdCommentsSheetState();
}

class _AdCommentsSheetState extends State<AdCommentsSheet> {
  final AdsService _adsService = AdsService();
  final AdsApi _adsApi = AdsApi();
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _comments = <Map<String, dynamic>>[];
  final Map<String, List<Map<String, dynamic>>> _repliesByComment =
      <String, List<Map<String, dynamic>>>{};
  final Set<String> _loadingReplies = <String>{};
  final Set<String> _expandedReplies = <String>{};
  bool _loading = true;
  bool _loadingAd = true;
  bool _posting = false;
  String? _replyParentId;
  String? _replyingTo;
  Ad? _ad;
  final Map<String, Map<String, dynamic>> _userCache =
      <String, Map<String, dynamic>>{};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    () async {
      final id = await CurrentUser.id;
      if (!mounted) return;
      setState(() {
        _currentUserId = id;
      });
    }();
    _loadAd();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _adsService.fetchAdComments(widget.adId);
      final hydrated = await _hydrateUsersInComments(list);
      if (!mounted) return;
      setState(() {
        _comments = hydrated;
      });
      await _autoLoadRepliesForComments(hydrated);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractUserId(Map<String, dynamic> c) {
    String? fromMap(dynamic value) {
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);
        final id =
            (m['_id'] ?? m['id'] ?? m['user_id'] ?? m['userId'])?.toString();
        if (id != null && id.trim().isNotEmpty) return id.trim();
      }
      return null;
    }

    final direct = (c['user_id'] ??
        c['userId'] ??
        c['uid'] ??
        c['author_id'] ??
        c['authorId']);
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();
    if (direct is num) return direct.toString();
    if (direct is Map) {
      final id = fromMap(direct);
      if (id != null) return id;
    }
    final user = c['user'] ??
        c['users'] ??
        c['author'] ??
        c['posted_by'] ??
        c['commented_by'];
    final id = fromMap(user);
    return id ?? '';
  }

  bool _hasName(Map<String, dynamic> u) {
    final v = (u['username'] ??
            u['userName'] ??
            u['user_name'] ??
            u['full_name'] ??
            u['fullName'] ??
            u['name'] ??
            u['business_name'] ??
            u['company_name'])
        ?.toString()
        .trim();
    return v != null && v.isNotEmpty;
  }

  Future<void> _primeUsers(Iterable<String> userIds) async {
    final missing = userIds
        .where((id) => id.isNotEmpty && !_userCache.containsKey(id))
        .toList();
    if (missing.isEmpty) return;

    final futures = <Future<void>>[];
    for (final id in missing) {
      futures.add(() async {
        try {
          final u = await _supabase.getUserById(id);
          if (u == null) return;
          _userCache[id] = Map<String, dynamic>.from(u);
        } catch (_) {}
      }());
    }
    await Future.wait(futures);
  }

  Future<List<Map<String, dynamic>>> _hydrateUsersInComments(
      List<Map<String, dynamic>> list) async {
    final ids = <String>{};
    for (final c in list) {
      final id = _extractUserId(c);
      if (id.isNotEmpty) ids.add(id);
    }
    await _primeUsers(ids);

    return list.map((c) {
      final next = Map<String, dynamic>.from(c);
      final uid = _extractUserId(next);
      if (uid.isEmpty) return next;
      final cached = _userCache[uid];
      if (cached == null) return next;
      final current = next['user'];
      if (current is Map) {
        final merged = Map<String, dynamic>.from(cached);
        merged.addAll(Map<String, dynamic>.from(current));
        next['user'] = merged;
      } else if (!_hasName(next['user'] is Map
          ? Map<String, dynamic>.from(next['user'] as Map)
          : <String, dynamic>{})) {
        next['user'] = cached;
      } else {
        next['user'] = cached;
      }
      return next;
    }).toList();
  }

  Future<void> _autoLoadRepliesForComments(
      List<Map<String, dynamic>> comments) async {
    final futures = <Future<void>>[];
    for (final comment in comments) {
      final commentId = _commentId(comment);
      if (commentId.isEmpty) continue;
      futures.add(() async {
        try {
          final replies = await _adsService.fetchAdCommentReplies(commentId);
          if (!mounted) return;
          final hydrated = await _hydrateUsersInComments(replies);
          if (!mounted) return;
          if (hydrated.isNotEmpty) {
            setState(() {
              _repliesByComment[commentId] = hydrated;
            });
          }
        } catch (_) {}
      }());
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _posting) return;
    final parentId = _replyParentId;

    setState(() => _posting = true);
    try {
      final created = await _adsService.addAdComment(
        adId: widget.adId,
        text: text,
        parentId: parentId,
      );
      if (!mounted) return;

      final comment = created['comment'] is Map
          ? Map<String, dynamic>.from(created['comment'] as Map)
          : created;
      setState(() {
        if (parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
            _repliesByComment[parentId] ?? const <Map<String, dynamic>>[],
          );
          list.insert(0, comment);
          _repliesByComment[parentId] = list;
          _expandedReplies.add(parentId);
        } else {
          _comments = [comment, ..._comments];
        }
        _controller.clear();
        _replyParentId = null;
        _replyingTo = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add comment: $e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  String _commentId(Map<String, dynamic> c) {
    return ((c['_id'] ?? c['id'])?.toString() ?? '').trim();
  }

  String _commentText(Map<String, dynamic> c) {
    return ((c['text'] ?? c['content'])?.toString() ?? '').trim();
  }

  String _commentAuthor(Map<String, dynamic> c) {
    Map<String, dynamic>? pick(dynamic value) {
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);
        final nested = m['user'];
        if (nested is Map) return Map<String, dynamic>.from(nested);
        return m;
      }
      return null;
    }

    final user = pick(c['user']) ??
        pick(c['user_id']) ??
        pick(c['userId']) ??
        pick(c['users']) ??
        pick(c['author']) ??
        pick(c['posted_by']) ??
        pick(c['commented_by']);

    if (user != null) {
      final username = (user['username'] ??
              user['full_name'] ??
              user['name'] ??
              user['business_name'] ??
              user['company_name'])
          ?.toString()
          .trim();
      if (username != null && username.isNotEmpty) return username;
    }

    final fallback = (c['username'] ??
            c['user_name'] ??
            c['userName'] ??
            c['author_name'] ??
            c['authorName'])
        ?.toString()
        .trim();
    return (fallback != null && fallback.isNotEmpty) ? fallback : 'user';
  }

  bool _isCommentLiked(Map<String, dynamic> c) {
    return (c['is_liked'] == true) ||
        (c['isLiked'] == true) ||
        (c['is_liked_by_me'] == true) ||
        (c['liked_by_me'] == true) ||
        (c['liked'] == true);
  }

  int _commentLikeCount(Map<String, dynamic> c) {
    final value = c['likes_count'] ?? c['likesCount'] ?? c['likes'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  bool _isCommentDisliked(Map<String, dynamic> c) {
    return (c['is_disliked'] == true) ||
        (c['isDisliked'] == true) ||
        (c['is_disliked_by_me'] == true) ||
        (c['disliked_by_me'] == true) ||
        (c['disliked'] == true);
  }

  int _commentDislikeCount(Map<String, dynamic> c) {
    final value = c['dislikes_count'] ?? c['dislikesCount'] ?? c['dislikes'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  int _commentReplyCount(Map<String, dynamic> c, String id) {
    final loaded =
        (_repliesByComment[id] ?? const <Map<String, dynamic>>[]).length;
    int parseCount(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final meta = [
      c['reply_count'],
      c['replies_count'],
      c['replyCount'],
      c['repliesCount'],
      c['total_replies'],
      c['totalReplies'],
      c['children_count'],
      c['childrenCount'],
    ].map(parseCount).fold<int>(
        0, (maxValue, current) => current > maxValue ? current : maxValue);
    return loaded > meta ? loaded : meta;
  }

  Future<void> _toggleCommentLike({
    required String commentId,
    required bool isReply,
    String? parentId,
  }) async {
    if (commentId.isEmpty) return;

    Map<String, dynamic>? target;
    int? targetIndex;
    if (isReply && parentId != null && parentId.isNotEmpty) {
      final list = _repliesByComment[parentId];
      if (list != null) {
        final idx = list.indexWhere((x) => _commentId(x) == commentId);
        if (idx >= 0) {
          target = Map<String, dynamic>.from(list[idx]);
          targetIndex = idx;
        }
      }
    } else {
      final idx = _comments.indexWhere((x) => _commentId(x) == commentId);
      if (idx >= 0) {
        target = Map<String, dynamic>.from(_comments[idx]);
        targetIndex = idx;
      }
    }
    if (target == null || targetIndex == null) return;
    final idx = targetIndex;

    final prevLiked = _isCommentLiked(target);
    final prevLikes = _commentLikeCount(target);
    final optimisticLiked = !prevLiked;
    final optimisticLikes =
        optimisticLiked ? prevLikes + 1 : (prevLikes > 0 ? prevLikes - 1 : 0);

    void applyLike(Map<String, dynamic> map, bool liked, int likes) {
      map['is_liked'] = liked;
      map['liked_by_me'] = liked;
      map['likes_count'] = likes;
    }

    setState(() {
      if (isReply && parentId != null && parentId.isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(
            _repliesByComment[parentId] ?? const []);
        final next = Map<String, dynamic>.from(list[idx]);
        applyLike(next, optimisticLiked, optimisticLikes);
        list[idx] = next;
        _repliesByComment[parentId] = list;
      } else {
        final next = Map<String, dynamic>.from(_comments[idx]);
        applyLike(next, optimisticLiked, optimisticLikes);
        _comments[idx] = next;
      }
    });

    try {
      final res = await _adsService.toggleAdCommentLike(commentId);
      final serverLiked = res['is_liked'];
      final serverLikes = res['likes_count'];
      if (!mounted) return;
      setState(() {
        final liked = serverLiked is bool ? serverLiked : optimisticLiked;
        final likes = serverLikes is int ? serverLikes : optimisticLikes;
        if (isReply && parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
              _repliesByComment[parentId] ?? const []);
          if (idx >= 0 && idx < list.length) {
            final next = Map<String, dynamic>.from(list[idx]);
            applyLike(next, liked, likes);
            list[idx] = next;
            _repliesByComment[parentId] = list;
          }
        } else if (idx >= 0 && idx < _comments.length) {
          final next = Map<String, dynamic>.from(_comments[idx]);
          applyLike(next, liked, likes);
          _comments[idx] = next;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isReply && parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
              _repliesByComment[parentId] ?? const []);
          if (idx >= 0 && idx < list.length) {
            final next = Map<String, dynamic>.from(list[idx]);
            applyLike(next, prevLiked, prevLikes);
            list[idx] = next;
            _repliesByComment[parentId] = list;
          }
        } else if (idx >= 0 && idx < _comments.length) {
          final next = Map<String, dynamic>.from(_comments[idx]);
          applyLike(next, prevLiked, prevLikes);
          _comments[idx] = next;
        }
      });
    }
  }

  Future<void> _toggleCommentDislike({
    required String commentId,
    required bool isReply,
    String? parentId,
  }) async {
    if (commentId.isEmpty) return;

    Map<String, dynamic>? target;
    int? targetIndex;
    if (isReply && parentId != null && parentId.isNotEmpty) {
      final list = _repliesByComment[parentId];
      if (list != null) {
        final idx = list.indexWhere((x) => _commentId(x) == commentId);
        if (idx >= 0) {
          target = Map<String, dynamic>.from(list[idx]);
          targetIndex = idx;
        }
      }
    } else {
      final idx = _comments.indexWhere((x) => _commentId(x) == commentId);
      if (idx >= 0) {
        target = Map<String, dynamic>.from(_comments[idx]);
        targetIndex = idx;
      }
    }
    if (target == null || targetIndex == null) return;
    final idx = targetIndex;

    final prevDisliked = _isCommentDisliked(target);
    final prevDislikes = _commentDislikeCount(target);
    final optimisticDisliked = !prevDisliked;
    final optimisticDislikes = optimisticDisliked
        ? prevDislikes + 1
        : (prevDislikes > 0 ? prevDislikes - 1 : 0);

    void applyDislike(Map<String, dynamic> map, bool disliked, int dislikes) {
      map['is_disliked'] = disliked;
      map['disliked_by_me'] = disliked;
      map['dislikes_count'] = dislikes;
    }

    setState(() {
      if (isReply && parentId != null && parentId.isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(
            _repliesByComment[parentId] ?? const []);
        final next = Map<String, dynamic>.from(list[idx]);
        applyDislike(next, optimisticDisliked, optimisticDislikes);
        list[idx] = next;
        _repliesByComment[parentId] = list;
      } else {
        final next = Map<String, dynamic>.from(_comments[idx]);
        applyDislike(next, optimisticDisliked, optimisticDislikes);
        _comments[idx] = next;
      }
    });

    try {
      final res = await _adsService.toggleAdCommentDislike(commentId);
      final serverDisliked = res['is_disliked'];
      final serverDislikes = res['dislikes_count'];
      if (!mounted) return;
      setState(() {
        final disliked =
            serverDisliked is bool ? serverDisliked : optimisticDisliked;
        final dislikes =
            serverDislikes is int ? serverDislikes : optimisticDislikes;
        if (isReply && parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
              _repliesByComment[parentId] ?? const []);
          if (idx >= 0 && idx < list.length) {
            final next = Map<String, dynamic>.from(list[idx]);
            applyDislike(next, disliked, dislikes);
            list[idx] = next;
            _repliesByComment[parentId] = list;
          }
        } else if (idx >= 0 && idx < _comments.length) {
          final next = Map<String, dynamic>.from(_comments[idx]);
          applyDislike(next, disliked, dislikes);
          _comments[idx] = next;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isReply && parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
              _repliesByComment[parentId] ?? const []);
          if (idx >= 0 && idx < list.length) {
            final next = Map<String, dynamic>.from(list[idx]);
            applyDislike(next, prevDisliked, prevDislikes);
            list[idx] = next;
            _repliesByComment[parentId] = list;
          }
        } else if (idx >= 0 && idx < _comments.length) {
          final next = Map<String, dynamic>.from(_comments[idx]);
          applyDislike(next, prevDisliked, prevDislikes);
          _comments[idx] = next;
        }
      });
    }
  }

  Future<void> _toggleReplies(String commentId) async {
    if (commentId.isEmpty) return;

    if (_expandedReplies.contains(commentId)) {
      setState(() {
        _expandedReplies.remove(commentId);
      });
      return;
    }

    if (_repliesByComment.containsKey(commentId)) {
      setState(() {
        _expandedReplies.add(commentId);
      });
      return;
    }

    setState(() {
      _loadingReplies.add(commentId);
    });
    try {
      final replies = await _adsService.fetchAdCommentReplies(commentId);
      if (!mounted) return;
      setState(() {
        _repliesByComment[commentId] = replies;
        _expandedReplies.add(commentId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load replies: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingReplies.remove(commentId);
        });
      }
    }
  }

  Future<void> _deleteComment({
    required String commentId,
    required bool isReply,
    String? parentId,
  }) async {
    if (commentId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _adsService.deleteAdComment(commentId);
      if (!mounted) return;
      setState(() {
        if (isReply && parentId != null && parentId.isNotEmpty) {
          final list = List<Map<String, dynamic>>.from(
            _repliesByComment[parentId] ?? const <Map<String, dynamic>>[],
          );
          list.removeWhere((r) => _commentId(r) == commentId);
          _repliesByComment[parentId] = list;
        } else {
          _comments.removeWhere((c) => _commentId(c) == commentId);
          _repliesByComment.remove(commentId);
          _expandedReplies.remove(commentId);
          _loadingReplies.remove(commentId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete comment: $e')),
      );
    }
  }

  Future<void> _loadAd() async {
    setState(() => _loadingAd = true);
    try {
      final raw = await _adsApi.getAdById(widget.adId);
      if (!mounted) return;
      setState(() {
        _ad = raw == null ? null : Ad.fromApi(raw);
        _loadingAd = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ad = null;
        _loadingAd = false;
      });
    }
  }

  void _openAdVendorProfile(Ad ad) {
    final uid = _adProfileId(ad);
    if (uid == null || uid.isEmpty) return;
    Navigator.of(context).pushNamed('/profile/$uid');
  }

  String _fmtCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _commentCreatedAt(Map<String, dynamic> c) {
    return ((c['created_at'] ?? c['createdAt'] ?? c['created'] ?? '')
                ?.toString() ??
            '')
        .trim();
  }

  Map<String, dynamic> _commentUser(Map<String, dynamic> c) {
    Map<String, dynamic>? pick(dynamic value) {
      if (value is Map) {
        final m = Map<String, dynamic>.from(value);
        final nested = m['user'];
        if (nested is Map) return Map<String, dynamic>.from(nested);
        return m;
      }
      return null;
    }

    return pick(c['user']) ??
        pick(c['user_id']) ??
        pick(c['userId']) ??
        pick(c['users']) ??
        pick(c['author']) ??
        pick(c['posted_by']) ??
        pick(c['commented_by']) ??
        <String, dynamic>{};
  }

  String _commentAvatarUrl(Map<String, dynamic> c) {
    final u = _commentUser(c);
    return (u['avatar_url'] ??
            u['avatarUrl'] ??
            u['avatar'] ??
            u['profile_image'] ??
            u['profileImage'] ??
            c['avatar_url'] ??
            '')
        .toString()
        .trim();
  }

  bool _commentVerified(Map<String, dynamic> c) {
    final u = _commentUser(c);
    return u['is_verified'] == true || u['verified'] == true;
  }

  Widget _avatar(String url, String fallbackChar, {double size = 16}) {
    final ring = url.trim().isNotEmpty;
    return Container(
      width: size * 2.25,
      height: size * 2.25,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ring
            ? const LinearGradient(
                colors: [
                  Color(0xFFFACC15),
                  Color(0xFFF97316),
                  Color(0xFFEC4899)
                ],
              )
            : null,
        color: ring ? null : Colors.grey.shade300,
      ),
      child: Container(
        decoration:
            const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        padding: const EdgeInsets.all(1),
        child: CircleAvatar(
          backgroundImage: ring ? NetworkImage(url) : null,
          backgroundColor: Colors.grey.shade200,
          child: ring
              ? null
              : Text(
                  fallbackChar,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }

  Widget _buildAdContextCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();

    final border = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final surface =
        isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF7F7FA);
    final muted = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.55);

    final headline = (ad.caption?.trim().isNotEmpty ?? false)
        ? ad.caption!.trim()
        : ad.title;
    final name = (ad.vendorBusinessName?.trim().isNotEmpty ?? false)
        ? ad.vendorBusinessName!.trim()
        : ((ad.userName?.trim().isNotEmpty ?? false)
            ? ad.userName!.trim()
            : ad.companyName);
    final avatarUrl = (ad.userAvatarUrl?.trim().isNotEmpty ?? false)
        ? ad.userAvatarUrl!.trim()
        : (ad.companyLogo ?? '');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: (ad.userId?.trim().isNotEmpty ?? false)
                    ? () => _openAdVendorProfile(ad)
                    : null,
                borderRadius: BorderRadius.circular(999),
                child: _avatar(
                  avatarUrl,
                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: (ad.userId?.trim().isNotEmpty ?? false)
                                ? () => _openAdVendorProfile(ad)
                                : null,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(ad.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    Text(
                      'Sponsored',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (headline.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(headline, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (ad.category != null && ad.category!.trim().isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1A3B82F6),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x333B82F6)),
                  ),
                  child: Text(
                    ad.category!.trim(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB)),
                  ),
                ),
              if (ad.totalBudgetCoins > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0x1AF59E0B),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x33F59E0B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.coins,
                          size: 14, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        '${_fmtCount(ad.totalBudgetCoins)} coins budget',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD97706)),
                      ),
                    ],
                  ),
                ),
              if (ad.currentViews > 0)
                Text('${_fmtCount(ad.currentViews)} views',
                    style: TextStyle(
                        fontSize: 12,
                        color: muted,
                        fontWeight: FontWeight.w600)),
            ],
          ),
          if (ad.targetLocations.isNotEmpty ||
              ad.targetLanguages.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (ad.targetLocations.isNotEmpty)
              Text(
                '📍 ${ad.targetLocations.join(', ')}',
                style: TextStyle(
                    fontSize: 12, color: muted, fontWeight: FontWeight.w600),
              ),
            if (ad.targetLanguages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '🌐 ${ad.targetLanguages.join(', ')}',
                  style: TextStyle(
                      fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _commentTile({
    required Map<String, dynamic> c,
    required bool isReply,
    String? parentId,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final id = _commentId(c);
    final author = _commentAuthor(c);
    final avatarUrl = _commentAvatarUrl(c);
    final isVerified = _commentVerified(c);
    final text = _commentText(c);
    final created = _commentCreatedAt(c);
    final likeCount = _commentLikeCount(c);
    final liked = _isCommentLiked(c);
    final ownerId = _extractUserId(c);
    final isOwner = _currentUserId != null &&
        ownerId.isNotEmpty &&
        ownerId.toString() == _currentUserId.toString();

    DateTime? dt;
    if (created.isNotEmpty) {
      dt = DateTime.tryParse(created);
    }
    final timeLabel = dt == null ? '' : _formatTimestamp(dt);

    final surface = isDark ? Colors.transparent : Colors.transparent;

    final nameStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: isReply ? 12 : 13,
      color: theme.colorScheme.onSurface,
    );
    final textStyle = TextStyle(
      fontSize: isReply ? 12 : 13,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
      height: 1.2,
    );

    return Container(
      color: surface,
      padding: EdgeInsets.symmetric(vertical: isReply ? 8 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(
            avatarUrl,
            author.isNotEmpty ? author[0].toUpperCase() : 'U',
            size: isReply ? 12 : 14,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: textStyle,
                    children: [
                      TextSpan(text: author, style: nameStyle),
                      if (isVerified)
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(left: 4, right: 4),
                            child: Icon(Icons.check_circle,
                                size: 13, color: Colors.blueAccent),
                          ),
                        )
                      else
                        const TextSpan(text: '  '),
                      TextSpan(text: text.isEmpty ? '-' : text),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (timeLabel.isNotEmpty)
                      Text(
                        timeLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    if (likeCount > 0) ...[
                      const SizedBox(width: 10),
                      Text(
                        '$likeCount likes',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: id.isEmpty
                          ? null
                          : () {
                              setState(() {
                                _replyParentId = isReply ? parentId : id;
                                _replyingTo = author;
                              });
                              _focusNode.requestFocus();
                            },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Reply',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (isOwner && id.isNotEmpty) ...[
                      const Spacer(),
                      IconButton(
                        icon: Icon(LucideIcons.trash2,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () => _deleteComment(
                          commentId: id,
                          isReply: isReply,
                          parentId: parentId,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (id.isNotEmpty)
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      liked ? Icons.favorite : LucideIcons.heart,
                      size: isReply ? 14 : 16,
                      color: liked
                          ? Colors.red
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => _toggleCommentLike(
                      commentId: id,
                      isReply: isReply,
                      parentId: parentId,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (likeCount > 0)
                    Text(
                      '$likeCount',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: liked
                            ? Colors.red
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final handleColor = isDark
        ? Colors.white.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.18);
    final showAdContext = !_loadingAd && _ad != null;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          color: bg,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Comments (${_comments.length})',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(LucideIcons.x,
                          color: theme.iconTheme.color, size: 20),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        itemCount: (showAdContext ? 1 : 0) +
                            (_comments.isEmpty ? 1 : _comments.length),
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: theme.dividerColor.withValues(alpha: 0.35)),
                        itemBuilder: (context, index) {
                          if (showAdContext && index == 0) {
                            return _buildAdContextCard();
                          }
                          if (_comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'No comments yet.\nBe the first to comment.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                ),
                              ),
                            );
                          }
                          final commentIndex = index - (showAdContext ? 1 : 0);
                          final c = _comments[commentIndex];
                          final id = _commentId(c);
                          final replyCount = _commentReplyCount(c, id);
                          final showReplies = _expandedReplies.contains(id);
                          final isLoadingReplies = _loadingReplies.contains(id);
                          final replies = _repliesByComment[id] ??
                              const <Map<String, dynamic>>[];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _commentTile(c: c, isReply: false),
                              if (id.isNotEmpty && replyCount > 0)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 6, top: 6),
                                  child: TextButton(
                                    onPressed: isLoadingReplies
                                        ? null
                                        : () => _toggleReplies(id),
                                    child: Text(
                                      isLoadingReplies
                                          ? 'Loading replies...'
                                          : (showReplies
                                              ? 'Hide replies'
                                              : 'View replies ($replyCount)'),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              if (showReplies)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 18, top: 6),
                                  child: replies.isEmpty
                                      ? Text('No replies',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant))
                                      : Column(
                                          children: [
                                            for (final r in replies) ...[
                                              _commentTile(
                                                  c: r,
                                                  isReply: true,
                                                  parentId: id),
                                              if (r != replies.last)
                                                Divider(
                                                  height: 1,
                                                  color: theme.dividerColor
                                                      .withValues(alpha: 0.25),
                                                ),
                                            ],
                                          ],
                                        ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              if (_replyingTo != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.grey.withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Replying to $_replyingTo',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setState(() {
                            _replyParentId = null;
                            _replyingTo = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: _replyingTo != null
                              ? 'Reply to @$_replyingTo...'
                              : 'Add a comment...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: (_posting || _controller.text.trim().isEmpty)
                          ? null
                          : _submit,
                      child: _posting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Post',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF3B82F6)),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
