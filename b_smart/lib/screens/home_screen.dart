import 'package:flutter/material.dart';
import '../services/feed_service.dart';
import '../widgets/post_card.dart';
import '../utils/current_user.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FeedService _feedService = FeedService();
  final List posts = [];
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];
  int _activeIndex = 0;
  int _page = 0;
  final int _limit = 10;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    final currentUserId = await CurrentUser.id;
    final items = await _feedService.fetchFeedFromBackend(
      limit: _limit,
      offset: _page * _limit,
      currentUserId: currentUserId,
    );
    setState(() {
      posts.addAll(items);
      // Ensure keys for new items
      while (_itemKeys.length < posts.length) {
        _itemKeys.add(GlobalKey());
      }
      _page += 1;
      if (items.length < _limit) _hasMore = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateActiveIndex());
  }

  Future<void> _refresh() async {
    setState(() {
      posts.clear();
      _page = 0;
      _hasMore = true;
      _activeIndex = 0;
      _itemKeys.clear();
    });
    await _loadMore();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _updateActiveIndex();
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _updateActiveIndex() {
    if (!mounted) return;
    final centerY = MediaQuery.of(context).size.height / 2;
    double bestDist = double.infinity;
    int bestIndex = _activeIndex;

    for (int i = 0; i < posts.length; i++) {
      if (i >= _itemKeys.length) break;
      final ctx = _itemKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final pos = box.localToGlobal(Offset.zero);
      final size = box.size;
      final itemCenter = pos.dy + size.height / 2;
      final dist = (itemCenter - centerY).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestIndex = i;
      }
    }

    if (bestIndex != _activeIndex) {
      setState(() => _activeIndex = bestIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          cacheExtent: 800,
          controller: _scrollController,
          itemCount: posts.length + 1,
          itemBuilder: (context, index) {
            if (index < posts.length) {
              // Ensure a stable key for geometry measurements
              if (index >= _itemKeys.length) {
                _itemKeys.add(GlobalKey());
              }
              return Container(
                key: _itemKeys[index],
                child: PostCard(
                  post: posts[index],
                  isActive: index == _activeIndex,
                ),
              );
            }
            if (_hasMore) {
              _loadMore();
              return const Padding(
                padding: EdgeInsets.all(12.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
