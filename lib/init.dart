import 'dart:io';

import 'package:path/path.dart' as p;

/// Known MCU board scaffolds under `templates/<id>/` (issue 075 / 054).
const knownInitBoards = <String>[
  'nucleo-f411',
  'pico',
  'pico2',
  'waveshare-rp2350-lcd-096',
  'waveshare-esp32-s3-pico',
  'gd32vw553h-eval',
  'gd32vw553h-start',
  'weact-f411',
];

/// Possible `templates/` locations under [roots] (repo layout + Homebrew
/// `pkgshare` / release tarball next to the binary).
///
/// Visible for tests (mirrors [stdlibCandidatesForInstallRoot]).
Iterable<String> templatesCandidatesForInstallRoot(
  Iterable<String> roots,
) sync* {
  final sep = Platform.pathSeparator;
  final seen = <String>{};
  for (final root in roots) {
    if (root.isEmpty) continue;
    for (final rel in ['templates', 'share${sep}klin${sep}templates']) {
      final path = '$root$sep$rel';
      if (seen.add(path)) yield path;
    }
  }
}

Iterable<String> _installRootHints() sync* {
  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    yield exeDir;
    yield Directory(exeDir).parent.path; // Cellar/.../bin → formula prefix
  } catch (_) {}
  if (Platform.script.scheme == 'file') {
    final scriptFile = File.fromUri(Platform.script);
    yield scriptFile.parent.parent.path; // bin/klin.dart → repo root
  }
}

/// Resolve the directory that contains per-board scaffolds (`templates/`).
///
/// Order: [packageRoot] override → `$KLIN_TEMPLATES` → repo walk (pubspec +
/// `templates/`) → install layout next to binary / `share/klin/templates`.
String findTemplatesRoot({String? packageRoot}) {
  if (packageRoot != null) {
    final dir = Directory(p.join(packageRoot, 'templates'));
    if (dir.existsSync()) return dir.absolute.path;
    throw StateError('templates/ missing under package root `$packageRoot`');
  }

  final env = Platform.environment['KLIN_TEMPLATES'];
  if (env != null && env.isNotEmpty) {
    final dir = Directory(env);
    if (dir.existsSync()) return dir.absolute.path;
    throw StateError('\$KLIN_TEMPLATES is set but missing: $env');
  }

  var dir = Directory.current.absolute;
  for (var i = 0; i < 10; i++) {
    final templates = Directory(p.join(dir.path, 'templates'));
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (templates.existsSync() && pubspec.existsSync()) {
      return templates.absolute.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  for (final candidate in templatesCandidatesForInstallRoot(
    _installRootHints(),
  )) {
    if (Directory(candidate).existsSync()) {
      return Directory(candidate).absolute.path;
    }
  }

  throw StateError(
    'cannot locate Klin templates/ '
    '(repo root, \$KLIN_TEMPLATES, or share/klin/templates next to install)',
  );
}

/// Absolute path to `templates/<boardId>/`, or null if [boardId] is unknown.
///
/// Throws [StateError] when the board is known but its template directory is
/// missing under the resolved templates root.
String? initTemplateDir(String boardId, {String? packageRoot}) {
  if (!knownInitBoards.contains(boardId)) return null;
  final templatesRoot = findTemplatesRoot(packageRoot: packageRoot);
  final dir = Directory(p.join(templatesRoot, boardId));
  if (!dir.existsSync()) {
    throw StateError(
      'init template missing for `$boardId` under $templatesRoot',
    );
  }
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
