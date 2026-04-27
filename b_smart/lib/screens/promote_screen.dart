import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/design_tokens.dart';
import '../services/promote_service.dart';
import 'package:b_smart/widgets/glass_action_button.dart';

class PromoteScreen extends StatefulWidget {
  const PromoteScreen({super.key});

  @override
  State<PromoteScreen> createState() => _PromoteScreenState();
}

class _PromoteScreenState extends State<PromoteScreen> {
  final PageController _pageController = PageController();
  final PromoteService _promoteService = PromoteService();
  int _currentIndex = 0;
  bool _isMuted = true;
  bool _loading = true;
  List<Map<String, dynamic>> _promotes = [];
  final Map<int, VideoPlayerController> _controllers = {};
  double _cachedBottomInset = 0;

  @override
  void initState() {
    super.initState();
    _loadPromotes();
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
  }

  Future<void> _loadPromotes() async {
    final list = await _promoteService.fetchPromotes();
    if (mounted) {
      setState(() {
        _promotes = list;
        _loading = false;
      });
      if (_promotes.isNotEmpty) _initControllerForIndex(0);
    }
  }

  Future<void> _initControllerForIndex(int index) async {
    if (index < 0 || index >= _promotes.length) return;
    if (_controllers.containsKey(index)) return;
    final url = _promotes[index]['videoUrl'] as String?;
    if (url == null || url.isEmpty) return;
    final controller = VideoPlayerController.network(url);
    _controllers[index] = controller;
    await controller.initialize();
    controller.setLooping(true);
    if (mounted && _currentIndex == index) controller.play();
    setState(() {});
  }

  void _disposeFarControllers(int keepIndex) {
    final keys = List<int>.from(_controllers.keys);
    for (final k in keys) {
      if ((k - keepIndex).abs() > 1) {
        try {
          _controllers[k]?.pause();
          _controllers[k]?.dispose();
        } catch (_) {}
        _controllers.remove(k);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      try {
        c.pause();
        c.dispose();
      } catch (_) {}
    }
    _controllers.clear();
    super.dispose();
  }

  void _onPageChanged(int idx) {
    setState(() {
      _currentIndex = idx;
    });
    _initControllerForIndex(idx);
    _disposeFarControllers(idx);
    final c = _controllers[idx];
    if (c != null) {
      if (c.value.isInitialized) {
        if (!_isMuted) c.setVolume(1.0);
        c.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final view = View.of(context);
    final viewPaddingBottom = view.padding.bottom / view.devicePixelRatio;
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
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: DesignTokens.instaPink)),
      );
    }
    if (_promotes.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Text('No promoted content yet.',
                style: TextStyle(color: Colors.grey.shade400))),
      );
    }
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.black,
      body: ClipRect(
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPageChanged,
          itemCount: _promotes.length,
          itemBuilder: (context, index) {
            final item = _promotes[index];
            final products = (item['products'] as List<dynamic>?) ?? [];
            final controller = _controllers[index];
            final actionsBottom = 96.0 + bottomSystemInset;
            return Stack(
              fit: StackFit.expand,
              children: [
                // 0. Solid black for nav bar zone
                if (bottomSystemInset > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: bottomSystemInset,
                    child: const ColoredBox(color: Colors.black),
                  ),
                // Video
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: bottomSystemInset,
                  child: controller != null && controller.value.isInitialized
                      ? FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        )
                      : Container(
                          color: Colors.black,
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white54))),
                ),
                // Gradient overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: bottomSystemInset,
                  child: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                  ),
                ),
                // Right side actions (aligned with Ads layout)
                Positioned(
                  right: 4,
                  bottom: actionsBottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlassActionButton(
                        icon: LucideIcons.heart,
                        label: (item['likes'] as String?) ?? '0',
                        onTap: () {},
                      ),
                      const SizedBox(height: 16),
                      GlassActionButton(
                        icon: LucideIcons.messageCircle,
                        label: (item['comments'] as String?) ?? '0',
                        onTap: () {},
                      ),
                      const SizedBox(height: 16),
                      GlassActionButton(
                        icon: LucideIcons.send,
                        label: '',
                        rotate: -0.2,
                        onTap: () {},
                      ),
                      const SizedBox(height: 16),
                      GlassActionButton(
                        icon: LucideIcons.ellipsis,
                        label: '',
                        onTap: () {},
                      ),
                      const SizedBox(height: 16),
                      GlassActionButton(
                        icon:
                            _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                        label: '',
                        onTap: () {
                          setState(() {
                            _isMuted = !_isMuted;
                            final c = _controllers[_currentIndex];
                            if (c != null) c.setVolume(_isMuted ? 0.0 : 1.0);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                // Bottom: brand + username (aligned with mute icon)
                Positioned(
                  left: 16,
                  right: 92,
                  bottom: actionsBottom,
                  child: _PromoteUsernamePill(item: item),
                ),
                if (products.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: bottomSystemInset + 6,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragStart: (_) {},
                      onVerticalDragUpdate: (_) {},
                      child: SizedBox(
                        height: 82,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: products.length.clamp(0, 8),
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, i) {
                            final p = products[i] is Map
                                ? Map<String, dynamic>.from(products[i] as Map)
                                : <String, dynamic>{};
                            return _MiniProductCard(product: p);
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showFeaturedProductsSheet(
      BuildContext context, List<dynamic> products) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text('Featured Products',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final prod = products[i] as Map<String, dynamic>;
                  return Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CachedNetworkImage(
                            imageUrl: (prod['image'] as String?) ?? '',
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                                child: Icon(LucideIcons.image,
                                    color: Colors.white54)),
                            errorWidget: (_, __, ___) => const Center(
                                child: Icon(LucideIcons.imageOff,
                                    color: Colors.white54)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            (prod['title'] as String?) ?? 'Product',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).then((_) => setState(() {}));
  }
}

class _PromoteUsernamePill extends StatelessWidget {
  final Map<String, dynamic> item;
  const _PromoteUsernamePill({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.00),
            Colors.black.withValues(alpha: 0.35),
            Colors.black.withValues(alpha: 0.65),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: DesignTokens.instaPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              ((item['brandName'] as String?) ?? 'G')[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              (item['username'] as String?) ??
                  (item['brandName'] as String?) ??
                  '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _MiniProductCard({required this.product});

  int _seed() {
    final id = product['id'];
    if (id is int) return id;
    return (product['title']?.toString() ?? '').hashCode.abs();
  }

  @override
  Widget build(BuildContext context) {
    final seed = _seed();
    final title = (product['title'] as String?)?.trim().isNotEmpty == true
        ? (product['title'] as String).trim()
        : 'Product';
    final imageUrl = (product['image'] as String?)?.trim() ?? '';

    final price = (product['price'] as num?)?.toInt() ?? (599 + (seed % 400));
    final mrp = (product['mrp'] as num?)?.toInt() ?? (price + 900 + seed % 600);
    final off = mrp > 0 ? (((mrp - price) * 100) / mrp).round() : 0;
    final rating =
        (product['rating'] as num?)?.toDouble() ?? (4.0 + (seed % 3) * 0.1);

    return Container(
      width: 260,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const ColoredBox(
                      color: Color(0xFFF1F5F9),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFF1F5F9),
                      child: Center(child: Icon(LucideIcons.imageOff, size: 18)),
                    ),
                  )
                else
                  const ColoredBox(
                    color: Color(0xFFF1F5F9),
                    child: Center(child: Icon(LucideIcons.image, size: 18)),
                  ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          LucideIcons.star,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹$price',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '₹$mrp',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.45),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${off.clamp(0, 99)}% off',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
