import 'package:flutter/material.dart';

import '../store_theme.dart';

Future<String?> showStorePublishOptionPicker({
  required BuildContext context,
  required String title,
  required List<String> options,
  bool allowCustom = false,
  String? selectedValue,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.18),
    barrierDismissible: true,
    barrierLabel: 'Close',
    transitionDuration: const Duration(milliseconds: 90),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _StorePublishOptionPicker(
        title: title,
        options: options,
        allowCustom: allowCustom,
        selectedValue: selectedValue,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _StorePublishOptionPicker extends StatefulWidget {
  final String title;
  final List<String> options;
  final bool allowCustom;
  final String? selectedValue;

  const _StorePublishOptionPicker({
    required this.title,
    required this.options,
    required this.allowCustom,
    this.selectedValue,
  });

  @override
  State<_StorePublishOptionPicker> createState() =>
      _StorePublishOptionPickerState();
}

class _StorePublishOptionPickerState extends State<_StorePublishOptionPicker> {
  final _customController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.68,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                Flexible(child: _buildOptionList(context)),
                if (_showCustomInput) _buildCustomInput(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      shrinkWrap: true,
      itemCount: widget.options.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
      itemBuilder: (context, index) {
        final option = widget.options[index];
        final selected = option == widget.selectedValue;
        return InkWell(
          onTap: () {
            if (option == 'Other' && widget.allowCustom) {
              setState(() => _showCustomInput = true);
              return;
            }
            Navigator.of(context).pop(option);
          },
          child: SizedBox(
            height: 38,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (option == 'Other' && widget.allowCustom)
                  const Icon(Icons.edit_rounded, size: 17),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    color: StorePalette.blue,
                    size: 20,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomInput(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        6,
        16,
        MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _customController,
              autofocus: true,
              cursorColor: StorePalette.blue,
              decoration: InputDecoration(
                hintText: 'Type custom value',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: const BorderSide(
                    color: StorePalette.blue,
                    width: 1.3,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _submitCustomValue,
              style: ElevatedButton.styleFrom(
                backgroundColor: StorePalette.blue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitCustomValue() {
    final value = _customController.text.trim();
    if (value.isNotEmpty) Navigator.of(context).pop(value);
  }
}
