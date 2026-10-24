@Tags(['unit'])
library;

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/fmt.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/project.dart';
import 'package:test/test.dart';

void main() {
  test('parser accepts module-level let and let mut', () {
    const source = '''
let mut n: i32 = 1
let limit: i32
fn main() {}
''';
    final unit = Parser(Lexer(source).tokenize()).parseUnit();
    expect(unit.globals, hasLength(2));
    expect(unit.globals[0].isMut, isTrue);
    expect(unit.globals[0].name, 'n');
    expect(unit.globals[0].init, isNotNull);
    expect(unit.globals[1].isMut, isFalse);
    expect(unit.globals[1].init, isNull);
  });

  test('fmt keeps a module-level let', () {
    const source = '''
pub let mut n: i32 = 1
let limit: i32 = 2

fn main() {
    n = limit
}
''';
    final once = formatSource(source);
    expect(once, contains('pub let mut n: i32 = 1'));
    expect(once, contains('let limit: i32 = 2'));
    expect(formatSource(once), once);
  });

  test('error: module-level let binds one name', () {
    const source = '''
let mut { x } = p
fn main() {}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(predicate(
          (e) => e is ParseError && e.toString().contains('binds one name'))),
    );
  });

  test('error: module-level let requires a type', () {
    const source = '''
let mut n = 1
fn main() {}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(predicate((e) =>
          e is ParseError && e.toString().contains('after global name'))),
    );
  });

  test('error: := is not a module-level declaration', () {
    const source = '''
n := 1
fn main() {}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(predicate((e) =>
          e is ParseError &&
          e.toString().contains('struct, enum, const, let, or function'))),
    );
  });

  test('error: non-constant global initializer', () {
    const source = '''
fn next(): i32 { return 1 }
let mut n: i32 = next()
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('must be a constant expression'))),
    );
  });

  test('error: a global value is not a constant initializer', () {
    const source = '''
let mut a: i32 = 1
let mut b: i32 = a
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('must be a constant expression'))),
    );
  });

  test('address of let is *T and address of let mut is *mut T', () {
    const source = '''
let n: i32 = 1
let mut m: i32 = 2
fn main() {
    let p: *i32 = &n
    let q: *mut i32 = &m
    printf("%d %d\\n", *p, *q)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    const bad = '''
let n: i32 = 1
fn main() {
    let p: *mut i32 = &n
    printf("%d\\n", *p)
}
''';
    final badProgram = Parser(Lexer(bad).tokenize()).parse();
    expect(
      () => Checker().check(badProgram),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('type mismatch'))),
    );
  });

  test('error: assign to an immutable global', () {
    const source = '''
let n: i32 = 1
fn main() { n = 2 }
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('cannot assign to immutable variable `n`'))),
    );
  });

  test('error: assign to a field of an immutable global', () {
    const source = '''
struct P { x: i32 }
let p: P = P{ x: 1 }
fn main() { p.x = 2 }
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('immutable variable'))),
    );
  });

  test('error: a global cannot have type !T', () {
    const source = '''
let mut r: !i32
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('cannot have type `!i32`'))),
    );
  });

  test('error: attributes are not allowed on a global', () {
    const source = '''
@[cexport]
let mut n: i32 = 1
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('attributes are not allowed on a global'))),
    );
  });

  test('error: global conflicts with a constant', () {
    const source = '''
const N: i32 = 1
let mut N: i32 = 2
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('conflicts with constant'))),
    );
  });

  test('error: global conflicts with a function', () {
    const source = '''
let mut inc: i32 = 1
fn inc(): i32 { return inc }
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('conflicts with global'))),
    );
  });

  test('error: a global is not an array length', () {
    const source = '''
let mut n: i32 = 4
fn main() {
    let xs: [n]i32
    printf("%d\\n", xs.len)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('unknown constant `n`'))),
    );
  });

  test('error: private imported global', () {
    final program = loadProject('test/global_mod/bad.kl');
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('global `store.hidden` is private'))),
    );
  });

  test('error: cannot assign an imported immutable global', () {
    final overwritten = loadProject('test/global_mod/write_limit.kl');
    expect(
      () => Checker().check(overwritten),
      throwsA(predicate((e) =>
          e is CheckError &&
          e
              .toString()
              .contains('cannot assign to immutable variable `store.limit`'))),
    );
  });

  test('scalar globals emit static storage, a folded const, and an async use',
      () {
    final program = loadProject('test/global_scalar/app.kl');
    Checker().check(program);
    final c = emitC(program, 'test/global_scalar/app.kl');
    expect(c, contains('static int32_t app_n;'));
    expect(c, contains('static int32_t app_n = 1;'));
    expect(c, contains('static int32_t app_limit = 7;'));
    expect(c, contains('static bool app_flag = true;'));
    expect(c, contains('static const char* app_msg = "ok";'));
    expect(
      c,
      contains('static klin_slice_u8 app_bytes = { (uint8_t *)"ab", 2 };'),
    );
    expect(c, contains('static int32_t * app_p = &(app_n);'));
    expect(c, contains('static int32_t app_zero = 0;'));
    expect(c, contains('18446744073709551615ULL'));
    expect(c, contains('(-9223372036854775807LL - 1)'));
    // The async poll reads the global, not a state-struct field.
    expect(c, contains('app_n = (app_n + 10);'));
    expect(c, isNot(contains('st->n')));
    final slice = c.indexOf('typedef struct { uint8_t *ptr; size_t len; }');
    final global = c.indexOf('static klin_slice_u8 app_bytes');
    expect(slice, greaterThanOrEqualTo(0));
    expect(global, greaterThan(slice));
    expect(c, contains('(*app_missing)(int32_t) = 0;'));
    expect(c, isNot(contains('(*app_missing)(int32_t) = NULL')));
    final proto = c.indexOf('int32_t app_inc(int32_t x);');
    final op = c.indexOf('(*app_op)(int32_t) = app_inc;');
    expect(proto, greaterThanOrEqualTo(0));
    expect(op, greaterThan(proto));
  });

  test('immutable []u8 global is read-only; mutable global slice still binds',
      () {
    const mutable = '''
let mut bytes: []u8 = b"ab"
fn main() {
  let mut w = bytes
  w = bytes
  printf("%d\\n", w.len)
}
''';
    expect(
      () => Checker().check(Parser(Lexer(mutable).tokenize()).parse()),
      returnsNormally,
    );

    const source = '''
let mut n: i32 = 1
let kw: []u8 = b"fn"
fn main() {
  let s = kw
  n = n + s.len
  printf("%d %d\\n", n, kw[0])
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'global_kw.kl');
    expect(c, contains('static klin_slice_u8 kw = { (uint8_t *)"fn", 2 };'));
    expect(c, contains('n = (n + s.len);'));
    expect(c, isNot(contains('st->n')));
    expect(c, isNot(contains('st->kw')));
  });

  test('error: imported immutable []u8 global cannot bind let mut', () {
    final program = loadProject('test/global_ro/app.kl');
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('cannot bind read-only bytes'))),
    );
  });

  test('aggregate globals are emitted after their types, forwards first', () {
    final program = loadProject('test/global_agg/app.kl');
    Checker().check(program);
    final c = emitC(program, 'test/global_agg/app.kl');
    final structDef = c.indexOf('typedef struct app_Point');
    final point = c.indexOf('static app_Point app_pt =');
    expect(structDef, greaterThanOrEqualTo(0));
    expect(point, greaterThan(structDef));
    final forwardLater = c.indexOf('static int32_t app_later;');
    final useLater = c.indexOf('static int32_t * app_p = &(app_later);');
    expect(forwardLater, greaterThanOrEqualTo(0));
    expect(useLater, greaterThan(forwardLater));
    expect(c, contains('static app_Point app_origin = {0};'));
    expect(c, contains('static klin_slice_i32 app_view = { app_xs, 3 };'));
    expect(c, contains('static klin_slice_i32 app_empty = { NULL, 0 };'));
  });

  test('pub global is not static; private global is', () {
    final program = loadProject('test/global_mod/app.kl');
    Checker().check(program);
    final c = emitC(program, 'test/global_mod/app.kl');
    expect(c, contains('int32_t store_count = 1;'));
    expect(c, isNot(contains('static int32_t store_count')));
    expect(c, contains('int32_t store_limit = 10;'));
    expect(c, contains('static int32_t store_hidden = 5;'));
    expect(c, contains('static int32_t app_count = 10;'));
    expect(c, contains('store_Point store_point = { .x = 1, .y = 2 };'));
  });

  test('for-loop header assigns a global, and an imported fn is an initializer',
      () {
    final program = loadProject('test/global_mod/fn.kl');
    Checker().check(program);
    final c = emitC(program, 'test/global_mod/fn.kl');
    expect(c, contains('for (fnapp_n = 1; (fnapp_n < 4); fnapp_n += 1)'));
    expect(c, contains('(*fnapp_op)(int32_t) = store_inc;'));
    expect(c, contains('(*fnapp_missing)(int32_t) = 0;'));
  });

  test('error: a global shadows an import qualifier', () {
    final program = loadProject('test/global_mod/shade.kl');
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('field access requires a struct'))),
    );
  });

  test('error: private imported function is not a global initializer', () {
    final program = loadProject('test/global_mod/bad_fn.kl');
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('function `store.hidden_fn` is private'))),
    );
  });

  test('error: for-loop cannot assign an immutable global', () {
    const source = '''
let limit: i32 = 1
fn main() {
    for limit = 0; limit < 1; limit += 1 {
    }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e
              .toString()
              .contains('cannot assign to immutable variable `limit`'))),
    );
  });

  test('error: calling a non-function global', () {
    const source = '''
let mut n: i32 = 1
fn main() {
    n(1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('`n` is not a function'))),
    );
  });

  test('global subslice of an array is a constant brace initializer', () {
    const source = '''
module app
let mut xs: [5]i32 = [10, 20, 30, 40, 50]
let mut mid: []i32 = xs[1:4]
let mut tail: []i32 = xs[3:]
let mut head: []i32 = xs[:2]
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'global_subslice_unit.kl');
    expect(
      c,
      contains(
        'static klin_slice_i32 mid = { (xs) + (size_t)(1), ((size_t)(4) - (size_t)(1)) };',
      ),
    );
    expect(
      c,
      contains(
        'static klin_slice_i32 tail = { (xs) + (size_t)(3), ((5) - (size_t)(3)) };',
      ),
    );
    expect(
      c,
      contains('static klin_slice_i32 head = { xs, (size_t)(2) };'),
    );
  });

  test('error: a slice global is not a constant slice source', () {
    const source = '''
let mut xs: [3]i32 = [1, 2, 3]
let mut view: []i32 = xs[:]
let mut again: []i32 = view[:]
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('must be a constant expression'))),
    );
  });

  test('error: a global subslice bound must be a constant', () {
    const source = '''
fn one(): i32 { return 1 }
let mut xs: [3]i32 = [1, 2, 3]
let mut mid: []i32 = xs[one():]
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('must be a constant expression'))),
    );
  });
}
