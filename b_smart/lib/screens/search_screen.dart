import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/search_api.dart';
import '../utils/current_user.dart';
import '../utils/url_helper.dart';
import '../widgets/post_detail_modal.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchApi _searchApi = SearchApi();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  String _query = '';
  bool _loading = false;
  bool _historyLoading = false;
  List<Map<String, dynamic>> _history = const [];
  String _activeTab = 'all';

  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _posts = const [];
  List<Map<String, dynamic>> _reels = const [];
  Map<String, int> _totals = const {'users': 0, 'posts': 0, 'reels': 0};

  int _userLimit = 10;
  int _postLimit = 10;
  int _reelLimit = 10;
  final Map<String, bool> _loadingMore = {
    'users': false,
    'posts': false,
    'reels': false,
  };

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final userId = await CurrentUser.id;
    if (userId == null || userId.trim().isEmpty) return;
    setState(() => _historyLoading = true);
    try {
      final items = await _searchApi.getHistory(userId);
      if (!mounted) return;
      setState(() {
        _history = items;
      });
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    final userId = await CurrentUser.id;
    if (userId == null || userId.trim().isEmpty) return;
    await _searchApi.clearHistory(userId);
    if (!mounted) return;
    setState(() {
      _history = const [];
    });
  }

  Future<void> _deleteHistoryItem(String historyId) async {
    final userId = await CurrentUser.id;
    if (userId == null || userId.trim().isEmpty) return;
    await _searchApi.deleteHistoryItem(userId, historyId);
    if (!mounted) return;
    setState(() {
      _history = _history.where((h) {
        final id = (h['_id'] ?? h['id'])?.toString() ?? '';
        return id != historyId;
      }).toList();
    });
  }

  void _onInputChanged(String value) {
    setState(() {
      _query = value;
      _activeTab = 'all';
      _userLimit = 10;
      _postLimit = 10;
      _reelLimit = 10;
    });
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _users = const [];
        _posts = const [];
        _reels = const [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(
    String query, {
    int? userLimit,
    int? postLimit,
    int? reelLimit,
    bool append = false,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    if (!append) setState(() => _loading = true);
    try {
      final uLimit = userLimit ?? _userLimit;
      final pLimit = postLimit ?? _postLimit;
      final rLimit = reelLimit ?? _reelLimit;
      final maxLimit = [uLimit, pLimit, rLimit].reduce((a, b) => a > b ? a : b);
      final res = await _searchApi.search(query: trimmed, limit: maxLimit);
      final results = (res['results'] as Map?) ?? const {};
      final users = (results['users'] as List?) ?? const [];
      final posts = (results['posts'] as List?) ?? const [];
      final reels = (results['reels'] as List?) ?? const [];
      final totals = (res['totals'] as Map?) ?? const {};
      if (!mounted) return;
      setState(() {
        _totals = {
          'users': (totals['users'] as int?) ?? users.length,
          'posts': (totals['posts'] as int?) ?? posts.length,
          'reels': (totals['reels'] as int?) ?? reels.length,
        };
        _users = users.take(uLimit).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _posts = posts.take(pLimit).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _reels = reels.take(rLimit).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _users = const [];
        _posts = const [];
        _reels = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore['users'] = false;
          _loadingMore['posts'] = false;
          _loadingMore['reels'] = false;
        });
      }
    }
  }

  void _handleHistoryClick(Map<String, dynamic> item) {
    final label = (item['query'] ?? item['keyword'] ?? item['text'])?.toString() ?? '';
    if (label.trim().isEmpty) return;
    _controller.text = label;
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: label.length));
    setState(() {
      _query = label;
      _activeTab = 'all';
      _userLimit = 10;
      _postLimit = 10;
      _reelLimit = 10;
    });
    _runSearch(label);
  }

  Future<void> _loadMore(String type) async {
    if (_loadingMore[type] == true) return;
    setState(() {
      _loadingMore[type] = true;
      if (type == 'users') _userLimit += 10;
      if (type == 'posts') _postLimit += 10;
      if (type == 'reels') _reelLimit += 10;
    });
    await _runSearch(
      _query,
      userLimit: _userLimit,
      postLimit: _postLimit,
      reelLimit: _reelLimit,
      append: true,
    );
  }

  bool get _hasResults => _users.isNotEmpty || _posts.isNotEmpty || _reels.isNotEmpty;

  void _showPostDetail(String postId) {
    if (postId.isEmpty) return;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      Navigator.of(context).pushNamed('/post/$postId');
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: PostDetailModal(
            postId: postId,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      );
    }
  }

  String _extractMediaUrl(Map<String, dynamic> item) {
    dynamic media = item['media'] ?? item['mediaUrls'] ?? item['media_urls'];
    if (media is List && media.isNotEmpty) {
      final first = media.first;
      if (first is Map) {
        final m = Map<String, dynamic>.from(first);
        final url = m['fileUrl'] ??
            m['file_url'] ??
            m['url'] ??
            m['thumbnail_url'] ??
            m['thumbnailUrl'] ??
            m['thumbnail'] ??
            m['image'];
        if (url != null) return UrlHelper.normalizeUrl(url.toString());
      } else if (first is String) {
        return UrlHelper.normalizeUrl(first);
      }
    }
    final direct = item['image_url'] ?? item['thumbnail_url'] ?? item['image'] ?? item['thumb'];
    if (direct != null) return UrlHelper.normalizeUrl(direct.toString());
    return '';
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(LucideIcons.arrowLeft),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.search, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onInputChanged,
                      onSubmitted: _runSearch,
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Search',
                      ),
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_query.trim().isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        setState(() {
                          _query = '';
                          _activeTab = 'all';
                          _users = const [];
                          _posts = const [];
                          _reels = const [];
                        });
                        _focusNode.requestFocus();
                      },
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey,
                        ),
                        child: const Icon(Icons.close, size: 12, color: Colors.white),
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

  Widget _buildTabs() {
    final tabs = [
      {'key': 'all', 'label': 'All'},
      {'key': 'people', 'label': 'People (${_users.length})'},
      {'key': 'posts', 'label': 'Posts (${_posts.length})'},
      {'key': 'reels', 'label': 'Reels (${_reels.length})'},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final key = t['key'] as String;
            final active = _activeTab == key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: active,
                label: Text(t['label'] as String),
                onSelected: (_) => setState(() => _activeTab = key),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_historyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return const Center(
        child: Text('No recent searches'),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent', style: TextStyle(fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: _clearHistory,
                child: const Text('Clear all'),
              ),
            ],
          ),
        ),
        ..._history.map((item) {
          final id = (item['_id'] ?? item['id'])?.toString();
          final label = (item['query'] ?? item['keyword'] ?? item['text'])?.toString() ?? '';
          if (label.trim().isEmpty) return const SizedBox.shrink();
          return ListTile(
            leading: const CircleAvatar(child: Icon(LucideIcons.clock)),
            title: Text(label),
            onTap: () => _handleHistoryClick(item),
            trailing: id == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _deleteHistoryItem(id),
                  ),
          );
        }),
      ],
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    final uid = (user['_id'] ?? user['id'] ?? user['user_id'])?.toString() ?? '';
    final username = (user['username'] ?? user['userName'] ?? '').toString();
    final fullName = (user['full_name'] ?? user['fullName'] ?? '').toString();
    final avatar = (user['avatar_url'] ?? user['avatar'] ?? user['profile_image'])?.toString() ?? '';
    final role = (user['role'] ?? '').toString().toLowerCase();
    return ListTile(
      onTap: uid.isNotEmpty ? () => Navigator.of(context).pushNamed('/profile/$uid') : null,
      leading: CircleAvatar(
        backgroundImage: avatar.trim().isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar.trim().isEmpty ? Text((username.isNotEmpty ? username[0] : 'U').toUpperCase()) : null,
      ),
      title: Text(fullName.isNotEmpty ? fullName : username),
      subtitle: username.isNotEmpty ? Text('@$username') : null,
      trailing: role.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: role == 'vendor' ? const Color(0xFFFFEDD5) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                role == 'vendor' ? 'Vendor' : 'Member',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: role == 'vendor' ? const Color(0xFFEA580C) : Colors.grey.shade700,
                ),
              ),
            ),
    );
  }

  Widget _buildGridSection(String label, List<Map<String, dynamic>> items,
      {required VoidCallback onLoadMore, required bool canLoadMore, required bool isLoadingMore, required bool isReel}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(label.toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey)),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              final id = (item['_id'] ?? item['id'])?.toString() ?? '';
              final thumb = _extractMediaUrl(item);
              return GestureDetector(
                onTap: isReel
                    ? () => Navigator.of(context).pushNamed(
                          '/reels',
                          arguments: id.isNotEmpty ? {'initialReelId': id} : null,
                        )
                    : () => _showPostDetail(id),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.grey.shade200,
                    child: thumb.isEmpty
                        ? const Center(child: Icon(Icons.image, color: Colors.grey))
                        : CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              );
            },
          ),
          if (canLoadMore)
            TextButton(
              onPressed: isLoadingMore ? null : onLoadMore,
              child: isLoadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Load more'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTabs = _query.trim().isNotEmpty && _hasResults;
    final filteredUsers = (_activeTab == 'all' || _activeTab == 'people')
        ? _users
        : const <Map<String, dynamic>>[];
    final filteredPosts = (_activeTab == 'all' || _activeTab == 'posts')
        ? _posts
        : const <Map<String, dynamic>>[];
    final filteredReels = (_activeTab == 'all' || _activeTab == 'reels')
        ? _reels
        : const <Map<String, dynamic>>[];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(context),
            if (showTabs) _buildTabs(),
            Expanded(
              child: _query.trim().isEmpty
                  ? _buildHistory()
                  : _loading
                      ? const Center(child: CircularProgressIndicator())
                      : !_hasResults
                          ? Center(
                              child: Text('No results for "$_query"'),
                            )
                          : ListView(
                              children: [
                                if (filteredUsers.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Column(
                                      children:
                                          filteredUsers.map(_buildUserRow).toList(),
                                    ),
                                  ),
                                _buildGridSection(
                                  'Posts',
                                  filteredPosts,
                                  onLoadMore: () => _loadMore('posts'),
                                  canLoadMore: _posts.length < (_totals['posts'] ?? 0),
                                  isLoadingMore: _loadingMore['posts'] == true,
                                  isReel: false,
                                ),
                                _buildGridSection(
                                  'Reels',
                                  filteredReels,
                                  onLoadMore: () => _loadMore('reels'),
                                  canLoadMore: _reels.length < (_totals['reels'] ?? 0),
                                  isLoadingMore: _loadingMore['reels'] == true,
                                  isReel: true,
                                ),
                                if (filteredUsers.isNotEmpty &&
                                    _users.length < (_totals['users'] ?? 0))
                                  TextButton(
                                    onPressed: _loadingMore['users'] == true
                                        ? null
                                        : () => _loadMore('users'),
                                    child: _loadingMore['users'] == true
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Load more people'),
                                  ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
