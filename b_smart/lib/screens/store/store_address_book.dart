import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A structured delivery address.
class ShipAddress {
  final String id;
  final String label;
  final String name;
  final String phone;
  final String line1;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;

  const ShipAddress({
    required this.id,
    required this.label,
    required this.name,
    required this.phone,
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    this.isDefault = false,
  });

  String get summaryLine =>
      [line1, city, state, pincode].where((e) => e.trim().isNotEmpty).join(', ');

  /// `shipping_address` for `POST /api/orders/checkout` (Phase 2 md).
  Map<String, String> toShippingJson() => {
        'name': name,
        'phone': phone,
        'address_line1': line1,
        'city': city,
        'state': state,
        'pincode': pincode,
      };

  /// `customer_address` for `POST /api/service-bookings` (Phase 2 md).
  /// Only line1/city/pincode are required by the spec.
  Map<String, String> toCustomerJson() => {
        'address_line1': line1,
        'city': city,
        'pincode': pincode,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'name': name,
        'phone': phone,
        'line1': line1,
        'city': city,
        'state': state,
        'pincode': pincode,
        'isDefault': isDefault,
      };

  factory ShipAddress.fromJson(Map<String, dynamic> json) => ShipAddress(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? 'Home',
        name: json['name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        line1: json['line1']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        pincode: json['pincode']?.toString() ?? '',
        isDefault: json['isDefault'] == true,
      );

  ShipAddress copyWith({
    String? label,
    String? name,
    String? phone,
    String? line1,
    String? city,
    String? state,
    String? pincode,
    bool? isDefault,
  }) {
    return ShipAddress(
      id: id,
      label: label ?? this.label,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      line1: line1 ?? this.line1,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// Persisted address book shared by checkout and service booking.
///
/// The Phase 2 API has no address endpoints, so addresses live on-device
/// (SharedPreferences) and are sent inline with each order/booking.
class StoreAddressBook extends ChangeNotifier {
  StoreAddressBook._();

  static final StoreAddressBook instance = StoreAddressBook._();

  static const _prefsKey = 'bstore_address_book_v1';

  static List<ShipAddress> _seed() => [
        const ShipAddress(
          id: 'home',
          label: 'Home',
          name: 'B-Smart Customer',
          phone: '9999999999',
          line1: '24 Market Street',
          city: 'Mumbai',
          state: 'MH',
          pincode: '400001',
          isDefault: true,
        ),
        const ShipAddress(
          id: 'work',
          label: 'Work',
          name: 'B-Smart Customer',
          phone: '9999999999',
          line1: '460 Harbor Avenue',
          city: 'Mumbai',
          state: 'MH',
          pincode: '400051',
        ),
      ];

  List<ShipAddress> _addresses = _seed();
  bool _loaded = false;
  String? _selectedId;

  List<ShipAddress> get addresses => List.unmodifiable(_addresses);

  ShipAddress get selected {
    final match = _addresses.where((a) => a.id == _selectedId);
    if (match.isNotEmpty) return match.first;
    final def = _addresses.where((a) => a.isDefault);
    if (def.isNotEmpty) return def.first;
    return _addresses.first;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) {
        notifyListeners();
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final parsed = decoded
            .whereType<Map>()
            .map((m) => ShipAddress.fromJson(
                m.map((key, value) => MapEntry(key.toString(), value))))
            .where((a) => a.line1.trim().isNotEmpty)
            .toList();
        if (parsed.isNotEmpty) _addresses = parsed;
      }
    } catch (_) {
      // Keep seeds on any failure.
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey,
          jsonEncode(_addresses.map((a) => a.toJson()).toList()));
    } catch (_) {}
  }

  void select(String id) {
    _selectedId = id;
    notifyListeners();
  }

  Future<void> add(ShipAddress address) async {
    final withId = address.id.isEmpty
        ? address.copyWith()
        : address;
    _addresses = [
      ..._addresses,
      ShipAddress(
        id: withId.id.isEmpty
            ? 'addr_${DateTime.now().millisecondsSinceEpoch}'
            : withId.id,
        label: withId.label,
        name: withId.name,
        phone: withId.phone,
        line1: withId.line1,
        city: withId.city,
        state: withId.state,
        pincode: withId.pincode,
        isDefault: _addresses.isEmpty ? true : withId.isDefault,
      ),
    ];
    if (_addresses.length == 1) _selectedId = _addresses.first.id;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> update(String id, ShipAddress address) async {
    _addresses = _addresses
        .map((a) => a.id == id
            ? ShipAddress(
                id: id,
                label: address.label,
                name: address.name,
                phone: address.phone,
                line1: address.line1,
                city: address.city,
                state: address.state,
                pincode: address.pincode,
                isDefault: a.isDefault,
              )
            : a)
        .toList();
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> remove(String id) async {
    if (_addresses.length <= 1) return;
    final removedDefault =
        _addresses.any((a) => a.id == id && a.isDefault);
    _addresses = _addresses.where((a) => a.id != id).toList();
    if (removedDefault && _addresses.isNotEmpty) {
      _addresses = [
        _addresses.first.copyWith(isDefault: true),
        ..._addresses.skip(1),
      ];
    }
    if (_selectedId == id) _selectedId = null;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> setDefault(String id) async {
    _addresses =
        _addresses.map((a) => a.copyWith(isDefault: a.id == id)).toList();
    notifyListeners();
    unawaited(_persist());
  }
}
