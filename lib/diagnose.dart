import 'dart:io';

import 'checker.dart';
import 'lexer.dart';
import 'parser.dart';

/// One diagnostic line for the CLI.
///
/// [CheckError], [ParseError], and [LexError] already include their file
/// when [path] is set. Prefixing the entry path again prints
/// `main.kl:/abs/m.kl:2:10: …`. This prints the error's own file once.
/// When that file is the entry, the user's spelling of [entryPath] is
/// kept. An error with no path is attributed to the entry.
String formatFrontendError(String entryPath, Object error) {
  final String? errorPath;
  if (error is CheckError) {
    errorPath = error.path;
  } else if (error is ParseError) {
    errorPath = error.path;
  } else if (error is LexError) {
    errorPath = error.path;
  } else {
    return '$entryPath:$error';
  }
  final rendered = error.toString();
  if (errorPath == null || errorPath.isEmpty) {
    return '$entryPath:$rendered';
  }
  if (_sameFile(entryPath, errorPath)) {
    return '$entryPath:${_suffixAfterPath(rendered, errorPath)}';
  }
  return rendered;
}

bool _sameFile(String a, String b) {
  if (a == b) return true;
  try {
    return File(a).absolute.path == File(b).absolute.path;
  } on FileSystemException {
    return false;
  }
}

String _suffixAfterPath(String rendered, String path) {
  final prefix = '$path:';
  if (rendered.startsWith(prefix)) {
    return rendered.substring(prefix.length);
  }
  try {
    final abs = '${File(path).absolute.path}:';
    if (rendered.startsWith(abs)) {
      return rendered.substring(abs.length);
    }
  } on FileSystemException {
    // Keep the rendered line.
  }
  return rendered;
}
