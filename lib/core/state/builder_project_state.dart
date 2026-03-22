import 'package:flutter/foundation.dart';

/// Tracks which project the builder currently has "active" (open/focused on).
///
/// Before switching to a different project, the projects page shows a
/// confirmation dialog — preventing accidental uploads to the wrong project.
class BuilderProjectState extends ChangeNotifier {
  String? _activeProjectId;
  String? _activeProjectTitle;

  String? get activeProjectId => _activeProjectId;
  String? get activeProjectTitle => _activeProjectTitle;

  bool get hasActive => _activeProjectId != null;

  bool isSameProject(String projectId) => _activeProjectId == projectId;

  void activate(String projectId, String title) {
    if (_activeProjectId == projectId) return;
    _activeProjectId = projectId;
    _activeProjectTitle = title;
    notifyListeners();
  }

  void clear() {
    _activeProjectId = null;
    _activeProjectTitle = null;
    notifyListeners();
  }
}
