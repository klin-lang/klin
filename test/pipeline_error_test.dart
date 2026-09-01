@Tags(['unit'])
library;

import 'dart:io';

import 'package:klin/checker.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/project.dart';
import 'package:test/test.dart';


void main() {
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

  test('error: logical op rejects int (issue 097)', () {
    const source = 'fn main() { let x = 1 && true }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('requires type `bool`'))),
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

  test('error: %= rejects float', () {
    const source = 'fn main() { let mut x: f64 = 1.0\n x %= 2.0 }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('requires integer'))),
    );
  });

  test('error: for post rejects *= (issue 152)', () {
    expect(
      () => Parser(Lexer('''
fn main() {
    for i := 0; i < 3; i *= 2 { }
}
''').tokenize()).parse(),
      throwsA(predicate((e) =>
          e is ParseError && e.toString().contains('expected `=`, `+=`, or `-=`'))),
    );
  });

  test('error: for-init := when name already in scope (issue 151)', () {
    const source = '''
fn main() {
    x := 9
    for x := 10; x < 20; x = x + 1 { }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('already in scope'))),
    );
  });

  test('error: for-init = without prior binding (issue 151)', () {
    const source = '''
fn main() {
    for i = 0; i < 3; i = i + 1 { }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('unknown variable `i`'))),
    );
  });

  test('error: for-init = to immutable (issue 151)', () {
    const source = '''
fn main() {
    let i = 0
    for i = 1; i < 3; i = i + 1 { }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('immutable variable `i`'))),
    );
  });

  test('error: := without initializer', () {
    expect(
      () => Parser(Lexer('fn main() { x := }').tokenize()).parse(),
      throwsA(isA<ParseError>()),
    );
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

  test('error: numeric cast rejects bool (issue 154)', () {
    const source = '''
fn main() {
  let x: i32 = cast(i32, true)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('numeric cast requires an integer or float'))),
    );
  });

  test('error: numeric cast rejects float literal to integer (issue 154)', () {
    const source = '''
fn main() {
  let x: i32 = cast(i32, 1.5)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('float literal to integer'))),
    );
  });

  test('error: cast rejects float to enum (issue 154)', () {
    const source = '''
enum Color { Red, Green }
fn main() {
  let c: Color = cast(Color, cast(f64, 1))
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains('cast to enum requires an integer'))),
    );
  });

  test('error: cast rejects struct target (issue 154)', () {
    const source = '''
struct P { x: i32 }
fn main() {
  let p = cast(P, 1)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError &&
          e.toString().contains(
              'cast supports pointer, enum↔integer, or numeric conversions'))),
    );
  });

  test('error: no implicit i32 to i64 assign (issue 154)', () {
    const source = '''
fn main() {
  let a: i32 = 1
  let b: i64 = a
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate((e) =>
          e is CheckError && e.toString().contains('type mismatch'))),
    );
  });

  test('error: bare error(n) without !T context (issue 132)', () {
    const source = 'fn main() { let x = error(1) }';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError && e.toString().contains('needs a `!T` context')),
      ),
    );
  });

  test('error: match with only error arms cannot infer !T (issue 132)', () {
    const source = '''
fn main() {
    let x = match 1 {
        else { error(1) }
    } or { 0 }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('at least one success arm')),
      ),
    );
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

  test('error: enum match statement is not exhaustive (issue 129)', () {
    const source = '''
enum Color { Red, Green, Blue }
fn main() {
    let c: Color = Color.Red
    match c {
        Color.Red { }
        Color.Green { }
    }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('not exhaustive') &&
            e.toString().contains('`Blue`')),
      ),
    );
  });

  test('error: enum match expression is not exhaustive (issue 129)', () {
    const source = '''
enum Color { Red, Green, Blue }
fn main() {
    let c: Color = Color.Red
    let n = match c {
        Color.Red { 1 }
        Color.Green { 2 }
    }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('not exhaustive') &&
            e.toString().contains('`Blue`')),
      ),
    );
  });

  test('error: when guard does not cover an enum variant (issue 129)', () {
    const source = '''
enum Color { Red, Green }
fn main() {
    let c: Color = Color.Red
    match c {
        Color.Red when 1 == 1 { }
        Color.Green { }
    }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('not exhaustive') &&
            e.toString().contains('`Red`')),
      ),
    );
  });

  test('error: runtime enum value does not cover a variant (issue 129)', () {
    const source = '''
enum Color { Red, Green }
fn main() {
    let c: Color = Color.Red
    let other: Color = Color.Green
    match c {
        other { }
    }
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(
        predicate((e) =>
            e is CheckError &&
            e.toString().contains('not exhaustive') &&
            e.toString().contains('`Red`') &&
            e.toString().contains('`Green`')),
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

  test('error: match requires at least one arm', () {
    expect(
      () => Parser(Lexer('fn main() { match 1 { } }').tokenize()).parse(),
      throwsA(isA<ParseError>()),
    );
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

  test('error: interpolated string in let needs a sink', () {
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
              e is CheckError && e.toString().contains('fmt.write'),
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

}
