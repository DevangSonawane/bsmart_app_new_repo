import 'package:flutter/material.dart';

import '../../api/address_api.dart';
import '../../models/ship_address.dart';
import '../../utils/app_error_handler.dart';

export '../../models/ship_address.dart';

/// Server-backed saved address book shared by product checkout and service
/// booking.
///
/// Backed by `/api/addresses`. The server owns the default-address rules
/// (first saved becomes default; deleting the default promotes the next most
/// recent), so every mutation re-reads the list rather than patching local
/// state.
class StoreAddressBook extends ChangeNotifier {
  StoreAddressBook._();

  static final StoreAddressBook instance = StoreAddressBook._();

  final AddressApi _api = AddressApi();

  List<ShipAddress> _addresses = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  bool _saving = false;
  Object? _lastError;
  String? _selectedId;

  List<ShipAddress> get addresses => List.unmodifiable(_addresses);
  bool get isEmpty => _addresses.isEmpty;
  bool get loading => _loading;
  bool get saving => _saving;
  Object? get lastError => _lastError;

  /// User-facing text for [lastError]; never a raw exception.
  String? get lastErrorMessage {
    final error = _lastError;
    if (error == null) return null;
    return AppErrorHandler.userMessage(
      error,
      fallback: 'Could not load your addresses. Please try again.',
    );
  }

  /// The address to deliver to, or null when none are saved.
  ///
  /// `GET /addresses` returns the default first, so the default is preferred
  /// over any ad-hoc selection.
  ShipAddress? get selected {
    final match = _addresses.where((a) => a.id == _selectedId);
    if (match.isNotEmpty) return match.first;
    final def = _addresses.where((a) => a.isDefault);
    if (def.isNotEmpty) return def.first;
    return _addresses.isEmpty ? null : _addresses.first;
  }

  /// Loads once (idempotent) — safe to call from widget initStates.
  Future<void> ensureLoaded() {
    if (_loadedOnce || _loading) return Future.value();
    return refresh();
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _lastError = null;
    notifyListeners();
    try {
      _addresses = await _api.list();
      _loadedOnce = true;
      if (_selectedId != null &&
          !_addresses.any((a) => a.id == _selectedId)) {
        _selectedId = null;
      }
    } catch (e) {
      _lastError = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Local-only selection for the current checkout; not persisted.
  void select(String id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  Future<void> add(ShipAddress address) async {
    if (_saving) return;
    _saving = true;
    _lastError = null;
    notifyListeners();
    try {
      _addresses = await _api.create(address);
      _selectedId = _addresses.isEmpty
          ? null
          : (address.id.isEmpty ? _addresses.last.id : address.id);
    } catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> update(String id, ShipAddress address) async {
    if (_saving) return;
    _saving = true;
    _lastError = null;
    notifyListeners();
    try {
      _addresses = await _api.update(id, address);
    } catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    if (_saving) return;
    _saving = true;
    _lastError = null;
    notifyListeners();
    try {
      _addresses = await _api.remove(id);
      if (_selectedId == id) _selectedId = null;
    } catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> setDefault(String id) async {
    if (_saving) return;
    _saving = true;
    _lastError = null;
    notifyListeners();
    try {
      _addresses = await _api.setDefault(id);
      _selectedId = id;
    } catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
