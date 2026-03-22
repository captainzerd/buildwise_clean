// lib/core/services/connectivity_service.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 5), (_) => _check());
    // Run immediately on start
    _check();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      _set(result.isNotEmpty && result.first.rawAddress.isNotEmpty);
    } catch (_) {
      _set(false);
    }
  }

  void _set(bool v) {
    if (v != _isOnline) {
      _isOnline = v;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
