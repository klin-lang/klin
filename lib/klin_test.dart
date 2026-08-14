import 'dart:io';

import 'ast.dart';
import 'checker.dart';
import 'emit_c.dart';
import 'link_args.dart';
import 'project.dart';
import 'token.dart';

/// Result of running one `*_test.kl` file.
final class KlinTestFileResult {
  final String path;
  final bool ok;
  final String stdout;
  final String stderr;
  final int exitCode;
  final List<String> testNames;

  const KlinTestFileResult({
    required this.path,
    required this.ok,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.testNames,
  });
}

/// Discovers `*_test.kl` under [paths] (files or directories). Empty → cwd.
List<String> discoverTestFiles(List<String> paths) {
  final roots = paths.isEmpty ? [Directory.current.path] : paths;
  final found = <String>{};
  for (final root in roots) {
    final entity = FileSystemEntity.typeSync(root);
    if (entity == FileSystemEntityType.file) {
      if (!_isTestFile(root)) {
        throw FileSystemException(
          'not a *_test.kl file',
          root,
        );
      }
      found.add(File(root).absolute.path);
      continue;
    }
    if (entity == FileSystemEntityType.directory) {
      final dir = Directory(root);
      for (final file in dir.listSync(recursive: false)) {
        if (file is File && _isTestFile(file.path)) {
          found.add(file.absolute.path);
        }
      }
      continue;
    }
    throw FileSystemException('path not found', root);
  }
  final list = found.toList()..sort();
  return list;
}

bool _isTestFile(String path) {
  final name = path.split(Platform.pathSeparator).last;
  return name.endsWith('_test.kl');
}

/// Loads [entryPath], injects `main` that calls `test_*` when needed, runs it.
Future<KlinTestFileResult> runKlinTestFile(
  String entryPath, {
  String cc = 'gcc',
  Directory? outDir,
  List<String> klinPathDirs = const [],
  List<String> cliLibs = const [],
  List<String> cliLibDirs = const [],
  String? opt,
}) async {
  final absEntry = File(entryPath).absolute.path;
  final stem = _basenameWithoutExt(absEntry);
  final dir = outDir ?? Directory('out');
  await dir.create(recursive: true);

  var program = loadProject(absEntry, klinPathDirs: klinPathDirs);

  final entryTests = _entryTestFns(program, absEntry);
  // Only the entry file's `main` counts. Imported mains are dropped so they
  // neither skip the harness nor collide with an injected test `main`.
  program = _withoutImportedMains(program, absEntry);
  final hasEntryMain = program.funcs.any(
    (f) =>
        _isFromEntry(f, absEntry) &&
        f.receiver == null &&
        f.name == 'main' &&
        f.body != null,
  );
  if (!hasEntryMain) {
    if (entryTests.isEmpty) {
      throw CheckError(
        'no `test_*` functions and no `main` in test file',
        const SourcePos(1, 1),
      );
    }
    program = _withInjectedMain(program, absEntry, entryTests);
  }

  Checker().check(program);

  final cPath = '${dir.path}${Platform.pathSeparator}klin_test_$stem.c';
  final binPath = '${dir.path}${Platform.pathSeparator}klin_test_$stem';
  await File(cPath).writeAsString(emitC(program, absEntry));

  final sourceDir = File(absEntry).parent.path;
  final ccArgs = buildCcArgs(
    cPath: cPath,
    binPath: binPath,
    program: program,
    sourceDir: sourceDir,
    cliLibs: cliLibs,
    cliLibDirs: cliLibDirs,
    opt: opt,
  );
  final compile = await Process.run(cc, ccArgs);
  if (compile.exitCode != 0) {
    return KlinTestFileResult(
      path: absEntry,
      ok: false,
      stdout: compile.stdout.toString(),
      stderr: 'klin: C compiler error ($cc):\n'
          '${compile.stderr}${compile.stdout}',
      exitCode: compile.exitCode,
      testNames: entryTests.map((t) => t.name).toList(),
    );
  }

  final run = await Process.run(binPath, []);
  return KlinTestFileResult(
    path: absEntry,
    ok: run.exitCode == 0,
    stdout: run.stdout.toString(),
    stderr: run.stderr.toString(),
    exitCode: run.exitCode,
    testNames: entryTests.map((t) => t.name).toList(),
  );
}

List<FuncDecl> _entryTestFns(Program program, String absEntry) {
  return program.funcs.where((f) {
    if (f.receiver != null || f.body == null || f.params.isNotEmpty) {
      return false;
    }
    if (!f.name.startsWith('test_')) return false;
    return _isFromEntry(f, absEntry);
  }).toList();
}

bool _isFromEntry(FuncDecl f, String absEntry) {
  if (f.sourcePath == null) return false;
  return File(f.sourcePath!).absolute.path == File(absEntry).absolute.path;
}

Program _withoutImportedMains(Program program, String absEntry) {
  final funcs = program.funcs.where((f) {
    if (f.receiver != null || f.name != 'main') return true;
    return _isFromEntry(f, absEntry);
  }).toList();
  if (funcs.length == program.funcs.length) return program;
  return Program(
    program.structs,
    funcs,
    program.pos,
    enums: program.enums,
    importAliases: program.importAliases,
  );
}

Program _withInjectedMain(
  Program program,
  String absEntry,
  List<FuncDecl> tests,
) {
  final module = tests.first.moduleName;
  final pos = tests.first.pos;
  final calls = <Stmt>[
    for (final t in tests)
      CallStmt(
        callee: t.name,
        args: const [],
        pos: t.pos,
      ),
  ];
  final main = FuncDecl(
    name: 'main',
    receiver: null,
    params: const [],
    returnTypeName: null,
    body: Block(calls, pos),
    pos: pos,
    moduleName: module,
    sourcePath: absEntry,
  );
  return Program(
    program.structs,
    [...program.funcs, main],
    program.pos,
    enums: program.enums,
    importAliases: program.importAliases,
  );
}

String _basenameWithoutExt(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return name;
  return name.substring(0, dot);
}
