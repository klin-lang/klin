@Tags(['e2e'])
library;

import 'dart:io';

import 'package:klin/remote.dart';
import 'package:test/test.dart';

import 'support/compile_and_run.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('klin_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('--emit-pp writes expanded Klin source', () async {
    final proc = await Process.run(
      'dart',
      ['run', 'bin/klin.dart', '--emit-pp', 'test/point_macro.kl'],
    );
    final pp = File('out/point_macro.pp.kl');
    addTearDown(() async {
      if (await pp.exists()) await pp.delete();
    });
    expect(proc.exitCode, 0, reason: proc.stderr.toString());
    expect(await pp.exists(), isTrue);
    final text = await pp.readAsString();
    expect(text, contains('struct Vec2i'));
    expect(text, isNot(contains(r'$point')));
  });

  test('remote import from preseeded cache (issue 049)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_cache049_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final pkg = Directory(
      '${cache.path}/pkg/github/klin-lang/osa',
    )..createSync(recursive: true);
    File('${pkg.path}/version.kl').writeAsStringSync('''
module osa
pub fn version(): i32 { return 1 }
''');
    File('${pkg.path}/math.kl').writeAsStringSync('''
module osa
pub fn add(a: i32, b: i32): i32 { return a + b }
pub fn clamp(v: i32, lo: i32, hi: i32): i32 {
  if v < lo { return lo }
  if v > hi { return hi }
  return v
}
''');
    File('${pkg.path}/.pin').writeAsStringSync('v0.1.0\n');

    final result = await compileAndRun(
      'test/remote_osa.kl',
      tmp,
      klinCacheDir: cache.path,
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, await File('test/remote_osa.out').readAsString());
  });

  test('remote import alias `import "github/…" o` (issue 049)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_alias049_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final pkg = Directory(
      '${cache.path}/pkg/github/klin-lang/osa',
    )..createSync(recursive: true);
    File('${pkg.path}/lib.kl').writeAsStringSync('''
module osa
pub fn version(): i32 { return 1 }
''');
    final work = Directory.systemTemp.createTempSync('klin_aliasapp049_');
    addTearDown(() => work.deleteSync(recursive: true));
    File('${work.path}/app.kl').writeAsStringSync('''
import "github/klin-lang/osa" o
fn main() { printf("%d\\n", o.version()) }
''');
    final result = await compileAndRun(
      '${work.path}/app.kl',
      tmp,
      klinCacheDir: cache.path,
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, '1\n');
  });

  test('klin get fetches osa@v0.1.0 and run works (issue 049 network)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_get049_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final work = Directory.systemTemp.createTempSync('klin_getwork049_');
    addTearDown(() => work.deleteSync(recursive: true));
    File('${work.path}/app.kl').writeAsStringSync(
      File('test/remote_osa.kl').readAsStringSync(),
    );
    final repoRoot = Directory.current.path;
    final klinBin = '$repoRoot/bin/klin.dart';

    final get = await Process.run(
      'dart',
      ['run', klinBin, 'get', 'github/klin-lang/osa@v0.1.0'],
      workingDirectory: work.path,
      environment: {
        ...Platform.environment,
        'KLIN_CACHE': cache.path,
      },
    );
    expect(get.exitCode, 0, reason: '${get.stderr}${get.stdout}');
    expect(File('${work.path}/klin.mod').existsSync(), isTrue);
    final mod = loadKlinMod(File('${work.path}/klin.mod'));
    expect(mod.requires['github/klin-lang/osa'], 'v0.1.0');

    expect(File('${work.path}/klin.lock').existsSync(), isTrue);
    final lock = loadKlinLock(File('${work.path}/klin.lock'));
    final entry = lock.packages['github/klin-lang/osa']!;
    expect(entry.version, 'v0.1.0');
    expect(entry.commit, matches(RegExp(r'^[0-9a-f]{40}$')));
    expect(entry.hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    final pkgDir = '${cache.path}/pkg/github/klin-lang/osa';
    expect(packageContentHash(pkgDir), entry.hash);
    expect(readCommit(pkgDir), entry.commit);

    // Second get prefers lock SHA (offline-capable once cached) and keeps lock.
    final get2 = await Process.run(
      'dart',
      ['run', klinBin, 'get'],
      workingDirectory: work.path,
      environment: {
        ...Platform.environment,
        'KLIN_CACHE': cache.path,
      },
    );
    expect(get2.exitCode, 0, reason: '${get2.stderr}${get2.stdout}');
    expect(
      loadKlinLock(File('${work.path}/klin.lock'))
          .packages['github/klin-lang/osa']!
          .commit,
      entry.commit,
    );

    // Tampered lock hash must fail.
    File('${work.path}/klin.lock').writeAsStringSync(
      'klin lock 1\n'
      'github/klin-lang/osa v0.1.0 ${entry.commit} '
      'sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\n',
    );
    final bad = await Process.run(
      'dart',
      ['run', klinBin, 'get'],
      workingDirectory: work.path,
      environment: {
        ...Platform.environment,
        'KLIN_CACHE': cache.path,
      },
    );
    expect(bad.exitCode, isNot(0));
    expect('${bad.stderr}', contains('hash mismatch'));

    final run = await Process.run(
      'dart',
      ['run', klinBin, 'run', '${work.path}/app.kl'],
      workingDirectory: repoRoot,
      environment: {
        ...Platform.environment,
        'KLIN_CACHE': cache.path,
      },
    );
    expect(run.exitCode, 0, reason: '${run.stderr}${run.stdout}');
    expect(run.stdout, await File('test/remote_osa.out').readAsString());
  }, timeout: Timeout(Duration(minutes: 2)));

  test('klin outdated/upgrade with osa@v0.1.0 (issue 066 network)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_outdated066_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final work = Directory.systemTemp.createTempSync('klin_outdatedwork066_');
    addTearDown(() => work.deleteSync(recursive: true));
    File('${work.path}/klin.mod').writeAsStringSync(
      'klin 1\nrequire github/klin-lang/osa v0.1.0\n',
    );
    final repoRoot = Directory.current.path;
    final klinBin = '$repoRoot/bin/klin.dart';
    final env = {
      ...Platform.environment,
      'KLIN_CACHE': cache.path,
    };

    final get = await Process.run(
      'dart',
      ['run', klinBin, 'get'],
      workingDirectory: work.path,
      environment: env,
    );
    expect(get.exitCode, 0, reason: '${get.stderr}${get.stdout}');

    final outdated = await Process.run(
      'dart',
      ['run', klinBin, 'outdated'],
      workingDirectory: work.path,
      environment: env,
    );
    expect(outdated.exitCode, 0, reason: '${outdated.stderr}${outdated.stdout}');
    expect(outdated.stdout, 'all packages up to date\n');

    final upgrade = await Process.run(
      'dart',
      ['run', klinBin, 'upgrade'],
      workingDirectory: work.path,
      environment: env,
    );
    expect(upgrade.exitCode, 0, reason: '${upgrade.stderr}${upgrade.stdout}');
    expect(upgrade.stdout, 'all packages up to date\n');
    expect(
      loadKlinMod(File('${work.path}/klin.mod')).requires['github/klin-lang/osa'],
      'v0.1.0',
    );
  }, timeout: Timeout(Duration(minutes: 2)));

  test('remote eventloop: every_ms + run + stop (issue 029 MVP)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_cache_eloop_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final pkg = Directory('${cache.path}/pkg/github/klin-lang/eventloop')
      ..createSync(recursive: true);
    // Preseed cache from fixture mirroring eventloop v0.2 (keeps v0.1 callbacks).
    File('${pkg.path}/version.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/version.kl').readAsString(),
    );
    File('${pkg.path}/executor.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/executor.kl').readAsString(),
    );
    File('${pkg.path}/.pin').writeAsStringSync('v0.2.0\n');

    final result = await compileAndRun(
      'examples/remote_eventloop/app.kl',
      tmp,
      klinCacheDir: cache.path,
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'tick\ntick\ntick\nticks=3 version=2\n');
  });

  test('remote eventloop: async spawn + sleep_ms (issue 029)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_cache_async_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final pkg = Directory('${cache.path}/pkg/github/klin-lang/eventloop')
      ..createSync(recursive: true);
    File('${pkg.path}/version.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/version.kl').readAsString(),
    );
    File('${pkg.path}/executor.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/executor.kl').readAsString(),
    );
    File('${pkg.path}/.pin').writeAsStringSync('v0.2.0\n');

    final result = await compileAndRun(
      'examples/remote_eventloop/async_app.kl',
      tmp,
      klinCacheDir: cache.path,
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'tick\ntick\ntick\nticks done version=2\n');
  });

  test('remote sketch_async_eventloop (issue 029 phase 4)', () async {
    final cache = Directory.systemTemp.createTempSync('klin_cache_sketch_');
    addTearDown(() => cache.deleteSync(recursive: true));
    final pkg = Directory('${cache.path}/pkg/github/klin-lang/eventloop')
      ..createSync(recursive: true);
    File('${pkg.path}/version.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/version.kl').readAsString(),
    );
    File('${pkg.path}/executor.kl').writeAsStringSync(
      await File('test/fixtures/mrhiden_eventloop/executor.kl').readAsString(),
    );
    File('${pkg.path}/.pin').writeAsStringSync('v0.2.0\n');

    final result = await compileAndRun(
      'examples/sketch_async_eventloop.kl',
      tmp,
      klinCacheDir: cache.path,
    );
    expect(result.exitCode, 0, reason: result.stderr);
    expect(result.stdout, 'tick\ntick\ntick\nticks done version=2\n');
  });

}
