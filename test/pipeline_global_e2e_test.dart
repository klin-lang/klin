@Tags(['e2e'])
library;

import 'dart:io';

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/project.dart';
import 'package:test/test.dart';

import 'support/compile_and_run.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_global_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('scalar module globals run', () async {
    final result =
        await compileAndRun('test/global_scalar/app.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/global_scalar/app.out').readAsString());
    await _expectPedantic('test/global_scalar/app.kl', tmp);
  });

  test('array, struct, slice, and pointer globals run', () async {
    final result =
        await compileAndRun('test/global_agg/app.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/global_agg/app.out').readAsString());
    await _expectPedantic('test/global_agg/app.kl', tmp);
  });

  test('for-loop on a global and an imported function pointer run', () async {
    final result = await compileAndRun('test/global_mod/fn.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/global_mod/fn.out').readAsString());
    await _expectPedantic('test/global_mod/fn.kl', tmp);
  });

  test('immutable byte-string global and a typed match run together', () async {
    final result = await compileAndRun('test/global_match.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/global_match.out').readAsString());
    await _expectPedantic('test/global_match.kl', tmp);
  });

  test('imported pub let mut can be written', () async {
    final result =
        await compileAndRun('test/global_mod/app.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/global_mod/app.out').readAsString());
    await _expectPedantic('test/global_mod/app.kl', tmp);
  });
}

/// `gcc -std=c11 -pedantic-errors` on the C this program emits.
Future<void> _expectPedantic(String klPath, Directory tmp) async {
  final program = loadProject(klPath);
  Checker().check(program);
  final cPath = '${tmp.path}/pedantic.c';
  await File(cPath).writeAsString(emitC(program, klPath));
  final pedantic = await Process.run('gcc', [
    '-std=c11',
    '-pedantic-errors',
    cPath,
    '-o',
    '${tmp.path}/pedantic_bin',
  ]);
  expect(pedantic.exitCode, 0, reason: pedantic.stderr.toString());
}
