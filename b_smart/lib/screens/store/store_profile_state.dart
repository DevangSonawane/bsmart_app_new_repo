import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api/phase2_store_api.dart';
import '../../models/store_profile.dart';
import '../../utils/app_error_handler.dart';
import '../../utils/current_user.dart';

/// Per-seller storefront profile cache.
///
/// `GET /api/users/:id/store-profile` is public and returns everything the
/// storefront header needs in one call, so profiles are cached per user id
/// and shared across widgets.
class StoreProfileState extends ChangeNotifier {
  StoreProfileState._();

  static final StoreProfileState instance = StoreProfileState._();

  final Phase2StoreApi _api = Phase2StoreApi();

  final Map<String, StoreProfile> _profiles = {};
  final Set<String> _loading = {};
  final Map<String, Object> _errors = {};
  String? _selfId;

  StoreProfile? profileFor(String? userId) {
    final id = userId?.trim();
    if (id == null || id.isEmpty) return null;
    return _profiles[id];
  }

  bool isLoading(String? userId) {
    final id = userId?.trim();
    return id != null && _loading.contains(id);
  }

  bool hasError(String? userId) {
    final id = userId?.trim();
    return id != null && _errors.containsKey(id);
  }

  String? errorMessage(String? userId) {
    final id = userId?.trim();
    final error = id == null ? null : _errors[id];
    if (error == null) return null;
    return AppErrorHandler.userMessage(
      error,
      fallback: 'Could not load the store profile. Please try again.',
    );
  }

  bool isSelf(String? userId) =>
      _selfId != null && userId?.trim() == _selfId;

  /// Loads a seller's profile once; safe to call from initState.
  Future<void> ensureLoaded(String? userId) {
    final id = userId?.trim();
    if (id == null || id.isEmpty) return Future.value();
    if (_profiles.containsKey(id) || _loading.contains(id)) {
      return Future.value();
    }
    return load(id);
  }

  Future<void> load(String userId, {bool force = false}) async {
    final id = userId.trim();
    if (id.isEmpty) return;
    if (_loading.contains(id)) return;
    if (!force && _profiles.containsKey(id)) return;

    _loading.add(id);
    _errors.remove(id);
    notifyListeners();
    try {
      _profiles[id] = await _api.getStoreProfile(id);
    } catch (e) {
      _errors[id] = e;
    } finally {
      _loading.remove(id);
      notifyListeners();
    }
  }

  /// Updates the signed-in seller's own storefront profile.
  ///
  /// Only non-null arguments are sent, per the endpoint's partial-update
  /// behaviour.
  Future<StoreProfile> updateSelf({
    List<String>? serviceAreas,
    List<String>? languages,
    List<String>? trustBadges,
    String? storeType,
  }) async {
    final id = await CurrentUser.id;
    if (id == null || id.isEmpty) {
      throw StateError('You need to be signed in to edit the store profile.');
    }
    final patch = const StoreProfile().toUpdateJson(
              serviceAreas: serviceAreas,
              languages: languages,
              trustBadges: trustBadges,
              storeType: storeType,
            );
    if (patch.isEmpty) {
      throw ArgumentError('Nothing to update on the store profile.');
    }

    _loading.add(id);
    _errors.remove(id);
    notifyListeners();
    try {
      final updated = await _api.updateStoreProfile(body: patch);
      _selfId = id;
      _profiles[id] = _merge(_profiles[id], updated, patch);
      return _profiles[id]!;
    } catch (e) {
      _errors[id] = e;
      rethrow;
    } finally {
      _loading.remove(id);
      notifyListeners();
    }
  }

  /// Applies a partial update on top of the cached profile so the header
  /// reflects the change even when the server only acks.
  static StoreProfile _merge(
    StoreProfile? base,
    StoreProfile updated,
    Map<String, dynamic> patch,
  ) {
    final current = base ?? updated;
    return StoreProfile(
      storeName: updated.storeName.isNotEmpty
          ? updated.storeName
          : current.storeName,
      storeType: patch.containsKey('store_type')
          ? updated.storeType
          : (updated.storeType.isNotEmpty
              ? updated.storeType
              : current.storeType),
      about: updated.about.isNotEmpty ? updated.about : current.about,
      serviceAreas: patch.containsKey('service_areas')
          ? updated.serviceAreas
          : (updated.serviceAreas.isNotEmpty
              ? updated.serviceAreas
              : current.serviceAreas),
      languages: patch.containsKey('languages')
          ? updated.languages
          : (updated.languages.isNotEmpty
              ? updated.languages
              : current.languages),
      trustBadges: patch.containsKey('trust_badges')
          ? updated.trustBadges
          : (updated.trustBadges.isNotEmpty
              ? updated.trustBadges
              : current.trustBadges),
      followersCount: updated.followersCount,
      followingCount: updated.followingCount,
      isFollowing: updated.isFollowing,
      productCount: updated.productCount,
      serviceCount: updated.serviceCount,
      memberSince: updated.memberSince.isNotEmpty
          ? updated.memberSince
          : current.memberSince,
    );
  }

  /// Marks the signed-in user so `isSelf` works before the first update.
  void setSelfId(String? id) {
    final trimmed = id?.trim();
    if (_selfId == trimmed) return;
    _selfId = trimmed;
    notifyListeners();
  }
}
