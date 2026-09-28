import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'shared/store_shared_widgets.dart';
import 'store_address_book.dart';
import 'store_theme.dart';

/// Manage mode (default): add/edit/delete/default.
/// Select mode (`selectMode: true`): picking returns the [ShipAddress] via
/// `Navigator.pop`, used by product checkout and service booking.
class StoreSavedAddressPage extends StatefulWidget {
  final bool selectMode;

  const StoreSavedAddressPage({super.key, this.selectMode = false});

  @override
  State<StoreSavedAddressPage> createState() => _StoreSavedAddressPageState();
}

class _StoreSavedAddressPageState extends State<StoreSavedAddressPage> {
  @override
  void initState() {
    super.initState();
    StoreAddressBook.instance.ensureLoaded();
  }

  Future<void> _openForm({ShipAddress? initial}) async {
    final result = await showAddressFormDialog(context, initial: initial);
    if (result == null || !mounted) return;
    final book = StoreAddressBook.instance;
    if (initial == null) {
      await book.add(result);
    } else {
      await book.update(initial.id, result);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(initial == null ? 'Address added.' : 'Address updated.')),
    );
  }

  Future<void> _confirmDelete(ShipAddress address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text('Remove "${address.label}" (${address.summaryLine})?'),
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
    if (confirm != true || !mounted) return;
    await StoreAddressBook.instance.remove(address.id);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: BStoreTheme.data(context),
      child: Scaffold(
        backgroundColor: BStoreColors.background,
        body: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: StoreAddressBook.instance,
            builder: (context, _) {
              final book = StoreAddressBook.instance;
              final addresses = book.addresses;
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        BStoreSpacing.screenX,
                        8,
                        BStoreSpacing.screenX,
                        MediaQuery.of(context).padding.bottom + 104,
                      ),
                      children: [
                        _AddressHeader(
                            title: widget.selectMode
                                ? 'Select address'
                                : 'Select address'),
                        const SizedBox(height: 14),
                        const _MapPreview(),
                        const SizedBox(height: 20),
                        const Text(
                          'Saved addresses',
                          style: TextStyle(
                            color: BStoreColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final address in addresses) ...[
                          _SavedAddressCard(
                            address: address,
                            selected: book.selected.id == address.id,
                            onTap: () {
                              book.select(address.id);
                              if (widget.selectMode) {
                                Navigator.of(context).pop(address);
                              }
                            },
                            onEdit: () => _openForm(initial: address),
                            onSetDefault: address.isDefault
                                ? null
                                : () => book.setDefault(address.id),
                            onDelete: addresses.length <= 1
                                ? null
                                : () => _confirmDelete(address),
                          ),
                          const SizedBox(height: 9),
                        ],
                        _AddAddressButton(onTap: () => _openForm()),
                      ],
                    ),
                  ),
                  _DeliverHereButton(
                    label: widget.selectMode
                        ? 'Deliver here'
                        : 'Done',
                    onPressed: () {
                      if (widget.selectMode) {
                        Navigator.of(context).pop(book.selected);
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AddressHeader extends StatelessWidget {
  final String title;

  const _AddressHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.chevronLeft, size: 26),
              color: BStoreColors.textPrimary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const StoreBsmartWordmark(),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: BStoreColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BStoreDecorations.card(radius: 18),
      clipBehavior: Clip.antiAlias,
      child: const CustomPaint(
        painter: _MapPreviewPainter(),
        child: Stack(
          children: [
            Positioned(
              left: 112,
              top: 114,
              child: _MapPin(size: 50),
            ),
            Positioned(
              right: 104,
              top: 50,
              child: _MapPin(size: 50),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  const _MapPreviewPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final water = Paint()..color = const Color(0xFFB9E2F1);
    final park = Paint()..color = const Color(0xFFD9EECF);
    final land = Paint()..color = const Color(0xFFF3F0EB);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadThin = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadShadow = Paint()
      ..color = const Color(0xFFE3DFD7)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(Offset.zero & size, land);

    final bay = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.22, 0)
      ..cubicTo(size.width * 0.15, size.height * 0.28, size.width * 0.17,
          size.height * 0.55, size.width * 0.08, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bay, water);

    for (final rect in [
      Rect.fromLTWH(size.width * 0.50, 10, 72, 72),
      Rect.fromLTWH(size.width * 0.74, 20, 110, 72),
      Rect.fromLTWH(size.width * 0.58, size.height * 0.66, 88, 66),
      Rect.fromLTWH(size.width * 0.82, size.height * 0.54, 58, 44),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        park,
      );
    }

    void drawRoad(List<Offset> points, Paint paint) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, roadShadow);
      canvas.drawPath(path, paint);
    }

    for (final x in [0.30, 0.43, 0.60, 0.72, 0.86]) {
      drawRoad([
        Offset(size.width * x, -8),
        Offset(size.width * (x - 0.02), size.height * 0.45),
        Offset(size.width * (x + 0.01), size.height + 8),
      ], roadThin);
    }

    for (final y in [0.18, 0.38, 0.58, 0.78]) {
      drawRoad([
        Offset(size.width * 0.08, size.height * y),
        Offset(size.width * 0.44, size.height * (y - 0.03)),
        Offset(size.width * 0.95, size.height * (y + 0.01)),
      ], y == 0.58 ? road : roadThin);
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    void drawLabel(String text, Offset offset, double angle) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(angle);
      textPainter.text = TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.62),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
      canvas.restore();
    }

    drawLabel('Market St', Offset(size.width * 0.46, size.height * 0.41), -0.1);
    drawLabel('1st Ave', Offset(size.width * 0.70, size.height * 0.34), 1.52);
    drawLabel(
        'Kettner Blvd', Offset(size.width * 0.43, size.height * 0.70), 1.55);
    drawLabel('Marina', Offset(size.width * 0.92, size.height * 0.48), 0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapPin extends StatelessWidget {
  final double size;

  const _MapPin({required this.size});

  @override
  Widget build(BuildContext context) {
    return Icon(
      LucideIcons.mapPin,
      color: BStoreColors.primary,
      size: size,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

class _SavedAddressCard extends StatelessWidget {
  final ShipAddress address;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onSetDefault;
  final VoidCallback? onDelete;

  const _SavedAddressCard({
    required this.address,
    required this.selected,
    required this.onTap,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 14, 11, 14),
        decoration: BStoreDecorations.card(radius: 18),
        child: Row(
          children: [
            _AddressRadio(selected: selected),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          color: BStoreColors.primary, size: 23),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          address.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BStoreColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        const _DefaultBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    address.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.summaryLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BStoreColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(LucideIcons.pencil, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: BStoreColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                  onSelected: (value) {
                    if (value == 'default') onSetDefault?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    if (onSetDefault != null)
                      const PopupMenuItem(
                        value: 'default',
                        child: Text('Set as default'),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressRadio extends StatelessWidget {
  final bool selected;

  const _AddressRadio({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 25,
      height: 25,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? BStoreColors.primary : BStoreColors.textMuted,
          width: selected ? 2.2 : 1.2,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? BStoreColors.primary : Colors.transparent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BStoreColors.accentPurpleSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Default',
        style: TextStyle(
          color: BStoreColors.accentPurple,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AddAddressButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddAddressButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const CustomPaint(
          painter: _DashedBorderPainter(),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.circlePlus,
                  color: BStoreColors.primary,
                  size: 21,
                ),
                SizedBox(width: 10),
                Text(
                  'Add new address',
                  style: TextStyle(
                    color: BStoreColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = BStoreColors.primary
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 2.8).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 5.2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DeliverHereButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DeliverHereButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BStoreColors.background,
      padding: EdgeInsets.fromLTRB(
        BStoreSpacing.screenX,
        12,
        BStoreSpacing.screenX,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: onPressed,
          style: BStoreButtons.filled(radius: 10),
          child: Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

/// Store-themed popup dialog for adding/editing an address.
///
/// Returns the saved [ShipAddress], or null when dismissed.
Future<ShipAddress?> showAddressFormDialog(
  BuildContext context, {
  ShipAddress? initial,
}) {
  return showDialog<ShipAddress>(
    context: context,
    builder: (dialogContext) => Theme(
      data: BStoreTheme.data(dialogContext),
      child: Dialog(
        backgroundColor: BStoreColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: _AddressFormSheet(initial: initial),
      ),
    ),
  );
}

class _AddressFormSheet extends StatefulWidget {
  final ShipAddress? initial;

  const _AddressFormSheet({required this.initial});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  late final TextEditingController _label;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _line1;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _pincode;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _label = TextEditingController(text: initial?.label ?? 'Home');
    _name = TextEditingController(text: initial?.name ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _line1 = TextEditingController(text: initial?.line1 ?? '');
    _city = TextEditingController(text: initial?.city ?? '');
    _state = TextEditingController(text: initial?.state ?? '');
    _pincode = TextEditingController(text: initial?.pincode ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    _name.dispose();
    _phone.dispose();
    _line1.dispose();
    _city.dispose();
    _state.dispose();
    _pincode.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final line1 = _line1.text.trim();
    final city = _city.text.trim();
    final pincode = _pincode.text.trim();
    if (name.isEmpty ||
        phone.isEmpty ||
        line1.isEmpty ||
        city.isEmpty ||
        pincode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill name, phone, address, city and pincode.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      ShipAddress(
        id: widget.initial?.id ?? '',
        label: _label.text.trim().isEmpty ? 'Home' : _label.text.trim(),
        name: name,
        phone: phone,
        line1: line1,
        city: city,
        state: _state.text.trim(),
        pincode: pincode,
        isDefault: widget.initial?.isDefault ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initial == null ? 'Add address' : 'Edit address',
                    style: const TextStyle(
                      color: BStoreColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(LucideIcons.x, size: 20),
                  color: BStoreColors.textSecondary,
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 8),
            _AddressTextField(controller: _label, label: 'Label (Home / Work)'),
            const SizedBox(height: 10),
            _AddressTextField(controller: _name, label: 'Full name'),
            const SizedBox(height: 10),
            _AddressTextField(
              controller: _phone,
              label: 'Phone',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            _AddressTextField(controller: _line1, label: 'Address line'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AddressTextField(controller: _city, label: 'City'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AddressTextField(controller: _state, label: 'State'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _AddressTextField(
              controller: _pincode,
              label: 'Pincode',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: BStoreButtons.outlined(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: BStoreButtons.filled(),
                    child: Text(widget.initial == null
                        ? 'Save address'
                        : 'Update address'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  const _AddressTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    // Pinned light styling: the store has no dark mode.
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: BStoreColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: BStoreColors.textMuted),
        hintStyle: const TextStyle(color: BStoreColors.textMuted),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BStoreColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BStoreColors.primary),
        ),
      ),
    );
  }
}
