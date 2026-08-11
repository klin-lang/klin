import 'dart:io';

import 'package:klin/ast.dart';
import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/fmt.dart';
import 'package:klin/init.dart';
import 'package:klin/klin_test.dart';
import 'package:klin/lexer.dart';
import 'package:klin/link_args.dart';
import 'package:klin/parser.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/project.dart';
import 'package:klin/lsp/server.dart';
import 'package:klin/remote.dart';
import 'package:klin/version.dart';

/// CLI: argv → preprocess → lex → parse → check → emit → optionally cc → run
///
/// Usage:
///   klin --version|-v
///   klin --help|-h
///   klin run [--cc …] [-g|--debug] [-I dir] [-l lib] [-L dir] <file.kl>
///   klin fmt [-w] <file.kl…>
///   klin lsp
///   klin test [--cc …] [-I dir] [-l lib] [-L dir] [path…]
///   klin init <board> [dir]
///   klin get [path[@ref]…]
///   klin update [path[@ref]…]
///   klin outdated [path…]
///   klin upgrade [path…]
///   klin [--cc …] [-g|--debug] [-I dir] [-l lib] [-L dir]
///        [--emit-c] [--emit-h] [--emit-pp] <file.kl>
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stdout.write(_usageText());
    exit(0);
  }
  if (args.length == 1 && (args.first == '--version' || args.first == '-v')) {
    stdout.writeln('klin $klinVersion');
    exit(0);
  }
  if (args.length == 1 && (args.first == '--help' || args.first == '-h')) {
    stdout.write(_usageText());
    exit(0);
  }

  if (args.first == 'fmt') {
    await _runFmt(args.skip(1).toList());
    return;
  }
  if (args.first == 'lsp') {
    await runKlinLsp();
    return;
  }
  if (args.first == 'test') {
    await _runTest(args.skip(1).toList());
    return;
  }
  if (args.first == 'get') {
    await _runGet(args.skip(1).toList(), force: false);
    return;
  }
  if (args.first == 'update') {
    await _runGet(args.skip(1).toList(), force: true);
    return;
  }
  if (args.first == 'outdated') {
    await _runOutdated(args.skip(1).toList());
    return;
  }
  if (args.first == 'upgrade') {
    await _runUpgrade(args.skip(1).toList());
    return;
  }
  if (args.first == 'init') {
    await _runInit(args.skip(1).toList());
    return;
  }

  final opts = _parseArgs(args);
  if (opts == null) {
    stderr.write(_usageText());
    exit(2);
  }

  final sourcePath = opts.sourcePath;
  final file = File(sourcePath);
  if (!await file.exists()) {
    stderr.writeln('klin: file not found `$sourcePath`');
    exit(1);
  }

  final base = _basenameWithoutExt(sourcePath);
  final outDir = Directory('out');
  await outDir.create(recursive: true);

  if (opts.emitPp) {
    try {
      final expanded = preprocess(await file.readAsString(), path: sourcePath);
      await File('out/$base.pp.kl').writeAsString(expanded);
    } on PreprocessError catch (e) {
      stderr.writeln('$e');
      exit(1);
    }
    return;
  }

  final Program program;
  try {
    program = loadProject(sourcePath, klinPathDirs: opts.klinPathDirs);
    Checker().check(program);
  } on PreprocessError catch (e) {
    stderr.writeln('$e');
    exit(1);
  } on LexError catch (e) {
    stderr.writeln('$sourcePath:$e');
    exit(1);
  } on ParseError catch (e) {
    stderr.writeln('$sourcePath:$e');
    exit(1);
  } on CheckError catch (e) {
    stderr.writeln('$sourcePath:$e');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('klin: ${e.message}: ${e.path}');
    exit(1);
  }

  final cPath = 'out/$base.c';
  final hPath = 'out/$base.h';
  final binPath = 'out/$base';
  final sourceDir = File(sourcePath).absolute.parent.path;

  if (opts.emitH) {
    await File(hPath).writeAsString(emitH(program, sourcePath));
  }

  if (opts.emitC || !opts.emitH) {
    final cSource = emitC(program, sourcePath);
    await File(cPath).writeAsString(cSource);
    if (opts.emitC) {
      // Resolve @[link] paths (package .c / .s) so bare-metal Makefiles work.
      final resolved = <String>[];
      for (final ref in collectLinkAttrRefs(program, sourceDir)) {
        final raw = ref.raw;
        if (raw.startsWith('-')) {
          resolved.add(raw);
        } else {
          final fromSource =
              File('${ref.sourceDir}${Platform.pathSeparator}$raw');
          resolved.add(
            fromSource.existsSync() ? fromSource.absolute.path : raw,
          );
        }
      }
      if (resolved.isNotEmpty) {
        await File('out/$base.link').writeAsString('${resolved.join('\n')}\n');
      }
    }
  }

  if (opts.emitC || opts.emitH) {
    return;
  }

  final ccArgs = buildCcArgs(
    cPath: cPath,
    binPath: binPath,
    program: program,
    sourceDir: sourceDir,
    cliLibs: opts.libs,
    cliLibDirs: opts.libDirs,
    debug: opts.debug,
  );
  final compile = await Process.run(opts.cc, ccArgs);
  if (compile.exitCode != 0) {
    // Z3: gcc should not report errors; if it does, the frontend is at fault.
    stderr.writeln('klin: C compiler error (${opts.cc}):');
    stderr.write(compile.stderr);
    stderr.write(compile.stdout);
    exit(1);
  }

  final run = await Process.run(binPath, []);
  stdout.write(run.stdout);
  stderr.write(run.stderr);
  exit(run.exitCode);
}

/// `klin outdated` — report requires behind remote latest (issue 066; uses network).
Future<void> _runOutdated(List<String> args) async {
  try {
    final modFile = findKlinModFile(Directory.current.path);
    if (modFile == null || !modFile.existsSync()) {
      stderr.writeln('klin outdated: no klin.mod found');
      exit(2);
    }
    final mod = loadKlinMod(modFile);
    if (mod.requires.isEmpty) {
      stderr.writeln('klin outdated: klin.mod has no requires');
      exit(2);
    }
    final rows = await collectOutdated(
      mod,
      onlyPaths: args.isEmpty ? null : args,
    );
    stdout.write(formatOutdatedReport(rows));
  } on FormatException catch (e) {
    stderr.writeln('klin outdated: ${e.message}');
    exit(1);
  } on ProcessException catch (e) {
    stderr.writeln('klin outdated: ${e.message}');
    exit(1);
  }
}

/// `klin upgrade` — bump outdated requires to latest + fetch (issue 066).
Future<void> _runUpgrade(List<String> args) async {
  try {
    final cwd = Directory.current.path;
    final modFile = findKlinModFile(cwd);
    if (modFile == null || !modFile.existsSync()) {
      stderr.writeln('klin upgrade: no klin.mod found');
      exit(2);
    }
    var mod = loadKlinMod(modFile);
    if (mod.requires.isEmpty) {
      stderr.writeln('klin upgrade: klin.mod has no requires');
      exit(2);
    }
    final lockFile = klinLockFileFor(modFile);
    var lock = loadKlinLockOrEmpty(lockFile);

    final rows = await collectOutdated(
      mod,
      onlyPaths: args.isEmpty ? null : args,
    );
    if (rows.isEmpty) {
      stdout.write(formatOutdatedReport(rows));
      return;
    }

    for (final row in rows) {
      final base = parseRemoteImport(row.path);
      final remote = RemoteImport(
        host: base.host,
        owner: base.owner,
        repo: base.repo,
        ref: row.latest,
      );
      final (pkgDir, ref, _) = await ensureRemotePackage(
        remote: remote,
        mod: mod,
        modFile: modFile,
        lock: lock,
        lockFile: lockFile,
        force: true,
      );
      if (modFile.existsSync()) mod = loadKlinMod(modFile);
      if (lockFile.existsSync()) lock = loadKlinLock(lockFile);
      stdout.writeln('${row.path}: ${row.current} → $ref → $pkgDir');
    }
  } on FormatException catch (e) {
    stderr.writeln('klin upgrade: ${e.message}');
    exit(1);
  } on StateError catch (e) {
    stderr.writeln('klin upgrade: $e');
    exit(1);
  } on ProcessException catch (e) {
    stderr.writeln('klin upgrade: ${e.message}');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('klin upgrade: ${e.message}: ${e.path}');
    exit(1);
  }
}

/// `klin init <board> [dir]` — copy MCU board scaffold (issue 075).
Future<void> _runInit(List<String> args) async {
  if (args.isEmpty || args.length > 2) {
    stderr.writeln(
      'usage: klin init <board> [dir]\n'
      '  known boards: ${knownInitBoards.join(', ')}',
    );
    exit(2);
  }
  final board = args[0];
  final destPath = args.length == 2 ? args[1] : board;
  try {
    final created = scaffoldBoardInit(boardId: board, destDir: destPath);
    stdout.writeln('klin init: $board → $destPath');
    for (final rel in created) {
      stdout.writeln('  $rel');
    }
    stdout.writeln('next: cd $destPath && klin get && make');
  } on StateError catch (e) {
    stderr.writeln('klin init: $e');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('klin init: ${e.message}: ${e.path}');
    exit(1);
  }
}

/// `klin get` / `klin update` — packages, devices, boards; write mod + lock.
Future<void> _runGet(List<String> args, {required bool force}) async {
  final cmd = force ? 'update' : 'get';
  try {
    final cwd = Directory.current.path;
    var modFile = findKlinModFile(cwd);
    var mod = modFile != null ? loadKlinMod(modFile) : KlinMod.empty();
    modFile ??= File('$cwd${Platform.pathSeparator}klin.mod');
    final lockFile = klinLockFileFor(modFile);
    var lock = loadKlinLockOrEmpty(lockFile);

    final specs = <String>[];
    if (args.isEmpty) {
      if (!modFile.existsSync() || mod.isEmpty) {
        stderr.writeln(
          'klin $cmd: no klin.mod requires/devices/boards; pass path[@ref] '
          '(e.g. github/klin-lang/osa@v0.1.0, '
          'github/tinygo-org/stm32-svd/svd/stm32f411.svd@main, or '
          'github/klin-lang/boards/nucleo_f411re.ioc@v0.1.0)',
        );
        exit(2);
      }
      for (final path in mod.requires.keys.toList()..sort()) {
        specs.add('$path@${mod.requires[path]}');
      }
      for (final path in mod.devices.keys.toList()..sort()) {
        specs.add('$path@${mod.devices[path]}');
      }
      for (final path in mod.boards.keys.toList()..sort()) {
        specs.add('$path@${mod.boards[path]}');
      }
    } else {
      specs.addAll(args);
    }

    for (final spec in specs) {
      if (isRemoteDevicePath(spec)) {
        final asset = parseRemoteAsset(spec);
        final effective = force &&
                asset.ref == null &&
                mod.devices[asset.path] != null
            ? RemoteAsset(
                host: asset.host,
                owner: asset.owner,
                repo: asset.repo,
                filePath: asset.filePath,
                ref: mod.devices[asset.path],
              )
            : asset;
        final (filePath, ref, _) = await ensureRemoteDevice(
          asset: effective,
          mod: mod,
          modFile: modFile,
          lock: lock,
          lockFile: lockFile,
          force: force,
        );
        if (modFile.existsSync()) mod = loadKlinMod(modFile);
        if (lockFile.existsSync()) lock = loadKlinLock(lockFile);
        stdout.writeln('${asset.path}@$ref → $filePath');
        continue;
      }

      if (isRemoteBoardPath(spec)) {
        final asset = parseRemoteAsset(spec);
        final effective = force &&
                asset.ref == null &&
                mod.boards[asset.path] != null
            ? RemoteAsset(
                host: asset.host,
                owner: asset.owner,
                repo: asset.repo,
                filePath: asset.filePath,
                ref: mod.boards[asset.path],
              )
            : asset;
        final (filePath, ref, _) = await ensureRemoteBoard(
          asset: effective,
          mod: mod,
          modFile: modFile,
          lock: lock,
          lockFile: lockFile,
          force: force,
        );
        if (modFile.existsSync()) mod = loadKlinMod(modFile);
        if (lockFile.existsSync()) lock = loadKlinLock(lockFile);
        // Cache only — never writes into a project-local board/*.ioc (074).
        stdout.writeln('${asset.path}@$ref → $filePath');
        continue;
      }

      final remote = parseRemoteImport(spec);
      // update without @ref keeps klin.mod pin; get without @ref may resolve latest
      final effective = force && remote.ref == null && mod.requires[remote.path] != null
          ? RemoteImport(
              host: remote.host,
              owner: remote.owner,
              repo: remote.repo,
              ref: mod.requires[remote.path],
            )
          : remote;
      final (pkgDir, ref, _) = await ensureRemotePackage(
        remote: effective,
        mod: mod,
        modFile: modFile,
        lock: lock,
        lockFile: lockFile,
        force: force,
      );
      if (modFile.existsSync()) mod = loadKlinMod(modFile);
      if (lockFile.existsSync()) lock = loadKlinLock(lockFile);
      stdout.writeln('${remote.path}@$ref → $pkgDir');
    }
  } on FormatException catch (e) {
    stderr.writeln('klin $cmd: ${e.message}');
    exit(1);
  } on StateError catch (e) {
    stderr.writeln('klin $cmd: $e');
    exit(1);
  } on ProcessException catch (e) {
    stderr.writeln('klin $cmd: ${e.message}');
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('klin $cmd: ${e.message}: ${e.path}');
    exit(1);
  }
}

Future<void> _runFmt(List<String> args) async {
  var write = false;
  final paths = <String>[];
  for (final a in args) {
    if (a == '-w') {
      write = true;
    } else if (a.startsWith('-')) {
      stderr.writeln('usage: klin fmt [-w] <file.kl…>');
      exit(2);
    } else {
      paths.add(a);
    }
  }
  if (paths.isEmpty) {
    stderr.writeln('usage: klin fmt [-w] <file.kl…>');
    exit(2);
  }

  var failed = false;
  for (final path in paths) {
    final file = File(path);
    if (!await file.exists()) {
      stderr.writeln('klin: file not found `$path`');
      failed = true;
      continue;
    }
    final raw = await file.readAsString();
    try {
      final formatted = formatSource(raw);
      if (write) {
        if (formatted != raw) {
          await file.writeAsString(formatted);
        }
      } else {
        stdout.write(formatted);
        if (paths.length > 1 && !formatted.endsWith('\n')) {
          stdout.writeln();
        }
      }
    } on LexError catch (e) {
      stderr.writeln('$path:$e');
      failed = true;
    } on ParseError catch (e) {
      stderr.writeln('$path:$e');
      failed = true;
    }
  }
  if (failed) exit(1);
}

Future<void> _runTest(List<String> args) async {
  var cc = 'gcc';
  final klinPathDirs = <String>[];
  final libs = <String>[];
  final libDirs = <String>[];
  final paths = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--cc') {
      if (i + 1 >= args.length) {
        stderr.writeln(_testUsage());
        exit(2);
      }
      cc = args[++i];
    } else if (a == '-I') {
      if (i + 1 >= args.length) {
        stderr.writeln(_testUsage());
        exit(2);
      }
      klinPathDirs.add(args[++i]);
    } else if (a.startsWith('-I') && a.length > 2) {
      klinPathDirs.add(a.substring(2));
    } else if (a == '-l') {
      if (i + 1 >= args.length) {
        stderr.writeln(_testUsage());
        exit(2);
      }
      libs.add(args[++i]);
    } else if (a == '-L') {
      if (i + 1 >= args.length) {
        stderr.writeln(_testUsage());
        exit(2);
      }
      libDirs.add(args[++i]);
    } else if (a.startsWith('-l') && a.length > 2) {
      libs.add(a.substring(2));
    } else if (a.startsWith('-L') && a.length > 2) {
      libDirs.add(a.substring(2));
    } else if (a.startsWith('-')) {
      stderr.writeln(_testUsage());
      exit(2);
    } else {
      paths.add(a);
    }
  }

  final List<String> files;
  try {
    files = discoverTestFiles(paths);
  } on FileSystemException catch (e) {
    stderr.writeln('klin: ${e.message}: ${e.path}');
    exit(1);
  }
  if (files.isEmpty) {
    stderr.writeln('klin test: no *_test.kl files found');
    exit(1);
  }

  var failed = 0;
  final cwd = Directory.current.absolute.path;
  String displayPath(String path) {
    final abs = File(path).absolute.path;
    final prefix = cwd.endsWith(Platform.pathSeparator)
        ? cwd
        : '$cwd${Platform.pathSeparator}';
    return abs.startsWith(prefix) ? abs.substring(prefix.length) : abs;
  }

  for (final path in files) {
    final shown = displayPath(path);
    try {
      final result = await runKlinTestFile(
        path,
        cc: cc,
        klinPathDirs: klinPathDirs,
        cliLibs: libs,
        cliLibDirs: libDirs,
      );
      if (result.ok) {
        stdout.writeln('ok\t$shown');
      } else {
        failed++;
        stdout.writeln('FAIL\t$shown');
        if (result.stderr.isNotEmpty) stderr.write(result.stderr);
        if (result.stdout.isNotEmpty) stdout.write(result.stdout);
      }
    } on PreprocessError catch (e) {
      failed++;
      stdout.writeln('FAIL\t$shown');
      stderr.writeln('$e');
    } on LexError catch (e) {
      failed++;
      stdout.writeln('FAIL\t$shown');
      stderr.writeln('$path:$e');
    } on ParseError catch (e) {
      failed++;
      stdout.writeln('FAIL\t$shown');
      stderr.writeln('$path:$e');
    } on CheckError catch (e) {
      failed++;
      stdout.writeln('FAIL\t$shown');
      stderr.writeln('$path:$e');
    } on FileSystemException catch (e) {
      failed++;
      stdout.writeln('FAIL\t$shown');
      stderr.writeln('klin: ${e.message}: ${e.path}');
    }
  }

  if (failed == 0) {
    stdout.writeln('PASS');
    exit(0);
  }
  stdout.writeln('FAIL\t$failed/${files.length}');
  exit(1);
}

final class _Opts {
  final String sourcePath;
  final String cc;
  final bool emitC;
  final bool emitH;
  final bool emitPp;
  final bool debug;
  final List<String> klinPathDirs;
  final List<String> libs;
  final List<String> libDirs;

  const _Opts(
    this.sourcePath,
    this.cc,
    this.emitC,
    this.emitH,
    this.emitPp,
    this.debug,
    this.klinPathDirs,
    this.libs,
    this.libDirs,
  );
}

/// Recognized subcommands. Bare `<file.kl>` is an alias for `run`.
const _commands = {'run'};

_Opts? _parseArgs(List<String> args) {
  String cc = 'gcc';
  var emitC = false;
  var emitH = false;
  var emitPp = false;
  var debug = false;
  final klinPathDirs = <String>[];
  final libs = <String>[];
  final libDirs = <String>[];
  String? command;
  String? source;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--cc') {
      if (i + 1 >= args.length) return null;
      cc = args[++i];
    } else if (a == '--emit-c') {
      emitC = true;
    } else if (a == '--emit-h') {
      emitH = true;
    } else if (a == '--emit-pp') {
      emitPp = true;
    } else if (a == '-g' || a == '--debug') {
      debug = true;
    } else if (a == '-I') {
      if (i + 1 >= args.length) return null;
      klinPathDirs.add(args[++i]);
    } else if (a.startsWith('-I') && a.length > 2) {
      klinPathDirs.add(a.substring(2));
    } else if (a == '-l') {
      if (i + 1 >= args.length) return null;
      libs.add(args[++i]);
    } else if (a == '-L') {
      if (i + 1 >= args.length) return null;
      libDirs.add(args[++i]);
    } else if (a.startsWith('-l') && a.length > 2) {
      libs.add(a.substring(2));
    } else if (a.startsWith('-L') && a.length > 2) {
      libDirs.add(a.substring(2));
    } else if (a.startsWith('-')) {
      return null;
    } else if (command == null && source == null && _commands.contains(a)) {
      command = a;
    } else if (source == null) {
      source = a;
    } else {
      return null;
    }
  }
  if (source == null) return null;
  if (emitPp && (emitC || emitH)) return null;
  // `run` means compile+execute; `--emit-*` skip execution.
  if (command != null && command != 'run') return null;
  return _Opts(
    source,
    cc,
    emitC,
    emitH,
    emitPp,
    debug,
    klinPathDirs,
    libs,
    libDirs,
  );
}

String _testUsage() =>
    'usage: klin test [--cc gcc|clang|tcc] [-I dir] [-l lib] [-L dir] [path…]';

String _usageText() =>
    'usage: klin --version|-v\n'
    '       klin --help|-h\n'
    '       klin run [--cc gcc|clang|tcc] [-g|--debug] '
    '[-I dir] [-l lib] [-L dir] <file.kl>\n'
    '       klin fmt [-w] <file.kl…>\n'
    '       klin lsp\n'
    '       klin test [--cc gcc|clang|tcc] [-I dir] [-l lib] [-L dir] [path…]\n'
    '       klin init <board> [dir]\n'
    '       klin get [path[@ref]…]\n'
    '       klin update [path[@ref]…]\n'
    '       klin outdated [path…]\n'
    '       klin upgrade [path…]\n'
    '       klin [--cc gcc|clang|tcc] [-g|--debug] [-I dir] [-l lib] [-L dir] '
    '[--emit-c] [--emit-h] [--emit-pp] <file.kl>\n';

String _basenameWithoutExt(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}
