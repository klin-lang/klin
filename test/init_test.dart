import 'dart:io';

import 'package:klin/init.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late String packageRoot;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('klin_init_');
    // test/ is under the package root.
    packageRoot = Directory.current.path;
    expect(
      File(p.join(packageRoot, 'pubspec.yaml')).existsSync(),
      isTrue,
      reason: 'tests must run from package root',
    );
    expect(
      Directory(p.join(packageRoot, 'templates', 'nucleo-f411')).existsSync(),
      isTrue,
    );
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('scaffold nucleo-f411 copies board layout', () {
    final dest = p.join(tmp.path, 'my_blink');
    final created = scaffoldBoardInit(
      boardId: 'nucleo-f411',
      destDir: dest,
      packageRoot: packageRoot,
    );

    expect(
      created,
      containsAll([
        'main.kl',
        'Makefile',
        'klin.mod',
        'README.md',
        'board/startup.s',
        'board/linker.ld',
      ]),
    );

    final main = File(p.join(dest, 'main.kl')).readAsStringSync();
    expect(main, contains(r'$device('));
    expect(main, contains('board/startup.s'));
    expect(main, contains('GPIOA'));

    final mod = File(p.join(dest, 'klin.mod')).readAsStringSync();
    expect(mod, contains('device github/tinygo-org/stm32-svd'));

    final makefile = File(p.join(dest, 'Makefile')).readAsStringSync();
    expect(makefile, contains('board/linker.ld'));
    expect(makefile, contains('arm-none-eabi-gcc'));
  });

  test('unknown board fails', () {
    expect(
      () => scaffoldBoardInit(
        boardId: 'no-such-board',
        destDir: p.join(tmp.path, 'x'),
        packageRoot: packageRoot,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('unknown board'),
        ),
      ),
    );
  });

  test('refuse non-empty destination', () {
    final dest = Directory(p.join(tmp.path, 'busy'))..createSync();
    File(p.join(dest.path, 'keep.txt')).writeAsStringSync('x');
    expect(
      () => scaffoldBoardInit(
        boardId: 'nucleo-f411',
        destDir: dest.path,
        packageRoot: packageRoot,
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not empty'),
        ),
      ),
    );
  });

  test('CLI init nucleo-f411', () async {
    final dest = p.join(tmp.path, 'cli_blink');
    final result = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'init', 'nucleo-f411', dest],
      workingDirectory: packageRoot,
    );
    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
    expect(result.stdout.toString(), contains('klin init: nucleo-f411'));
    expect(result.stdout.toString(), contains('board/startup.s'));
    expect(File(p.join(dest, 'main.kl')).existsSync(), isTrue);
  });

  test('CLI init unknown board exits non-zero', () async {
    final result = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', 'init', 'unknown-board'],
      workingDirectory: packageRoot,
    );
    expect(result.exitCode, isNot(0));
    expect(result.stderr.toString(), contains('unknown board'));
  });
}
