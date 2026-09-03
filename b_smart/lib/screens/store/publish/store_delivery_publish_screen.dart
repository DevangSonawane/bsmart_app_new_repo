import 'package:flutter/material.dart';

import 'store_publish_option_picker.dart';
import '../store_theme.dart';

class StoreDeliveryPublishScreen extends StatefulWidget {
  const StoreDeliveryPublishScreen({super.key});

  @override
  State<StoreDeliveryPublishScreen> createState() =>
      _StoreDeliveryPublishScreenState();
}

class _StoreDeliveryPublishScreenState
    extends State<StoreDeliveryPublishScreen> {
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _hsnController = TextEditingController();

  bool _useDeliverySettings = true;
  bool _useReturnPolicy = true;
  String _dispatchTime = '2 days';
  String _country = 'India';

  @override
  void dispose() {
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _hsnController.dispose();
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
                  const _StepProgress(activeStep: 2),
                  const SizedBox(height: 14),
                  const Text(
                    'Delivery & Publish',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SplitInputRow(
                    label: 'Package Weight',
                    requiredField: true,
                    controller: _weightController,
                    hintText: '0.00',
                    suffix: 'kg',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  _buildDimensionsRow(),
                  const SizedBox(height: 10),
                  _SplitSelectRow(
                    label: 'Dispatch Time',
                    requiredField: true,
                    value: _dispatchTime,
                    onTap: _pickDispatchTime,
                  ),
                  const SizedBox(height: 10),
                  _SplitInputRow(
                    label: 'HSN / GST',
                    controller: _hsnController,
                    hintText: 'HSN / GST rate',
                  ),
                  const SizedBox(height: 10),
                  _SplitSelectRow(
                    label: 'Country of Origin',
                    requiredField: true,
                    value: _country,
                    onTap: _pickCountry,
                  ),
                  const SizedBox(height: 12),
                  _PolicyCheckRow(
                    value: _useDeliverySettings,
                    title: 'Use store delivery settings',
                    subtitle: 'Ships within India',
                    onChanged: (value) =>
                        setState(() => _useDeliverySettings = value ?? false),
                  ),
                  const SizedBox(height: 10),
                  _PolicyCheckRow(
                    value: _useReturnPolicy,
                    title: 'Use store return policy',
                    subtitle: '7-day return eligible',
                    onChanged: (value) =>
                        setState(() => _useReturnPolicy = value ?? false),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  const Text(
                    'Product Preview',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildProductPreview(),
                ],
              ),
            ),
            _buildFooterButtons(),
          ],
        ),
      ),
    );
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
            '3 of 3',
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

  Widget _buildDimensionsRow() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9DDE5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            const _SplitLabel(label: 'Dimensions', requiredField: true),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: _InlineNumberField(
                        controller: _lengthController,
                        hintText: 'L',
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('×', style: TextStyle(fontSize: 14)),
                    ),
                    Expanded(
                      child: _InlineNumberField(
                        controller: _widthController,
                        hintText: 'W',
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('×', style: TextStyle(fontSize: 14)),
                    ),
                    Expanded(
                      child: _InlineNumberField(
                        controller: _heightController,
                        hintText: 'H',
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'cm',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

  Widget _buildProductPreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9DDE5)),
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: const Color(0xFFF6F3EF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Color(0xFFA66332),
              size: 42,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Product name preview',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '₹0',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'MRP ₹0',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.54),
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '0% off',
                      style: TextStyle(
                        color: Color(0xFF22A652),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
                onPressed: _publishProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: StorePalette.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Publish Product',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDispatchTime() async {
    final value = await showStorePublishOptionPicker(
      context: context,
      title: 'Dispatch time',
      options: const ['Same day', '1 day', '2 days', '3 days', '5 days'],
      selectedValue: _dispatchTime,
    );
    if (value == null || !mounted) return;
    setState(() => _dispatchTime = value);
  }

  Future<void> _pickCountry() async {
    final value = await showStorePublishOptionPicker(
      context: context,
      title: 'Country of origin',
      options: const [
        'India',
        'United States',
        'United Kingdom',
        'China',
        'Vietnam',
        'Other',
      ],
      allowCustom: true,
      selectedValue: _country,
    );
    if (value == null || !mounted) return;
    setState(() => _country = value);
  }

  void _publishProduct() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product publishing is coming soon.')),
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
  final String? suffix;
  final TextInputType keyboardType;

  const _SplitInputRow({
    required this.label,
    required this.controller,
    required this.hintText,
    this.requiredField = false,
    this.suffix,
    this.keyboardType = TextInputType.text,
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
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                    ),
                    if (suffix != null)
                      Text(
                        suffix!,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
}

class _SplitSelectRow extends StatelessWidget {
  final String label;
  final bool requiredField;
  final String value;
  final VoidCallback onTap;

  const _SplitSelectRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.requiredField = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
              _SplitLabel(label: label, requiredField: requiredField),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
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
}

class _InlineNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _InlineNumberField({
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      cursorColor: StorePalette.blue,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD9DDE5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFD9DDE5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: StorePalette.blue, width: 1.2),
        ),
      ),
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PolicyCheckRow extends StatelessWidget {
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool?> onChanged;

  const _PolicyCheckRow({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: Checkbox(
            value: value,
            activeColor: StorePalette.blue,
            side: const BorderSide(color: StorePalette.blue, width: 1.2),
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
      width: 124,
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
            fontSize: 12.5,
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
