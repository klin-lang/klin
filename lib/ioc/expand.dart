import 'dart:io';

import '../remote.dart';
import '../token.dart';
import 'emit.dart';
import 'parse.dart';

/// Expand `$board("…")` → Klin pin enums (issue 074).
String expandBoardIoc({
  required String boardArg,
  required String sourcePath,
  required SourcePos callPos,
  String? klinCacheDir,
}) {
  late final String iocPath;
  try {
    iocPath = resolveBoardPath(
      boardArg,
      sourcePath: sourcePath,
      cacheRoot: klinCacheDir,
    );
  } on FileSystemException catch (e) {
    throw PreprocessError(
      e.message,
      callPos,
      path: sourcePath,
    );
  }

  final text = File(iocPath).readAsStringSync();
  late final IocPinout pinout;
  try {
    pinout = parseIoc(text);
  } on IocParseError catch (e) {
    throw PreprocessError(e.message, callPos, path: sourcePath);
  }

  final note = boardArg.replaceAll('\\', '/');
  return emitIocPinout(pinout, sourceNote: note);
}
