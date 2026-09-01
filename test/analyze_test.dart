@Tags(['unit'])
library;

import 'dart:io';

import 'package:klin/analyze.dart';
import 'package:klin/fmt.dart';
import 'package:klin/lexer.dart';
import 'package:klin/parser.dart';
import 'package:klin/token.dart';
import 'package:test/test.dart';

void main() {
  group('analyzeSource', () {
    test('clean library file has no diagnostics when requireMain is false', () {
      const source = '''
fn foo(): void {
}
''';
      final result = analyzeSource(
        path: 'lib_foo.kl',
        source: source,
        requireMain: false,
      );
      expect(result.diagnostics, isEmpty);
      expect(result.program, isNotNull);
    });

    test('parse error yields diagnostic with line/col', () {
      const source = '''
fn foo(): void {
''';
      final result = analyzeSource(path: 'bad.kl', source: source);
      expect(result.diagnostics, isNotEmpty);
      final d = result.diagnostics.first;
      expect(d.path, 'bad.kl');
      expect(d.message, isNotEmpty);
      expect(d.pos.line, greaterThanOrEqualTo(1));
      expect(d.pos.col, greaterThanOrEqualTo(1));
    });

    test('parse recovery reports multiple decl errors (issue 092)', () {
      const source = '''
fn broken( {
fn ok(): void {
}
fn also_broken( {
''';
      final result = analyzeSource(
        path: 'multi_parse.kl',
        source: source,
        requireMain: false,
      );
      expect(result.diagnostics.length, greaterThanOrEqualTo(2));
      expect(result.program, isNotNull);
      expect(result.hasParseErrors, isTrue);
      expect(
        result.program!.funcs.any((f) => f.name == 'ok'),
        isTrue,
        reason: 'recovery should keep the valid `ok` function',
      );
    });

    test('LSP overlay path still uses parse recovery (issue 092)', () {
      final dir = Directory.systemTemp.createTempSync('klin_092_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      const source = '''
fn broken( {
fn ok(): void {
}
fn also_broken( {
''';
      final file = File('${dir.path}/multi_parse.kl')
        ..writeAsStringSync(source);
      final abs = file.absolute.path;
      final result = analyzeSource(
        path: abs,
        source: source,
        requireMain: false,
        sourceOverlay: {abs: source},
      );
      expect(result.diagnostics.length, greaterThanOrEqualTo(2));
      expect(result.program, isNotNull);
      expect(
        result.program!.funcs.any((f) => f.name == 'ok'),
        isTrue,
      );
    });

    test('LSP overlay keeps project-level ParseError without path', () {
      final dir = Directory.systemTemp.createTempSync('klin_092_alias_');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final b = File('${dir.path}/b.kl')
        ..writeAsStringSync('module b\nfn fb(): void {}\n');
      final c = File('${dir.path}/c.kl')
        ..writeAsStringSync('module c\nfn fc(): void {}\n');
      final a = File('${dir.path}/a.kl')
        ..writeAsStringSync('''
module a
import "b" x
import "c" x
fn main(): void {
}
''');
      final absA = a.absolute.path;
      final result = analyzeSource(
        path: absA,
        source: a.readAsStringSync(),
        requireMain: false,
        sourceOverlay: {
          absA: a.readAsStringSync(),
          b.absolute.path: b.readAsStringSync(),
          c.absolute.path: c.readAsStringSync(),
        },
      );
      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.any((d) => d.message.contains('already bound')),
        isTrue,
        reason: 'must not swallow pathless project ParseError via fall-through',
      );
    });

    test('LSP overlay does not fall through on same-basename foreign parse', () {
      final root = Directory.systemTemp.createTempSync('klin_092_base_');
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      final app = Directory('${root.path}/app')..createSync();
      final lib = Directory('${root.path}/lib')..createSync();
      final foreign = File('${lib.path}/main.kl')
        ..writeAsStringSync('fn broken( {\n');
      final open = File('${app.path}/main.kl')
        ..writeAsStringSync('''
import "../lib/main" util
fn main(): void {
}
''');
      // Call with relative basename so a naive sameDiagnosticPath(path)
      // would match the foreign file.
      final result = analyzeSource(
        path: open.path,
        source: open.readAsStringSync(),
        requireMain: false,
        sourceOverlay: {
          open.absolute.path: open.readAsStringSync(),
          foreign.absolute.path: foreign.readAsStringSync(),
        },
      );
      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.any(
          (d) =>
              d.message.contains('expected') ||
              sameDiagnosticPath(d.path, foreign.absolute.path),
        ),
        isTrue,
        reason: 'foreign same-basename syntax error must not be dropped',
      );
    });

    test('parse recovery reports stmt error and keeps later stmts', () {
      const source = '''
fn main(): void {
    let = 1
    let y: i32 = 2
}
''';
      final result = analyzeSource(path: 'stmt.kl', source: source);
      expect(result.diagnostics, isNotEmpty);
      expect(result.program, isNotNull);
    });

    test('CLI-style Parser remains fail-fast without collectErrors', () {
      const source = '''
fn broken( {
fn ok(): void {
}
''';
      expect(
        () => Parser(Lexer(source).tokenize()).parse(),
        throwsA(isA<ParseError>()),
      );
    });

    test('check error keeps program for navigation', () {
      const source = '''
fn main(): void {
    let x: NoSuchType = 1
}
''';
      final result = analyzeSource(
        path: 'check.kl',
        source: source,
        requireMain: true,
      );
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.message, contains('NoSuchType'));
      expect(result.program, isNotNull);
    });

    test('requireMain true reports missing main', () {
      const source = '''
fn foo(): void {
}
''';
      final withMain = analyzeSource(
        path: 'lib.kl',
        source: source,
        requireMain: true,
      );
      expect(withMain.diagnostics, hasLength(1));
      expect(withMain.diagnostics.single.message, contains('main'));

      final without = analyzeSource(
        path: 'lib.kl',
        source: source,
        requireMain: false,
      );
      expect(without.diagnostics, isEmpty);
    });

    test('check error after macro expand remaps via source map', () {
      const source = r'''
$fn point(name: name, T: type) {
  struct $name { x: $T y: $T }
}
$point(Vec2i, i32)
fn main(): void {
  let bad: NoSuch = 1
}
''';
      final result = analyzeSource(path: 'skew.kl', source: source);
      expect(result.diagnostics, hasLength(1));
      expect(result.positionsSkewed, isFalse);
      expect(result.sourceMap, isNotNull);
      final d = result.diagnostics.single;
      expect(d.message, contains('NoSuch'));
      expect(d.message, isNot(contains('after preprocess')));
      // Squiggle on the editor line with `NoSuch`, not line 1.
      expect(d.pos.line, 6);
    });

    test('collects check errors from multiple functions', () {
      const source = '''
fn a(): void {
    let x: NoSuchA = 1
}
fn b(): void {
    let y: NoSuchB = 1
}
''';
      final result = analyzeSource(
        path: 'multi.kl',
        source: source,
        requireMain: false,
      );
      expect(result.diagnostics.length, greaterThanOrEqualTo(2));
      final messages = result.diagnostics.map((d) => d.message).join('\n');
      expect(messages, contains('NoSuchA'));
      expect(messages, contains('NoSuchB'));
      expect(result.program, isNotNull);
    });

    test('diagnosticForOpenDocument rewrites foreign paths', () {
      const foreign = KlinDiagnostic(
        message: 'boom',
        pos: SourcePos(3, 4),
        path: '/other/macros.kl',
      );
      final attributed = diagnosticForOpenDocument(foreign, '/app/main.kl');
      expect(attributed.path, '/app/main.kl');
      expect(attributed.pos.line, 1);
      expect(attributed.pos.col, 1);
      expect(attributed.message, contains('/other/macros.kl'));
      expect(attributed.message, contains('boom'));
    });

    test('sameDiagnosticPath does not equate distinct dirs by basename', () {
      expect(sameDiagnosticPath('/a/main.kl', '/b/main.kl'), isFalse);
      expect(sameDiagnosticPath('main.kl', '/proj/main.kl'), isTrue);
      expect(sameDiagnosticPath('/proj/main.kl', 'main.kl'), isTrue);
      expect(sameDiagnosticPath('/proj/main.kl', '/proj/main.kl'), isTrue);
    });

    test('same-basename foreign diagnostic is pinned, not line-mapped', () {
      const foreign = KlinDiagnostic(
        message: 'boom',
        pos: SourcePos(10, 3),
        path: '/lib/util/main.kl',
      );
      final attributed = diagnosticForOpenDocument(foreign, '/app/main.kl');
      expect(attributed.pos.line, 1);
      expect(attributed.pos.col, 1);
      expect(attributed.message, contains('/lib/util/main.kl'));
    });
  });

  group('formatDocument helper', () {
    test('formatSource is idempotent on a small snippet', () {
      const ugly = 'fn foo():void{let x:i32=1}';
      final once = formatSource(ugly);
      final twice = formatSource(once);
      expect(twice, once);
      expect(once, contains('fn foo'));
    });

    test('formatSource throws on invalid input (LSP returns empty edits)', () {
      expect(() => formatSource('fn {'), throwsA(anything));
    });
  });
}
