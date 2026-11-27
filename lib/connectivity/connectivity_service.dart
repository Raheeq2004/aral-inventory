import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  static final ConnectivityService instance = ConnectivityService();

  final Connectivity _connectivity;

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  StreamController<bool>? _controller;
  bool _initialized = false;

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  Future<bool> initialize() async {
    final bool current = await checkInitialConnection();
    isOnline.value = current;

    if (!_initialized) {
      _initialized = true;
      _controller ??= StreamController<bool>.broadcast();
      _subscription = _connectivity.onConnectivityChanged.listen((results) {
        final bool online = _hasConnection(results);
        isOnline.value = online;
        _controller?.add(online);
      });
    }
    return current;
  }

  Stream<bool> get onConnectivityChanged {
    _controller ??= StreamController<bool>.broadcast();
    if (!_initialized) {
      unawaited(initialize());
    }
    return _controller!.stream;
  }

  Future<bool> checkInitialConnection() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    final bool online = _hasConnection(results);
    isOnline.value = online;
    return online;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _controller?.close();
    _controller = null;
    _initialized = false;
  }
}
