import 'dart:io';

import 'ast.dart';
import 'checker.dart';
import 'lexer.dart';
import 'navigate.dart';
import 'parser.dart';
import 'preprocess.dart';
import 'project.dart';
import 'token.dart';

export 'source_map.dart' show SourceMap;

/// Severity for editor diagnostics (issue 086). Matches LSP Error for MVP.
enum KlinDiagnosticSeverity { error }

/// One frontend error mapped for the Language Server / editors.
final class KlinDiagnostic {
  final String message;
  final SourcePos pos;
  final String path;
  final KlinDiagnosticSeverity severity;

  const KlinDiagnostic({
    required this.message,
    required this.pos,
    required this.path,
    this.severity = KlinDiagnosticSeverity.error,
  });
}

/// Result of analyzing one Klin source buffer.
final class AnalysisResult {
  final List<KlinDiagnostic> diagnostics;
  final Program? program;

  /// True when preprocess rewrote the buffer and no usable [sourceMap] exists
  /// (e.g. after SVD fluent rewrite). Nav / completion stay disabled then.
  final bool positionsSkewed;

  /// Editor ↔ expanded position map when preprocess tracking succeeded.
  final SourceMap? sourceMap;

  /// True when diagnostics include parse recovery / fail-fast parse failures.
  /// LSP keeps the previous clean AST as `lastGood` for completion then.
  final bool hasParseErrors;

  const AnalysisResult({
    required this.diagnostics,
    this.program,
    this.positionsSkewed = false,
    this.sourceMap,
    this.hasParseErrors = false,
  });
}

/// Preprocess → lex → parse → check for a single buffer.
///
/// When [sourceOverlay] is provided (LSP open buffers), analysis uses
/// [loadProject] so imports / siblings resolve and cross-file definitions
/// work. Falls back to a single-file parse if the project load fails.
///
/// Check-phase errors are collected per function (`collectErrors: true`).
/// Lex stays fail-fast; parse recovers at declaration/statement boundaries when
/// analyzing for the LSP (`Parser(collectErrors: true)`).
///
/// [requireMain] defaults to `false` (library-friendly). CLI compile paths keep
/// calling [Checker.check] with the default `true`.
AnalysisResult analyzeSource({
  required String path,
  required String source,
  bool requireMain = false,
  Map<String, String>? sourceOverlay,
}) {
  late final PreprocessResult pp;
  try {
    pp = preprocessWithMap(source, path: path);
  } on PreprocessError catch (e) {
    return AnalysisResult(
      diagnostics: [
        KlinDiagnostic(
          message: e.message,
          pos: e.pos,
          path: e.path.isNotEmpty ? e.path : path,
        ),
      ],
    );
  }

  final expanded = pp.text;
  final map = pp.map;
  final skewed = expanded != source &&
      (map == null || map.origOfExpanded.isEmpty);

  if (sourceOverlay != null) {
    final project = _tryAnalyzeProject(
      path: path,
      source: source,
      requireMain: requireMain,
      sourceOverlay: sourceOverlay,
      openMap: map,
      skewed: skewed,
    );
    if (project != null) return project;
  }

  return _analyzeExpanded(
    path: path,
    expanded: expanded,
    map: map,
    skewed: skewed,
    requireMain: requireMain,
  );
}

AnalysisResult? _tryAnalyzeProject({
  required String path,
  required String source,
  required bool requireMain,
  required Map<String, String> sourceOverlay,
  required SourceMap? openMap,
  required bool skewed,
}) {
  String abs;
  try {
    abs = File(path).absolute.path;
  } catch (_) {
    return null;
  }
  final overlay = <String, String>{
    for (final e in sourceOverlay.entries)
      File(e.key).absolute.path: e.value,
  };
  overlay[abs] = source;

  try {
    final program = loadProject(abs, sourceOverlay: overlay);
    return _checkProgram(
      path: path,
      program: program,
      map: openMap,
      skewed: skewed,
      requireMain: requireMain,
    );
  } on PreprocessError catch (e) {
    return AnalysisResult(
      diagnostics: [
        KlinDiagnostic(
          message: e.message,
          pos: e.pos,
          path: e.path.isNotEmpty ? e.path : path,
        ),
      ],
      sourceMap: openMap,
      positionsSkewed: skewed,
    );
  } on LexError catch (e) {
    return AnalysisResult(
      diagnostics: [
        _mappedDiagnostic(
          path,
          e.message,
          e.pos,
          openMap,
          skewed,
          errorPath: e.path,
        ),
      ],
      sourceMap: openMap,
      positionsSkewed: skewed,
    );
  } on ParseError catch (e) {
    // Open-buffer syntax errors: fall through to `_analyzeExpanded` so
    // `Parser(collectErrors: true)` can report multiple diagnostics and keep
    // a partial AST. A project-level error (import alias, module name) is
    // not a syntax error of that buffer, even when its path is the open
    // file. Foreign files stay a single diagnostic — loadProject is fail-fast.
    final errPath = e.path;
    // Compare only to the absolute open path — a relative basename `path`
    // would falsely match another module's `…/same.kl` via sameDiagnosticPath.
    final inOpen = errPath != null &&
        errPath.isNotEmpty &&
        sameDiagnosticPath(errPath, abs);
    if (inOpen && !e.fromProject) return null;
    return AnalysisResult(
      diagnostics: [
        _mappedDiagnostic(
          path,
          e.message,
          e.pos,
          openMap,
          skewed,
          errorPath: e.path,
        ),
      ],
      sourceMap: openMap,
      positionsSkewed: skewed,
      hasParseErrors: true,
    );
  } on FileSystemException {
    return null;
  } on ArgumentError {
    return null;
  }
}

AnalysisResult _analyzeExpanded({
  required String path,
  required String expanded,
  required SourceMap? map,
  required bool skewed,
  required bool requireMain,
}) {
  try {
    final program = Parser(
      Lexer(expanded).tokenize(),
      collectErrors: true,
    ).parse();
    return _checkProgram(
      path: path,
      program: program,
      map: map,
      skewed: skewed,
      requireMain: requireMain,
    );
  } on LexError catch (e) {
    return AnalysisResult(
      diagnostics: [
        _mappedDiagnostic(path, e.message, e.pos, map, skewed),
      ],
      positionsSkewed: skewed,
      sourceMap: map,
    );
  } on ParseErrors catch (e) {
    final parseDiags = [
      for (final err in e.errors)
        _mappedDiagnostic(
          path,
          err.message,
          err.pos,
          map,
          skewed,
          errorPath: err.path,
        ),
    ];
    final program = e.program;
    if (program == null) {
      return AnalysisResult(
        diagnostics: parseDiags,
        positionsSkewed: skewed,
        sourceMap: map,
        hasParseErrors: true,
      );
    }
    final checked = _checkProgram(
      path: path,
      program: program,
      map: map,
      skewed: skewed,
      requireMain: requireMain,
    );
    return AnalysisResult(
      diagnostics: [...parseDiags, ...checked.diagnostics],
      program: checked.program ?? program,
      positionsSkewed: skewed,
      sourceMap: map,
      hasParseErrors: true,
    );
  } on ParseError catch (e) {
    return AnalysisResult(
      diagnostics: [
        _mappedDiagnostic(
          path,
          e.message,
          e.pos,
          map,
          skewed,
          errorPath: e.path,
        ),
      ],
      positionsSkewed: skewed,
      sourceMap: map,
      hasParseErrors: true,
    );
  }
}

AnalysisResult _checkProgram({
  required String path,
  required Program program,
  required SourceMap? map,
  required bool skewed,
  required bool requireMain,
}) {
  try {
    Checker().check(
      program,
      requireMain: requireMain,
      collectErrors: true,
    );
    return AnalysisResult(
      diagnostics: const [],
      program: program,
      positionsSkewed: skewed,
      sourceMap: map,
    );
  } on CheckErrors catch (e) {
    return AnalysisResult(
      diagnostics: [
        for (final err in e.errors)
          _mappedDiagnostic(
            path,
            err.message,
            err.pos,
            map,
            skewed,
            errorPath: err.path,
          ),
      ],
      program: program,
      positionsSkewed: skewed,
      sourceMap: map,
    );
  } on CheckError catch (e) {
    return AnalysisResult(
      diagnostics: [
        _mappedDiagnostic(
          path,
          e.message,
          e.pos,
          map,
          skewed,
          errorPath: e.path,
        ),
      ],
      program: program,
      positionsSkewed: skewed,
      sourceMap: map,
    );
  }
}

KlinDiagnostic _mappedDiagnostic(
  String openPath,
  String message,
  SourcePos pos,
  SourceMap? map,
  bool skewed, {
  String? errorPath,
}) {
  final ep = errorPath;
  final foreign = ep != null &&
      ep.isNotEmpty &&
      !sameDiagnosticPath(ep, openPath);

  if (foreign) {
    // Do not apply the open file's SourceMap to another module's positions.
    return KlinDiagnostic(message: message, pos: pos, path: ep);
  }

  if (map != null) {
    return KlinDiagnostic(
      message: message,
      pos: map.toOriginal(pos),
      path: openPath,
    );
  }
  if (!skewed) {
    return KlinDiagnostic(message: message, pos: pos, path: openPath);
  }
  return KlinDiagnostic(
    message: '$message (after preprocess)',
    pos: const SourcePos(1, 1),
    path: openPath,
  );
}

/// True when [a] and [b] name the same file.
///
/// Compares normalized full paths, and allows a relative path to match an
/// absolute (or longer) path that ends with that relative path — but not two
/// distinct directories that only share a basename.
bool sameDiagnosticPath(String a, String b) {
  if (a == b) return true;
  if (a.isEmpty || b.isEmpty) return false;
  final na = a.replaceAll('\\', '/');
  final nb = b.replaceAll('\\', '/');
  if (na == nb) return true;
  return na.endsWith('/$nb') || nb.endsWith('/$na');
}

/// Attribute a diagnostic to [openPath] for publishDiagnostics on that URI.
///
/// Errors that originated in another file (e.g. preprocess of an import) keep
/// their message but are pinned to the start of the open buffer so the editor
/// still surfaces them.
KlinDiagnostic diagnosticForOpenDocument(
  KlinDiagnostic d,
  String openPath,
) {
  if (sameDiagnosticPath(d.path, openPath)) {
    return KlinDiagnostic(
      message: d.message,
      pos: d.pos,
      path: openPath,
      severity: d.severity,
    );
  }
  return KlinDiagnostic(
    message: '${d.path}:${d.pos.line}:${d.pos.col}: ${d.message}',
    pos: const SourcePos(1, 1),
    path: openPath,
    severity: d.severity,
  );
}

SourcePos _queryPos(AnalysisResult result, int line, int col) {
  final map = result.sourceMap;
  if (map == null) return SourcePos(line, col);
  return map.toExpanded(SourcePos(line, col));
}

/// Hover text at 1-based editor [line]/[col], or null.
String? hoverAt(AnalysisResult result, int line, int col) {
  if (result.positionsSkewed || result.program == null) return null;
  final q = _queryPos(result, line, col);
  final target = findNavTarget(result.program!, q.line, q.col);
  if (target == null) return null;
  return hoverText(target);
}

/// Go-to-definition at 1-based editor [line]/[col], or null.
///
/// Definition positions in the **open** file are remapped via [SourceMap].
/// Cross-file definitions keep their path and expanded positions as stored on
/// the AST (other-file maps are not applied in MVP).
ResolvedDef? definitionAt(
  AnalysisResult result,
  int line,
  int col, {
  String? openPath,
}) {
  if (result.positionsSkewed || result.program == null) return null;
  final q = _queryPos(result, line, col);
  final target = findNavTarget(result.program!, q.line, q.col);
  final def = target?.def;
  if (def == null) return null;
  final map = result.sourceMap;
  if (map == null) return def;
  final defPath = def.path;
  if (openPath != null &&
      defPath != null &&
      defPath.isNotEmpty &&
      !sameDiagnosticPath(defPath, openPath)) {
    return def;
  }
  return ResolvedDef(map.toOriginal(def.pos), def.path);
}
