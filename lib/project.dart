import 'dart:io';

import 'ast.dart';
import 'lexer.dart';
import 'parser.dart';
import 'preprocess.dart';
import 'remote.dart';
import 'token.dart';

/// Loads an entry file (and same-module siblings) plus transitive imports.
///
/// [klinPathDirs] are CLI `-I` directories (searched in order, after `lib/`).
/// Environment `$KLIN_PATH` is also consulted (PATH-style separator).
/// [klinCacheDir] overrides `$KLIN_CACHE` for remote imports (049) and
/// `$device` SVD assets (053).
///
/// `import name` resolves to `name.kl` **or** a directory `name/` of `.kl`
/// files (issue 047). Both in the same search slot → error.
/// Remote `import "github|gitlab/…"` resolves only from the package cache.
Program loadProject(
  String entryPath, {
  List<String> klinPathDirs = const [],
  String? klinCacheDir,
  /// Absolute path → source text; wins over disk (LSP open buffers).
  Map<String, String>? sourceOverlay,
}) {
  final structs = <StructDecl>[];
  final enums = <EnumDecl>[];
  final funcs = <FuncDecl>[];
  final importAliases = <String, Map<String, String>>{};
  final loading = <String>{};
  final loaded = <String, String>{}; // packageKey → moduleName
  final fileModule = <String, String>{}; // abs file path → moduleName
  SourcePos? firstPos;

  String readSource(String absPath) {
    final abs = File(absPath).absolute.path;
    final fromOverlay = sourceOverlay?[abs] ?? sourceOverlay?[absPath];
    if (fromOverlay != null) return fromOverlay;
    return File(abs).readAsStringSync();
  }

  bool sourceExists(String absPath) {
    final abs = File(absPath).absolute.path;
    if (sourceOverlay != null &&
        (sourceOverlay.containsKey(abs) ||
            sourceOverlay.containsKey(absPath))) {
      return true;
    }
    return File(abs).existsSync();
  }

  String loadPackageFiles(
    List<String> filePaths, {
    String? requiredModule,
  }) {
    final absFiles = [
      for (final p in filePaths) File(p).absolute.path,
    ]..sort();
    if (absFiles.isEmpty) {
      throw FileSystemException('imported package has no .kl files', '');
    }

    // Already loaded as part of a larger (or identical) package — do not
    // re-parse / re-register declarations (issue 047 / Bugbot).
    if (absFiles.every(fileModule.containsKey)) {
      final module = fileModule[absFiles.first]!;
      for (final path in absFiles) {
        if (fileModule[path] != module) {
          throw ParseError(
            'file `$path` already loaded as module `${fileModule[path]}`',
            const SourcePos(1, 1),
          );
        }
      }
      return module;
    }
    if (absFiles.any(fileModule.containsKey)) {
      final conflict = absFiles.firstWhere(fileModule.containsKey);
      throw ParseError(
        'file `$conflict` already loaded as part of another package',
        const SourcePos(1, 1),
      );
    }

    final packageKey = absFiles.join('\x1e');
    final existing = loaded[packageKey];
    if (existing != null) return existing;
    if (!loading.add(packageKey)) {
      throw ParseError('cyclic import `$packageKey`', const SourcePos(1, 1));
    }

    final units = <({String path, ModuleUnit unit, String moduleName})>[];
    for (final path in absFiles) {
      if (!sourceExists(path)) {
        throw FileSystemException('imported file not found', path);
      }
      final unit = _parseUnitFile(
        path,
        readSource(path),
        klinCacheDir: klinCacheDir,
        klinPathDirs: klinPathDirs,
      );
      final moduleName = unit.declaredName ?? _fileStem(path);
      if (requiredModule != null && moduleName != requiredModule) {
        throw ParseError(
          'module `$moduleName` in `$path` does not match package '
          '`$requiredModule`',
          unit.pos,
        );
      }
      units.add((path: path, unit: unit, moduleName: moduleName));
    }

    final moduleName = units.first.moduleName;
    for (final u in units) {
      if (u.moduleName != moduleName) {
        throw ParseError(
          'mixed module names in package (`$moduleName` vs `${u.moduleName}`)',
          u.unit.pos,
        );
      }
    }

    firstPos ??= units.first.unit.pos;
    for (final u in units) {
      for (final struct in u.unit.structs) {
        struct.moduleName = moduleName;
        struct.sourcePath = u.path;
        structs.add(struct);
      }
      for (final enumDecl in u.unit.enums) {
        enumDecl.moduleName = moduleName;
        enumDecl.sourcePath = u.path;
        enums.add(enumDecl);
      }
      for (final func in u.unit.funcs) {
        func.moduleName = moduleName;
        func.sourcePath = u.path;
        funcs.add(func);
      }
    }

    // Mark files loaded before resolving imports so same-package
    // `import otherfile` does not re-register declarations.
    for (final path in absFiles) {
      fileModule[path] = moduleName;
    }
    loaded[packageKey] = moduleName;

    final aliases = importAliases.putIfAbsent(moduleName, () => {});
    // Group imports by their source qualifier (alias or default). The same
    // qualifier bound to two different specs is a conflict.
    final byQualifier = <String, ImportSpec>{};
    for (final u in units) {
      for (final imp in u.unit.imports) {
        final existing = byQualifier[imp.qualifier];
        if (existing != null &&
            existing.resolutionKey != imp.resolutionKey) {
          throw ParseError(
            'import alias `${imp.qualifier}` is already bound to '
            '`${existing.spec}`',
            imp.pos,
          );
        }
        byQualifier[imp.qualifier] = imp;
      }
    }
    // Resolve imports relative to the package directory (parent of files).
    final fromDir = File(absFiles.first).parent.path;
    for (final qualifier in byQualifier.keys.toList()..sort()) {
      final imp = byQualifier[qualifier]!;
      final target = _resolveImportTarget(
        fromDir,
        imp.resolutionKey,
        klinPathDirs: klinPathDirs,
        klinCacheDir: klinCacheDir,
      );
      final childModule = switch (target) {
        _FileImport(:final path) => loadPackageFiles([path]),
        _DirImport(:final path) => loadPackageFiles(
            _packageKlFiles(path),
            requiredModule: imp.defaultQualifier,
          ),
      };
      aliases[qualifier] = childModule;
    }

    loading.remove(packageKey);
    return moduleName;
  }

  // Entry: load the entry file plus same-module siblings in its directory.
  final entryAbs = File(entryPath).absolute.path;
  final entryUnit = _parseUnitFile(
    entryAbs,
    readSource(entryAbs),
    klinCacheDir: klinCacheDir,
    klinPathDirs: klinPathDirs,
  );
  final entryModule = entryUnit.declaredName ?? _fileStem(entryAbs);
  final entryDir = File(entryAbs).parent.path;
  final siblingFiles = <String>[entryAbs];
  final moduleDecl = RegExp('(?:^|\\n)\\s*module\\s+$entryModule\\b');
  for (final path in _packageKlFiles(entryDir)) {
    if (path == entryAbs) continue;
    final raw = readSource(path);
    final looksLikeSibling = _fileStem(path) == entryModule ||
        moduleDecl.hasMatch(raw);
    try {
      final unit = _parseUnitFile(
        path,
        raw,
        klinCacheDir: klinCacheDir,
        klinPathDirs: klinPathDirs,
      );
      final name = unit.declaredName ?? _fileStem(path);
      if (name == entryModule) siblingFiles.add(path);
    } on PreprocessError {
      if (looksLikeSibling) rethrow;
    } on LexError {
      if (looksLikeSibling) rethrow;
    } on ParseError {
      if (looksLikeSibling) rethrow;
    }
  }
  loadPackageFiles(siblingFiles);

  return Program(
    structs,
    funcs,
    firstPos ?? const SourcePos(1, 1),
    enums: enums,
    importAliases: importAliases,
  );
}

sealed class _ImportTarget {
  const _ImportTarget();
}

final class _FileImport extends _ImportTarget {
  final String path;
  const _FileImport(this.path);
}

final class _DirImport extends _ImportTarget {
  final String path;
  const _DirImport(this.path);
}

/// Resolves `import name` → single file or package directory.
///
/// Per search root (sibling, `lib/`, `-I`, `$KLIN_PATH`, stdlib): try
/// `name.kl` and `name/` in that slot; both present → ambiguous.
///
/// Remote paths (`github/…`, `gitlab/…`) resolve **only** from the Klin
/// package cache — never from a local `github/` folder (issue 049).
_ImportTarget _resolveImportTarget(
  String fromDir,
  String importName, {
  List<String> klinPathDirs = const [],
  String? klinCacheDir,
}) {
  if (isRemoteImportPath(importName)) {
    return _resolveRemoteImportTarget(importName, klinCacheDir: klinCacheDir);
  }

  final sep = Platform.pathSeparator;
  final roots = <String>[
    fromDir,
    '$fromDir${sep}lib',
    ...klinPathDirs,
    ..._klinPathEnvDirs(),
    ..._stdlibSearchDirs(),
  ];

  for (final root in roots) {
    final filePath = '$root$sep$importName.kl';
    final dirPath = '$root$sep$importName';
    final hasFile = File(filePath).existsSync();
    final dirFiles = _packageKlFilesIfDir(dirPath);
    final hasDir = dirFiles.isNotEmpty;
    if (hasFile && hasDir) {
      throw FileSystemException(
        'ambiguous import `$importName`: both `$filePath` and package '
        'directory `$dirPath` exist',
        filePath,
      );
    }
    if (hasFile) return _FileImport(File(filePath).absolute.path);
    if (hasDir) return _DirImport(Directory(dirPath).absolute.path);
  }

  throw FileSystemException(
    'imported file not found',
    '$fromDir$sep$importName.kl',
  );
}

_ImportTarget _resolveRemoteImportTarget(
  String importName, {
  String? klinCacheDir,
}) {
  final RemoteImport remote;
  try {
    remote = parseRemoteImport(importName);
  } on FormatException catch (e) {
    throw FileSystemException(e.message, importName);
  }
  final pkgDir = packageCacheDir(remote, cacheRoot: klinCacheDir);
  if (isPackageInstalled(pkgDir)) {
    if (!packageCacheHasRequiredLinkUnits(pkgDir)) {
      throw FileSystemException(
        'remote package `${remote.path}` is incomplete '
        '(missing @[link] C/ASM units); '
        'run `klin get ${remote.path}` to repair the cache',
        pkgDir,
      );
    }
    return _DirImport(Directory(pkgDir).absolute.path);
  }
  throw FileSystemException(
    'remote package `${remote.path}` is not in the cache; '
    'run `klin get ${remote.path}` (or `klin get ${remote.path}@<ref>`)',
    pkgDir,
  );
}

/// `.kl` files in [dir], excluding `*_test.kl`. Empty if not a directory.
List<String> _packageKlFiles(String dir) {
  final directory = Directory(dir);
  if (!directory.existsSync()) return const [];
  final out = <String>[];
  for (final entity in directory.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (!name.endsWith('.kl')) continue;
    if (name.endsWith('_test.kl')) continue;
    out.add(entity.absolute.path);
  }
  out.sort();
  return out;
}

List<String> _packageKlFilesIfDir(String dir) => _packageKlFiles(dir);

/// Directories from `$KLIN_PATH` (`:` on Unix, `;` on Windows).
Iterable<String> _klinPathEnvDirs() sync* {
  final env = Platform.environment['KLIN_PATH'];
  if (env == null || env.isEmpty) return;
  final sep = Platform.isWindows ? ';' : ':';
  for (final part in env.split(sep)) {
    final trimmed = part.trim();
    if (trimmed.isNotEmpty) yield trimmed;
  }
}

Iterable<String> _stdlibSearchDirs() sync* {
  final env = Platform.environment['KLIN_STDLIB'];
  if (env != null && env.isNotEmpty) yield env;

  var dir = Directory.current.absolute;
  for (var i = 0; i < 8; i++) {
    final std = Directory('${dir.path}${Platform.pathSeparator}stdlib');
    final pubspec = File('${dir.path}${Platform.pathSeparator}pubspec.yaml');
    if (std.existsSync() && pubspec.existsSync()) {
      yield std.path;
      break;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }

  for (final candidate in stdlibCandidatesForInstallRoot(_installRootHints())) {
    if (Directory(candidate).existsSync()) yield candidate;
  }
}

/// Prefix / repo-root hints for a packaged or source install (Homebrew, `task release`).
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

/// Possible `stdlib/` locations under [roots] (repo layout + Homebrew `pkgshare`).
///
/// Visible for tests.
Iterable<String> stdlibCandidatesForInstallRoot(Iterable<String> roots) sync* {
  final sep = Platform.pathSeparator;
  final seen = <String>{};
  for (final root in roots) {
    if (root.isEmpty) continue;
    for (final rel in ['stdlib', 'share${sep}klin${sep}stdlib']) {
      final path = '$root$sep$rel';
      if (seen.add(path)) yield path;
    }
  }
}

ModuleUnit _parseUnitFile(
  String path,
  String source, {
  String? klinCacheDir,
  List<String> klinPathDirs = const [],
}) {
  try {
    final expanded = preprocess(
      source,
      path: path,
      klinCacheDir: klinCacheDir,
      klinPathDirs: klinPathDirs,
    );
    return Parser(Lexer(expanded).tokenize()).parseUnit();
  } on LexError catch (e) {
    throw LexError(e.message, e.pos, path: e.path ?? path);
  } on ParseError catch (e) {
    throw ParseError(e.message, e.pos, path: e.path ?? path);
  }
}

String _fileStem(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  return dot == -1 ? name : name.substring(0, dot);
}
