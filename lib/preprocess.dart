import 'dart:io';

import 'ioc/expand.dart';
import 'remote.dart';
import 'source_map.dart';
import 'svd/fluent.dart';
import 'svd/model.dart';
import 'token.dart';

export 'token.dart' show PreprocessError;
export 'source_map.dart' show SourceMap;

/// Result of preprocess: expanded text plus an optional position [map].
///
/// [map] is null when a secondary rewrite (e.g. SVD fluent) invalidated
/// offset tracking — callers then treat positions as skewed.
final class PreprocessResult {
  final String text;
  final SourceMap? map;

  const PreprocessResult(this.text, {this.map});
}

/// Expands `$fn` definitions and `$name(...)` invocations in [source].
String preprocess(
  String source, {
  String path = '<input>',
  String? klinCacheDir,
  List<String> klinPathDirs = const [],
}) {
  return preprocessWithMap(
    source,
    path: path,
    klinCacheDir: klinCacheDir,
    klinPathDirs: klinPathDirs,
  ).text;
}

/// Like [preprocess], but also returns a [SourceMap] when tracking succeeded.
PreprocessResult preprocessWithMap(
  String source, {
  String path = '<input>',
  String? klinCacheDir,
  List<String> klinPathDirs = const [],
}) {
  final scanner = _PpScanner(
    source,
    path,
    klinCacheDir: klinCacheDir,
    klinPathDirs: klinPathDirs,
  );
  return scanner.expandWithMap();
}

final class _MacroParam {
  final String name;
  final String kind; // `type` | `name` | `str` | `block`

  const _MacroParam(this.name, this.kind);
}

final class _MacroDef {
  final String name;
  final List<_MacroParam> params;
  final String body;
  final SourcePos pos;

  /// Import qualifier when this `$fn` was loaded from `import "…" [alias]`.
  final String? packageQualifier;

  const _MacroDef({
    required this.name,
    required this.params,
    required this.body,
    required this.pos,
    this.packageQualifier,
  });
}

final class _ScannedPathImport {
  final String spec;
  final String qualifier;

  const _ScannedPathImport(this.spec, this.qualifier);
}

/// Growable expanded buffer that records original offsets per emitted char.
final class _MappedOut {
  final StringBuffer _buf = StringBuffer();
  final List<int> origOfExp = [];

  void copyChar(String c, int origOff) {
    _buf.write(c);
    origOfExp.add(origOff);
  }

  void copyString(String s, int origStart) {
    for (var i = 0; i < s.length; i++) {
      copyChar(s[i], origStart + i);
    }
  }

  void synthetic(String s, int origOff) {
    for (var i = 0; i < s.length; i++) {
      copyChar(s[i], origOff);
    }
  }

  String get text => _buf.toString();
}

final class _PpScanner {
  final String source;
  final String path;
  final String? klinCacheDir;
  final List<String> klinPathDirs;
  int _i = 0;
  int _line = 1;
  int _col = 1;

  /// Shared across nested expansion of macro bodies (e.g. `$event_loop` in
  /// `$rtos_task` block). Set by [expand] before scanning.
  Map<String, _MacroDef>? _macros;
  int _nestDepth = 0;

  static const int _maxNestDepth = 32;

  _PpScanner(
    this.source,
    this.path, {
    this.klinCacheDir,
    this.klinPathDirs = const [],
  });

  Never _err(String message, [SourcePos? pos]) =>
      throw PreprocessError(message, pos ?? _pos, path: path);

  PreprocessResult expandWithMap() {
    final macros = <String, _MacroDef>{};
    _loadMacrosFromPathImports(macros);
    _macros = macros;
    _nestDepth = 0;
    return _expandBodyMapped(trackMap: true);
  }

  /// Expand `$fn` defs / `$name(...)` calls in [source] using [_macros].
  String _expandBody() => _expandBodyMapped(trackMap: false).text;

  PreprocessResult _expandBodyMapped({required bool trackMap}) {
    final macros = _macros!;
    final out = trackMap ? _MappedOut() : null;
    final plain = trackMap ? null : StringBuffer();
    SvdDevice? svdDevice;

    void emitCopy(String s, int origStart) {
      if (out != null) {
        out.copyString(s, origStart);
      } else {
        plain!.write(s);
      }
    }

    void emitSynthetic(String s, int origOff) {
      if (out != null) {
        out.synthetic(s, origOff);
      } else {
        plain!.write(s);
      }
    }

    void emitChar(String c, int origOff) {
      if (out != null) {
        out.copyChar(c, origOff);
      } else {
        plain!.write(c);
      }
    }

    while (!_atEnd) {
      if (_startsWithFn()) {
        final def = _parseFnDef();
        if (macros.containsKey(def.name)) {
          _err('redefinition of macro `\$${def.name}`', def.pos);
        }
        macros[def.name] = def;
        continue;
      }

      if (_peek == r'$' &&
          _i + 1 < source.length &&
          _isIdentStart(source[_i + 1])) {
        final startOff = _i;
        final start = _pos;
        _advance(); // $
        final name = _readIdent();
        _skipSpace();
        if (!_atEnd && _peek == '(') {
          if (name == 'peripherals_from_svd' || name == 'device') {
            if (svdDevice != null) {
              _err('duplicate `\$device` / `\$peripherals_from_svd`', start);
            }
            final args = _parseArgList();
            if (args.isEmpty || args.length > 2) {
              _err(
                '`\$$name` expects 1 or 2 arguments '
                '(svd path[, peripherals])',
                start,
              );
            }
            final expansion = expandPeripheralsFromSvd(
              svdArg: args[0],
              peripheralsArg: args.length > 1 ? args[1] : null,
              sourcePath: path,
              callPos: start,
              klinCacheDir: klinCacheDir,
            );
            svdDevice = expansion.device;
            emitSynthetic(expansion.klinSnippet, startOff);
            continue;
          }
          if (name == 'board') {
            final args = _parseArgList();
            if (args.length != 1) {
              _err('`\$board` expects 1 argument (path to `.ioc`)', start);
            }
            final snippet = expandBoardIoc(
              boardArg: args[0],
              sourcePath: path,
              callPos: start,
              klinCacheDir: klinCacheDir,
            );
            emitSynthetic(snippet, startOff);
            continue;
          }
          final def = macros[name];
          if (def == null) {
            _err('unknown macro `\$$name`', start);
          }
          final args = _parseArgList();
          _appendTrailingBlockArg(def, args, start);
          emitSynthetic(_expandCall(def, args, start), startOff);
          continue;
        }
        _err('expected `(` after macro `\$$name`', start);
      }

      // Skip strings / comments so `$` inside them is left alone.
      if (_peek == '"') {
        final startOff = _i;
        final s = _readStringLiteral();
        emitCopy(s, startOff);
        continue;
      }
      if (_peek == '/' && _i + 1 < source.length && source[_i + 1] == '/') {
        final startOff = _i;
        final s = _readLineComment();
        emitCopy(s, startOff);
        continue;
      }

      final origOff = _i;
      emitChar(_advance(), origOff);
    }

    final text = out?.text ?? plain!.toString();
    if (svdDevice != null) {
      final SvdFluentRewrite fluent;
      try {
        fluent = rewriteSvdFluentWithMap(text, svdDevice, path: path);
      } on PreprocessError catch (e) {
        // Fluent positions are in mid-text (`text`); map to the editor buffer.
        final mid = out?.origOfExp;
        if (mid == null || mid.isEmpty || mid.length != text.length) {
          rethrow;
        }
        final stage1 = SourceMap(
          origOfExpanded: mid,
          original: source,
          expanded: text,
        );
        throw PreprocessError(
          e.message,
          stage1.toOriginal(e.pos),
          path: e.path,
        );
      }
      final mid = out?.origOfExp;
      if (mid == null || mid.isEmpty) {
        return PreprocessResult(fluent.text);
      }
      // Strict compose: bad mid indices mean drop the map (safer than skew).
      if (fluent.midOfFinal.length != fluent.text.length ||
          fluent.midOfFinal.any((m) => m < 0 || m >= mid.length)) {
        return PreprocessResult(fluent.text);
      }
      final composed = [for (final m in fluent.midOfFinal) mid[m]];
      return PreprocessResult(
        fluent.text,
        map: SourceMap(
          origOfExpanded: composed,
          original: source,
          expanded: fluent.text,
        ),
      );
    }
    if (out == null) {
      return PreprocessResult(text);
    }
    if (out.origOfExp.isEmpty) {
      return PreprocessResult(text);
    }
    if (text == source) {
      return PreprocessResult(text, map: SourceMap.identity(source));
    }
    return PreprocessResult(
      text,
      map: SourceMap(
        origOfExpanded: out.origOfExp,
        original: source,
        expanded: text,
      ),
    );
  }

  void _loadMacrosFromPathImports(Map<String, _MacroDef> macros) {
    final fromDir = path == '<input>'
        ? Directory.current.path
        : File(path).parent.path;
    for (final imp in _scanPathImports(source)) {
      final files = _resolvePathImportKlFiles(imp.spec, fromDir);
      for (final filePath in files) {
        final text = File(filePath).readAsStringSync();
        for (final def in _extractMacroDefs(text, filePath)) {
          if (macros.containsKey(def.name)) {
            _err(
              'redefinition of macro `\$${def.name}` via import '
              '`${imp.spec}`',
              def.pos,
            );
          }
          macros[def.name] = _MacroDef(
            name: def.name,
            params: def.params,
            body: def.body,
            pos: def.pos,
            packageQualifier: imp.qualifier,
          );
        }
      }
    }
  }

  /// `import "path"` / `import "path" alias` (string path imports only).
  static List<_ScannedPathImport> _scanPathImports(String source) {
    final out = <_ScannedPathImport>[];
    final re = RegExp(
      r'^\s*import\s+"([^"]+)"(?:\s+([A-Za-z_][A-Za-z0-9_]*))?\s*$',
      multiLine: true,
    );
    for (final m in re.allMatches(source)) {
      final lineStart =
          m.start == 0 ? 0 : source.lastIndexOf('\n', m.start - 1) + 1;
      final prefix = source.substring(lineStart, m.start).trim();
      if (prefix.startsWith('//')) continue;
      final spec = m.group(1)!;
      final alias = m.group(2);
      final key = spec.endsWith('.kl')
          ? spec.substring(0, spec.length - 3)
          : spec;
      final slash = key.lastIndexOf('/');
      final defaultQ = slash >= 0 ? key.substring(slash + 1) : key;
      out.add(_ScannedPathImport(spec, alias ?? defaultQ));
    }
    return out;
  }

  List<String> _resolvePathImportKlFiles(String spec, String fromDir) {
    final sep = Platform.pathSeparator;
    if (isRemoteImportPath(spec)) {
      final RemoteImport remote;
      try {
        remote = parseRemoteImport(spec);
      } on FormatException {
        return const [];
      }
      final pkgDir = packageCacheDir(remote, cacheRoot: klinCacheDir);
      if (!isPackageInstalled(pkgDir)) return const [];
      return _listPackageKlFiles(pkgDir);
    }

    final roots = <String>[
      fromDir,
      '$fromDir${sep}lib',
      ...klinPathDirs,
    ];
    for (final root in roots) {
      final filePath = spec.endsWith('.kl')
          ? '$root$sep$spec'
          : '$root$sep$spec.kl';
      final dirPath = spec.endsWith('.kl')
          ? null
          : '$root$sep$spec';
      if (File(filePath).existsSync()) {
        return [File(filePath).absolute.path];
      }
      if (dirPath != null) {
        final files = _listPackageKlFiles(dirPath);
        if (files.isNotEmpty) return files;
      }
    }
    // Absolute / relative path as written (e.g. ../../pkg).
    final directFile = File('$fromDir$sep$spec');
    if (spec.endsWith('.kl') && directFile.existsSync()) {
      return [directFile.absolute.path];
    }
    final directDir = Directory('$fromDir$sep$spec');
    if (directDir.existsSync()) {
      return _listPackageKlFiles(directDir.path);
    }
    return const [];
  }

  static List<String> _listPackageKlFiles(String dir) {
    final directory = Directory(dir);
    if (!directory.existsSync()) return const [];
    final out = <String>[];
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!name.endsWith('.kl')) continue;
      if (name.endsWith('_test.kl')) continue;
      out.add(entity.absolute.path);
    }
    out.sort();
    return out;
  }

  static List<_MacroDef> _extractMacroDefs(String source, String path) {
    final scanner = _PpScanner(source, path);
    final defs = <_MacroDef>[];
    while (!scanner._atEnd) {
      if (scanner._startsWithFn()) {
        defs.add(scanner._parseFnDef());
        continue;
      }
      if (scanner._peek == '"') {
        scanner._readStringLiteral();
        continue;
      }
      if (scanner._peek == '/' &&
          scanner._i + 1 < scanner.source.length &&
          scanner.source[scanner._i + 1] == '/') {
        scanner._readLineComment();
        continue;
      }
      scanner._advance();
    }
    return defs;
  }

  void _appendTrailingBlockArg(
    _MacroDef def,
    List<String> args,
    SourcePos callPos,
  ) {
    final blockIdx = def.params.indexWhere((p) => p.kind == 'block');
    if (blockIdx < 0) return;
    if (blockIdx != def.params.length - 1) {
      _err(
        'macro `\$${def.name}`: `block` parameter must be last',
        def.pos,
      );
    }
    if (def.params.where((p) => p.kind == 'block').length > 1) {
      _err(
        'macro `\$${def.name}`: at most one `block` parameter',
        def.pos,
      );
    }
    _skipSpace();
    if (_atEnd || _peek != '{') {
      _err(
        'macro `\$${def.name}` expects a trailing `{ … }` block',
        callPos,
      );
    }
    args.add(_readBalanced('{', '}'));
  }

  bool _startsWithFn() {
    if (!_startsWith(r'$fn')) return false;
    final after = _i + 3;
    if (after >= source.length) return true;
    return !_isIdentContinue(source[after]);
  }

  _MacroDef _parseFnDef() {
    final start = _pos;
    _expectPrefix(r'$fn');
    _skipSpace();
    final name = _readIdent();
    if (name.isEmpty) {
      _err('expected macro name after `\$fn`');
    }
    _skipSpace();
    if (_atEnd || _peek != '(') {
      _err('expected `(` after macro name');
    }
    _advance();
    final params = <_MacroParam>[];
    _skipSpace();
    if (!_atEnd && _peek != ')') {
      while (true) {
        _skipSpace();
        final pname = _readIdent();
        if (pname.isEmpty) {
          _err('expected parameter name');
        }
        _skipSpace();
        if (_atEnd || _peek != ':') {
          _err('expected `:` after parameter `$pname`');
        }
        _advance();
        _skipSpace();
        final kind = _readIdent();
        if (kind != 'type' &&
            kind != 'name' &&
            kind != 'str' &&
            kind != 'block') {
          _err(
            'macro parameter kind must be `type`, `name`, `str`, or `block`',
          );
        }
        params.add(_MacroParam(pname, kind));
        _skipSpace();
        if (!_atEnd && _peek == ',') {
          _advance();
          continue;
        }
        break;
      }
    }
    _skipSpace();
    if (_atEnd || _peek != ')') {
      _err('expected `)` after macro parameters');
    }
    _advance();
    _skipSpace();
    if (_atEnd || _peek != '{') {
      _err('expected `{` to start macro body');
    }
    final body = _readBalanced('{', '}');
    return _MacroDef(name: name, params: params, body: body, pos: start);
  }

  List<String> _parseArgList() {
    if (_atEnd || _peek != '(') {
      _err('expected `(`');
    }
    _advance();
    final args = <String>[];
    _skipSpace();
    if (!_atEnd && _peek == ')') {
      _advance();
      return args;
    }
    while (true) {
      _skipSpace();
      final arg = _readArg();
      args.add(arg);
      _skipSpace();
      if (!_atEnd && _peek == ',') {
        _advance();
        continue;
      }
      break;
    }
    _skipSpace();
    if (_atEnd || _peek != ')') {
      _err('expected `)` after macro arguments');
    }
    _advance();
    return args;
  }

  String _readArg() {
    if (_atEnd) _err('expected macro argument');
    if (_peek == '"') {
      final lit = _readStringLiteral();
      // Strip quotes for substitution into `$name` / `$T` slots.
      return lit.substring(1, lit.length - 1);
    }
    // Integer literal (e.g. stack depth / priority for `$rtos_task`).
    if (_isDigit(_peek)) {
      final start = _i;
      while (!_atEnd && _isDigit(_peek)) {
        _advance();
      }
      return source.substring(start, _i);
    }
    // Bare identifier or type name (i32, *mut u8 — MVP: single ident only).
    final id = _readIdent();
    if (id.isEmpty) {
      _err('expected macro argument');
    }
    return id;
  }

  String _expandCall(_MacroDef def, List<String> args, SourcePos callPos) {
    if (args.length != def.params.length) {
      _err(
        'macro `\$${def.name}` expects ${def.params.length} arguments, '
        'got ${args.length}',
        callPos,
      );
    }
    var body = def.body;
    for (var i = 0; i < def.params.length; i++) {
      final param = def.params[i];
      final value = args[i];
      body = body.replaceAllMapped(
        RegExp('\\\$' + RegExp.escape(param.name) + r'\b'),
        (_) => value,
      );
    }
    if (def.packageQualifier != null) {
      body = body.replaceAllMapped(
        RegExp(r'\$mod\b'),
        (_) => def.packageQualifier!,
      );
    }
    // Nested calls in substituted text (e.g. `$event_loop` inside `$rtos_task`).
    body = _expandNested(body);
    final leftover = _firstCodeSlot(body);
    if (leftover != null) {
      _err(
        'unsubstituted `$leftover` in expansion of `\$${def.name}`',
        callPos,
      );
    }
    return body;
  }

  /// Re-scan a macro expansion so `$name(...)` calls inside `block` bodies
  /// expand too (issue 029: `$rtos_task` + `$event_loop`).
  String _expandNested(String text) {
    if (_macros == null) return text;
    if (!_textMayContainMacroCall(text)) return text;
    if (_nestDepth >= _maxNestDepth) {
      _err('macro expansion nested too deeply');
    }
    final nested = _PpScanner(
      text,
      path,
      klinCacheDir: klinCacheDir,
      klinPathDirs: klinPathDirs,
    );
    nested._macros = _macros;
    nested._nestDepth = _nestDepth + 1;
    return nested._expandBody();
  }

  static bool _textMayContainMacroCall(String text) {
    var i = 0;
    while (i < text.length) {
      if (text[i] == r'$' &&
          i + 1 < text.length &&
          _isIdentStart(text[i + 1])) {
        return true;
      }
      i++;
    }
    return false;
  }

  /// First `$ident` outside string literals and `//` comments, if any.
  static String? _firstCodeSlot(String text) {
    var i = 0;
    while (i < text.length) {
      final c = text[i];
      if (c == '"') {
        i++;
        while (i < text.length && text[i] != '"') {
          if (text[i] == '\\' && i + 1 < text.length) {
            i += 2;
          } else {
            i++;
          }
        }
        if (i < text.length) i++;
        continue;
      }
      if (c == '/' && i + 1 < text.length && text[i + 1] == '/') {
        i += 2;
        while (i < text.length && text[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == r'$' &&
          i + 1 < text.length &&
          _isIdentStart(text[i + 1])) {
        final start = i;
        i += 2;
        while (i < text.length && _isIdentContinue(text[i])) {
          i++;
        }
        return text.substring(start, i);
      }
      i++;
    }
    return null;
  }

  String _readBalanced(String open, String close) {
    if (_atEnd || _peek != open) {
      _err('expected `$open`');
    }
    _advance(); // consume open
    final buf = StringBuffer();
    var depth = 1;
    while (!_atEnd && depth > 0) {
      if (_peek == '"') {
        buf.write(_readStringLiteral());
        continue;
      }
      if (_peek == '/' && _i + 1 < source.length && source[_i + 1] == '/') {
        buf.write(_readLineComment());
        continue;
      }
      final c = _advance();
      if (c == open) {
        depth++;
        buf.write(c);
      } else if (c == close) {
        depth--;
        if (depth > 0) buf.write(c);
      } else {
        buf.write(c);
      }
    }
    if (depth != 0) {
      _err('unclosed `$open` in macro body');
    }
    return buf.toString();
  }

  String _readStringLiteral() {
    final buf = StringBuffer();
    buf.write(_advance()); // "
    while (!_atEnd && _peek != '"') {
      if (_peek == '\\') {
        buf.write(_advance());
        if (!_atEnd) buf.write(_advance());
      } else {
        buf.write(_advance());
      }
    }
    if (_atEnd) _err('unterminated string in macro');
    buf.write(_advance()); // closing "
    return buf.toString();
  }

  String _readLineComment() {
    final buf = StringBuffer();
    while (!_atEnd && _peek != '\n') {
      buf.write(_advance());
    }
    return buf.toString();
  }

  void _expectPrefix(String prefix) {
    if (!_startsWith(prefix)) {
      _err('expected `$prefix`');
    }
    for (var k = 0; k < prefix.length; k++) {
      _advance();
    }
  }

  bool _startsWith(String s) {
    if (_i + s.length > source.length) return false;
    return source.substring(_i, _i + s.length) == s;
  }

  void _skipSpace() {
    while (!_atEnd) {
      final c = _peek;
      if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
        _advance();
      } else if (c == '/' && _i + 1 < source.length && source[_i + 1] == '/') {
        while (!_atEnd && _peek != '\n') {
          _advance();
        }
      } else {
        break;
      }
    }
  }

  String _readIdent() {
    if (_atEnd || !_isIdentStart(_peek)) return '';
    final start = _i;
    _advance();
    while (!_atEnd && _isIdentContinue(_peek)) {
      _advance();
    }
    return source.substring(start, _i);
  }

  SourcePos get _pos => SourcePos(_line, _col);

  bool get _atEnd => _i >= source.length;

  String get _peek => source[_i];

  String _advance() {
    final c = source[_i++];
    if (c == '\n') {
      _line++;
      _col = 1;
    } else {
      _col++;
    }
    return c;
  }

  static bool _isIdentStart(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u == 95;
  }

  static bool _isIdentContinue(String c) =>
      _isIdentStart(c) || _isDigit(c);

  static bool _isDigit(String c) {
    final u = c.codeUnitAt(0);
    return u >= 48 && u <= 57;
  }
}
