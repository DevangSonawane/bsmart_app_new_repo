import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'store_models.dart';
import 'store_theme.dart';
import 'tabs/store_account_tab.dart';
import 'tabs/store_categories_tab.dart';
import 'tabs/store_home_tab.dart';

class StoreHomeScreen extends StatefulWidget {
  const StoreHomeScreen({super.key});

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  int _selectedCategory = 0;
  int _selectedNav = 0;
  int _refreshTick = 0;
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
    final slivers = switch (_selectedNav) {
      2 => [
          SliverFillRemaining(
            child: StoreCategoriesTab(
              key: ValueKey('categories-$_refreshTick'),
              onOpenSearch: _openSearchPage,
              onOpenCamera: _openCamera,
            ),
          ),
        ],
      3 => [
          SliverToBoxAdapter(
            child: StoreAccountTab(key: ValueKey('account-$_refreshTick')),
          ),
        ],
      _ => StoreHomeTab(
          key: ValueKey('home-$_refreshTick-$_selectedNav'),
          searchController: _searchController,
          categories: _categories,
          products: _products,
          selectedCategory: _selectedCategory,
          speechListening: _speech.isListening,
          onCategorySelected: (index) =>
              setState(() => _selectedCategory = index),
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
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, 'Home'),
      (Icons.play_circle_outline_rounded, 'Play'),
      (Icons.grid_view_rounded, 'Categories'),
      (Icons.person_outline_rounded, 'Account'),
      (Icons.shopping_cart_outlined, 'Cart'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.10)),
        ),
      ),
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              onTap: () => setState(() => _selectedNav = i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    items[i].$1,
                    color:
                        i == _selectedNav ? StorePalette.blue : Colors.black54,
                    size: 23,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].$2,
                    style: TextStyle(
                      color: i == _selectedNav
                          ? StorePalette.blue
                          : Colors.black87,
                      fontSize: 10,
                      fontWeight:
                          i == _selectedNav ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
