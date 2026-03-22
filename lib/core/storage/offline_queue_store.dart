// lib/core/storage/offline_queue_store.dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Persists a queue of pending write operations as a JSON array.
/// Each entry is a map with {'id': String (UUID), 'op': String, 'projectId': String, 'payload': Map}.
class OfflineQueueStore {
  static const _filename = 'offline_queue.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/offline_queue/$_filename');
    if (!await f.parent.exists()) {
      await f.parent.create(recursive: true);
    }
    return f;
  }

  Future<List<Map<String, dynamic>>> readAll() async {
    final file = await _file();
    if (!await file.exists()) return [];
    try {
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
      }
    } catch (_) {
      // corrupt — reset
      await _write([]);
    }
    return [];
  }

  Future<void> enqueue(Map<String, dynamic> op) async {
    final opWithId = {
      'id': const Uuid().v4(),
      ...op,
    };
    final list = await readAll();
    list.add(opWithId);
    await _write(list);
  }

  Future<void> dequeueAll() async {
    await _write([]);
  }

  Future<void> removeAt(int index) async {
    final list = await readAll();
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      await _write(list);
    }
  }

  Future<void> _write(List<Map<String, dynamic>> list) async {
    final file = await _file();
    final json = const JsonEncoder.withIndent('  ').convert(list);
    await file.writeAsString(json, flush: true);
  }
}
