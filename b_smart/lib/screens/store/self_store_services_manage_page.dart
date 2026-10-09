import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
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

const _servicesCacheGroup = 'store_my_services';

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

  /// Loads my services from the personal endpoint. Keep this cache separate
  /// from products/marketplace caches so "My" screens cannot bleed into each
  /// other if a previous tab has already filled the page cache.
  static Future<List<Map<String, dynamic>>> _loadMyServices(
      {bool forceNetwork = false}) async {
    final myId = await CurrentUser.id;
    final pageCache = PageCacheService();
    final cacheParams = <String, dynamic>{};
    final cached = forceNetwork
        ? null
        : await pageCache.get(_servicesCacheGroup, myId ?? '', cacheParams);

    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as List;
        return decoded.cast<Map<String, dynamic>>();
      } on Exception catch (_) {
        await pageCache.invalidate(_servicesCacheGroup, myId ?? '');
      }
    }

    final items = _onlyCurrentOwner(await Phase2StoreApi().myServices(), myId);
    if (myId != null && myId.isNotEmpty) {
      try {
        await pageCache.invalidate('store', myId);
        await pageCache.set(
            _servicesCacheGroup, myId, cacheParams, jsonEncode(items));
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
  // Mirrors React ServiceForm.jsx + serviceFields.js: same options, validation,
  // and payload. No Flutter-only fields (currency / advance notice).
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
  int _mainImageIndex = 0;
  String _method = 'At customer location';
  String _category = 'Home Services';
  String _duration = '1 hour';
  String _rateType = 'Starting from';
  bool _visible = true;
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _providerController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  final List<TextEditingController> _highlightControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final List<_ServiceSubservice> _subservices = [_ServiceSubservice()];
  String _serviceStart = '09:00';
  String _serviceEnd = '17:00';
  final List<TextEditingController> _serviceAreaControllers = [
    TextEditingController(),
  ];
  final List<_AvailDay> _availability = [
    for (var i = 0; i < _days.length; i++)
      _AvailDay(_days[i], [if (i < 5) _Slot('09:00', '17:00')]),
  ];
  // Pending picks (not yet uploaded) + already-uploaded covers. Upload happens
  // once at publish so ordering incl. main image is preserved like React.
  final _pendingImages = <XFile>[];
  final _coverImages = <UploadedImage>[];

  @override
  void dispose() {
    _nameController.dispose();
    _providerController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    for (final c in _highlightControllers) {
      c.dispose();
    }
    for (final s in _subservices) {
      s.dispose();
    }
    for (final c in _serviceAreaControllers) {
      c.dispose();
    }
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
              title: _step == 1
                  ? 'Add Service'
                  : _step == 2
                      ? 'Pricing'
                      : 'Availability & publish',
              trailing: 'Save draft',
              onSaveDraft: _publishing ? null : () => _saveService(draft: true),
              onBack: () {
                if (_step == 1) {
                  Navigator.of(context).pop();
                } else {
                  setState(() => _step = _step - 1);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 10, 26, 2),
              child: _FlowSteps(
                step: _step,
                totalSteps: 3,
                labels: const ['Details', 'Pricing', 'Availability'],
                onStepTap: (i) => setState(() => _step = i),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                children: _step == 1
                    ? _detailsStep()
                    : _step == 2
                        ? _pricingStep()
                        : _availabilityStep(),
              ),
            ),
            _FlowFooter(
              step: _step,
              totalSteps: 3,
              onContinue: () => setState(() => _step = _step + 1),
              onBack:
                  _step == 1 ? null : () => setState(() => _step = _step - 1),
              publishing: _publishing,
              publishLabel: 'Publish Service',
              onPublish: () => _saveService(draft: false),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _detailsStep() {
    return [
      const _ServiceStepHeader(stepText: '1 of 3', title: 'Service Details'),
      const SizedBox(height: 14),
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
      const SizedBox(height: 14),
      _InputShell(
        label: 'Service Name * (${_nameController.text.length}/150)',
        hint: 'Home Cleaning',
        controller: _nameController,
      ),
      const SizedBox(height: 12),
      _InputShell(
        label: 'Provider (optional)',
        hint: 'Your business name',
        controller: _providerController,
      ),
      const SizedBox(height: 12),
      _ServiceHighlightsEditor(
        controllers: _highlightControllers,
        max: _maxHighlights,
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 12),
      _DropdownShell<String>(
        label: 'Category *',
        value: _category,
        hint: 'Select category',
        items: _categories,
        onChanged: (value) => setState(() => _category = value ?? _category),
      ),
      const SizedBox(height: 12),
      _InputShell(
        label:
            'Short Description * (${_descriptionController.text.length}/500)',
        hint: 'Describe your service...',
        controller: _descriptionController,
        minHeight: 94,
        maxLines: 4,
      ),
    ];
  }

  List<Widget> _pricingStep() {
    return [
      const _ServiceStepHeader(stepText: '2 of 3', title: 'Pricing'),
      const SizedBox(height: 14),
      _InputShell(
        label: 'Price (₹) *',
        hint: 'Enter amount',
        controller: _priceController,
        keyboardType: TextInputType.number,
        prefixText: '₹ ',
      ),
      const SizedBox(height: 12),
      _DropdownShell<String>(
        label: 'Rate *',
        value: _rateType,
        items: _rateTypes,
        onChanged: (value) => setState(() => _rateType = value ?? _rateType),
      ),
      const SizedBox(height: 12),
      _DropdownShell<String>(
        label: 'Duration *',
        value: _duration,
        items: _durations,
        onChanged: (value) => setState(() => _duration = value ?? _duration),
      ),
      const SizedBox(height: 12),
      _SubservicesEditor(
        subservices: _subservices,
        onChanged: () => setState(() {}),
      ),
    ];
  }

  List<Widget> _availabilityStep() {
    return [
      const _SectionLabel('Service method *'),
      const SizedBox(height: 10),
      Row(
        children: [
          for (var i = 0; i < _methods.length; i++) ...[
            Expanded(
              child: _MethodCard(
                icon: _methods[i] == 'Online'
                    ? LucideIcons.globe
                    : LucideIcons.mapPin,
                label: _methods[i],
                selected: _method == _methods[i],
                onTap: () => setState(() => _method = _methods[i]),
              ),
            ),
            if (i < _methods.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
      if (_method == 'At my location') ...[
        const SizedBox(height: 12),
        _InputShell(
          label: 'Service Address *',
          hint: 'Where customers should visit',
          controller: _addressController,
        ),
      ],
      const SizedBox(height: 16),
      const _SectionLabel('Service hours *'),
      const SizedBox(height: 10),
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
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('–'),
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
      const SizedBox(height: 16),
      const _SectionLabel('Service areas *'),
      const SizedBox(height: 10),
      _ServiceAreasEditor(
        controllers: _serviceAreaControllers,
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 16),
      const _SectionLabel('Weekly availability'),
      const SizedBox(height: 10),
      _EditableAvailabilityPanel(
        days: _availability,
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Visible to customers when published',
              style: TextStyle(
                color: Color(0xFF060D35),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch.adaptive(
            value: _visible,
            onChanged: (v) => setState(() => _visible = v),
          ),
        ],
      ),
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
      if (name.isEmpty && hoursRaw.isEmpty && priceRaw.isEmpty) continue;
      if (name.isEmpty) return 'Enter a name for each subservice.';
      final hours = double.tryParse(hoursRaw);
      if (hoursRaw.isEmpty || hours == null || hours <= 0) {
        return 'Enter hours greater than zero for each subservice.';
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
      if (_priceController.text.trim().isEmpty || price == null || price < 0) {
        return 'Enter a valid price of zero or more.';
      }
      final subError = _validateSubservices();
      if (subError != null) return subError;
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
        'subservices': _subservices
            .where((s) =>
                s.nameController.text.trim().isNotEmpty ||
                s.hoursController.text.trim().isNotEmpty ||
                s.priceController.text.trim().isNotEmpty)
            .map((s) => {
                  'name': s.nameController.text.trim(),
                  'hours': double.tryParse(s.hoursController.text.trim()) ?? 0,
                  'price': double.tryParse(s.priceController.text.trim()) ?? 0,
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

class _FlowHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onSaveDraft;
  final VoidCallback onBack;

  const _FlowHeader({
    required this.title,
    this.trailing,
    this.onSaveDraft,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        6,
        MediaQuery.of(context).padding.top + 8,
        12,
        0,
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(LucideIcons.arrowLeft, size: 22),
              color: const Color(0xFF060D35),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF060D35),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            SizedBox(
              width: 92,
              child: trailing == null
                  ? const SizedBox.shrink()
                  : TextButton(
                      onPressed: onSaveDraft,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        trailing!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

class _FlowSteps extends StatelessWidget {
  final int step;
  final int totalSteps;
  final List<String> labels;
  final ValueChanged<int> onStepTap;

  const _FlowSteps({
    required this.step,
    required this.totalSteps,
    required this.labels,
    required this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= totalSteps; i++) ...[
          Expanded(
            child: InkWell(
              onTap: () => onStepTap(i),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (i > 1)
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFD5DEE4),
                            thickness: 2,
                          ),
                        )
                      else
                        const Spacer(),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < step
                              ? const Color(0xFF078D92)
                              : i == step
                                  ? const Color(0xFF060D35)
                                  : Colors.white,
                          border: Border.all(
                            color: i <= step
                                ? Colors.transparent
                                : const Color(0xFFD5DEE4),
                            width: 1.5,
                          ),
                        ),
                        child: i < step
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 15)
                            : Text(
                                '$i',
                                style: TextStyle(
                                  color: i == step
                                      ? Colors.white
                                      : const Color(0xFF8B90A2),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                      ),
                      if (i < totalSteps)
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFD5DEE4),
                            thickness: 2,
                          ),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i - 1],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: i == step
                          ? const Color(0xFF060D35)
                          : const Color(0xFF8B90A2),
                      fontSize: 10.5,
                      fontWeight: i == step ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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

class _FlowFooter extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final VoidCallback onPublish;
  final String publishLabel;
  final bool publishing;

  const _FlowFooter({
    required this.step,
    this.totalSteps = 2,
    required this.onContinue,
    this.onBack,
    required this.onPublish,
    this.publishLabel = 'Publish',
    this.publishing = false,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final primary = SizedBox(
      height: 50,
      child: FilledButton(
        onPressed:
            publishing ? null : (step < totalSteps ? onContinue : onPublish),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF078D92),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: publishing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  step < totalSteps ? 'Continue' : publishLabel,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 12 + bottomPad),
      child: onBack == null
          ? SizedBox(width: double.infinity, child: primary)
          : Row(
              children: [
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: publishing ? null : onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF060D35),
                      side: const BorderSide(color: Color(0xFFD5DEE4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Text(
                      'Back',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: primary),
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

String _rateTypeFor(String rateType) {
  return switch (rateType) {
    'Fixed price' => 'fixed',
    'Per hour' => 'per_hour',
    'Per session' => 'per_session',
    // API enum: starting_from, fixed, per_hour, per_session.
    _ => 'starting_from',
  };
}

class _ServiceSubservice {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController hoursController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  void dispose() {
    nameController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final total = pending.length + uploaded.length;
    if (total == 0) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD5DEE4), width: 1.2),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.cloudUpload,
                    color: Color(0xFF684AC8), size: 36),
                SizedBox(height: 12),
                Text(
                  'Add service photos',
                  style: TextStyle(
                    color: Color(0xFF060D35),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'JPG, PNG up to 10MB (max 10)',
                  style: TextStyle(
                    color: Color(0xFF29304D),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: total,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final isMain = index == mainIndex;
              final isPending = index < pending.length;
              Widget thumb;
              if (isPending) {
                thumb = FutureBuilder(
                  future: pending[index].readAsBytes(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const SizedBox(width: 110, height: 110);
                    }
                    return Image.memory(
                      snap.data!,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    );
                  },
                );
              } else {
                final img = uploaded[index - pending.length];
                thumb = StoreItemImage(
                  imageUrl: img.fileUrl.isNotEmpty ? img.fileUrl : img.fileName,
                  icon: LucideIcons.image,
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                );
              }
              return GestureDetector(
                onTap: () => onSetMain(index),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isMain ? const Color(0xFF078D92) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        thumb,
                        if (isMain)
                          const Positioned(
                            left: 4,
                            bottom: 4,
                            child: ColoredBox(
                              color: Colors.black54,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                child: Text(
                                  'Main',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => isPending
                                ? onRemovePending(index)
                                : onRemoveUploaded(index - pending.length),
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
                  ),
                ),
              );
            },
          ),
        ),
        TextButton(
          onPressed: onPick,
          child: const Text(
            '+ Add more (max 10)',
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
        const Text(
          'Key Highlights *',
          style: TextStyle(
            color: Color(0xFF29304D),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        for (var i = 0; i < controllers.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _InputShell(
                  label: 'Highlight ${i + 1}',
                  hint: 'e.g. All equipment included',
                  controller: controllers[i],
                ),
              ),
              IconButton(
                onPressed: () {
                  controllers[i].dispose();
                  controllers.removeAt(i);
                  onChanged();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                color: const Color(0xFF8B90A2),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (controllers.length < max)
          TextButton(
            onPressed: () {
              controllers.add(TextEditingController());
              onChanged();
            },
            child: const Text(
              '+ Add Highlight (Max 5)',
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD5DEE4)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          value.isEmpty ? placeholder : value,
          style: TextStyle(
            color: value.isEmpty
                ? const Color(0xFF8B90A2)
                : const Color(0xFF060D35),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
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
      children: [
        for (var i = 0; i < controllers.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _InputShell(
                  label: 'Area ${i + 1}',
                  hint: 'e.g. Malad',
                  controller: controllers[i],
                ),
              ),
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
                icon: const Icon(Icons.close_rounded, size: 18),
                color: const Color(0xFF8B90A2),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              controllers.add(TextEditingController());
              onChanged();
            },
            child: const Text(
              '+ Add Area',
              style: TextStyle(
                color: Color(0xFF078D92),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SubservicesEditor extends StatefulWidget {
  final List<_ServiceSubservice> subservices;
  final VoidCallback onChanged;

  const _SubservicesEditor({
    required this.subservices,
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
                          widget.subservices[i].dispose();
                          widget.subservices.removeAt(i);
                        });
                        widget.onChanged();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: const Color(0xFF8B90A2),
                    ),
                  ],
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
