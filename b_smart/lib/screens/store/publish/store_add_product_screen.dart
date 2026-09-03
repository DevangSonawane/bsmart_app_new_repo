import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'store_publish_option_picker.dart';
import '../store_theme.dart';

class StoreAddProductScreen extends StatefulWidget {
  const StoreAddProductScreen({super.key});

  @override
  State<StoreAddProductScreen> createState() => _StoreAddProductScreenState();
}

class _StoreAddProductScreenState extends State<StoreAddProductScreen> {
  static const _categories = [
    'Grocery',
    'Fashion',
    'Mobiles',
    'Electronics',
    'Appliances',
    'Smart Gadgets',
    'Home',
    'Beauty',
    'Bags & Luggage',
    'Footwear',
    'Sports',
    'Toys',
    'Books',
    'Automotive',
    'Other',
  ];

  static const _colorOptions = [
    'Black',
    'White',
    'Blue',
    'Red',
    'Green',
    'Yellow',
    'Brown',
    'Grey',
    'Pink',
    'Purple',
    'Gold',
    'Silver',
    'Other',
  ];

  static const _sizeOptions = [
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'One Size',
    'Free Size',
    '6',
    '7',
    '8',
    '9',
    '10',
    'Other',
  ];

  final _imagePicker = ImagePicker();
  final _productNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productImages = <XFile>[];
  final _colors = <String>[];
  final _sizes = <String>[];
  String? _selectedCategory;

  @override
  void dispose() {
    _productNameController.dispose();
    _brandController.dispose();
    _descriptionController.dispose();
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
                  const _StepProgress(activeStep: 0),
                  const SizedBox(height: 12),
                  const Text(
                    'Product Details',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _FieldLabel('Product Images', requiredField: true),
                  const SizedBox(height: 7),
                  _buildImagesArea(),
                  const SizedBox(height: 12),
                  _InputCard(
                    label: 'Product Name',
                    requiredField: true,
                    controller: _productNameController,
                    maxLength: 100,
                    hintText: 'Enter product name',
                  ),
                  const SizedBox(height: 8),
                  _SelectCard(
                    label: 'Category',
                    requiredField: true,
                    value: _selectedCategory ?? 'Select category',
                    empty: _selectedCategory == null,
                    onTap: _pickCategory,
                  ),
                  const SizedBox(height: 8),
                  _InputCard(
                    label: 'Brand',
                    controller: _brandController,
                    hintText: 'Enter brand name',
                    clearable: true,
                  ),
                  const SizedBox(height: 8),
                  _InputCard(
                    label: 'Short Description',
                    requiredField: true,
                    controller: _descriptionController,
                    maxLength: 200,
                    maxLines: 2,
                    hintText: 'Describe your product',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ChipEditor(
                          label: 'Color',
                          chips: _colors,
                          onAdd: () => _pickChipValue(
                            title: 'Add color',
                            options: _colorOptions,
                            values: _colors,
                          ),
                          onRemove: (value) =>
                              setState(() => _colors.remove(value)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChipEditor(
                          label: 'Size',
                          chips: _sizes,
                          onAdd: () => _pickChipValue(
                            title: 'Add size',
                            options: _sizeOptions,
                            values: _sizes,
                          ),
                          onRemove: (value) =>
                              setState(() => _sizes.remove(value)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildContinueButton(),
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
            '1 of 3',
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

  Widget _buildImagesArea() {
    if (_productImages.isEmpty) {
      return SizedBox(
        height: 120,
        child: _AddImageTile(
          large: true,
          onTap: _pickProductImage,
        ),
      );
    }

    return SizedBox(
      height: 138,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _ProductImagePreview(
              image: _productImages.first,
              onRemove: () => setState(() => _productImages.removeAt(0)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: _AddImageTile(onTap: _pickProductImage)),
                if (_productImages.length > 1) ...[
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _ProductImagePreview(
                            image: _productImages[1],
                            onRemove: () =>
                                setState(() => _productImages.removeAt(1)),
                          ),
                        ),
                        if (_productImages.length > 2) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ProductImagePreview(
                              image: _productImages[2],
                              onRemove: () =>
                                  setState(() => _productImages.removeAt(2)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pushNamed(
            '/store/publish/price-inventory',
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
    );
  }

  Future<void> _pickProductImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      setState(() => _productImages.add(image));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image picker is not available.')),
      );
    }
  }

  Future<void> _pickCategory() async {
    final category = await _showOptionSheet(
      title: 'Select category',
      options: _categories,
      allowCustom: true,
    );
    if (category == null || !mounted) return;
    setState(() => _selectedCategory = category);
  }

  Future<void> _pickChipValue({
    required String title,
    required List<String> options,
    required List<String> values,
  }) async {
    final value = await _showOptionSheet(
      title: title,
      options: options,
      allowCustom: true,
    );
    if (value == null || !mounted || values.contains(value)) return;
    setState(() => values.add(value));
  }

  Future<String?> _showOptionSheet({
    required String title,
    required List<String> options,
    required bool allowCustom,
  }) {
    return showStorePublishOptionPicker(
      context: context,
      title: title,
      options: options,
      allowCustom: allowCustom,
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
                color: index == activeStep
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

class _ProductImagePreview extends StatelessWidget {
  final XFile image;
  final VoidCallback onRemove;

  const _ProductImagePreview({
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(image.path),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            cacheWidth: 720,
          ),
        ),
        Positioned(
          right: -5,
          top: -5,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final VoidCallback onTap;
  final bool large;

  const _AddImageTile({
    required this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD6D6D6)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: StorePalette.blue,
              size: large ? 30 : 24,
            ),
            SizedBox(height: large ? 6 : 4),
            Text(
              'Add Image',
              style: TextStyle(
                color: Colors.black54,
                fontSize: large ? 13 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final String label;
  final bool requiredField;
  final TextEditingController controller;
  final String hintText;
  final int? maxLength;
  final int maxLines;
  final bool clearable;

  const _InputCard({
    required this.label,
    required this.controller,
    required this.hintText,
    this.requiredField = false,
    this.maxLength,
    this.maxLines = 1,
    this.clearable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9DDE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label, requiredField: requiredField),
          const SizedBox(height: 3),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLines: maxLines,
                      maxLength: maxLength,
                      cursorColor: StorePalette.blue,
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: const TextStyle(
                          color: Colors.black38,
                          fontSize: 13,
                        ),
                        counterText: '',
                        filled: false,
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (maxLength != null)
                    Text(
                      '${value.text.length}/$maxLength',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (clearable && value.text.isNotEmpty)
                    GestureDetector(
                      onTap: controller.clear,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SelectCard extends StatelessWidget {
  final String label;
  final bool requiredField;
  final String value;
  final bool empty;
  final VoidCallback onTap;

  const _SelectCard({
    required this.label,
    required this.value,
    required this.onTap,
    this.requiredField = false,
    this.empty = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD9DDE5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel(label, requiredField: requiredField),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: empty ? Colors.black38 : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.black87, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipEditor extends StatelessWidget {
  final String label;
  final List<String> chips;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _ChipEditor({
    required this.label,
    required this.chips,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final chip in chips)
              _ValueChip(label: chip, onRemove: () => onRemove(chip)),
            _AddChip(onTap: onAdd),
          ],
        ),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ValueChip({
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 7),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                color: Colors.black87, size: 14),
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD5D8DE)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.black54, size: 16),
            SizedBox(width: 5),
            Text(
              'Add',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool requiredField;

  const _FieldLabel(this.label, {this.requiredField = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        children: [
          TextSpan(text: label),
          if (requiredField)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFFF314A)),
            ),
          if (!requiredField)
            const TextSpan(
              text: ' (optional)',
              style: TextStyle(color: Colors.black54),
            ),
        ],
      ),
    );
  }
}
