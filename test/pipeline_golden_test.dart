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
import 'package:klin/remote.dart';
import 'package:klin/token.dart';
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

  test('golden: hello.kl prints expected output', () async {
    final result = await compileAndRun('test/hello.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/hello.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: shared type annotation `a, b: T` (issue 068)', () async {
    final result = await compileAndRun('test/shared_type.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/shared_type.out').readAsString());

    final source = File('test/shared_type.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/shared_type.kl');
    // `x, y: f64` expands to two fields; `a, b: i32` to two params.
    expect(c, contains('double x;'));
    expect(c, contains('double y;'));
    expect(c, contains('int32_t a, int32_t b, int32_t c'));
  });

  test('golden: !T propagates errors and or handles them', () async {
    final result = await compileAndRun('test/result_chain.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/result_chain.out').readAsString());

    final source = File('test/result_chain.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/result_chain.kl');
    expect(c, contains('} klin_res_i32;'));
    expect(c, contains('.is_err = true'));
    expect(c, contains('.u.ok ='));
  });

  test('golden: struct destructuring `let { }` (issue 056)', () async {
    final result = await compileAndRun('test/destruct_struct.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/destruct_struct.out').readAsString());

    final source = File('test/destruct_struct.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/destruct_struct.kl');
    // A plain-name source lowers to direct field reads, no temp copy.
    expect(c, contains('int32_t x = p.x;'));
    expect(c, contains('int32_t y = p.y;'));
    // A call source is evaluated once into a temp, then read per field.
    expect(c, contains('klin_val_0 = make();'));
    expect(c, contains('int32_t x = klin_val_0.x;'));
  });

  test('golden: fixed-array destructuring `let [ ]` (issue 056)', () async {
    final result = await compileAndRun('test/destruct_array.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/destruct_array.out').readAsString());

    final source = File('test/destruct_array.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/destruct_array.kl');
    // A named array source (no shadow) is indexed in place.
    expect(c, contains('int32_t a = xs[0];'));
    expect(c, contains('int32_t c = xs[2];'));
    // A binding that shadows the source name captures it via a pointer first.
    expect(c, contains('int32_t *'));
    expect(c, contains('int32_t xs = '));
  });

  test('golden: destructuring rename and `_` skip (issue 056 phase D)',
      () async {
    final result = await compileAndRun('test/destruct_phase_d.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/destruct_phase_d.out').readAsString());

    final source = File('test/destruct_phase_d.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/destruct_phase_d.kl');
    // Rename binds the local name from the named field.
    expect(c, contains('int32_t px = p.x;'));
    expect(c, contains('int32_t py = p.y;'));
    // `_` skips positions but keeps the original indices.
    expect(c, contains('int32_t b = xs[1];'));
    expect(c, contains('int32_t d = xs[3];'));
    expect(c, contains('int32_t last = xs[3];'));
    // A `_`-skipped literal element is still evaluated (side effects run).
    expect(c, contains('= noisy();'));
  });

  test('golden: multi-assignment swap (issue 056 phase B)', () async {
    final result = await compileAndRun('test/multi_assign.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/multi_assign.out').readAsString());

    final source = File('test/multi_assign.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/multi_assign.kl');
    // Values are captured into temps before any target is written.
    expect(c, contains('int32_t klin_val_0 = b;'));
    expect(c, contains('int32_t klin_val_1 = a;'));
    expect(c, contains('a = klin_val_0;'));
    expect(c, contains('b = klin_val_1;'));
  });

  test('golden: bare struct assignment `{ } =` (issue 056 phase A\')', () async {
    final result = await compileAndRun('test/struct_assign.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/struct_assign.out').readAsString());

    final source = File('test/struct_assign.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/struct_assign.kl');
    // The source is copied once, then each field is assigned to its target.
    expect(c, contains('x = klin_val_0.x;'));
    expect(c, contains('y = klin_val_0.y;'));
    // A rename assigns the field to a differently named target.
    expect(c, contains('a = klin_val_1.x;'));
  });

  test("a plain block after a statement stays a block (issue 056)", () async {
    // `{ ... }` with no trailing `=` must not be read as a destructure pattern.
    const source = '''
fn main() {
  let mut x: i32 = 1
  {
    x = 2
  }
  printf("%d\\n", x)
}
''';
    final file = File('${tmp.path}/block_stmt.kl');
    await file.writeAsString(source);
    final result = await compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '2\n');
  });

  test('propagation runs defer before returning an error', () async {
    const source = '''
fn fail(): !i32 { return error(7) }
fn wrap(): !i32 {
  defer puts("cleanup")
  return fail()!
}
fn main() {
  let value = wrap() or { err }
  printf("%d\\n", value)
}
''';
    final file = File('${tmp.path}/defer_propagate.kl');
    await file.writeAsString(source);
    final result = await compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'cleanup\n7\n');
  });

  test('or and propagate work as call arguments', () async {
    const source = '''
fn fail(): !i32 { return error(3) }
fn ok(): !i32 { return 8 }
fn main() {
  printf("%d\\n", ok() or { 0 })
  printf("%d\\n", fail() or { err })
}
''';
    final file = File('${tmp.path}/result_nested.kl');
    await file.writeAsString(source);
    final result = await compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '8\n3\n');
  });

  test('golden: vars.kl — arithmetic, mut, range', () async {
    final result = await compileAndRun('test/vars.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/vars.out').readAsString();
    expect(result.stdout, expected);

    final source = File('test/vars.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/vars.kl');
    expect(c, contains('int32_t x = (2 + 3);'));
    expect(c, contains('int32_t y = (x * 2);'));
    expect(c, contains('y = (y + 1);'));
  });

  test('golden: logical ops && || (issue 097)', () async {
    final result = await compileAndRun('test/logical.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/logical.out').readAsString());

    final source = File('test/logical.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/logical.kl');
    expect(c, contains('(a && !(b))'));
    expect(c, contains('(b || a)'));
    expect(c, contains('(b && side_effect_false())'));
    expect(c, contains('(a || side_effect_false())'));
    // Precedence: `||` below `&&`.
    expect(c, contains('(a || (b && false))'));
  });

  test('golden: bitwise ops | & ^ ~ << >> (issue 078)', () async {
    final result = await compileAndRun('test/bitwise.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/bitwise.out').readAsString());

    final source = File('test/bitwise.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/bitwise.kl');
    expect(c, contains('(a & b)'));
    expect(c, contains('(a | b)'));
    expect(c, contains('(a ^ b)'));
    expect(c, contains('~(a)'));
    expect(c, contains('(1 << 3)'));
    expect(c, contains('(0x8 >> 2)'));
    // Rust-like: `&` binds tighter than `==`.
    expect(c, contains('((flags & 0x4) == 0x4)'));
    // Compound assigns emit 1:1 as C `op=`.
    expect(c, contains('f |= 0x1;'));
    expect(c, contains('f &= 0x5;'));
    expect(c, contains('f ^= 0x1;'));
    expect(c, contains('f <<= 1;'));
    expect(c, contains('f >>= 1;'));
  });

  test('golden: arithmetic compound assigns += -= *= /= %=', () async {
    final dir = Directory.systemTemp.createTempSync('klin_arith_comp_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/app.kl').writeAsStringSync('''
fn main() {
  let mut x: i32 = 10
  x += 5
  x -= 3
  x *= 2
  x /= 4
  x %= 3
  printf("%d\\n", x)

  let mut f: f64 = 2.0
  f *= 1.5
  f += 0.5
  printf("%.1f\\n", f)
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '0\n3.5\n');

    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('x += 5;'));
    expect(c, contains('x -= 3;'));
    expect(c, contains('x *= 2;'));
    expect(c, contains('x /= 4;'));
    expect(c, contains('x %= 3;'));
    expect(c, contains('f *= 1.5;'));
  });

  test('golden: short_decl.kl — := sugar for let mut (issue 055)', () async {
    final result = await compileAndRun('test/short_decl.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/short_decl.out').readAsString());

    final source = File('test/short_decl.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/short_decl.kl');
    expect(c, contains('int32_t x = (2 + 3);'));
    expect(c, contains('int32_t i = 0;'));
    expect(c, isNot(contains('mut')));

    final tokens = Lexer('x := 1').tokenize();
    expect(tokens[1].kind, TokenKind.colonEqual);
    expect(tokens[1].lexeme, ':=');
  });

  test('golden: for_c_post_compound.kl — += / -= in post (issue 152)',
      () async {
    final result = await compileAndRun('test/for_c_post_compound.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      await File('test/for_c_post_compound.out').readAsString(),
    );

    final source = File('test/for_c_post_compound.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/for_c_post_compound.kl');
    expect(c, contains('i += 2'));
    expect(c, contains('j -= 2'));
  });

  test('golden: for_c_init_assign.kl — = assigns existing mut (issue 151)',
      () async {
    final result = await compileAndRun('test/for_c_init_assign.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      await File('test/for_c_init_assign.out').readAsString(),
    );

    final source = File('test/for_c_init_assign.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/for_c_init_assign.kl');
    expect(c, contains('for (i = 1;'));
    expect(c, isNot(contains('int32_t i = 1')));
  });

  test('golden: if/while/for bare-name condition (issue 064)', () async {
    final result = await compileAndRun('test/if_cond_bare_name.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      await File('test/if_cond_bare_name.out').readAsString(),
    );
  });

  test('golden: struct literal in if-condition needs parens (issue 064)',
      () async {
    final result = await compileAndRun('test/if_cond_struct_paren.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      await File('test/if_cond_struct_paren.out').readAsString(),
    );
  });

  test('golden: match statement lowers to if/else chains (issue 014)',
      () async {
    final result = await compileAndRun('test/match_stmt.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/match_stmt.out').readAsString());

    final source = File('test/match_stmt.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/match_stmt.kl');
    // No switch/case/break: `match` is an if/else chain, so arms never fall
    // through and `break` inside an arm still belongs to the enclosing loop.
    expect(c, isNot(contains('switch (')));
    expect(c, isNot(contains('case ')));
    // The subject is evaluated once into a temp, then compared.
    expect(c, matches(RegExp(r'if \(\w+ == 1 \|\| \w+ == 2 \|\| \w+ == 3\)')));
    expect(c, matches(RegExp(r'else if \(\(\w+ >= 4 && \w+ <= 10\)\)')));

    final tokens = Lexer('match x { 1..=2 { } }').tokenize();
    expect(tokens[0].kind, TokenKind.match_);
    expect(tokens[4].kind, TokenKind.dotDotEqual);
    expect(tokens[4].lexeme, '..=');
  });

  test('golden: match expression assigns from each arm (issue 014)', () async {
    final result = await compileAndRun('test/match_expr.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/match_expr.out').readAsString());

    final source = File('test/match_expr.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/match_expr.kl');
    expect(c, isNot(contains('switch (')));
    // The result is a plain declaration assigned inside the branches.
    expect(c, contains('int32_t a;'));
    expect(c, contains('double c;'));
  });

  test('golden: match when guards (issue 084)', () async {
    final result = await compileAndRun('test/match_when.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/match_when.out').readAsString());

    final source = File('test/match_when.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/match_when.kl');
    expect(c, isNot(contains('switch (')));
    expect(c, contains('flag != 0'));
    final tokens = Lexer('when').tokenize();
    expect(tokens[0].kind, TokenKind.when_);
  });

  test('golden: match relational patterns (issue 084)', () async {
    final result = await compileAndRun('test/match_rel.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/match_rel.out').readAsString());

    final source = File('test/match_rel.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/match_rel.kl');
    expect(c, matches(RegExp(r'if \(\w+ > 0\)')));
    expect(c, matches(RegExp(r'else if \(\w+ < 0\)')));
    expect(c, matches(RegExp(r'\w+ >= lim')));
    expect(c, matches(RegExp(r'\w+ != 0')));
  });

  test('golden: enums — base type, methods, match, cast (issue 072)', () async {
    final result = await compileAndRun('test/enum_basic.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/enum_basic.out').readAsString());

    final source = File('test/enum_basic.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/enum_basic.kl');
    // Portable emission: a base typedef plus an anonymous enum of constants
    // (no C23 `enum E : T`, so tcc works).
    expect(c, contains('typedef int32_t Color;'));
    expect(c, contains('enum { Color_Red, Color_Green, Color_Blue };'));
    expect(c, contains('typedef uint8_t Status;'));
    expect(c, contains('Status_Warn = 5'));
    // Receiver method on an enum + enum constant + explicit casts.
    expect(c, contains('Color_name(Color c)'));
    expect(c, contains('c == Color_Green'));
    expect(c, contains('(int32_t)(s)'));
    expect(c, contains('(Status)(5)'));
  });

  test('golden: numeric cast int/float (issue 154)', () async {
    final result = await compileAndRun('test/numeric_cast.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/numeric_cast.out').readAsString());

    final source = File('test/numeric_cast.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/numeric_cast.kl');
    expect(c, contains('(int64_t)(a)'));
    expect(c, contains('(uint8_t)(300)'));
    expect(c, contains('(double)(a)'));
    expect(c, contains('(int32_t)('));
    expect(c, contains('(float)('));
  });

  test('golden: exhaustive enum match without else (issue 129)', () async {
    final result = await compileAndRun('test/enum_match_exh.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/enum_match_exh.out').readAsString());
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
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/bad_syntax.kl'],
    );
    expect(proc.exitCode, isNot(0));
    expect(proc.stderr.toString(), contains('3:'));
  });

  test('type error through CLI: nonzero exit and message', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/type_mismatch.kl'],
    );
    expect(proc.exitCode, isNot(0));
    final err = proc.stderr.toString();
    expect(err, contains('2:'));
    expect(err, contains('type mismatch'));
  });

  test('mutation error through CLI: nonzero exit and message', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/immutable_assign.kl'],
    );
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

  test('golden: defer — LIFO order', () async {
    final result = await compileAndRun('test/defer_order.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_order.out').readAsString());
  });

  test('golden: defer before break is block-scoped', () async {
    final result = await compileAndRun('test/defer_break.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_break.out').readAsString());
  });

  test('golden: defer before continue is block-scoped', () async {
    final result = await compileAndRun('test/defer_continue.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_continue.out').readAsString());
  });

  test('golden: defer before return preserves value', () async {
    final result = await compileAndRun('test/defer_return.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_return.out').readAsString());
  });

  test('early return does not run a later defer', () async {
    const source = '''
fn main() {
  defer puts("a")
  puts("body")
  return
  defer puts("b")
}
''';
    final dir = await Directory.systemTemp.createTemp('klin_defer_early_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    final kl = File('${dir.path}/early.kl');
    await kl.writeAsString(source);
    final result = await compileAndRun(kl.path, dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'body\na\n');
  });

  test('golden: function called before definition', () async {
    final result = await compileAndRun('test/call_before_def.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/call_before_def.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: recursive fib', () async {
    final result = await compileAndRun('test/fib.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/fib.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: Vec2 — structs, fields, and methods', () async {
    final result = await compileAndRun('test/vec2.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/vec2.out').readAsString());

    final program = loadProject('test/vec2.kl');
    Checker().check(program);
    final c = emitC(program, 'test/vec2.kl');
    expect(c, contains('vec2_Vec2_translate(vec2_Vec2 *v'));
    expect(c, isNot(contains('mut')));
  });

  test('golden: project with modules', () async {
    final result = await compileAndRun('test/modules/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/modules/app.out').readAsString());

    final program = loadProject('test/modules/app.kl');
    Checker().check(program);
    final c = emitC(program, 'test/modules/app.kl');
    expect(c, contains('typedef struct {'));
    expect(c, contains('} geom_Vec2;'));
    expect(c, contains('static void geom_helper(void);'));
    expect(c, contains('geom_Vec2_len_sq(geom_Vec2 v)'));
    expect(c, contains('util_add(2, 3)'));
  });

  test('explicit import alias `import geom oso` (issue 048)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_alias048_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/geom.kl').writeAsStringSync('''
module geom
pub fn answer(): i32 { return 42 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom oso
fn main() {
  printf("%d\\n", oso.answer())
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '42\n');

    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    // The alias is frontend-only; C uses the real module name.
    expect(c, contains('geom_answer'));
  });

  test('string path import `import "sub/osa"` with optional alias (issue 048)',
      () async {
    final dir = Directory.systemTemp.createTempSync('klin_pathimp048_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/sub').createSync();
    File('${dir.path}/sub/osa.kl').writeAsStringSync('''
module osa
pub fn answer(): i32 { return 7 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import "sub/osa"
import "sub/osa" aa
fn main() {
  printf("%d %d\\n", osa.answer(), aa.answer())
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '7 7\n');

    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('osa_answer'));
  });

  test('string path import tolerates a trailing `.kl` (issue 048)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_pathkl048_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/sub').createSync();
    File('${dir.path}/sub/osa.kl').writeAsStringSync('''
module osa
pub fn answer(): i32 { return 9 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import "sub/osa.kl"
fn main() {
  printf("%d\\n", osa.answer())
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '9\n');
  });

  test(
    'klin get device SVD + \$device offline preprocess (issue 053 network)',
    () async {
    final cache = Directory.systemTemp.createTempSync('klin_get053_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final work = Directory.systemTemp.createTempSync('klin_getwork053_');
    addTearDown(() => work.deleteSync(recursive: true));
    const devicePath =
        'github/tinygo-org/stm32-svd/svd/stm32f411.svd';
    File('${work.path}/app.kl').writeAsStringSync('''
\$device("$devicePath", "RCC,GPIOA")
fn main() {
  RCC.AHB1ENR.GPIOAEN.set(1)
}
''');
    final repoRoot = Directory.current.path;
    final klinBin = '$repoRoot/bin/klin.dart';
    final env = {
      ...Platform.environment,
      'KLIN_CACHE': cache.path,
    };

    final get = await Process.run(
      'dart',
      ['run', klinBin, 'get', '$devicePath@main'],
      workingDirectory: work.path,
      environment: env,
    );
    expect(get.exitCode, 0, reason: '${get.stderr}${get.stdout}');
    expect(File('${work.path}/klin.mod').existsSync(), isTrue);
    final mod = loadKlinMod(File('${work.path}/klin.mod'));
    expect(mod.devices[devicePath], 'main');
    expect(File('${work.path}/klin.lock').existsSync(), isTrue);
    final lock = loadKlinLock(File('${work.path}/klin.lock'));
    final entry = lock.packages[devicePath]!;
    expect(entry.version, 'main');
    expect(entry.commit, matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(entry.hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    final svdCached =
        '${cache.path}/asset/github/tinygo-org/stm32-svd/svd/stm32f411.svd';
    expect(File(svdCached).existsSync(), isTrue);
    expect(fileContentHash(svdCached), entry.hash);

    final pp = await Process.run(
      'dart',
      ['run', klinBin, '--emit-pp', '${work.path}/app.kl'],
      workingDirectory: work.path,
      environment: env,
    );
    expect(pp.exitCode, 0, reason: '${pp.stderr}${pp.stdout}');
    final ppFile = File('${work.path}/out/app.pp.kl');
    // emit-pp may write under cwd out/ — accept either
    final ppText = ppFile.existsSync()
        ? ppFile.readAsStringSync()
        : File('$repoRoot/out/app.pp.kl').readAsStringSync();
    expect(ppText, contains('RCC_AHB1ENR_GPIOAEN_set(1)'));
  },
    timeout: Timeout(Duration(minutes: 3)),
  );

  test('import resolves from lib/ next to the importer (issue 020)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_lib_dir_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/lib').createSync();
    File('${dir.path}/lib/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return a + b }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import mathx
fn main() {
  printf("%d\\n", mathx.add(2, 3))
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '5\n');
  });

  test('import -I / KLIN_PATH; sibling wins over lib/ (issue 020)', () async {
    final root = Directory.systemTemp.createTempSync('klin_lib_path_');
    addTearDown(() => root.deleteSync(recursive: true));
    final vendor = Directory('${root.path}/vendor')..createSync();
    File('${vendor.path}/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return a + b }
''');
    final appDir = Directory('${root.path}/app')..createSync();
    Directory('${appDir.path}/lib').createSync();
    File('${appDir.path}/lib/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return 99 }
''');
    File('${appDir.path}/mathx.kl').writeAsStringSync('''
module mathx
pub fn add(a: i32, b: i32): i32 { return 7 }
''');
    File('${appDir.path}/app.kl').writeAsStringSync('''
module app
import mathx
fn main() {
  printf("%d\\n", mathx.add(2, 3))
}
''');

    // Sibling wins over lib/.
    final sibling = await compileAndRun('${appDir.path}/app.kl', tmp);
    expect(sibling.exitCode, 0, reason: sibling.stderr);
    expect(sibling.stdout, '7\n');

    File('${appDir.path}/mathx.kl').deleteSync();
    Directory('${appDir.path}/lib').deleteSync(recursive: true);

    // -I finds vendor.
    final viaI = await Process.run(
      'dart',
      [
        'run',
        'bin/klin.dart',
        'run',
        '-I',
        vendor.path,
        '${appDir.path}/app.kl',
      ],
    );
    expect(viaI.exitCode, 0, reason: '${viaI.stderr}${viaI.stdout}');
    expect(viaI.stdout, '5\n');

    // $KLIN_PATH finds vendor.
    final viaEnv = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'run', '${appDir.path}/app.kl'],
      environment: {
        ...Platform.environment,
        'KLIN_PATH': vendor.path,
      },
    );
    expect(viaEnv.exitCode, 0, reason: '${viaEnv.stderr}${viaEnv.stdout}');
    expect(viaEnv.stdout, '5\n');
  });

  test('directory package is one module; private shared across files (issue 047)',
      () async {
    final result = await compileAndRun('examples/pkg_geom/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '25\n');

    final program = loadProject('examples/pkg_geom/app.kl');
    Checker().check(program);
    final c = emitC(program, 'examples/pkg_geom/app.kl');
    expect(c, contains('static int32_t geom_sq('));
    expect(c, contains('geom_Vec2_len_sq('));
  });

  test('entry loads same-module sibling files (issue 047)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_entry_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/helper.kl').writeAsStringSync('''
module app
fn answer(): i32 { return 7 }
''');
    File('${dir.path}/main.kl').writeAsStringSync('''
module app
fn main() {
  printf("%d\\n", answer())
}
''');
    final result = await compileAndRun('${dir.path}/main.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '7\n');
  });

  test('golden: nested mutable places (issue 069 checker unblock)', () async {
    final result = await compileAndRun('test/nested_mut_place.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/nested_mut_place.out').readAsString());

    final source = File('test/nested_mut_place.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/nested_mut_place.kl');
    // A mut receiver's nested array element writes through the pointer.
    expect(c, contains('b->slots[i] = v;'));
    // Nested struct field and array-element field through a mut variable.
    expect(c, contains('o.inner.x = 5;'));
    expect(c, contains('xs[0].x = 9;'));
  });

  test('golden: assign to a field through a *mut deref (parser + checker)',
      () async {
    final result = await compileAndRun('test/deref_field_assign.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/deref_field_assign.out').readAsString());

    final source = File('test/deref_field_assign.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/deref_field_assign.kl');
    expect(c, contains('(*(p)).x = 7;'));
    expect(c, contains('(*(p)).y = 9;'));
  });

  test('golden: associated functions on types (Type.func)', () async {
    final result = await compileAndRun('test/assoc_fn.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/assoc_fn.out').readAsString());

    final program = loadProject('test/assoc_fn.kl');
    Checker().check(program);
    final c = emitC(program, 'test/assoc_fn.kl');
    // Associated functions emit as plain C functions with no receiver arg,
    // mangled `Type_func`.
    expect(c, contains('Color_from_name(const char* s)'));
    expect(c, contains('Point_new(int32_t x, int32_t y)'));
    expect(c, contains('Point_new(3, 4)'));
    expect(c, contains('str_eq('));
  });

  test('imported associated function via mod.Type.func (Type.func)', () async {
    final dir = Directory.systemTemp.createTempSync('klin_impassoc079_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/geom.kl').writeAsStringSync('''
module geom
pub struct Point { x, y: i32 }
pub fn Point.origin(): Point { return Point{ x: 0, y: 0 } }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  let p: geom.Point = geom.Point.origin()
  printf("%d\\n", p.x)
}
''');
    final result = await compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '0\n');

    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('geom_Point_origin'));
  });

  test('golden: number + character literals (issue 081)', () async {
    final result = await compileAndRun('test/number_literals.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
        result.stdout, await File('test/number_literals.out').readAsString());

    final source = File('test/number_literals.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/number_literals.kl');
    // Binary and octal literals emit as portable 0x (no `0b`/`0o`).
    expect(c, contains('uint32_t mask = 0xf0;'));
    expect(c, contains('uint32_t bit = 0x5;'));
    expect(c, contains('uint32_t perm = 0x1ed;')); // 0o755 == 493
    expect(c, isNot(contains('0b')));
    expect(c, isNot(contains('0o')));
    // Float exponents pass through; `0b100` array length becomes 4.
    expect(c, contains('double small = 1.5e-3;'));
    expect(c, contains('int32_t xs[4]'));
    expect(c, contains("uint8_t a = 'A';"));
    expect(c, contains("uint8_t nl = '\\n';"));
  });

  test('golden: slice, array, and mutable pointer', () async {
    final result = await compileAndRun('test/slice_sum.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/slice_sum.out').readAsString());

    final source = File('test/slice_sum.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/slice_sum.kl');
    expect(c, contains('klin_slice_i32'));
    expect(c, contains('int32_t buf[4] = { 10, 20, 30, 40 };'));
    expect(c, contains('(klin_slice_i32){ buf, 4 }'));
    expect(c, contains('xs.ptr[i]'));
    expect(c, contains('volatile uint32_t * p'));
    expect(c, contains('(volatile uint32_t *)(uintptr_t)'));
  });

  test('--emit-c writes C without compiling or running', () async {
    final source = File('${tmp.path}/emit_only.kl');
    await source.writeAsString('''
@[link("driver.a")]
fn main() {}
''');
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-c', source.path],
    );
    final cFile = File('out/emit_only.c');
    final linkFile = File('out/emit_only.link');
    addTearDown(() async {
      if (await cFile.exists()) await cFile.delete();
      if (await linkFile.exists()) await linkFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await cFile.exists(), isTrue);
    expect(await linkFile.readAsString(), 'driver.a\n');
  });

  test('--emit-c .link resolves existing @[link] paths to absolute', () async {
    final driver = File('${tmp.path}/usb_stub.c');
    await driver.writeAsString('void klin_usb_stub(void) {}\n');
    final source = File('${tmp.path}/emit_abs_link.kl');
    await source.writeAsString('''
@[link("usb_stub.c")]
fn main() {}
''');
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-c', source.path],
    );
    final cFile = File('out/emit_abs_link.c');
    final linkFile = File('out/emit_abs_link.link');
    addTearDown(() async {
      if (await cFile.exists()) await cFile.delete();
      if (await linkFile.exists()) await linkFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    final linkBody = await linkFile.readAsString();
    expect(linkBody.trim(), driver.absolute.path);
  });

  test('--emit-h writes header without compiling or running', () async {
    final source = File('${tmp.path}/emit_h_only.kl');
    await source.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 { return a + b }
fn main() {}
''');
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-h', source.path],
    );
    final hFile = File('out/emit_h_only.h');
    final cFile = File('out/emit_h_only.c');
    addTearDown(() async {
      if (await hFile.exists()) await hFile.delete();
      if (await cFile.exists()) await cFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await hFile.exists(), isTrue);
    expect(await cFile.exists(), isFalse);
    expect(await hFile.readAsString(), contains('int32_t klin_add'));
  });

  test('--emit-c --emit-h writes both artifacts', () async {
    final source = File('${tmp.path}/emit_both.kl');
    await source.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 { return a + b }
fn main() {}
''');
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-c', '--emit-h', source.path],
    );
    final hFile = File('out/emit_both.h');
    final cFile = File('out/emit_both.c');
    addTearDown(() async {
      if (await hFile.exists()) await hFile.delete();
      if (await cFile.exists()) await cFile.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await hFile.exists(), isTrue);
    expect(await cFile.exists(), isTrue);
  });

}
