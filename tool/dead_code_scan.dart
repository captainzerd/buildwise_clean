// tool/dead_code_scan.dart
import 'dart:io';

final ignoreDirs = {
  '.dart_tool',
  'build',
  '.git',
  'android',
  'ios',
  'web',
  'linux',
  'macos',
  'windows',
  'test'
};
final whitelistEntrypoints = {'lib/main.dart'};

void main() async {
  final allDart = <String>{};
  final imported = <String>{};

  void walk(Directory d) {
    for (final e in d.listSync(recursive: false, followLinks: false)) {
      final path = e.path.replaceAll('\\', '/');
      final name = path.split('/').last;
      if (e is Directory) {
        if (ignoreDirs.contains(name)) continue;
        walk(e);
      } else if (e is File && path.endsWith('.dart')) {
        allDart.add(path);
        final text = e.readAsStringSync();
        final regex = RegExp(r'''import\s+['"]([^'"]+)['"]''');
        for (final m in regex.allMatches(text)) {
          var imp = m.group(1)!;
          if (!imp.startsWith('package:') && imp.endsWith('.dart')) {
            // Normalize relative imports
            final from = File(path).parent.path.replaceAll('\\', '/');
            final normalized =
                File(Uri.file(from + '/' + imp).normalizePath().toFilePath())
                    .path
                    .replaceAll('\\', '/');
            imported.add(Uri.file(normalized)
                .normalizePath()
                .toFilePath()
                .replaceAll('\\', '/'));
          }
        }
      }
    }
  }

  walk(Directory('lib'));

  // Add known entrypoints
  imported.addAll(whitelistEntrypoints);

  final unused = allDart
      .where((f) =>
          f.startsWith('lib/') &&
          !imported.contains(f) &&
          !whitelistEntrypoints.contains(f))
      .toList()
    ..sort();

  if (unused.isEmpty) {
    print('✅ No obviously unused files.');
  } else {
    print('🧹 Candidates for removal (${unused.length}):');
    for (final f in unused) {
      print(' - $f');
    }
  }
}
