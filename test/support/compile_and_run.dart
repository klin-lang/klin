import 'dart:io';

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/link_args.dart';
import 'package:klin/project.dart';

/// Host C compiler for goldens: `KLIN_CC`, else `tcc` on PATH, else `gcc`.
String resolveHostCc() {
  final fromEnv = Platform.environment['KLIN_CC'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  if (_hasOnPath('tcc')) return 'tcc';
  return 'gcc';
}

bool _hasOnPath(String name) {
  if (Platform.isWindows) {
    return Process.runSync('where', [name], runInShell: true).exitCode == 0;
  }
  return Process.runSync('which', [name]).exitCode == 0;
}

/// Emit C for [klPath], compile with [resolveHostCc], run the binary.
Future<({int exitCode, String stdout, String stderr})> compileAndRun(
  String klPath,
  Directory tmp, {
  String? klinCacheDir,
  String? cc,
}) async {
  final program = loadProject(klPath, klinCacheDir: klinCacheDir);
  Checker().check(program);
  final base = klPath.split('/').last.replaceAll('.kl', '');
  final cPath = '${tmp.path}/$base.c';
  final binPath = '${tmp.path}/$base';
  await File(cPath).writeAsString(emitC(program, klPath));

  final sourceDir = File(klPath).absolute.parent.path;
  final ccArgs = buildCcArgs(
    cPath: cPath,
    binPath: binPath,
    program: program,
    sourceDir: sourceDir,
  );
  final compiler = cc ?? resolveHostCc();
  final compile = await Process.run(compiler, ccArgs);
  if (compile.exitCode != 0) {
    return (
      exitCode: compile.exitCode,
      stdout: compile.stdout.toString(),
      stderr: '$compiler: ${compile.stderr}',
    );
  }

  final run = await Process.run(binPath, []);
  return (
    exitCode: run.exitCode,
    stdout: run.stdout.toString(),
    stderr: run.stderr.toString(),
  );
}
