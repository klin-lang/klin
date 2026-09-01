@Tags(['e2e'])
library;

import 'dart:io';

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/project.dart';
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

}
