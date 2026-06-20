import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkStatus {
  final bool isOnline;
  const NetworkStatus(this.isOnline);
}

final connectivityProvider = StreamProvider<NetworkStatus>((ref) {
  final connectivity = Connectivity();
  final controller = StreamController<NetworkStatus>();

  Future<void> emit(List<ConnectivityResult> results) async {
    final online = results.any((r) => r != ConnectivityResult.none);
    controller.add(NetworkStatus(online));
  }

  connectivity.checkConnectivity().then(emit);
  final sub = connectivity.onConnectivityChanged.listen(emit);

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});
