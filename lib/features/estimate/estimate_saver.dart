// lib/features/estimate/estimate_saver.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/services/auth_service.dart';
import '../../core/storage/storage_service.dart';

dynamic _tryFirestore() {
  try {
    // ignore: avoid_dynamic_calls
    return (firebaseFirestoreInstanceGetter)();
  } catch (_) {
    return null;
  }
}

// ignore: prefer_function_declarations_over_variables
dynamic Function() firebaseFirestoreInstanceGetter =
    () => FirebaseFirestore.instance;

class EstimateSaver with ChangeNotifier {
  EstimateSaver({
    required bool useCloud,
    required AuthService auth,
    required StorageService storage,
  })  : _useCloud = useCloud,
        _auth = auth,
        _storage = storage;

  final bool _useCloud;
  final AuthService _auth;
  final StorageService _storage;

  bool _saving = false;
  Object? _lastError;

  bool get isSaving => _saving;
  Object? get lastError => _lastError;

  bool get _isAuthed {
    try {
      final dyn = _auth as dynamic;
      final isSignedIn = dyn.isSignedIn as bool?;
      if (isSignedIn == true) return true;
      final user = dyn.user;
      return user != null;
    } catch (_) {
      return false;
    }
  }

  String get _uid {
    try {
      final user = (_auth as dynamic).user;
      final id = (user?.uid as String?) ?? 'anon';
      return id;
    } catch (_) {
      return 'anon';
    }
  }

  Future<void> save(String id, Map<String, dynamic> data) async {
    _saving = true;
    _lastError = null;
    notifyListeners();

    try {
      if (_useCloud && _isAuthed) {
        final fs = _tryFirestore();
        if (fs != null) {
          // ignore: avoid_dynamic_calls
          await fs
              .collection('users')
              .doc(_uid)
              .collection('estimates')
              .doc(id)
              .set(data);
        } else {
          await _saveLocal(id, data);
        }
      } else {
        await _saveLocal(id, data);
      }
    } catch (e) {
      _lastError = e;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<void> delete(String id) async {
    try {
      if (_useCloud && _isAuthed) {
        final fs = _tryFirestore();
        if (fs != null) {
          // ignore: avoid_dynamic_calls
          await fs
              .collection('users')
              .doc(_uid)
              .collection('estimates')
              .doc(id)
              .delete();
        }
      }
    } catch (_) {}

    try {
      await _deleteLocal(id);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> listLocal() async {
    try {
      final dyn = _storage as dynamic;
      final listEstimates = dyn.listEstimates;
      if (listEstimates != null) {
        final result = await listEstimates.call();
        return (result as List).cast<Map<String, dynamic>>();
      }
      final readFolderJson = dyn.readFolderJson;
      if (readFolderJson != null) {
        final result = await readFolderJson.call('estimates');
        return (result as List).cast<Map<String, dynamic>>();
      }
      return const <Map<String, dynamic>>[];
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>?> read(String id) async {
    if (_useCloud && _isAuthed) {
      final fs = _tryFirestore();
      if (fs != null) {
        try {
          // ignore: avoid_dynamic_calls
          final snap = await fs
              .collection('users')
              .doc(_uid)
              .collection('estimates')
              .doc(id)
              .get();
          // ignore: avoid_dynamic_calls
          if (snap.exists == true) {
            // ignore: avoid_dynamic_calls
            final data = Map<String, dynamic>.from(snap.data());
            return data;
          }
        } catch (_) {}
      }
    }
    return _readLocal(id);
  }

  Future<void> _saveLocal(String id, Map<String, dynamic> data) async {
    final dyn = _storage as dynamic;
    final saveEstimate = dyn.saveEstimate;
    if (saveEstimate != null) {
      await saveEstimate.call(id, data);
      return;
    }
    final writeJson = dyn.writeJson;
    if (writeJson != null) {
      await writeJson.call('estimates/$id.json', data);
      return;
    }
    final setItem = dyn.setItem;
    if (setItem != null) {
      await setItem.call('estimates:$id', data);
      return;
    }
    throw StateError('StorageService has no save methods for estimates.');
  }

  Future<Map<String, dynamic>?> _readLocal(String id) async {
    final dyn = _storage as dynamic;

    final readEstimate = dyn.readEstimate;
    if (readEstimate != null) {
      final result = await readEstimate.call(id);
      return (result == null) ? null : Map<String, dynamic>.from(result);
    }

    final readJson = dyn.readJson;
    if (readJson != null) {
      final result = await readJson.call('estimates/$id.json');
      return (result == null) ? null : Map<String, dynamic>.from(result);
    }

    final getItem = dyn.getItem;
    if (getItem != null) {
      final result = await getItem.call('estimates:$id');
      return (result == null) ? null : Map<String, dynamic>.from(result);
    }

    return null;
  }

  Future<void> _deleteLocal(String id) async {
    final dyn = _storage as dynamic;

    final deleteEstimate = dyn.deleteEstimate;
    if (deleteEstimate != null) {
      await deleteEstimate.call(id);
      return;
    }
    final delete = dyn.delete;
    if (delete != null) {
      await delete.call('estimates/$id.json');
      return;
    }
    final removeItem = dyn.removeItem;
    if (removeItem != null) {
      await removeItem.call('estimates:$id');
    }
  }
}
