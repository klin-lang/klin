@Tags(['e2e'])
library;

import 'dart:io';

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/lexer.dart';
import 'package:klin/link_args.dart';
import 'package:klin/parser.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/project.dart';
import 'package:klin/token.dart';
import 'package:test/test.dart';

import 'support/klin_cli.dart';

import 'support/compile_and_run.dart';

void main() {

  setUpAll(() async {
    await ensureKlinE2eBin();
  });

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });
  test('golden: match else { error(n) } or { } (issue 132)', () async {
    final result = await compileAndRun('test/match_else_or.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/match_else_or.out').readAsString());

    final source = File('test/match_else_or.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/match_else_or.kl');
    expect(c, contains('klin_res_str'));
    expect(c, contains('.is_err = true'));
    expect(c, contains('.is_err = false'));
  });

  test('golden: enum as array index (issue 126)', () async {
    final result = await compileAndRun('test/enum_index.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/enum_index.out').readAsString());

    final source = File('test/enum_index.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/enum_index.kl');
    expect(c, contains('codes[s]'));
    expect(c, contains('codes[Slot_B]'));
  });

  test('imported pub enum variants via mod.Enum.Variant (issue 072)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_impenum072_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/colors.kl').writeAsStringSync('''
module colors
pub enum Color { Red, Green, Blue }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import colors
fn main() {
  let c: colors.Color = colors.Color.Green
  printf("%d\\n", cast(i32, c))
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '1\n');

    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('colors_Color_Green'));
  });

  test('grouped match expression is allowed as a let initializer', () async {
    const source = '''
fn main() {
  let a = (match 1 { 1 { 2 } else { 3 } })
  printf("%d\\n", a)
}
''';
    final file = File('${tmp.path}/grouped_match.kl');
    await file.writeAsString(source);
    final result = await compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '2\n');
  });

  test('golden: pick expression emits C ternary (issue 085)', () async {
    final result = await compileAndRun('test/pick_expr.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/pick_expr.out').readAsString());

    final source = File('test/pick_expr.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/pick_expr.kl');
    expect(c, contains('?'));
    expect(c, contains(':'));
    expect(c, isNot(contains('if (')));
    final tokens = Lexer('pick').tokenize();
    expect(tokens[0].kind, TokenKind.pick_);
  });

  test('assignment from or-block resolves the target type', () async {
    const source = '''
fn fallible(): !i32 { return error(1) }
fn main() {
  let mut b = 0
  b = fallible() or { 42 }
  printf("%d\\n", b)
}
''';
    final file = File('${tmp.path}/assign_or.kl');
    await file.writeAsString(source);
    final result = await compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '42\n');
  });

  test('golden: int/float aliases emit fixed-width C types', () async {
    final result = await compileAndRun('test/int_float_aliases.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      await File('test/int_float_aliases.out').readAsString(),
    );

    final source = File('test/int_float_aliases.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/int_float_aliases.kl');
    expect(c, contains('int32_t add(int32_t a, int32_t b)'));
    expect(c, contains('int32_t x = 40;'));
    expect(c, contains('double y = 1.5;'));
    expect(c, isNot(contains(' int ')));
    expect(c, isNot(contains(' float ')));
  });

  test('golden: stdlib io.print / io.println', () async {
    final result = await compileAndRun('test/io_println.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/io_println.out').readAsString());

    final program = loadProject('test/io_println.kl');
    Checker().check(program);
    final c = emitC(program, 'test/io_println.kl');
    expect(c, contains('#include <stdio.h>'));
    expect(c, contains('int32_t puts(const char* msg);'));
    expect(c, contains('puts(" from io");'));
    expect(c, contains('io_print("hello");'));
    expect(c, contains('printf("%s", msg);'));
    expect(c, isNot(contains('io_println(')));
  });

  test('golden: stdlib str.eq / str.len (issue 080)', () async {
    final result = await compileAndRun('test/str_eq.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/str_eq.out').readAsString());

    final program = loadProject('test/str_eq.kl');
    Checker().check(program);
    final c = emitC(program, 'test/str_eq.kl');
    expect(c, contains('#include <string.h>'));
    expect(c, contains('str_eq('));
    expect(c, contains('str_len('));
    expect(c, contains('strcmp('));
    expect(c, contains('strlen('));
  });

  test('golden: stdlib math (issue 083)', () async {
    final result = await compileAndRun('test/math_basic.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/math_basic.out').readAsString());

    final program = loadProject('test/math_basic.kl');
    Checker().check(program);
    final c = emitC(program, 'test/math_basic.kl');
    expect(c, contains('#include <math.h>'));
    // pub @[cimport] emits direct C calls (like io.println → puts).
    expect(c, contains('sin('));
    expect(c, contains('sqrt('));
    expect(c, contains('fabs('));
    expect(c, contains('cbrt('));
    expect(c, contains('sqrtf('));
    expect(c, contains('sinf('));
    expect(c, contains('powf('));
    expect(collectLinkAttrs(program), contains('-lm'));
  });

  test('golden: string interpolation → printf (issue 016)', () async {
    final result = await compileAndRun('test/interp.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/interp.out').readAsString());

    final program = loadProject('test/interp.kl');
    Checker().check(program);
    final c = emitC(program, 'test/interp.kl');
    expect(c, contains('printf('));
    expect(c, contains('klin_fmt_trim_frac'));
    expect(c, isNot(contains('malloc')));
    expect(c, contains('%.8s'));
  });

  test('golden: fmt.write buffer interpolation (issue 156)', () async {
    final result = await compileAndRun('test/fmt_write.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/fmt_write.out').readAsString());

    final program = loadProject('test/fmt_write.kl');
    Checker().check(program);
    final c = emitC(program, 'test/fmt_write.kl');
    expect(c, contains('snprintf('));
    expect(c, contains('klin_fmt_write_str'));
    expect(c, isNot(contains('malloc')));
  });

  test('golden: stdlib time Instant/Duration/format (issue 037)', () async {
    final result = await compileAndRun('test/time_basic.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/time_basic.out').readAsString());

    final program = loadProject('test/time_basic.kl');
    Checker().check(program);
    final c = emitC(program, 'test/time_basic.kl');
    expect(c, contains('klin_time_format'));
    expect(c, contains('klin_time_wall_ns'));
    expect(c, contains('klin_time_mono_ns'));
    expect(c, contains('clock_gettime'));
    expect(c, isNot(contains('malloc')));
  });

  test('golden: time calendar add_days/months/years (issue 039)', () async {
    final result = await compileAndRun('test/time_calendar.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/time_calendar.out').readAsString());

    final program = loadProject('test/time_calendar.kl');
    Checker().check(program);
    final c = emitC(program, 'test/time_calendar.kl');
    expect(c, contains('klin_time_add_date'));
    expect(c, isNot(contains('malloc')));
  });

  test('golden: function pointers without capture (issue 017 phase 2)', () async {
    final result = await compileAndRun('test/fn_ptr.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/fn_ptr.out').readAsString());

    final program = loadProject('test/fn_ptr.kl');
    Checker().check(program);
    final c = emitC(program, 'test/fn_ptr.kl');
    expect(c, contains('(*'));
    expect(c, isNot(contains('malloc')));
  });

  test('golden: stdlib mem Allocator heap alloc/free (issue 057)', () async {
    final result = await compileAndRun('test/mem_alloc.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/mem_alloc.out').readAsString());

    final program = loadProject('test/mem_alloc.kl');
    Checker().check(program);
    final c = emitC(program, 'test/mem_alloc.kl');
    expect(c, contains('klin_mem_alloc_u8'));
    expect(c, contains('klin_mem_free_u8'));
    expect(c, contains('klin_mem_alloc_i32'));
    expect(c, contains('klin_mem_alloc_i64'));
    expect(c, contains('klin_mem_alloc_f64'));
    expect(c, contains('malloc'));
    expect(c, contains('free('));
    expect(c, contains('#include <stdlib.h>'));

    final hello = loadProject('test/hello.kl');
    Checker().check(hello);
    final helloC = emitC(hello, 'test/hello.kl');
    expect(helloC, isNot(contains('malloc')));
    expect(helloC, isNot(contains('klin_mem_')));
    expect(helloC, isNot(contains('#include <stdlib.h>')));
  });

  test('golden: stdlib slice ops layer 0+1 (issue 017 phase 3)', () async {
    final result = await compileAndRun('test/slice_ops.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/slice_ops.out').readAsString());

    final program = loadProject('test/slice_ops.kl');
    Checker().check(program);
    final c = emitC(program, 'test/slice_ops.kl');
    expect(c, contains('slice_map_into_i32'));
    expect(c, isNot(contains('malloc')));
    expect(c, isNot(contains('klin_mem_')));
  });

  test('golden: stdlib slice_alloc map/filter (issue 017 phase 4)', () async {
    final result = await compileAndRun('test/slice_alloc_ops.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      await File('test/slice_alloc_ops.out').readAsString(),
    );

    final program = loadProject('test/slice_alloc_ops.kl');
    Checker().check(program);
    final c = emitC(program, 'test/slice_alloc_ops.kl');
    expect(c, contains('slice_alloc_map_alloc_i32'));
    expect(c, contains('slice_alloc_filter_alloc_i32'));
    expect(c, contains('slice_alloc_map_alloc_i64'));
    expect(c, contains('slice_alloc_filter_alloc_f64'));
    expect(c, contains('klin_mem_alloc_i32'));
    expect(c, contains('klin_mem_alloc_i64'));
    expect(c, contains('malloc'));
    expect(c, contains('#include <stdlib.h>'));
  });

  test('time.parse_iso failure uses or branch', () async {
    final file = File('${tmp.path}/time_bad_parse.kl');
    await file.writeAsString(r'''
import time

fn main() {
    let t = time.parse_iso("not-a-date") or {
        printf("bad=%d\n", err)
        time.unix(0)
    }
    printf("ok=%lld\n", t.unix_ns)
}
''');
    final result = await compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, contains('bad='));
    expect(result.stdout, contains('ok=0'));
  });

  test('time.parse_iso rejects truncated datetime and trailing junk', () async {
    final file = File('${tmp.path}/time_trunc_iso.kl');
    await file.writeAsString(r'''
import time

fn main() {
    let a = time.parse_iso("2024-01-01T12:00:00") or {
        printf("trunc=1\n")
        time.unix(0)
    }
    let b = time.parse_iso("2024-01-01junk") or {
        printf("junk=1\n")
        time.unix(0)
    }
    let c = time.parse_iso("1969-12-31T23:59:59Z") or {
        printf("epoch_m1_fail=1\n")
        time.unix(0)
    }
    printf("a=%lld b=%lld c=%lld\n", a.unix_ns, b.unix_ns, c.unix_ns)
}
''');
    final result = await compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, contains('trunc=1'));
    expect(result.stdout, contains('junk=1'));
    expect(result.stdout, isNot(contains('epoch_m1_fail=1')));
    expect(result.stdout, contains('c=-1000000000'));
  });

  test('time.format returns -1 for too-small buffer', () async {
    final file = File('${tmp.path}/time_tiny_buf.kl');
    await file.writeAsString(r'''
import time

fn main() {
    let t = time.unix(1704067200)
    let mut buf: [1]u8
    let n = time.format(buf[:], "%Y-%m-%d", t)
    printf("n=%d\n", n)
}
''');
    final result = await compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, contains('n=-1'));
  });

  test(r'golden: $fn macro expands to a specialized struct (issue 026)',
      () async {
    final result = await compileAndRun('test/point_macro.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/point_macro.out').readAsString());

    final raw = File('test/point_macro.kl').readAsStringSync();
    final expanded = preprocess(raw, path: 'test/point_macro.kl');
    expect(expanded, contains('struct Vec2i'));
    expect(expanded, contains('fn (p: Vec2i) len_sq(): i32'));
    expect(expanded, isNot(contains(r'$fn')));
    expect(expanded, isNot(contains(r'$point')));

    final program = loadProject('test/point_macro.kl');
    Checker().check(program);
    final c = emitC(program, 'test/point_macro.kl');
    expect(c, contains('typedef struct'));
    expect(c, contains('Vec2i'));
    expect(c, contains('len_sq'));
  });

  test('syntax error through CLI: nonzero exit and line number on stderr',
      () async {
    final proc = await runKlin(['test/bad_syntax.kl']);
    expect(proc.exitCode, isNot(0));
    expect(proc.stderr.toString(), contains('3:'));
  });

  test('type error through CLI: nonzero exit and message', () async {
    final proc = await runKlin(['test/type_mismatch.kl']);
    expect(proc.exitCode, isNot(0));
    final err = proc.stderr.toString();
    expect(err, contains('2:'));
    expect(err, contains('type mismatch'));
  });

  test('mutation error through CLI: nonzero exit and message', () async {
    final proc = await runKlin(['test/immutable_assign.kl']);
    expect(proc.exitCode, isNot(0));
    final err = proc.stderr.toString();
    expect(err, contains('3:'));
    expect(err, contains('immutable variable'));
  });

  test('golden: fizzbuzz.kl', () async {
    final result = await compileAndRun('test/fizzbuzz.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/fizzbuzz.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: break_continue.kl — while + C-style for', () async {
    final result = await compileAndRun('test/break_continue.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/break_continue.out').readAsString();
    expect(result.stdout, expected);
  });

}
