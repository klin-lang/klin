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

  test('enum can be a struct field', () async {
    final result = await compileAndRun('test/enum_field.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/enum_field.out').readAsString());

    final program = loadProject('test/enum_field.kl');
    Checker().check(program);
    final c = emitC(program, 'test/enum_field.kl');
    expect(c, contains('enum_field_Tok k;'));
  });

  test('full-slice view write mutates the array', () async {
    final result = await compileAndRun('test/slice_view_write.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/slice_view_write.out').readAsString());

    final program = loadProject('test/slice_view_write.kl');
    Checker().check(program);
    final c = emitC(program, 'test/slice_view_write.kl');
    expect(c, contains(
        'typedef struct { int32_t *ptr; size_t len; } klin_slice_i32;'));
    expect(c, contains('klin_slice_i32 s = (klin_slice_i32){ xs, 3 };'));
    expect(c, contains('s.ptr[0] = 7;'));
  });

  test('byte-string literal is []u8 with .len', () async {
    final result = await compileAndRun('test/byte_string.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/byte_string.out').readAsString());

    final program = loadProject('test/byte_string.kl');
    Checker().check(program);
    final c = emitC(program, 'test/byte_string.kl');
    expect(c, contains('klin_slice_u8'));
    expect(c, contains('(uint8_t *)"fn", 2'));
    expect(c, contains(r'(uint8_t *)"a\tb\"\\$", 6'));
    // Embedded NUL is `\000` plus an explicit length, not strlen.
    expect(c, contains(r'(uint8_t *)"ab\000", 3'));
    expect(c, contains(r'(uint8_t *)"/proc/self/cmdline\000", 19'));
    expect(c, contains(r'(uint8_t *)"\000a", 2'));
    expect(c, contains(r'"hi\000there"'));
  });

  test('module-level const is a C constant', () async {
    final result = await compileAndRun('test/module_const.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/module_const.out').readAsString());

    final program = loadProject('test/module_const.kl');
    Checker().check(program);
    final c = emitC(program, 'test/module_const.kl');
    expect(c, contains('const int64_t module_const_PAGE = 4096;'));
    expect(c, isNot(contains('static const int64_t module_const_PAGE')));
    expect(c, contains('static const bool module_const_FLAG = true;'));
    expect(c, contains('static const int32_t module_const_NEG = -100;'));
    expect(c, contains('static const int32_t module_const_HEX = -0x10;'));
    expect(
      c,
      contains(
          'static const klin_slice_u8 module_const_KW = { (uint8_t *)"fn", 2 };'),
    );
  });

  test('imported pub const is visible', () async {
    final result = await compileAndRun('test/const_mod/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/const_mod/app.out').readAsString());

    final program = loadProject('test/const_mod/app.kl');
    Checker().check(program);
    final c = emitC(program, 'test/const_mod/app.kl');
    expect(c, contains('const int64_t os_AT_FDCWD = -100;'));
    expect(c, contains('static const int32_t os_HIDDEN = 1;'));
  });

  test('imported const in an if / while / for head is not a struct literal',
      () async {
    final result = await compileAndRun('test/const_mod/cond.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/const_mod/cond.out').readAsString());
  });

  test('struct tags are forward-declared before fn-pointer typedefs', () async {
    final program = loadProject('test/self_ref_fnptr.kl');
    Checker().check(program);
    final c = emitC(program, 'test/self_ref_fnptr.kl');
    final fwd = c.indexOf('struct self_ref_fnptr_Node;');
    final fnTypedef = c.indexOf('(struct self_ref_fnptr_Node *);');
    expect(fwd, greaterThanOrEqualTo(0));
    expect(fnTypedef, greaterThan(fwd));
    expect(c, contains('struct self_ref_fnptr_A;'));
    expect(c, contains('struct self_ref_fnptr_B;'));

    final result = await compileAndRun('test/self_ref_fnptr.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/self_ref_fnptr.out').readAsString());
  });

  test('expr! propagates between different !T result types', () async {
    final result = await compileAndRun('test/propagate_cross.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/propagate_cross.out').readAsString());
  });
}
