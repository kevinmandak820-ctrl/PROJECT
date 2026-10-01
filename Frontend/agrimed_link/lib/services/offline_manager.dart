import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Singleton that tracks online/offline status via connectivity_plus.
/// Usage:
///   await OfflineManager.instance.init(); // call once in main()
///   OfflineManager.instance.isOffline.value // current status
class OfflineManager {
  OfflineManager._();
  static final OfflineManager instance = OfflineManager._();

  /// True when the device has no network connection.
  final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  /// Subscribe to connectivity changes. Call once from main().
  Future<void> init() async {
    final result = await Connectivity().checkConnectivity();
    isOffline.value = _isDisconnected(result);

    Connectivity().onConnectivityChanged.listen((results) {
      // onConnectivityChanged returns List<ConnectivityResult> in v6+
      isOffline.value = results.every(_isDisconnected);
    });
  }

  /// One-shot connectivity check. Returns true if offline.
  Future<bool> checkOnce() async {
    final result = await Connectivity().checkConnectivity();
    return _isDisconnected(result);
  }

  static bool _isDisconnected(dynamic result) {
    if (result is List) {
      return (result as List<ConnectivityResult>).every(
        (r) => r == ConnectivityResult.none,
      );
    }
    return result == ConnectivityResult.none;
  }
}
