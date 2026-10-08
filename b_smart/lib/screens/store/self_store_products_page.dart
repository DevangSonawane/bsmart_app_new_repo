import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../api/phase2_store_api.dart';
import '../../api/upload_api.dart';
import '../../services/page_cache_service.dart';
import '../../utils/current_user.dart';
import 'store_models.dart';
import 'store_role_setup_screen.dart';
import 'store_theme.dart';
import 'shared/store_image_editor.dart';
import 'shared/store_shared_widgets.dart';
import 'shared/store_money.dart';

const _productsCacheGroup = 'store_my_products';

class SelfStoreProductsPage extends StatefulWidget {
  const SelfStoreProductsPage({super.key});

  @override
  State<SelfStoreProductsPage> createState() => _SelfStoreProductsPageState();
}

class SelfStoreProductsScreen extends StatefulWidget {
  const SelfStoreProductsScreen({super.key});

  @override
  State<SelfStoreProductsScreen> createState() =>
      _SelfStoreProductsScreenState();
}

class _SelfStoreProductsScreenState extends State<SelfStoreProductsScreen> {
  final _pageKey = GlobalKey<_SelfStoreProductsPageState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFC),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: const Color(0xFF078D92),
          onRefresh: () => _pageKey.currentState?.refresh() ?? Future.value(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              StoreRoleGateSliver(child: SelfStoreProductsPage(key: _pageKey)),
              SliverToBoxAdapter(
                child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelfStoreProductsPageState extends State<SelfStoreProductsPage> {
  int _selectedTab = 0;
  late Future<List<Map<String, dynamic>>> _productsFuture;

  static const _tabs = ['Active', 'Drafts', 'Out of stock'];

  @override
  void initState() {
    super.initState();
    _productsFuture = _loadMyProducts();
  }

  void _refreshProducts() {
    setState(() => _productsFuture = _loadMyProducts(forceNetwork: true));
  }

  /// Pull-to-refresh entry point (called by the parent [RefreshIndicator]).
  Future<void> refresh() async {
    final future = _loadMyProducts(forceNetwork: true);
    setState(() => _productsFuture = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder surfaces the error; refresh just needs to complete.
    }
  }

  /// Loads my products from the personal endpoint. Keep this cache separate
  /// from services/marketplace caches so "My" screens cannot bleed into each
  /// other if a previous tab has already filled the page cache.
  static Future<List<Map<String, dynamic>>> _loadMyProducts(
      {bool forceNetwork = false}) async {
    final myId = await CurrentUser.id;
    final pageCache = PageCacheService();
    final cacheParams = <String, dynamic>{};
    final cached = forceNetwork
        ? null
        : await pageCache.get(_productsCacheGroup, myId ?? '', cacheParams);

    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        return decoded.cast<Map<String, dynamic>>();
      } on Exception catch (_) {
        await pageCache.invalidate(_productsCacheGroup, myId ?? '');
      }
    }

    final items = _onlyCurrentOwner(await Phase2StoreApi().myProducts(), myId);
    if (myId != null && myId.isNotEmpty) {
      try {
        await pageCache.invalidate('store', myId);
        await pageCache.set(
            _productsCacheGroup, myId, cacheParams, jsonEncode(items));
      } on Exception catch (_) {}
    }
    return items;
  }

  static List<Map<String, dynamic>> _onlyCurrentOwner(
    List<Map<String, dynamic>> items,
    String? myId,
  ) {
    final id = myId?.trim();
    if (id == null || id.isEmpty) return items;
    return items.where((item) {
      final ownerIds = _ownerIdsFrom(item);
      return ownerIds.isEmpty || ownerIds.contains(id);
    }).toList();
  }

  static Set<String> _ownerIdsFrom(Map<String, dynamic> item) {
    final ids = <String>{};
    void add(dynamic value) {
      final id = value?.toString().trim();
      if (id != null && id.isNotEmpty) ids.add(id);
    }

    for (final key in const [
      'user_id',
      'userId',
      'owner_id',
      'ownerId',
      'seller_id',
      'sellerId',
      'vendor_id',
      'vendorId',
      'influencer_id',
      'influencerId',
      'created_by',
      'createdBy',
    ]) {
      add(item[key]);
    }
    for (final key in const [
      'user',
      'owner',
      'seller',
      'vendor',
      'influencer'
    ]) {
      final nested = item[key];
      if (nested is Map) {
        add(nested['id'] ??
            nested['_id'] ??
            nested['user_id'] ??
            nested['userId']);
      }
    }
    return ids;
  }

  static String _productStatus(Map<String, dynamic> product) {
    final raw = _text(product, const ['status']);
    if (raw.isEmpty) return 'Active';
    final value = raw.toLowerCase();
    if (value == 'active' || value == 'published') return 'Active';
    if (value == 'out_of_stock' || value == 'out of stock')
      return 'Out of Stock';
    return 'Draft';
  }

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        const _ProductsHeader(),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 20, 18, 0),
          child: Text(
            'My Products',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: StoreUnderlineTabs(
            tabs: _tabs,
            selectedIndex: _selectedTab,
            onSelected: (index) => setState(() => _selectedTab = index),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _productsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final products = snapshot.data ?? const [];
            if (products.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
                child: StoreEmptyState(
                  icon: LucideIcons.package,
                  title: 'No products yet',
                  body: 'Publish your first product to start selling.',
                ),
              );
            }
            final filtered = products.where((product) {
              final status = _productStatus(product);
              return switch (_selectedTab) {
                0 => status == 'Active',
                1 => status == 'Draft',
                _ => status == 'Out of Stock',
              };
            }).toList();
            return Column(
              children: [
                for (var i = 0; i < filtered.length; i++) ...[
                  _OwnerProductCard.fromApi(
                    filtered[i],
                    onChanged: _refreshProducts,
                  ),
                  if (i != filtered.length - 1) const SizedBox(height: 10),
                ],
                if (filtered.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: StoreEmptyState(
                      icon: LucideIcons.packageOpen,
                      title: 'Nothing in this tab',
                      body: 'Products with this status will appear here.',
                    ),
                  ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: StoreAddCtaButton(
              label: 'Add Product',
              onTap: () async {
                if (!await StoreRoleGate.ensureInfluencer(context)) return;
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StoreAddProductFlowScreen(
                      onPublished: _refreshProducts,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 12,
        18,
        0,
      ),
      child: const SizedBox(
        height: 32,
        child: Row(
          children: [
            Expanded(child: StoreBsmartWordmark()),
            Icon(LucideIcons.search, color: Color(0xFF060D35), size: 23),
            SizedBox(width: 18),
            _NotificationBell(),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(LucideIcons.bell, color: Color(0xFF060D35), size: 23),
        Positioned(
          right: -2,
          top: -4,
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: Color(0xFF684AC8),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

enum _StockState { ok, low }

class _OwnerProductCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final String stockLabel;
  final _StockState stockState;
  final String productId;
  final Map<String, dynamic> raw;
  final VoidCallback? onChanged;

  const _OwnerProductCard({
    this.imageUrl = '',
    required this.title,
    required this.price,
    required this.stockLabel,
    required this.stockState,
    this.productId = '',
    this.raw = const {},
    this.onChanged,
  });

  factory _OwnerProductCard.fromApi(
    Map<String, dynamic> product, {
    VoidCallback? onChanged,
  }) {
    final stock = _number(product, const ['stock_quantity']);
    final price = _number(product, const ['selling_price', 'price']);
    return _OwnerProductCard(
      imageUrl: _imageUrl(product),
      title: _text(product, const ['name', 'title'], fallback: 'Product'),
      price: formatCompactStoreMoney(price),
      stockLabel:
          stock <= 5 && stock > 0 ? 'Low stock' : '${stock.round()} in stock',
      stockState: stock <= 5 ? _StockState.low : _StockState.ok,
      // The API has returned the id under several keys across
      // deployments; missing it disables Edit/Delete, so check them all.
      productId: _text(product, const [
        'id',
        '_id',
        'product_id',
        'productId',
      ]),
      raw: product,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stockColor = stockState == _StockState.low
        ? const Color(0xFFE87822)
        : const Color(0xFF139B54);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GestureDetector(
        onTap: () => _showEditProductSheet(context),
        child: Container(
          height: 112,
          decoration: storeSoftCardDecoration(radius: 9),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              StoreItemImage(
                imageUrl: imageUrl,
                icon: LucideIcons.package,
                width: 120,
                height: 112,
                debugLabel: 'self-store-product',
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF060D35),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Georgia',
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              price,
                              style: const TextStyle(
                                color: Color(0xFF078D92),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (stockState == _StockState.ok)
                              Text(
                                stockLabel,
                                style: const TextStyle(
                                  color: Color(0xFF29304D),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            else
                              _StatusDot(label: stockLabel, color: stockColor),
                            const Spacer(),
                            const _StatusDot(
                              label: 'Visible',
                              color: Color(0xFF139B54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ProductActionsMenu(
                        productId: productId,
                        currentStatus:
                            _text(raw, const ['status'], fallback: 'active'),
                        title: title,
                        onEdit: () => _showEditProductSheet(context),
                        onDelete: () => _confirmDeleteProduct(context),
                        onToggleDraft: () => _toggleDraftStatus(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditProductSheet(BuildContext context) async {
    final priceCtrl = TextEditingController(
      text: _number(raw, const ['selling_price', 'price']).toStringAsFixed(0),
    );
    final stockCtrl = TextEditingController(
      text: _number(raw, const ['stock_quantity']).round().toString(),
    );
    String status = _text(raw, const ['status'], fallback: 'active');
    List<Map<String, dynamic>> images = StoreImageEditor.entriesOf(raw);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        // viewPadding covers the Android 3-button nav bar / iPhone home
        // indicator so Delete/Save are never hidden behind system UI.
        final bottomPad = MediaQuery.of(sheetContext).viewInsets.bottom +
            MediaQuery.of(sheetContext).viewPadding.bottom;
        return Theme(
          data: BStoreTheme.data(sheetContext),
          child: StatefulBuilder(
            builder: (innerContext, setSheetState) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 12, 18, bottomPad + 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1E5EA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: TextInputType.number,
                    style: _editFieldStyle,
                    cursorColor: const Color(0xFF078D92),
                    decoration: _editDecoration('Selling price (₹)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    style: _editFieldStyle,
                    cursorColor: const Color(0xFF078D92),
                    decoration: _editDecoration('Stock quantity'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status == 'draft' ? 'draft' : 'active',
                    dropdownColor: Colors.white,
                    focusColor: Colors.white,
                    style: _editFieldStyle,
                    icon: const Icon(LucideIcons.chevronDown, size: 17),
                    iconEnabledColor: const Color(0xFF060D35),
                    decoration: _editDecoration('Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active', style: _editFieldStyle),
                      ),
                      DropdownMenuItem(
                        value: 'draft',
                        child: Text('Draft', style: _editFieldStyle),
                      ),
                    ],
                    onChanged: (v) => setSheetState(() => status = v ?? status),
                  ),
                  const SizedBox(height: 10),
                  StoreImageEditor(
                    initial: images,
                    minCount: 1,
                    onChanged: (next) => images = next,
                    uploadFn: UploadApi().uploadInfluencerProductImages,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(innerContext).pop('delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(innerContext).pop('save'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF078D92),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result == null || !context.mounted) return;
    try {
      if (result == 'delete') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Delete product?',
                style: TextStyle(
                    color: Color(0xFF060D35), fontWeight: FontWeight.w900)),
            content: Text('Remove "$title" from your store?',
                style: const TextStyle(color: Color(0xFF29304D))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(d).pop(false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.of(d).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete')),
            ],
          ),
        );
        if (confirm != true || !context.mounted) return;
        await Phase2StoreApi().deleteProduct(productId);
        await StoreMockState.instance.refreshMarketplace();
        onChanged?.call();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Product deleted.')));
        return;
      }
      final price = double.tryParse(priceCtrl.text.trim());
      final stock = int.tryParse(stockCtrl.text.trim());
      if (images.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Products need at least one image.')),
        );
        return;
      }
      await Phase2StoreApi().updateProduct(productId, {
        if (price != null && price > 0) 'selling_price': price,
        if (price != null && price > 0) 'mrp': price,
        if (stock != null && stock >= 0) 'stock_quantity': stock,
        'status': status,
        'images': images,
      });
      await StoreMockState.instance.refreshMarketplace();
      try {
        final currentUserId = await CurrentUser.id;
        final pageCache = PageCacheService();
        if (currentUserId != null && currentUserId.trim().isNotEmpty) {
          await pageCache.invalidate(_productsCacheGroup, currentUserId);
          await pageCache.invalidate('store', currentUserId);
        }
      } on Exception catch (_) {}
      onChanged?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product updated.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _confirmDeleteProduct(BuildContext context) async {
    if (productId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete product?',
          style: TextStyle(
            color: Color(0xFF060D35),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          'Remove "$title" from your store?',
          style: const TextStyle(color: Color(0xFF29304D)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await Phase2StoreApi().deleteProduct(productId);
      await StoreMockState.instance.refreshMarketplace();
      onChanged?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product deleted.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _toggleDraftStatus(BuildContext context) async {
    if (productId.isEmpty) return;
    final current = _text(raw, const ['status'], fallback: 'active');
    final next = current == 'draft' ? 'active' : 'draft';
    try {
      await Phase2StoreApi().updateProduct(productId, {'status': next});
      await StoreMockState.instance.refreshMarketplace();
      onChanged?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next == 'draft'
              ? 'Product marked as draft.'
              : 'Product marked active.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }
}

class _StatusDot extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProductActionsMenu extends StatelessWidget {
  final String productId;
  final String currentStatus;
  final String title;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleDraft;

  const _ProductActionsMenu({
    required this.productId,
    required this.currentStatus,
    required this.title,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleDraft,
  });

  @override
  Widget build(BuildContext context) {
    if (productId.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      icon: const Icon(
        LucideIcons.ellipsisVertical,
        color: Color(0xFF060D35),
        size: 20,
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(LucideIcons.pencil,
                  size: 17, color: Color(0xFF060D35)),
              const SizedBox(width: 10),
              const Text('Edit',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF060D35))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'toggle_draft',
          child: Row(
            children: [
              Icon(
                currentStatus == 'draft'
                    ? LucideIcons.eye
                    : LucideIcons.archive,
                size: 17,
                color: const Color(0xFF060D35),
              ),
              const SizedBox(width: 10),
              Text(
                currentStatus == 'draft' ? 'Mark Active' : 'Mark as Draft',
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF060D35)),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(LucideIcons.trash2, size: 17, color: Colors.red),
              const SizedBox(width: 10),
              const Text('Delete',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
            break;
          case 'toggle_draft':
            onToggleDraft();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
    );
  }
}

class StoreAddProductFlowScreen extends StatefulWidget {
  final VoidCallback? onPublished;

  const StoreAddProductFlowScreen({super.key, this.onPublished});

  @override
  State<StoreAddProductFlowScreen> createState() =>
      _StoreAddProductFlowScreenState();
}

class _StoreAddProductFlowScreenState extends State<StoreAddProductFlowScreen> {
  // Mirrors React AddProduct.jsx: 3 steps, same option lists, same payload.
  static const _categories = ['Fashion', 'Tech', 'Home', 'Beauty'];
  static const _statusOptions = ['Draft', 'Active', 'Out of Stock'];
  static const _returnPolicies = [
    '7 Days Replacement',
    '10 Days Return',
    '15 Days Return',
    'No Returns',
  ];
  static const _warranties = [
    'None',
    '3 Months Manufacturer Warranty',
    '6 Months Manufacturer Warranty',
    '1 Year Manufacturer Warranty',
  ];
  static const _countries = ['India', 'China', 'USA', 'Other'];
  static const _weightUnits = ['kg', 'g', 'lb', 'oz'];
  static const _swatches = [
    '#8B5E3C',
    '#111111',
    '#C9A27E',
    '#E8DCC8',
    '#E24C4C',
    '#3B6FE2',
  ];
  static const _maxImages = 10;
  static const _maxHighlights = 5;

  int _step = 1;
  bool _publishing = false;
  int _mainImageIndex = 0;
  final _imagePicker = ImagePicker();
  final _productImages = <XFile>[];
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _mrpController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _skuController = TextEditingController();
  final _packageWeightController = TextEditingController();
  final _dimLController = TextEditingController();
  final _dimWController = TextEditingController();
  final _dimHController = TextEditingController();
  final _dispatchTimeController = TextEditingController();
  final _hsnController = TextEditingController();
  final List<TextEditingController> _highlightControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final List<_ProductVariant> _variants = [_ProductVariant()];
  String _category = 'Fashion';
  String _status = 'Active';
  String _weightUnit = 'kg';
  String _country = 'India';
  String _returnPolicy = '7 Days Replacement';
  String _warranty = 'None';
  bool _trackInventory = true;
  bool _useStoreDelivery = true;
  bool _useStoreReturnPolicy = true;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _shortDescController.dispose();
    _mrpController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    _packageWeightController.dispose();
    _dimLController.dispose();
    _dimWController.dispose();
    _dimHController.dispose();
    _dispatchTimeController.dispose();
    _hsnController.dispose();
    for (final c in _highlightControllers) {
      c.dispose();
    }
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFC),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _FlowHeader(
              title: _step == 1
                  ? 'Add Product'
                  : _step == 2
                      ? 'Price & Inventory'
                      : 'Delivery & publish',
              onBack: () {
                if (_step == 1) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _step = _step - 1);
                }
              },
              onSaveDraft: _publishing ? null : () => _submitProduct('Draft'),
              saving: _publishing,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 10, 26, 2),
              child: _FlowSteps(
                step: _step,
                totalSteps: 3,
                labels: const ['Details', 'Price', 'Delivery'],
                onStepTap: (i) => setState(() => _step = i),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                children: _step == 1
                    ? _detailsStep()
                    : _step == 2
                        ? _priceStep()
                        : _deliveryStep(),
              ),
            ),
            _FlowFooter(
              step: _step,
              totalSteps: 3,
              onContinue: () => setState(() => _step = _step + 1),
              onBack:
                  _step == 1 ? null : () => setState(() => _step = _step - 1),
              publishing: _publishing,
              publishLabel: 'Publish Product',
              onPublish: () => _submitProduct(
                _status == 'Draft' ? 'Active' : _status,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double get _discountPct {
    final mrp = double.tryParse(_mrpController.text) ?? 0;
    final sp = double.tryParse(_sellingPriceController.text) ?? 0;
    if (mrp <= 0 || sp <= 0 || sp >= mrp) return 0;
    return ((1 - sp / mrp) * 100).roundToDouble();
  }

  List<Widget> _detailsStep() {
    return [
      const _StepHeading(stepText: '1 of 3', title: 'Product Details'),
      const SizedBox(height: 14),
      _PhotoUploadCard(
        images: _productImages,
        mainIndex: _mainImageIndex,
        onTap: _pickProductImage,
        onSetMain: (index) => setState(() => _mainImageIndex = index),
        onRemove: (index) => setState(() {
          _productImages.removeAt(index);
          if (_mainImageIndex >= _productImages.length) {
            _mainImageIndex = 0;
          } else if (index < _mainImageIndex) {
            _mainImageIndex -= 1;
          }
        }),
      ),
      if (_productImages.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          '${_productImages.length}/$_maxImages photos · tap a photo to set it as main',
          style: const TextStyle(
            color: Color(0xFF8B90A2),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      const SizedBox(height: 12),
      _FormPanel(
        children: [
          _TextFieldShell(
            label: 'Product Name * (${_nameController.text.length}/150)',
            hint: 'Classic Brown Leather Tote',
            controller: _nameController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _TextFieldShell(
            label: 'Brand (optional)',
            hint: 'UrbanHide',
            controller: _brandController,
          ),
          const SizedBox(height: 14),
          _HighlightsEditor(
            controllers: _highlightControllers,
            max: _maxHighlights,
            hint: 'e.g. Premium full-grain leather for durability',
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 14),
          _DropdownShell<String>(
            label: 'Category *',
            value: _category,
            items: _categories,
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 14),
          _TextFieldShell(
            label:
                'Short Description * (${_shortDescController.text.length}/500)',
            hint: 'Describe your product...',
            controller: _shortDescController,
            minHeight: 76,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    ];
  }

  List<Widget> _priceStep() {
    return [
      const _StepHeading(stepText: '2 of 3', title: 'Price & Inventory'),
      const SizedBox(height: 14),
      _FormPanel(
        children: [
          Row(
            children: [
              Expanded(
                child: _TextFieldShell(
                  label: 'MRP (₹) *',
                  hint: '0',
                  controller: _mrpController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TextFieldShell(
                  label: 'Selling Price (₹) *',
                  hint: '0',
                  controller: _sellingPriceController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TextFieldShell(
                  label: 'Stock Quantity *',
                  hint: '0',
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TextFieldShell(
                  label: 'Seller SKU *',
                  hint: 'SKU-001',
                  controller: _skuController,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F7F9),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: const Color(0xFFD5DEE4)),
            ),
            child: Text(
              _discountPct > 0 ? '${_discountPct.toInt()}% off' : 'Discount: —',
              style: const TextStyle(
                color: Color(0xFF060D35),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Track Inventory',
                style: TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Switch.adaptive(
                value: _trackInventory,
                onChanged: (v) => setState(() => _trackInventory = v),
                activeThumbColor: const Color(0xFF078D92),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DropdownShell<String>(
            label: 'Product Status *',
            value: _status,
            items: _statusOptions,
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          const SizedBox(height: 12),
          _VariantsEditor(
            variants: _variants,
            swatches: _swatches,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    ];
  }

  List<Widget> _deliveryStep() {
    return [
      const _StepHeading(stepText: '3 of 3', title: 'Delivery & Publish'),
      const SizedBox(height: 14),
      _FormPanel(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _TextFieldShell(
                  label: 'Package Weight *',
                  hint: '0',
                  controller: _packageWeightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DropdownShell<String>(
                  label: 'Unit',
                  value: _weightUnit,
                  items: _weightUnits,
                  onChanged: (value) =>
                      setState(() => _weightUnit = value ?? _weightUnit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Dimensions (L x W x H) * in cm',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _TextFieldShell(
                  label: 'L',
                  hint: 'L',
                  controller: _dimLController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TextFieldShell(
                  label: 'W',
                  hint: 'W',
                  controller: _dimWController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TextFieldShell(
                  label: 'H',
                  hint: 'H',
                  controller: _dimHController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TextFieldShell(
            label: 'Dispatch Time *',
            hint: '1-2 Days',
            controller: _dispatchTimeController,
          ),
          const SizedBox(height: 12),
          _TextFieldShell(
            label: 'HSN / GST (optional)',
            hint: '4202',
            controller: _hsnController,
          ),
          const SizedBox(height: 12),
          _DropdownShell<String>(
            label: 'Country of Origin *',
            value: _country,
            items: _countries,
            onChanged: (value) => setState(() => _country = value ?? _country),
          ),
          const SizedBox(height: 12),
          _CheckRow(
            label: 'Use store delivery settings',
            value: _useStoreDelivery,
            onChanged: (v) => setState(() => _useStoreDelivery = v),
          ),
          const SizedBox(height: 12),
          _DropdownShell<String>(
            label: 'Return Policy *',
            value: _returnPolicy,
            items: _returnPolicies,
            onChanged: (value) =>
                setState(() => _returnPolicy = value ?? _returnPolicy),
          ),
          const SizedBox(height: 12),
          _CheckRow(
            label: 'Use store return policy',
            value: _useStoreReturnPolicy,
            onChanged: (v) => setState(() => _useStoreReturnPolicy = v),
          ),
          const SizedBox(height: 12),
          _DropdownShell<String>(
            label: 'Warranty (optional)',
            value: _warranty,
            items: _warranties,
            onChanged: (value) =>
                setState(() => _warranty = value ?? _warranty),
          ),
        ],
      ),
    ];
  }

  Future<void> _pickProductImage() async {
    try {
      final images = await _imagePicker.pickMultiImage();
      if (images.isEmpty || !mounted) return;
      setState(() {
        final room = _maxImages - _productImages.length;
        if (room <= 0) return;
        _productImages.addAll(images.take(room));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image picker is not available.')),
      );
    }
  }

  /// Reads each picked image into memory for upload.
  ///
  /// Reading bytes works for content:// URIs and provider cache paths, which
  /// `MultipartFile.fromPath` cannot. Images are capped at [_maxUploadBytes]
  /// so a huge photo cannot blow up the request.
  static Future<List<MultipartBytesFile>> _readImageBytes(
    List<XFile> images,
  ) async {
    const maxUploadBytes = 12 * 1024 * 1024;
    final files = <MultipartBytesFile>[];
    for (final image in images) {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) continue;
      files.add(MultipartBytesFile(
        bytes: bytes.length > maxUploadBytes
            ? bytes.sublist(0, maxUploadBytes)
            : bytes,
        filename: _uploadNameFor(image),
      ));
    }
    if (files.isEmpty) {
      throw StateError('Could not read the selected images.');
    }
    return files;
  }

  /// Builds an upload filename that keeps a real image extension, since the
  /// server infers the content type from it.
  static String _uploadNameFor(XFile image) =>
      influencerUploadFilename(image.name, image.path);

  String _apiStatus(String status) {
    final v = status.toLowerCase();
    if (v == 'active') return 'active';
    if (v == 'out of stock' || v == 'out_of_stock') return 'out_of_stock';
    return 'draft';
  }

  Future<void> _submitProduct(String status) async {
    if (_productImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one product image is required.'),
        ),
      );
      return;
    }
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      final ordered = [
        _productImages[_mainImageIndex.clamp(0, _productImages.length - 1)],
        for (var i = 0; i < _productImages.length; i++)
          if (i != _mainImageIndex.clamp(0, _productImages.length - 1))
            _productImages[i],
      ];
      final uploaded = await UploadApi().uploadInfluencerProductImages(
        byteFiles: await _readImageBytes(ordered),
      );
      final imagesPayload = ordered.asMap().entries.map((e) {
        final up = uploaded[e.key];
        return {'fileName': up.fileName};
      }).toList();
      final sellingPrice =
          double.tryParse(_sellingPriceController.text.trim()) ?? 0;
      await Phase2StoreApi().createProduct({
        'images': imagesPayload,
        'name': _nameController.text.trim(),
        'category': _category,
        'brand': _brandController.text.trim(),
        'short_description': _shortDescController.text.trim(),
        'key_highlights': _highlightControllers
            .map((c) => c.text.trim())
            .where((h) => h.isNotEmpty)
            .toList(),
        'mrp': double.tryParse(_mrpController.text.trim()) ?? 0,
        'selling_price': sellingPrice,
        'stock_quantity': int.tryParse(_stockController.text.trim()) ??
            _parseNumber(_stockController.text).round(),
        'seller_sku': _skuController.text.trim(),
        'track_inventory': _trackInventory,
        'status': _apiStatus(status),
        'variants': _variants
            .where((v) =>
                v.color.trim().isNotEmpty ||
                v.sizeController.text.trim().isNotEmpty ||
                v.stockController.text.trim().isNotEmpty ||
                v.priceController.text.trim().isNotEmpty)
            .map((v) => {
                  'color': v.color,
                  'size': v.sizeController.text.trim().isEmpty
                      ? 'One Size'
                      : v.sizeController.text.trim(),
                  'stock_quantity':
                      int.tryParse(v.stockController.text.trim()) ?? 0,
                  'price': double.tryParse(v.priceController.text.trim()) ??
                      sellingPrice,
                })
            .toList(),
        'package_weight':
            double.tryParse(_packageWeightController.text.trim()) ?? 0,
        'weight_unit': _weightUnit,
        'dimensions': {
          'length': double.tryParse(_dimLController.text.trim()) ?? 0,
          'width': double.tryParse(_dimWController.text.trim()) ?? 0,
          'height': double.tryParse(_dimHController.text.trim()) ?? 0,
          'unit': 'cm',
        },
        'dispatch_time': _dispatchTimeController.text.trim(),
        'hsn_gst': _hsnController.text.trim(),
        'country_of_origin': _country,
        'return_policy': _returnPolicy,
        'use_store_delivery_settings': _useStoreDelivery,
        'use_store_return_policy': _useStoreReturnPolicy,
        'warranty': _warranty,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e')),
      );
      return;
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
    try {
      widget.onPublished?.call();
    } catch (_) {}
    await StoreMockState.instance.refreshMarketplace();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status.toLowerCase() == 'draft'
              ? 'Draft saved.'
              : 'Product published.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }
}

class _FlowHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onSaveDraft;
  final bool saving;

  const _FlowHeader({
    required this.title,
    required this.onBack,
    this.onSaveDraft,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        6,
        MediaQuery.of(context).padding.top + 8,
        12,
        0,
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(LucideIcons.chevronLeft, size: 24),
              color: const Color(0xFF060D35),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(
              width: 92,
              child: onSaveDraft == null
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: saving ? null : onSaveDraft,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        saving ? 'Saving...' : 'Save Draft',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF684AC8),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowSteps extends StatelessWidget {
  final int step;
  final int totalSteps;
  final List<String> labels;
  final ValueChanged<int> onStepTap;

  const _FlowSteps({
    required this.step,
    required this.totalSteps,
    required this.labels,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= totalSteps; i++) ...[
          Expanded(
            child: InkWell(
              onTap: () => onStepTap(i),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (i > 1)
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFD5DEE4),
                            thickness: 2,
                          ),
                        )
                      else
                        const Spacer(),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < step
                              ? const Color(0xFF078D92)
                              : i == step
                                  ? const Color(0xFF060D35)
                                  : Colors.white,
                          border: Border.all(
                            color: i <= step
                                ? Colors.transparent
                                : const Color(0xFFD5DEE4),
                            width: 1.5,
                          ),
                        ),
                        child: i < step
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 15)
                            : Text(
                                '$i',
                                style: TextStyle(
                                  color: i == step
                                      ? Colors.white
                                      : const Color(0xFF8B90A2),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                      if (i < totalSteps)
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFD5DEE4),
                            thickness: 2,
                          ),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i - 1],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: i == step
                          ? const Color(0xFF060D35)
                          : const Color(0xFF8B90A2),
                      fontSize: 10.5,
                      fontWeight: i == step ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepHeading extends StatelessWidget {
  final String stepText;
  final String title;

  const _StepHeading({
    required this.stepText,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          stepText,
          style: const TextStyle(
            color: Color(0xFF684AC8),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF060D35),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            fontFamily: 'Georgia',
          ),
        ),
      ],
    );
  }
}

class _PhotoUploadCard extends StatelessWidget {
  final List<XFile> images;
  final int mainIndex;
  final VoidCallback onTap;
  final Function(int) onRemove;
  final Function(int)? onSetMain;

  const _PhotoUploadCard({
    required this.images,
    this.mainIndex = 0,
    required this.onTap,
    required this.onRemove,
    this.onSetMain,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 126,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD5DEE4), width: 1.2),
        ),
        child: images.isEmpty
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.cloudUpload,
                      color: Color(0xFF684AC8), size: 36),
                  SizedBox(height: 9),
                  Text(
                    'Add product photos',
                    style: TextStyle(
                      color: Color(0xFF060D35),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Required for publishing',
                    style: TextStyle(
                      color: Color(0xFF29304D),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ListView.separated(
                    padding: const EdgeInsets.all(8),
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isMain = index == mainIndex;
                      return GestureDetector(
                        onTap: () => onSetMain?.call(index),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isMain
                                  ? const Color(0xFF078D92)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                Image.file(
                                  File(images[index].path),
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                                if (isMain)
                                  const Positioned(
                                    left: 4,
                                    bottom: 4,
                                    child: ColoredBox(
                                      color: Colors.black54,
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        child: Text(
                                          'Main',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: GestureDetector(
                                    onTap: () => onRemove(index),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.black87,
                                      child: Icon(Icons.close_rounded,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  final List<Widget> children;

  const _FormPanel({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: storeSoftCardDecoration(radius: 12),
      child: Column(children: children),
    );
  }
}

class _TextFieldShell extends StatelessWidget {
  final String label;
  final String? subtitle;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? prefixText;
  final double minHeight;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  const _TextFieldShell({
    required this.label,
    this.subtitle,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.prefixText,
    this.minHeight = 42,
    this.maxLines = 1,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF060D35),
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            style: const TextStyle(
              color: Color(0xFF6E748B),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 7),
        TextField(
          key: ValueKey(controller),
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          onChanged: onChanged,
          minLines: maxLines > 1 ? maxLines : 1,
          maxLines: maxLines,
          style: const TextStyle(
            color: Color(0xFF060D35),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            constraints: BoxConstraints(minHeight: minHeight),
            hintText: hint,
            prefixText: prefixText,
            hintStyle: const TextStyle(
              color: Color(0xFF8B90A2),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF6F7F9),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Color(0xFFD5DEE4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Color(0xFF078D92)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Color(0xFFD5DEE4)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownShell<T> extends StatelessWidget {
  final String label;
  final String? hint;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _DropdownShell({
    required this.label,
    this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF060D35),
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          dropdownColor: Colors.white,
          focusColor: Colors.white,
          style: const TextStyle(
            color: Color(0xFF060D35),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          icon: const Icon(LucideIcons.chevronDown, size: 17),
          iconEnabledColor: const Color(0xFF060D35),
          iconDisabledColor: const Color(0xFF8B90A2),
          borderRadius: BorderRadius.circular(8),
          hint: hint == null
              ? null
              : Text(
                  hint!,
                  style: const TextStyle(
                    color: Color(0xFF8B90A2),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString(),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Color(0xFFD5DEE4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: const BorderSide(color: Color(0xFF078D92)),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlowFooter extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final VoidCallback onPublish;
  final String publishLabel;
  final bool publishing;

  const _FlowFooter({
    required this.step,
    this.totalSteps = 2,
    required this.onContinue,
    this.onBack,
    required this.onPublish,
    this.publishLabel = 'Publish',
    this.publishing = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final primary = SizedBox(
      height: 50,
      child: FilledButton(
        onPressed:
            publishing ? null : (step < totalSteps ? onContinue : onPublish),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF078D92),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: publishing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  step < totalSteps ? 'Continue' : publishLabel,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 12 + bottomPad),
      child: onBack == null
          ? SizedBox(width: double.infinity, child: primary)
          : Row(
              children: [
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: publishing ? null : onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF060D35),
                      side: const BorderSide(color: Color(0xFFD5DEE4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Text(
                      'Back',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: primary),
              ],
            ),
    );
  }
}

class _ProductVariant {
  String color;
  final TextEditingController sizeController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  _ProductVariant({this.color = '#8B5E3C'});

  void dispose() {
    sizeController.dispose();
    stockController.dispose();
    priceController.dispose();
  }
}

class _HighlightsEditor extends StatelessWidget {
  final List<TextEditingController> controllers;
  final int max;
  final String hint;
  final VoidCallback onChanged;

  const _HighlightsEditor({
    required this.controllers,
    required this.max,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Key Highlights *',
          style: TextStyle(
            color: Color(0xFF060D35),
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        for (var i = 0; i < controllers.length; i++) ...[
          Row(
            key: ValueKey(controllers[i]),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _TextFieldShell(
                  label: 'Highlight ${i + 1}',
                  hint: hint,
                  controller: controllers[i],
                ),
              ),
              IconButton(
                onPressed: () {
                  controllers.removeAt(i);
                  onChanged();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                color: const Color(0xFF8B90A2),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (controllers.length < max)
          TextButton(
            onPressed: () {
              controllers.add(TextEditingController());
              onChanged();
            },
            child: const Text(
              '+ Add Highlight (Max 5)',
              style: TextStyle(
                color: Color(0xFF078D92),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _VariantsEditor extends StatefulWidget {
  final List<_ProductVariant> variants;
  final List<String> swatches;
  final VoidCallback onChanged;

  const _VariantsEditor({
    required this.variants,
    required this.swatches,
    required this.onChanged,
  });

  @override
  State<_VariantsEditor> createState() => _VariantsEditorState();
}

String _normalizeHex(String raw) {
  var hex = raw.trim();
  if (!hex.startsWith('#')) hex = '#$hex';
  if (RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(hex)) {
    if (hex.length == 4) {
      hex = '#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}'
          .toUpperCase();
    }
    return hex.toUpperCase();
  }
  return '';
}

Color _parseHex(String hex) {
  final normalized = _normalizeHex(hex);
  if (normalized.isEmpty) return const Color(0xFF8B5E3C);
  return Color(int.parse(normalized.substring(1), radix: 16) + 0xFF000000);
}

String _colorToHex(Color color) {
  final r = ((color.r * 255).round()).clamp(0, 255);
  final g = ((color.g * 255).round()).clamp(0, 255);
  final b = ((color.b * 255).round()).clamp(0, 255);
  return '#${r.toRadixString(16).padLeft(2, '0')}'
          '${g.toRadixString(16).padLeft(2, '0')}'
          '${b.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

/// Mirrors web `ColorPicker`: the value is any hex string (not a preset),
/// swatch button opens a picker popover with a full color picker + hex input
/// + preset swatches.
class _VariantColorPicker extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChange;
  final List<String> swatches;

  const _VariantColorPicker({
    required this.value,
    required this.onChange,
    required this.swatches,
  });

  @override
  State<_VariantColorPicker> createState() => _VariantColorPickerState();
}

class _VariantColorPickerState extends State<_VariantColorPicker> {
  Future<void> _openPicker() async {
    var picked = _parseHex(widget.value);
    final hexController =
        TextEditingController(text: _normalizeHex(widget.value));
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            final maxContentHeight =
                (MediaQuery.sizeOf(context).height * 0.68).clamp(300.0, 420.0);
            final pickerHeight = (maxContentHeight - 112).clamp(210.0, 300.0);

            void commitHex(String raw) {
              final normalized = _normalizeHex(raw);
              if (normalized.isEmpty) return;
              setDialog(() {
                picked = _parseHex(normalized);
                hexController.text = normalized;
              });
            }

            // Force light styling: the app can run in system dark mode, which
            // turns the picker's slider/label boxes and the hex field black.
            // Web shows palette + hex input + swatches only, so the RGB/HSV
            // label boxes are hidden too.
            return Theme(
              data: ThemeData.light(useMaterial3: true),
              child: AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                content: SizedBox(
                  width: 280,
                  height: maxContentHeight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: pickerHeight,
                        child: ColorPicker(
                          pickerColor: picked,
                          onColorChanged: (c) {
                            setDialog(() {
                              picked = c;
                              hexController.text = _colorToHex(c);
                            });
                          },
                          enableAlpha: false,
                          displayThumbColor: true,
                          pickerAreaHeightPercent: 0.7,
                          labelTypes: const [],
                          pickerAreaBorderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: TextField(
                          controller: hexController,
                          decoration: InputDecoration(
                            hintText: '#8B5E3C',
                            hintStyle: const TextStyle(
                              color: Color(0xFF8B90A2),
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide:
                                  const BorderSide(color: Color(0xFFD5DEE4)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(7),
                              borderSide:
                                  const BorderSide(color: Color(0xFF078D92)),
                            ),
                          ),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF060D35),
                          ),
                          onSubmitted: commitHex,
                          onChanged: (v) {
                            if (_normalizeHex(v).isNotEmpty) {
                              setDialog(
                                  () => picked = _parseHex(_normalizeHex(v)));
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in widget.swatches)
                            GestureDetector(
                              onTap: () {
                                setDialog(() {
                                  picked = _parseHex(s);
                                  hexController.text = _normalizeHex(s);
                                });
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _parseHex(s),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        _colorToHex(picked) == _normalizeHex(s)
                                            ? const Color(0xFF078D92)
                                            : Colors.black12,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF29304D),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF078D92),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      widget.onChange(_colorToHex(picked));
                      Navigator.of(context).pop();
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: _openPicker,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _parseHex(widget.value),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD5DEE4)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.value.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF060D35),
            ),
          ),
        ),
      ],
    );
  }
}

class _VariantsEditorState extends State<_VariantsEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Variants (optional)',
          style: TextStyle(
            color: Color(0xFF060D35),
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        for (var i = 0; i < widget.variants.length; i++) ...[
          Container(
            key: ValueKey(widget.variants[i]),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD5DEE4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _VariantColorPicker(
                        value: widget.variants[i].color,
                        swatches: widget.swatches,
                        onChange: (hex) => setState(
                          () => widget.variants[i].color = hex,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          if (widget.variants.length <= 1) {
                            widget.variants[i].sizeController.clear();
                            widget.variants[i].stockController.clear();
                            widget.variants[i].priceController.clear();
                          } else {
                            widget.variants.removeAt(i);
                          }
                        });
                        widget.onChanged();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: const Color(0xFF8B90A2),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _TextFieldShell(
                  label: 'Size (e.g. One Size)',
                  hint: 'One Size',
                  controller: widget.variants[i].sizeController,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _TextFieldShell(
                        label: 'Stock',
                        hint: '0',
                        controller: widget.variants[i].stockController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TextFieldShell(
                        label: 'Price (₹)',
                        hint: '0',
                        controller: widget.variants[i].priceController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextButton(
          onPressed: () {
            setState(() => widget.variants.add(_ProductVariant()));
            widget.onChanged();
          },
          child: const Text(
            '+ Add Variant',
            style: TextStyle(
              color: Color(0xFF078D92),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF060D35),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

double _parseNumber(String value) {
  return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
}

/// Explicit light styling for the Edit bottom sheets. The app can run in
/// system dark mode, so every input declares its own fill / text / border
/// colors instead of inheriting the (possibly dark) ambient theme.
const TextStyle _editFieldStyle = TextStyle(
  color: Color(0xFF060D35),
  fontSize: 13,
  fontWeight: FontWeight.w700,
);

InputDecoration _editDecoration(String label) {
  const borderColor = Color(0xFFD5DEE4);
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    labelStyle: const TextStyle(
      color: Color(0xFF29304D),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
    hintStyle: const TextStyle(
      color: Color(0xFF8B90A2),
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: Color(0xFF078D92)),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: const BorderSide(color: borderColor),
    ),
  );
}

double _number(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

String _text(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key]?.toString().trim();
    if (value != null && value.isNotEmpty && value != 'null') return value;
  }
  return fallback;
}

/// Seller-owned products carry `images: [{fileUrl, fileName}]` from the
/// influencer upload endpoint, so reuse the catalog resolver instead of
/// guessing key order here.
String _imageUrl(Map<String, dynamic> json) =>
    StoreMockState.firstImageUrl(json);
