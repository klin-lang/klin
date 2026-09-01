@Tags(['unit'])
library;

import 'package:klin/analyze.dart';
import 'package:klin/complete.dart';
import 'package:test/test.dart';

AnalysisResult _ok(String source) {
  final result = analyzeSource(
    path: 'c.kl',
    source: source,
    requireMain: false,
  );
  expect(result.diagnostics, isEmpty, reason: '${result.diagnostics}');
  expect(result.program, isNotNull);
  return result;
}

/// 1-based line/col of the insertion point after [needle] on its first match.
(int, int) _after(String source, String needle) {
  final i = source.indexOf(needle);
  expect(i, greaterThanOrEqualTo(0), reason: 'missing `$needle`');
  final end = i + needle.length;
  var line = 1;
  var col = 1;
  for (var j = 0; j < end; j++) {
    if (source[j] == '\n') {
      line++;
      col = 1;
    } else {
      col++;
    }
  }
  return (line, col);
}

void main() {
  group('completeAt', () {
    test('suggests keywords and top-level names', () {
      const source = '''
struct Point { x: i32 y: i32 }
fn helper(): void {
}
fn main(): void {
    let a: i32 = 1
}
''';
      final result = _ok(source);
      final (line, col) = _after(source, 'let a: i32 = ');
      final items = completeAt(result, line, col, source: source);
      final labels = items.map((i) => i.label).toSet();
      expect(labels, contains('fn'));
      expect(labels, contains('helper'));
      expect(labels, contains('Point'));
      expect(labels, contains('i32'));
    });

    test('suggests locals in scope', () {
      const source = '''
fn main(): void {
    let x: i32 = 1
    let y: i32 = x
}
''';
      final result = _ok(source);
      final (line, col) = _after(source, 'let y: i32 = ');
      final items = completeAt(result, line, col, source: source);
      expect(items.map((i) => i.label), contains('x'));
    });

    test('does not suggest locals from another function', () {
      const source = '''
fn helper(): void {
    let secret: i32 = 1
}
fn main(): void {
    let a: i32 = 1
}
''';
      final result = _ok(source);
      final (line, col) = _after(source, 'let a: i32 = ');
      final labels =
          completeAt(result, line, col, source: source).map((i) => i.label);
      expect(labels, contains('a'));
      expect(labels, isNot(contains('secret')));
    });

    test('if-arm locals do not leak into the other arm', () {
      const source = '''
fn main(): void {
    if true {
        let onlyThen: i32 = 1
    } else {
        let onlyElse: i32 = 2
        let z: i32 = onlyElse
    }
}
''';
      final result = _ok(source);
      final (line, col) = _after(source, 'let z: i32 = ');
      final labels = completeAt(result, line, col, source: source)
          .map((i) => i.label)
          .toSet();
      expect(labels, contains('onlyElse'));
      expect(labels, isNot(contains('onlyThen')));
    });

    test('loop variable is not suggested after the loop', () {
      const source = '''
fn main(): void {
    for i in 0..<3 {
        let inside: i32 = i
    }
    let after: i32 = 1
}
''';
      final result = _ok(source);
      final (line, col) = _after(source, 'let after: i32 = ');
      final labels = completeAt(result, line, col, source: source)
          .map((i) => i.label)
          .toSet();
      expect(labels, contains('after'));
      expect(labels, isNot(contains('i')));
      expect(labels, isNot(contains('inside')));
    });

    test('member type uses enclosing-function binding', () {
      const source = '''
struct Point { x: i32 y: i32 }
struct Box { w: i32 h: i32 }
fn helper(): void {
    let p: Box = Box{ w: 1, h: 2 }
    let _u: i32 = p.w
}
fn main(): void {
    let p: Point = Point{ x: 1, y: 2 }
    let z: i32 = p.x
}
''';
      final result = _ok(source);
      final (line, col) = _after(source, 'let z: i32 = p.');
      final labels = completeAt(result, line, col, source: source)
          .map((i) => i.label)
          .toSet();
      expect(labels, containsAll(['x', 'y']));
      expect(labels, isNot(contains('w')));
      expect(labels, isNot(contains('h')));
    });

    test('filters by identifier prefix', () {
      const source = '''
fn foo(): void {
}
fn bar(): void {
}
fn main(): void {
    foo()
}
''';
      final result = _ok(source);
      final (line, col) = _after(source, '    fo');
      final items = completeAt(result, line, col, source: source);
      final labels = items.map((i) => i.label).toList();
      expect(labels, contains('foo'));
      expect(labels, contains('for'));
      expect(labels, isNot(contains('bar')));
    });

    test('member completion after dot uses fallback program', () {
      const good = '''
struct Point { x: i32 y: i32 }
fn main(): void {
    let p: Point = Point{ x: 1, y: 2 }
    let z: i32 = p.x
}
''';
      final goodResult = _ok(good);

      const broken = '''
struct Point { x: i32 y: i32 }
fn main(): void {
    let p: Point = Point{ x: 1, y: 2 }
    let z: i32 = p.
}
''';
      final brokenResult = analyzeSource(
        path: 'c.kl',
        source: broken,
        requireMain: false,
      );
      // Trailing `p.` is a parse error; recovery may still yield a partial AST.
      expect(brokenResult.diagnostics, isNotEmpty);

      final (line, col) = _after(broken, 'let z: i32 = p.');
      final items = completeAt(
        brokenResult,
        line,
        col,
        source: broken,
        fallbackProgram: goodResult.program,
      );
      final labels = items.map((i) => i.label).toSet();
      expect(labels, contains('x'));
      expect(labels, contains('y'));
    });

    test('enum variant completion after Type.', () {
      const source = '''
enum Color { Red, Green, Blue }
fn main(): void {
    let c: Color = Color.Red
}
''';
      final result = _ok(source);
      final (line, col) = _after(source, 'let c: Color = Color.');
      final items = completeAt(result, line, col, source: source);
      final labels = items.map((i) => i.label).toSet();
      expect(labels, containsAll(['Red', 'Green', 'Blue']));
    });

    test(r'completion works after $fn expand via source map', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let a: i32 = 1
}
''';
      final result = analyzeSource(
        path: 'c.kl',
        source: source,
        requireMain: false,
      );
      expect(result.positionsSkewed, isFalse);
      expect(result.sourceMap, isNotNull);
      final (line, col) = _after(source, 'let a: i32 = ');
      final labels = completeAt(result, line, col, source: source)
          .map((i) => i.label)
          .toSet();
      expect(labels, contains('a'));
      expect(labels, contains('Vec2i'));
    });
  });
}
