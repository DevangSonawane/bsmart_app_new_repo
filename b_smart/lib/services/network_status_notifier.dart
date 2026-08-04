import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkStatusNotifier extends ChangeNotifier {
  NetworkStatusNotifier._();

  static final NetworkStatusNotifier instance = NetworkStatusNotifier._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  List<ConnectivityResult> _results = const <ConnectivityResult>[];

  List<ConnectivityResult> get results => _results;

  bool get isOffline => _results.contains(ConnectivityResult.none);

  bool get isOnMobileData => _results.contains(ConnectivityResult.mobile);

  bool get isOnWifi =>
      _results.contains(ConnectivityResult.wifi) ||
      _results.contains(ConnectivityResult.ethernet);

  bool get shouldRestrictDownloads {
    if (isOffline) return true;
    return isOnMobileData || !isOnWifi;
  }

  Future<void> initialize() async {
    _results = await _connectivity.checkConnectivity();
    notifyListeners();
    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      _results = results;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
