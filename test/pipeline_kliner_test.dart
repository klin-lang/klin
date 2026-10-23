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
  test('mutating method and & through *mut', () async {
    final result = await compileAndRun('test/mut_place.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/mut_place.out').readAsString());

    final program = loadProject('test/mut_place.kl');
    Checker().check(program);
    final c = emitC(program, 'test/mut_place.kl');
    // A mut receiver is already T* in C. Another mut call passes it;
    // a by-value call dereferences.
    expect(c, contains('mut_place_Out_add(o, b.len);'));
    expect(c, contains('mut_place_Out_get(*(o))'));
    expect(c, isNot(contains('mut_place_Out_add(&o')));
    // Place reached through *mut: address the field, do not require a let mut.
    expect(c, contains('mut_place_Out_lit(&(*(c)).err,'));
    expect(c, contains('mut_place_Slot_set(&(*(c)).slots[1], 9);'));
    expect(c, contains('mut_place_Out_add(&c->err, 1);'));
    expect(c, contains('mut_place_Out_add(&(*(p)), 5);'));
  });

  test('integer const is an array length', () async {
    final result =
        await compileAndRun('test/const_array_len.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/const_array_len.out').readAsString());

    final program = loadProject('test/const_array_len.kl');
    Checker().check(program);
    final c = emitC(program, 'test/const_array_len.kl');
    // The bound is the integer value, not the C name of the const.
    expect(c, contains('static const int64_t const_array_len_N = 4;'));
    expect(c, contains('static const int32_t const_array_len_HEX = 0x4;'));
    expect(c, contains("static const uint8_t const_array_len_A = 'A';"));
    expect(c, contains('int32_t data[4];'));
    expect(c, contains('int32_t xs[4]'));
    expect(c, contains('uint8_t xs[65]'));
    expect(c, isNot(contains('data[const_array_len_N]')));
    expect(c, isNot(contains('xs[const_array_len_HEX]')));
  });

  test('imported integer const is an array length', () async {
    final result =
        await compileAndRun('test/const_len_mod/app.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/const_len_mod/app.out').readAsString());

    final program = loadProject('test/const_len_mod/app.kl');
    Checker().check(program);
    final c = emitC(program, 'test/const_len_mod/app.kl');
    expect(c, contains('const int64_t os_PAGE = 8;'));
    expect(c, contains('uint8_t data[8];'));
    expect(c, contains('uint8_t buf[8]'));
    expect(c, contains('uint8_t xs[8]'));
    expect(c, isNot(contains('[os_PAGE]')));
  });

  test('integer literals that fit their type compile and run', () async {
    final result = await compileAndRun('test/int_range.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/int_range.out').readAsString());

    final program = loadProject('test/int_range.kl');
    Checker().check(program);
    final c = emitC(program, 'test/int_range.kl');
    expect(c, contains('static const uint8_t int_range_HI = 255;'));
    expect(c, contains('static const int8_t int_range_LO = -128;'));
    expect(c, contains('static const uint8_t int_range_CH = \'A\';'));
  });

  test('unary - and ~ on an integer literal use the expected type', () async {
    final result =
        await compileAndRun('test/int_literal_op.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/int_literal_op.out').readAsString());

    final program = loadProject('test/int_literal_op.kl');
    Checker().check(program);
    final c = emitC(program, 'test/int_literal_op.kl');
    expect(c, contains('static const uint32_t int_literal_op_M = ~0;'));
    expect(c, contains('static const uint8_t int_literal_op_NIB = ~0x0F;'));
    expect(c, contains('static const int8_t int_literal_op_MIN = -128;'));
    expect(c, contains('int64_t a = -(1);'));
    expect(c, contains('int_literal_op_take(-(1))'));
  });

  test('folded integer constants compile and run', () async {
    final result =
        await compileAndRun('test/const_fold_mod/app.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/const_fold_mod/app.out').readAsString());

    final program = loadProject('test/const_fold_mod/app.kl');
    Checker().check(program);
    final c = emitC(program, 'test/const_fold_mod/app.kl');
    expect(c, contains('static const int32_t fold_TWICE = 6;'));
    expect(c, contains('static const uint8_t fold_MASK = ~0x0F;'));
    expect(c, contains('static const int32_t fold_SH = 16;'));
    expect(
      c,
      contains('static const uint64_t fold_WIDE = 18446744073709551615ULL;'),
    );
    expect(
      c,
      contains(
          'static const int64_t fold_IMIN = (-9223372036854775807LL - 1);'),
    );
    expect(c, contains('const int32_t os_PAGE = 4096;'));
    expect(c, contains('int32_t data[6];'));
    expect(c, contains('uint8_t raw[3]'));
    expect(c, contains('uint8_t kb[4]'));
    expect(c, contains('~(x)'));
    expect(c, isNot(contains('constexpr')));
    expect(c, isNot(contains('[fold_TWICE]')));
    expect(c, isNot(contains('[os_PAGE]')));
  });

  test('array literal uses the expected element type', () async {
    final result = await compileAndRun('test/array_lit.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/array_lit.out').readAsString());

    final program = loadProject('test/array_lit.kl');
    Checker().check(program);
    final c = emitC(program, 'test/array_lit.kl');
    expect(c, contains('uint8_t a[3] = { 1, 2, 3 };'));
    expect(c, contains('int32_t plain[2] = { 10, 20 };'));
    expect(c, contains('int8_t small[1] = { -(128) };'));
    expect(c, contains('take((uint8_t[3]){ 7, 8, 9 })'));
  });

  test('nested array keeps every bound in C', () async {
    final result = await compileAndRun('test/nested_array.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/nested_array.out').readAsString());

    final program = loadProject('test/nested_array.kl');
    Checker().check(program);
    final c = emitC(program, 'test/nested_array.kl');
    expect(c, contains('uint8_t xs[1][2];'));
    expect(c, contains('uint8_t xs[1][2])'));
    expect(c, contains('uint8_t nested[1][2] = { { 4, 5 } };'));
    expect(c, contains('uint8_t blank[2][2] = {0};'));
    expect(c, contains('cell((uint8_t[1][2]){ { 8, 9 } })'));
  });

  test('i64 minimum and u64 maximum literals compile and run', () async {
    final result = await compileAndRun('test/wide_literal.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/wide_literal.out').readAsString());

    final program = loadProject('test/wide_literal.kl');
    Checker().check(program);
    final c = emitC(program, 'test/wide_literal.kl');
    expect(c, contains('(-9223372036854775807LL - 1)'));
    expect(c, contains('18446744073709551615ULL'));
    expect(c, isNot(contains('9223372036854775808')));
  });

  test('address of a slice element follows place mutability', () async {
    final result = await compileAndRun('test/slice_addr.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/slice_addr.out').readAsString());

    final program = loadProject('test/slice_addr.kl');
    Checker().check(program);
    final c = emitC(program, 'test/slice_addr.kl');
    expect(c, contains('klin_slice_i32'));
    expect(c, contains('.ptr[1]'));
    expect(c, contains('.ptr[2]'));
  });

  test('integer constant expressions fold outside const', () async {
    final result = await compileAndRun('test/const_expr.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/const_expr.out').readAsString());

    final program = loadProject('test/const_expr.kl');
    Checker().check(program);
    final c = emitC(program, 'test/const_expr.kl');
    expect(c, contains('uint8_t a = 3;'));
    expect(c, contains('uint8_t e = ~(0);'));
    expect(c, contains('(-9223372036854775807LL - 1)'));
    expect(c, contains('18446744073709551615ULL'));
    expect(c, contains('(y + 1)'));
    expect(c, isNot(contains('constexpr')));

    final cPath = '${tmp.path}/const_expr_pedantic.c';
    await File(cPath).writeAsString(c);
    final pedantic = await Process.run('gcc', [
      '-std=c11',
      '-pedantic-errors',
      cPath,
      '-o',
      '${tmp.path}/const_expr_pedantic',
    ]);
    expect(pedantic.exitCode, 0, reason: pedantic.stderr.toString());
  });

  test('enum variant on the base maximum compiles and runs', () async {
    final result = await compileAndRun('test/enum_auto.kl', tmp, cc: 'gcc');
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/enum_auto.out').readAsString());
  });
}
