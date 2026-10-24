@Tags(['e2e'])
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/compile_and_run.dart';
import 'support/klin_cli.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_bugs_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('f()! as a statement propagates', () async {
    final result = await compileAndRun('test/propagate_stmt.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'ok 4\nerr 9\n');
  });

  test('let mut x = b"fn" reseats onto a mutable buffer', () async {
    final result = await compileAndRun('test/mut_ro_bytes.kl', tmp);
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '2 102\n3 111\n9\n');
  });

  test('klin run reports an imported parse error once', () async {
    final dir = Directory('${tmp.path}/proj');
    await dir.create();
    await File('${dir.path}/bad.kl').writeAsString('fn broken( {\n}\n');
    final mainPath = '${dir.path}/main.kl';
    await File(mainPath).writeAsString('import bad\nfn main() {}\n');
    final proc = await runKlin(['run', mainPath]);
    expect(proc.exitCode, isNot(0));
    final err = proc.stderr.toString();
    expect(err, contains('bad.kl'));
    expect('bad.kl'.allMatches(err).length, 1);
    expect(err.contains('main.kl:'), isFalse);
  });
}
