@Tags(['unit'])
library;

import 'dart:io';

import 'package:klin/analyze.dart';
import 'package:klin/project.dart';
import 'package:test/test.dart';

void main() {
  group('loadProject sourceOverlay', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('klin_overlay_');
    });

    tearDown(() {
      dir.deleteSync(recursive: true);
    });

    test('overlay wins over disk for imported module', () {
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
      // Dirty buffer: helper returns 2 — only visible via overlay.
      final overlay = {
        lib.absolute.path: '''
module util
pub fn helper(): i32 {
    return 2
}
''',
        main.absolute.path: main.readAsStringSync(),
      };
      final program = loadProject(
        main.path,
        sourceOverlay: overlay,
      );
      expect(program.funcs.any((f) => f.name == 'helper'), isTrue);
      final result = analyzeSource(
        path: main.path,
        source: main.readAsStringSync(),
        sourceOverlay: overlay,
      );
      expect(result.diagnostics, isEmpty);
      expect(result.program, isNotNull);
      // Go-to util.helper from call site.
      final callLine = main.readAsStringSync().split('\n').indexWhere(
            (l) => l.contains('util.helper'),
          );
      expect(callLine, greaterThanOrEqualTo(0));
      final col = main.readAsStringSync().split('\n')[callLine].indexOf('helper') + 1;
      final def = definitionAt(
        result,
        callLine + 1,
        col,
        openPath: main.absolute.path,
      );
      expect(def, isNotNull);
      expect(def!.path, isNotNull);
      expect(File(def.path!).absolute.path, lib.absolute.path);
    });

    test('check errors from import keep import path', () {
      final lib = File('${dir.path}/util.kl')
        ..writeAsStringSync('''
module util
pub fn helper(): i32 {
    return true
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
      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.any(
          (d) => sameDiagnosticPath(d.path, lib.absolute.path),
        ),
        isTrue,
        reason: 'type error in util must keep util path, not open main',
      );
      expect(
        result.diagnostics
            .where((d) => sameDiagnosticPath(d.path, lib.absolute.path))
            .every((d) => d.pos.line >= 3),
        isTrue,
      );
    });

    test('parse errors from import keep import path', () {
      final lib = File('${dir.path}/util.kl')
        ..writeAsStringSync('''
module util
pub fn helper(: i32 {
    return 1
}
''');
      final main = File('${dir.path}/main.kl')
        ..writeAsStringSync('''
import util
fn main(): void {}
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
      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.any(
          (d) => sameDiagnosticPath(d.path, lib.absolute.path),
        ),
        isTrue,
        reason: 'syntax error in util must not use open main path',
      );
    });

    test('async main diagnostic keeps main file path', () {
      final lib = File('${dir.path}/util.kl')
        ..writeAsStringSync('''
module util
pub fn helper(): void {
}
''');
      final main = File('${dir.path}/main.kl')
        ..writeAsStringSync('''
import util
async fn main(): void {
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
      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.any(
          (d) =>
              d.message.contains('async') &&
              sameDiagnosticPath(d.path, main.absolute.path),
        ),
        isTrue,
        reason: 'async main must not inherit util.kl path',
      );
    });
  });
}
