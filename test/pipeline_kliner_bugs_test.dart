@Tags(['unit'])
library;

import 'dart:io';

import 'package:klin/checker.dart';
import 'package:klin/diagnose.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/project.dart';
import 'package:test/test.dart';

void main() {
  test('puts and printf reject a byte string', () {
    expectCheck(
      'fn main() { puts(b"hi") }',
      '`puts` expects `str`, got `[]u8`',
    );
    expectCheck(
      'fn main() { puts(1) }',
      '`puts` expects `str`, got `i32`',
    );
    expectCheck(
      'fn main() { puts("a", "b") }',
      '`puts` expects 1 argument of type `str`, got 2',
    );
    expectCheck(
      'fn main() { printf(b"%d", 1) }',
      '`printf` expects a `str` format, got `[]u8`',
    );
    check('fn main() { puts("hi") }');
    check('fn main() { printf("%d\\n", 1 + 2) }');
    check('fn main() { let x = 1\n puts("hi \$x") }');
  });

  test('by-value struct cycle names the cycle', () {
    expectCheck('''
struct A { b: B }
struct B { a: A }
fn main() {}
''', 'struct cycle A -> B -> A has infinite size');
    expectCheck('''
struct A { a: A }
fn main() {}
''', 'struct cycle A -> A has infinite size');
    check('''
struct A { b: *B }
struct B { a: *A }
fn main() {}
''');
  });

  test('import errors name the imported file once', () {
    final dir = Directory.systemTemp.createTempSync('klin_diag_');
    try {
      final bad = File('${dir.path}/bad.kl');
      bad.writeAsStringSync('fn broken( {\n}\n');
      final mainPath = '${dir.path}/main.kl';
      File(mainPath).writeAsStringSync('import bad\nfn main() {}\n');
      ParseError? parseError;
      try {
        loadProject(mainPath);
      } on ParseError catch (e) {
        parseError = e;
      }
      expect(parseError, isNotNull);
      final parseShown = formatFrontendError(mainPath, parseError!);
      expect(parseShown, parseError.toString());
      expect('bad.kl'.allMatches(parseShown).length, 1);
      expect(parseShown.contains('main.kl:'), isFalse);

      bad.writeAsStringSync('pub fn boom() { let x: i32 = true }\n');
      File(mainPath).writeAsStringSync('''
import bad
fn main() { bad.boom() }
''');
      final program = loadProject(mainPath);
      CheckError? checkError;
      try {
        Checker().check(program);
      } on CheckError catch (e) {
        checkError = e;
      }
      expect(checkError, isNotNull);
      final checkShown = formatFrontendError(mainPath, checkError!);
      expect(checkShown, checkError.toString());
      expect(checkShown.contains('bad.kl'), isTrue);
      expect(checkShown.contains('main.kl:'), isFalse);
      expect(checkShown.split('bad.kl').length, 2);

      final spelled = '${dir.path}/./app.kl';
      File(spelled).writeAsStringSync('fn main() { let x: i32 = true }\n');
      CheckError? entryError;
      try {
        Checker().check(loadProject(spelled));
      } on CheckError catch (e) {
        entryError = e;
      }
      expect(entryError, isNotNull);
      final entryShown = formatFrontendError(spelled, entryError!);
      expect(entryShown.startsWith('$spelled:'), isTrue);
      expect('app.kl'.allMatches(entryShown).length, 1);
      final abs = entryError.path!;
      expect(entryShown.startsWith('$abs:$spelled'), isFalse);
      expect(entryShown.startsWith('$spelled:$abs'), isFalse);
    } finally {
      dir.deleteSync(recursive: true);
    }
  });

  test('f()! is a statement that discards the success value', () {
    const source = '''
fn step(ok: bool): !i32 {
  if !ok { return error(9) }
  return 3
}
fn run(ok: bool): !i32 {
  step(ok)!
  return 4
}
fn main() {}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'prop_stmt.kl');
    expect(c, contains('.is_err'));
    expect(c, contains('return '));
    expectCheck('''
fn step(): !i32 { return 1 }
fn main() { step()! }
''', 'postfix operator `!` requires a function returning `!T`');
  });

  test('let _ is a discard and can be repeated', () {
    const source = '''
struct P { a: i32
  b: i32 }
fn bump(): i32 { return 1 }
fn main() {
  let _ = bump()
  let _ = 2
  let p = P{ a: 3, b: 4 }
  let { a: _, b: _ } = p
  for _ := 0; false; _ = _ + 1 {}
}
''';
    final program = Parser(Lexer(source).tokenize()).parse();
    Checker().check(program);
    final c = emitC(program, 'discard.kl');
    expect(c, isNot(contains(' _;')));
    expect(c, contains('klin_val_'));
    expect(c, contains('(void)klin_val_'));
    expectCheck('''
fn main() {
  let _ = 1
  let y = _
}
''', 'unknown variable `_`');
    expectCheck('''
fn step(): !i32 { return 1 }
fn main() { let _ = step() }
''', 'must be handled with `!` or `or`');
  });

  test('let mut may hold read-only bytes and cannot write them', () {
    check('''
fn main() {
  let mut x = b"fn"
  let n = x.len
  let b = x[0]
  x = b"ok!"
  printf("%d %d\\n", n, b)
}
''');
    expectCheck('''
fn main() {
  let mut x = b"fn"
  x[0] = 1
}
''', 'cannot assign through read-only bytes');
    check('''
fn main() {
  let mut buf: [2]u8 = [1, 2]
  let mut x = b"fn"
  x = buf[:]
  x[0] = 9
}
''');
    expectCheck('''
let kw: []u8 = b"fn"
fn main() {
  let mut w = kw
  w[0] = 1
}
''', 'cannot assign through read-only bytes');
    expectCheck('''
fn main() {
  let mut x = b"fn"
  let p: *mut u8 = &x[0]
}
''', 'type mismatch: expected `*mut u8`, got `*u8`');
    check('''
fn main() {
  let mut buf: [2]u8 = [1, 2]
  let mut x = b"fn"
  x = buf[:]
  let p: *mut u8 = &x[0]
  *p = 9
}
''');
  });

  test('constant index of a fixed array must be in range', () {
    expectCheck('''
fn main() {
  let a: [3]i32 = [1, 2, 3]
  let n = a[5]
}
''', 'index 5 is out of range for `[3]i32`');
    expectCheck('''
fn main() {
  let a: [3]i32 = [1, 2, 3]
  let n = a[-1]
}
''', 'index -1 is out of range for `[3]i32`');
    expectCheck('''
const I: i32 = 1 + 4
fn main() {
  let a: [3]i32 = [1, 2, 3]
  let n = a[I]
}
''', 'index 5 is out of range for `[3]i32`');
    check('''
fn main() {
  let a: [3]i32 = [1, 2, 3]
  let n = a[2]
  let i = 5
  let m = a[i]
  printf("%d %d\\n", n, m)
}
''');
  });

  test('duplicate unguarded match arms are an error', () {
    expectCheck('''
fn main() {
  match 1 {
    1 { }
    1 { }
    else { }
  }
}
''', 'duplicate `match` pattern');
    expectCheck('''
fn main() {
  match 1 {
    1, 2 { }
    2, 1 { }
    else { }
  }
}
''', 'duplicate `match` pattern');
    expectCheck('''
fn main() {
  let x = match 1 {
    1 { 2 }
    1 + 0 { 3 }
    else { 4 }
  }
}
''', 'duplicate `match` pattern');
    expectCheck('''
enum Color { Red, Green }
fn main() {
  let c = Color.Red
  match c {
    Color.Red { }
    Color.Red { }
  }
}
''', 'duplicate `match` pattern');
    check('''
fn main() {
  match 1 {
    1 when true { }
    1 when false { }
    else { }
  }
}
''');
    check('''
fn main() {
  match 1 {
    1..=3 { }
    2 { }
    else { }
  }
}
''');
  });

  test('duplicate enum values are an error', () {
    expectCheck('''
enum E { A, A }
fn main() {}
''', 'duplicate enum variant');
    expectCheck('''
enum E { A = 1, B = 1 }
fn main() {}
''', 'duplicate enum value 1 (`B` and `A`)');
    expectCheck('''
enum E { A = 1, B = 0, C }
fn main() {}
''', 'duplicate enum value 1 (`C` and `A`)');
    check('''
enum E { Ok, Warn = 5, Err }
fn main() {}
''');
  });
}

void check(String source) {
  final program = Parser(Lexer(source).tokenize()).parse();
  Checker().check(program);
}

void expectCheck(String source, String fragment) {
  expect(
    () {
      final program = Parser(Lexer(source).tokenize()).parse();
      Checker().check(program);
    },
    throwsA(predicate(
      (e) => e is CheckError && e.toString().contains(fragment),
    )),
    reason: source,
  );
}
