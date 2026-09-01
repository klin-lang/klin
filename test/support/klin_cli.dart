import 'dart:io';

/// Host Klin CLI for e2e tests.
///
/// Prefer a prebuilt binary:
/// - `KLIN_E2E_BIN` (CI sets this after `dart compile exe`)
/// - else `build/klin` / `build/klin.exe` if present
/// - else compile once into `build/klin` (exclusive lock for parallel suites)
Future<String> ensureKlinE2eBin() async {
  final cached = _klinE2eBin;
  if (cached != null) return cached;

  final fromEnv = Platform.environment['KLIN_E2E_BIN'];
  if (fromEnv != null && fromEnv.isNotEmpty && File(fromEnv).existsSync()) {
    return _klinE2eBin = File(fromEnv).absolute.path;
  }

  final exe = Platform.isWindows ? 'klin.exe' : 'klin';
  final buildBin = File('build/$exe');
  if (await buildBin.exists()) {
    return _klinE2eBin = buildBin.absolute.path;
  }

  await Directory('build').create(recursive: true);
  final lockFile = File('build/.klin_e2e_compile.lock');
  RandomAccessFile? raf;
  Object? lockError;
  for (var attempt = 0; attempt < 120; attempt++) {
    try {
      raf = await lockFile.open(mode: FileMode.write);
      await raf.lock(FileLock.exclusive);
      lockError = null;
      break;
    } catch (e) {
      lockError = e;
      await raf?.close();
      raf = null;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }
  if (raf == null) {
    throw StateError('could not lock $lockFile: $lockError');
  }

  try {
    if (await buildBin.exists()) {
      return _klinE2eBin = buildBin.absolute.path;
    }
    final compile = await Process.run('dart', [
      'compile',
      'exe',
      'bin/klin.dart',
      '-o',
      buildBin.path,
    ]);
    if (compile.exitCode != 0) {
      throw StateError(
        'dart compile exe failed:\n${compile.stderr}${compile.stdout}',
      );
    }
    return _klinE2eBin = buildBin.absolute.path;
  } finally {
    await raf.unlock();
    await raf.close();
  }
}

String? _klinE2eBin;

/// Run the host Klin CLI (AOT binary when available).
Future<ProcessResult> runKlin(
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final bin = await ensureKlinE2eBin();
  return Process.run(
    bin,
    args,
    workingDirectory: workingDirectory,
    environment: environment,
  );
}

/// Sync variant for legacy sync tests.
ProcessResult runKlinSync(
  List<String> args, {
  String? workingDirectory,
  Map<String, String>? environment,
}) {
  // Sync path: require prebuilt bin (CI / prior async ensure).
  final fromEnv = Platform.environment['KLIN_E2E_BIN'];
  final exe = Platform.isWindows ? 'klin.exe' : 'klin';
  final buildBin = File('build/$exe');
  final bin = () {
    if (fromEnv != null && fromEnv.isNotEmpty && File(fromEnv).existsSync()) {
      return File(fromEnv).absolute.path;
    }
    if (buildBin.existsSync()) return buildBin.absolute.path;
    throw StateError(
      'runKlinSync needs KLIN_E2E_BIN or build/$exe '
      '(call ensureKlinE2eBin() in setUpAll first)',
    );
  }();
  return Process.runSync(
    bin,
    args,
    workingDirectory: workingDirectory,
    environment: environment,
  );
}
