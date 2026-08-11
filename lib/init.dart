import 'dart:io';

import 'package:path/path.dart' as p;

/// Known MCU board scaffolds under `templates/<id>/` (issue 075 / 054).
const knownInitBoards = <String>['nucleo-f411'];

/// Package root containing `bin/`, `lib/`, `templates/`.
///
/// Prefer walking up from [Directory.current] / the entry script until
/// `pubspec.yaml` + `templates/` are found (works for `dart run` and tests).
String klinPackageRoot({String? override}) {
  if (override != null) return override;

  final candidates = <String>[
    if (Platform.script.scheme == 'file')
      p.dirname(Platform.script.toFilePath()),
    Directory.current.path,
  ];
  for (final start in candidates) {
    var dir = p.normalize(start);
    for (var i = 0; i < 10; i++) {
      if (File(p.join(dir, 'pubspec.yaml')).existsSync() &&
          Directory(p.join(dir, 'templates')).existsSync()) {
        return dir;
      }
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }
  }
  throw StateError(
    'cannot locate Klin package root (pubspec.yaml + templates/)',
  );
}

/// Absolute path to `templates/<boardId>/`, or null if missing / unknown.
String? initTemplateDir(String boardId, {String? packageRoot}) {
  if (!knownInitBoards.contains(boardId)) return null;
  final root = packageRoot ?? klinPackageRoot();
  final dir = Directory(p.join(root, 'templates', boardId));
  if (!dir.existsSync()) return null;
  return dir.absolute.path;
}

/// Copy board template into [destDir]. Returns list of created relative paths.
///
/// Fails if [boardId] is unknown, template missing, or [destDir] exists and
/// is non-empty (refuses to overwrite).
List<String> scaffoldBoardInit({
  required String boardId,
  required String destDir,
  String? packageRoot,
}) {
  final template = initTemplateDir(boardId, packageRoot: packageRoot);
  if (template == null) {
    throw StateError(
      'unknown board `$boardId`; known: ${knownInitBoards.join(', ')}',
    );
  }

  final dest = Directory(destDir);
  if (dest.existsSync()) {
    final leftovers = dest
        .listSync(followLinks: false)
        .where((e) => p.basename(e.path) != '.' && p.basename(e.path) != '..')
        .toList();
    if (leftovers.isNotEmpty) {
      throw StateError(
        'directory `$destDir` is not empty; refuse to overwrite',
      );
    }
  } else {
    dest.createSync(recursive: true);
  }

  final created = <String>[];
  _copyTree(Directory(template), dest, dest.absolute.path, created);
  created.sort();
  return created;
}

void _copyTree(
  Directory from,
  Directory to,
  String destRoot,
  List<String> created,
) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(followLinks: false)) {
    final name = p.basename(entity.path);
    if (name == '.' || name == '..') continue;
    final outPath = p.join(to.path, name);
    if (entity is Directory) {
      _copyTree(entity, Directory(outPath), destRoot, created);
    } else if (entity is File) {
      entity.copySync(outPath);
      created.add(p.relative(outPath, from: destRoot).replaceAll('\\', '/'));
    }
  }
}
