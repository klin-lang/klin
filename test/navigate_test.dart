@Tags(['unit'])
library;

import 'package:klin/analyze.dart';
import 'package:test/test.dart';

void main() {
  group('hover + definition', () {
    test('hover and goto local variable', () {
      const source = '''
fn main(): void {
    let x: i32 = 1
    let y: i32 = x
}
''';
      final result = analyzeSource(
        path: 'nav.kl',
        source: source,
        requireMain: true,
      );
      expect(result.diagnostics, isEmpty);
      expect(result.program, isNotNull);

      // Declaration site: `x` in `let x`.
      final declLine = 2;
      final declCol = source.split('\n')[declLine - 1].indexOf('x') + 1;
      expect(hoverAt(result, declLine, declCol), contains('x: i32'));
      final self = definitionAt(result, declLine, declCol);
      expect(self, isNotNull);
      expect(self!.pos.line, declLine);
      expect(self.pos.col, declCol);

      // Use site: `x` on the `let y` line.
      final useLine = 3;
      final useCol = source.split('\n')[useLine - 1].indexOf('x') + 1;
      final hover = hoverAt(result, useLine, useCol);
      expect(hover, contains('x:'));
      expect(hover, contains('i32'));

      final def = definitionAt(result, useLine, useCol);
      expect(def, isNotNull);
      expect(def!.pos.line, declLine);
      expect(def.pos.col, declCol);
    });

    test('hover and goto function call', () {
      const source = '''
fn add(a: i32, b: i32): i32 {
    return a + b
}
fn main(): void {
    let z: i32 = add(1, 2)
}
''';
      final result = analyzeSource(
        path: 'nav_fn.kl',
        source: source,
        requireMain: true,
      );
      expect(result.diagnostics, isEmpty);

      final callLine = 5;
      final callCol = source.split('\n')[callLine - 1].indexOf('add') + 1;
      final hover = hoverAt(result, callLine, callCol);
      expect(hover, contains('add'));
      expect(hover, contains('i32'));

      final def = definitionAt(result, callLine, callCol);
      expect(def, isNotNull);
      expect(def!.pos.line, 1);
    });

    test('hover field access', () {
      const source = '''
struct Point {
    x: i32
    y: i32
}
fn main(): void {
    let p: Point = Point { x: 1, y: 2 }
    let a: i32 = p.x
}
''';
      final result = analyzeSource(
        path: 'nav_field.kl',
        source: source,
        requireMain: true,
      );
      expect(result.diagnostics, isEmpty);

      final line = 7;
      final col = source.split('\n')[line - 1].indexOf('.x') + 2; // on `x`
      final hover = hoverAt(result, line, col);
      expect(hover, contains('x:'));
      expect(hover, contains('i32'));

      final def = definitionAt(result, line, col);
      expect(def, isNotNull);
      expect(def!.pos.line, 2);
    });

    test(r'nav works after $fn expand via source map', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let v: Vec2i = Vec2i { x: 1, y: 2 }
  let a: i32 = v.x
}
''';
      final result = analyzeSource(path: 'skew_nav.kl', source: source);
      expect(result.positionsSkewed, isFalse);
      expect(result.sourceMap, isNotNull);
      expect(result.diagnostics, isEmpty);
      // `v` on the `let a` line (editor coords).
      final hover = hoverAt(result, 7, 16);
      expect(hover, isNotNull);
      expect(hover, contains('Vec2i'));
      final def = definitionAt(result, 7, 16);
      expect(def, isNotNull);
      expect(def!.pos.line, 6);
    });
  });
}
