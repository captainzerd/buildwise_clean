// lib/core/storage/local_doc_store.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalDocStore {
  /// Reads an array JSON file "app-docs/{subFolder}/{filename}".
  static Future<List<Map<String, dynamic>>> readAll({
    required String subFolder,
    required String filename,
  }) async {
    final file = await _file(subFolder, filename);
    if (!await file.exists()) return <Map<String, dynamic>>[];
    final txt = await file.readAsString();
    final decoded = jsonDecode(txt);
    if (decoded is List) {
      return decoded
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  /// Appends an entry to the JSON array and writes pretty JSON.
  static Future<void> append({
    required String subFolder,
    required String filename,
    required Map<String, dynamic> entry,
  }) async {
    final file = await _file(subFolder, filename);
    final list = await readAll(subFolder: subFolder, filename: filename);
    list.add(entry);
    final pretty = const JsonEncoder.withIndent('  ').convert(list);
    await file.create(recursive: true);
    await file.writeAsString(pretty, flush: true);
  }

  static Future<File> _file(String subFolder, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$subFolder/$filename');
  }
}
