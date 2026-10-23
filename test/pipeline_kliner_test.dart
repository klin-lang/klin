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
    tmp = await Directory.systemTemp.createTemp('klin_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('self-referential struct pointer emits a named C tag', () async {
    final result = await compileAndRun('test/self_ref_struct.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/self_ref_struct.out').readAsString());

    final program = loadProject('test/self_ref_struct.kl');
    Checker().check(program);
    final c = emitC(program, 'test/self_ref_struct.kl');
    expect(c, contains('typedef struct self_ref_struct_Node {'));
    expect(c, contains('struct self_ref_struct_Node * next;'));
    expect(c, contains('struct self_ref_struct_Node * prev;'));
    expect(c, contains('typedef struct self_ref_struct_Holder {'));
    expect(c, contains('struct self_ref_struct_Item * item;'));
    expect(c, contains('typedef struct self_ref_struct_Item {'));
  });
}
