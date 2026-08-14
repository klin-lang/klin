import 'dart:io';

import 'package:klin/ast.dart';
import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/fmt.dart';
import 'package:klin/lexer.dart';
import 'package:klin/link_args.dart';
import 'package:klin/parser.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/project.dart';
import 'package:klin/remote.dart';
import 'package:klin/token.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('golden: hello.kl prints expected output', () async {
    final result = await _compileAndRun('test/hello.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/hello.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: shared type annotation `a, b: T` (issue 068)', () async {
    final result = await _compileAndRun('test/shared_type.kl', tmp);
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

  test('error: shared-type params without a type (issue 068)', () {
    const source = '''
fn add(a, b): i32 { return a }
fn main() {}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(predicate((e) =>
          e is ParseError && e.toString().contains('after parameter name'))),
    );
  });

  test('error: shared-type struct fields without a type (issue 068)', () {
    const source = '''
struct P { x, y }
fn main() {}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(predicate((e) =>
          e is ParseError && e.toString().contains('after field name'))),
    );
  });

  test('golden: !T propagates errors and or handles them', () async {
    final result = await _compileAndRun('test/result_chain.kl', tmp);
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
    final result = await _compileAndRun('test/destruct_struct.kl', tmp);
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

  test('error: destructuring a non-struct value (issue 056)', () {
    const source = '''
fn main() {
  let n = 5
  let { x } = n
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError && e.toString().contains('requires a struct')),
      ),
    );
  });

  test('error: destructuring an unknown field (issue 056)', () {
    const source = '''
struct P { x: i32
 y: i32 }
fn main() {
  let p = P{ x: 1, y: 2 }
  let { z } = p
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
            (e) => e is CheckError && e.toString().contains('has no field `z`')),
      ),
    );
  });

  test('error: destructuring a fixed-array field is rejected (issue 056)', () {
    const source = '''
struct Box { data: [3]i32
 n: i32 }
fn main() {
  let b = Box{ data: [1, 2, 3], n: 3 }
  let { data, n } = b
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('cannot destructure array field')),
      ),
    );
  });

  test('error: duplicate name in destructuring pattern (issue 056)', () {
    const source = '''
struct P { x: i32
 y: i32 }
fn main() {
  let p = P{ x: 1, y: 2 }
  let { x, x } = p
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) => e is ParseError && e.toString().contains('duplicate')),
      ),
    );
  });

  test('error: destructuring `let` requires `=` (issue 056)', () {
    const source = '''
struct P { x: i32
 y: i32 }
fn main() {
  let p = P{ x: 1, y: 2 }
  let { x } p
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(isA<ParseError>()),
    );
  });

  test('golden: fixed-array destructuring `let [ ]` (issue 056)', () async {
    final result = await _compileAndRun('test/destruct_array.kl', tmp);
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

  test('error: array destructuring length mismatch (issue 056)', () {
    const source = '''
fn main() {
  let xs: [3]i32 = [1, 2, 3]
  let [a, b] = xs
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError && e.toString().contains('but the pattern binds')),
      ),
    );
  });

  test('error: array destructuring rejects a slice (issue 056)', () {
    const source = '''
fn main() {
  let buf: [3]i32 = [1, 2, 3]
  let s = buf[:]
  let [a, b, c] = s
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('requires a fixed-length array')),
      ),
    );
  });

  test('error: array destructuring rejects a non-array source (issue 056)', () {
    const source = '''
fn make(): i32 { return 1 }
fn main() {
  let [a, b] = make()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('array variable or literal')),
      ),
    );
  });

  test('golden: destructuring rename and `_` skip (issue 056 phase D)',
      () async {
    final result = await _compileAndRun('test/destruct_phase_d.kl', tmp);
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

  test('error: duplicate renamed binding in struct pattern (issue 056)', () {
    const source = '''
struct P { x: i32
 y: i32 }
fn main() {
  let p = P{ x: 1, y: 2 }
  let { x: a, y: a } = p
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) =>
            e is ParseError && e.toString().contains('duplicate name `a`')),
      ),
    );
  });

  test('error: array pattern that binds nothing (all `_`) (issue 056)', () {
    const source = '''
fn main() {
  let xs: [2]i32 = [1, 2]
  let [_, _] = xs
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) => e is ParseError && e.toString().contains('binds nothing')),
      ),
    );
  });

  test('golden: multi-assignment swap (issue 056 phase B)', () async {
    final result = await _compileAndRun('test/multi_assign.kl', tmp);
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

  test('error: multi-assignment count mismatch (issue 056)', () {
    const source = '''
fn main() {
  let mut a: i32 = 1
  let mut b: i32 = 2
  a, b = 1
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) =>
            e is ParseError && e.toString().contains('2 targets but 1 values')),
      ),
    );
  });

  test('error: multi-assignment to an immutable target (issue 056)', () {
    const source = '''
fn main() {
  let a: i32 = 1
  let mut b: i32 = 2
  a, b = b, a
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError && e.toString().contains('immutable variable `a`')),
      ),
    );
  });

  test('error: multi-assignment rejects `or`/`!`/`match` values (issue 056)',
      () {
    const source = '''
fn fallible(): !i32 { return error(1) }
fn main() {
  let mut a: i32 = 1
  let mut b: i32 = 2
  a, b = fallible()!, 3
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('must be plain expressions')),
      ),
    );
  });

  test('golden: bare struct assignment `{ } =` (issue 056 phase A\')', () async {
    final result = await _compileAndRun('test/struct_assign.kl', tmp);
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
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '2\n');
  });

  test("error: bare struct assign to an immutable target (issue 056)", () {
    const source = '''
struct P { x: i32
 y: i32 }
fn main() {
  let x: i32 = 0
  let mut y: i32 = 0
  let p = P{ x: 1, y: 2 }
  { x, y } = p
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError && e.toString().contains('immutable variable `x`')),
      ),
    );
  });

  test("error: bare struct assign rename to a non-place (issue 056)", () {
    const source = '''
struct P { x: i32
 y: i32 }
fn main() {
  let p = P{ x: 1, y: 2 }
  { x: 5 } = p
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) =>
            e is ParseError && e.toString().contains('must be assignable')),
      ),
    );
  });

  test('error: unhandled !T result', () {
    const source = '''
fn fallible(): !i32 { return error(1) }
fn main() {
  fallible()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('must be handled'),
        ),
      ),
    );
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
    final result = await _compileAndRun(file.path, tmp);
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
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '8\n3\n');
  });

  test('different !*T types emit separate result typedefs', () {
    const source = '''
fn a(): !*i32 { return error(1) }
fn b(): !*f64 { return error(2) }
fn main() {
  let x = a() or { cast(*i32, 0) }
  let y = b() or { cast(*f64, 0) }
  printf("%p %p\\n", x, y)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'ptr_results.kl');
    expect(c, contains('} klin_res_ptr_i32;'));
    expect(c, contains('} klin_res_ptr_f64;'));
    expect(c, isNot(contains('} klin_res_ptr;')));
  });

  test('golden: emitted C is readable and contains #line', () {
    final source = File('test/hello.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/hello.kl');

    expect(c, contains('#include <stdio.h>'));
    expect(c, contains('int main(void) {'));
    expect(c, contains('puts("hello");'));
    expect(c, contains('puts("from Klin");'));
    expect(c, contains('return 0;'));
    expect(c, contains('#line '));
    expect(c, contains('test/hello.kl'));
  });

  test('golden: vars.kl — arithmetic, mut, range', () async {
    final result = await _compileAndRun('test/vars.kl', tmp);
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
    final result = await _compileAndRun('test/logical.kl', tmp);
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

  test('lexer: logical tokens && || (issue 097)', () {
    final tokens = Lexer('a&&b||c&d|e').tokenize();
    expect(
      tokens.map((t) => t.kind).toList(),
      [
        TokenKind.ident,
        TokenKind.ampAmp,
        TokenKind.ident,
        TokenKind.pipePipe,
        TokenKind.ident,
        TokenKind.ampersand,
        TokenKind.ident,
        TokenKind.pipe,
        TokenKind.ident,
        TokenKind.eof,
      ],
    );
  });

  test('error: logical op rejects int (issue 097)', () {
    const source = 'fn main() { let x = 1 && true }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('requires type `bool`'))),
    );
  });

  test('klin fmt: logical operators (issue 097)', () {
    const ugly = 'fn main(){let x=true&&false||!true}';
    final once = formatSource(ugly);
    expect(once, contains('true && false || !true'));
    expect(formatSource(once), once);
  });

  test('golden: bitwise ops | & ^ ~ << >> (issue 078)', () async {
    final result = await _compileAndRun('test/bitwise.kl', tmp);
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

  test('lexer: bitwise tokens << >> | ^ ~ and compounds (issue 078)', () {
    final tokens = Lexer('a<<b>>c|d^e~f&g a&=b|=c^=d<<=e>>=f').tokenize();
    expect(
      tokens.map((t) => t.kind).toList(),
      [
        TokenKind.ident,
        TokenKind.lessLess,
        TokenKind.ident,
        TokenKind.greaterGreater,
        TokenKind.ident,
        TokenKind.pipe,
        TokenKind.ident,
        TokenKind.caret,
        TokenKind.ident,
        TokenKind.tilde,
        TokenKind.ident,
        TokenKind.ampersand,
        TokenKind.ident,
        TokenKind.ident,
        TokenKind.ampEqual,
        TokenKind.ident,
        TokenKind.pipeEqual,
        TokenKind.ident,
        TokenKind.caretEqual,
        TokenKind.ident,
        TokenKind.lessLessEqual,
        TokenKind.ident,
        TokenKind.greaterGreaterEqual,
        TokenKind.ident,
        TokenKind.eof,
      ],
    );
  });

  test('error: bitwise op rejects float (issue 078)', () {
    const source = 'fn main() { let x = 1.5 & 2.0 }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('requires integer'))),
    );
  });

  test('error: bitwise not rejects bool (issue 078)', () {
    const source = 'fn main() { let x = ~true }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('requires an integer'))),
    );
  });

  test('klin fmt: bitwise operators (issue 078)', () {
    const ugly = 'fn main(){let x=1<<2|3&4^~5\nlet mut y=0\ny|=1\ny<<=2}';
    final once = formatSource(ugly);
    expect(once, contains('1 << 2 | 3 & 4 ^ ~5'));
    expect(once, contains('y |= 1'));
    expect(once, contains('y <<= 2'));
    expect(formatSource(once), once);
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
    final result = await _compileAndRun('${dir.path}/app.kl', dir);
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

  test('lexer: arithmetic compound assign tokens', () {
    final tokens = Lexer('a+=b-=c*=d/=e%=f').tokenize();
    expect(
      tokens.map((t) => t.kind).toList(),
      [
        TokenKind.ident,
        TokenKind.plusEqual,
        TokenKind.ident,
        TokenKind.minusEqual,
        TokenKind.ident,
        TokenKind.starEqual,
        TokenKind.ident,
        TokenKind.slashEqual,
        TokenKind.ident,
        TokenKind.percentEqual,
        TokenKind.ident,
        TokenKind.eof,
      ],
    );
  });

  test('error: %= rejects float', () {
    const source = 'fn main() { let mut x: f64 = 1.0\n x %= 2.0 }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('requires integer'))),
    );
  });

  test('golden: short_decl.kl — := sugar for let mut (issue 055)', () async {
    final result = await _compileAndRun('test/short_decl.kl', tmp);
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

  test('klin fmt: preserves := short decl (issue 055)', () {
    final ugly = File('test/fmt_short_decl.kl').readAsStringSync();
    final expected = File('test/fmt_short_decl.fmt.kl').readAsStringSync();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);
  });

  test('error: := without initializer', () {
    expect(
      () => Parser(Lexer('fn main() { x := }').tokenize()).parse(),
      throwsA(isA<ParseError>()),
    );
  });

  test('golden: if/while/for bare-name condition (issue 064)', () async {
    final result = await _compileAndRun('test/if_cond_bare_name.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      await File('test/if_cond_bare_name.out').readAsString(),
    );
  });

  test('golden: struct literal in if-condition needs parens (issue 064)',
      () async {
    final result = await _compileAndRun('test/if_cond_struct_paren.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(
      result.stdout,
      await File('test/if_cond_struct_paren.out').readAsString(),
    );
  });

  test('golden: match statement lowers to if/else chains (issue 014)',
      () async {
    final result = await _compileAndRun('test/match_stmt.kl', tmp);
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
    final result = await _compileAndRun('test/match_expr.kl', tmp);
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

  test('match statement calling only puts still includes <stdio.h>', () {
    const source = '''
fn main() {
  match 1 {
    1 { puts("one") }
    else { puts("other") }
  }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'match_stdio.kl');
    expect(c, contains('#include <stdio.h>'));
  });

  test('klin fmt: formats match arms (issue 014)', () {
    final ugly = File('test/fmt_match.kl').readAsStringSync();
    final expected = File('test/fmt_match.fmt.kl').readAsStringSync();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);
  });

  test('golden: match when guards (issue 084)', () async {
    final result = await _compileAndRun('test/match_when.kl', tmp);
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
    final result = await _compileAndRun('test/match_rel.kl', tmp);
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

  test('error: bare match wildcard requires when (issue 084)', () {
    expect(
      () => Parser(Lexer('fn main() { match 1 { _ { puts("x") } } }').tokenize())
          .parse(),
      throwsA(
        predicate((e) =>
            e is ParseError &&
            e.toString().contains('requires a `when`') &&
            e.toString().contains('else')),
      ),
    );
  });

  test('error: else cannot have when guard (issue 084)', () {
    expect(
      () => Parser(Lexer(
              'fn main() { match 1 { else when 1 != 0 { puts("x") } } }')
          .tokenize())
          .parse(),
      throwsA(
        predicate((e) =>
            e is ParseError && e.toString().contains('cannot have a `when`')),
      ),
    );
  });

  test('error: when guard must be bool (issue 084)', () {
    const source = '''
fn main() {
  match 1 {
    1 when 2 { puts("x") }
    else { puts("y") }
  }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError && e.toString().contains('condition requires type `bool`')),
      ),
    );
  });

  test('error: relational pattern not allowed for enum (issue 084)', () {
    const source = '''
enum Color { Red, Green, Blue }
fn main() {
  let c: Color = Color.Red
  match c {
    > Color.Red { puts("x") }
    else { puts("y") }
  }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('relational patterns'))),
    );
  });

  test('klin fmt: formats enum declarations (issue 072)', () {
    const ugly =
        'enum Color{Red,Green,Blue}\nenum Status : u8 { Ok , Warn = 5 , Err }\nfn main(){}';
    final once = formatSource(ugly);
    expect(once, contains('enum Color {\n    Red\n    Green\n    Blue\n}'));
    expect(once, contains('enum Status: u8 {\n    Ok\n    Warn = 5\n    Err\n}'));
    expect(formatSource(once), once);
  });

  test('error: match else arm must come last', () {
    final source = File('test/match_else_order.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('3:') &&
              msg.contains('else') &&
              msg.contains('last arm');
        }),
      ),
    );
  });

  test('error: match requires an integer subject', () {
    const source = 'fn main() { match 1.5 { 1 { puts("a") } } }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('integer or enum subject'),
        ),
      ),
    );
  });

  test('golden: enums — base type, methods, match, cast (issue 072)', () async {
    final result = await _compileAndRun('test/enum_basic.kl', tmp);
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

  test('golden: enum as array index (issue 126)', () async {
    final result = await _compileAndRun('test/enum_index.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/enum_index.out').readAsString());

    final source = File('test/enum_index.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'test/enum_index.kl');
    expect(c, contains('codes[s]'));
    expect(c, contains('codes[Slot_B]'));
  });

  test('error: enum index does not fit the array (issue 126)', () {
    const source = '''
enum Slot { A, B = 5 }
fn main() {
  let codes: [3]i32 = [1, 2, 3]
  printf("%d\\n", codes[Slot.A])
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('does not fit') &&
          e.toString().contains('B'))),
    );
  });

  test('error: enum index requires a fixed array (issue 126)', () {
    const source = '''
enum Slot { A, B }
fn main() {
  let codes: [2]i32 = [1, 2]
  let xs = codes[:]
  printf("%d\\n", xs[Slot.A])
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('fixed array'))),
    );
  });

  test('error: enum base type must be an integer (issue 072)', () {
    const source = 'enum E: f64 { A, B }\nfn main() {}';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
          (e) => e is CheckError && e.toString().contains('base type'))),
    );
  });

  test('error: unknown enum variant (issue 072)', () {
    const source = '''
enum Color { Red, Green }
fn main() {
  let c: Color = Color.Blue
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
          (e) => e is CheckError && e.toString().contains('no variant'))),
    );
  });

  test('error: cannot compare two different enums (issue 072)', () {
    const source = '''
enum A { X }
enum B { Y }
fn main() {
  let a: A = A.X
  let b: B = B.Y
  if a == b {
    puts("no")
  }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
          (e) => e is CheckError && e.toString().contains('cannot compare'))),
    );
  });

  test('error: range pattern is not allowed for an enum (issue 072)', () {
    const source = '''
enum Color { Red, Green, Blue }
fn main() {
  let c: Color = Color.Red
  match c {
    Color.Red ..= Color.Blue { puts("x") }
    else { puts("y") }
  }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('range patterns'))),
    );
  });

  test('error: duplicate enum variant (issue 072)', () {
    const source = 'enum E { A, A }\nfn main() {}';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('duplicate enum variant'))),
    );
  });

  test('error: enum name collides with a struct (issue 072)', () {
    const source = 'struct T { x: i32 }\nenum T { A }\nfn main() {}';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('redeclaration of type'))),
    );
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
    final result = await _compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '1\n');

    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('colors_Color_Green'));
  });

  test('error: match expression requires an else arm', () {
    const source = 'fn main() { let a = match 1 { 1 { 2 } } }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('requires an `else`'),
        ),
      ),
    );
  });

  test('error: match expression only in let/assign position', () {
    const source =
        'fn main() { printf("%d\\n", match 1 { 1 { 2 } else { 3 } }) }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('only allowed as a `let` initializer'),
        ),
      ),
    );
  });

  test('error: match expression cannot nest under let arithmetic', () {
    const source = 'fn main() { let a = 1 + match 1 { else { 2 } } }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('only allowed as a `let` initializer'),
        ),
      ),
    );
  });

  test('error: match expression cannot nest in let call argument', () {
    const source =
        'fn main() { let a = printf("%d\\n", match 1 { 1 { 2 } else { 3 } }) }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('only allowed as a `let` initializer'),
        ),
      ),
    );
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
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '2\n');
  });

  test('error: match requires at least one arm', () {
    expect(
      () => Parser(Lexer('fn main() { match 1 { } }').tokenize()).parse(),
      throwsA(isA<ParseError>()),
    );
  });

  test('golden: pick expression emits C ternary (issue 085)', () async {
    final result = await _compileAndRun('test/pick_expr.kl', tmp);
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

  test('klin fmt: formats pick expression (issue 085)', () {
    final ugly = File('test/fmt_pick.kl').readAsStringSync();
    final expected = File('test/fmt_pick.fmt.kl').readAsStringSync();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);
  });

  test('error: pick condition must be bool (issue 085)', () {
    const source = 'fn main() { let a = pick 1 { 2 } { 3 } }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('condition requires type `bool`')),
      ),
    );
  });

  test('error: pick arms must share a type (issue 085)', () {
    const source = 'fn main() { let a = pick true { true } { 1 } }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError && e.toString().contains('type mismatch')),
      ),
    );
  });

  test('error: pick arm cannot contain match (issue 085)', () {
    const source = '''
fn main() {
  let a = pick true { match 1 { 1 { 2 } else { 3 } } } { 0 }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('cannot contain `match`')),
      ),
    );
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
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '42\n');
  });

  test('golden: int/float aliases emit fixed-width C types', () async {
    final result = await _compileAndRun('test/int_float_aliases.kl', tmp);
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

  test('error: C keyword cannot be a variable name', () {
    const source = '''
fn main() {
  let int = 1
}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate(
          (e) =>
              e is ParseError &&
              e.toString().contains('a C keyword') &&
              e.toString().contains('variable name'),
        ),
      ),
    );
  });

  test('golden: stdlib io.print / io.println', () async {
    final result = await _compileAndRun('test/io_println.kl', tmp);
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
    final result = await _compileAndRun('test/str_eq.kl', tmp);
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
    final result = await _compileAndRun('test/math_basic.kl', tmp);
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
    expect(collectLinkAttrs(program), contains('-lm'));
  });

  test('golden: string interpolation → printf (issue 016)', () async {
    final result = await _compileAndRun('test/interp.kl', tmp);
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

  test('golden: stdlib time Instant/Duration/format (issue 037)', () async {
    final result = await _compileAndRun('test/time_basic.kl', tmp);
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
    final result = await _compileAndRun('test/time_calendar.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/time_calendar.out').readAsString());

    final program = loadProject('test/time_calendar.kl');
    Checker().check(program);
    final c = emitC(program, 'test/time_calendar.kl');
    expect(c, contains('klin_time_add_date'));
    expect(c, isNot(contains('malloc')));
  });

  test('golden: function pointers without capture (issue 017 phase 2)', () async {
    final result = await _compileAndRun('test/fn_ptr.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/fn_ptr.out').readAsString());

    final program = loadProject('test/fn_ptr.kl');
    Checker().check(program);
    final c = emitC(program, 'test/fn_ptr.kl');
    expect(c, contains('(*'));
    expect(c, isNot(contains('malloc')));
  });

  test('golden: stdlib mem Allocator heap alloc/free (issue 057)', () async {
    final result = await _compileAndRun('test/mem_alloc.kl', tmp);
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
    final result = await _compileAndRun('test/slice_ops.kl', tmp);
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
    final result = await _compileAndRun('test/slice_alloc_ops.kl', tmp);
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

  test('nested fn types emit typedefs leaves-first', () {
    final file = File('${Directory.systemTemp.path}/klin_nested_fn.kl');
    file.writeAsStringSync(r'''
fn id(x: i32): i32 {
    return x
}

fn choose(): fn(i32): i32 {
    return id
}

fn main() {
    let f = choose()
    printf("%d\n", f(7))
}
''');
    final program = loadProject(file.path);
    Checker().check(program);
    final c = emitC(program, file.path);
    // Inner fn(i32):i32 typedef must appear before any that mention it as return.
    final innerName = 'klin_fn_i32__i32';
    final outerRet = c.indexOf('(*klin_fn_void_');
    expect(c.indexOf(innerName), lessThan(outerRet == -1 ? c.length : outerRet));
    expect(c, contains(innerName));
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
    final result = await _compileAndRun(file.path, tmp);
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
    final result = await _compileAndRun(file.path, tmp);
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
    final result = await _compileAndRun(file.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, contains('n=-1'));
  });

  test('error: interpolated string in let is print-only', () {
    final source = r'''
fn main() {
    let b: str = "x"
    let s = "a $b"
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError && e.toString().contains('print-only'),
        ),
      ),
    );
  });

  test('error: interpolated printf rejects extra args', () {
    final source = r'''
fn main() {
    let n = 1
    printf("${n:%d}", n)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError && e.toString().contains('sole argument'),
        ),
      ),
    );
  });

  test('error: unknown interpolation mask n3', () {
    final source = r'''
fn main() {
    let n = 1
    puts("${n:n3}")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError && e.toString().contains('unknown format'),
        ),
      ),
    );
  });

  test('error: sN format requires str', () {
    final source = r'''
fn main() {
    let n = 1
    puts("${n:s8}")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('requires `str`'),
        ),
      ),
    );
  });

  test('error: fraction mask requires numeric type', () {
    final source = r'''
fn main() {
    let s: str = "x"
    puts("${s:0.00}")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('requires a numeric type'),
        ),
      ),
    );
  });

  test('fmt preserves interpolation syntax', () {
    final source = r'''
fn main() {
puts("hi $name ${n:%d} ${x:0.00} ${t:s8}")
}
''';
    final formatted = formatSource(source);
    expect(formatted, contains(r'$name'));
    expect(formatted, contains(r'${n:%d}'));
    expect(formatted, contains(r'${x:0.00}'));
    expect(formatted, contains(r'${t:s8}'));
  });

  test(r'golden: $fn macro expands to a specialized struct (issue 026)',
      () async {
    final result = await _compileAndRun('test/point_macro.kl', tmp);
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

  test('error: unknown macro reports call site and file path', () {
    expect(
      () => preprocess(r'$missing(i32)', path: 'mod/t.kl'),
      throwsA(
        predicate(
          (e) =>
              e is PreprocessError &&
              e.toString().contains('mod/t.kl:') &&
              e.toString().contains('unknown macro') &&
              e.toString().contains(r'$missing'),
        ),
      ),
    );
  });

  test(r'$fn block param + integer args (rtos_task shape)', () {
    final expanded = preprocess(r'''
$fn rtos_task(name: name, stack: name, prio: name, body: block) {
@[codename("task_$name")]
fn task_$name(arg: *mut void) {
$body
}
fn start_$name() {
  let n: i32 = $stack
  let p: i32 = $prio
}
}
$rtos_task(blink, 512, 2) {
  let x: i32 = 1
}
fn main() {}
''', path: 'mod/rtos_shape.kl');
    expect(expanded, contains('@[codename("task_blink")]'));
    expect(expanded, contains('fn task_blink(arg: *mut void)'));
    expect(expanded, contains('let x: i32 = 1'));
    expect(expanded, contains('fn start_blink()'));
    expect(expanded, contains('let n: i32 = 512'));
    expect(expanded, contains('let p: i32 = 2'));
    expect(expanded, isNot(contains(r'$rtos_task')));
  });

  test(r'macros from path import + $mod qualifier (059 A1 lite)', () {
    final dir = Directory.systemTemp.createTempSync('klin_macro_import_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pkg = Directory('${dir.path}/mylib')..createSync();
    File('${pkg.path}/macros.kl').writeAsStringSync(r'''
module mylib
$fn greet(name: name, body: block) {
fn hello_$name() {
  $mod.ping()
$body
}
}
pub fn ping() {}
''');
    File('${dir.path}/app.kl').writeAsStringSync(r'''
import "mylib" lib
$greet(world) {
  let z: i32 = 0
}
fn main() {
  hello_world()
}
''');
    final expanded = preprocess(
      File('${dir.path}/app.kl').readAsStringSync(),
      path: '${dir.path}/app.kl',
    );
    expect(expanded, contains('fn hello_world()'));
    expect(expanded, contains('lib.ping()'));
    expect(expanded, contains('let z: i32 = 0'));
    expect(expanded, isNot(contains(r'$mod')));
  });

  test(r'nested macros: block body may invoke another $fn (rtos+event_loop)',
      () {
    final expanded = preprocess(r'''
$fn event_loop(ex: name, body: block) {
let mut $ex: Executor
$body
run(&$ex)
}
$fn rtos_task(name: name, body: block) {
fn task_$name() {
$body
}
}
$rtos_task(net) {
  $event_loop(ex) {
    every_ms(&ex)
  }
}
fn main() {}
''', path: 'mod/nested_macros.kl');
    expect(expanded, contains('fn task_net()'));
    expect(expanded, contains('let mut ex: Executor'));
    expect(expanded, contains('every_ms(&ex)'));
    expect(expanded, contains('run(&ex)'));
    expect(expanded, isNot(contains(r'$rtos_task')));
    expect(expanded, isNot(contains(r'$event_loop')));
  });

  test('klin fmt: ugly source matches golden and is idempotent (issue 033)',
      () async {
    final ugly = await File('test/fmt_ugly.kl').readAsString();
    final expected = await File('test/fmt_ugly.fmt.kl').readAsString();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);

    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'fmt', 'test/fmt_ugly.kl'],
    );
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout, expected);

    for (final path in [
      'examples/hello.kl',
      'examples/vec2.kl',
      'examples/point.kl',
      'examples/slice_sum.kl',
      'examples/modules/app.kl',
    ]) {
      final src = File(path).readAsStringSync();
      final formatted = formatSource(src);
      expect(formatSource(formatted), formatted, reason: path);
    }
    expect(
      formatSource(File('examples/slice_sum.kl').readAsStringSync()),
      contains('[10, 20, 30, 40]'),
    );
  });

  test(r'$ in macro strings/comments is not an unsubstituted slot', () {
    final expanded = preprocess(r'''
$fn note(T: type) {
fn f(): $T {
  // keep $hint
  puts("$USD")
  return 0
}
}
$note(i32)
''', path: 't.kl');
    expect(expanded, contains(r'// keep $hint'));
    expect(expanded, contains(r'puts("$USD")'));
    expect(expanded, contains('fn f(): i32'));
  });

  test(r'$peripherals_from_svd rewrites fluent MMIO (issue 027)', () {
    final dir = Directory('${tmp.path}/svd_fluent')..createSync();
    File('${dir.path}/tiny.svd').writeAsStringSync('''
<device><peripherals>
  <peripheral><name>RCC</name><baseAddress>0x40023800</baseAddress><registers>
    <register><name>AHB1ENR</name><addressOffset>0x30</addressOffset><fields>
      <field><name>GPIOAEN</name><bitOffset>0</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
  <peripheral><name>GPIOA</name><baseAddress>0x40020000</baseAddress><registers>
    <register><name>MODER</name><addressOffset>0</addressOffset><fields>
      <field><name>MODER5</name><bitOffset>10</bitOffset><bitWidth>2</bitWidth>
        <enumeratedValues><enumeratedValue><name>Output</name><value>1</value></enumeratedValue></enumeratedValues>
      </field>
    </fields></register>
    <register><name>ODR</name><addressOffset>0x14</addressOffset><fields>
      <field><name>ODR5</name><bitOffset>5</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
</peripherals></device>
''');
    final klPath = '${dir.path}/blinky.kl';
    File(klPath).writeAsStringSync(r'''
$peripherals_from_svd("tiny.svd", "RCC,GPIOA")
fn main() {
  RCC.AHB1ENR.GPIOAEN.set(1)
  GPIOA.MODER.MODER5.write(.Output)
  GPIOA.ODR.ODR5.toggle()
}
''');
    final expanded = preprocess(
      File(klPath).readAsStringSync(),
      path: klPath,
    );
    expect(expanded, contains('@[cinclude("tiny_regs.h")]'));
    expect(
      expanded,
      contains('@[cimport, cheader, codename("GPIOA_ODR_ODR5_toggle")]'),
    );
    expect(expanded, contains('RCC_AHB1ENR_GPIOAEN_set(1)'));
    expect(expanded, contains('GPIOA_MODER_MODER5_write(1)'));
    expect(expanded, contains('GPIOA_ODR_ODR5_toggle()'));
    expect(expanded, isNot(contains('RCC.AHB1ENR')));
    expect(File('${dir.path}/tiny_regs.h').existsSync(), isTrue);

    expect(
      () => preprocess(
        r'''
$peripherals_from_svd("tiny.svd", "RCC,GPIOA")
fn main() { GPIOA.ODR.ODR5.toggle(1) }
''',
        path: klPath,
      ),
      throwsA(
        predicate(
          (e) =>
              e is PreprocessError && e.toString().contains('takes no arguments'),
        ),
      ),
    );
  });

  test('--emit-pp writes expanded Klin source', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-pp', 'test/point_macro.kl'],
    );
    final pp = File('out/point_macro.pp.kl');
    addTearDown(() async {
      if (await pp.exists()) await pp.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await pp.exists(), isTrue);
    final text = await pp.readAsString();
    expect(text, contains('struct Vec2i'));
    expect(text, isNot(contains(r'$point')));
  });

  test('syntax error: message includes line number', () async {
    final source = await File('test/bad_syntax.kl').readAsString();
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) {
          final msg = e.toString();
          // `42` is on line 3, where the lexer reports the position.
          return msg.contains('3:') && (e is LexError || e is ParseError);
        }),
      ),
    );
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

  test('error: frontend catches a C keyword call, not gcc', () {
    final source = File('test/c_keyword_call.kl').readAsStringSync();
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(
        predicate((e) {
          if (e is! ParseError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('a C keyword') &&
              msg.contains('typedef');
        }),
      ),
    );
  });

  test('type error: mismatch includes position', () {
    final source = File('test/type_mismatch.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('type mismatch') &&
              msg.contains('i32') &&
              msg.contains('bool');
        }),
      ),
    );
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

  test('error: mutating let without mut', () {
    final source = File('test/immutable_assign.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('3:') &&
              msg.contains('immutable variable') &&
              msg.contains('x');
        }),
      ),
    );
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
    final result = await _compileAndRun('test/fizzbuzz.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/fizzbuzz.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: break_continue.kl — while + C-style for', () async {
    final result = await _compileAndRun('test/break_continue.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/break_continue.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: defer — LIFO order', () async {
    final result = await _compileAndRun('test/defer_order.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_order.out').readAsString());
  });

  test('golden: defer before break is block-scoped', () async {
    final result = await _compileAndRun('test/defer_break.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_break.out').readAsString());
  });

  test('golden: defer before continue is block-scoped', () async {
    final result = await _compileAndRun('test/defer_continue.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_continue.out').readAsString());
  });

  test('golden: defer before return preserves value', () async {
    final result = await _compileAndRun('test/defer_return.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/defer_return.out').readAsString());
  });

  test('error: defer inside defer', () {
    const source = '''
fn main() {
  defer defer puts("nested")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('inside `defer`'),
        ),
      ),
    );
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
    final result = await _compileAndRun(kl.path, dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'body\na\n');
  });

  test('golden: function called before definition', () async {
    final result = await _compileAndRun('test/call_before_def.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/call_before_def.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: recursive fib', () async {
    final result = await _compileAndRun('test/fib.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    final expected = await File('test/fib.out').readAsString();
    expect(result.stdout, expected);
  });

  test('golden: Vec2 — structs, fields, and methods', () async {
    final result = await _compileAndRun('test/vec2.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/vec2.out').readAsString());

    final program = loadProject('test/vec2.kl');
    Checker().check(program);
    final c = emitC(program, 'test/vec2.kl');
    expect(c, contains('vec2_Vec2_translate(vec2_Vec2 *v'));
    expect(c, isNot(contains('mut')));
  });

  test('golden: project with modules', () async {
    final result = await _compileAndRun('test/modules/app.kl', tmp);
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

  test('error: private symbol from imported module', () {
    final program = loadProject('test/modules/private_app.kl');
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('is private'),
        ),
      ),
    );
  });

  test('error: unqualified call to another module function is not FFI', () {
    final dir = Directory.systemTemp.createTempSync('klin_mod_bare_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/lib.kl').writeAsStringSync('''
module lib
fn secret(): i32 { return 1 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import lib
fn main() {
  secret()
}
''');
    final program = loadProject('${dir.path}/app.kl');
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('is in module') &&
              e.toString().contains('lib.secret'),
        ),
      ),
    );
  });

  test('import alias maps to the file module declaration', () {
    final dir = Directory.systemTemp.createTempSync('klin_mod_alias_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/file_a.kl').writeAsStringSync('''
module real
pub fn answer(): i32 { return 42 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import file_a
fn main() {
  printf("%d\\n", file_a.answer())
}
''');
    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('real_answer'));
    expect(c, isNot(contains('file_a_answer')));
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
    final result = await _compileAndRun('${dir.path}/app.kl', dir);
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
    final result = await _compileAndRun('${dir.path}/app.kl', dir);
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
    final result = await _compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '9\n');
  });

  test('remote import from preseeded cache (issue 049)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_cache049_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final pkg = Directory(
      '${cache.path}/pkg/github/klin-lang/osa',
    )..createSync(recursive: true);
    File('${pkg.path}/version.kl').writeAsStringSync('''
module osa
pub fn version(): i32 { return 1 }
''');
    File('${pkg.path}/math.kl').writeAsStringSync('''
module osa
pub fn add(a: i32, b: i32): i32 { return a + b }
pub fn clamp(v: i32, lo: i32, hi: i32): i32 {
  if v < lo { return lo }
  if v > hi { return hi }
  return v
}
''');
    File('${pkg.path}/.pin').writeAsStringSync('v0.1.0\n');

    final result = await _compileAndRun(
      'test/remote_osa.kl',
      tmp,
      klinCacheDir: cache.path,
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/remote_osa.out').readAsString());
  });

  test('remote import missing cache suggests klin get (issue 049)', () {
    final cache = Directory.systemTemp.createTempSync('klin_nocache049_');
    addTearDown(() => cache.deleteSync(recursive: true));
    expect(
      () => loadProject(
        'test/remote_osa.kl',
        klinCacheDir: cache.path,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (e) => e.message,
          'message',
          contains('klin get'),
        ),
      ),
    );
  });

  test('remote import incomplete @[link] units suggests klin get', () {
    final cache = Directory.systemTemp.createTempSync('klin_incomplete_link_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final work = Directory.systemTemp.createTempSync('klin_incomplete_work_');
    addTearDown(() => work.deleteSync(recursive: true));
    final pkg = Directory('${cache.path}/pkg/github/klin-lang/linkpkg')
      ..createSync(recursive: true);
    File('${pkg.path}/usb.kl').writeAsStringSync('''
module usb
@[link("usb_cdc_rp.c")]
pub fn out() {}
''');
    File('${pkg.path}/.pin').writeAsStringSync('v0.1.0\n');
    File('${work.path}/app.kl').writeAsStringSync('''
import "github/klin-lang/linkpkg"
fn main() { usb.out() }
''');
    expect(
      () => loadProject(
        '${work.path}/app.kl',
        klinCacheDir: cache.path,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (e) => e.message,
          'message',
          allOf(contains('incomplete'), contains('klin get')),
        ),
      ),
    );
  });

  test('local github/ directory does not shadow remote import (issue 049)', () {
    final cache = Directory.systemTemp.createTempSync('klin_shadow049_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final work = Directory.systemTemp.createTempSync('klin_work049_');
    addTearDown(() => work.deleteSync(recursive: true));
    Directory('${work.path}/github/klin-lang/osa').createSync(recursive: true);
    File('${work.path}/github/klin-lang/osa/bogus.kl').writeAsStringSync('''
module osa
pub fn version(): i32 { return 99 }
''');
    File('${work.path}/app.kl').writeAsStringSync('''
import "github/klin-lang/osa"
fn main() { printf("%d\\n", osa.version()) }
''');
    expect(
      () => loadProject(
        '${work.path}/app.kl',
        klinCacheDir: cache.path,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (e) => e.message,
          'message',
          contains('klin get'),
        ),
      ),
    );
  });

  test('remote import alias `import "github/…" o` (issue 049)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_alias049_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final pkg = Directory(
      '${cache.path}/pkg/github/klin-lang/osa',
    )..createSync(recursive: true);
    File('${pkg.path}/lib.kl').writeAsStringSync('''
module osa
pub fn version(): i32 { return 1 }
''');
    final work = Directory.systemTemp.createTempSync('klin_aliasapp049_');
    addTearDown(() => work.deleteSync(recursive: true));
    File('${work.path}/app.kl').writeAsStringSync('''
import "github/klin-lang/osa" o
fn main() { printf("%d\\n", o.version()) }
''');
    final result = await _compileAndRun(
      '${work.path}/app.kl',
      tmp,
      klinCacheDir: cache.path,
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '1\n');
  });

  test('stdlibCandidatesForInstallRoot Homebrew layout (issue 067)', () {
    final sep = Platform.pathSeparator;
    final roots = ['/opt/homebrew/Cellar/klin/0.1.0', '/repo'];
    final paths = stdlibCandidatesForInstallRoot(roots).toList();
    expect(paths, contains('/opt/homebrew/Cellar/klin/0.1.0${sep}stdlib'));
    expect(
      paths,
      contains('/opt/homebrew/Cellar/klin/0.1.0${sep}share${sep}klin${sep}stdlib'),
    );
    expect(paths, contains('/repo${sep}stdlib'));
  });

  test('klin.mod parse/format round-trip (issue 049)', () {
    final mod = parseKlinMod('klin 1\nrequire github/klin-lang/osa v0.1.0\n');
    expect(mod.requires['github/klin-lang/osa'], 'v0.1.0');
    expect(formatKlinMod(mod), 'klin 1\nrequire github/klin-lang/osa v0.1.0\n');
  });

  test('klin.mod device + parseRemoteAsset (issue 053)', () {
    const devicePath =
        'github/tinygo-org/stm32-svd/svd/stm32f411.svd';
    final mod = parseKlinMod(
      'klin 1\n'
      'require github/klin-lang/osa v0.1.0\n'
      'device $devicePath main\n',
    );
    expect(mod.devices[devicePath], 'main');
    expect(
      formatKlinMod(mod),
      'klin 1\n'
      'require github/klin-lang/osa v0.1.0\n'
      'device $devicePath main\n',
    );

    final asset = parseRemoteAsset('$devicePath@main');
    expect(asset.host, 'github');
    expect(asset.owner, 'tinygo-org');
    expect(asset.repo, 'stm32-svd');
    expect(asset.filePath, 'svd/stm32f411.svd');
    expect(asset.path, devicePath);
    expect(asset.ref, 'main');
    expect(isRemoteDevicePath(devicePath), isTrue);
    expect(isRemoteDevicePath('github/klin-lang/osa'), isFalse);

    expect(
      () => parseRemoteAsset('github/acme/svd/chip.svd'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseRemoteAsset('github/tinygo-org/stm32-svd/../x.svd'),
      throwsA(isA<FormatException>()),
    );
  });

  test(r'$device alias + remote miss suggests klin get (issue 053)', () {
    final dir = Directory('${tmp.path}/svd_device_alias')..createSync();
    File('${dir.path}/tiny.svd').writeAsStringSync('''
<device><peripherals>
  <peripheral><name>RCC</name><baseAddress>0x40023800</baseAddress><registers>
    <register><name>AHB1ENR</name><addressOffset>0x30</addressOffset><fields>
      <field><name>GPIOAEN</name><bitOffset>0</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
</peripherals></device>
''');
    final klPath = '${dir.path}/dev.kl';
    File(klPath).writeAsStringSync(r'''
$device("tiny.svd", "RCC")
fn main() { RCC.AHB1ENR.GPIOAEN.set(1) }
''');
    final expanded = preprocess(
      File(klPath).readAsStringSync(),
      path: klPath,
    );
    expect(expanded, contains('RCC_AHB1ENR_GPIOAEN_set(1)'));

    final cache = Directory.systemTemp.createTempSync('klin_nocache053_');
    addTearDown(() => cache.deleteSync(recursive: true));
    expect(
      () => preprocess(
        r'''
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC")
fn main() {}
''',
        path: klPath,
        klinCacheDir: cache.path,
      ),
      throwsA(
        predicate(
          (e) =>
              e is PreprocessError && e.toString().contains('klin get'),
        ),
      ),
    );
  });

  test(r'$device prefers local github-shaped path (issue 053)', () {
    final dir = Directory('${tmp.path}/svd_local_github')..createSync();
    final vendored = Directory(
      '${dir.path}/github/tinygo-org/stm32-svd/svd',
    )..createSync(recursive: true);
    File('${vendored.path}/stm32f411.svd').writeAsStringSync('''
<device><peripherals>
  <peripheral><name>RCC</name><baseAddress>0x40023800</baseAddress><registers>
    <register><name>AHB1ENR</name><addressOffset>0x30</addressOffset><fields>
      <field><name>GPIOAEN</name><bitOffset>0</bitOffset><bitWidth>1</bitWidth></field>
    </fields></register>
  </registers></peripheral>
</peripherals></device>
''');
    final klPath = '${dir.path}/app.kl';
    File(klPath).writeAsStringSync(r'''
$device("github/tinygo-org/stm32-svd/svd/stm32f411.svd", "RCC")
fn main() { RCC.AHB1ENR.GPIOAEN.set(1) }
''');
    final cache = Directory.systemTemp.createTempSync('klin_local053_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final expanded = preprocess(
      File(klPath).readAsStringSync(),
      path: klPath,
      klinCacheDir: cache.path,
    );
    expect(expanded, contains('RCC_AHB1ENR_GPIOAEN_set(1)'));
    expect(
      Directory('${cache.path}/asset').existsSync(),
      isFalse,
      reason: 'vendored path must not require asset cache',
    );
  });

  test('klin.lock parse/format round-trip (issue 065)', () {
    const sha = '0123456789abcdef0123456789abcdef01234567';
    const hash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final lock = parseKlinLock(
      'klin lock 1\n'
      'github/klin-lang/osa v0.1.0 $sha sha256:$hash\n',
    );
    expect(lock.packages['github/klin-lang/osa']!.version, 'v0.1.0');
    expect(lock.packages['github/klin-lang/osa']!.commit, sha);
    expect(lock.packages['github/klin-lang/osa']!.hash, hash);
    expect(
      formatKlinLock(lock),
      'klin lock 1\n'
      'github/klin-lang/osa v0.1.0 $sha sha256:$hash\n',
    );
  });

  test('cacheSatisfiesRemoteFetch requires lock SHA match (issue 065)', () {
    const pin = 'v0.1.0';
    const sha = '0123456789abcdef0123456789abcdef01234567';
    expect(
      cacheSatisfiesRemoteFetch(
        cachedPin: pin,
        pinValue: pin,
        cachedCommit: sha,
        gitRef: pin,
      ),
      isTrue,
    );
    expect(
      cacheSatisfiesRemoteFetch(
        cachedPin: pin,
        pinValue: pin,
        cachedCommit: sha,
        gitRef: sha,
      ),
      isTrue,
    );
    expect(
      cacheSatisfiesRemoteFetch(
        cachedPin: pin,
        pinValue: pin,
        cachedCommit: sha,
        gitRef: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      isFalse,
    );
    expect(
      cacheSatisfiesRemoteFetch(
        cachedPin: pin,
        pinValue: pin,
        cachedCommit: null,
        gitRef: sha,
      ),
      isFalse,
    );
  });

  test('packageCacheHasRequiredLinkUnits detects missing @[link] .c', () {
    final dir = Directory.systemTemp.createTempSync('klin_link_units_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/usb.kl').writeAsStringSync('''
@[link("usb_cdc_rp.c")]
@[link("-lm")]
fn usb_cdc_out() {}
''');
    expect(packageCacheHasRequiredLinkUnits(dir.path), isFalse);
    File('${dir.path}/usb_cdc_rp.c').writeAsStringSync('void f(void) {}\n');
    expect(packageCacheHasRequiredLinkUnits(dir.path), isTrue);
  });

  test('packageContentHash is stable and order-independent (issue 065)', () {
    final dir = Directory.systemTemp.createTempSync('klin_hash065_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/b.kl').writeAsStringSync('module x\n');
    File('${dir.path}/a.kl').writeAsStringSync('module x\nfn f() {}\n');
    final h1 = packageContentHash(dir.path);
    // Recreate in opposite write order — hash must match.
    final dir2 = Directory.systemTemp.createTempSync('klin_hash065b_');
    addTearDown(() => dir2.deleteSync(recursive: true));
    File('${dir2.path}/a.kl').writeAsStringSync('module x\nfn f() {}\n');
    File('${dir2.path}/b.kl').writeAsStringSync('module x\n');
    expect(packageContentHash(dir2.path), h1);
    File('${dir2.path}/a.kl').writeAsStringSync('module x\nfn f() { }\n');
    expect(packageContentHash(dir2.path), isNot(h1));
  });

  test('remote import rejects path traversal segments (issue 049)', () {
    expect(
      () => parseRemoteImport('github/../../tmp/evil'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseRemoteImport('github/foo/bar/../../x'),
      throwsA(isA<FormatException>()),
    );
  });

  test('isUpgradeTarget / collectOutdated (issue 066)', () async {
    expect(isUpgradeTarget('v0.1.0', 'v0.1.0'), isFalse);
    expect(isUpgradeTarget('v0.1.0', 'v0.2.0'), isTrue);
    expect(isUpgradeTarget('v0.2.0', 'v0.1.0'), isFalse);
    expect(isUpgradeTarget('1.0.0', 'v1.0.1'), isTrue);
    expect(isUpgradeTarget('main', 'v0.1.0'), isTrue);
    expect(isUpgradeTarget('main', 'main'), isFalse);

    final mod = KlinMod(requires: {
      'github/klin-lang/osa': 'v0.1.0',
      'github/acme/lib': 'v1.0.0',
    });
    Future<String> fakeLatest(RemoteImport r) async => switch (r.path) {
          'github/klin-lang/osa' => 'v0.2.0',
          'github/acme/lib' => 'v1.0.0',
          _ => 'v0.0.0',
        };
    final rows = await collectOutdated(mod, resolveLatest: fakeLatest);
    expect(rows.length, 1);
    expect(rows.single.path, 'github/klin-lang/osa');
    expect(rows.single.current, 'v0.1.0');
    expect(rows.single.latest, 'v0.2.0');
    expect(
      formatOutdatedReport(rows),
      'github/klin-lang/osa\tv0.1.0\tv0.2.0\n',
    );
    expect(formatOutdatedReport(const []), 'all packages up to date\n');

    await expectLater(
      collectOutdated(
        mod,
        onlyPaths: ['github/missing/pkg'],
        resolveLatest: fakeLatest,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('klin get fetches osa@v0.1.0 and run works (issue 049 network)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_get049_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final work = Directory.systemTemp.createTempSync('klin_getwork049_');
    addTearDown(() => work.deleteSync(recursive: true));
    File('${work.path}/app.kl').writeAsStringSync(
      File('test/remote_osa.kl').readAsStringSync(),
    );
    final repoRoot = Directory.current.path;
    final klinBin = '$repoRoot/bin/klin.dart';

    final get = await Process.run(
      'dart',
      ['run', klinBin, 'get', 'github/klin-lang/osa@v0.1.0'],
      workingDirectory: work.path,
      environment: {
        ...Platform.environment,
        'KLIN_CACHE': cache.path,
      },
    );
    expect(get.exitCode, 0, reason: '${get.stderr}${get.stdout}');
    expect(File('${work.path}/klin.mod').existsSync(), isTrue);
    final mod = loadKlinMod(File('${work.path}/klin.mod'));
    expect(mod.requires['github/klin-lang/osa'], 'v0.1.0');

    expect(File('${work.path}/klin.lock').existsSync(), isTrue);
    final lock = loadKlinLock(File('${work.path}/klin.lock'));
    final entry = lock.packages['github/klin-lang/osa']!;
    expect(entry.version, 'v0.1.0');
    expect(entry.commit, matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(entry.hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    final pkgDir = '${cache.path}/pkg/github/klin-lang/osa';
    expect(packageContentHash(pkgDir), entry.hash);
    expect(readCommit(pkgDir), entry.commit);

    // Second get prefers lock SHA (offline-capable once cached) and keeps lock.
    final get2 = await Process.run(
      'dart',
      ['run', klinBin, 'get'],
      workingDirectory: work.path,
      environment: {
        ...Platform.environment,
        'KLIN_CACHE': cache.path,
      },
    );
    expect(get2.exitCode, 0, reason: '${get2.stderr}${get2.stdout}');
    expect(
      loadKlinLock(File('${work.path}/klin.lock'))
          .packages['github/klin-lang/osa']!
          .commit,
      entry.commit,
    );

    // Tampered lock hash must fail.
    File('${work.path}/klin.lock').writeAsStringSync(
      'klin lock 1\n'
      'github/klin-lang/osa v0.1.0 ${entry.commit} '
      'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n',
    );
    final bad = await Process.run(
      'dart',
      ['run', klinBin, 'get'],
      workingDirectory: work.path,
      environment: {
        ...Platform.environment,
        'KLIN_CACHE': cache.path,
      },
    );
    expect(bad.exitCode, isNot(0));
    expect('${bad.stderr}', contains('hash mismatch'));

    final run = await Process.run(
      'dart',
      ['run', klinBin, 'run', '${work.path}/app.kl'],
      workingDirectory: repoRoot,
      environment: {
        ...Platform.environment,
        'KLIN_CACHE': cache.path,
      },
    );
    expect(run.exitCode, 0, reason: '${run.stderr}${run.stdout}');
    expect(run.stdout, await File('test/remote_osa.out').readAsString());
  }, timeout: Timeout(Duration(minutes: 2)));

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

  test('klin outdated/upgrade with osa@v0.1.0 (issue 066 network)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_outdated066_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final work = Directory.systemTemp.createTempSync('klin_outdatedwork066_');
    addTearDown(() => work.deleteSync(recursive: true));
    File('${work.path}/klin.mod').writeAsStringSync(
      'klin 1\nrequire github/klin-lang/osa v0.1.0\n',
    );
    final repoRoot = Directory.current.path;
    final klinBin = '$repoRoot/bin/klin.dart';
    final env = {
      ...Platform.environment,
      'KLIN_CACHE': cache.path,
    };

    final get = await Process.run(
      'dart',
      ['run', klinBin, 'get'],
      workingDirectory: work.path,
      environment: env,
    );
    expect(get.exitCode, 0, reason: '${get.stderr}${get.stdout}');

    final outdated = await Process.run(
      'dart',
      ['run', klinBin, 'outdated'],
      workingDirectory: work.path,
      environment: env,
    );
    expect(outdated.exitCode, 0, reason: '${outdated.stderr}${outdated.stdout}');
    expect(outdated.stdout, 'all packages up to date\n');

    final upgrade = await Process.run(
      'dart',
      ['run', klinBin, 'upgrade'],
      workingDirectory: work.path,
      environment: env,
    );
    expect(upgrade.exitCode, 0, reason: '${upgrade.stderr}${upgrade.stdout}');
    expect(upgrade.stdout, 'all packages up to date\n');
    expect(
      loadKlinMod(File('${work.path}/klin.mod')).requires['github/klin-lang/osa'],
      'v0.1.0',
    );
  }, timeout: Timeout(Duration(minutes: 2)));

  test('error: conflicting import alias (issue 048)', () {
    final dir = Directory.systemTemp.createTempSync('klin_aliasdup048_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/geom.kl').writeAsStringSync('''
module geom
pub fn a(): i32 { return 1 }
''');
    File('${dir.path}/util.kl').writeAsStringSync('''
module util
pub fn a(): i32 { return 2 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom x
import util x
fn main() { printf("%d\\n", x.a()) }
''');
    expect(
      () => loadProject('${dir.path}/app.kl'),
      throwsA(
        predicate(
            (e) => e is ParseError && e.toString().contains('already bound')),
      ),
    );
  });

  test('error: C keyword as an import alias (issue 048)', () {
    const source = '''
module app
import geom int
fn main() {}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parseUnit(),
      throwsA(
        predicate((e) => e is ParseError && e.toString().contains('C keyword')),
      ),
    );
  });

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
    final result = await _compileAndRun('${dir.path}/app.kl', tmp);
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
    final sibling = await _compileAndRun('${appDir.path}/app.kl', tmp);
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
    final result = await _compileAndRun('examples/pkg_geom/app.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '25\n');

    final program = loadProject('examples/pkg_geom/app.kl');
    Checker().check(program);
    final c = emitC(program, 'examples/pkg_geom/app.kl');
    expect(c, contains('static int32_t geom_sq('));
    expect(c, contains('geom_Vec2_len_sq('));
  });

  test('remote eventloop: every_ms + run + stop (issue 029 MVP)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_cache_eloop_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final pkg = Directory('${cache.path}/pkg/github/klin-lang/eventloop')
      ..createSync(recursive: true);
    // Preseed cache from fixture mirroring eventloop v0.2 (keeps v0.1 callbacks).
    File('${pkg.path}/version.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/version.kl').readAsString(),
    );
    File('${pkg.path}/executor.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/executor.kl').readAsString(),
    );
    File('${pkg.path}/.pin').writeAsStringSync('v0.2.0\n');

    final result = await _compileAndRun(
      'examples/remote_eventloop/app.kl',
      tmp,
      klinCacheDir: cache.path,
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'tick\ntick\ntick\nticks=3 version=2\n');
  });

  test('golden: async fn emits State + poll (issue 029)', () {
    const source = '''
struct Fut {
  done: i32
}

fn (mut f: Fut) poll(): i32 {
  if f.done != 0 { return 1 }
  f.done = 1
  return 0
}

fn make_fut(): Fut {
  return Fut{ done: 0 }
}

async fn work() {
  make_fut().await
}

fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'async_work.kl');
    expect(c, contains('typedef struct {'));
    expect(c, contains('__stage'));
    expect(c, contains('work_State'));
    expect(c, contains('work_init'));
    expect(c, contains('work_poll'));
    expect(c, contains('work_init_erased'));
    expect(c, contains('work_poll_erased'));
    expect(c, contains('#line '));
    expect(c, contains('case 1:'));
  });

  test('error: await outside async fn (issue 029)', () {
    const source = '''
struct Fut { done: i32 }
fn (mut f: Fut) poll(): i32 { return 1 }
fn main() {
  let mut f = Fut{ done: 1 }
  f.await
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('only allowed inside `async fn`'))),
    );
  });

  test('error: async main rejected (issue 029)', () {
    final program = Parser(Lexer('async fn main() {}\n').tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('cannot be `async`'))),
    );
  });

  test('error: async methods rejected (issue 029)', () {
    const source = '''
struct S {}
async fn (s: S) go() {}
fn main() {}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(predicate((e) =>
          e is ParseError && e.toString().contains('async'))),
    );
  });

  test('error: bare async call statement (issue 029)', () {
    const source = '''
async fn work() {}
fn main() {
  work()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('can only be used with `.await`'))),
    );
  });

  test('error: async shadowed let rejected (issue 029)', () {
    const source = '''
async fn work() {
  let x: i32 = 1
  if true {
    let x: i32 = 2
  }
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('reused `let x`'))),
    );
  });

  test('error: async sibling-scope let reuse rejected (issue 029)', () {
    const source = '''
async fn work() {
  if true {
    let x: i32 = 1
  } else {
    let x: i32 = 2
  }
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('reused `let x`'))),
    );
  });

  test('remote eventloop: async spawn + sleep_ms (issue 029)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_cache_async_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final pkg = Directory('${cache.path}/pkg/github/klin-lang/eventloop')
      ..createSync(recursive: true);
    File('${pkg.path}/version.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/version.kl').readAsString(),
    );
    File('${pkg.path}/executor.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/executor.kl').readAsString(),
    );
    File('${pkg.path}/.pin').writeAsStringSync('v0.2.0\n');

    final result = await _compileAndRun(
      'examples/remote_eventloop/async_app.kl',
      tmp,
      klinCacheDir: cache.path,
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'tick\ntick\ntick\nticks done version=2\n');
  });

  test('remote sketch_async_eventloop (issue 029 phase 4)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_cache_sketch_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final pkg = Directory('${cache.path}/pkg/github/klin-lang/eventloop')
      ..createSync(recursive: true);
    File('${pkg.path}/version.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/version.kl').readAsString(),
    );
    File('${pkg.path}/executor.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/executor.kl').readAsString(),
    );
    File('${pkg.path}/.pin').writeAsStringSync('v0.2.0\n');

    final result = await _compileAndRun(
      'examples/sketch_async_eventloop.kl',
      tmp,
      klinCacheDir: cache.path,
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'tick\ntick\ntick\nticks done version=2\n');
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
    final result = await _compileAndRun('${dir.path}/main.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '7\n');
  });

  test('*_test.kl is skipped when loading a package directory (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_skip_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/vec.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 1 }
''');
    File('${dir.path}/geom/geom_test.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 99 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  printf("%d\\n", geom.n())
}
''');
    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    // Duplicate `n` would fail if *_test.kl were loaded.
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('klin_ret_0 = 1'));
    expect(c, isNot(contains('99')));
  });

  test('ambiguous name.kl and name/ directory is an error (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_ambig_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/geom.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 1 }
''');
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/a.kl').writeAsStringSync('''
module geom
pub fn n(): i32 { return 2 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {}
''');
    expect(
      () => loadProject('${dir.path}/app.kl'),
      throwsA(
        predicate(
          (e) =>
              e is FileSystemException &&
              e.message.contains('ambiguous import'),
        ),
      ),
    );
  });

  test('package directory rejects mismatched module name (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_mismatch_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/a.kl').writeAsStringSync('''
module wrong
pub fn n(): i32 { return 1 }
''');
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  printf("%d\\n", geom.n())
}
''');
    expect(
      () => loadProject('${dir.path}/app.kl'),
      throwsA(
        predicate(
          (e) =>
              e is ParseError &&
              e.toString().contains('does not match package'),
        ),
      ),
    );
  });

  test('re-import of a file already in a loaded package is a no-op (issue 047)',
      () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_reimport_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/geom').createSync();
    File('${dir.path}/geom/a.kl').writeAsStringSync('''
module geom
import b
pub fn one(): i32 { return b.two() }
''');
    File('${dir.path}/geom/b.kl').writeAsStringSync('''
module geom
pub fn two(): i32 { return 2 }
''');
    // Mistaken same-package import by file name would resolve to b.kl;
    // must not duplicate geom_two.
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
import geom
fn main() {
  printf("%d\\n", geom.one())
}
''');
    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program); // would fail on duplicate `two` if re-parsed
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('geom_one'));
    expect(c, contains('geom_two'));
  });

  test('broken same-module sibling fails loudly (issue 047)', () {
    final dir = Directory.systemTemp.createTempSync('klin_pkg_bad_sib_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/app.kl').writeAsStringSync('''
module app
fn main() {}
''');
    File('${dir.path}/other.kl').writeAsStringSync('''
module app
fn broken( {
''');
    expect(
      () => loadProject('${dir.path}/app.kl'),
      throwsA(isA<ParseError>()),
    );
  });

  test('error: mutating method on immutable variable', () {
    final source = File('test/bad_mut_method.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('mutating method'),
        ),
      ),
    );
  });

  test('shadowed mut receiver emits `.` rather than `->`', () {
    const source = '''
struct Vec2 {
  x: i32
}
fn (mut v: Vec2) bump() {
  let mut v = Vec2{ 1 }
  v.x = v.x + 1
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'shadow.kl');
    expect(c, contains('v.x = (v.x + 1);'));
    expect(c, isNot(contains('v->x')));
  });

  test('error: assignment to a struct literal field', () {
    const source = '''
struct Vec2 {
  x: i32
}
fn main() {
  Vec2{ 1 }.x = 2
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('field of an immutable expression'),
        ),
      ),
    );
  });

  test('golden: nested mutable places (issue 069 checker unblock)', () async {
    final result = await _compileAndRun('test/nested_mut_place.kl', tmp);
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

  test('error: nested array write through an immutable receiver', () {
    const source = '''
struct Bus {
  slots: [2]i32
}
fn (b: Bus) set(i: i32, v: i32) {
  b.slots[i] = v
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) => e is CheckError && e.toString().contains('immutable')),
      ),
    );
  });

  test('error: nested struct field write through an immutable variable', () {
    const source = '''
struct Inner {
  x: i32
}
struct Outer {
  inner: Inner
}
fn main() {
  let o = Outer{ inner: Inner{ x: 1 } }
  o.inner.x = 5
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) => e is CheckError && e.toString().contains('immutable')),
      ),
    );
  });

  test('golden: assign to a field through a *mut deref (parser + checker)',
      () async {
    final result = await _compileAndRun('test/deref_field_assign.kl', tmp);
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

  test('parser: `(` on a new line starts a new statement, not a call', () {
    // `&q` ends a line; the next line opens with `(`. Previously this parsed as
    // a call `q(*p)`, swallowing the assignment. It must now be two statements.
    const source = '''
struct P {
  x: i32
}
fn main() {
  let mut q = P{ x: 0 }
  let p: *mut P = &q
  (*p).x = 7
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final main = program.funcs.firstWhere((f) => f.name == 'main');
    // let q, let p, (*p).x = 7  → three statements (no swallowing).
    expect(main.body!.stmts.length, 3);
    expect(main.body!.stmts.last, isA<AssignStmt>());
  });

  test('parser: same-line `(` still parses as a call', () {
    const source = '''
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {
  let x = add(2, 3)
  printf("%d\\n", x)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'call.kl');
    expect(c, contains('add(2, 3)'));
  });

  test('parser: newline before `(` inside open parens still forms a call', () {
    // Go-like: only statement-level newline before `(` breaks a call.
    // Inside an argument list, `bar\\n(y)` must remain a call.
    const source = '''
fn bar(y: i32): i32 { return y }
fn foo(a: i32, b: i32): i32 { return a + b }
fn main() {
  let x = foo(1, bar
(2))
  printf("%d\\n", x)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'nested_call.kl');
    expect(c, contains('foo(1, bar(2))'));
  });

  test('golden: associated functions on types (Type.func)', () async {
    final result = await _compileAndRun('test/assoc_fn.kl', tmp);
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

  test('error: unknown associated function (Type.func)', () {
    const source = '''
enum Color { Red, Green }
fn main() {
  let c: Color = Color.parse("red")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('no associated function'))),
    );
  });

  test('error: associated function wrong argument count (Type.func)', () {
    const source = '''
struct Point { x, y: i32 }
fn Point.new(x, y: i32): Point { return Point{ x: x, y: y } }
fn main() {
  let p: Point = Point.new(1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('expects 2 arguments'))),
    );
  });

  test('error: associated function conflicts with method C name (Type.func)', () {
    const source = '''
struct Point { x, y: i32 }
fn (p: Point) new(): i32 { return p.x }
fn Point.new(x, y: i32): Point { return Point{ x: x, y: y } }
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('conflicts with a method'))),
    );
  });

  test('error: associated function conflicts with enum variant (Type.func)', () {
    const source = '''
enum Color { Red, Green }
fn Color.Red(): i32 { return 1 }
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('conflicts with enum variant'))),
    );
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
    final result = await _compileAndRun('${dir.path}/app.kl', dir);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '0\n');

    final program = loadProject('${dir.path}/app.kl');
    Checker().check(program);
    final c = emitC(program, '${dir.path}/app.kl');
    expect(c, contains('geom_Point_origin'));
  });

  test('klin fmt: formats associated function declaration (Type.func)', () {
    const ugly =
        'struct Point{x,y:i32}\nfn Point.new(x,y:i32):Point{return Point{x:x,y:y}}\nfn main(){}';
    final once = formatSource(ugly);
    expect(once, contains('fn Point.new(x: i32, y: i32): Point {'));
    expect(formatSource(once), once);
  });

  test('golden: number + character literals (issue 081)', () async {
    final result = await _compileAndRun('test/number_literals.kl', tmp);
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

  test('error: empty character literal (issue 081)', () {
    expect(
      () => Lexer("fn main() { let x = '' }").tokenize(),
      throwsA(predicate(
          (e) => e is LexError && e.toString().contains('empty character'))),
    );
  });

  test('error: unknown character escape (issue 081)', () {
    expect(
      () => Lexer(r"fn main() { let x = '\q' }").tokenize(),
      throwsA(predicate(
          (e) => e is LexError && e.toString().contains('escape sequence'))),
    );
  });

  test('fmt: character literal spelling preserved (issue 081)', () {
    const src = "fn main() {\n    let a: u8 = 'A'\n    let b: u8 = '\\n'\n}";
    expect(formatSource(src), contains("'A'"));
    expect(formatSource(src), contains(r"'\n'"));
  });

  test('checker: array length character `]` and quote escape (issue 081)', () {
    final program = Parser(Lexer(r"""
fn take_brack(xs: [']']u8) {}
fn take_quote(ys: ['\'']u8) {}
fn main() {}
""")
        .tokenize())
        .parse();
    expect(() => Checker().check(program), returnsNormally);
    final c = emitC(program, 't.kl');
    expect(c, contains('uint8_t xs[93]')); // ']' == 93
    expect(c, contains('uint8_t ys[39]')); // '\'' == 39
  });

  test('error: binary literal without a digit (issue 081)', () {
    expect(
      () => Lexer('fn main() { let x = 0b }').tokenize(),
      throwsA(predicate(
          (e) => e is LexError && e.toString().contains('binary digit'))),
    );
  });

  test('error: octal literal without a digit (issue 081)', () {
    expect(
      () => Lexer('fn main() { let x = 0o }').tokenize(),
      throwsA(predicate(
          (e) => e is LexError && e.toString().contains('octal digit'))),
    );
  });

  test('lexer: `1end` is `1` then ident, not a float exponent (issue 081)', () {
    final tokens = Lexer('1end').tokenize();
    expect(tokens[0].kind, TokenKind.intLit);
    expect(tokens[0].lexeme, '1');
    expect(tokens[1].kind, TokenKind.ident);
    expect(tokens[1].lexeme, 'end');
  });

  test('klin fmt: preserves binary and exponent literals (issue 081)', () {
    const source =
        'fn main() { let a = 0b1010\nlet o = 0o755\nlet b = 1.5e-3\nlet c = 1e9 }';
    final once = formatSource(source);
    expect(once, contains('0b1010'));
    expect(once, contains('0o755'));
    expect(once, contains('1.5e-3'));
    expect(once, contains('1e9'));
    expect(formatSource(once), once);
  });

  test('error: wrong function argument count', () {
    final source = File('test/bad_arity.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('expects 2 arguments') &&
              e.toString().contains('got 1'),
        ),
      ),
    );
  });

  test('error: mismatched function argument type', () {
    final source = File('test/bad_arg_type.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) =>
              e is CheckError &&
              e.toString().contains('expected `i32`') &&
              e.toString().contains('got `bool`'),
        ),
      ),
    );
  });

  test('return plus a next-line call does not consume the statement', () {
    const source = '''
fn main() {
  return
  puts("after")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    final body = program.funcs.single.body!.stmts;
    expect(body.length, 2);
    expect(body[0], isA<ReturnStmt>());
    expect((body[0] as ReturnStmt).value, isNull);
    expect(body[1], isA<CallStmt>());
  });

  test('error: calling a local variable instead of a function', () {
    const source = '''
fn foo(): i32 { return 1 }
fn main() {
  let foo = 1
  foo()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('is not a function'),
        ),
      ),
    );
  });

  test('error: break outside a loop', () {
    final source = File('test/break_outside.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('break') &&
              msg.contains('a loop');
        }),
      ),
    );
  });

  test('error: if condition is not bool', () {
    final source = File('test/bad_cond.kl').readAsStringSync();
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) {
          if (e is! CheckError) return false;
          final msg = e.toString();
          return msg.contains('2:') &&
              msg.contains('bool') &&
              msg.contains('untyped int');
        }),
      ),
    );
  });

  test('golden: slice, array, and mutable pointer', () async {
    final result = await _compileAndRun('test/slice_sum.kl', tmp);
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

  test('implicit array-to-slice conversion emits a slice header', () {
    const source = '''
fn sum(xs: []i32): i32 { return xs.len }
fn main() {
  let buf: [2]i32 = [1, 2]
  printf("%d\\n", sum(buf))
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'coerce.kl');
    expect(c, contains('(klin_slice_i32){ buf, 2 }'));
  });

  test('error: write through immutable pointer', () {
    const source = '''
fn main() {
  let mut value: i32 = 0
  let p: *i32 = &value
  *p = 1
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate(
          (e) => e is CheckError && e.toString().contains('immutable pointer'),
        ),
      ),
    );
  });

  test('hexadecimal literal accepts underscores', () {
    const source = '''
fn main() {
  let address: u32 = 0x4000_1000
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    expect(emitC(program, 'hex.kl'), contains('0x40001000'));
  });

  test('codename emits a global C symbol', () {
    const source = '''
@[codename("SysTick_Handler")]
fn tick() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'tick.kl');
    expect(c, contains('void SysTick_Handler(void);'));
    expect(c, contains('void SysTick_Handler(void) {'));
    expect(c, isNot(contains('static void SysTick_Handler')));
  });

  test('isr("…") sugar emits a global C vector symbol (issue 030)', () {
    const source = '''
@[isr("SysTick_Handler")]
fn tick() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'isr.kl');
    expect(c, contains('void SysTick_Handler(void);'));
    expect(c, contains('void SysTick_Handler(void) {'));
    expect(c, isNot(contains('static void SysTick_Handler')));
  });

  test('isr + codename emits a global C vector symbol (issue 030)', () {
    const source = '''
@[isr, codename("TIM2_IRQHandler")]
fn on_tim2() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'isr2.kl');
    expect(c, contains('void TIM2_IRQHandler(void);'));
    expect(c, isNot(contains('static void TIM2_IRQHandler')));
  });

  test('isr without vector name is a checker error', () {
    const source = '''
@[isr]
fn tick() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('isr'),
      )),
    );
  });

  test('isr with parameters is a checker error', () {
    const source = '''
@[isr("SysTick_Handler")]
fn tick(x: i32) {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError && e.toString().contains('no parameters'),
      )),
    );
  });

  test('isr with non-void return is a checker error', () {
    const source = '''
@[isr("SysTick_Handler")]
fn tick(): i32 { return 0 }
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('void'),
      )),
    );
  });

  test('isr name conflicting with codename is a checker error', () {
    const source = '''
@[isr("SysTick_Handler"), codename("Other_Handler")]
fn tick() {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('conflicts'),
      )),
    );
  });

  test('cexport + codename emits a global C symbol (issue 045)', () {
    const source = '''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {
  printf("%d\\n", add(2, 3))
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'exp.kl');
    expect(c, contains('int32_t klin_add(int32_t a, int32_t b);'));
    expect(c, contains('int32_t klin_add(int32_t a, int32_t b) {'));
    expect(c, isNot(contains('static int32_t klin_add')));
  });

  test('cexport without codename is a checker error', () {
    const source = '''
@[cexport]
fn add(a: i32, b: i32): i32 { return a + b }
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('codename'),
      )),
    );
  });

  test('cexport cannot combine with cimport', () {
    const source = '''
@[cexport, cimport, codename("x")]
fn x()
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('cimport') &&
            e.toString().contains('cexport'),
      )),
    );
  });

  test('cexport on main is a checker error', () {
    const source = '''
@[cexport, codename("not_really_main")]
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('main'),
      )),
    );
  });

  test('C caller can link against cexport symbol (issue 045)', () async {
    final kl = File('${tmp.path}/lib_add.kl');
    await kl.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {}
''');
    final program = loadProject(kl.path);
    Checker().check(program);
    // Klin requires `main`; rename it so the C caller owns the entry point.
    var cSource = emitC(program, kl.path);
    cSource = cSource.replaceAll('int main(void)', 'static int klin_lib_main(void)');
    final cPath = '${tmp.path}/lib_add.c';
    await File(cPath).writeAsString(cSource);

    final caller = File('${tmp.path}/caller.c');
    await caller.writeAsString('''
#include <stdint.h>
#include <stdio.h>
int32_t klin_add(int32_t a, int32_t b);
int main(void) {
  printf("%d\\n", (int)klin_add(2, 3));
  return 0;
}
''');
    final bin = '${tmp.path}/cexport_bin';
    final compile = await Process.run('gcc', [
      caller.path,
      cPath,
      '-o',
      bin,
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stderr}${compile.stdout}');
    final run = await Process.run(bin, []);
    expect(run.exitCode, 0, reason: run.stderr);
    expect(run.stdout, '5\n');
  });

  test('emitH writes prototypes for cexport (issue 046)', () {
    const source = '''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final h = emitH(program, 'lib.kl');
    expect(h, contains('#ifndef KLIN_LIB_H'));
    expect(h, contains('#include <stdint.h>'));
    expect(h, contains('int32_t klin_add(int32_t a, int32_t b);'));
    expect(h, isNot(contains('main')));
    expect(h, contains('#endif /* KLIN_LIB_H */'));
  });

  test('emitH closes nested struct deps regardless of decl order (issue 046)', () {
    // Signature only mentions Outer; Inner is two levels down. One pass over
    // program.structs (decl order Inner → Mid → Outer) used to miss Inner.
    const source = '''
struct Inner {
  x: i32
}
struct Mid {
  inner: Inner
}
struct Outer {
  mid: Mid
}
@[cexport, codename("klin_take_outer")]
fn take_outer(o: Outer): i32 {
  return o.mid.inner.x
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final h = emitH(program, 'nest.kl');
    expect(h, contains('Inner'));
    expect(h, contains('Mid'));
    expect(h, contains('Outer'));
    expect(h.indexOf('Inner'), lessThan(h.indexOf('Mid')));
    expect(h.indexOf('Mid'), lessThan(h.indexOf('Outer')));
    expect(h, contains('klin_take_outer'));
  });

  test('emitC emits nested struct typedefs before dependents', () {
    // Declaration order Outer → Mid → Inner must still typedef Inner first.
    const source = '''
struct Outer {
  mid: Mid
}
struct Mid {
  inner: Inner
}
struct Inner {
  x: i32
}
fn main() {
  let o = Outer{ mid: Mid{ inner: Inner{ x: 1 } } }
  let _ = o.mid.inner.x
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'struct_order.kl');
    // Typedef close lines: "} <module>_Inner;" — use the closing tag to avoid
    // matching field type mentions inside later structs.
    final innerTd = c.indexOf('} Inner;');
    final midTd = c.indexOf('} Mid;');
    final outerTd = c.indexOf('} Outer;');
    expect(innerTd, greaterThanOrEqualTo(0));
    expect(midTd, greaterThanOrEqualTo(0));
    expect(outerTd, greaterThanOrEqualTo(0));
    expect(innerTd, lessThan(midTd));
    expect(midTd, lessThan(outerTd));
  });

  test('C caller can #include emitH header (issue 046)', () async {
    final kl = File('${tmp.path}/lib_add_h.kl');
    await kl.writeAsString('''
@[cexport, codename("klin_add")]
fn add(a: i32, b: i32): i32 {
  return a + b
}
fn main() {}
''');
    final program = loadProject(kl.path);
    Checker().check(program);
    var cSource = emitC(program, kl.path);
    cSource =
        cSource.replaceAll('int main(void)', 'static int klin_lib_main(void)');
    final cPath = '${tmp.path}/lib_add_h.c';
    final hPath = '${tmp.path}/lib_add_h.h';
    await File(cPath).writeAsString(cSource);
    await File(hPath).writeAsString(emitH(program, kl.path));

    final caller = File('${tmp.path}/caller_h.c');
    await caller.writeAsString('''
#include <stdio.h>
#include "lib_add_h.h"
int main(void) {
  printf("%d\\n", (int)klin_add(2, 3));
  return 0;
}
''');
    final bin = '${tmp.path}/cexport_h_bin';
    final compile = await Process.run('gcc', [
      caller.path,
      cPath,
      '-I',
      tmp.path,
      '-o',
      bin,
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stderr}${compile.stdout}');
    final run = await Process.run(bin, []);
    expect(run.exitCode, 0, reason: run.stderr);
    expect(run.stdout, '5\n');
  });

  test('cimport emits a declaration and checks its signature', () {
    const source = '''
@[cimport, codename("pin_set")]
fn set_pin(value: u32)
fn main() {
  set_pin(1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'ffi.kl');
    expect(c, contains('uint32_t value'));
    expect(c, contains('void pin_set(uint32_t value);'));
    expect(c, isNot(contains('void pin_set(uint32_t value) {')));

    const badSource = '''
@[cimport]
fn set_pin(value: u32)
fn main() {
  set_pin()
}
''';
    final bad = Parser(Lexer(badSource).tokenize()).parse();
    expect(
      () => Checker().check(bad),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('expects 1 arguments'),
      )),
    );
  });

  test(
      'cimport with a body and a bodyless non-cimport function are checker errors',
      () {
    final pos = const SourcePos(1, 1);
    final main = FuncDecl(
      name: 'main',
      receiver: null,
      params: [],
      returnTypeName: null,
      body: Block([], pos),
      pos: pos,
    );
    final importedWithBody = FuncDecl(
      name: 'ffi',
      receiver: null,
      params: [],
      returnTypeName: null,
      body: Block([], pos),
      attrs: [Attr('cimport', null, pos)],
      pos: pos,
    );
    expect(
      () => Checker().check(Program([], [importedWithBody, main], pos)),
      throwsA(isA<CheckError>()),
    );
    final missingBody = FuncDecl(
      name: 'missing',
      receiver: null,
      params: [],
      returnTypeName: null,
      body: null,
      pos: pos,
    );
    expect(
      () => Checker().check(Program([], [missingBody, main], pos)),
      throwsA(isA<CheckError>()),
    );
  });

  test('asm emits asm volatile without stdio', () {
    const source = '''
fn main() {
  asm("wfi")
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'asm.kl');
    expect(c, contains('asm volatile("wfi");'));
    expect(c, isNot(contains('#include <stdio.h>')));
  });

  test('klin test runs *_test.kl and reports assert failures (issue 035)',
      () async {
    final pass = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test', 'examples/add_test.kl'],
    );
    expect(pass.exitCode, 0, reason: pass.stderr.toString());
    expect(pass.stdout.toString(), contains('ok\texamples/add_test.kl'));
    expect(pass.stdout.toString(), contains('PASS'));

    final dir = Directory('${tmp.path}/klin_tests')..createSync();
    File('${dir.path}/fail_test.kl').writeAsStringSync('''
import testing
fn test_boom() {
  testing.assert_eq_i32(1, 2)
}
''');
    final fail = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test', '${dir.path}/fail_test.kl'],
      environment: {
        ...Platform.environment,
        'KLIN_STDLIB': Directory('stdlib').absolute.path,
      },
    );
    expect(fail.exitCode, isNot(0));
    expect(fail.stdout.toString(), contains('FAIL'));
    expect(
      '${fail.stdout}${fail.stderr}',
      contains('assert_eq_i32'),
    );

    // Imported `main` must not suppress the test harness.
    File('${dir.path}/lib_with_main.kl').writeAsStringSync('''
module lib_with_main
pub fn value(): i32 { return 7 }
fn main() { puts("imported-main") }
''');
    File('${dir.path}/import_main_test.kl').writeAsStringSync('''
import lib_with_main
import testing
fn test_value() {
  testing.assert_eq_i32(lib_with_main.value(), 7)
}
''');
    final imported = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test', '${dir.path}/import_main_test.kl'],
      environment: {
        ...Platform.environment,
        'KLIN_STDLIB': Directory('stdlib').absolute.path,
      },
    );
    expect(imported.exitCode, 0, reason: imported.stderr.toString());
    expect(imported.stdout.toString(), contains('ok\t'));
    expect('${imported.stdout}${imported.stderr}', isNot(contains('imported-main')));

    // Injected test `main` must keep enum declarations (Bugbot retro #97).
    File('${dir.path}/enum_harness_test.kl').writeAsStringSync('''
import testing
enum Color { Red, Green }
fn test_color() {
  testing.assert_eq_i32(cast(i32, Color.Green), 1)
}
''');
    final withEnum = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test', '${dir.path}/enum_harness_test.kl'],
      environment: {
        ...Platform.environment,
        'KLIN_STDLIB': Directory('stdlib').absolute.path,
      },
    );
    expect(withEnum.exitCode, 0, reason: withEnum.stderr.toString());
    expect(withEnum.stdout.toString(), contains('ok\t'));
  });

  test('klin run compiles and executes a program', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'run', 'test/hello.kl'],
    );
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout, await File('test/hello.out').readAsString());
  });

  test('klin --version and -v print package version', () async {
    for (final flag in ['--version', '-v']) {
      final proc = await Process.run('dart', ['run', 'bin/klin.dart', flag]);
      expect(proc.exitCode, 0, reason: '$flag: ${proc.stderr}');
      expect(proc.stdout.toString().trim(), 'klin 0.1.2');
    }
  });

  test('klin --help and -h print usage on stdout', () async {
    for (final flag in ['--help', '-h']) {
      final proc = await Process.run('dart', ['run', 'bin/klin.dart', flag]);
      expect(proc.exitCode, 0, reason: '$flag: ${proc.stderr}');
      expect(proc.stdout.toString(), contains('usage:'));
      expect(proc.stdout.toString(), contains('--version'));
      expect(proc.stdout.toString(), contains('--opt'));
      expect(proc.stderr.toString(), isEmpty);
    }
  });

  test('klin run -O2 / --opt s / -Os compile hello', () async {
    for (final flags in [
      ['-O2'],
      ['--opt', 's'],
      ['-Os'],
      ['-g', '-O0'],
    ]) {
      final proc = await Process.run('dart', [
        'run',
        'bin/klin.dart',
        'run',
        ...flags,
        'test/hello.kl',
      ]);
      expect(proc.exitCode, 0, reason: '$flags: ${proc.stderr}');
      expect(proc.stdout, await File('test/hello.out').readAsString());
    }
  });

  test('klin run --opt invalid prints usage', () async {
    final proc = await Process.run('dart', [
      'run',
      'bin/klin.dart',
      'run',
      '--opt',
      'fast',
      'test/hello.kl',
    ]);
    expect(proc.exitCode, isNot(0));
    expect(proc.stderr.toString(), contains('usage:'));
  });

  test('klin with no args prints help on stdout', () async {
    final proc = await Process.run('dart', ['run', 'bin/klin.dart']);
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout.toString(), contains('usage:'));
    expect(proc.stderr.toString(), isEmpty);
  });

  test('klin run without a file prints usage', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'run'],
    );
    expect(proc.exitCode, isNot(0));
    expect(proc.stderr.toString(), contains('usage:'));
    expect(proc.stderr.toString(), contains('klin run'));
  });

  test('bare file path remains an alias for run', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'test/hello.kl'],
    );
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout, await File('test/hello.out').readAsString());
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

  test('buildCcArgs resolves @[link] paths and CLI -l/-L', () {
    const pos = SourcePos(1, 1);
    final program = Program(
      [],
      [
        FuncDecl(
          name: 'main',
          receiver: null,
          params: const [],
          returnTypeName: null,
          body: Block(const [], pos),
          pos: pos,
          attrs: [
            Attr('link', 'libadd.a', pos),
            Attr('link', '-lm', pos),
          ],
          sourcePath: '${tmp.path}/main.kl',
        ),
      ],
      pos,
    );
    final dir = tmp.path;
    File('$dir/libadd.a').writeAsStringSync('');
    final args = buildCcArgs(
      cPath: 'out/x.c',
      binPath: 'out/x',
      program: program,
      sourceDir: dir,
      cliLibs: const ['m'],
      cliLibDirs: const ['/opt/lib'],
    );
    expect(args.first, 'out/x.c');
    expect(args, contains('$dir/libadd.a'));
    final lOpt = args.indexOf('-L/opt/lib');
    final lm = args.indexOf('-lm');
    expect(lOpt, greaterThan(0));
    expect(lm, greaterThan(lOpt));
    expect(args.where((a) => a == '-lm').length, 2);
    expect(args.sublist(args.length - 2), ['-o', 'out/x']);
  });

  test('buildCcArgs puts CLI -L before @[link("-l…")]', () {
    const pos = SourcePos(1, 1);
    final program = Program(
      [],
      [
        FuncDecl(
          name: 'main',
          receiver: null,
          params: const [],
          returnTypeName: null,
          body: Block(const [], pos),
          pos: pos,
          attrs: [Attr('link', '-lfoo', pos)],
        ),
      ],
      pos,
    );
    final args = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
      cliLibDirs: const ['/libs'],
    );
    expect(args.indexOf('-L/libs'), lessThan(args.indexOf('-lfoo')));
  });

  test('buildCcArgs -g / debug passes host -g (issue 088)', () {
    const pos = SourcePos(1, 1);
    final program = Program(
      [],
      [
        FuncDecl(
          name: 'main',
          receiver: null,
          params: const [],
          returnTypeName: null,
          body: Block(const [], pos),
          pos: pos,
        ),
      ],
      pos,
    );
    final plain = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
    );
    expect(plain, isNot(contains('-g')));
    final debug = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
      debug: true,
    );
    expect(debug, contains('-g'));
    expect(debug.indexOf('-g'), lessThan(debug.indexOf('-o')));
  });

  test('normalizeCcOptFlag and buildCcArgs -O / --opt', () {
    expect(normalizeCcOptFlag('0'), '-O0');
    expect(normalizeCcOptFlag('2'), '-O2');
    expect(normalizeCcOptFlag('O3'), '-O3');
    expect(normalizeCcOptFlag('-Os'), '-Os');
    expect(normalizeCcOptFlag('z'), '-Oz');
    expect(normalizeCcOptFlag('Oz'), '-Oz');
    expect(normalizeCcOptFlag('S'), '-Os');
    expect(normalizeCcOptFlag('9'), isNull);
    expect(normalizeCcOptFlag('fast'), isNull);

    const pos = SourcePos(1, 1);
    final program = Program(
      [],
      [
        FuncDecl(
          name: 'main',
          receiver: null,
          params: const [],
          returnTypeName: null,
          body: Block(const [], pos),
          pos: pos,
        ),
      ],
      pos,
    );
    final plain = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
    );
    expect(plain.any((a) => a.startsWith('-O')), isFalse);
    final opt2 = buildCcArgs(
      cPath: 'a.c',
      binPath: 'a',
      program: program,
      sourceDir: tmp.path,
      debug: true,
      opt: normalizeCcOptFlag('2'),
    );
    expect(opt2, contains('-g'));
    expect(opt2, contains('-O2'));
    expect(opt2.indexOf('-g'), lessThan(opt2.indexOf('-O2')));
    expect(opt2.indexOf('-O2'), lessThan(opt2.indexOf('-o')));
  });

  test('cheader cimport skips C prototype emission', () {
    const source = '''
@[cinclude("regs.h")]
@[cimport, cheader, codename("pin_toggle")]
fn pin_toggle()
fn main() {
  pin_toggle()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'hdr.kl');
    expect(c, contains('#include "regs.h"'));
    expect(c, isNot(contains('void pin_toggle(void);')));
    expect(c, contains('pin_toggle();'));
  });

  test('klin run links @[cimport] against a static archive (issue 021)', () async {
    final addC = File('${tmp.path}/add.c');
    await addC.writeAsString('''
int add(int a, int b) { return a + b; }
''');
    final obj = '${tmp.path}/add.o';
    final archive = '${tmp.path}/libadd.a';
    final ccObj = await Process.run('gcc', ['-c', addC.path, '-o', obj]);
    expect(ccObj.exitCode, 0, reason: ccObj.stderr);
    final ar = await Process.run('ar', ['rcs', archive, obj]);
    expect(ar.exitCode, 0, reason: ar.stderr);

    final kl = File('${tmp.path}/use_add.kl');
    await kl.writeAsString('''
@[link("libadd.a")]
@[cimport, codename("add")]
fn add(a: i32, b: i32): i32

fn main() {
  printf("%d\\n", add(2, 3))
}
''');
    final result = await _compileAndRun(kl.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '5\n');
  });

  test('klin run links @[cimport] against an ASM unit (issue 022)', () async {
    final asm = File('${tmp.path}/add.S');
    await asm.writeAsString(r'''
#if defined(__APPLE__)
#  define ASM_ADD_SYM _asm_add
#else
#  define ASM_ADD_SYM asm_add
#endif
.globl ASM_ADD_SYM
ASM_ADD_SYM:
#if defined(__aarch64__) || defined(__arm64__)
        add     w0, w0, w1
        ret
#elif defined(__x86_64__)
        movl    %edi, %eax
        addl    %esi, %eax
        ret
#else
#  error unsupported arch
#endif
''');
    final kl = File('${tmp.path}/use_asm.kl');
    await kl.writeAsString('''
@[link("add.S")]
@[cimport, codename("asm_add")]
fn asm_add(a: i32, b: i32): i32

fn main() {
  printf("%d\\n", asm_add(2, 3))
}
''');
    final result = await _compileAndRun(kl.path, tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '5\n');
  });

  test('klin run -l/-L links a named library (issue 021)', () async {
    final addC = File('${tmp.path}/mylib.c');
    await addC.writeAsString('''
int mylib_answer(void) { return 42; }
''');
    final obj = '${tmp.path}/mylib.o';
    final archive = '${tmp.path}/libmylib.a';
    expect(
      (await Process.run('gcc', ['-c', addC.path, '-o', obj])).exitCode,
      0,
    );
    expect((await Process.run('ar', ['rcs', archive, obj])).exitCode, 0);

    final kl = File('${tmp.path}/use_mylib.kl');
    await kl.writeAsString('''
@[cimport, codename("mylib_answer")]
fn answer(): i32

fn main() {
  printf("%d\\n", answer())
}
''');
    final program = loadProject(kl.path);
    Checker().check(program);
    final cPath = '${tmp.path}/use_mylib.c';
    final binPath = '${tmp.path}/use_mylib';
    await File(cPath).writeAsString(emitC(program, kl.path));
    final args = buildCcArgs(
      cPath: cPath,
      binPath: binPath,
      program: program,
      sourceDir: tmp.path,
      cliLibs: const ['mylib'],
      cliLibDirs: [tmp.path],
    );
    final compile = await Process.run('gcc', args);
    expect(compile.exitCode, 0, reason: '${compile.stderr}${compile.stdout}');
    final run = await Process.run(binPath, []);
    expect(run.exitCode, 0, reason: run.stderr);
    expect(run.stdout, '42\n');
  });

  test('error: unknown C call without cimport (issue 021)', () {
    const source = '''
fn main() {
  unknown_c_fn(1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('unknown function') &&
            e.toString().contains('cimport'),
      )),
    );
  });

  test('host builtins puts/printf remain without cimport', () {
    const source = '''
fn main() {
  puts("hi")
  printf("%d\\n", 1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
  });

  test('STM32 example builds and exports SysTick_Handler', () async {
    final compiler = await Process.run(
      'sh',
      ['-c', 'command -v arm-none-eabi-gcc'],
    );
    if (compiler.exitCode != 0) return;

    const example = 'examples/stm32/blink_f411';
    addTearDown(
        () => Process.run('make', ['clean'], workingDirectory: example));
    final registers = await Process.run(
      'dart',
      [
        'run',
        'bin/svd2klin.dart',
        '--svd',
        'third_party/svd/stm32f411.svd',
        '--out-h',
        '$example/stm32f411_regs.h',
        '--out-kl',
        '$example/stm32f411_regs.kl',
        '--peripherals',
        'RCC,GPIOA,STK',
      ],
    );
    expect(registers.exitCode, 0, reason: registers.stderr.toString());
    final build = await Process.run('make', [], workingDirectory: example);
    expect(build.exitCode, 0, reason: '${build.stdout}${build.stderr}');

    final nm = await Process.run(
      'arm-none-eabi-nm',
      ['main.elf'],
      workingDirectory: example,
    );
    expect(nm.exitCode, 0, reason: nm.stderr.toString());
    expect(nm.stdout.toString(), contains('SysTick_Handler'));

    final objdump = await Process.run(
      'arm-none-eabi-objdump',
      ['-d', 'main.elf'],
      workingDirectory: example,
    );
    expect(objdump.exitCode, 0, reason: objdump.stderr.toString());
    final disasm = objdump.stdout.toString();
    expect(disasm, contains('<SysTick_Handler>'));
    // Fluent API must lower to static inline MMIO — no bl to accessors (027).
    final accessorBl = RegExp(
      r'bl\s+[0-9a-f]+\s+<(?:RCC_|GPIOA_|STK_)[^>]+>',
    );
    expect(accessorBl.hasMatch(disasm), isFalse, reason: disasm);
  });
}

Future<({int exitCode, String stdout, String stderr})> _compileAndRun(
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
