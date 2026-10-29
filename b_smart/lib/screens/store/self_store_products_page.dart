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
import 'publish/store_publish_ui.dart';
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
    return BStoreThemeScope(
      child: Scaffold(
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
                StoreRoleGateSliver(
                    child: SelfStoreProductsPage(key: _pageKey)),
                SliverToBoxAdapter(
                  child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 18),
                ),
              ],
            ),
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
      stockLabel: stock <= 5 && stock > 0
          ? 'Low stock'
          : '${groupThousands('${stock.round()}')} in stock',
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              price,
                              style: const TextStyle(
                                color: Color(0xFF078D92),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
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

  static const _flowSteps = [
    PublishStep(
      label: 'Details',
      subtitle: 'Photos, name & description',
      icon: LucideIcons.image,
    ),
    PublishStep(
      label: 'Price',
      subtitle: 'Pricing, stock & variants',
      icon: LucideIcons.tag,
    ),
    PublishStep(
      label: 'Delivery',
      subtitle: 'Shipping, policies & publish',
      icon: LucideIcons.truck,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BStoreThemeScope(
      child: Scaffold(
        backgroundColor: PublishStyle.canvas,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              PublishFlowHeader(
                eyebrow: 'Seller studio · products',
                title: 'Add Product',
                step: _step,
                steps: _flowSteps,
                completion: _completion,
                onStepTap: (i) => setState(() => _step = i),
                onBack: () {
                  if (_step == 1) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _step = _step - 1);
                  }
                },
                draftLabel: 'Save draft',
                onSaveDraft: _publishing ? null : () => _submitProduct('Draft'),
                saving: _publishing,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.035, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: ListView(
                    key: ValueKey(_step),
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
                    children: _step == 1
                        ? _detailsStep()
                        : _step == 2
                            ? _priceStep()
                            : _deliveryStep(),
                  ),
                ),
              ),
              PublishFooter(
                step: _step,
                totalSteps: 3,
                onPrimary: () {
                  if (_step < 3) {
                    setState(() => _step = _step + 1);
                  } else {
                    _submitProduct(_status == 'Draft' ? 'Active' : _status);
                  }
                },
                primaryLabel: _step < 3 ? 'Continue' : 'Publish product',
                onBack:
                    _step == 1 ? null : () => setState(() => _step = _step - 1),
                busy: _publishing,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _completion {
    var done = 0;
    if (_nameController.text.trim().isNotEmpty &&
        _shortDescController.text.trim().isNotEmpty &&
        _productImages.isNotEmpty) {
      done++;
    }
    if (_mrpController.text.trim().isNotEmpty &&
        _sellingPriceController.text.trim().isNotEmpty &&
        _stockController.text.trim().isNotEmpty &&
        _skuController.text.trim().isNotEmpty) {
      done++;
    }
    if (_packageWeightController.text.trim().isNotEmpty &&
        _dimLController.text.trim().isNotEmpty &&
        _dimWController.text.trim().isNotEmpty &&
        _dimHController.text.trim().isNotEmpty &&
        _dispatchTimeController.text.trim().isNotEmpty) {
      done++;
    }
    return done / 3;
  }

  List<PublishChecklistItem> get _checklist => [
        PublishChecklistItem(
          'Product details & photos',
          _nameController.text.trim().isNotEmpty &&
              _shortDescController.text.trim().isNotEmpty &&
              _productImages.isNotEmpty,
        ),
        PublishChecklistItem(
          'Price, stock & SKU',
          _mrpController.text.trim().isNotEmpty &&
              _sellingPriceController.text.trim().isNotEmpty &&
              _stockController.text.trim().isNotEmpty &&
              _skuController.text.trim().isNotEmpty,
        ),
        PublishChecklistItem(
          'Shipping & delivery details',
          _packageWeightController.text.trim().isNotEmpty &&
              _dimLController.text.trim().isNotEmpty &&
              _dimWController.text.trim().isNotEmpty &&
              _dimHController.text.trim().isNotEmpty &&
              _dispatchTimeController.text.trim().isNotEmpty,
        ),
      ];

  double get _discountPct {
    final mrp = _parseNumber(_mrpController.text);
    final sp = _parseNumber(_sellingPriceController.text);
    if (mrp <= 0 || sp <= 0 || sp >= mrp) return 0;
    return ((1 - sp / mrp) * 100).roundToDouble();
  }

  List<Widget> _detailsStep() {
    return [
      const PublishStepIntro(
        title: 'Product details',
        subtitle: 'Add clear photos and the basics customers need to say yes.',
      ),
      const SizedBox(height: 16),
      _PhotoUploadCard(
        images: _productImages,
        maxImages: _maxImages,
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
          '${_productImages.length}/$_maxImages photos · tap a photo to make it the main one',
          style: const TextStyle(
            color: PublishStyle.soft,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      const SizedBox(height: 16),
      PublishSectionCard(
        title: 'Basics',
        subtitle: 'This is what customers see first',
        icon: LucideIcons.package,
        children: [
          PublishField(
            label: 'Product Name',
            required: true,
            hint: 'Classic Brown Leather Tote',
            controller: _nameController,
            maxLength: 150,
            onChanged: (_) => setState(() {}),
          ),
          PublishField(
            label: 'Brand',
            hint: 'UrbanHide',
            controller: _brandController,
            onChanged: (_) => setState(() {}),
          ),
          PublishSelectField<String>(
            label: 'Category',
            required: true,
            value: _category,
            items: _categories,
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          PublishField(
            label: 'Short Description',
            required: true,
            hint: 'Describe what makes your product special…',
            controller: _shortDescController,
            maxLength: 500,
            minLines: 4,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      const SizedBox(height: 14),
      PublishSectionCard(
        title: 'Key highlights',
        subtitle: 'A few quick selling points · up to $_maxHighlights',
        icon: LucideIcons.sparkles,
        accent: PublishStyle.purple,
        children: [
          _HighlightsEditor(
            controllers: _highlightControllers,
            max: _maxHighlights,
            hint: 'e.g. Premium full-grain leather for durability',
            onChanged: () => setState(() {}),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const PublishHint(
        text:
            'Tip: listings with 3+ bright photos and a specific name get noticed more often.',
        icon: LucideIcons.wandSparkles,
      ),
    ];
  }

  List<Widget> _priceStep() {
    final mrp = _parseNumber(_mrpController.text);
    final selling = _parseNumber(_sellingPriceController.text);
    final savings = (mrp - selling).clamp(0, double.infinity);
    return [
      const PublishStepIntro(
        title: 'Pricing & inventory',
        subtitle: 'Set a fair price and keep your stock count accurate.',
      ),
      const SizedBox(height: 16),
      PublishSectionCard(
        title: 'Pricing',
        subtitle: 'Selling price and original MRP',
        icon: LucideIcons.tag,
        trailing: _discountPct > 0
            ? PublishPill(
                label: '${_discountPct.toInt()}% OFF',
                color: PublishStyle.success,
              )
            : null,
        children: [
          Row(
            children: [
              Expanded(
                child: PublishField(
                  label: 'MRP',
                  required: true,
                  hint: '0',
                  controller: _mrpController,
                  keyboardType: TextInputType.number,
                  prefixText: '₹ ',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PublishField(
                  label: 'Selling Price',
                  required: true,
                  hint: '0',
                  controller: _sellingPriceController,
                  keyboardType: TextInputType.number,
                  prefixText: '₹ ',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (_discountPct > 0)
            PublishHint(
              text:
                  'Customers save ₹${savings.toStringAsFixed(0)} on every order.',
              icon: LucideIcons.percent,
            ),
        ],
      ),
      const SizedBox(height: 14),
      PublishSectionCard(
        title: 'Inventory',
        subtitle: 'How many units are ready to ship',
        icon: LucideIcons.layers,
        children: [
          Row(
            children: [
              Expanded(
                child: PublishField(
                  label: 'Stock Quantity',
                  required: true,
                  hint: '0',
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PublishField(
                  label: 'Seller SKU',
                  required: true,
                  hint: 'SKU-001',
                  controller: _skuController,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          PublishSelectField<String>(
            label: 'Product Status',
            required: true,
            value: _status,
            items: _statusOptions,
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          PublishSwitchRow(
            title: 'Track inventory',
            subtitle: 'Automatically reduce stock when an order is placed',
            value: _trackInventory,
            onChanged: (value) => setState(() => _trackInventory = value),
          ),
        ],
      ),
      const SizedBox(height: 14),
      PublishSectionCard(
        title: 'Variants',
        subtitle: 'Optional · colour, size and price combinations',
        icon: LucideIcons.palette,
        accent: PublishStyle.purple,
        children: [
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
      const PublishStepIntro(
        title: 'Delivery & publish',
        subtitle:
            'Add shipping details so orders reach customers without surprises.',
      ),
      const SizedBox(height: 16),
      PublishSectionCard(
        title: 'Shipping',
        subtitle: 'Package weight, size and dispatch time',
        icon: LucideIcons.truck,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: PublishField(
                  label: 'Package Weight',
                  required: true,
                  hint: '0.00',
                  controller: _packageWeightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: PublishSelectField<String>(
                  label: 'Unit',
                  value: _weightUnit,
                  items: _weightUnits,
                  onChanged: (value) =>
                      setState(() => _weightUnit = value ?? _weightUnit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          PublishFieldLabel('Dimensions (cm)', required: true),
          Row(
            children: [
              Expanded(
                child: PublishField(
                  label: 'Length',
                  hint: 'L',
                  controller: _dimLController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PublishField(
                  label: 'Width',
                  hint: 'W',
                  controller: _dimWController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PublishField(
                  label: 'Height',
                  hint: 'H',
                  controller: _dimHController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          PublishField(
            label: 'Dispatch Time',
            required: true,
            hint: '1-2 Days',
            controller: _dispatchTimeController,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      const SizedBox(height: 14),
      PublishSectionCard(
        title: 'Compliance & policies',
        subtitle: 'Tax, origin, returns and warranty',
        icon: LucideIcons.shieldCheck,
        children: [
          Row(
            children: [
              Expanded(
                child: PublishField(
                  label: 'HSN / GST',
                  hint: '4202',
                  controller: _hsnController,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PublishSelectField<String>(
                  label: 'Country of Origin',
                  required: true,
                  value: _country,
                  items: _countries,
                  onChanged: (value) =>
                      setState(() => _country = value ?? _country),
                ),
              ),
            ],
          ),
          PublishSelectField<String>(
            label: 'Return Policy',
            required: true,
            value: _returnPolicy,
            items: _returnPolicies,
            onChanged: (value) =>
                setState(() => _returnPolicy = value ?? _returnPolicy),
          ),
          PublishSelectField<String>(
            label: 'Warranty',
            value: _warranty,
            items: _warranties,
            onChanged: (value) =>
                setState(() => _warranty = value ?? _warranty),
          ),
          const SizedBox(height: 2),
          PublishSwitchRow(
            title: 'Use store delivery settings',
            subtitle: 'Reuse the delivery defaults from your store',
            value: _useStoreDelivery,
            onChanged: (value) => setState(() => _useStoreDelivery = value),
          ),
          PublishSwitchRow(
            title: 'Use store return policy',
            subtitle: 'Reuse the return policy from your store',
            value: _useStoreReturnPolicy,
            onChanged: (value) => setState(() => _useStoreReturnPolicy = value),
          ),
        ],
      ),
      const SizedBox(height: 14),
      PublishPreviewCard(
        image: _previewImage(),
        children: [
          if (_brandController.text.trim().isNotEmpty)
            Text(
              _brandController.text.trim().toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PublishStyle.teal,
                fontSize: 9.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          Text(
            _nameController.text.trim().isEmpty
                ? 'Product name'
                : _nameController.text.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PublishStyle.ink,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
          Row(
            children: [
              Text(
                '₹${_sellingPriceController.text.trim().isEmpty ? '0' : _sellingPriceController.text.trim()}',
                style: const TextStyle(
                  color: PublishStyle.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_discountPct > 0) ...[
                const SizedBox(width: 7),
                Text(
                  '₹${_mrpController.text.trim()}',
                  style: const TextStyle(
                    color: PublishStyle.soft,
                    fontSize: 10.5,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          Row(
            children: [
              const Icon(LucideIcons.truck,
                  size: 12, color: PublishStyle.success),
              const SizedBox(width: 4),
              Text(
                _dispatchTimeController.text.trim().isEmpty
                    ? 'Delivery details pending'
                    : 'Dispatches in ${_dispatchTimeController.text.trim()}',
                style: const TextStyle(
                  color: PublishStyle.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 14),
      PublishChecklistCard(items: _checklist),
    ];
  }

  Widget _previewImage() {
    if (_productImages.isEmpty) {
      return Container(
        color: PublishStyle.fieldFill,
        child: const Icon(
          LucideIcons.image,
          size: 26,
          color: PublishStyle.soft,
        ),
      );
    }
    final index = _mainImageIndex.clamp(0, _productImages.length - 1);
    return Image.file(
      File(_productImages[index].path),
      fit: BoxFit.cover,
      cacheWidth: 400,
    );
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

class _PhotoUploadCard extends StatelessWidget {
  final List<XFile> images;
  final int mainIndex;
  final VoidCallback onTap;
  final ValueChanged<int> onRemove;
  final ValueChanged<int>? onSetMain;
  final int maxImages;

  const _PhotoUploadCard({
    required this.images,
    this.mainIndex = 0,
    required this.onTap,
    required this.onRemove,
    this.onSetMain,
    this.maxImages = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return PublishDashedBox(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          height: 190,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.cloudUpload,
                  size: 25,
                  color: PublishStyle.teal,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add product photos',
                style: TextStyle(
                  color: PublishStyle.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Up to $maxImages · the first photo becomes your cover',
                style: TextStyle(
                  color: PublishStyle.soft,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final index = mainIndex.clamp(0, images.length - 1);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 214,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(images[index].path),
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x99000000)],
                      stops: [0.45, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Text(
                      'COVER PHOTO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _RoundOverlayButton(
                    icon: LucideIcons.x,
                    onTap: () => onRemove(index),
                    tooltip: 'Remove cover photo',
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 13,
                  child: Row(
                    children: [
                      const Icon(LucideIcons.image,
                          size: 13, color: Colors.white),
                      const SizedBox(width: 5),
                      const Expanded(
                        child: Text(
                          'Main photo · tap a thumbnail to switch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Add more',
                            style: TextStyle(
                              color: PublishStyle.teal,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 62,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + (images.length < maxImages ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i >= images.length) {
                return PublishDashedBox(
                  onTap: onTap,
                  radius: 16,
                  child: const SizedBox(
                    width: 60,
                    height: 60,
                    child: Icon(LucideIcons.plus,
                        size: 20, color: PublishStyle.teal),
                  ),
                );
              }
              final isMain = i == index;
              return GestureDetector(
                onTap: () => onSetMain?.call(i),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMain
                                ? PublishStyle.teal
                                : PublishStyle.cardBorder,
                            width: isMain ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(images[i].path),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            cacheWidth: 180,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: GestureDetector(
                          onTap: () => onRemove(i),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 12, color: Colors.white),
                          ),
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
}

class _RoundOverlayButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _RoundOverlayButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
      ),
    );
  }
}

class _ProductVariant {
  String color = '#8B5E3C';
  final TextEditingController sizeController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  _ProductVariant();

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
        for (var i = 0; i < controllers.length; i++) ...[
          Row(
            key: ValueKey(controllers[i]),
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PublishStyle.purpleSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: PublishStyle.purple,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controllers[i],
                  cursorColor: PublishStyle.teal,
                  style: const TextStyle(
                    color: PublishStyle.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: publishInputDecoration(hint: hint),
                ),
              ),
              const SizedBox(width: 3),
              IconButton(
                onPressed: () {
                  controllers.removeAt(i);
                  onChanged();
                },
                visualDensity: VisualDensity.compact,
                icon: const Icon(LucideIcons.x,
                    size: 16, color: PublishStyle.soft),
              ),
            ],
          ),
          if (i != controllers.length - 1) const SizedBox(height: 8),
        ],
        if (controllers.length < max) ...[
          const SizedBox(height: 10),
          PublishAddButton(
            label: 'Add highlight',
            onTap: () {
              controllers.add(TextEditingController());
              onChanged();
            },
          ),
        ],
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
        for (var i = 0; i < widget.variants.length; i++) ...[
          Container(
            key: ValueKey(widget.variants[i]),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
            decoration: BoxDecoration(
              color: PublishStyle.fieldFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PublishStyle.fieldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remove variant',
                      icon: const Icon(LucideIcons.trash2,
                          size: 17, color: PublishStyle.soft),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PublishField(
                  label: 'Size',
                  hint: 'One Size',
                  controller: widget.variants[i].sizeController,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PublishField(
                        label: 'Stock',
                        hint: '0',
                        controller: widget.variants[i].stockController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PublishField(
                        label: 'Price',
                        hint: '0',
                        controller: widget.variants[i].priceController,
                        keyboardType: TextInputType.number,
                        prefixText: '₹ ',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        PublishAddButton(
          label: 'Add variant',
          onTap: () {
            setState(() => widget.variants.add(_ProductVariant()));
            widget.onChanged();
          },
        ),
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
