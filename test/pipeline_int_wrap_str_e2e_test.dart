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
    tmp = await Directory.systemTemp.createTemp('klin_wrap_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('narrow arithmetic wraps and wide shifts are defined', () async {
    final result = await compileAndRun('test/int_wrap.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      'u8 2 0 15 0 44 22\n'
      'i8 56 -2 0 -1 -64 -128\n'
      'u16 14464 0 0\n'
      'i16 25536 0 -1\n'
      'i32 0 -1 -2 -2147483648 0\n'
      'u32 0 0\n'
      'wide 0 -1 0\n'
      'place 1\n',
    );
  });

  test('a zero str is empty for a local, a field, and a global', () async {
    final result = await compileAndRun('test/str_zero.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '0 0 0 0 4 0 0 0 0 0\n');
  });

  test('wrapped C is accepted by gcc -std=c11 -pedantic-errors', () async {
    for (final path in ['test/int_wrap.kl', 'test/str_zero.kl']) {
      final program = loadProject(path);
      Checker().check(program);
      final c = emitC(program, path);
      final name = path.split('/').last.replaceAll('.kl', '');
      final cPath = '${tmp.path}/$name.c';
      await File(cPath).writeAsString(c);
      final pedantic = await Process.run('gcc', [
        '-std=c11',
        '-pedantic-errors',
        '-Wall',
        '-Werror',
        cPath,
        '-o',
        '${tmp.path}/$name',
      ]);
      expect(pedantic.exitCode, 0, reason: pedantic.stderr.toString());
    }
  });
}
