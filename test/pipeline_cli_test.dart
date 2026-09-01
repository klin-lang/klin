@Tags(['e2e'])
library;

import 'dart:io';

import 'package:klin/fmt.dart';
import 'package:klin/lexer.dart';
import 'package:klin/version.dart';
import 'package:test/test.dart';

import 'support/klin_cli.dart';


void main() {
  setUpAll(() async {
    await ensureKlinE2eBin();
  });

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('klin fmt: preserves // comments (issue 128)', () async {
    final ugly = File('test/fmt_comments.kl').readAsStringSync();
    final expected = File('test/fmt_comments.fmt.kl').readAsStringSync();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);

    final lexer = Lexer('fn main() {\n    let x = 1 // trail\n}\n');
    final tokens = lexer.tokenize();
    expect(tokens.any((t) => t.lexeme.contains('//')), isFalse);
    expect(lexer.comments, hasLength(1));
    expect(lexer.comments.single.trailing, isTrue);
    expect(lexer.comments.single.text, '// trail');

    // stdout (`fmt` without -w) must keep comments
    final stdoutProc = await runKlin(['fmt', 'test/fmt_comments.kl']);
    expect(stdoutProc.exitCode, 0, reason: stdoutProc.stderr.toString());
    expect(stdoutProc.stdout, expected);
    expect(stdoutProc.stdout, contains('// file header'));
    expect(stdoutProc.stdout, contains('// one'));

    // `-w` uses the same formatSource — must rewrite the file with comments
    final dir = Directory.systemTemp.createTempSync('klin_fmt_w_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final copy = File('${dir.path}/fmt_comments.kl')
      ..writeAsStringSync(ugly);
    final writeProc = await runKlin(['fmt', '-w', copy.path]);
    expect(writeProc.exitCode, 0, reason: writeProc.stderr.toString());
    final written = copy.readAsStringSync();
    expect(written, expected);
    expect(written, contains('// file header'));
    expect(written, contains('// one'));
    expect(written, contains('// footer'));
  });

  test('klin fmt: ugly source matches golden and is idempotent (issue 033)',
      () async {
    final ugly = await File('test/fmt_ugly.kl').readAsString();
    final expected = await File('test/fmt_ugly.fmt.kl').readAsString();
    final once = formatSource(ugly);
    expect(once, expected);
    expect(formatSource(once), once);

    final proc = await runKlin(['fmt', 'test/fmt_ugly.kl']);
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout, expected);

    for (final path in [
      'examples/hello.kl',
      'examples/vec2.kl',
      'examples/point.kl',
      'examples/slice_sum.kl',
      'examples/modules/app.kl',
    ]) {
      final src = File(path).readAsStringSync();
      final formatted = formatSource(src);
      expect(formatSource(formatted), formatted, reason: path);
    }
    expect(
      formatSource(File('examples/slice_sum.kl').readAsStringSync()),
      contains('[10, 20, 30, 40]'),
    );
  });

  test('klin test runs *_test.kl and reports assert failures (issue 035)',
      () async {
    final pass = await runKlin(['test', 'examples/add_test.kl']);
    expect(pass.exitCode, 0, reason: pass.stderr.toString());
    expect(pass.stdout.toString(), contains('ok\texamples/add_test.kl'));
    expect(pass.stdout.toString(), contains('PASS'));

    final dir = Directory('${tmp.path}/klin_tests')..createSync();
    File('${dir.path}/fail_test.kl').writeAsStringSync('''
import testing
fn test_boom() {
  testing.assert_eq_i32(1, 2)
}
''');
    final fail = await runKlin(['test', '${dir.path}/fail_test.kl'], environment: {
        ...Platform.environment,
        'KLIN_STDLIB': Directory('stdlib').absolute.path,
      },);
    expect(fail.exitCode, isNot(0));
    expect(fail.stdout.toString(), contains('FAIL'));
    expect(
      '${fail.stdout}${fail.stderr}',
      contains('assert_eq_i32'),
    );

    // Imported `main` must not suppress the test harness.
    File('${dir.path}/lib_with_main.kl').writeAsStringSync('''
module lib_with_main
pub fn value(): i32 { return 7 }
fn main() { puts("imported-main") }
''');
    File('${dir.path}/import_main_test.kl').writeAsStringSync('''
import lib_with_main
import testing
fn test_value() {
  testing.assert_eq_i32(lib_with_main.value(), 7)
}
''');
    final imported = await runKlin(['test', '${dir.path}/import_main_test.kl'], environment: {
        ...Platform.environment,
        'KLIN_STDLIB': Directory('stdlib').absolute.path,
      },);
    expect(imported.exitCode, 0, reason: imported.stderr.toString());
    expect(imported.stdout.toString(), contains('ok\t'));
    expect('${imported.stdout}${imported.stderr}', isNot(contains('imported-main')));

    // Injected test `main` must keep enum declarations (Bugbot retro #97).
    File('${dir.path}/enum_harness_test.kl').writeAsStringSync('''
import testing
enum Color { Red, Green }
fn test_color() {
  testing.assert_eq_i32(cast(i32, Color.Green), 1)
}
''');
    final withEnum = await runKlin(['test', '${dir.path}/enum_harness_test.kl'], environment: {
        ...Platform.environment,
        'KLIN_STDLIB': Directory('stdlib').absolute.path,
      },);
    expect(withEnum.exitCode, 0, reason: withEnum.stderr.toString());
    expect(withEnum.stdout.toString(), contains('ok\t'));
  });

  test('klin run compiles and executes a program', () async {
    final proc = await runKlin(['run', 'test/hello.kl']);
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout, await File('test/hello.out').readAsString());
  });

  test('klin --version and -v print package version', () async {
    for (final flag in ['--version', '-v']) {
      final proc = await runKlin([flag]);
      expect(proc.exitCode, 0, reason: '$flag: ${proc.stderr}');
      expect(proc.stdout.toString().trim(), 'klin $klinVersion');
    }
  });

  test('klin --help and -h print usage on stdout', () async {
    for (final flag in ['--help', '-h']) {
      final proc = await runKlin([flag]);
      expect(proc.exitCode, 0, reason: '$flag: ${proc.stderr}');
      expect(proc.stdout.toString(), contains('usage:'));
      expect(proc.stdout.toString(), contains('--version'));
      expect(proc.stdout.toString(), contains('--opt'));
      expect(proc.stderr.toString(), isEmpty);
    }
  });

  test('klin run -O2 / --opt s / -Os compile hello', () async {
    for (final flags in [
      ['-O2'],
      ['--opt', 's'],
      ['-Os'],
      ['-g', '-O0'],
    ]) {
      final proc = await runKlin(['run',
        ...flags,
        'test/hello.kl']);
      expect(proc.exitCode, 0, reason: '$flags: ${proc.stderr}');
      expect(proc.stdout, await File('test/hello.out').readAsString());
    }
  });

  test('klin run --opt invalid prints usage', () async {
    final proc = await runKlin(['run',
      '--opt',
      'fast',
      'test/hello.kl']);
    expect(proc.exitCode, isNot(0));
    expect(proc.stderr.toString(), contains('usage:'));
  });

  test('klin with no args prints help on stdout', () async {
    final proc = await runKlin([]);
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout.toString(), contains('usage:'));
    expect(proc.stderr.toString(), isEmpty);
  });

  test('klin run without a file prints usage', () async {
    final proc = await runKlin(['run']);
    expect(proc.exitCode, isNot(0));
    expect(proc.stderr.toString(), contains('usage:'));
    expect(proc.stderr.toString(), contains('klin run'));
  });

  test('bare file path remains an alias for run', () async {
    final proc = await runKlin(['test/hello.kl']);
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(proc.stdout, await File('test/hello.out').readAsString());
  });

}
