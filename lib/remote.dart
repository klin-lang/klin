import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Reserved first path segments for remote imports (issue 049).
const remoteHosts = {'github', 'gitlab'};

/// Parsed `host/owner/repo` with optional `@ref`.
final class RemoteImport {
  final String host;
  final String owner;
  final String repo;
  final String? ref;

  const RemoteImport({
    required this.host,
    required this.owner,
    required this.repo,
    this.ref,
  });

  /// Import path without `@ref` (e.g. `github/klin-lang/osa`).
  String get path => '$host/$owner/$repo';

  String get gitUrl => switch (host) {
        'github' => 'https://github.com/$owner/$repo.git',
        'gitlab' => 'https://gitlab.com/$owner/$repo.git',
        _ => throw StateError('unsupported host `$host`'),
      };
}

/// True when [importKey] is a remote import (`github/…` or `gitlab/…`).
bool isRemoteImportPath(String importKey) {
  final slash = importKey.indexOf('/');
  if (slash <= 0) return false;
  return remoteHosts.contains(importKey.substring(0, slash));
}

/// Parse `github/owner/repo` or `github/owner/repo@ref`.
///
/// MVP: exactly three path segments. Throws [FormatException] on bad input.
RemoteImport parseRemoteImport(String spec) {
  var path = spec.trim();
  String? ref;
  final at = path.lastIndexOf('@');
  if (at > 0) {
    ref = path.substring(at + 1).trim();
    path = path.substring(0, at).trim();
    if (ref.isEmpty) {
      throw FormatException('empty @ref in remote import `$spec`');
    }
  }
  final parts = path.split('/');
  if (parts.length != 3 || parts.any((p) => p.isEmpty)) {
    throw FormatException(
      'remote import `$spec` must be host/owner/repo (optionally @ref)',
    );
  }
  final host = parts[0];
  if (!remoteHosts.contains(host)) {
    throw FormatException(
      'remote host `$host` is not allowed (use github or gitlab)',
    );
  }
  final owner = parts[1];
  final repo = parts[2];
  if (!_isSafePathSegment(owner) || !_isSafePathSegment(repo)) {
    throw FormatException(
      'remote import `$spec` has an invalid owner or repo segment',
    );
  }
  if (ref != null && (ref.contains('..') || ref.contains('/') || ref.contains('\\'))) {
    throw FormatException('invalid @ref in remote import `$spec`');
  }
  return RemoteImport(
    host: host,
    owner: owner,
    repo: repo,
    ref: ref,
  );
}

bool _isSafePathSegment(String s) {
  if (s == '.' || s == '..') return false;
  if (s.contains('..')) return false;
  // Allow typical GitHub names; reject path separators and NUL.
  return RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(s);
}

/// Root of Klin cache (`$KLIN_CACHE` or `~/.klin`), overridable for tests.
String klinCacheRoot({String? override}) {
  if (override != null && override.isNotEmpty) return override;
  final env = Platform.environment['KLIN_CACHE'];
  if (env != null && env.isNotEmpty) return env;
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.systemTemp.path;
  return '$home${Platform.pathSeparator}.klin';
}

/// Directory for a cached package: `$cache/pkg/host/owner/repo`.
String packageCacheDir(RemoteImport remote, {String? cacheRoot}) {
  final root = klinCacheRoot(override: cacheRoot);
  final sep = Platform.pathSeparator;
  return '$root${sep}pkg$sep${remote.host}$sep${remote.owner}$sep${remote.repo}';
}

/// Whether the package directory looks installed (has `.kl` sources).
bool isPackageInstalled(String pkgDir) {
  final dir = Directory(pkgDir);
  if (!dir.existsSync()) return false;
  for (final entity in dir.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.isEmpty
        ? entity.path
        : entity.path.split(Platform.pathSeparator).last;
    if (name.endsWith('.kl') && !name.endsWith('_test.kl')) return true;
  }
  return false;
}

String? readPin(String pkgDir) {
  final f = File('$pkgDir${Platform.pathSeparator}.pin');
  if (!f.existsSync()) return null;
  final text = f.readAsStringSync().trim();
  return text.isEmpty ? null : text;
}

void writePin(String pkgDir, String ref) {
  Directory(pkgDir).createSync(recursive: true);
  File('$pkgDir${Platform.pathSeparator}.pin').writeAsStringSync('$ref\n');
}

String? readCommit(String pkgDir) {
  final f = File('$pkgDir${Platform.pathSeparator}.commit');
  if (!f.existsSync()) return null;
  final text = f.readAsStringSync().trim().toLowerCase();
  if (text.isEmpty || !RegExp(r'^[0-9a-f]{7,40}$').hasMatch(text)) {
    return null;
  }
  return text;
}

void writeCommit(String pkgDir, String commit) {
  Directory(pkgDir).createSync(recursive: true);
  File('$pkgDir${Platform.pathSeparator}.commit')
      .writeAsStringSync('${commit.toLowerCase()}\n');
}

/// SHA-256 of installed package `.kl` sources (sorted by basename).
///
/// Format is stable: for each file, `name\0` + bytes + `\0`.
String packageContentHash(String pkgDir) {
  final files = <File>[];
  for (final entity in Directory(pkgDir).listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (!name.endsWith('.kl') || name.endsWith('_test.kl')) continue;
    files.add(entity);
  }
  files.sort((a, b) {
    final an = a.path.split(Platform.pathSeparator).last;
    final bn = b.path.split(Platform.pathSeparator).last;
    return an.compareTo(bn);
  });
  final bytes = BytesBuilder(copy: false);
  for (final f in files) {
    final name = f.path.split(Platform.pathSeparator).last;
    bytes.add(utf8.encode(name));
    bytes.addByte(0);
    bytes.add(f.readAsBytesSync());
    bytes.addByte(0);
  }
  return sha256.convert(bytes.takeBytes()).toString();
}

// --- klin.mod ---------------------------------------------------------------

final class KlinMod {
  final int version;
  final Map<String, String> requires; // path → ref (Klin packages)
  final Map<String, String> devices; // path → ref (SVD assets, issue 053)
  final Map<String, String> boards; // path → ref (.ioc assets, issue 074)

  KlinMod({
    this.version = 1,
    Map<String, String>? requires,
    Map<String, String>? devices,
    Map<String, String>? boards,
  })  : requires = Map<String, String>.from(requires ?? {}),
        devices = Map<String, String>.from(devices ?? {}),
        boards = Map<String, String>.from(boards ?? {});

  static KlinMod empty() => KlinMod();

  bool get isEmpty =>
      requires.isEmpty && devices.isEmpty && boards.isEmpty;
}

/// Find `klin.mod` walking up from [startDir]. Returns null if none.
File? findKlinModFile(String startDir) {
  var dir = Directory(startDir).absolute;
  for (var i = 0; i < 32; i++) {
    final candidate = File('${dir.path}${Platform.pathSeparator}klin.mod');
    if (candidate.existsSync()) return candidate;
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  return null;
}

KlinMod parseKlinMod(String content) {
  final requires = <String, String>{};
  final devices = <String, String>{};
  final boards = <String, String>{};
  var version = 1;
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('//') || line.startsWith('#')) {
      continue;
    }
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length == 2 && parts[0] == 'klin') {
      version = int.tryParse(parts[1]) ?? 1;
      continue;
    }
    if (parts.length == 3 && parts[0] == 'require') {
      requires[parts[1]] = parts[2];
      continue;
    }
    if (parts.length == 3 && parts[0] == 'device') {
      parseRemoteAsset('${parts[1]}@${parts[2]}');
      devices[parts[1]] = parts[2];
      continue;
    }
    if (parts.length == 3 && parts[0] == 'board') {
      parseRemoteAsset('${parts[1]}@${parts[2]}');
      boards[parts[1]] = parts[2];
      continue;
    }
    throw FormatException('invalid klin.mod line: `$rawLine`');
  }
  return KlinMod(
    version: version,
    requires: requires,
    devices: devices,
    boards: boards,
  );
}

String formatKlinMod(KlinMod mod) {
  final buf = StringBuffer('klin ${mod.version}\n');
  final reqKeys = mod.requires.keys.toList()..sort();
  for (final path in reqKeys) {
    buf.writeln('require $path ${mod.requires[path]}');
  }
  final devKeys = mod.devices.keys.toList()..sort();
  for (final path in devKeys) {
    buf.writeln('device $path ${mod.devices[path]}');
  }
  final boardKeys = mod.boards.keys.toList()..sort();
  for (final path in boardKeys) {
    buf.writeln('board $path ${mod.boards[path]}');
  }
  return buf.toString();
}

KlinMod loadKlinMod(File file) => parseKlinMod(file.readAsStringSync());

void saveKlinMod(File file, KlinMod mod) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(formatKlinMod(mod));
}

// --- Remote SVD / device assets (issue 053) ---------------------------------

/// MVP allowlist: patched SVD mirrors only (not raw ST).
const allowedDeviceRepos = {
  'github/tinygo-org/stm32-svd',
};

/// MVP allowlist for CubeMX `.ioc` board pinouts (issue 074).
const allowedBoardRepos = {
  'github/klin-lang/boards',
};

/// Parsed `host/owner/repo/rel/path.{svd,ioc}` with optional `@ref`.
final class RemoteAsset {
  final String host;
  final String owner;
  final String repo;
  final String filePath; // repo-relative, e.g. svd/stm32f411.svd
  final String? ref;

  const RemoteAsset({
    required this.host,
    required this.owner,
    required this.repo,
    required this.filePath,
    this.ref,
  });

  /// Full asset path without `@ref`.
  String get path => '$host/$owner/$repo/$filePath';

  String get repoPath => '$host/$owner/$repo';

  bool get isBoard => filePath.toLowerCase().endsWith('.ioc');

  bool get isDevice => filePath.toLowerCase().endsWith('.svd');

  RemoteImport get asRepo => RemoteImport(
        host: host,
        owner: owner,
        repo: repo,
        ref: ref,
      );
}

bool _isRemoteAssetPath(String spec, String suffix) {
  var path = spec.trim();
  final at = path.lastIndexOf('@');
  if (at > 0) path = path.substring(0, at).trim();
  if (!path.toLowerCase().endsWith(suffix)) return false;
  final slash = path.indexOf('/');
  if (slash <= 0) return false;
  return remoteHosts.contains(path.substring(0, slash));
}

/// True when [spec] looks like a remote device asset (`….svd`).
bool isRemoteDevicePath(String spec) => _isRemoteAssetPath(spec, '.svd');

/// True when [spec] looks like a remote board pinout (`….ioc`).
bool isRemoteBoardPath(String spec) => _isRemoteAssetPath(spec, '.ioc');

/// Parse `github/owner/repo/rel/file.{svd,ioc}` or `…@ref`.
RemoteAsset parseRemoteAsset(String spec) {
  var path = spec.trim();
  String? ref;
  final at = path.lastIndexOf('@');
  if (at > 0) {
    ref = path.substring(at + 1).trim();
    path = path.substring(0, at).trim();
    if (ref.isEmpty) {
      throw FormatException('empty @ref in remote asset `$spec`');
    }
    if (ref.contains('..') || ref.contains('/') || ref.contains('\\')) {
      throw FormatException('invalid @ref in remote asset `$spec`');
    }
  }
  final isSvd = path.toLowerCase().endsWith('.svd');
  final isIoc = path.toLowerCase().endsWith('.ioc');
  if (!isSvd && !isIoc) {
    throw FormatException(
      'remote asset `$spec` must end with `.svd` or `.ioc`',
    );
  }
  final parts = path.split('/');
  if (parts.length < 4 || parts.any((p) => p.isEmpty)) {
    throw FormatException(
      'remote asset `$spec` must be host/owner/repo/path '
      '(optionally @ref)',
    );
  }
  final host = parts[0];
  if (!remoteHosts.contains(host)) {
    throw FormatException(
      'remote host `$host` is not allowed (use github or gitlab)',
    );
  }
  final owner = parts[1];
  final repo = parts[2];
  if (!_isSafePathSegment(owner) || !_isSafePathSegment(repo)) {
    throw FormatException(
      'remote asset `$spec` has an invalid owner or repo segment',
    );
  }
  final fileParts = parts.sublist(3);
  for (final seg in fileParts) {
    if (!_isSafePathSegment(seg)) {
      throw FormatException(
        'remote asset `$spec` has an invalid path segment `$seg`',
      );
    }
  }
  final repoKey = '$host/$owner/$repo';
  final allow = isSvd ? allowedDeviceRepos : allowedBoardRepos;
  final allowHint = isSvd
      ? 'github/tinygo-org/stm32-svd'
      : 'github/klin-lang/boards';
  if (!allow.contains(repoKey)) {
    throw FormatException(
      'remote ${isSvd ? 'device' : 'board'} repo `$repoKey` is not on the '
      'allowlist (MVP: $allowHint)',
    );
  }
  return RemoteAsset(
    host: host,
    owner: owner,
    repo: repo,
    filePath: fileParts.join('/'),
    ref: ref,
  );
}

/// Directory for a cached device repo: `$cache/asset/host/owner/repo`.
String assetCacheDir(RemoteAsset asset, {String? cacheRoot}) {
  final root = klinCacheRoot(override: cacheRoot);
  final sep = Platform.pathSeparator;
  return '$root${sep}asset$sep${asset.host}$sep${asset.owner}$sep${asset.repo}';
}

/// Absolute path to a cached SVD file, or null if missing.
String? cachedDeviceFilePath(RemoteAsset asset, {String? cacheRoot}) {
  final dir = assetCacheDir(asset, cacheRoot: cacheRoot);
  final sep = Platform.pathSeparator;
  final file = File('$dir$sep${asset.filePath.replaceAll('/', sep)}');
  if (!file.existsSync()) return null;
  return file.path;
}

String fileContentHash(String filePath) {
  final bytes = File(filePath).readAsBytesSync();
  return sha256.convert(bytes).toString();
}

bool _isDeviceRepoInstalled(String assetDir, String pinValue) {
  if (!Directory(assetDir).existsSync()) return false;
  final pin = readPin(assetDir);
  return pin == pinValue && readCommit(assetDir) != null;
}

/// Fetch [asset] into the asset cache. Returns `(assetDir, commitSha)`.
Future<(String assetDir, String commit)> fetchRemoteAsset(
  RemoteAsset asset, {
  required String gitRef,
  String? pin,
  String? cacheRoot,
  bool force = false,
}) async {
  final pinValue = pin ?? gitRef;
  final assetDir = assetCacheDir(asset, cacheRoot: cacheRoot);
  final sep = Platform.pathSeparator;
  final targetFile = File(
    '$assetDir$sep${asset.filePath.replaceAll('/', sep)}',
  );

  if (!force &&
      _isDeviceRepoInstalled(assetDir, pinValue) &&
      targetFile.existsSync()) {
    final commit = readCommit(assetDir)!;
    if (cacheSatisfiesRemoteFetch(
      cachedPin: pinValue,
      pinValue: pinValue,
      cachedCommit: commit,
      gitRef: gitRef,
    )) {
      return (assetDir, commit);
    }
  }

  final tmp = Directory.systemTemp.createTempSync('klin_device_');
  // Stage under the cache parent so rename stays on one filesystem.
  final parent = Directory(assetDir).parent;
  parent.createSync(recursive: true);
  final staging = Directory(
    '${parent.path}$sep.klin_devstage_${DateTime.now().microsecondsSinceEpoch}',
  )..createSync();
  var swapped = false;
  try {
    final commit = await _gitCheckoutRef(asset.asRepo.gitUrl, gitRef, tmp.path);
    final srcFile = File(
      [tmp.path, ...asset.filePath.split('/')].join(sep),
    );
    if (!srcFile.existsSync()) {
      throw FileSystemException(
        'remote device `${asset.path}` not found in repo after fetch',
        srcFile.path,
      );
    }
    final destRel = asset.filePath.replaceAll('/', sep);
    final dest = File('${staging.path}$sep$destRel');
    dest.parent.createSync(recursive: true);
    srcFile.copySync(dest.path);
    File('${staging.path}$sep.pin').writeAsStringSync('$pinValue\n');
    File('${staging.path}$sep.commit')
        .writeAsStringSync('${commit.toLowerCase()}\n');

    // Keep sibling .svd / .ioc paths: prefer bytes from this checkout; only
    // reuse prior cache bytes when pin and commit are unchanged (adding a file).
    if (Directory(assetDir).existsSync()) {
      final prevPin = readPin(assetDir);
      final prevCommit = readCommit(assetDir);
      final samePin = prevPin == pinValue;
      final sameCommit = prevCommit != null &&
          (commit.startsWith(prevCommit) || prevCommit.startsWith(commit));
      for (final entity in Directory(assetDir).listSync(recursive: true)) {
        if (entity is! File) continue;
        final name = entity.path.split(sep).last;
        final lower = name.toLowerCase();
        if (!lower.endsWith('.svd') && !lower.endsWith('.ioc')) continue;
        final rel = entity.path.substring(assetDir.length + 1);
        final staged = File('${staging.path}$sep$rel');
        if (staged.existsSync()) continue;
        staged.parent.createSync(recursive: true);
        final fromCheckout = File([tmp.path, ...rel.split(sep)].join(sep));
        if (fromCheckout.existsSync()) {
          fromCheckout.copySync(staged.path);
        } else if (samePin && sameCommit) {
          entity.copySync(staged.path);
        }
      }
    }

    _swapCacheDir(staging.path, assetDir);
    swapped = true;
    return (assetDir, commit.toLowerCase());
  } finally {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    if (!swapped && staging.existsSync()) {
      staging.deleteSync(recursive: true);
    }
  }
}

/// Atomically replace [destDir] with [stagingDir] (same parent filesystem).
void _swapCacheDir(String stagingDir, String destDir) {
  final dest = Directory(destDir);
  final staging = Directory(stagingDir);
  if (!dest.existsSync()) {
    staging.renameSync(destDir);
    return;
  }
  final backup = Directory('$destDir.__klin_old');
  if (backup.existsSync()) backup.deleteSync(recursive: true);
  dest.renameSync(backup.path);
  try {
    staging.renameSync(destDir);
  } catch (_) {
    if (!Directory(destDir).existsSync() && backup.existsSync()) {
      backup.renameSync(destDir);
    }
    rethrow;
  }
  backup.deleteSync(recursive: true);
}

/// Ensure [asset] is installed per [mod] / lock. Updates `device` lines + lock.
Future<(String filePath, String ref, bool modUpdated)> ensureRemoteDevice({
  required RemoteAsset asset,
  required KlinMod mod,
  required File modFile,
  KlinLock? lock,
  File? lockFile,
  String? cacheRoot,
  bool force = false,
}) async {
  var modUpdated = false;
  String version;
  if (asset.ref != null) {
    version = asset.ref!;
    if (mod.devices[asset.path] != version) modUpdated = true;
  } else if (mod.devices.containsKey(asset.path)) {
    version = mod.devices[asset.path]!;
  } else {
    version = await resolveLatestRef(asset.asRepo);
    modUpdated = true;
  }

  final lockEntry = lock?.packages[asset.path];
  final assetDir = assetCacheDir(asset, cacheRoot: cacheRoot);
  final cachePin = readPin(assetDir);
  final cacheCommit = readCommit(assetDir);
  final cachedFile = cachedDeviceFilePath(asset, cacheRoot: cacheRoot);

  // Shared repo cache: one .commit for all .svd files. Prefer an existing
  // same-pin install over a stale per-file lock SHA (avoids downgrade that
  // would mix sibling SVDs from different checkouts).
  final cacheReusable = !force &&
      cachePin == version &&
      cacheCommit != null &&
      cachedFile != null;

  final useLock = !force &&
      !cacheReusable &&
      lockEntry != null &&
      lockEntry.version == version &&
      RegExp(r'^[0-9a-f]{7,40}$').hasMatch(lockEntry.commit);
  final gitRef = cacheReusable
      ? cacheCommit
      : (useLock ? lockEntry.commit : version);

  final (_, commit) = await fetchRemoteAsset(
    asset,
    gitRef: gitRef,
    pin: version,
    cacheRoot: cacheRoot,
    force: force,
  );
  final filePath = cachedDeviceFilePath(asset, cacheRoot: cacheRoot);
  if (filePath == null) {
    throw FileSystemException(
      'device `${asset.path}` missing after fetch',
      assetDir,
    );
  }
  final hash = fileContentHash(filePath);
  if (useLock) {
    if (lockEntry.hash != hash) {
      throw StateError(
        'klin.lock hash mismatch for `${asset.path}@$version` '
        '(expected sha256:${lockEntry.hash}, got sha256:$hash)',
      );
    }
    if (!commit.startsWith(lockEntry.commit) &&
        !lockEntry.commit.startsWith(commit)) {
      throw StateError(
        'klin.lock commit mismatch for `${asset.path}@$version` '
        '(expected ${lockEntry.commit}, got $commit)',
      );
    }
  } else if (!force &&
      lockEntry != null &&
      lockEntry.version == version &&
      RegExp(r'^[0-9a-f]{7,40}$').hasMatch(lockEntry.commit) &&
      (commit.startsWith(lockEntry.commit) ||
          lockEntry.commit.startsWith(commit)) &&
      lockEntry.hash != hash) {
    throw StateError(
      'klin.lock hash mismatch for `${asset.path}@$version` '
      '(expected sha256:${lockEntry.hash}, got sha256:$hash)',
    );
  }

  if (modUpdated || mod.devices[asset.path] != version) {
    mod.devices[asset.path] = version;
    saveKlinMod(modFile, mod);
    modUpdated = true;
  }

  final outLock = lock ?? KlinLock.empty();
  final prev = outLock.packages[asset.path];
  if (prev == null ||
      prev.version != version ||
      prev.commit != commit ||
      prev.hash != hash) {
    outLock.packages[asset.path] = KlinLockEntry(
      version: version,
      commit: commit,
      hash: hash,
    );
    // Align sibling device locks for the same repo + pin to this commit.
    final prefix = '${asset.repoPath}/';
    for (final path in outLock.packages.keys.toList()) {
      if (path == asset.path || !path.startsWith(prefix)) continue;
      final entry = outLock.packages[path]!;
      if (entry.version != version) continue;
      final siblingFile = cachedDeviceFilePath(
        parseRemoteAsset(path),
        cacheRoot: cacheRoot,
      );
      if (siblingFile == null) continue;
      outLock.packages[path] = KlinLockEntry(
        version: version,
        commit: commit,
        hash: fileContentHash(siblingFile),
      );
    }
    final outFile = lockFile ?? klinLockFileFor(modFile);
    saveKlinLock(outFile, outLock);
  }
  return (filePath, version, modUpdated);
}

/// Resolve a `$device` / `$peripherals_from_svd` path to a local SVD file.
///
/// Order: existing local file (incl. vendored `github/…/*.svd`) → asset cache
/// (offline). Throws [FileSystemException] with a `klin get` hint when a
/// remote-shaped path is missing from cache.
String resolveSvdPath(
  String svdArg, {
  required String sourcePath,
  String? cacheRoot,
}) {
  final sourceFile = File(sourcePath).absolute;
  final sourceDir = sourceFile.parent;
  final localFile = File(
    svdArg.startsWith('/') ||
            (svdArg.length >= 3 &&
                svdArg[1] == ':' &&
                (svdArg[2] == '\\' || svdArg[2] == '/'))
        ? svdArg
        : '${sourceDir.path}${Platform.pathSeparator}$svdArg',
  ).absolute;
  if (localFile.existsSync()) return localFile.path;

  if (isRemoteDevicePath(svdArg)) {
    final asset = parseRemoteAsset(svdArg);
    // Prefer pin from klin.mod when path has no @ref.
    RemoteAsset effective = asset;
    if (asset.ref == null) {
      final modFile = findKlinModFile(sourceDir.path);
      if (modFile != null) {
        final mod = loadKlinMod(modFile);
        final pinned = mod.devices[asset.path];
        if (pinned != null) {
          effective = RemoteAsset(
            host: asset.host,
            owner: asset.owner,
            repo: asset.repo,
            filePath: asset.filePath,
            ref: pinned,
          );
        }
      }
    }
    final cached = cachedDeviceFilePath(effective, cacheRoot: cacheRoot);
    if (cached != null) {
      final dir = assetCacheDir(effective, cacheRoot: cacheRoot);
      final pin = readPin(dir);
      if (effective.ref == null || pin == effective.ref) return cached;
    }
    throw FileSystemException(
      'remote device `${asset.path}` is not in the Klin cache; '
      'run `klin get ${asset.path}${asset.ref != null ? '@${asset.ref}' : ''}` '
      'first (compile stays offline)',
      cachedDeviceFilePath(asset, cacheRoot: cacheRoot) ??
          assetCacheDir(asset, cacheRoot: cacheRoot),
    );
  }

  throw FileSystemException('SVD file not found', localFile.path);
}

/// Ensure [asset] (`.ioc`) is installed per [mod] / lock. Updates `board` lines.
///
/// Writes **only** into `$KLIN_CACHE/asset/` — never overwrites a project-local
/// `board/*.ioc` (issue 074).
Future<(String filePath, String ref, bool modUpdated)> ensureRemoteBoard({
  required RemoteAsset asset,
  required KlinMod mod,
  required File modFile,
  KlinLock? lock,
  File? lockFile,
  String? cacheRoot,
  bool force = false,
}) async {
  if (!asset.isBoard) {
    throw FormatException(
      'ensureRemoteBoard expects a `.ioc` asset, got `${asset.path}`',
    );
  }
  var modUpdated = false;
  String version;
  if (asset.ref != null) {
    version = asset.ref!;
    if (mod.boards[asset.path] != version) modUpdated = true;
  } else if (mod.boards.containsKey(asset.path)) {
    version = mod.boards[asset.path]!;
  } else {
    version = await resolveLatestRef(asset.asRepo);
    modUpdated = true;
  }

  final lockEntry = lock?.packages[asset.path];
  final assetDir = assetCacheDir(asset, cacheRoot: cacheRoot);
  final cachePin = readPin(assetDir);
  final cacheCommit = readCommit(assetDir);
  final cachedFile = cachedDeviceFilePath(asset, cacheRoot: cacheRoot);

  final cacheReusable = !force &&
      cachePin == version &&
      cacheCommit != null &&
      cachedFile != null;

  final useLock = !force &&
      !cacheReusable &&
      lockEntry != null &&
      lockEntry.version == version &&
      RegExp(r'^[0-9a-f]{7,40}$').hasMatch(lockEntry.commit);
  final gitRef = cacheReusable
      ? cacheCommit
      : (useLock ? lockEntry.commit : version);

  final (_, commit) = await fetchRemoteAsset(
    asset,
    gitRef: gitRef,
    pin: version,
    cacheRoot: cacheRoot,
    force: force,
  );
  final filePath = cachedDeviceFilePath(asset, cacheRoot: cacheRoot);
  if (filePath == null) {
    throw FileSystemException(
      'board `${asset.path}` missing after fetch',
      assetDir,
    );
  }
  final hash = fileContentHash(filePath);
  if (useLock) {
    if (lockEntry.hash != hash) {
      throw StateError(
        'klin.lock hash mismatch for `${asset.path}@$version` '
        '(expected sha256:${lockEntry.hash}, got sha256:$hash)',
      );
    }
    if (!commit.startsWith(lockEntry.commit) &&
        !lockEntry.commit.startsWith(commit)) {
      throw StateError(
        'klin.lock commit mismatch for `${asset.path}@$version` '
        '(expected ${lockEntry.commit}, got $commit)',
      );
    }
  } else if (!force &&
      lockEntry != null &&
      lockEntry.version == version &&
      RegExp(r'^[0-9a-f]{7,40}$').hasMatch(lockEntry.commit) &&
      (commit.startsWith(lockEntry.commit) ||
          lockEntry.commit.startsWith(commit)) &&
      lockEntry.hash != hash) {
    throw StateError(
      'klin.lock hash mismatch for `${asset.path}@$version` '
      '(expected sha256:${lockEntry.hash}, got sha256:$hash)',
    );
  }

  if (modUpdated || mod.boards[asset.path] != version) {
    mod.boards[asset.path] = version;
    saveKlinMod(modFile, mod);
    modUpdated = true;
  }

  final outLock = lock ?? KlinLock.empty();
  final prev = outLock.packages[asset.path];
  if (prev == null ||
      prev.version != version ||
      prev.commit != commit ||
      prev.hash != hash) {
    outLock.packages[asset.path] = KlinLockEntry(
      version: version,
      commit: commit,
      hash: hash,
    );
    final prefix = '${asset.repoPath}/';
    for (final path in outLock.packages.keys.toList()) {
      if (path == asset.path || !path.startsWith(prefix)) continue;
      if (!path.toLowerCase().endsWith('.ioc')) continue;
      final entry = outLock.packages[path]!;
      if (entry.version != version) continue;
      final siblingFile = cachedDeviceFilePath(
        parseRemoteAsset(path),
        cacheRoot: cacheRoot,
      );
      if (siblingFile == null) continue;
      outLock.packages[path] = KlinLockEntry(
        version: version,
        commit: commit,
        hash: fileContentHash(siblingFile),
      );
    }
    final outFile = lockFile ?? klinLockFileFor(modFile);
    saveKlinLock(outFile, outLock);
  }
  return (filePath, version, modUpdated);
}

/// Resolve a `$board("…")` path to a local `.ioc` file.
///
/// Order: existing local file (project `board/*.ioc` wins) → asset cache
/// (offline). Never downloads. Never overwrites a local project `.ioc`.
String resolveBoardPath(
  String boardArg, {
  required String sourcePath,
  String? cacheRoot,
}) {
  final sourceFile = File(sourcePath).absolute;
  final sourceDir = sourceFile.parent;
  final localFile = File(
    boardArg.startsWith('/') ||
            (boardArg.length >= 3 &&
                boardArg[1] == ':' &&
                (boardArg[2] == '\\' || boardArg[2] == '/'))
        ? boardArg
        : '${sourceDir.path}${Platform.pathSeparator}$boardArg',
  ).absolute;
  if (localFile.existsSync()) return localFile.path;

  if (isRemoteBoardPath(boardArg)) {
    final asset = parseRemoteAsset(boardArg);
    RemoteAsset effective = asset;
    if (asset.ref == null) {
      final modFile = findKlinModFile(sourceDir.path);
      if (modFile != null) {
        final mod = loadKlinMod(modFile);
        final pinned = mod.boards[asset.path];
        if (pinned != null) {
          effective = RemoteAsset(
            host: asset.host,
            owner: asset.owner,
            repo: asset.repo,
            filePath: asset.filePath,
            ref: pinned,
          );
        }
      }
    }
    final cached = cachedDeviceFilePath(effective, cacheRoot: cacheRoot);
    if (cached != null) {
      final dir = assetCacheDir(effective, cacheRoot: cacheRoot);
      final pin = readPin(dir);
      if (effective.ref == null || pin == effective.ref) return cached;
    }
    throw FileSystemException(
      'remote board `${asset.path}` is not in the Klin cache; '
      'run `klin get ${asset.path}${asset.ref != null ? '@${asset.ref}' : ''}` '
      'first (compile stays offline)',
      cachedDeviceFilePath(asset, cacheRoot: cacheRoot) ??
          assetCacheDir(asset, cacheRoot: cacheRoot),
    );
  }

  throw FileSystemException('board .ioc file not found', localFile.path);
}

// --- klin.lock (issue 065) --------------------------------------------------

/// One locked remote: mod version pin → resolved commit + content hash.
final class KlinLockEntry {
  final String version;
  final String commit;
  final String hash; // sha256 hex of package .kl sources

  const KlinLockEntry({
    required this.version,
    required this.commit,
    required this.hash,
  });
}

final class KlinLock {
  final int version;
  final Map<String, KlinLockEntry> packages; // path → entry

  KlinLock({this.version = 1, Map<String, KlinLockEntry>? packages})
      : packages = Map<String, KlinLockEntry>.from(packages ?? {});

  static KlinLock empty() => KlinLock();
}

/// `klin.lock` beside [modFile], if present.
File klinLockFileFor(File modFile) =>
    File('${modFile.parent.path}${Platform.pathSeparator}klin.lock');

KlinLock parseKlinLock(String content) {
  final packages = <String, KlinLockEntry>{};
  var version = 1;
  for (final rawLine in content.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('//') || line.startsWith('#')) {
      continue;
    }
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length == 3 && parts[0] == 'klin' && parts[1] == 'lock') {
      version = int.tryParse(parts[2]) ?? 1;
      continue;
    }
    // path version commit sha256:<hex>
    if (parts.length == 4 && parts[3].startsWith('sha256:')) {
      final commit = parts[2].toLowerCase();
      if (!RegExp(r'^[0-9a-f]{7,40}$').hasMatch(commit)) {
        throw FormatException('invalid klin.lock commit: `$rawLine`');
      }
      final hash = parts[3].substring('sha256:'.length);
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
        throw FormatException('invalid klin.lock hash: `$rawLine`');
      }
      packages[parts[0]] = KlinLockEntry(
        version: parts[1],
        commit: commit,
        hash: hash,
      );
      continue;
    }
    throw FormatException('invalid klin.lock line: `$rawLine`');
  }
  return KlinLock(version: version, packages: packages);
}

String formatKlinLock(KlinLock lock) {
  final buf = StringBuffer('klin lock ${lock.version}\n');
  final keys = lock.packages.keys.toList()..sort();
  for (final path in keys) {
    final e = lock.packages[path]!;
    buf.writeln('$path ${e.version} ${e.commit} sha256:${e.hash}');
  }
  return buf.toString();
}

KlinLock loadKlinLock(File file) => parseKlinLock(file.readAsStringSync());

void saveKlinLock(File file, KlinLock lock) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(formatKlinLock(lock));
}

KlinLock loadKlinLockOrEmpty(File file) {
  if (!file.existsSync()) return KlinLock.empty();
  return loadKlinLock(file);
}

/// Parse `v1.2.3` / `1.2.3` into `[major, minor, patch]`, else null.
List<int>? parseSemverParts(String ref) {
  final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(ref.trim());
  if (m == null) return null;
  return [
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  ];
}

/// Compare two semver refs. Returns negative / zero / positive, or null if
/// either side is not strict `v?X.Y.Z`.
int? compareSemverRefs(String a, String b) {
  final pa = parseSemverParts(a);
  final pb = parseSemverParts(b);
  if (pa == null || pb == null) return null;
  for (var i = 0; i < 3; i++) {
    final c = pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return 0;
}

/// True when [candidate] should replace [current] (`klin upgrade` / outdated).
///
/// Semver pins: only when candidate is greater than current. Otherwise any
/// different latest (branch / non-semver) is treated as an upgrade candidate.
bool isUpgradeTarget(String current, String candidate) {
  if (current == candidate) return false;
  final cmp = compareSemverRefs(current, candidate);
  if (cmp != null) return cmp < 0;
  return true;
}

/// Resolve "latest" ref for a remote: newest `v*` semver tag, else main/master.
Future<String> resolveLatestRef(RemoteImport remote) async {
  final tags = await _gitLsRemote(remote.gitUrl, '--tags');
  final semver = <(List<int>, String)>[];
  for (final line in tags) {
    // <sha>\trefs/tags/v1.2.3 or refs/tags/v1.2.3^{}
    final tab = line.indexOf('\t');
    if (tab < 0) continue;
    var ref = line.substring(tab + 1).trim();
    if (ref.endsWith('^{}')) continue;
    const prefix = 'refs/tags/';
    if (!ref.startsWith(prefix)) continue;
    final tag = ref.substring(prefix.length);
    final parts = parseSemverParts(tag);
    if (parts == null) continue;
    semver.add((parts, tag));
  }
  if (semver.isNotEmpty) {
    semver.sort((a, b) {
      for (var i = 0; i < 3; i++) {
        final c = b.$1[i].compareTo(a.$1[i]);
        if (c != 0) return c;
      }
      return 0;
    });
    return semver.first.$2;
  }

  final heads = await _gitLsRemote(remote.gitUrl, '--heads');
  for (final preferred in ['main', 'master']) {
    for (final line in heads) {
      if (line.endsWith('refs/heads/$preferred')) return preferred;
    }
  }
  throw ProcessException(
    'git',
    ['ls-remote', remote.gitUrl],
    'no tags or main/master on ${remote.gitUrl}',
  );
}

/// One package where [klin.mod] pin is behind remote latest (issue 066).
final class OutdatedPackage {
  final String path;
  final String current;
  final String latest;

  const OutdatedPackage({
    required this.path,
    required this.current,
    required this.latest,
  });
}

typedef LatestRefResolver = Future<String> Function(RemoteImport remote);

/// Compare `klin.mod` requires to remote latest tags/refs.
///
/// [onlyPaths] limits the scan (must already be in [mod.requires]).
Future<List<OutdatedPackage>> collectOutdated(
  KlinMod mod, {
  Iterable<String>? onlyPaths,
  LatestRefResolver resolveLatest = resolveLatestRef,
}) async {
  final paths = <String>[];
  if (onlyPaths == null || onlyPaths.isEmpty) {
    paths.addAll(mod.requires.keys);
  } else {
    for (final raw in onlyPaths) {
      final remote = parseRemoteImport(raw);
      if (remote.ref != null) {
        throw FormatException(
          'outdated/upgrade path must not include @ref (`$raw`)',
        );
      }
      if (!mod.requires.containsKey(remote.path)) {
        throw FormatException('`$remote.path` is not in klin.mod requires');
      }
      paths.add(remote.path);
    }
  }
  paths.sort();

  final out = <OutdatedPackage>[];
  for (final path in paths) {
    final current = mod.requires[path]!;
    final latest = await resolveLatest(parseRemoteImport(path));
    if (isUpgradeTarget(current, latest)) {
      out.add(OutdatedPackage(path: path, current: current, latest: latest));
    }
  }
  return out;
}

String formatOutdatedReport(List<OutdatedPackage> rows) {
  if (rows.isEmpty) return 'all packages up to date\n';
  final buf = StringBuffer();
  for (final row in rows) {
    buf.writeln('${row.path}\t${row.current}\t${row.latest}');
  }
  return buf.toString();
}

Future<List<String>> _gitLsRemote(String url, String mode) async {
  final result = await Process.run('git', ['ls-remote', mode, url]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      ['ls-remote', mode, url],
      '${result.stderr}'.trim().isEmpty
          ? 'git ls-remote failed'
          : '${result.stderr}'.trim(),
      result.exitCode,
    );
  }
  return '${result.stdout}'
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

/// Whether an installed cache entry can satisfy a fetch without network.
///
/// When [gitRef] looks like a commit SHA (lock prefer-SHA), the cached
/// `.commit` must match — otherwise stale pin+wrong-SHA would skip repair.
bool cacheSatisfiesRemoteFetch({
  required String? cachedPin,
  required String pinValue,
  required String? cachedCommit,
  required String gitRef,
}) {
  if (cachedPin != pinValue || cachedCommit == null) return false;
  if (!RegExp(r'^[0-9a-fA-F]{7,40}$').hasMatch(gitRef)) return true;
  final want = gitRef.toLowerCase();
  final have = cachedCommit.toLowerCase();
  return have.startsWith(want) || want.startsWith(have);
}

final _linkAttrPathRe = RegExp(r'link\("([^"]+)"\)');

/// Whether every `@[link("….c|.h|.s|.S")]` path named from package `.kl`
/// sources is present in [pkgDir].
///
/// Older Klin installs copied only `.kl`; after a compiler upgrade the pin
/// and commit can still match while freestanding units are missing — those
/// installs must be re-fetched.
bool packageCacheHasRequiredLinkUnits(String pkgDir) {
  final dir = Directory(pkgDir);
  if (!dir.existsSync()) return false;
  for (final entity in dir.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (!name.endsWith('.kl') || name.endsWith('_test.kl')) continue;
    final text = entity.readAsStringSync();
    for (final m in _linkAttrPathRe.allMatches(text)) {
      final raw = m.group(1)!;
      if (raw.startsWith('-')) continue;
      final base = raw.split(RegExp(r'[/\\]')).last;
      if (!_isPackageNativeUnit(base)) continue;
      final linked = File('$pkgDir${Platform.pathSeparator}$base');
      if (!linked.existsSync()) return false;
    }
  }
  return true;
}

bool _isPackageNativeUnit(String name) {
  return name.endsWith('.c') ||
      name.endsWith('.h') ||
      name.endsWith('.s') ||
      name.endsWith('.S');
}

/// Fetch [remote] at [gitRef] into the package cache.
///
/// Returns `(pkgDir, commitSha)`. [pin] is written to `.pin` (klin.mod version);
/// defaults to [gitRef]. [force] replaces an existing install.
Future<(String pkgDir, String commit)> fetchRemote(
  RemoteImport remote, {
  required String gitRef,
  String? pin,
  String? cacheRoot,
  bool force = false,
}) async {
  final pinValue = pin ?? gitRef;
  final pkgDir = packageCacheDir(remote, cacheRoot: cacheRoot);
  if (!force && isPackageInstalled(pkgDir)) {
    final existing = readPin(pkgDir);
    if (existing != pinValue) {
      throw StateError(
        'package `${remote.path}` is already installed at `$existing`; '
        'use `klin update ${remote.path}@$pinValue` to change',
      );
    }
    final commit = readCommit(pkgDir);
    if (cacheSatisfiesRemoteFetch(
          cachedPin: existing,
          pinValue: pinValue,
          cachedCommit: commit,
          gitRef: gitRef,
        ) &&
        packageCacheHasRequiredLinkUnits(pkgDir)) {
      return (pkgDir, commit!);
    }
    // Missing `.commit`, pin matches but SHA ≠ locked gitRef, or install from
    // an older Klin that omitted `@[link]` `.c`/`.h`/`.s` — re-fetch.
  }

  final tmp = Directory.systemTemp.createTempSync('klin_get_');
  final staging = Directory.systemTemp.createTempSync('klin_stage_');
  try {
    final commit = await _gitCheckoutRef(remote.gitUrl, gitRef, tmp.path);

    final sourceDir = _selectPackageSourceDir(tmp.path, remote.repo);
    // Stage into a fresh dir, then swap into place so a failed copy cannot
    // wipe a previously good cache install.
    for (final entity in Directory(sourceDir).listSync(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!_isPackageSourceFile(name)) continue;
      entity.copySync('${staging.path}${Platform.pathSeparator}$name');
    }
    if (!isPackageInstalled(staging.path)) {
      throw FileSystemException(
        'remote package `${remote.path}` has no .kl sources after fetch',
        sourceDir,
      );
    }
    File('${staging.path}${Platform.pathSeparator}.pin')
        .writeAsStringSync('$pinValue\n');
    File('${staging.path}${Platform.pathSeparator}.commit')
        .writeAsStringSync('${commit.toLowerCase()}\n');

    final parent = Directory(pkgDir).parent;
    parent.createSync(recursive: true);
    if (Directory(pkgDir).existsSync()) {
      Directory(pkgDir).deleteSync(recursive: true);
    }
    staging.renameSync(pkgDir);
    return (pkgDir, commit.toLowerCase());
  } finally {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    if (staging.existsSync()) staging.deleteSync(recursive: true);
  }
}

/// Checkout [ref] into [dest]; returns full commit SHA.
Future<String> _gitCheckoutRef(String url, String ref, String dest) async {
  final isCommit = RegExp(r'^[0-9a-fA-F]{7,40}$').hasMatch(ref);
  if (!isCommit) {
    final clone = await Process.run('git', [
      'clone',
      '--depth',
      '1',
      '--branch',
      ref,
      url,
      dest,
    ]);
    if (clone.exitCode == 0) {
      return _gitRevParseHead(dest);
    }
  }

  if (Directory(dest).existsSync()) {
    Directory(dest).deleteSync(recursive: true);
  }
  Directory(dest).createSync(recursive: true);
  final init = await Process.run('git', ['-C', dest, 'init']);
  if (init.exitCode != 0) {
    throw ProcessException('git', ['init'], '${init.stderr}'.trim(), init.exitCode);
  }
  await Process.run('git', ['-C', dest, 'remote', 'add', 'origin', url]);
  final fetch = await Process.run('git', [
    '-C',
    dest,
    'fetch',
    '--depth',
    '1',
    'origin',
    ref,
  ]);
  if (fetch.exitCode != 0) {
    throw ProcessException(
      'git',
      ['fetch', 'origin', ref],
      '${fetch.stderr}'.trim().isEmpty
          ? 'git fetch failed for `$ref`'
          : '${fetch.stderr}'.trim(),
      fetch.exitCode,
    );
  }
  final co = await Process.run('git', [
    '-C',
    dest,
    'checkout',
    'FETCH_HEAD',
  ]);
  if (co.exitCode != 0) {
    throw ProcessException(
      'git',
      ['checkout', 'FETCH_HEAD'],
      '${co.stderr}'.trim(),
      co.exitCode,
    );
  }
  return _gitRevParseHead(dest);
}

Future<String> _gitRevParseHead(String repo) async {
  final result = await Process.run('git', ['-C', repo, 'rev-parse', 'HEAD']);
  if (result.exitCode != 0) {
    throw ProcessException(
      'git',
      ['rev-parse', 'HEAD'],
      '${result.stderr}'.trim(),
      result.exitCode,
    );
  }
  final sha = '${result.stdout}'.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(sha)) {
    throw ProcessException(
      'git',
      ['rev-parse', 'HEAD'],
      'unexpected HEAD sha `$sha`',
    );
  }
  return sha;
}

/// Prefer `<repo>/*.kl` inside the clone; else root `*.kl`.
String _selectPackageSourceDir(String cloneRoot, String repo) {
  final nested = '$cloneRoot${Platform.pathSeparator}$repo';
  if (_hasKlSources(nested)) return nested;
  if (_hasKlSources(cloneRoot)) return cloneRoot;
  throw FileSystemException(
    'no .kl package sources in clone of `$repo`',
    cloneRoot,
  );
}

bool _hasKlSources(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return false;
  for (final entity in d.listSync(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.endsWith('.kl') && !name.endsWith('_test.kl')) return true;
  }
  return false;
}

/// Package install copies Klin sources plus freestanding C/ASM units that
/// `@[link]` may reference (e.g. `usb_cdc_rp.c`).
bool _isPackageSourceFile(String name) {
  if (name.endsWith('_test.kl')) return false;
  if (name.endsWith('.kl')) return true;
  return _isPackageNativeUnit(name);
}

/// Ensure [remote] is installed per [mod] / lock policy.
///
/// Returns `(pkgDir, version pin, modWasUpdated)`.
/// When [lock] has a matching version entry and [force] is false, fetches by
/// locked commit SHA and verifies the content hash (issue 065).
Future<(String pkgDir, String ref, bool modUpdated)> ensureRemotePackage({
  required RemoteImport remote,
  required KlinMod mod,
  required File modFile,
  KlinLock? lock,
  File? lockFile,
  String? cacheRoot,
  bool force = false,
}) async {
  var modUpdated = false;
  String version;
  if (remote.ref != null) {
    version = remote.ref!;
    if (mod.requires[remote.path] != version) {
      modUpdated = true;
    }
  } else if (mod.requires.containsKey(remote.path)) {
    version = mod.requires[remote.path]!;
  } else {
    version = await resolveLatestRef(remote);
    modUpdated = true;
  }

  final lockEntry = lock?.packages[remote.path];
  final useLock = !force &&
      lockEntry != null &&
      lockEntry.version == version &&
      RegExp(r'^[0-9a-f]{7,40}$').hasMatch(lockEntry.commit);
  final gitRef = useLock ? lockEntry.commit : version;

  final (pkgDir, commit) = await fetchRemote(
    remote,
    gitRef: gitRef,
    pin: version,
    cacheRoot: cacheRoot,
    force: force,
  );

  final hash = packageContentHash(pkgDir);
  if (useLock) {
    if (lockEntry.hash != hash) {
      throw StateError(
        'klin.lock hash mismatch for `${remote.path}@$version` '
        '(expected sha256:${lockEntry.hash}, got sha256:$hash)',
      );
    }
    if (!commit.startsWith(lockEntry.commit) &&
        !lockEntry.commit.startsWith(commit)) {
      throw StateError(
        'klin.lock commit mismatch for `${remote.path}@$version` '
        '(expected ${lockEntry.commit}, got $commit)',
      );
    }
  }

  // Write klin.mod / klin.lock only after a successful fetch so a failed get
  // cannot leave a pin that was never installed.
  if (modUpdated || mod.requires[remote.path] != version) {
    mod.requires[remote.path] = version;
    saveKlinMod(modFile, mod);
    modUpdated = true;
  }

  final outLock = lock ?? KlinLock.empty();
  final prev = outLock.packages[remote.path];
  if (prev == null ||
      prev.version != version ||
      prev.commit != commit ||
      prev.hash != hash) {
    outLock.packages[remote.path] = KlinLockEntry(
      version: version,
      commit: commit,
      hash: hash,
    );
    final outFile = lockFile ?? klinLockFileFor(modFile);
    saveKlinLock(outFile, outLock);
  }
  return (pkgDir, version, modUpdated);
}
