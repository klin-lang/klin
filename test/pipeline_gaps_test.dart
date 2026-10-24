@Tags(['unit'])
library;

import 'package:klin/checker.dart';
import 'package:klin/emit_c.dart';
import 'package:klin/fmt.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/preprocess.dart';
import 'package:test/test.dart';

void main() {
  test('two expansions rename a plain helper and keep spliced names', () {
    final expanded = preprocess(r'''
$fn vec(name: name, T: type) {
struct $name { x: $T }
fn helper(v: $T): $T { return v }
fn id_$T(v: $T): $T { return helper(v) }
fn (p: $name) get(): $T { return helper(p.x) }
}
$vec(A, i32)
$vec(B, u8)
fn main() {}
''', path: 'box.kl');
    expect(expanded, contains('fn helper__vec_box_1(v: i32): i32'));
    expect(expanded, contains('fn helper__vec_box_2(v: u8): u8'));
    expect(expanded, contains('fn id_i32(v: i32): i32'));
    expect(expanded, contains('fn id_u8(v: u8): u8'));
    expect(expanded, contains('return helper__vec_box_1(v)'));
    expect(expanded, contains('return helper__vec_box_2(p.x)'));
    expect(expanded, contains('fn (p: A) get(): i32'));
    expect(expanded, contains('fn (p: B) get(): u8'));
    expect(expanded, isNot(contains('fn helper(')));
    check(expanded);
  });

  test('strings and comments are not renamed with the helper', () {
    final expanded = preprocess(r'''
$fn note(T: type) {
fn helper(): i32 {
  // helper stays
  puts("helper")
  return helper()
}
}
$note(i32)
fn main() {}
''', path: 'gaps.kl');
    expect(expanded, contains('// helper stays'));
    expect(expanded, contains('puts("helper")'));
    expect(expanded, contains('fn helper__note_gaps_1(): i32'));
    expect(expanded, contains('return helper__note_gaps_1()'));
    check(expanded);
  });

  test('a field spelled like the helper is rewritten with it', () {
    final expanded = preprocess(r'''
$fn box(T: type) {
struct S { helper: $T }
fn helper(v: $T): $T { return v }
fn (p: S) helper(): $T { return helper(p.helper) }
}
$box(i32)
fn main() {}
''', path: 'box.kl');
    expect(expanded, isNot(contains('struct S { helper:')));
    expect(expanded, contains('struct S { helper__box_box_1: i32 }'));
    expect(expanded, contains('fn (p: S) helper__box_box_1(): i32'));
    expect(expanded, contains('return helper__box_box_1(p.helper__box_box_1)'));
    check(expanded);
  });

  test(r'a $ splice in the function name stays stable', () {
    final expanded = preprocess(r'''
$fn pair(T: type) {
fn helper$T(v: $T): $T { return v }
fn id_$T(v: $T): $T { return helper$T(v) }
}
$pair(i32)
$pair(u8)
fn main() {}
''', path: 'box.kl');
    expect(expanded, contains('fn helperi32(v: i32): i32'));
    expect(expanded, contains('fn helperu8(v: u8): u8'));
    expect(expanded, contains('fn id_i32(v: i32): i32'));
    expect(expanded, isNot(contains('helper__')));
    check(expanded);
  });

  test('the same spliced name twice is still a redeclaration', () {
    expectCheck(r'''
$fn pair(T: type) {
fn id_$T(v: $T): $T { return v }
}
$pair(i32)
$pair(i32)
fn main() {}
''', 'redeclaration of function `id_i32`');
  });

  test('the file stem keeps helpers from two paths apart', () {
    const source = r'''
$fn note(T: type) {
fn helper(v: $T): $T { return v }
}
$note(i32)
fn main() {}
''';
    final a = preprocess(source, path: 'dir/a.kl');
    final b = preprocess(source, path: 'dir/b.kl');
    expect(a, contains('fn helper__note_a_1(v: i32): i32'));
    expect(b, contains('fn helper__note_b_1(v: i32): i32'));
  });

  test(r'a nested $macro keeps its name when a helper is spelled the same', () {
    final expanded = preprocess(r'''
$fn inner(T: type) {
fn note(): $T { return 1 }
}
$fn outer(T: type) {
fn inner(): i32 { return 2 }
$inner($T)
}
$outer(i32)
fn main() {}
''', path: 'gaps.kl');
    expect(expanded, contains('fn inner__outer_gaps_1(): i32'));
    expect(expanded, contains('fn note__inner_gaps_1(): i32'));
    expect(expanded, isNot(contains(r'$inner')));
    check(expanded);
  });

  test('a block argument calls the expansion-local helper', () {
    final expanded = preprocess(r'''
$fn wrap(body: block) {
fn helper(): i32 { return 1 }
fn go(): i32 {
$body
}
}
$wrap() {
  return helper()
}
fn main() {}
''', path: 'gaps.kl');
    expect(expanded, contains('return helper__wrap_gaps_1()'));
    expect(expanded, contains('fn helper__wrap_gaps_1(): i32'));
    check(expanded);
  });

  test('or { return } is accepted when the function returns void', () {
    check('''
fn g(): !i32 { return 1 }
fn main() {
  let n = g() or { return }
  printf("%d\\n", n)
}
''');
  });

  test('or { return value } matches the function, not the ok type', () {
    check('''
fn g(): !i32 { return 1 }
fn f(): i32 {
  let n = g() or { return 4 }
  return n
}
fn h(): !i32 {
  let n = g() or { return error(err) }
  return n
}
fn k(): !i32 {
  let n = g()!
  return n + 1
}
fn main() {}
''');
  });

  test('or { break } and or { continue } leave the enclosing loop', () {
    check('''
fn g(): !i32 { return error(1) }
fn f(): i32 {
  let mut i = 0
  while i < 2 {
    let n = g() or { break }
    i = n
  }
  while i < 2 {
    let n = g() or { continue }
    return n
  }
  return 0
}
fn main() {}
''');
  });

  test('both arms of if, and an exhaustive match, may diverge', () {
    check('''
fn g(): !i32 { return error(1) }
fn f(): i32 {
  let n = g() or {
    if err == 1 { return 2 }
    return 3
  }
  let m = g() or {
    match 1 {
      1 { return 8 }
      else { return 9 }
    }
  }
  return n + m
}
fn main() {}
''');
  });

  test('while true and for ;; diverge the or', () {
    check('''
fn g(): !i32 { return error(1) }
fn f(): i32 {
  let n = g() or { while true { return 4 } }
  let m = g() or { for ;; { return 5 } }
  return n + m
}
fn main() {}
''');
  });

  test('error: empty or and a non-diverging or', () {
    expectCheck('''
fn g(): !i32 { return 1 }
fn f(): i32 {
  let n = g() or { }
  return n
}
fn main() {}
''', '`or` block must end with a value');
    expectCheck('''
fn g(): !i32 { return 1 }
fn f(): i32 {
  let n = g() or { if true { return 1 } }
  return n
}
fn main() {}
''', '`or` block must end with a value');
    expectCheck('''
fn g(): !i32 { return 1 }
fn f(): i32 {
  let n = g() or { while true { break } }
  return n
}
fn main() {}
''', '`or` block must end with a value');
    expectCheck('''
fn g(): !i32 { return 1 }
fn f(): i32 {
  let n = g() or { while 1 == 1 { return 1 } }
  return n
}
fn main() {}
''', '`or` block must end with a value');
    expectCheck('''
fn g(): !i32 { return 1 }
fn f(): i32 {
  let n = g() or {
    match 1 {
      1 { return 1 }
    }
  }
  return n
}
fn main() {}
''', '`or` block must end with a value');
  });

  test('error: return in or is checked against the function', () {
    expectCheck('''
fn g(): !i32 { return 1 }
fn f(): i32 {
  let n = g() or { return }
  return n
}
fn main() {}
''', 'function `f` must return `i32`');
    expectCheck('''
fn g(): !i32 { return 1 }
fn f() {
  let n = g() or { return 1 }
  printf("%d\\n", n)
}
fn main() {}
''', 'void function cannot return a value');
    expectCheck('''
fn g(): !i32 { return 1 }
fn f(): !i32 {
  let n = g() or { return }
  return n
}
fn main() {}
''', 'function `f` must return `!i32`');
    expectCheck('''
fn g(): !i32 { return 1 }
fn f(): i32 {
  let n = g() or { return error(1) }
  return n
}
fn main() {}
''', 'type mismatch: expected `i32`, got `error`');
    expectCheck('''
fn g(): !i32 { return 1 }
fn f(): i32 {
  let n = g() or { break }
  return n
}
fn main() {}
''', '`break` outside a loop');
    expectCheck('''
fn g(): i32 { return 1 }
fn f(): i32 {
  let n = g() or { return 1 }
  return n
}
fn main() {}
''', 'left side of `or` must have type `!T`');
    expectCheck('''
fn g(): !i32 { return 1 }
fn f(): i32 {
  let n = g()!
  return n
}
fn main() {}
''', 'postfix operator `!` requires a function returning `!T`');
  });

  test('error: unclosed or block', () {
    expect(
      () => Parser(Lexer('fn main() {\n  let n = 1 or {\n').tokenize()).parse(),
      throwsA(predicate(
        (e) => e is ParseError && e.toString().contains('unclosed `or` block'),
      )),
    );
  });

  test('fmt keeps a diverging or on one line', () {
    final formatted = formatSource('''
fn g(): !i32 { return 1 }
fn f(): i32 {
let n = g() or { return 1 }
return n
}
fn main() {}
''');
    expect(formatted, contains('or { return 1 }'));
    final bare = formatSource('''
fn g(): !i32 { return 1 }
fn main() {
let n = g() or { return }
printf("%d\\n", n)
}
''');
    expect(bare, contains('or { return }'));
  });

  test('s.len and s[i] emit strlen and a u8 load', () {
    final c = emitOf('''
fn main() {
  let s = "hi"
  printf("%d\\n", s.len)
  printf("%d\\n", s[1])
}
''');
    expect(c, contains('#include <string.h>'));
    expect(c, contains('(int32_t)strlen('));
    expect(c, contains('(uint8_t *)'));
  });

  test('indexing a str does not pull in string.h', () {
    final c = emitOf('''
fn main() {
  let s = "hi"
  printf("%d\\n", s[0])
}
''');
    expect(c, contains('(uint8_t *)'));
    expect(c, isNot(contains('strlen')));
    expect(c, isNot(contains('string.h')));
  });

  test('cstr_u8 evaluates its argument once', () {
    final c = emitOf('''
fn id(s: str): str { return s }
fn main() {
  let v = cstr_u8(id("ab"))
  printf("%d\\n", cast(i32, v.len))
  cstr_u8("zz")
}
''');
    expect(c, contains('#include <string.h>'));
    expect('id("ab")'.allMatches(c), hasLength(1));
    expect(c, contains('strlen(klin_val_'));
    expect(c, contains('(void)klin_val_'));
  });

  test('a user fn cstr_u8 hides the builtin', () {
    final c = emitOf('''
fn cstr_u8(s: str): i32 { return 4 }
fn main() {
  let n = cstr_u8("ab")
  printf("%d\\n", n)
}
''');
    expect(c, isNot(contains('strlen')));
    expect(c, contains('cstr_u8('));
  });

  test('str bytes are read-only', () {
    expectCheck('''
fn main() {
  let s = "ab"
  s[0] = 1
}
''', 'cannot assign through a string (`str` is read-only)');
    expectCheck('''
fn main() {
  let mut s = "ab"
  s[0] = 1
}
''', 'cannot assign through a string (`str` is read-only)');
    expectCheck('''
fn main() {
  let s = "ab"
  s.len = 1
}
''', '`len` is read-only');
    expectCheck('''
fn main() {
  let s = "ab"
  let n = s.foo
  printf("%d\\n", n)
}
''', '`str` has no field `foo`');
    expectCheck('''
fn main() {
  let s = "ab"
  let t = s[0:1]
  printf("%d\\n", t[0])
}
''', '`str` has no subslice');
    expectCheck('''
fn main() {
  let s = "ab"
  let p: *mut u8 = &s[0]
  printf("%d\\n", *p)
}
''', 'type mismatch: expected `*mut u8`, got `*u8`');
    check('''
fn main() {
  let mut s = "ab"
  let p: *u8 = &s[0]
  printf("%d\\n", *p)
}
''');
    expectCheck('''
fn main() {
  let mut w = cstr_u8("ab")
  printf("%d\\n", w[0])
}
''', 'cannot bind read-only bytes');
    expectCheck('''
fn main() {
  let mut buf: [2]u8 = [1, 2]
  let mut s = buf[:]
  s = cstr_u8("ab")
}
''', 'cannot assign read-only bytes');
    expectCheck('''
fn main() {
  cstr_u8("ab")[0] = 1
}
''', 'cannot assign through an immutable slice');
    expectCheck('''
fn main() {
  let mut p = cstr_u8("ab")[0:1]
  printf("%d\\n", p[0])
}
''', 'cannot bind read-only bytes');
    expectCheck('''
fn main() {
  let n = cstr_u8(1)
  printf("%d\\n", n)
}
''', '`cstr_u8` expects `str`, got `untyped int`');
    expectCheck('''
fn main() {
  let s = "ab"
  let n = cstr_u8()
  printf("%d %s\\n", n, s)
}
''', '`cstr_u8` expects 1 argument, got 0');
  });
}

void check(String source) {
  final program = Parser(Lexer(source).tokenize()).parse();
  Checker().check(program);
}

void expectCheck(String source, String fragment) {
  final expanded = preprocess(source, path: 'gaps.kl');
  expect(
    () {
      final program = Parser(Lexer(expanded).tokenize()).parse();
      Checker().check(program);
    },
    throwsA(predicate(
      (e) => e is CheckError && e.toString().contains(fragment),
    )),
  );
}

String emitOf(String source) {
  final program = Parser(Lexer(source).tokenize()).parse();
  Checker().check(program);
  return emitC(program, 'gaps.kl');
}
