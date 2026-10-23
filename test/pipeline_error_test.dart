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

  test('error: assign through a byte-string literal', () {
    const source = '''
fn main() {
  b"fn"[0] = 65
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('byte-string literal'),
      )),
    );
  });

  test('error: const without a type', () {
    const source = '''
const N = 1
fn main() {}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(predicate(
        (e) => e is ParseError && e.toString().contains('after constant name'),
      )),
    );
  });

  test('error: const type must be integer, bool, or []u8', () {
    const source = '''
const X: f64 = 1.5
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('integer, bool, or []u8'),
      )),
    );
  });

  test('error: const initializer must be a constant expression', () {
    const source = '''
fn one(): i32 { return 1 }
const N: i32 = one()
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains(
                'integer constant must be an integer constant expression'),
      )),
    );
  });

  test('error: bool const must be true or false', () {
    const source = '''
const F: bool = 1
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError && e.toString().contains('true or false'),
      )),
    );
  });

  test('error: assign to a constant', () {
    const source = '''
const N: i32 = 1
fn main() {
  N = 2
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError && e.toString().contains('cannot assign to constant'),
      )),
    );
  });

  test('error: assign through a []u8 constant', () {
    const source = '''
const S: []u8 = b"ab"
fn main() {
  S[0] = 1
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('cannot assign through a constant'),
      )),
    );
  });

  test('error: private imported const', () {
    final program = loadProject('test/const_mod/bad.kl');
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('constant `os.HIDDEN` is private'),
      )),
    );
  });

  test('error: unknown escape in a byte string', () {
    const source = '''
fn main() {
  let s = b"\\q"
}
''';
    expect(
      () => Lexer(source).tokenize(),
      throwsA(predicate(
        (e) => e is LexError && e.toString().contains('unknown escape'),
      )),
    );
  });

  test('error: attribute on a module const', () {
    const source = '''
@[cexport]
const X: i32 = 1

fn main() {
  printf("%d\\n", X)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('attributes are not allowed on a constant'),
      )),
    );
  });
  test('error: mutating method through a non-mut pointer', () {
    const source = '''
struct Out {
  n: i32
}
struct Ctx {
  err: Out
}
fn (mut o: Out) add() {
  o.n = 1
}
fn main() {
  let mut ctx = Ctx{ err: Out{ n: 0 } }
  let c: *Ctx = &ctx
  (*c).err.add()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('cannot write through an immutable pointer'),
      )),
    );
  });

  test('error: mutating method on a let mut pointer that is not *mut', () {
    const source = '''
struct Out {
  n: i32
}
fn (mut o: Out) add() {
  o.n = 1
}
fn main() {
  let mut o = Out{ n: 0 }
  let mut p: *Out = &o
  (*p).add()
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('cannot write through an immutable pointer'),
      )),
    );
  });

  test('error: & through a non-mut pointer is not *mut', () {
    const source = '''
struct Out {
  n: i32
}
struct Ctx {
  err: Out
}
fn main() {
  let mut ctx = Ctx{ err: Out{ n: 0 } }
  let c: *Ctx = &ctx
  let p: *mut Out = &(*c).err
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('type mismatch') &&
            e.toString().contains('*mut Out'),
      )),
    );
  });

  test('error: & of a reborrow through *T is not *mut', () {
    const source = '''
struct Ctx {
  n: i32
}
fn main() {
  let mut ctx = Ctx{ n: 0 }
  let c: *Ctx = &ctx
  let p: *mut Ctx = &(*c)
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('type mismatch') &&
            e.toString().contains('*mut Ctx'),
      )),
    );
  });

  test('error: negative const array length', () {
    const source = '''
const NEG: i32 = -100
struct S {
  data: [NEG]i32
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('array length `NEG` must be non-negative'),
      )),
    );
  });

  test('error: bool const array length', () {
    const source = '''
const FLAG: bool = true
fn main() {
  let buf: [FLAG]u8
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains(
                'array length `FLAG` must be an integer constant, got `bool`'),
      )),
    );
  });

  test('error: []u8 const array length', () {
    const source = '''
const KW: []u8 = b"fn"
fn take(xs: [KW]u8) {}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains(
                'array length `KW` must be an integer constant, got `[]u8`'),
      )),
    );
  });

  test('error: unknown const array length', () {
    const source = '''
fn main() {
  let buf: [NOPE]u8
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError && e.toString().contains('unknown constant `NOPE`'),
      )),
    );
  });

  test('error: local is not an array length', () {
    const source = '''
fn main() {
  let N: i32 = 4
  let buf: [N]u8
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains('unknown constant `N`'),
      )),
    );
  });

  test('error: array length expression is not a constant', () {
    const source = '''
fn main() {
  let buf: [1 + missing]u8
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('unknown constant `missing`'),
      )),
    );
  });

  test('error: private imported const array length', () {
    final program = loadProject('test/const_len_mod/bad_private.kl');
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('constant `os.HIDDEN` is private'),
      )),
    );
  });

  test('error: imported bool const array length', () {
    final program = loadProject('test/const_len_mod/bad_bool.kl');
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('array length `os.FLAG` must be an integer'),
      )),
    );
  });

  test('error: imported negative const array length', () {
    final program = loadProject('test/const_len_mod/bad_neg.kl');
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('array length `os.NEG` must be non-negative'),
      )),
    );
  });

  test('error: imported []u8 const array length', () {
    final program = loadProject('test/const_len_mod/bad_bytes.kl');
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('array length `os.KW` must be an integer'),
      )),
    );
  });

  void expectRange(String source, String fragment) {
    final program = Parser(Lexer(source).tokenize()).parse();
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) => e is CheckError && e.toString().contains(fragment),
      )),
    );
  }

  test('error: const u8 literal is out of range', () {
    expectRange('''
const X: u8 = 300
fn main() {}
''', 'integer literal `300` is out of range for `u8` (0..=255)');
  });

  test('error: let u8 literal is out of range', () {
    expectRange('''
fn main() {
  let x: u8 = 300
}
''', 'integer literal `300` is out of range for `u8` (0..=255)');
  });

  test('error: negative const does not fit unsigned', () {
    expectRange('''
const X: u8 = -1
fn main() {}
''', 'integer literal `-1` is out of range for `u8` (0..=255)');
  });

  test('error: hex literal does not fit u8', () {
    expectRange('''
const X: u8 = 0x12C
fn main() {}
''', 'integer literal `0x12C` is out of range for `u8` (0..=255)');
  });

  test('error: i8 literal above 127', () {
    expectRange('''
fn main() {
  let x: i8 = 128
}
''', 'integer literal `128` is out of range for `i8` (-128..=127)');
  });

  test('error: const i8 negative literal below the minimum', () {
    expectRange('''
const X: i8 = -129
fn main() {}
''', 'integer literal `-129` is out of range for `i8` (-128..=127)');
  });

  test('error: default i32 literal is out of range', () {
    expectRange('''
fn main() {
  let x = 3000000000
}
''', 'integer literal `3000000000` is out of range for `i32`');
  });

  test('error: enum variant literal does not fit the base type', () {
    expectRange('''
enum E: u8 { A = 300 }
fn main() {}
''', 'integer literal `300` is out of range for `u8` (0..=255)');
  });

  test('error: automatic enum variant overflows u8', () {
    expectRange('''
enum E: u8 { A = 255, B }
fn main() {}
''', 'enum variant `B` value 256 is out of range for `u8` (0..=255)');
  });

  test('error: automatic enum variant overflows i8', () {
    expectRange('''
enum E: i8 { A = 127, B }
fn main() {}
''', 'enum variant `B` value 128 is out of range for `i8` (-128..=127)');
  });

  test('error: automatic enum variant overflows a later variant', () {
    expectRange('''
enum E: u8 { A = 254, B, C }
fn main() {}
''', 'enum variant `C` value 256 is out of range for `u8` (0..=255)');
  });

  test('error: automatic enum variant overflows i64', () {
    expectRange('''
enum E: i64 { A = 9223372036854775807, B }
fn main() {}
''', 'enum variant `B` value 9223372036854775808 is out of range for `i64`');
  });

  test('error: return literal does not fit', () {
    expectRange('''
fn f(): u8 { return 300 }
fn main() {}
''', 'integer literal `300` is out of range for `u8`');
  });

  test('error: argument literal does not fit the parameter', () {
    expectRange('''
fn f(x: u8) {}
fn main() { f(0b1_0000_0000) }
''', 'integer literal `0b1_0000_0000` is out of range for `u8`');
  });

  test('error: field literal does not fit', () {
    expectRange('''
struct S { n: i8 }
fn main() {
  let s = S{ n: 200 }
}
''', 'integer literal `200` is out of range for `i8`');
  });

  test('error: i32 array element literal does not fit', () {
    expectRange('''
fn main() {
  let xs: [1]i32 = [3000000000]
}
''', 'integer literal `3000000000` is out of range for `i32`');
  });

  test('error: let negative literal does not fit unsigned', () {
    expectRange('''
fn main() {
  let x: u8 = -1
}
''', 'integer literal `-1` is out of range for `u8` (0..=255)');
  });

  test('error: negated literal below i8 minimum', () {
    expectRange('''
fn main() {
  let x: i8 = -129
}
''', 'integer literal `-129` is out of range for `i8` (-128..=127)');
  });

  test('error: complement operand does not fit the target type', () {
    expectRange('''
const M: i8 = ~128
fn main() {}
''', 'integer literal `128` is out of range for `i8` (-128..=127)');
  });

  test('error: complement of a literal is not a float', () {
    expectRange('''
fn main() {
  let x: f64 = ~0
}
''', 'operator `~` requires an integer type, got `f64`');
  });

  test('error: folded const is out of range', () {
    expectRange('''
const X: u8 = 200 + 100
fn main() {}
''', 'integer literal `300` is out of range for `u8` (0..=255)');
  });

  test('error: const division by zero', () {
    expectRange('''
const X: i32 = 1 / 0
fn main() {}
''', 'division by zero');
  });

  test('error: const remainder by zero', () {
    expectRange('''
const X: i32 = 1 % (2 - 2)
fn main() {}
''', 'remainder by zero');
  });

  test('error: const shift by a negative count', () {
    expectRange('''
const X: i32 = 1 << -1
fn main() {}
''', 'shift by a negative count');
  });

  test('error: const shift wider than the type', () {
    expectRange('''
const X: i32 = 1 << 32
fn main() {}
''', 'shift by `32` is wider than `i32` (width 32)');
  });

  test('error: negative shift count on u8 fails the range check', () {
    expectRange('''
const X: u8 = 1 << -1
fn main() {}
''', 'integer literal `-1` is out of range for `u8` (0..=255)');
  });

  test('error: i8 subtraction does not wrap the operand', () {
    expectRange('''
const X: i8 = 0 - 128
fn main() {}
''', 'integer literal `128` is out of range for `i8` (-128..=127)');
  });

  test('error: const names a different integer type', () {
    expectRange('''
const A: i32 = 1
const B: u8 = A
fn main() {}
''', 'type mismatch: expected `u8`, got `i32`');
  });

  test('error: const cycle', () {
    expectRange('''
const A: i32 = B
const B: i32 = A
fn main() {}
''', 'constant `A` depends on itself');
  });

  test('error: unknown const in an initializer', () {
    expectRange('''
const X: i32 = NOPE
fn main() {}
''', 'unknown constant `NOPE`');
  });

  test('error: const names a module that is not imported', () {
    expectRange('''
const X: i32 = os.PAGE
fn main() {}
''', 'module `os` is not imported');
  });

  test('error: u64 literal above the type does not fit', () {
    expectRange('''
const X: u64 = 18446744073709551616
fn main() {}
''', 'integer literal `18446744073709551616` is out of range for `u64`');
  });

  test('error: array literal element does not fit the contextual type', () {
    expectRange('''
fn main() {
  let a: [2]u8 = [1, 300]
}
''', 'integer literal `300` is out of range for `u8` (0..=255)');
  });

  test('error: nested array literal element does not fit', () {
    expectRange('''
fn main() {
  let a: [1][1]u8 = [[300]]
}
''', 'integer literal `300` is out of range for `u8` (0..=255)');
  });

  test('error: array literal length does not match', () {
    expectRange('''
fn main() {
  let a: [3]u8 = [1, 2]
}
''', 'type mismatch: expected `[3]u8`, got `[2]i32`');
  });

  test('error: array element sum is out of range', () {
    expectRange('''
fn main() {
  let a: [1]u8 = [200 + 100]
}
''', 'integer literal `300` is out of range for `u8` (0..=255)');
  });

  test('error: array literal argument element does not fit', () {
    expectRange('''
fn take(xs: [1]i8) {}
fn main() { take([200]) }
''', 'integer literal `200` is out of range for `i8`');
  });

  test('error: struct field array literal element does not fit', () {
    expectRange('''
struct Row { xs: [1]u8 }
fn main() {
  let row = Row{ xs: [300] }
}
''', 'integer literal `300` is out of range for `u8`');
  });

  test('error: address of an immutable slice element is not *mut', () {
    expectRange('''
fn main() {
  let xs: [2]i32 = [1, 2]
  let p: *mut i32 = &xs[:][0]
}
''', 'type mismatch: expected `*mut i32`, got `*i32`');
  });

  test('error: cannot assign through an immutable slice', () {
    expectRange('''
fn main() {
  let mut xs: [2]u8 = [1, 2]
  let s = xs[:]
  s[0] = 9
}
''', 'cannot assign through an immutable slice');
  });

  test('error: cannot assign through a slice parameter', () {
    expectRange('''
fn f(s: []u8) { s[0] += 1 }
fn main() {}
''', 'cannot assign through an immutable slice');
  });

  test('error: slice index of an immutable array cannot be assigned', () {
    expectRange('''
fn main() {
  let xs: [2]u8 = [1, 2]
  xs[:][0] = 9
}
''', 'cannot assign to an immutable array');
  });

  test('error: immutable slice binding does not yield *mut', () {
    expectRange('''
fn main() {
  let mut xs: [2]i32 = [1, 2]
  let s = xs[:]
  let p: *mut i32 = &s[0]
}
''', 'type mismatch: expected `*mut i32`, got `*i32`');
  });

  test('error: slice parameter element address is not *mut', () {
    expectRange('''
fn first(s: []i32): *mut i32 { return &s[0] }
fn main() {}
''', 'type mismatch: expected `*mut i32`, got `*i32`');
  });

  test('error: address through *[]T is not *mut', () {
    expectRange('''
fn at(p: *[]i32): *mut i32 { return &(*p)[0] }
fn main() {}
''', 'type mismatch: expected `*mut i32`, got `*i32`');
  });

  test('error: let of a sum is out of range', () {
    expectRange('''
fn main() {
  let x: u8 = 200 + 100
}
''', 'integer literal `300` is out of range for `u8` (0..=255)');
  });

  test('error: let subtraction does not wrap the operand', () {
    expectRange('''
fn main() {
  let x: i8 = 0 - 128
}
''', 'integer literal `128` is out of range for `i8` (-128..=127)');
  });

  test('error: let division by zero', () {
    expectRange('''
fn main() {
  let x: i32 = 1 / 0
}
''', 'division by zero');
  });

  test('error: let names a constant of a different integer type', () {
    expectRange('''
const A: i32 = 1
fn main() {
  let x: u8 = A + 1
}
''', 'type mismatch: expected `u8`, got `i32`');
  });

  test('error: let shift wider than the type', () {
    expectRange('''
fn main() {
  let x: i32 = 1 << 40
}
''', 'shift by `40` is wider than `i32` (width 32)');
  });

  test('error: argument sum is out of range', () {
    expectRange('''
fn take(n: u8) {}
fn main() { take(200 + 100) }
''', 'integer literal `300` is out of range for `u8`');
  });

  test('error: return sum is out of range', () {
    expectRange('''
fn f(): u8 { return 200 + 100 }
fn main() {}
''', 'integer literal `300` is out of range for `u8`');
  });

  test('error: field sum is out of range', () {
    expectRange('''
struct S { n: u8 }
fn main() {
  let s = S{ n: 200 + 100 }
}
''', 'integer literal `300` is out of range for `u8`');
  });

  test('error: negative array length expression', () {
    expectRange('''
fn main() {
  let buf: [0 - 1]i32
}
''', 'array length `0 - 1` must be non-negative');
  });

  test('error: array length above 2^63-1', () {
    expectRange('''
const N: u64 = ~0 + 0
fn main() {
  let buf: [N]u8
}
''', 'array length `N` is too large');
  });

  test('error: array length mixes integer const types', () {
    expectRange('''
const A: i32 = 1
const B: i64 = 2
fn main() {
  let buf: [A + B]u8
}
''', 'type mismatch: `i32` and `i64`');
  });

  test('error: private imported const in a constant expression', () {
    final program = loadProject('test/const_fold_mod/bad_private.kl');
    expect(
      () => Checker().check(program),
      throwsA(predicate(
        (e) =>
            e is CheckError &&
            e.toString().contains('constant `os.HIDDEN` is private'),
      )),
    );
  });

  test('error: function cannot return a zero-length array', () {
    expectRange('''
fn z(): [0]u8 { return [1] }
fn main() {}
''', 'function cannot return a zero-length array `[0]u8`');
  });

  test('error: nested zero-length array cannot be returned', () {
    expectRange('''
fn z(): [1][0]u8 { return [[]] }
fn main() {}
''', 'function cannot return a zero-length array `[1][0]u8`');
  });

  test('error: function type cannot return a zero-length array', () {
    expectRange('''
fn main() {
  let f: fn(): [0]u8
}
''', 'function cannot return a zero-length array `[0]u8`');
  });

  test('error: result type cannot wrap an array', () {
    expectRange('''
fn f(): ![2]u8 { return error(1) }
fn main() {}
''', 'invalid result type `![2]u8`');
  });

  test('error: return array element must be bound first', () {
    expectRange('''
fn row(a: [2][2]u8, i: i32): [2]u8 { return a[i] }
fn main() {}
''', 'cannot use this array expression here (bind it to a variable first)');
  });

  test('error: copying a C array into a let still needs a literal', () {
    expectRange('''
fn main() {
  let a: [2]u8 = [1, 2]
  let b = a
}
''', 'array initialization requires a `[...]` literal');
  });

  test('error: array literal in a returned array is range-checked', () {
    expectRange('''
fn f(): [1]u8 { return [200 + 100] }
fn main() {}
''', 'integer literal `300` is out of range for `u8` (0..=255)');
  });

  test('error: struct field cannot be a function returning an array of structs', () {
    expectRange('''
struct Pair { n: u8 }
struct Bad { f: fn(): [1]Pair }
fn main() {}
''', 'a struct field cannot be a function that returns an array of structs');
  });

  test('error: async fn cannot return an array', () {
    const source = '''
async fn f(): [2]u8 {}
fn main() {}
''';
    expect(
      () => Parser(Lexer(source).tokenize()).parse(),
      throwsA(predicate((e) =>
          e is ParseError &&
          e.toString().contains('async fn MVP returns void'))),
    );
  });

  test('error: let shift by a negative count', () {
    expectRange('''
fn main() {
  let x: i32 = 1 << -1
}
''', 'shift by a negative count');
  });

  test('error: empty array literal needs a type', () {
    expectRange('''
fn main() {
  let a = []
}
''', 'empty array literal needs a type, for example `[0]u8`');
  });

  test('error: empty array literal has length 0', () {
    expectRange('''
fn main() {
  let a: [2]u8 = []
}
''', 'empty array literal has length 0, expected `[2]u8`');
  });

  test('error: empty array literal is not a scalar', () {
    expectRange('''
fn main() {
  let x: u8 = []
}
''', 'empty array literal needs an array type, for example `[0]u8`');
  });

  test('error: return of empty array into a non-zero array', () {
    expectRange('''
fn f(): [2]u8 { return [] }
fn main() {}
''', 'empty array literal has length 0, expected `[2]u8`');
  });

  test('error: nested empty array length mismatch names [0]', () {
    expectRange('''
fn main() {
  let a: [2][0]u8 = [[]]
}
''', 'type mismatch: expected `[2][0]u8`, got `[1][0]`');
  });
}
