import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../api/phase2_store_api.dart';
import '../../api/upload_api.dart';
import '../../widgets/safe_network_image.dart';
import 'publish/store_publish_ui.dart';
import 'store_theme.dart';
import 'shared/store_shared_widgets.dart';

/// Entry point used by the store home "Add service" action.
///
/// The publishing flow is also exposed through [SelfStoreServicesManageScreen]
/// for the existing dashboard shortcuts.
class StoreAddServiceFlowScreen extends SelfStoreServicesManageScreen {
  const StoreAddServiceFlowScreen({super.key});
}

class SelfStoreServicesManageScreen extends StatefulWidget {
  const SelfStoreServicesManageScreen({super.key});

  @override
  State<SelfStoreServicesManageScreen> createState() =>
      _SelfStoreServicesManageScreenState();
}

class _SelfStoreServicesManageScreenState
    extends State<SelfStoreServicesManageScreen> {
  static const _categories = [
    'Home Services',
    'Business Consulting',
    'Health & Wellness',
    'Photography',
    'Delivery',
    'Education',
    'Other',
  ];
  static const _rateTypes = [
    'Starting from',
    'Fixed price',
    'Per hour',
    'Per session',
  ];
  static const _durations = [
    '30 minutes',
    '1 hour',
    '2 hours',
    '2–3 hours',
    'Half day',
    'Full day',
  ];
  static const _methods = [
    'At customer location',
    'Online',
    'At my location',
  ];
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _maxImages = 10;
  static const _maxHighlights = 5;

  int _step = 1;
  bool _publishing = false;
  bool _hasVariants = false;
  bool _allowMultiple = false;
  bool _visible = true;
  int _mainImageIndex = 0;
  String _method = 'At customer location';
  String _category = 'Home Services';
  String _duration = '1 hour';
  String _rateType = 'Starting from';
  String _serviceStart = '09:00';
  String _serviceEnd = '17:00';
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _providerController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  final List<TextEditingController> _highlightControllers = [
    TextEditingController(),
  ];
  final List<_ServiceSubservice> _subservices = [_ServiceSubservice()];
  final List<TextEditingController> _serviceAreaControllers = [
    TextEditingController(),
  ];
  final List<_AvailDay> _availability = [
    for (var i = 0; i < _days.length; i++)
      _AvailDay(_days[i], [if (i < 5) _Slot('09:00', '17:00')]),
  ];
  final List<XFile> _pendingImages = [];
  final List<UploadedImage> _coverImages = [];

  static const _flowSteps = [
    PublishStep(
      label: 'Details',
      subtitle: 'Photos, name & description',
      icon: LucideIcons.image,
    ),
    PublishStep(
      label: 'Pricing',
      subtitle: 'Rate, duration & variants',
      icon: LucideIcons.tag,
    ),
    PublishStep(
      label: 'Availability',
      subtitle: 'Hours, areas & publish',
      icon: LucideIcons.calendarDays,
    ),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    for (final controller in _highlightControllers) {
      controller.dispose();
    }
    for (final controller in _serviceAreaControllers) {
      controller.dispose();
    }
    for (final subservice in _subservices) {
      subservice.dispose();
    }
    super.dispose();
  }

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
                eyebrow: 'Seller studio · services',
                title: 'Add Service',
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
                onSaveDraft:
                    _publishing ? null : () => _saveService(draft: true),
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
                            ? _pricingStep()
                            : _availabilityStep(),
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
                    _saveService(draft: false);
                  }
                },
                primaryLabel: _step < 3 ? 'Continue' : 'Publish service',
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

  bool get _hasAnyHighlight =>
      _highlightControllers.any((c) => c.text.trim().isNotEmpty);

  bool get _hasPricedVariant => _subservices.any((s) =>
      s.nameController.text.trim().isNotEmpty &&
      (double.tryParse(s.priceController.text.trim()) ?? 0) > 0);

  bool get _hasArea =>
      _serviceAreaControllers.any((c) => c.text.trim().isNotEmpty);

  bool get _hasAvailabilitySlot => _availability.any((d) => d.slots.isNotEmpty);

  double get _completion {
    var done = 0;
    if (_nameController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _hasAnyHighlight) {
      done++;
    }
    if ((_hasVariants
        ? _hasPricedVariant
        : _priceController.text.trim().isNotEmpty)) {
      done++;
    }
    if (_serviceStart.isNotEmpty &&
        _serviceEnd.isNotEmpty &&
        _hasArea &&
        _hasAvailabilitySlot &&
        (_method != 'At my location' ||
            _addressController.text.trim().isNotEmpty)) {
      done++;
    }
    return done / 3;
  }

  List<PublishChecklistItem> get _checklist => [
        PublishChecklistItem(
          'Service details & highlights',
          _nameController.text.trim().isNotEmpty &&
              _descriptionController.text.trim().isNotEmpty &&
              _hasAnyHighlight,
        ),
        PublishChecklistItem(
          _hasVariants ? 'At least one priced variant' : 'Price & duration',
          _hasVariants
              ? _hasPricedVariant
              : _priceController.text.trim().isNotEmpty,
        ),
        PublishChecklistItem(
          'Hours, areas & availability',
          _serviceStart.isNotEmpty &&
              _serviceEnd.isNotEmpty &&
              _hasArea &&
              _hasAvailabilitySlot &&
              (_method != 'At my location' ||
                  _addressController.text.trim().isNotEmpty),
        ),
      ];

  String get _previewPrice {
    if (_hasVariants) {
      var min = double.infinity;
      for (final s in _subservices) {
        final p = double.tryParse(s.priceController.text.trim()) ?? 0;
        if (p > 0 && p < min) min = p;
      }
      if (min == double.infinity) return 'Pricing not set';
      return 'From ₹${min.toStringAsFixed(0)}';
    }
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final amount = '₹${price.toStringAsFixed(0)}';
    return switch (_rateType) {
      'Per hour' => '$amount / hour',
      'Per session' => '$amount / session',
      'Starting from' => 'From $amount',
      _ => amount,
    };
  }

  Widget _previewImage() {
    final total = _totalImageCount;
    if (total == 0) {
      return Container(
        color: PublishStyle.fieldFill,
        child: const Icon(
          LucideIcons.image,
          size: 26,
          color: PublishStyle.soft,
        ),
      );
    }
    final index = _mainImageIndex.clamp(0, total - 1);
    if (index < _pendingImages.length) {
      return FutureBuilder<Uint8List>(
        future: _pendingImages[index].readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const ColoredBox(color: PublishStyle.fieldFill);
          }
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        },
      );
    }
    final image = _coverImages[index - _pendingImages.length];
    return StoreItemImage(
      imageUrl: image.fileUrl.isNotEmpty ? image.fileUrl : image.fileName,
      icon: LucideIcons.image,
      fit: BoxFit.cover,
    );
  }

  List<Widget> _detailsStep() {
    return [
      const PublishStepIntro(
        title: 'Service details',
        subtitle:
            'Show what you offer with great photos and a clear description.',
      ),
      const SizedBox(height: 16),
      _ServicePhotoCard(
        pending: _pendingImages,
        uploaded: _coverImages,
        mainIndex: _mainImageIndex,
        onPick: _pickServiceImages,
        onSetMain: (i) => setState(() => _mainImageIndex = i),
        onRemovePending: (i) => setState(() {
          _pendingImages.removeAt(i);
          if (_mainImageIndex >= _totalImageCount) _mainImageIndex = 0;
        }),
        onRemoveUploaded: (i) => setState(() {
          _coverImages.removeAt(i); // index within uploaded list
          if (_mainImageIndex >= _totalImageCount) _mainImageIndex = 0;
        }),
      ),
      if (_totalImageCount > 0) ...[
        const SizedBox(height: 8),
        Text(
          '$_totalImageCount/$_maxImages photos · tap a photo to make it the main one',
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
        subtitle: 'What customers see first',
        icon: LucideIcons.briefcaseBusiness,
        children: [
          PublishField(
            label: 'Service Name',
            required: true,
            hint: 'Home Cleaning',
            controller: _nameController,
            maxLength: 150,
            onChanged: (_) => setState(() {}),
          ),
          PublishField(
            label: 'Provider',
            hint: 'Your business name',
            controller: _providerController,
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
            hint: 'Describe what your service includes…',
            controller: _descriptionController,
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
        subtitle: 'Quick reasons to book · up to $_maxHighlights',
        icon: LucideIcons.sparkles,
        accent: PublishStyle.purple,
        children: [
          _ServiceHighlightsEditor(
            controllers: _highlightControllers,
            max: _maxHighlights,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const PublishHint(
        text:
            'Tip: list exactly what is included — equipment, time and any extras.',
        icon: LucideIcons.wandSparkles,
      ),
    ];
  }

  List<Widget> _pricingStep() {
    return [
      const PublishStepIntro(
        title: 'Pricing',
        subtitle:
            'Pick a flat rate, or let customers choose from service variants.',
      ),
      const SizedBox(height: 16),
      PublishSectionCard(
        title: 'Pricing mode',
        subtitle: 'Choose how customers pick this service',
        icon: LucideIcons.layers,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: PublishChoiceCard(
                    icon: LucideIcons.tag,
                    title: 'Flat price',
                    subtitle: 'One rate for everyone',
                    selected: !_hasVariants,
                    onTap: () => setState(() => _hasVariants = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PublishChoiceCard(
                    icon: LucideIcons.layers,
                    title: 'Variants',
                    subtitle: 'Multiple price options',
                    selected: _hasVariants,
                    onTap: () => setState(() => _hasVariants = true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      if (!_hasVariants) ...[
        const SizedBox(height: 14),
        PublishSectionCard(
          title: 'Rate & duration',
          subtitle: 'How much and how long',
          icon: LucideIcons.tag,
          children: [
            PublishField(
              label: 'Price',
              required: true,
              hint: 'Enter amount',
              controller: _priceController,
              keyboardType: TextInputType.number,
              prefixText: '₹ ',
              onChanged: (_) => setState(() {}),
            ),
            Row(
              children: [
                Expanded(
                  child: PublishSelectField<String>(
                    label: 'Rate',
                    required: true,
                    value: _rateType,
                    items: _rateTypes,
                    onChanged: (value) =>
                        setState(() => _rateType = value ?? _rateType),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PublishSelectField<String>(
                    label: 'Duration',
                    required: true,
                    value: _duration,
                    items: _durations,
                    onChanged: (value) =>
                        setState(() => _duration = value ?? _duration),
                  ),
                ),
              ],
            ),
            PublishSwitchRow(
              title: 'Allow multiple units',
              subtitle: 'Let customers book more than one of this service',
              value: _allowMultiple,
              onChanged: (value) => setState(() => _allowMultiple = value),
            ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      PublishSectionCard(
        title: _hasVariants ? 'Service variants' : 'Subservices',
        subtitle: _hasVariants
            ? 'Each variant has its own price and photo'
            : 'Optional add-ons customers can choose',
        icon: LucideIcons.layers,
        accent: PublishStyle.purple,
        children: [
          _SubservicesEditor(
            subservices: _subservices,
            variants: _hasVariants,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
      if (_hasVariants) ...[
        const SizedBox(height: 14),
        const PublishHint(
          text: 'Add at least one named variant with a price to publish.',
          icon: LucideIcons.info,
        ),
      ],
    ];
  }

  List<Widget> _availabilityStep() {
    return [
      const PublishStepIntro(
        title: 'Availability & publish',
        subtitle: 'Tell customers where, when and how you deliver.',
      ),
      const SizedBox(height: 16),
      PublishSectionCard(
        title: 'How you deliver',
        subtitle: 'Where customers receive this service',
        icon: LucideIcons.mapPin,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _methods.length; i++) ...[
                  Expanded(
                    child: PublishChoiceCard(
                      icon: _methods[i] == 'Online'
                          ? LucideIcons.globe
                          : LucideIcons.mapPin,
                      title: _methods[i],
                      selected: _method == _methods[i],
                      onTap: () => setState(() => _method = _methods[i]),
                    ),
                  ),
                  if (i < _methods.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (_method == 'At my location')
            PublishField(
              label: 'Service Address',
              required: true,
              hint: 'Where customers should visit',
              controller: _addressController,
              onChanged: (_) => setState(() {}),
            ),
        ],
      ),
      const SizedBox(height: 14),
      PublishSectionCard(
        title: 'Hours & coverage',
        subtitle: 'General hours and the areas you serve',
        icon: LucideIcons.clock,
        children: [
          const PublishFieldLabel('Service hours', required: true),
          Row(
            children: [
              Expanded(
                child: _TimeBox(
                  value: _serviceStart,
                  placeholder: 'Start',
                  onTap: () => _pickServiceTime(true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('–', style: TextStyle(color: PublishStyle.soft)),
              ),
              Expanded(
                child: _TimeBox(
                  value: _serviceEnd,
                  placeholder: 'End',
                  onTap: () => _pickServiceTime(false),
                ),
              ),
            ],
          ),
          const Text(
            'General hours this service is offered within.',
            style: TextStyle(
              color: PublishStyle.soft,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const PublishFieldLabel('Service areas', required: true),
          _ServiceAreasEditor(
            controllers: _serviceAreaControllers,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
      const SizedBox(height: 14),
      PublishSectionCard(
        title: 'Weekly availability',
        subtitle: 'Add the time slots customers can book',
        icon: LucideIcons.calendarDays,
        children: [
          _EditableAvailabilityPanel(
            days: _availability,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
      const SizedBox(height: 14),
      PublishSectionCard(
        title: 'Publishing',
        subtitle: 'Control who can see this listing',
        icon: LucideIcons.eye,
        children: [
          PublishSwitchRow(
            title: 'Visible to customers',
            subtitle: 'Show this service in your store once published',
            value: _visible,
            onChanged: (value) => setState(() => _visible = value),
          ),
        ],
      ),
      const SizedBox(height: 14),
      PublishPreviewCard(
        image: _previewImage(),
        children: [
          if (_providerController.text.trim().isNotEmpty)
            Text(
              _providerController.text.trim().toUpperCase(),
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
                ? 'Service name'
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
          Text(
            _previewPrice,
            style: const TextStyle(
              color: PublishStyle.ink,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          Row(
            children: [
              const Icon(LucideIcons.clock,
                  size: 12, color: PublishStyle.success),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$_duration · ${_method == 'At my location' ? 'At my place' : _method}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PublishStyle.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
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

  int get _totalImageCount => _pendingImages.length + _coverImages.length;

  Future<void> _pickServiceTime(bool isStart) async {
    final parts = (isStart ? _serviceStart : _serviceEnd).split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      final v =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (isStart) {
        _serviceStart = v;
      } else {
        _serviceEnd = v;
      }
    });
  }

  String? _validateServiceTime() {
    if (_serviceStart.isEmpty || _serviceEnd.isEmpty) {
      return 'Enter service start and end times.';
    }
    if (_serviceEnd.compareTo(_serviceStart) <= 0) {
      return 'Service start time must be before end time.';
    }
    return null;
  }

  Future<void> _pickServiceImages() async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.isEmpty || !mounted) return;
      setState(() {
        final room = _maxImages - _totalImageCount;
        if (room <= 0) return;
        _pendingImages.addAll(images.take(room));
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image picker is not available.')),
      );
    }
  }

  String? _validateSubservices() {
    for (final s in _subservices) {
      final name = s.nameController.text.trim();
      final hoursRaw = s.hoursController.text.trim();
      final priceRaw = s.priceController.text.trim();
      final sqftRaw = s.sqftController.text.trim();
      if (name.isEmpty &&
          hoursRaw.isEmpty &&
          priceRaw.isEmpty &&
          sqftRaw.isEmpty) {
        continue;
      }
      if (name.isEmpty) return 'Enter a name for each subservice.';
      final hours = double.tryParse(hoursRaw);
      if (hoursRaw.isNotEmpty && (hours == null || hours <= 0)) {
        return 'Enter a valid number of hours, or leave it blank.';
      }
      final sqft = double.tryParse(sqftRaw);
      if (sqftRaw.isNotEmpty && (sqft == null || sqft <= 0)) {
        return 'Enter a valid square-foot value, or leave it blank.';
      }
      final price = double.tryParse(priceRaw);
      if (priceRaw.isEmpty || price == null || price < 0) {
        return 'Enter a valid price for each subservice.';
      }
    }
    return null;
  }

  String? _validateService({required bool draft}) {
    if (!draft) {
      if (_nameController.text.trim().isEmpty ||
          _descriptionController.text.trim().isEmpty) {
        return 'Enter a service name and description.';
      }
      if (!_highlightControllers.any((c) => c.text.trim().isNotEmpty)) {
        return 'Add at least one key highlight.';
      }
      final price = double.tryParse(_priceController.text.trim());
      if (!_hasVariants &&
          (_priceController.text.trim().isEmpty ||
              price == null ||
              price < 0)) {
        return 'Enter a valid price of zero or more.';
      }
      final subError = _validateSubservices();
      if (subError != null) return subError;
      if (_hasVariants &&
          !_subservices.any((s) =>
              s.nameController.text.trim().isNotEmpty &&
              double.tryParse(s.priceController.text.trim()) != null)) {
        return 'Add at least one priced variant.';
      }
      if (!_availability.any((d) => d.slots.isNotEmpty)) {
        return 'Add at least one availability slot.';
      }
      if (_method == 'At my location' &&
          _addressController.text.trim().isEmpty) {
        return 'Enter your service address.';
      }
    }
    // service_time + service_area are required on every create (POST),
    // including draft saves — so they are checked even for drafts.
    final timeError = _validateServiceTime();
    if (timeError != null) return timeError;
    if (_serviceAreaControllers
        .map((c) => c.text.trim())
        .where((a) => a.isNotEmpty)
        .isEmpty) {
      return 'Add at least one service area.';
    }
    for (final day in _availability) {
      final sorted = [...day.slots]..sort((a, b) => a.start.compareTo(b.start));
      for (var i = 0; i < sorted.length; i++) {
        final s = sorted[i];
        if (s.start.isEmpty ||
            s.end.isEmpty ||
            s.end.compareTo(s.start) <= 0 ||
            (i > 0 && sorted[i - 1].end.compareTo(s.start) > 0)) {
          return '${day.day}: use valid start and end times without overlapping slots.';
        }
      }
    }
    return null;
  }

  Future<void> _saveService({required bool draft}) async {
    final error = _validateService(draft: draft);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      // Upload pending picks first, then merge with already-uploaded covers
      // preserving main-image-first ordering like React.
      var uploaded = <UploadedImage>[..._coverImages];
      if (_pendingImages.isNotEmpty) {
        final byteFiles = <MultipartBytesFile>[];
        for (final img in _pendingImages) {
          final bytes = await img.readAsBytes();
          if (bytes.isEmpty) continue;
          byteFiles.add(MultipartBytesFile(
            bytes: bytes,
            filename: influencerUploadFilename(img.name, img.path),
          ));
        }
        if (byteFiles.isNotEmpty) {
          final fresh = await UploadApi().uploadInfluencerServiceImages(
            byteFiles: byteFiles,
          );
          uploaded = [...uploaded, ...fresh];
        }
      }
      // Pending uploads were appended in pick order above; rotate the
      // merged list so the chosen main image goes first like React.
      final refs = uploaded.map((img) => img.toJson()).toList();
      final orderedRefs = refs.isEmpty
          ? <Map<String, String>>[]
          : [
              refs[_mainImageIndex.clamp(0, refs.length - 1)],
              for (var i = 0; i < refs.length; i++)
                if (i != _mainImageIndex.clamp(0, refs.length - 1)) refs[i],
            ];
      // Variant photos use the same batch endpoint as service cover images.
      for (final subservice in _subservices) {
        if (subservice.pendingImage == null) continue;
        final image = subservice.pendingImage!;
        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) continue;
        final uploadedSubservice =
            await UploadApi().uploadInfluencerServiceImages(byteFiles: [
          MultipartBytesFile(
              bytes: bytes,
              filename: influencerUploadFilename(image.name, image.path))
        ]);
        if (uploadedSubservice.isNotEmpty) {
          subservice.uploadedImage = uploadedSubservice.first;
        }
      }
      await Phase2StoreApi().createService({
        'images': orderedRefs,
        'name': _nameController.text.trim(),
        'category': _category,
        'provider': _providerController.text.trim(),
        'short_description': _descriptionController.text.trim(),
        'key_highlights': _highlightControllers
            .map((c) => c.text.trim())
            .where((h) => h.isNotEmpty)
            .toList(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'rate_type': _rateTypeFor(_rateType),
        'duration': _duration,
        'has_variants': _hasVariants,
        'allow_multiple': !_hasVariants && _allowMultiple,
        'subservices': _subservices
            .where((s) =>
                s.nameController.text.trim().isNotEmpty ||
                s.hoursController.text.trim().isNotEmpty ||
                s.sqftController.text.trim().isNotEmpty ||
                s.priceController.text.trim().isNotEmpty)
            .map((s) => {
                  'name': s.nameController.text.trim(),
                  'hours': double.tryParse(s.hoursController.text.trim()) ?? 0,
                  'price': double.tryParse(s.priceController.text.trim()) ?? 0,
                  'allow_multiple': s.allowMultiple,
                  'sqft': double.tryParse(s.sqftController.text.trim()) ?? 0,
                  if (s.uploadedImage != null)
                    'image': {'fileName': s.uploadedImage!.fileName},
                })
            .toList(),
        'service_method': _methodFor(_method),
        'service_time': {'start': _serviceStart, 'end': _serviceEnd},
        'service_area': _serviceAreaControllers
            .map((c) => c.text.trim())
            .where((a) => a.isNotEmpty)
            .toList(),
        'weekly_availability': {
          for (final d in _availability)
            d.day.toLowerCase(): [
              for (final s in d.slots)
                if (s.start.isNotEmpty && s.end.isNotEmpty)
                  {'start': s.start, 'end': s.end},
            ],
        },
        'visible_to_customers': _visible,
        'status': draft ? 'draft' : 'active',
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(draft ? 'Draft saved.' : 'Service published.'),
        ),
      );
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

class _ServicePhotoCard extends StatelessWidget {
  final List<XFile> pending;
  final List<UploadedImage> uploaded;
  final int mainIndex;
  final VoidCallback onPick;
  final ValueChanged<int> onSetMain;
  final ValueChanged<int> onRemovePending;
  final ValueChanged<int> onRemoveUploaded;

  const _ServicePhotoCard({
    required this.pending,
    required this.uploaded,
    required this.mainIndex,
    required this.onPick,
    required this.onSetMain,
    required this.onRemovePending,
    required this.onRemoveUploaded,
  });

  Widget _imageAt(int index) {
    if (index < pending.length) {
      return FutureBuilder<Uint8List>(
        future: pending[index].readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const ColoredBox(color: PublishStyle.fieldFill);
          }
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        },
      );
    }
    final img = uploaded[index - pending.length];
    return StoreItemImage(
      imageUrl: img.fileUrl.isNotEmpty ? img.fileUrl : img.fileName,
      icon: LucideIcons.image,
      fit: BoxFit.cover,
    );
  }

  void _removeAt(int index) {
    if (index < pending.length) {
      onRemovePending(index);
    } else {
      onRemoveUploaded(index - pending.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = pending.length + uploaded.length;
    if (total == 0) {
      return PublishDashedBox(
        onTap: onPick,
        radius: 22,
        child: const SizedBox(
          height: 190,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: Icon(
                    LucideIcons.cloudUpload,
                    size: 25,
                    color: PublishStyle.teal,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Add service photos',
                style: TextStyle(
                  color: PublishStyle.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'JPG or PNG · up to 10 photos',
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

    final index = mainIndex.clamp(0, total - 1);
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
                _imageAt(index),
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
                  child: InkWell(
                    onTap: () => _removeAt(index),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(LucideIcons.x,
                          size: 15, color: Colors.white),
                    ),
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
                        onTap: onPick,
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
            itemCount: total + (total < 10 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              if (i >= total) {
                return PublishDashedBox(
                  onTap: onPick,
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
                onTap: () => onSetMain(i),
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
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: _imageAt(i),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: GestureDetector(
                          onTap: () => _removeAt(i),
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

class _ServiceHighlightsEditor extends StatelessWidget {
  final List<TextEditingController> controllers;
  final int max;
  final VoidCallback onChanged;

  const _ServiceHighlightsEditor({
    required this.controllers,
    required this.max,
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
                decoration: const BoxDecoration(
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
                  onChanged: (_) => onChanged(),
                  style: const TextStyle(
                    color: PublishStyle.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: publishInputDecoration(
                    hint: 'e.g. All equipment included',
                  ),
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

class _TimeBox extends StatelessWidget {
  final String value;
  final String placeholder;
  final VoidCallback onTap;

  const _TimeBox({
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: PublishStyle.fieldFill,
          border: Border.all(color: PublishStyle.fieldBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.clock,
              size: 14,
              color: empty ? PublishStyle.soft : PublishStyle.teal,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                empty ? placeholder : value,
                style: TextStyle(
                  color: empty ? PublishStyle.soft : PublishStyle.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceAreasEditor extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback onChanged;

  const _ServiceAreasEditor({
    required this.controllers,
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
                decoration: const BoxDecoration(
                  color: PublishStyle.tealSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.mapPin,
                    size: 12, color: PublishStyle.teal),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controllers[i],
                  cursorColor: PublishStyle.teal,
                  onChanged: (_) => onChanged(),
                  style: const TextStyle(
                    color: PublishStyle.ink,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: publishInputDecoration(hint: 'e.g. Malad'),
                ),
              ),
              const SizedBox(width: 3),
              IconButton(
                onPressed: () {
                  if (controllers.length <= 1) {
                    controllers[i].clear();
                  } else {
                    controllers[i].dispose();
                    controllers.removeAt(i);
                  }
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
        const SizedBox(height: 10),
        PublishAddButton(
          label: 'Add area',
          onTap: () {
            controllers.add(TextEditingController());
            onChanged();
          },
        ),
      ],
    );
  }
}

class _InputShell extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _InputShell({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return PublishField(
      label: label,
      hint: hint,
      controller: controller,
      keyboardType: keyboardType,
    );
  }
}

class _ServiceSubservice {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController sqftController = TextEditingController();
  final TextEditingController hoursController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  bool allowMultiple = false;
  XFile? pendingImage;
  UploadedImage? uploadedImage;

  void dispose() {
    nameController.dispose();
    sqftController.dispose();
    hoursController.dispose();
    priceController.dispose();
  }
}

class _Slot {
  String start;
  String end;

  _Slot(this.start, this.end);
}

class _AvailDay {
  final String day;
  final List<_Slot> slots;

  _AvailDay(this.day, this.slots);
}

class _SubservicesEditor extends StatefulWidget {
  final List<_ServiceSubservice> subservices;
  final bool variants;
  final VoidCallback onChanged;

  const _SubservicesEditor({
    required this.subservices,
    required this.variants,
    required this.onChanged,
  });

  @override
  State<_SubservicesEditor> createState() => _SubservicesEditorState();
}

class _SubservicesEditorState extends State<_SubservicesEditor> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Subservices',
          style: TextStyle(
            color: Color(0xFF29304D),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        for (var i = 0; i < widget.subservices.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD5DEE4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _InputShell(
                  label: 'Service Name',
                  hint: 'Service name',
                  controller: widget.subservices[i].nameController,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _InputShell(
                        label: 'Sqft',
                        hint: 'Sqft',
                        controller: widget.subservices[i].sqftController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InputShell(
                        label: 'Hr',
                        hint: 'Hr',
                        controller: widget.subservices[i].hoursController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InputShell(
                        label: 'Price (₹)',
                        hint: '0',
                        controller: widget.subservices[i].priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        if (widget.subservices.length <= 1) return;
                        setState(() {
                          widget.subservices.removeAt(i);
                        });
                        widget.onChanged();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: const Color(0xFF8B90A2),
                    ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow multiple quantity',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  value: widget.subservices[i].allowMultiple,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF078D92),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFD5DEE4),
                  onChanged: (value) {
                    setState(() => widget.subservices[i].allowMultiple = value);
                    widget.onChanged();
                  },
                ),
                _SubservicePhotoControl(
                  pending: widget.subservices[i].pendingImage,
                  uploaded: widget.subservices[i].uploadedImage,
                  onPick: () async {
                    final picked = await ImagePicker()
                        .pickImage(source: ImageSource.gallery);
                    if (picked == null || !mounted) return;
                    setState(() {
                      widget.subservices[i].pendingImage = picked;
                      // A new local pick supersedes the old server image.
                      widget.subservices[i].uploadedImage = null;
                    });
                    widget.onChanged();
                  },
                  onRemove: () {
                    setState(() {
                      widget.subservices[i].pendingImage = null;
                      widget.subservices[i].uploadedImage = null;
                    });
                    widget.onChanged();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextButton(
          onPressed: () {
            setState(() => widget.subservices.add(_ServiceSubservice()));
            widget.onChanged();
          },
          child: const Text(
            '+ Add Subservice',
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

class _SubservicePhotoControl extends StatelessWidget {
  final XFile? pending;
  final UploadedImage? uploaded;
  final Future<void> Function() onPick;
  final VoidCallback onRemove;

  const _SubservicePhotoControl({
    required this.pending,
    required this.uploaded,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = pending != null || uploaded != null;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (pending != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FutureBuilder<Uint8List>(
                future: pending!.readAsBytes(),
                builder: (context, snapshot) => SizedBox(
                  width: 52,
                  height: 52,
                  child: snapshot.hasData
                      ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                      : const ColoredBox(color: Color(0xFFEAF7F6)),
                ),
              ),
            )
          else if (uploaded != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SafeNetworkImage(
                url: uploaded!.fileUrl,
                width: 52,
                height: 52,
                debugLabel: 'subservice-editor',
              ),
            ),
          TextButton.icon(
            onPressed: onPick,
            icon: Icon(hasPhoto ? LucideIcons.refreshCw : LucideIcons.imagePlus,
                size: 17),
            label: Text(hasPhoto ? 'Change photo' : 'Add photo'),
          ),
          if (hasPhoto)
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove photo',
              icon: const Icon(LucideIcons.trash2, size: 17),
              color: const Color(0xFFB3261E),
            ),
        ],
      ),
    );
  }
}

class _EditableAvailabilityPanel extends StatefulWidget {
  final List<_AvailDay> days;
  final VoidCallback onChanged;

  const _EditableAvailabilityPanel({
    required this.days,
    required this.onChanged,
  });

  @override
  State<_EditableAvailabilityPanel> createState() =>
      _EditableAvailabilityPanelState();
}

class _EditableAvailabilityPanelState
    extends State<_EditableAvailabilityPanel> {
  Future<void> _pickTime(_Slot slot, bool isStart) async {
    final parts = (isStart ? slot.start : slot.end).split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      final v =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (isStart) {
        slot.start = v;
      } else {
        slot.end = v;
      }
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: storeSoftCardDecoration(radius: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final day in widget.days) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        day.day,
                        style: const TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      if (day.slots.isEmpty)
                        const Text(
                          'Unavailable',
                          style: TextStyle(
                            color: Color(0xFF8B90A2),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      IconButton(
                        onPressed: () {
                          setState(() => day.slots.add(_Slot('', '')));
                          widget.onChanged();
                        },
                        icon: const Icon(LucideIcons.plus, size: 17),
                        color: const Color(0xFF29304D),
                      ),
                    ],
                  ),
                  for (var i = 0; i < day.slots.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickTime(day.slots[i], true),
                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFD5DEE4)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  day.slots[i].start.isEmpty
                                      ? 'Start'
                                      : day.slots[i].start,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text('–'),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickTime(day.slots[i], false),
                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFD5DEE4)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  day.slots[i].end.isEmpty
                                      ? 'End'
                                      : day.slots[i].end,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() => day.slots.removeAt(i));
                              widget.onChanged();
                            },
                            icon: const Icon(Icons.close_rounded, size: 17),
                            color: const Color(0xFF8B90A2),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE8EBF0)),
          ],
        ],
      ),
    );
  }
}

String _methodFor(String method) {
  return switch (method) {
    'Online' => 'online',
    'At my location' => 'at_my_location',
    _ => 'at_customer_location',
  };
}

String _rateTypeFor(String rateType) {
  return switch (rateType) {
    'Fixed price' => 'fixed',
    'Per hour' => 'per_hour',
    'Per session' => 'per_session',
    _ => 'starting_from',
  };
}
