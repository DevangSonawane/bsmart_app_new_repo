import 'package:flutter/material.dart';
import '../services/feed_service.dart';
import '../widgets/post_card.dart';
import '../utils/current_user.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FeedService _feedService = FeedService();
  final List posts = [];
  int _page = 0;
  final int _limit = 10;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
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
      _page += 1;
      if (items.length < _limit) _hasMore = false;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      posts.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          itemCount: posts.length + 1,
          itemBuilder: (context, index) {
            if (index < posts.length) {
              return PostCard(post: posts[index]);
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
