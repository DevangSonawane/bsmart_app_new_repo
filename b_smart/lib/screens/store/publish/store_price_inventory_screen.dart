import 'package:flutter/material.dart';

import 'store_publish_option_picker.dart';
import '../store_theme.dart';

class StorePriceInventoryScreen extends StatefulWidget {
  const StorePriceInventoryScreen({super.key});

  @override
  State<StorePriceInventoryScreen> createState() =>
      _StorePriceInventoryScreenState();
}

class _StorePriceInventoryScreenState extends State<StorePriceInventoryScreen> {
  final _mrpController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _skuController = TextEditingController();
  bool _trackInventory = true;
  String _productStatus = 'Active';

  @override
  void dispose() {
    _mrpController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                children: [
                  const _StepProgress(activeStep: 1),
                  const SizedBox(height: 14),
                  const Text(
                    'Price & Inventory',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SplitInputRow(
                    label: 'MRP',
                    requiredField: true,
                    controller: _mrpController,
                    hintText: '₹0',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _SplitInputRow(
                    label: 'Selling Price',
                    requiredField: true,
                    controller: _sellingPriceController,
                    hintText: '₹0',
                    keyboardType: TextInputType.number,
                    helperBuilder: () => _discountText,
                    helperListenable: Listenable.merge([
                      _mrpController,
                      _sellingPriceController,
                    ]),
                  ),
                  const SizedBox(height: 10),
                  _SplitInputRow(
                    label: 'Stock Quantity',
                    requiredField: true,
                    controller: _stockController,
                    hintText: '0',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _SplitInputRow(
                    label: 'Seller SKU',
                    requiredField: true,
                    controller: _skuController,
                    hintText: 'Unique SKU',
                    helper: 'Unique identifier for your product',
                  ),
                  const SizedBox(height: 10),
                  _buildTrackInventoryCard(),
                  const SizedBox(height: 18),
                  const Text(
                    'Variants (optional)',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildVariantCard(),
                  const SizedBox(height: 10),
                  _buildStatusPicker(),
                ],
              ),
            ),
            _buildFooterButtons(),
          ],
        ),
      ),
    );
  }

  String? get _discountText {
    final mrp = double.tryParse(_digitsOnly(_mrpController.text));
    final selling = double.tryParse(_digitsOnly(_sellingPriceController.text));
    if (mrp == null || selling == null || mrp <= 0 || selling <= 0) return null;
    if (selling >= mrp) return 'No discount';
    final discount = ((mrp - selling) / mrp * 100).round();
    return '$discount% off';
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9.]'), '');
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: StorePalette.blue,
      padding: EdgeInsets.fromLTRB(
        6,
        MediaQuery.of(context).padding.top + 8,
        14,
        10,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Add Product',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Text(
            '2 of 3',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackInventoryCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9DDE5)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track Inventory',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Automatically deduct stock on order',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _trackInventory,
            activeThumbColor: StorePalette.blue,
            activeTrackColor: StorePalette.blue.withValues(alpha: 0.28),
            onChanged: (value) => setState(() => _trackInventory = value),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9DDE5)),
      ),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0xFF8A563B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Brown',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(width: 1, height: 24, color: const Color(0xFFD9DDE5)),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'One Size',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () => _showComingSoon('Variant editor'),
            style: OutlinedButton.styleFrom(
              foregroundColor: StorePalette.blue,
              side: const BorderSide(color: StorePalette.blue, width: 1.2),
              minimumSize: const Size(58, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Edit',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPicker() {
    return InkWell(
      onTap: _pickStatus,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD9DDE5)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              const _SplitLabel(label: 'Product Status', requiredField: true),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _productStatus,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 21),
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

  Widget _buildFooterButtons() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: StorePalette.blue,
                  side: const BorderSide(color: StorePalette.blue, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed(
                  '/store/publish/delivery',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StorePalette.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStatus() async {
    final status = await showStorePublishOptionPicker(
      context: context,
      title: 'Product status',
      options: const ['Active', 'Draft', 'Inactive'],
      selectedValue: _productStatus,
    );
    if (status == null || !mounted) return;
    setState(() => _productStatus = status);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int activeStep;

  const _StepProgress({required this.activeStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < 3; index++) ...[
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: index <= activeStep
                    ? const Color(0xFFFFC400)
                    : const Color(0xFFE4E4E4),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (index != 2) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _SplitInputRow extends StatelessWidget {
  final String label;
  final bool requiredField;
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final String? helper;
  final Listenable? helperListenable;
  final String? Function()? helperBuilder;

  const _SplitInputRow({
    required this.label,
    required this.controller,
    required this.hintText,
    this.requiredField = false,
    this.keyboardType = TextInputType.text,
    this.helper,
    this.helperListenable,
    this.helperBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9DDE5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _SplitLabel(label: label, requiredField: requiredField),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      cursorColor: StorePalette.blue,
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: const TextStyle(
                          color: Colors.black38,
                          fontSize: 14,
                        ),
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _SplitInputHelper(
                      helper: helper,
                      helperListenable: helperListenable,
                      helperBuilder: helperBuilder,
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
}

class _SplitInputHelper extends StatelessWidget {
  final String? helper;
  final Listenable? helperListenable;
  final String? Function()? helperBuilder;

  const _SplitInputHelper({
    this.helper,
    this.helperListenable,
    this.helperBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final listenable = helperListenable;
    if (listenable == null) {
      return _HelperText(helper: helper);
    }
    return AnimatedBuilder(
      animation: listenable,
      builder: (_, __) => _HelperText(helper: helperBuilder?.call() ?? helper),
    );
  }
}

class _HelperText extends StatelessWidget {
  final String? helper;

  const _HelperText({required this.helper});

  @override
  Widget build(BuildContext context) {
    final text = helper;
    if (text == null) return const SizedBox.shrink();
    final isDiscount = text.contains('off');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDiscount ? const Color(0xFF22A652) : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (isDiscount) ...[
            const SizedBox(width: 8),
            const Icon(Icons.info_outline_rounded,
                color: Colors.black54, size: 15),
          ],
        ],
      ),
    );
  }
}

class _SplitLabel extends StatelessWidget {
  final String label;
  final bool requiredField;

  const _SplitLabel({
    required this.label,
    required this.requiredField,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFD9DDE5)),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(text: label),
            if (requiredField)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: Color(0xFFFF314A)),
              ),
          ],
        ),
      ),
    );
  }
}
