// lib/core/storage/storage_service.dart
//
// File IO helpers used across the app. Provides:
// - readJsonAtPath, writeJsonToPath
// - writeBytesToPath, readBytes
// - listJson<T>()  (generic to satisfy older call-sites that expect StoredFile)
// - listJson() returning List<String> (paths)
//
// Also defines a tiny StoredFile adapter to satisfy legacy usages.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredFile {
  final String path;
  final String filename;
  const StoredFile(this.path, this.filename);
}

class StorageService {
  StorageService({String appFolderName = 'BuildWise'})
      : _appFolderName = appFolderName;

  final String _appFolderName;

  Future<Directory> _ensureAppRoot() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, _appFolderName));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> _ensureSub(String sub) async {
    final root = await _ensureAppRoot();
    final d = Directory(p.join(root.path, sub));
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  // ---------- Bytes ----------

  Future<Uint8List> readBytes(String fullPath) async {
    final f = File(fullPath);
    return await f.readAsBytes();
  }

  Future<String> writeBytesToPath(String fullPath, Uint8List bytes) async {
    final f = File(fullPath);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  // ---------- JSON (generic paths) ----------

  Future<Map<String, dynamic>> readJsonAtPath(String fullPath) async {
    final f = File(fullPath);
    final raw = await f.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    throw const FormatException('JSON root is not an object');
  }

  Future<String> writeJsonToPath(
      String fullPath, Map<String, dynamic> data) async {
    final f = File(fullPath);
    await f.parent.create(recursive: true);
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data),
        flush: true);
    return f.path;
  }

  // ---------- JSON (default app area) ----------

  Future<String> writeJson(String filename, Map<String, dynamic> data) async {
    final estimatesDir = await _ensureSub('estimates');
    final path = p.join(estimatesDir.path, filename);
    return writeJsonToPath(path, data);
  }

  /// Legacy-friendly generic list:
  /// - T == String => returns List<String> of full paths
  /// - T == StoredFile => returns List<StoredFile>
  Future<List<T>> listJson<T>({String subFolder = 'estimates'}) async {
    final dir = await _ensureSub(subFolder);
    final files = await dir
        .list()
        .where((e) => e is File && e.path.toLowerCase().endsWith('.json'))
        .cast<File>()
        .toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    if (T == StoredFile) {
      return files.map((f) => StoredFile(f.path, p.basename(f.path))).toList()
          as List<T>;
    }

    // default: List<String>
    return files.map((f) => f.path).toList() as List<T>;
  }

  /// Simple non-generic variant: paths only.
  Future<List<String>> listJsonPaths({String subFolder = 'estimates'}) =>
      listJson<String>(subFolder: subFolder);
}
