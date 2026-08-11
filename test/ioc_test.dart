import 'dart:io';

import 'package:klin/ioc/emit.dart';
import 'package:klin/ioc/parse.dart';
import 'package:klin/preprocess.dart';
import 'package:klin/remote.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('parseIoc extracts labeled Nucleo pins', () {
    final text = File('third_party/ioc/nucleo_f411re.ioc').readAsStringSync();
    final pinout = parseIoc(text);
    final byName = {for (final p in pinout.pins) p.name: p};
    expect(byName.keys, containsAll(['LD2', 'B1', 'USART_TX', 'USART_RX']));
    expect(byName.keys, isNot(contains('TMS')));
    expect(byName['LD2']!.port, 'A');
    expect(byName['LD2']!.pin, 5);
    expect(byName['LD2']!.portIndex, 0);
    expect(byName['B1']!.port, 'C');
    expect(byName['B1']!.pin, 13);
    expect(byName['B1']!.portIndex, 2);
  });

  test('emitIocPinout produces BoardPort / BoardPin enums', () {
    final pinout = parseIoc(
      File('third_party/ioc/nucleo_f411re.ioc').readAsStringSync(),
    );
    final kl = emitIocPinout(pinout, sourceNote: 'board/nucleo.ioc');
    expect(kl, contains('enum BoardPort: i32'));
    expect(kl, contains('enum BoardPin: i32'));
    expect(kl, contains('LD2 = 0'));
    expect(kl, contains('LD2 = 5'));
    expect(kl, contains('source: board/nucleo.ioc'));
  });

  test('klin.mod board directive round-trip (issue 074)', () {
    const boardPath = 'github/klin-lang/boards/nucleo_f411re.ioc';
    final mod = parseKlinMod(
      'klin 1\n'
      'device github/tinygo-org/stm32-svd/svd/stm32f411.svd main\n'
      'board $boardPath v0.1.0\n',
    );
    expect(mod.boards[boardPath], 'v0.1.0');
    expect(
      formatKlinMod(mod),
      'klin 1\n'
      'device github/tinygo-org/stm32-svd/svd/stm32f411.svd main\n'
      'board $boardPath v0.1.0\n',
    );
    expect(isRemoteBoardPath(boardPath), isTrue);
    expect(isRemoteDevicePath(boardPath), isFalse);
    expect(
      () => parseRemoteAsset('github/acme/boards/x.ioc'),
      throwsA(isA<FormatException>()),
    );
    // Board pack repo is also allowlisted (issue 096).
    expect(
      parseRemoteAsset(
        'github/klin-lang/nucleo_f411re/nucleo_f411re.ioc@v0.1.3',
      ).repoPath,
      'github/klin-lang/nucleo_f411re',
    );
  });

  test(r'$board expands local .ioc (issue 074)', () {
    final dir = Directory.systemTemp.createTempSync('klin_board_');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory(p.join(dir.path, 'board')).createSync();
    File(p.join(dir.path, 'board', 'nucleo.ioc')).writeAsStringSync(
      File('third_party/ioc/nucleo_f411re.ioc').readAsStringSync(),
    );
    final klPath = p.join(dir.path, 'app.kl');
    File(klPath).writeAsStringSync(r'''
$board("board/nucleo.ioc")
fn main() {
  let p: i32 = BoardPin.LD2
  let q: i32 = BoardPort.LD2
}
''');
    final expanded = preprocess(
      File(klPath).readAsStringSync(),
      path: klPath,
    );
    expect(expanded, contains('enum BoardPin: i32'));
    expect(expanded, contains('LD2 = 5'));
    expect(expanded, contains('BoardPin.LD2'));
  });

  test(r'$board local-first over cache; remote miss hints klin get', () {
    final dir = Directory.systemTemp.createTempSync('klin_board_local_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final cache = Directory.systemTemp.createTempSync('klin_board_cache_');
    addTearDown(() => cache.deleteSync(recursive: true));

    final vendored = Directory(
      p.join(dir.path, 'github/klin-lang/boards'),
    )..createSync(recursive: true);
    File(p.join(vendored.path, 'nucleo_f411re.ioc')).writeAsStringSync(
      'PA5.GPIO_Label=LD2 [Green Led]\nPA5.Signal=GPIO_Output\n',
    );
    final klPath = p.join(dir.path, 'app.kl');
    File(klPath).writeAsStringSync(r'''
$board("github/klin-lang/boards/nucleo_f411re.ioc")
fn main() {}
''');
    final expanded = preprocess(
      File(klPath).readAsStringSync(),
      path: klPath,
      klinCacheDir: cache.path,
    );
    expect(expanded, contains('LD2 = 5'));
    expect(Directory(p.join(cache.path, 'asset')).existsSync(), isFalse);

    expect(
      () => preprocess(
        r'''
$board("github/klin-lang/boards/missing.ioc")
fn main() {}
''',
        path: klPath,
        klinCacheDir: cache.path,
      ),
      throwsA(
        predicate(
          (e) => e is PreprocessError && e.toString().contains('klin get'),
        ),
      ),
    );
  });

  test('ensureRemoteBoard does not overwrite project board/*.ioc', () async {
    final work = Directory.systemTemp.createTempSync('klin_board_noow_');
    addTearDown(() => work.deleteSync(recursive: true));
    final cache = Directory.systemTemp.createTempSync('klin_board_noow_c_');
    addTearDown(() => cache.deleteSync(recursive: true));

    final boardDir = Directory(p.join(work.path, 'board'))..createSync();
    final localIoc = File(p.join(boardDir.path, 'nucleo_f411re.ioc'));
    localIoc.writeAsStringSync('PA5.GPIO_Label=LOCAL_LED\nPA5.Signal=GPIO_Output\n');

    // Seed cache with different bytes (simulates prior get).
    const remotePath = 'github/klin-lang/boards/nucleo_f411re.ioc';
    final asset = parseRemoteAsset('$remotePath@v0.1.0');
    final assetDir = assetCacheDir(asset, cacheRoot: cache.path);
    Directory(assetDir).createSync(recursive: true);
    // filePath is nucleo_f411re.ioc at repo root
    File(p.join(assetDir, 'nucleo_f411re.ioc')).writeAsStringSync(
      'PA5.GPIO_Label=CACHE_LED\nPA5.Signal=GPIO_Output\n',
    );
    File(p.join(assetDir, '.pin')).writeAsStringSync('v0.1.0\n');
    File(p.join(assetDir, '.commit')).writeAsStringSync('${'a' * 40}\n');

    final klPath = p.join(work.path, 'app.kl');
    File(klPath).writeAsStringSync(r'''
$board("board/nucleo_f411re.ioc")
fn main() {}
''');
    final expanded = preprocess(
      File(klPath).readAsStringSync(),
      path: klPath,
      klinCacheDir: cache.path,
    );
    expect(expanded, contains('LOCAL_LED = 5'));
    expect(expanded, isNot(contains('CACHE_LED')));
    expect(
      localIoc.readAsStringSync(),
      contains('LOCAL_LED'),
      reason: 'project .ioc must remain untouched',
    );
  });
}
