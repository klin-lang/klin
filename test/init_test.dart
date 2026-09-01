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
        'board/nucleo_f411re.ioc',
      ]),
    );

    final main = File(p.join(dest, 'main.kl')).readAsStringSync();
    expect(main, contains(r'$device('));
    expect(main, contains(r'$board('));
    expect(main, contains('board/startup.s'));
    expect(main, contains('GPIOA'));
    expect(main, contains('BoardPin.LD2'));

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

  test('scaffold waveshare-rp2350-lcd-096', () {
    final dest = p.join(tmp.path, 'ws_blink');
    final created = scaffoldBoardInit(
      boardId: 'waveshare-rp2350-lcd-096',
      destDir: dest,
      packageRoot: packageRoot,
    );
    expect(
      created,
      containsAll([
        'main.kl',
        'Makefile',
        'klin.mod',
        'board/startup.s',
        'board/linker.ld',
        'board/image_def.S',
      ]),
    );
    final main = File(p.join(dest, 'main.kl')).readAsStringSync();
    expect(main, contains('waveshare_rp2350_lcd_096'));
    expect(main, contains('board/image_def.S'));
    final mod = File(p.join(dest, 'klin.mod')).readAsStringSync();
    expect(mod, contains('waveshare_rp2350_lcd_096'));
    expect(mod, contains('machine_rp'));
  });

  test('scaffold waveshare-esp32-s3-pico (ESP-IDF)', () {
    final dest = p.join(tmp.path, 's3_pico_blink');
    final created = scaffoldBoardInit(
      boardId: 'waveshare-esp32-s3-pico',
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
        'CMakeLists.txt',
        'sdkconfig.defaults',
        'main/app_main.c',
        'main/CMakeLists.txt',
      ]),
    );
    expect(created, isNot(contains('board/startup.s')));
    final main = File(p.join(dest, 'main.kl')).readAsStringSync();
    expect(main, contains('waveshare_esp32_s3_pico'));
    expect(main, contains('pin_out_s3'));
    expect(main, contains('klin_app_main'));
    final mod = File(p.join(dest, 'klin.mod')).readAsStringSync();
    expect(mod, contains('waveshare_esp32_s3_pico'));
    expect(mod, contains('machine_esp'));
    final makefile = File(p.join(dest, 'Makefile')).readAsStringSync();
    expect(makefile, contains('idf.py'));
    expect(makefile, contains('esp32s3'));
    final sdk = File(p.join(dest, 'sdkconfig.defaults')).readAsStringSync();
    expect(sdk, contains('esp32s3'));
  });

  test('scaffold waveshare-esp32-s3-rlcd-42 (ESP-IDF ST7305)', () {
    final dest = p.join(tmp.path, 's3_rlcd');
    final created = scaffoldBoardInit(
      boardId: 'waveshare-esp32-s3-rlcd-42',
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
        'CMakeLists.txt',
        'sdkconfig.defaults',
        'main/app_main.c',
        'main/CMakeLists.txt',
      ]),
    );
    expect(created, isNot(contains('board/startup.s')));
    final main = File(p.join(dest, 'main.kl')).readAsStringSync();
    expect(main, contains('waveshare_esp32_s3_rlcd_42'));
    expect(main, contains('klin_app_main'));
    expect(main, contains('flush'));
    final mod = File(p.join(dest, 'klin.mod')).readAsStringSync();
    expect(mod, contains('waveshare_esp32_s3_rlcd_42'));
    expect(mod, contains('machine_esp'));
    expect(mod, contains('klin_st7305'));
    expect(mod, contains('v0.4.0'));
    final makefile = File(p.join(dest, 'Makefile')).readAsStringSync();
    expect(makefile, contains('idf.py'));
    expect(makefile, contains('esp32s3'));
    final sdk = File(p.join(dest, 'sdkconfig.defaults')).readAsStringSync();
    expect(sdk, contains('esp32s3'));
    expect(sdk, contains('SPIRAM'));
    final readme = File(p.join(dest, 'README.md')).readAsStringSync();
    expect(readme, contains('waveshare.com/esp32-s3-rlcd-4.2'));
    expect(readme, contains('163'));
    expect(readme, contains('klin_st7305'));
    expect(main, contains('fb[:]'));
    expect(main, contains('draw_text'));
  });

  test('scaffold gd32vw553h-eval', () {
    final dest = p.join(tmp.path, 'vw553_blink');
    final created = scaffoldBoardInit(
      boardId: 'gd32vw553h-eval',
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
        'board/startup.S',
        'board/linker.ld',
      ]),
    );
    final main = File(p.join(dest, 'main.kl')).readAsStringSync();
    expect(main, contains('gd32vw553h_eval'));
    expect(main, contains('pin_out_vw553'));
    expect(main, contains('led1_port'));
    expect(main, contains('board/startup.S'));
    final mod = File(p.join(dest, 'klin.mod')).readAsStringSync();
    expect(mod, contains('gd32vw553h_eval'));
    expect(mod, contains('machine_gd32v'));
    final makefile = File(p.join(dest, 'Makefile')).readAsStringSync();
    expect(makefile, contains('CC := riscv64-unknown-elf-gcc'));
    expect(makefile, contains('board/linker.ld'));
  });

  test('scaffold gd32vw553h-start', () {
    final dest = p.join(tmp.path, 'vw553_start_blink');
    final created = scaffoldBoardInit(
      boardId: 'gd32vw553h-start',
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
        'board/startup.S',
        'board/linker.ld',
      ]),
    );
    final main = File(p.join(dest, 'main.kl')).readAsStringSync();
    expect(main, contains('gd32vw553h_start'));
    expect(main, contains('pin_out_vw553'));
    expect(main, contains('led_r_port'));
    expect(main, contains('board/startup.S'));
    final mod = File(p.join(dest, 'klin.mod')).readAsStringSync();
    expect(mod, contains('gd32vw553h_start'));
    expect(mod, contains('machine_gd32v'));
    final makefile = File(p.join(dest, 'Makefile')).readAsStringSync();
    expect(makefile, contains('CC := riscv64-unknown-elf-gcc'));
    expect(makefile, contains('board/linker.ld'));
  });

  test('scaffold lckfb-gd32vw553', () {
    final dest = p.join(tmp.path, 'lckfb_vw553_blink');
    final created = scaffoldBoardInit(
      boardId: 'lckfb-gd32vw553',
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
        'board/startup.S',
        'board/linker.ld',
      ]),
    );
    final main = File(p.join(dest, 'main.kl')).readAsStringSync();
    expect(main, contains('pin_out_vw553'));
    expect(main, contains('Port.C'));
    expect(main, contains('board/startup.S'));
    final mod = File(p.join(dest, 'klin.mod')).readAsStringSync();
    expect(mod, contains('machine_gd32v'));
    expect(mod, isNot(contains('gd32vw553h_eval')));
    expect(mod, isNot(contains('gd32vw553h_start')));
    final makefile = File(p.join(dest, 'Makefile')).readAsStringSync();
    expect(makefile, contains('CC := riscv64-unknown-elf-gcc'));
    expect(makefile, contains('board/linker.ld'));
    final ld = File(p.join(dest, 'board/linker.ld')).readAsStringSync();
    expect(ld, contains('4096K'));
  });

  test('scaffold weact-f411', () {
    final dest = p.join(tmp.path, 'weact_blink');
    final created = scaffoldBoardInit(
      boardId: 'weact-f411',
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
    expect(main, contains('machine_stm32'));
    expect(main, contains('Port.C'));
    expect(main, contains('board/startup.s'));
    final mod = File(p.join(dest, 'klin.mod')).readAsStringSync();
    expect(mod, contains('machine_stm32'));
    final makefile = File(p.join(dest, 'Makefile')).readAsStringSync();
    expect(makefile, contains('arm-none-eabi-gcc'));
    expect(makefile, contains('dfu-util'));
    expect(makefile, contains('st-flash'));
  });

  test('scaffold pico and pico2', () {
    final pico = scaffoldBoardInit(
      boardId: 'pico',
      destDir: p.join(tmp.path, 'pico_blink'),
      packageRoot: packageRoot,
    );
    expect(pico, contains('board/boot2_w25q080.S'));
    expect(
      File(p.join(tmp.path, 'pico_blink', 'main.kl')).readAsStringSync(),
      contains('pin_out(25)'),
    );

    final pico2 = scaffoldBoardInit(
      boardId: 'pico2',
      destDir: p.join(tmp.path, 'pico2_blink'),
      packageRoot: packageRoot,
    );
    expect(pico2, contains('board/image_def.S'));
    expect(
      File(p.join(tmp.path, 'pico2_blink', 'main.kl')).readAsStringSync(),
      contains('pin_out_rp2350'),
    );
  });

  test('knownInitBoards matches templates/ directories', () {
    for (final id in knownInitBoards) {
      expect(
        Directory(p.join(packageRoot, 'templates', id)).existsSync(),
        isTrue,
        reason: 'missing templates/$id',
      );
    }
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

  test('templatesCandidatesForInstallRoot Homebrew + release layout', () {
    final sep = Platform.pathSeparator;
    final roots = ['/opt/klin', '/opt/homebrew/Cellar/klin/0.1.2'];
    final paths = templatesCandidatesForInstallRoot(roots).toList();
    expect(paths, contains('/opt/klin${sep}templates'));
    expect(
      paths,
      contains('/opt/homebrew/Cellar/klin/0.1.2${sep}share${sep}klin${sep}templates'),
    );
  });

  test('CLI init uses KLIN_TEMPLATES outside the repo', () {
    expect(
      findTemplatesRoot(packageRoot: packageRoot),
      endsWith('${Platform.pathSeparator}templates'),
    );

    final fake = Directory(p.join(tmp.path, 'tpl'))..createSync();
    final board = Directory(p.join(fake.path, 'nucleo-f411'))..createSync();
    File(p.join(board.path, 'main.kl')).writeAsStringSync('// from env\n');

    final dest = p.join(tmp.path, 'from_env');
    final klinEntry = p.join(packageRoot, 'bin', 'klin.dart');
    final result = Process.runSync(
      'dart',
      ['run', klinEntry, 'init', 'nucleo-f411', dest],
      workingDirectory: tmp.path,
      environment: {
        ...Platform.environment,
        'KLIN_TEMPLATES': fake.path,
      },
    );
    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
    expect(
      File(p.join(dest, 'main.kl')).readAsStringSync(),
      contains('from env'),
    );
  });
}
