import 'package:flutter/foundation.dart';

/// Central app badge state (bottom bar bubble counts).
class AppBadges extends ChangeNotifier {
  int _complaints = 0;
  int _vendors = 0;
  int _projects = 0;
  int _account = 0;

  int get complaints => _complaints;
  int get vendors => _vendors;
  int get projects => _projects;
  int get account => _account;

  void setComplaints(int n) {
    if (n != _complaints) {
      _complaints = n;
      notifyListeners();
    }
  }

  void setVendors(int n) {
    if (n != _vendors) {
      _vendors = n;
      notifyListeners();
    }
  }

  void setProjects(int n) {
    if (n != _projects) {
      _projects = n;
      notifyListeners();
    }
  }

  void setAccount(int n) {
    if (n != _account) {
      _account = n;
      notifyListeners();
    }
  }

  /// Convenience for clearing all badges.
  void clearAll() {
    _complaints = _vendors = _projects = _account = 0;
    notifyListeners();
  }
}
