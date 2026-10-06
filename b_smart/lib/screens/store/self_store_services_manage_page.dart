import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/phase2_store_api.dart';
import '../../api/upload_api.dart';
import '../../services/page_cache_service.dart';
import '../../utils/current_user.dart';
import 'self_store_availability_page.dart';
import 'shared/store_image_editor.dart';
import 'store_models.dart';
import 'store_role_setup_screen.dart';
import 'store_theme.dart';
import 'shared/store_shared_widgets.dart';
import 'shared/store_money.dart';

class SelfStoreServicesManageScreen extends StatefulWidget {
  const SelfStoreServicesManageScreen({super.key});

  @override
  State<SelfStoreServicesManageScreen> createState() =>
      _SelfStoreServicesManageScreenState();
}

class _SelfStoreServicesManageScreenState
    extends State<SelfStoreServicesManageScreen> {
  final _pageKey = GlobalKey<_SelfStoreServicesManagePageState>();

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
              StoreRoleGateSliver(
                  child: SelfStoreServicesManagePage(key: _pageKey)),
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
    _servicesFuture = _loadMyServices();
    _bookingsFuture = _loadMyBookings();
  }

  Future<List<Map<String, dynamic>>> _loadMyBookings() {
    return Phase2StoreApi()
        .sellerServiceBookings()
        .catchError((_) => const <Map<String, dynamic>>[]);
  }

  void _refreshServices() {
    if (!mounted) return;
    setState(() {
      _servicesFuture = _loadMyServices(forceNetwork: true);
      _bookingsFuture = _loadMyBookings();
    });
  }

  /// Pull-to-refresh entry point (called by the parent [RefreshIndicator]).
  Future<void> refresh() async {
    final services = _loadMyServices(forceNetwork: true);
    final bookings = _loadMyBookings();
    if (!mounted) return;
    setState(() {
      _servicesFuture = services;
      _bookingsFuture = bookings;
    });
    try {
      await Future.wait([services, bookings]);
    } catch (_) {
      // Builders surface errors; refresh just needs to complete.
    }
  }

  /// Loads my services and defensively drops anything owned by someone else,
  /// so a backend hiccup can never show another seller's services here.
  static Future<List<Map<String, dynamic>>> _loadMyServices(
      {bool forceNetwork = false}) async {
    final myId = await CurrentUser.id;
    final pageCache = PageCacheService();
    final cacheParams = <String, dynamic>{};
    final cached =
        forceNetwork ? null : await pageCache.get('store', myId ?? '', cacheParams);

    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        return decoded.cast<Map<String, dynamic>>();
      } on Exception catch (_) {
        await pageCache.invalidate('store', myId ?? '');
      }
    }

    final items = await Phase2StoreApi().myServices();
    if (myId == null || myId.isEmpty) return items;
    final filtered = items.where((item) => _isMine(item, myId)).toList();
    try {
      await pageCache.set(
          'store', myId, cacheParams, jsonEncode(filtered));
    } on Exception catch (_) {}
    return filtered;
  }

  static bool _isMine(Map<String, dynamic> item, String myId) {
    const ownerKeys = [
      'influencer_id',
      'influencerId',
      'user_id',
      'userId',
      'owner_id',
      'ownerId',
      'seller_id',
      'sellerId',
      'created_by',
      'createdBy',
    ];
    var sawOwner = false;
    for (final key in ownerKeys) {
      final value = item[key]?.toString().trim();
      if (value == null || value.isEmpty || value == 'null') continue;
      sawOwner = true;
      if (value == myId) return true;
    }
    const nestedKeys = ['influencer', 'owner', 'seller', 'user', 'created_by'];
    for (final key in nestedKeys) {
      final nested = item[key];
      if (nested is! Map) continue;
      final map = nested.map((k, v) => MapEntry(k.toString(), v));
      for (final idKey in ['id', '_id', 'user_id', 'userId']) {
        final value = map[idKey]?.toString().trim();
        if (value == null || value.isEmpty || value == 'null') continue;
        sawOwner = true;
        if (value == myId) return true;
      }
    }
    // No owner info on the item: trust the server-side `/my` filter.
    return !sawOwner ? true : false;
  }

  static int _bookingsFor(
      String serviceId, List<Map<String, dynamic>> bookings) {
    if (serviceId.isEmpty) return 0;
    var count = 0;
    for (final booking in bookings) {
      final service = booking['service'];
      String? id;
      if (service is Map) {
        final map = service.map((k, v) => MapEntry(k.toString(), v));
        id = (map['id'] ?? map['_id'] ?? map['service_id'] ?? map['serviceId'])
            ?.toString();
      }
      id ??= (booking['service_id'] ?? booking['serviceId'])?.toString();
      if (id == serviceId) {
        final status = booking['status']?.toString().toLowerCase() ?? '';
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
          child: StoreUnderlineTabs(
            tabs: const ['Published', 'Drafts'],
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
                        bookingsCount: _bookingsFor(serviceId, bookings),
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
            child: StoreAddCtaButton(
              label: 'Add Service',
              onTap: () async {
                if (!await StoreRoleGate.ensureInfluencer(context)) return;
                if (!context.mounted) return;
                final published = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => const StoreAddServiceFlowScreen(),
                  ),
                );
                if (published != true || !context.mounted) return;
                await StoreMockState.instance.refreshMarketplace();
                _refreshServices();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Service published.')),
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
      price: '${formatCompactStoreMoney(price)}$suffix',
      // The API has returned the id under several keys across
      // deployments; missing it disables Edit/Delete, so check them all.
      serviceId: _serviceText(service, const [
        'id',
        '_id',
        'service_id',
        'serviceId',
      ]),
      raw: service,
      onChanged: onChanged,
      bookingsCount: bookingsCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: GestureDetector(
        onTap: () => _showEditServiceSheet(context),
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
                          _ServiceActionsMenu(
                            serviceId: serviceId,
                            visible: raw['visible_to_customers'] != false,
                            title: title,
                            onEdit: () => _showEditServiceSheet(context),
                            onDelete: () => _confirmDeleteService(context),
                            onToggleVisible: () => _toggleVisible(context),
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
      ),
    );
  }

  Future<void> _showEditServiceSheet(BuildContext context) async {
    final priceCtrl = TextEditingController(
      text: _serviceNumber(raw, const ['price']).toStringAsFixed(0),
    );
    bool visible = raw['visible_to_customers'] != false;
    List<Map<String, dynamic>> images = StoreImageEditor.entriesOf(raw);
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        // viewPadding covers the Android 3-button nav bar / iPhone home
        // indicator so the Save button is never hidden behind system UI.
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
                    decoration: _editDecoration('Price (₹)'),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Visible to customers',
                        style: TextStyle(
                            color: Color(0xFF060D35),
                            fontWeight: FontWeight.w700)),
                    value: visible,
                    activeThumbColor: Colors.white,
                    activeTrackColor:
                        const Color(0xFF078D92).withValues(alpha: 0.55),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFD5DEE4),
                    onChanged: (v) => setSheetState(() => visible = v),
                  ),
                  StoreImageEditor(
                    initial: images,
                    minCount: 0,
                    onChanged: (next) => images = next,
                    uploadFn: UploadApi().uploadInfluencerServiceImages,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.of(context).push<bool>(
                          MaterialPageRoute<bool>(
                            builder: (_) => SelfStoreAvailabilityScreen(
                              serviceId: serviceId,
                              serviceName: title,
                              initialAvailability:
                                  raw['weekly_availability'] is Map
                                      ? Map<String, dynamic>.from(
                                          raw['weekly_availability'] as Map)
                                      : const {},
                            ),
                          ),
                        );
                        if (updated == true) {
                          if (!context.mounted) return;
                          Navigator.of(innerContext).pop('saved-externally');
                        }
                      },
                      icon: const Icon(LucideIcons.calendarDays, size: 18),
                      label: const Text('Edit weekly availability'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF078D92),
                        side: const BorderSide(color: Color(0xFF078D92)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () => Navigator.of(innerContext).pop('save'),
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
                ],
              ),
            ),
          ),
        );
      },
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text('Delete service?',
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

  Future<void> _toggleVisible(BuildContext context) async {
    if (serviceId.isEmpty) return;
    final next = raw['visible_to_customers'] == false;
    try {
      await Phase2StoreApi().updateService(serviceId, {
        'visible_to_customers': next,
      });
      await StoreMockState.instance.refreshMarketplace();
      onChanged?.call();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next ? 'Service marked visible.' : 'Service marked as draft.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
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

class _ServiceActionsMenu extends StatelessWidget {
  final String serviceId;
  final bool visible;
  final String title;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleVisible;

  const _ServiceActionsMenu({
    required this.serviceId,
    required this.visible,
    required this.title,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (serviceId.isEmpty) return const SizedBox.shrink();

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
          value: 'toggle_visible',
          child: Row(
            children: [
              Icon(
                visible ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 17,
                color: const Color(0xFF060D35),
              ),
              const SizedBox(width: 10),
              Text(
                visible ? 'Mark as Draft' : 'Mark Visible',
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
          case 'toggle_visible':
            onToggleVisible();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
    );
  }
}

class StoreAddServiceFlowScreen extends StatefulWidget {
  const StoreAddServiceFlowScreen({super.key});

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
  String _currency = 'INR';
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
  final _coverImages = <UploadedImage>[];

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
      _CoverUploadCard(
        images: _coverImages,
        onChanged: (list) => setState(() => _coverImages
          ..clear()
          ..addAll(list)),
      ),
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
          const SizedBox(width: 12),
          Expanded(
            child: _MethodCard(
              icon: LucideIcons.house,
              label: 'At my location',
              selected: _serviceMethod == 'At my location',
              onTap: () => setState(() => _serviceMethod = 'At my location'),
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
      // Cover photos are already uploaded when picked (see
      // _CoverUploadCard): send the returned file references straight to
      // POST /influencer-services `images` — re-uploading server file names
      // as local paths is what made publish fail before.
      final images = _coverImages.map((img) => img.toJson()).toList();
      await Phase2StoreApi().createService({
        'images': images,
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
      if (!mounted) return;
      Navigator.of(context).pop(true);
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

class _CoverUploadCard extends StatefulWidget {
  final List<UploadedImage> images;
  final ValueChanged<List<UploadedImage>> onChanged;

  const _CoverUploadCard({
    required this.images,
    required this.onChanged,
  });

  @override
  State<_CoverUploadCard> createState() => _CoverUploadCardState();
}

class _CoverUploadCardState extends State<_CoverUploadCard> {
  final _picker = ImagePicker();
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final uploaded = await UploadApi().uploadInfluencerServiceImages(
        filePaths: [picked.path],
      );
      if (!mounted) return;
      widget.onChanged([...widget.images, ...uploaded]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cover upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _remove(int index) {
    final images = [...widget.images];
    images.removeAt(index);
    widget.onChanged(images);
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    return InkWell(
      onTap: _uploading ? null : _pickAndUpload,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 150,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD5DEE4), width: 1.2),
        ),
        child: Stack(
          children: [
            if (images.isEmpty)
              const Center(
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.cloudUpload,
                          color: Color(0xFF684AC8), size: 36),
                      SizedBox(height: 12),
                      Text(
                        'Add cover photo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF060D35),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'JPG, PNG up to 10MB',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF29304D),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                padding: const EdgeInsets.all(8),
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        StoreItemImage(
                          imageUrl: images[index].fileUrl.isNotEmpty
                              ? images[index].fileUrl
                              : images[index].fileName,
                          icon: LucideIcons.image,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => _remove(index),
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
                  );
                },
              ),
            if (_uploading)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
          ],
        ),
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
  final String? prefixText;

  const _InputShell({
    required this.label,
    required this.hint,
    required this.controller,
    this.minHeight = 48,
    this.maxLines = 1,
    this.keyboardType,
    this.prefixText,
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
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        minHeight: minHeight,
        prefixText: prefixText,
      ),
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
      decoration: _inputDecoration(label: label),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  String? hint,
  double minHeight = 48,
  String? prefixText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DropdownShell<String>(
          label: 'Currency',
          value: currency,
          items: const ['INR'],
          onChanged: onCurrencyChanged,
        ),
        const SizedBox(height: 12),
        _InputShell(
          label: 'Price or rate (₹)',
          hint: 'Enter amount',
          controller: amountController,
          keyboardType: TextInputType.number,
          prefixText: '₹ ',
        ),
        const SizedBox(height: 12),
        _DropdownShell<String>(
          label: 'Unit',
          value: rateUnit,
          items: const [
            'starting from',
            'fixed',
            'per hour',
            'per session',
          ],
          onChanged: onUnitChanged,
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
        height: 98,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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

/// Explicit light styling for the Edit bottom sheet. The app can run in
/// system dark mode, so inputs declare their own fill / text / border
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

/// Seller-owned services carry `images: [{fileUrl, fileName}]` from the
/// influencer upload endpoint, so reuse the catalog resolver instead of
/// guessing key order here.
String _serviceImageUrl(Map<String, dynamic> json) =>
    StoreMockState.firstImageUrl(json);

String _rateTypeFor(String rateUnit) {
  return switch (rateUnit) {
    'per hour' => 'per_hour',
    'per session' => 'per_session',
    'fixed' => 'fixed',
    // API enum: starting_from, fixed, per_hour, per_session.
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
