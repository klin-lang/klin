import 'dart:io';

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/link_args.dart';
import 'package:klin/project.dart';

/// Emit C for [klPath], compile with host `gcc`, run the binary.
Future<({int exitCode, String stdout, String stderr})> compileAndRun(
  String klPath,
  Directory tmp, {
  String? klinCacheDir,
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
  final compile = await Process.run('gcc', ccArgs);
  if (compile.exitCode != 0) {
    return (
      exitCode: compile.exitCode,
      stdout: compile.stdout.toString(),
      stderr: 'gcc: ${compile.stderr}',
    );
  }

  final run = await Process.run(binPath, []);
  return (
    exitCode: run.exitCode,
    stdout: run.stdout.toString(),
    stderr: run.stderr.toString(),
  );
}
