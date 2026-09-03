import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'store_models.dart';
import 'store_theme.dart';
import 'tabs/store_account_tab.dart';
import 'tabs/store_cart_tab.dart';
import 'tabs/store_categories_tab.dart';
import 'tabs/store_home_tab.dart';
import 'tabs/store_my_store_tab.dart';

class StoreHomeScreen extends StatefulWidget {
  final bool isSelfStore;
  final String? ownerUserId;

  const StoreHomeScreen({
    super.key,
    this.isSelfStore = true,
    this.ownerUserId,
  });

  static StoreHomeScreen fromRouteArgs(Object? args) {
    if (args is StoreHomeScreenArgs) {
      return StoreHomeScreen(
        isSelfStore: args.isSelfStore,
        ownerUserId: args.ownerUserId,
      );
    }
    if (args is Map) {
      final rawIsSelf = args['isSelfStore'];
      return StoreHomeScreen(
        isSelfStore: rawIsSelf is bool ? rawIsSelf : true,
        ownerUserId: args['ownerUserId']?.toString(),
      );
    }
    return const StoreHomeScreen();
  }

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class StoreHomeScreenArgs {
  final bool isSelfStore;
  final String? ownerUserId;

  const StoreHomeScreenArgs({
    this.isSelfStore = true,
    this.ownerUserId,
  });
}

enum _StoreNavSection {
  home,
  categories,
  myStore,
  account,
  cart,
}

class _StoreNavItem {
  final IconData icon;
  final String label;
  final _StoreNavSection section;

  const _StoreNavItem(this.icon, this.label, this.section);
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  int _selectedNav = 0;
  int _selectedCategory = 0;
  int _refreshTick = 0;
  String _deliveryAddress = 'HOME  Select delivery address';
  final _searchController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _speech = SpeechToText();
  bool _speechAvailable = false;

  final _categories = const [
    StoreCategory('For You', Icons.shopping_bag_outlined),
    StoreCategory('Fashion', Icons.checkroom_outlined),
    StoreCategory('Mobiles', Icons.phone_android_outlined),
    StoreCategory('Electronics', Icons.laptop_outlined),
    StoreCategory('Beauty', Icons.brush_outlined),
    StoreCategory('Home', Icons.chair_outlined),
  ];

  final _products = const [
    StoreProduct('Everyday essentials', 'Fresh picks for your day',
        Color(0xFFFFD9E8), 'assets/bSmart_Store/mockimages/vegetables.jpg'),
    StoreProduct('Tech & accessories', 'Smart finds, better value',
        Color(0xFFD8EEFF), 'assets/bSmart_Store/mockimages/electronics.jpg'),
    StoreProduct('Style refresh', 'Looks you will love', Color(0xFFE9DFFF),
        'assets/bSmart_Store/mockimages/clothes.jpg'),
  ];

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_speechAvailable) {
      _speech.stop();
    }
    super.dispose();
  }

  Future<void> _initializeSpeech() async {
    try {
      final available = await _speech.initialize();
      if (mounted) setState(() => _speechAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  Future<void> _openCamera() async {
    try {
      await _imagePicker.pickImage(source: ImageSource.camera);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera is not available.')),
      );
    }
  }

  Future<void> _toggleSpeech() async {
    if (!_speechAvailable) {
      await _initializeSpeech();
    }
    if (!_speechAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not available.')),
      );
      return;
    }
    if (_speech.isListening) {
      await _speech.stop();
    } else {
      await _speech.listen(onResult: _onSpeechResult);
    }
    if (mounted) setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _searchController.value = _searchController.value.copyWith(
      text: result.recognizedWords,
      selection: TextSelection.collapsed(offset: result.recognizedWords.length),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openQrScanner() async {
    final result = await Navigator.of(context).pushNamed('/store/scan');
    if (result is String && result.isNotEmpty && mounted) {
      _searchController.text = result;
    }
  }

  Future<void> _openSearchPage() async {
    final result = await Navigator.of(context).pushNamed(
      '/store/search',
      arguments: _searchController.text,
    );
    if (result is String && result.isNotEmpty && mounted) {
      _searchController.text = result;
    }
  }

  void _showAddressSheet() {
    showStoreAddressSheet(
      context,
      onUseCurrentLocation: _useCurrentLocation,
    );
  }

  Future<bool> _useCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required.')),
        );
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return false;

      final address = _formatPlacemark(placemarks);
      setState(() {
        _deliveryAddress = address == null
            ? 'HOME  ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}'
            : 'HOME  $address';
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to fetch current location.')),
      );
      return false;
    }
  }

  String? _formatPlacemark(List<Placemark> placemarks) {
    if (placemarks.isEmpty) return null;
    final p = placemarks.first;
    final parts = [
      p.name,
      p.subLocality,
      p.locality,
      p.administrativeArea,
      p.postalCode,
    ];
    final text = parts
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet()
        .join(', ');
    return text.isEmpty ? null : text;
  }

  Future<void> _refreshStorePage() async {
    if (_speechAvailable && _speech.isListening) {
      await _speech.stop();
    }
    if (!mounted) return;
    setState(() => _refreshTick++);
    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _navItems;
    final selectedSection = navItems[_selectedNav].section;
    final slivers = switch (selectedSection) {
      _StoreNavSection.categories => [
          SliverFillRemaining(
            child: StoreCategoriesTab(
              key: ValueKey('categories-$_refreshTick'),
              onOpenSearch: _openSearchPage,
              onOpenCamera: _openCamera,
            ),
          ),
        ],
      _StoreNavSection.myStore => [
          SliverToBoxAdapter(
            child: StoreMyStoreTab(key: ValueKey('my-store-$_refreshTick')),
          ),
        ],
      _StoreNavSection.account => [
          SliverToBoxAdapter(
            child: StoreAccountTab(key: ValueKey('account-$_refreshTick')),
          ),
        ],
      _StoreNavSection.cart => [
          SliverToBoxAdapter(
            child: StoreCartTab(key: ValueKey('cart-$_refreshTick')),
          ),
        ],
      _StoreNavSection.home => StoreHomeTab(
          key: ValueKey('home-$_refreshTick-$_selectedNav'),
          searchController: _searchController,
          categories: _categories,
          products: _products,
          selectedCategory: _selectedCategory,
          deliveryAddress: _deliveryAddress,
          speechListening: _speech.isListening,
          onCategorySelected: (index) =>
              setState(() => _selectedCategory = index),
          onOpenAddressSheet: _showAddressSheet,
          onOpenSearch: _openSearchPage,
          onOpenCamera: _openCamera,
          onToggleSpeech: _toggleSpeech,
          onOpenQrScanner: _openQrScanner,
          onOpenMainApp: () => Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          ),
        ).buildSlivers(context),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator.adaptive(
                color: StorePalette.blue,
                onRefresh: _refreshStorePage,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.vertical,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: slivers,
                ),
              ),
            ),
            _buildBottomNav(navItems),
          ],
        ),
      ),
    );
  }

  List<_StoreNavItem> get _navItems {
    if (widget.isSelfStore) {
      return const [
        _StoreNavItem(Icons.home_rounded, 'Home', _StoreNavSection.home),
        _StoreNavItem(
            Icons.grid_view_rounded, 'Categories', _StoreNavSection.categories),
        _StoreNavItem(
            Icons.storefront_outlined, 'My Store', _StoreNavSection.myStore),
        _StoreNavItem(
            Icons.person_outline_rounded, 'Account', _StoreNavSection.account),
      ];
    }
    return const [
      _StoreNavItem(Icons.home_rounded, 'Home', _StoreNavSection.home),
      _StoreNavItem(
          Icons.grid_view_rounded, 'Categories', _StoreNavSection.categories),
      _StoreNavItem(
          Icons.person_outline_rounded, 'Account', _StoreNavSection.account),
      _StoreNavItem(
          Icons.shopping_cart_outlined, 'Cart', _StoreNavSection.cart),
    ];
  }

  Widget _buildBottomNav(List<_StoreNavItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
        ),
      ),
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: i == _selectedNav
                      ? null
                      : () => setState(() => _selectedNav = i),
                  child: SizedBox(
                    height: 52,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[i].icon,
                          color: i == _selectedNav
                              ? StorePalette.blue
                              : Colors.black54,
                          size: 23,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: i == _selectedNav
                                ? StorePalette.blue
                                : Colors.black87,
                            fontSize: 10,
                            fontWeight: i == _selectedNav
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
