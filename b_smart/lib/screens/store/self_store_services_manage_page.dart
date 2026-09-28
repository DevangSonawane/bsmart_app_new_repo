import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../utils/url_helper.dart';
import 'self_store_availability_page.dart';
import 'shared/store_image_editor.dart';
import 'store_models.dart';
import 'store_role_setup_screen.dart';
import 'store_theme.dart';
import 'shared/store_shared_widgets.dart';

class SelfStoreServicesManageScreen extends StatelessWidget {
  const SelfStoreServicesManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFEFC),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const StoreRoleGateSliver(
                child: SelfStoreServicesManagePage()),
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

class SelfStoreServicesManagePage extends StatefulWidget {
  const SelfStoreServicesManagePage({super.key});

  @override
  State<SelfStoreServicesManagePage> createState() =>
      _SelfStoreServicesManagePageState();
}

class _SelfStoreServicesManagePageState
    extends State<SelfStoreServicesManagePage> {
  int _selectedTab = 0;
  late Future<List<Map<String, dynamic>>> _servicesFuture;
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = Phase2StoreApi().myServices();
    _bookingsFuture =
        Phase2StoreApi().sellerServiceBookings().catchError((_) => const <Map<String, dynamic>>[]);
  }

  void _refreshServices() {
    setState(() {
      _servicesFuture = Phase2StoreApi().myServices();
      _bookingsFuture = Phase2StoreApi()
          .sellerServiceBookings()
          .catchError((_) => const <Map<String, dynamic>>[]);
    });
  }

  static int _bookingsFor(
      String serviceId, List<Map<String, dynamic>> bookings) {
    if (serviceId.isEmpty) return 0;
    var count = 0;
    for (final booking in bookings) {
      final service = booking['service'];
      String? id;
      if (service is Map) {
        id = (service['id'] ?? service['_id'])?.toString();
      }
      id ??= booking['service_id']?.toString();
      if (id == serviceId) {
        final status =
            booking['status']?.toString().toLowerCase() ?? '';
        if (status != 'cancelled' && status != 'canceled') count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return SliverList.list(
      children: [
        const _ServicesHeader(),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 20, 18, 0),
          child: Text(
            'My Services',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 25,
              fontWeight: FontWeight.w700,
              fontFamily: 'Georgia',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: _ServiceTabs(
            selectedIndex: _selectedTab,
            onSelected: (index) => setState(() => _selectedTab = index),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _servicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final services = (snapshot.data ?? const []).where((service) {
              final visible = service['visible_to_customers'];
              return _selectedTab == 0 ? visible != false : visible == false;
            }).toList();
            if (services.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
                child: StoreEmptyState(
                  icon: LucideIcons.briefcaseBusiness,
                  title: 'No services here',
                  body: 'Create a service to start accepting bookings.',
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < services.length; i++) ...[
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _bookingsFuture,
                    builder: (context, bookingSnapshot) {
                      final bookings = bookingSnapshot.data ?? const [];
                      final serviceId = _serviceText(
                        services[i],
                        const ['id', '_id'],
                      );
                      return _ManageServiceCard.fromApi(
                        services[i],
                        onChanged: _refreshServices,
                        bookingsCount:
                            _bookingsFor(serviceId, bookings),
                      );
                    },
                  ),
                  if (i != services.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: _AddServiceButton(
              onTap: () async {
                if (!await StoreRoleGate.ensureInfluencer(context)) return;
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => StoreAddServiceFlowScreen(
                      onPublished: _refreshServices,
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

class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader();

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
            Icon(LucideIcons.menu, color: Color(0xFF060D35), size: 23),
          ],
        ),
      ),
    );
  }
}

class _ServiceTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ServiceTabs({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    const tabs = ['Published', 'Drafts'];
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
                        style: TextStyle(
                          color: i == selectedIndex
                              ? const Color(0xFF060D35)
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
              alignment: Alignment(-1.0 + (2.0 * selectedIndex), 0),
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


class _ManageServiceCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String price;
  final String serviceId;
  final Map<String, dynamic> raw;
  final VoidCallback? onChanged;
  final int bookingsCount;

  const _ManageServiceCard({
    this.imageUrl = '',
    required this.title,
    required this.price,
    this.serviceId = '',
    this.raw = const {},
    this.onChanged,
    this.bookingsCount = 0,
  });

  factory _ManageServiceCard.fromApi(
    Map<String, dynamic> service, {
    VoidCallback? onChanged,
    int bookingsCount = 0,
  }) {
    final price = _serviceNumber(service, const ['price']);
    final rateType = _serviceText(service, const ['rate_type']);
    final suffix = switch (rateType) {
      'per_hour' => ' / hour',
      'per_session' => ' / session',
      'starting_from' => ' onwards',
      _ => '',
    };
    return _ManageServiceCard(
      imageUrl: _serviceImageUrl(service),
      title:
          _serviceText(service, const ['name', 'title'], fallback: 'Service'),
      price:
          '₹${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}$suffix',
      serviceId: _serviceText(service, const ['id', '_id']),
      raw: service,
      onChanged: onChanged,
      bookingsCount: bookingsCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        height: 146,
        decoration: storeSoftCardDecoration(radius: 9),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            StoreItemImage(
              imageUrl: imageUrl,
              icon: LucideIcons.briefcaseBusiness,
              width: 124,
              height: 146,
              debugLabel: 'self-store-service',
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 8, 12),
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
                        height: 1.15,
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
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.calendarDays,
                          color: Color(0xFF078D92),
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          bookingsCount == 0
                              ? 'No bookings yet'
                              : '$bookingsCount ${bookingsCount == 1 ? 'booking' : 'bookings'}',
                          style: const TextStyle(
                            color: Color(0xFF29304D),
                            fontSize: 11.5,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const _VisibleBadge(),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: serviceId.isEmpty
                              ? null
                              : () => _showEditServiceSheet(context),
                          icon: const Icon(LucideIcons.pencil, size: 13),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF060D35),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(48, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            textStyle: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: serviceId.isEmpty
                              ? null
                              : () => _confirmDeleteService(context),
                          icon: const Icon(LucideIcons.ellipsisVertical,
                              size: 17),
                          color: const Color(0xFF060D35),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                              width: 28, height: 28),
                        ),
                      ],
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

  Future<void> _showEditServiceSheet(BuildContext context) async {
    final priceCtrl = TextEditingController(
      text: _serviceNumber(raw, const ['price']).toStringAsFixed(0),
    );
    bool visible = raw['visible_to_customers'] != false;
    List<Map<String, dynamic>> images =
        StoreImageEditor.entriesOf(raw);
    final action = await showModalBottomSheet<String>(
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
                    labelText: 'Price (₹)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible to customers'),
                value: visible,
                onChanged: (v) => setSheetState(() => visible = v),
              ),
              StoreImageEditor(
                initial: images,
                minCount: 0,
                onChanged: (next) => images = next,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final updated = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => SelfStoreAvailabilityScreen(
                        serviceId: serviceId,
                        serviceName: title,
                        initialAvailability: raw['weekly_availability'] is Map
                            ? Map<String, dynamic>.from(
                                raw['weekly_availability'] as Map)
                            : const {},
                      ),
                    ),
                  );
                  if (updated == true) {
                    if (!context.mounted) return;
                    Navigator.of(sheetContext).pop('saved-externally');
                  }
                },
                icon: const Icon(LucideIcons.calendarDays, size: 18),
                label: const Text('Edit weekly availability'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop('save'),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'saved-externally') {
      await StoreMockState.instance.refreshMarketplace();
      onChanged?.call();
      return;
    }
    if (action != 'save') return;
    try {
      final price = double.tryParse(priceCtrl.text.trim());
      await Phase2StoreApi().updateService(serviceId, {
        if (price != null && price > 0) 'price': price,
        'visible_to_customers': visible,
        'images': images,
      });
      await StoreMockState.instance.refreshMarketplace();
      onChanged?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Service updated.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  Future<void> _confirmDeleteService(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete service?'),
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
    try {
      await Phase2StoreApi().deleteService(serviceId);
      await StoreMockState.instance.refreshMarketplace();
      onChanged?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Service deleted.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }
}

class _VisibleBadge extends StatelessWidget {
  const _VisibleBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6EA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 3, backgroundColor: Color(0xFF139B54)),
          SizedBox(width: 5),
          Text(
            'Visible',
            style: TextStyle(
              color: Color(0xFF139B54),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddServiceButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddServiceButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF078D92),
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              elevation: 8,
              shadowColor: const Color(0xFF078D92).withValues(alpha: 0.24),
            ),
            child: const Icon(LucideIcons.plus, size: 27),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Add Service',
          style: TextStyle(
            color: Color(0xFF078D92),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class StoreAddServiceFlowScreen extends StatefulWidget {
  final VoidCallback? onPublished;

  const StoreAddServiceFlowScreen({super.key, this.onPublished});

  @override
  State<StoreAddServiceFlowScreen> createState() =>
      _StoreAddServiceFlowScreenState();
}

class _StoreAddServiceFlowScreenState extends State<StoreAddServiceFlowScreen> {
  int _step = 1;
  bool _publishing = false;
  String _serviceMethod = 'At customer location';
  String? _category;
  String _duration = '1 hour';
  String _currency = 'USD';
  String _rateUnit = 'per hour';
  String _advanceNotice = '24 hours';
  final _serviceNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _weekdays = const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday'
  ];

  @override
  void dispose() {
    _serviceNameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
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
              title: _step == 1 ? 'Add Service' : 'Availability & publish',
              trailing: _step == 1 ? 'Save draft' : null,
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
                children: _step == 1 ? _basicsStep() : _availabilityStep(),
              ),
            ),
            _FlowFooter(
              step: _step,
              onContinue: () => setState(() => _step = 2),
              publishing: _publishing,
              onPublish: _publishService,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _basicsStep() {
    return [
      const _ServiceStepHeader(stepText: '1 of 2', title: 'Basics'),
      const SizedBox(height: 14),
      const _CoverUploadCard(),
      const SizedBox(height: 14),
      _InputShell(
        label: 'Service name',
        hint: 'Enter service name',
        controller: _serviceNameController,
      ),
      const SizedBox(height: 12),
      _DropdownShell<String>(
        label: 'Category',
        value: _category,
        hint: 'Select category',
        items: const ['Home', 'Business', 'Wellness', 'Education', 'Events'],
        onChanged: (value) => setState(() => _category = value),
      ),
      const SizedBox(height: 12),
      _InputShell(
        label: 'Description',
        hint: 'Describe your service',
        controller: _descriptionController,
        minHeight: 94,
        maxLines: 4,
      ),
      const SizedBox(height: 12),
      _PriceRateRow(
        currency: _currency,
        amountController: _amountController,
        rateUnit: _rateUnit,
        onCurrencyChanged: (value) =>
            setState(() => _currency = value ?? _currency),
        onUnitChanged: (value) =>
            setState(() => _rateUnit = value ?? _rateUnit),
      ),
    ];
  }

  List<Widget> _availabilityStep() {
    return [
      const _SectionLabel('Service method'),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _MethodCard(
              icon: LucideIcons.mapPin,
              label: 'At customer location',
              selected: _serviceMethod == 'At customer location',
              onTap: () =>
                  setState(() => _serviceMethod = 'At customer location'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MethodCard(
              icon: LucideIcons.globe,
              label: 'Online',
              selected: _serviceMethod == 'Online',
              onTap: () => setState(() => _serviceMethod = 'Online'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _DropdownShell<String>(
        label: 'Duration',
        value: _duration,
        items: const ['30 minutes', '1 hour', '90 minutes', '2 hours'],
        onChanged: (value) => setState(() => _duration = value ?? _duration),
      ),
      const SizedBox(height: 18),
      const _SectionLabel('Weekly availability'),
      const SizedBox(height: 10),
      _AvailabilityPanel(weekdays: _weekdays),
      const SizedBox(height: 16),
      _DropdownShell<String>(
        label: 'Advance notice',
        value: _advanceNotice,
        items: const ['2 hours', '12 hours', '24 hours', '48 hours'],
        onChanged: (value) =>
            setState(() => _advanceNotice = value ?? _advanceNotice),
      ),
    ];
  }

  Future<void> _publishService() async {
    final name = _serviceNameController.text.trim();
    final description = _descriptionController.text.trim();
    final category = _category?.trim();
    final price = _serviceNumber(
      {'price': _amountController.text},
      const ['price'],
    );
    if (name.isEmpty ||
        description.isEmpty ||
        category == null ||
        category.isEmpty ||
        price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add service name, category, description and price.'),
        ),
      );
      return;
    }
    setState(() => _publishing = true);
    try {
      await Phase2StoreApi().createService({
        'images': const [],
        'name': name,
        'category': category,
        'provider': 'B-Smart Store',
        'short_description': description,
        'key_highlights': const ['Published from B-Smart Store'],
        'price': price,
        'rate_type': _rateTypeFor(_rateUnit),
        'duration': _duration,
        'subservices': const [],
        'service_method': _methodFor(_serviceMethod),
        'weekly_availability': _defaultWeeklyAvailability(),
        'visible_to_customers': true,
      });
      await StoreMockState.instance.refreshMarketplace();
      widget.onPublished?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service published.')),
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
  final String? trailing;
  final VoidCallback onBack;

  const _FlowHeader({
    required this.title,
    this.trailing,
    required this.onBack,
  });

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
                icon: const Icon(LucideIcons.arrowLeft, size: 22),
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
            if (trailing != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    trailing!,
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

class _ServiceStepHeader extends StatelessWidget {
  final String stepText;
  final String title;

  const _ServiceStepHeader({
    required this.stepText,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          stepText,
          style: const TextStyle(
            color: Color(0xFF078D92),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF060D35),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _CoverUploadCard extends StatelessWidget {
  const _CoverUploadCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5DEE4), width: 1.2),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 31,
            backgroundColor: Color(0xFFE5F5F3),
            child: Icon(LucideIcons.image, color: Color(0xFF078D92), size: 32),
          ),
          SizedBox(height: 12),
          Text(
            'Add cover photo',
            style: TextStyle(
              color: Color(0xFF060D35),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'JPG, PNG up to 10MB',
            style: TextStyle(
              color: Color(0xFF29304D),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF29304D),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _InputShell extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final double minHeight;
  final int maxLines;
  final TextInputType? keyboardType;

  const _InputShell({
    required this.label,
    required this.hint,
    required this.controller,
    this.minHeight = 48,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      minLines: maxLines > 1 ? maxLines : 1,
      maxLines: maxLines,
      style: const TextStyle(
        color: Color(0xFF060D35),
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
      decoration:
          _inputDecoration(label: label, hint: hint, minHeight: minHeight),
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
    return DropdownButtonFormField<T>(
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
      decoration: _inputDecoration(label: label),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  String? hint,
  double minHeight = 48,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    constraints: BoxConstraints(minHeight: minHeight),
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
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFD5DEE4)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF078D92)),
    ),
  );
}

class _PriceRateRow extends StatelessWidget {
  final String currency;
  final TextEditingController amountController;
  final String rateUnit;
  final ValueChanged<String?> onCurrencyChanged;
  final ValueChanged<String?> onUnitChanged;

  const _PriceRateRow({
    required this.currency,
    required this.amountController,
    required this.rateUnit,
    required this.onCurrencyChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 82,
          child: _DropdownShell<String>(
            label: 'Currency',
            value: currency,
            items: const ['USD', 'INR', 'EUR'],
            onChanged: onCurrencyChanged,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _InputShell(
            label: 'Price or rate',
            hint: 'Enter amount',
            controller: amountController,
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          child: _DropdownShell<String>(
            label: 'Unit',
            value: rateUnit,
            items: const ['per hour', 'per session', 'fixed'],
            onChanged: onUnitChanged,
          ),
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 86,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF078D92) : const Color(0xFFD5DEE4),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  selected ? const Color(0xFF684AC8) : const Color(0xFF29304D),
              size: 27,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF060D35),
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

class _AvailabilityPanel extends StatelessWidget {
  final List<String> weekdays;

  const _AvailabilityPanel({required this.weekdays});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: storeSoftCardDecoration(radius: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < weekdays.length; i++) ...[
            _AvailabilityRow(day: weekdays[i]),
            const Divider(height: 1, color: Color(0xFFE8EBF0)),
          ],
          const _UnavailableRow(day: 'Saturday'),
          const Divider(height: 1, color: Color(0xFFE8EBF0)),
          const _UnavailableRow(day: 'Sunday'),
        ],
      ),
    );
  }
}

class _AvailabilityRow extends StatelessWidget {
  final String day;

  const _AvailabilityRow({required this.day});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                day,
                style: const TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Expanded(child: _SmallTimeBox(text: '9:00 AM')),
          const SizedBox(width: 6),
          const Text('-', style: TextStyle(color: Color(0xFF8B90A2))),
          const SizedBox(width: 6),
          const Expanded(child: _SmallTimeBox(text: '5:00 PM')),
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.plus, size: 17),
            color: const Color(0xFF29304D),
          ),
        ],
      ),
    );
  }
}

class _UnavailableRow extends StatelessWidget {
  final String day;

  const _UnavailableRow({required this.day});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                day,
                style: const TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF29304D),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.plus, size: 17),
            color: const Color(0xFF29304D),
          ),
        ],
      ),
    );
  }
}

class _SmallTimeBox extends StatelessWidget {
  final String text;

  const _SmallTimeBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD5DEE4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF060D35),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(LucideIcons.chevronDown, size: 12),
          ],
        ),
      ),
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
                          'Publish Service',
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

double _serviceNumber(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (parsed != null) return parsed;
    }
  }
  return 0;
}

String _serviceText(
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

String _serviceImageUrl(Map<String, dynamic> json) {
  final images = json['images'];
  dynamic first;
  if (images is List && images.isNotEmpty) first = images.first;
  if (first is Map) {
    return UrlHelper.absoluteUrl(_serviceText(
      first.map((key, value) => MapEntry(key.toString(), value)),
      const ['url', 'fileName', 'filename', 'path', 'src'],
    ));
  }
  if (first is String) return UrlHelper.absoluteUrl(first);
  return '';
}

String _rateTypeFor(String rateUnit) {
  return switch (rateUnit) {
    'per hour' => 'per_hour',
    'per session' => 'per_session',
    'fixed' => 'fixed',
    _ => 'starting_from',
  };
}

String _methodFor(String method) {
  return switch (method) {
    'Online' => 'online',
    'At my location' => 'at_my_location',
    _ => 'at_customer_location',
  };
}

Map<String, List<Map<String, String>>> _defaultWeeklyAvailability() {
  const available = [
    {'start': '09:00', 'end': '17:00'},
  ];
  return const {
    'monday': available,
    'tuesday': available,
    'wednesday': available,
    'thursday': available,
    'friday': available,
    'saturday': [],
    'sunday': [],
  };
}
