import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import 'shared/store_shared_widgets.dart';
import 'store_models.dart';
import 'store_theme.dart';
import 'visitor_product_detail_page.dart';
import 'visitor_service_detail_page.dart';

/// Live marketplace search (Phase 2 md: `q` + `category` on
/// `GET /api/influencer-products` and `GET /api/influencer-services`).
class StoreSearchScreen extends StatefulWidget {
  const StoreSearchScreen({super.key});

  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

enum _SearchScope { all, products, services }

class _StoreSearchScreenState extends State<StoreSearchScreen> {
  late final TextEditingController _controller;
  late final TextEditingController _categoryController;
  bool _loadedInitialQuery = false;
  _SearchScope _scope = _SearchScope.all;
  Timer? _debounce;
  Future<List<StoreMockCatalogItem>>? _resultsFuture;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _categoryController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedInitialQuery) return;
    _loadedInitialQuery = true;
    final initial = ModalRoute.of(context)?.settings.arguments;
    if (initial is String && initial.trim().isNotEmpty) {
      _controller.text = initial;
      _search();
    } else if (initial is Map) {
      final query = initial['q']?.toString() ?? '';
      final category = initial['category']?.toString() ?? '';
      _controller.text = query;
      _categoryController.text = category;
      if (query.trim().isNotEmpty || category.trim().isNotEmpty) _search();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _search);
  }

  void _search() {
    final query = _controller.text.trim();
    final category = _categoryController.text.trim();
    if (query.isEmpty && category.isEmpty) {
      setState(() => _resultsFuture = null);
      return;
    }
    final scope = _scope;
    setState(() {
      _resultsFuture = _runSearch(
        query: query.isEmpty ? null : query,
        category: category.isEmpty ? null : category,
        scope: scope,
      );
    });
  }

  static Future<List<StoreMockCatalogItem>> _runSearch({
    String? query,
    String? category,
    required _SearchScope scope,
  }) async {
    final api = Phase2StoreApi();
    final futures = <Future<List<Map<String, dynamic>>>>[];
    if (scope != _SearchScope.services) {
      futures.add(api.listProducts(query: query, category: category));
    }
    if (scope != _SearchScope.products) {
      futures.add(api.listServices(query: query, category: category));
    }
    final results = await Future.wait(futures);
    var index = 0;
    final items = <StoreMockCatalogItem>[];
    if (scope != _SearchScope.services) {
      items.addAll(
          results[index++].map(StoreMockState.productFromApi));
    }
    if (scope != _SearchScope.products) {
      items.addAll(
          results[index++].map(StoreMockState.serviceFromApi));
    }
    return items
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  void _openItem(StoreMockCatalogItem item) {
    if (item.type == StoreMockItemType.service) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VisitorServiceDetailPage(
            ownerUserId: null,
            item: item,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VisitorProductDetailPage(
            product: VisitorProductDetailData(item: item),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
      backgroundColor: StorePalette.paleBlue,
      appBar: AppBar(
        title: const Text('Search Store'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              cursorColor: StorePalette.blue,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              textInputAction: TextInputAction.search,
              onChanged: (_) => _scheduleSearch(),
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search products and services',
                hintStyle: const TextStyle(color: Colors.black54),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: () {
                    _controller.clear();
                    _search();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
                filled: true,
                fillColor: Colors.white,
                hoverColor: Colors.white,
                focusColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: StorePalette.blue),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _categoryController,
              cursorColor: StorePalette.blue,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              textInputAction: TextInputAction.search,
              onChanged: (_) => _scheduleSearch(),
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Category filter (exact match, optional)',
                hintStyle:
                    const TextStyle(color: Colors.black54, fontSize: 13),
                prefixIcon: const Icon(LucideIcons.tags),
                suffixIcon: IconButton(
                  onPressed: () {
                    _categoryController.clear();
                    _search();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: StorePalette.blue),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<_SearchScope>(
              segments: const [
                ButtonSegment(
                    value: _SearchScope.all, label: Text('All')),
                ButtonSegment(
                    value: _SearchScope.products, label: Text('Products')),
                ButtonSegment(
                    value: _SearchScope.services, label: Text('Services')),
              ],
              selected: {_scope},
              onSelectionChanged: (selected) {
                setState(() => _scope = selected.first);
                _search();
              },
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildResults() {
    final future = _resultsFuture;
    if (future == null) {
      return const Center(
        child: Text(
          'Search results will appear here',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return FutureBuilder<List<StoreMockCatalogItem>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Search failed: ${snapshot.error}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No matches. Try another keyword or category.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            final isService = item.type == StoreMockItemType.service;
            return InkWell(
              onTap: () => _openItem(item),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    StoreItemImage(
                      imageUrl: item.imageUrl,
                      icon: item.icon,
                      width: 56,
                      height: 56,
                      borderRadius: 8,
                      debugLabel: 'store-search-result',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${item.category} · ${isService ? 'Service' : 'Product'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.priceLabel,
                      style: const TextStyle(
                        color: StorePalette.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
