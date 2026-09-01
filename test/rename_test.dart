@Tags(['unit'])
library;

import 'dart:io';

import 'package:klin/analyze.dart';
import 'package:klin/ast.dart';
import 'package:klin/navigate.dart';
import 'package:klin/rename.dart';
import 'package:klin/token.dart';
import 'package:test/test.dart';

void main() {
  group('renameAt', () {
    test('renames local variable at declaration and uses', () {
      const source = '''
fn main(): void {
    let x: i32 = 1
    let y: i32 = x
}
''';
      final result = analyzeSource(
        path: 'r.kl',
        source: source,
        requireMain: false,
      );
      expect(result.diagnostics, isEmpty);
      // Cursor on `x` in `let x`
      final xCol = source.split('\n')[1].indexOf('x') + 1;
      final edits = renameAt(
        result,
        2,
        xCol,
        'z',
        openPath: 'r.kl',
      );
      expect(edits, isNotNull);
      final texts = edits!.map((e) => '${e.pos.line}:${e.pos.col}->${e.newText}');
      expect(edits.length, greaterThanOrEqualTo(2));
      expect(edits.every((e) => e.newText == 'z'), isTrue);
      expect(texts, isNotEmpty);
    });

    test('prepareRename returns range for a local', () {
      const source = '''
fn main(): void {
    let x: i32 = 1
}
''';
      final result = analyzeSource(
        path: 'r.kl',
        source: source,
        requireMain: false,
      );
      final xCol = source.split('\n')[1].indexOf('x') + 1;
      final prep = prepareRenameAt(result, 2, xCol, openPath: 'r.kl');
      expect(prep, isNotNull);
      expect(prep!.placeholder, 'x');
      expect(prep.length, 1);
    });

    test('rejects invalid identifier', () {
      const source = '''
fn main(): void {
    let x: i32 = 1
}
''';
      final result = analyzeSource(
        path: 'r.kl',
        source: source,
        requireMain: false,
      );
      final xCol = source.split('\n')[1].indexOf('x') + 1;
      expect(
        renameAt(result, 2, xCol, '1bad', openPath: 'r.kl'),
        isNull,
      );
    });

    test('cross-file rename puts call-site edit in open file', () {
      final dir = Directory.systemTemp.createTempSync('klin_rename_xf_');
      addTearDown(() => dir.deleteSync(recursive: true));

      final lib = File('${dir.path}/util.kl')
        ..writeAsStringSync('''
module util
pub fn helper(): i32 {
    return 1
}
''');
      final main = File('${dir.path}/main.kl')
        ..writeAsStringSync('''
import util
fn main(): void {
    let x: i32 = util.helper()
}
''');
      final overlay = {
        lib.absolute.path: lib.readAsStringSync(),
        main.absolute.path: main.readAsStringSync(),
      };
      final result = analyzeSource(
        path: main.path,
        source: main.readAsStringSync(),
        sourceOverlay: overlay,
      );
      expect(result.diagnostics, isEmpty);

      final lines = main.readAsStringSync().split('\n');
      final callLine = lines.indexWhere((l) => l.contains('util.helper'));
      final col = lines[callLine].indexOf('helper') + 1;
      final edits = renameAt(
        result,
        callLine + 1,
        col,
        'assist',
        openPath: main.absolute.path,
      );
      expect(edits, isNotNull);
      expect(edits!.length, greaterThanOrEqualTo(2));

      final mainEdits = edits
          .where((e) => File(e.path).absolute.path == main.absolute.path)
          .toList();
      final libEdits = edits
          .where((e) => File(e.path).absolute.path == lib.absolute.path)
          .toList();
      expect(mainEdits, isNotEmpty,
          reason: 'call site must be edited in main.kl, not util.kl');
      expect(libEdits, isNotEmpty, reason: 'definition in util.kl');
      expect(
        mainEdits.every((e) => e.pos.line == callLine + 1),
        isTrue,
      );
    });

    test('does not rename same-line locals across files', () {
      final dir = Directory.systemTemp.createTempSync('klin_rename_collide_');
      addTearDown(() => dir.deleteSync(recursive: true));

      // Identical layout so `let x` shares line/col in both files.
      const body = '''
fn go(): void {
    let x: i32 = 1
}
''';
      final a = File('${dir.path}/a.kl')
        ..writeAsStringSync('module a\npub $body');
      final b = File('${dir.path}/b.kl')
        ..writeAsStringSync('module b\npub $body');
      final main = File('${dir.path}/main.kl')
        ..writeAsStringSync('''
import a
import b
fn main(): void {
    a.go()
    b.go()
}
''');
      final overlay = {
        a.absolute.path: a.readAsStringSync(),
        b.absolute.path: b.readAsStringSync(),
        main.absolute.path: main.readAsStringSync(),
      };
      final result = analyzeSource(
        path: main.path,
        source: main.readAsStringSync(),
        sourceOverlay: overlay,
      );
      expect(result.diagnostics, isEmpty);

      final lets = allNavTargets(result.program!)
          .where((t) => t.label == 'x' && t.def != null)
          .toList();
      expect(lets.length, 2);
      expect(
        sameResolvedDef(lets[0].def, lets[1].def),
        isFalse,
        reason: 'lets in a.kl and b.kl must not share a ResolvedDef',
      );

      final aLet = lets.firstWhere(
        (t) =>
            t.occurrencePath != null &&
            File(t.occurrencePath!).absolute.path == a.absolute.path,
      );
      final matchedPaths = allNavTargets(result.program!)
          .where((t) => sameResolvedDef(t.def, aLet.def))
          .map((t) => File(t.occurrencePath ?? '').absolute.path)
          .toSet();
      expect(matchedPaths.contains(b.absolute.path), isFalse);
      expect(matchedPaths.contains(a.absolute.path), isTrue);
    });
  });

  group('sameResolvedDef', () {
    test('empty path does not match a concrete path', () {
      const pos = SourcePos(3, 5);
      expect(
        sameResolvedDef(ResolvedDef(pos), ResolvedDef(pos, 'a.kl')),
        isFalse,
      );
      expect(
        sameResolvedDef(ResolvedDef(pos, 'a.kl'), ResolvedDef(pos)),
        isFalse,
      );
      expect(
        sameResolvedDef(ResolvedDef(pos), ResolvedDef(pos)),
        isTrue,
      );
      expect(
        sameResolvedDef(ResolvedDef(pos, 'a.kl'), ResolvedDef(pos, 'a.kl')),
        isTrue,
      );
    });

    test('same basename in different dirs does not match', () {
      const pos = SourcePos(3, 5);
      expect(
        sameResolvedDef(
          ResolvedDef(pos, '/a/util.kl'),
          ResolvedDef(pos, '/b/util.kl'),
        ),
        isFalse,
      );
      expect(
        sameResolvedDef(
          ResolvedDef(pos, 'util.kl'),
          ResolvedDef(pos, '/proj/util.kl'),
        ),
        isTrue,
      );
    });
  });
}
