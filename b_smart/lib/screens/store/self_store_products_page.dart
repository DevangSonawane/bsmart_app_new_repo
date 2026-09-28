import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../api/upload_api.dart';
import '../../utils/url_helper.dart';
import 'store_models.dart';
import 'store_role_setup_screen.dart';
import 'store_theme.dart';
import 'shared/store_image_editor.dart';
import 'shared/store_shared_widgets.dart';

class SelfStoreProductsPage extends StatefulWidget {
  const SelfStoreProductsPage({super.key});

  @override
  State<SelfStoreProductsPage> createState() => _SelfStoreProductsPageState();
}

class SelfStoreProductsScreen extends StatelessWidget {
  const SelfStoreProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFC),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const StoreRoleGateSliver(child: SelfStoreProductsPage()),
            SliverToBoxAdapter(
              child:
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 18),
            ),
          ],
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
    _productsFuture = Phase2StoreApi().myProducts();
  }

  void _refreshProducts() {
    setState(() => _productsFuture = Phase2StoreApi().myProducts());
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
          child: _ProductTabs(
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
              final status = _text(product, const ['status']).toLowerCase();
              final stock = _number(product, const ['stock_quantity']);
              return switch (_selectedTab) {
                0 => status != 'draft' && stock > 0,
                1 => status == 'draft',
                _ => stock <= 0,
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
            child: _AddProductButton(
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

class _ProductTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ProductTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: SizedBox(
                    height: 35,
                    child: Center(
                      child: Text(
                        tabs[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: i == selectedIndex
                              ? const Color(0xFF078D92)
                              : const Color(0xFF29304D),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Stack(
          children: [
            const Divider(height: 1, color: Color(0xFFE1E5EA)),
            FractionallySizedBox(
              widthFactor: 1 / tabs.length,
              alignment:
                  Alignment(-1 + (2 * selectedIndex / (tabs.length - 1)), 0),
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0xFF078D92),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
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
      price:
          '₹${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}',
      stockLabel:
          stock <= 5 && stock > 0 ? 'Low stock' : '${stock.round()} in stock',
      stockState: stock <= 5 ? _StockState.low : _StockState.ok,
      productId: _text(product, const ['id', '_id']),
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
                    TextButton(
                      onPressed: productId.isEmpty
                          ? null
                          : () => _showEditProductSheet(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF078D92),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(54, 34),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(LucideIcons.chevronRight, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    List<Map<String, dynamic>> images =
        StoreImageEditor.entriesOf(raw);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => Theme(
        data: BStoreTheme.data(sheetContext),
        child: StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            MediaQuery.of(sheetContext).viewInsets.bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Selling price (₹)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Stock quantity', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: status == 'draft' ? 'draft' : 'active',
                decoration: const InputDecoration(
                    labelText: 'Status', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'draft', child: Text('Draft')),
                ],
                onChanged: (v) =>
                    setSheetState(() => status = v ?? status),
              ),
              const SizedBox(height: 10),
              StoreImageEditor(
                initial: images,
                minCount: 1,
                onChanged: (next) => images = next,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop('delete'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop('save'),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      if (result == 'delete') {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Delete product?'),
            content: Text('Remove "$title" from your store?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(d).pop(false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.of(d).pop(true),
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
          const SnackBar(
              content: Text('Products need at least one image.')),
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

class _AddProductButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddProductButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text(
          'Add Product',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF078D92),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          elevation: 8,
          shadowColor: const Color(0xFF078D92).withValues(alpha: 0.24),
        ),
      ),
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
  int _step = 1;
  bool _freeDelivery = false;
  bool _publishing = false;
  final _imagePicker = ImagePicker();
  XFile? _productImage;
  final _productNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0.00');
  final _stockController = TextEditingController(text: '0');
  final _shippingFeeController = TextEditingController(text: '5.00');
  final _lowStockController = TextEditingController(text: '5');
  String? _category;
  String _deliveryMethod = 'Standard shipping';
  String _packageSize = 'Medium (30x20x15 cm)';
  String _processingTime = '1-2 business days';

  @override
  void dispose() {
    _productNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _shippingFeeController.dispose();
    _lowStockController.dispose();
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
              title: _step == 1 ? 'Add Product' : 'Delivery & publish',
              onBack: () {
                if (_step == 1) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _step = 1);
                }
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                children: _step == 1 ? _detailsStep() : _deliveryStep(),
              ),
            ),
            _FlowFooter(
              step: _step,
              onContinue: () => setState(() => _step = 2),
              publishing: _publishing,
              onPublish: _publishProduct,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _detailsStep() {
    return [
      const _StepHeading(stepText: '1 of 2', title: 'Details'),
      const SizedBox(height: 14),
      _PhotoUploadCard(
        image: _productImage,
        onTap: _pickProductImage,
        onRemove: () => setState(() => _productImage = null),
      ),
      const SizedBox(height: 12),
      _FormPanel(
        children: [
          _TextFieldShell(
            label: 'Product name',
            hint: 'Enter product name',
            controller: _productNameController,
          ),
          const SizedBox(height: 14),
          _DropdownShell<String>(
            label: 'Category',
            value: _category,
            hint: 'Select category',
            items: const [
              'Home',
              'Beauty',
              'Wellness',
              'Stationery',
              'Electronics',
            ],
            onChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 14),
          _TextFieldShell(
            label: 'Description',
            hint: 'Describe your product',
            controller: _descriptionController,
            minHeight: 76,
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TextFieldShell(
                  label: 'Price',
                  hint: '0.00',
                  controller: _priceController,
                  prefixText: r'$ ',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TextFieldShell(
                  label: 'Stock quantity',
                  hint: '0',
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  List<Widget> _deliveryStep() {
    return [
      const _StepHeading(stepText: '2 of 2', title: 'Delivery & publish'),
      const SizedBox(height: 16),
      _FormPanel(
        children: [
          _DropdownShell<String>(
            label: 'Delivery method',
            value: _deliveryMethod,
            items: const [
              'Standard shipping',
              'Express shipping',
              'Local pickup',
            ],
            onChanged: (value) => setState(
              () => _deliveryMethod = value ?? _deliveryMethod,
            ),
          ),
          const SizedBox(height: 14),
          _DropdownShell<String>(
            label: 'Package size',
            value: _packageSize,
            items: const [
              'Small (20x15x8 cm)',
              'Medium (30x20x15 cm)',
              'Large (45x35x25 cm)',
            ],
            onChanged: (value) => setState(
              () => _packageSize = value ?? _packageSize,
            ),
          ),
          const SizedBox(height: 14),
          _DropdownShell<String>(
            label: 'Processing time',
            value: _processingTime,
            items: const [
              'Same day',
              '1-2 business days',
              '3-5 business days',
            ],
            onChanged: (value) => setState(
              () => _processingTime = value ?? _processingTime,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _FormPanel(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _TextFieldShell(
                  label: 'Shipping fee',
                  hint: '5.00',
                  controller: _shippingFeeController,
                  prefixText: r'$ ',
                  keyboardType: TextInputType.number,
                  enabled: !_freeDelivery,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Flexible(
                      child: Text(
                        'Free delivery',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF29304D),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: _freeDelivery,
                      onChanged: (value) => setState(() {
                        _freeDelivery = value;
                        if (value) _shippingFeeController.text = '0.00';
                      }),
                      activeThumbColor: const Color(0xFF078D92),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 12),
      _FormPanel(
        children: [
          _TextFieldShell(
            label: 'Low-stock alert',
            subtitle: 'Get notified when stock reaches this level',
            hint: '5',
            controller: _lowStockController,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    ];
  }

  Future<void> _pickProductImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      setState(() => _productImage = image);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image picker is not available.')),
      );
    }
  }

  Future<void> _publishProduct() async {
    final name = _productNameController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _category?.trim();
    final image = _productImage;
    final price = _parseNumber(_priceController.text);
    final stock = _parseNumber(_stockController.text).round();
    if (name.isEmpty ||
        description.isEmpty ||
        category == null ||
        category.isEmpty ||
        image == null ||
        price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add image, name, category, description and price.'),
        ),
      );
      return;
    }
    setState(() => _publishing = true);
    try {
      final upload = await UploadApi().uploadPromoteProductFile(image.path);
      final imageName = _firstUploadName(upload);
      await Phase2StoreApi().createProduct({
        'images': [
          {'fileName': imageName},
        ],
        'name': name,
        'category': category,
        'brand': 'B-Smart',
        'short_description': description,
        'key_highlights': const ['Published from B-Smart Store'],
        'mrp': price,
        'selling_price': price,
        'stock_quantity': stock,
        'seller_sku': 'SKU-${DateTime.now().millisecondsSinceEpoch}',
        'track_inventory': true,
        'status': 'active',
        'variants': const [],
        'package_weight': 1,
        'weight_unit': 'kg',
        'dimensions': const {
          'length': 30,
          'width': 20,
          'height': 10,
          'unit': 'cm',
        },
        'dispatch_time': _processingTime,
        'hsn_gst': '',
        'country_of_origin': 'India',
        'return_policy': '7 Days Replacement',
        'use_store_delivery_settings': _freeDelivery,
        'use_store_return_policy': true,
        'warranty': 'None',
      });
      await StoreMockState.instance.refreshMarketplace();
      widget.onPublished?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product published.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }
}

class _FlowHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _FlowHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        MediaQuery.of(context).padding.top + 10,
        18,
        0,
      ),
      child: SizedBox(
        height: 38,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(LucideIcons.chevronLeft, size: 24),
                color: const Color(0xFF060D35),
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF060D35),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
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
  final XFile? image;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PhotoUploadCard({
    required this.image,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final selectedImage = image;
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
        child: selectedImage == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.cloudUpload,
                      color: Color(0xFF684AC8), size: 36),
                  SizedBox(height: 9),
                  Text(
                    'Add product photo',
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
                  Image.file(File(selectedImage.path), fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: const CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.black87,
                        child: Icon(Icons.close_rounded,
                            color: Colors.white, size: 17),
                      ),
                    ),
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
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
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
          icon: const Icon(LucideIcons.chevronDown, size: 17),
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
  final VoidCallback onContinue;
  final VoidCallback onPublish;
  final bool publishing;

  const _FlowFooter({
    required this.step,
    required this.onContinue,
    required this.onPublish,
    this.publishing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (step == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF078D92),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF078D92),
                  side: const BorderSide(color: Color(0xFF078D92)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Preview',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: publishing ? null : onPublish,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF078D92),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: publishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Publish Product',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900),
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

double _parseNumber(String value) {
  return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
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

String _imageUrl(Map<String, dynamic> json) {
  final images = json['images'];
  dynamic first;
  if (images is List && images.isNotEmpty) first = images.first;
  if (first is Map) {
    return UrlHelper.absoluteUrl(_text(
      first.map((key, value) => MapEntry(key.toString(), value)),
      const ['url', 'fileName', 'filename', 'path', 'src'],
    ));
  }
  if (first is String) return UrlHelper.absoluteUrl(first);
  return '';
}

String _firstUploadName(Map<String, dynamic> upload) {
  final direct = _text(upload, const ['fileName', 'filename', 'path', 'url']);
  if (direct.isNotEmpty) return direct;
  final data = upload['data'];
  if (data is Map) {
    final nested = _text(
      data.map((key, value) => MapEntry(key.toString(), value)),
      const ['fileName', 'filename', 'path', 'url'],
    );
    if (nested.isNotEmpty) return nested;
  }
  final files = upload['files'];
  if (files is List && files.isNotEmpty && files.first is Map) {
    final nested = _text(
      (files.first as Map).map((key, value) => MapEntry(key.toString(), value)),
      const ['fileName', 'filename', 'path', 'url'],
    );
    if (nested.isNotEmpty) return nested;
  }
  throw StateError('Upload did not return a file name.');
}
