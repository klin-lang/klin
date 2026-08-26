import 'ast.dart';
import 'lexer.dart';
import 'parser.dart';
import 'token.dart';

/// Canonical Klin style (issue 033): 4 spaces, K&R braces, Go-like spacing.
///
/// `//` comments are collected by the lexer and replayed next to the
/// following declaration / statement (or as a same-line trailer).
/// Sources with `$…` macros must be formatted after preprocess, or not at all.
const indentUnit = '    ';

/// Formats a Klin source unit. Throws [LexError] / [ParseError] on invalid input.
String formatSource(String source) {
  final lexer = Lexer(source);
  final tokens = lexer.tokenize();
  final unit = Parser(tokens).parseUnit();
  return formatUnit(unit, comments: lexer.comments, tokens: tokens);
}

String formatUnit(
  ModuleUnit unit, {
  List<SourceComment> comments = const [],
  List<Token> tokens = const [],
}) {
  final out = _FmtOut(comments, tokens);
  var first = true;

  void blankBefore() {
    if (!first) out.buf.writeln();
    first = false;
  }

  out.writeLeading(out.firstContentLine(), '');

  if (unit.declaredName != null) {
    out.buf.write('module ${unit.declaredName}');
    var moduleLine = 1;
    for (final t in tokens) {
      if (t.kind == TokenKind.module) {
        moduleLine = t.pos.line;
        break;
      }
    }
    out.endLine(moduleLine);
    first = false;
  }
  for (final imp in unit.imports) {
    out.writeLeading(imp.pos.line, '');
    final spec = imp.isPath ? '"${imp.spec}"' : imp.spec;
    final alias = imp.alias == null ? '' : ' ${imp.alias}';
    out.buf.write('import $spec$alias');
    out.endLine(imp.pos.line);
    first = false;
  }
  if (unit.declaredName != null || unit.imports.isNotEmpty) {
    out.buf.writeln();
    first = true; // next decl starts a new "group" without extra blank before first
  }

  for (final decl in unit.decls) {
    blankBefore();
    out.writeLeading(_declLine(decl), '');
    switch (decl) {
      case StructDecl():
        _writeStruct(out, decl, 0);
      case EnumDecl():
        _writeEnum(out, decl, 0);
      case FuncDecl():
        _writeFunc(out, decl, 0);
      default:
        throw StateError('unknown top-level declaration ${decl.runtimeType}');
    }
  }
  out.writeRest();
  if (!out.buf.toString().endsWith('\n')) out.buf.writeln();
  return out.buf.toString();
}

int _declLine(Object decl) {
  switch (decl) {
    case FuncDecl(:final attrs, :final pos):
      return attrs.isNotEmpty ? attrs.first.pos.line : pos.line;
    case StructDecl(:final attrs, :final pos):
      return attrs.isNotEmpty ? attrs.first.pos.line : pos.line;
    case EnumDecl(:final attrs, :final pos):
      return attrs.isNotEmpty ? attrs.first.pos.line : pos.line;
    default:
      return 1;
  }
}

/// Replays lexer comments while pretty-printing the AST.
final class _FmtOut {
  final StringBuffer buf = StringBuffer();
  final List<SourceComment> _comments;
  final List<Token> tokens;
  int _ci = 0;

  _FmtOut(this._comments, this.tokens);

  void writeLeading(int beforeLine, String pad) {
    while (_ci < _comments.length) {
      final c = _comments[_ci];
      if (c.pos.line >= beforeLine) break;
      buf.write(pad);
      buf.writeln(c.text);
      _ci++;
    }
  }

  void endLine(int line, {bool takeTrailing = true}) {
    if (takeTrailing && _ci < _comments.length) {
      final c = _comments[_ci];
      if (c.trailing && c.pos.line == line) {
        buf.write(' ');
        buf.write(c.text);
        _ci++;
      }
    }
    buf.writeln();
  }

  void writeRest() {
    if (_ci >= _comments.length) return;
    final soFar = buf.toString();
    if (soFar.isNotEmpty && !soFar.endsWith('\n')) buf.writeln();
    if (soFar.isNotEmpty && !soFar.endsWith('\n\n')) buf.writeln();
    while (_ci < _comments.length) {
      buf.writeln(_comments[_ci++].text);
    }
  }

  int firstContentLine() {
    for (final t in tokens) {
      switch (t.kind) {
        case TokenKind.module:
        case TokenKind.import:
        case TokenKind.fn:
        case TokenKind.struct:
        case TokenKind.enum_:
        case TokenKind.pub:
        case TokenKind.atSign:
        case TokenKind.async_:
          return t.pos.line;
        default:
          break;
      }
    }
    return 1;
  }

  int? rBraceLine(SourcePos open) {
    var depth = 0;
    var seen = false;
    for (final t in tokens) {
      if (!seen) {
        if (t.kind == TokenKind.lBrace &&
            t.pos.line == open.line &&
            t.pos.col == open.col) {
          seen = true;
          depth = 1;
        }
        continue;
      }
      if (t.kind == TokenKind.lBrace) depth++;
      if (t.kind == TokenKind.rBrace) {
        depth--;
        if (depth == 0) return t.pos.line;
      }
    }
    return null;
  }

  int? firstRBraceAfter(SourcePos after) {
    var depth = 0;
    var seen = false;
    for (final t in tokens) {
      final before = t.pos.line < after.line ||
          (t.pos.line == after.line && t.pos.col < after.col);
      if (before) continue;
      if (t.kind == TokenKind.lBrace) {
        if (!seen) {
          seen = true;
          depth = 1;
          continue;
        }
        depth++;
      } else if (t.kind == TokenKind.rBrace && seen) {
        depth--;
        if (depth == 0) return t.pos.line;
      }
    }
    return null;
  }
}

void _writeAttrs(_FmtOut out, List<Attr> attrs, int indent) {
  final pad = indentUnit * indent;
  for (final attr in attrs) {
    out.writeLeading(attr.pos.line, pad);
    out.buf.write(pad);
    if (attr.arg != null) {
      out.buf.write('@[${attr.name}("${_escapeString(attr.arg!)}")]');
    } else {
      out.buf.write('@[${attr.name}]');
    }
    out.endLine(attr.pos.line);
  }
}

void _writeStruct(_FmtOut out, StructDecl decl, int indent) {
  _writeAttrs(out, decl.attrs, indent);
  final pad = indentUnit * indent;
  out.buf.write(pad);
  if (decl.isPub) out.buf.write('pub ');
  out.buf.write('struct ${decl.name} {');
  final fieldsShareHeader =
      decl.fields.any((f) => f.pos.line == decl.pos.line);
  out.endLine(decl.pos.line, takeTrailing: !fieldsShareHeader);
  final fieldPad = '$pad$indentUnit';
  for (var i = 0; i < decl.fields.length; i++) {
    final field = decl.fields[i];
    out.writeLeading(field.pos.line, fieldPad);
    out.buf.write('$fieldPad${field.name}: ${field.typeName}');
    final lastOnLine = i == decl.fields.length - 1 ||
        decl.fields[i + 1].pos.line != field.pos.line;
    out.endLine(field.pos.line, takeTrailing: lastOnLine);
  }
  final close = out.firstRBraceAfter(decl.pos);
  if (close != null) out.writeLeading(close, fieldPad);
  out.buf.writeln('$pad}');
}

void _writeEnum(_FmtOut out, EnumDecl decl, int indent) {
  _writeAttrs(out, decl.attrs, indent);
  final pad = indentUnit * indent;
  out.buf.write(pad);
  if (decl.isPub) out.buf.write('pub ');
  out.buf.write('enum ${decl.name}');
  if (decl.baseTypeName != null) out.buf.write(': ${decl.baseTypeName}');
  out.buf.write(' {');
  final variantsShareHeader =
      decl.variants.any((v) => v.pos.line == decl.pos.line);
  out.endLine(decl.pos.line, takeTrailing: !variantsShareHeader);
  final fieldPad = '$pad$indentUnit';
  for (var i = 0; i < decl.variants.length; i++) {
    final variant = decl.variants[i];
    out.writeLeading(variant.pos.line, fieldPad);
    final value = variant.value;
    final suffix = value is IntLit ? ' = ${value.lexeme}' : '';
    out.buf.write('$fieldPad${variant.name}$suffix');
    final lastOnLine = i == decl.variants.length - 1 ||
        decl.variants[i + 1].pos.line != variant.pos.line;
    out.endLine(variant.pos.line, takeTrailing: lastOnLine);
  }
  final close = out.firstRBraceAfter(decl.pos);
  if (close != null) out.writeLeading(close, fieldPad);
  out.buf.writeln('$pad}');
}

void _writeFunc(_FmtOut out, FuncDecl decl, int indent) {
  _writeAttrs(out, decl.attrs, indent);
  final pad = indentUnit * indent;
  out.buf.write(pad);
  if (decl.isPub) out.buf.write('pub ');
  if (decl.isAsync) out.buf.write('async ');
  out.buf.write('fn ');
  final recv = decl.receiver;
  if (recv != null) {
    out.buf.write('(');
    if (recv.isMut) out.buf.write('mut ');
    out.buf.write('${recv.name}: ${recv.typeName}) ');
  }
  if (decl.associatedType != null) out.buf.write('${decl.associatedType}.');
  out.buf.write(decl.name);
  out.buf.write('(');
  out.buf.write(
    decl.params.map((p) => '${p.name}: ${p.typeName}').join(', '),
  );
  out.buf.write(')');
  if (decl.returnTypeName != null) {
    out.buf.write(': ${decl.returnTypeName}');
  }
  final body = decl.body;
  if (body == null) {
    out.endLine(decl.pos.line);
    return;
  }
  out.buf.write(' ');
  _writeBlock(out, body, indent, leadingNewline: false);
}

void _writeBlock(
  _FmtOut out,
  Block block,
  int indent, {
  required bool leadingNewline,
}) {
  final pad = indentUnit * indent;
  if (leadingNewline) out.buf.write(pad);
  out.buf.write('{');
  out.endLine(block.pos.line);
  for (final stmt in block.stmts) {
    _writeStmt(out, stmt, indent + 1);
  }
  final close = out.rBraceLine(block.pos);
  if (close != null) out.writeLeading(close, '$pad$indentUnit');
  out.buf.writeln('$pad}');
}

void _writeStmt(_FmtOut out, Stmt stmt, int indent, {bool inline = false}) {
  final pad = indentUnit * indent;
  if (!inline) out.writeLeading(stmt.pos.line, pad);
  switch (stmt) {
    case AsmStmt(:final code):
      if (!inline) out.buf.write(pad);
      out.buf.write('asm("${_escapeString(code)}")');
      out.endLine(stmt.pos.line);
    case LetStmt(
        :final isMut,
        :final name,
        :final typeName,
        :final init,
        :final shortDecl
      ):
      if (!inline) out.buf.write(pad);
      if (shortDecl) {
        out.buf.write('$name := ');
        out.buf.write(_expr(init!, indent));
        out.endLine(stmt.pos.line);
        break;
      }
      out.buf.write(isMut ? 'let mut ' : 'let ');
      out.buf.write(name);
      if (typeName != null) out.buf.write(': $typeName');
      if (init != null) {
        out.buf.write(' = ');
        out.buf.write(_expr(init, indent));
      }
      out.endLine(stmt.pos.line);
    case LetDestructureStmt(
        :final isMut,
        :final fields,
        :final binds,
        :final source
      ):
      if (!inline) out.buf.write(pad);
      out.buf.write(isMut ? 'let mut { ' : 'let { ');
      final parts = <String>[];
      for (var i = 0; i < fields.length; i++) {
        parts.add(fields[i] == binds[i] ? fields[i] : '${fields[i]}: ${binds[i]}');
      }
      out.buf.write(parts.join(', '));
      out.buf.write(' } = ');
      out.buf.write(_expr(source, indent));
      out.endLine(stmt.pos.line);
    case LetArrayDestructureStmt(:final isMut, :final names, :final source):
      if (!inline) out.buf.write(pad);
      out.buf.write(isMut ? 'let mut [' : 'let [');
      out.buf.write(names.map((n) => n ?? '_').join(', '));
      out.buf.write('] = ');
      out.buf.write(_expr(source, indent));
      out.endLine(stmt.pos.line);
    case AssignStmt(:final target, :final value, :final compoundOp):
      final op = compoundOp == null ? '=' : '$compoundOp=';
      if (!inline) out.buf.write(pad);
      out.buf.write('${_expr(target, indent)} $op ${_expr(value, indent)}');
      out.endLine(stmt.pos.line);
    case MultiAssignStmt(:final targets, :final values):
      final lhs = targets.map((t) => _expr(t, indent)).join(', ');
      final rhs = values.map((v) => _expr(v, indent)).join(', ');
      if (!inline) out.buf.write(pad);
      out.buf.write('$lhs = $rhs');
      out.endLine(stmt.pos.line);
    case StructAssignStmt(:final fields, :final targets, :final source):
      final parts = <String>[];
      for (var i = 0; i < fields.length; i++) {
        final target = targets[i];
        final plain = target is NameExpr && target.name == fields[i];
        parts.add(plain ? fields[i] : '${fields[i]}: ${_expr(target, indent)}');
      }
      if (!inline) out.buf.write(pad);
      out.buf.write('{ ${parts.join(', ')} } = ${_expr(source, indent)}');
      out.endLine(stmt.pos.line);
    case CallStmt(:final moduleName, :final callee, :final args):
      final name = moduleName == null ? callee : '$moduleName.$callee';
      if (!inline) out.buf.write(pad);
      out.buf.write('$name(${_argList(args, indent)})');
      out.endLine(stmt.pos.line);
    case MethodCallStmt(:final call):
      if (!inline) out.buf.write(pad);
      out.buf.write(_expr(call, indent));
      out.endLine(stmt.pos.line);
    case AwaitStmt(:final expr):
      if (!inline) out.buf.write(pad);
      out.buf.write(_expr(expr, indent));
      out.endLine(stmt.pos.line);
    case IfStmt():
      _writeIf(out, stmt, indent, chained: false);
    case WhileStmt(:final cond, :final body):
      if (!inline) out.buf.write(pad);
      out.buf.write('while ${_expr(cond, indent)} ');
      _writeBlock(out, body, indent, leadingNewline: false);
    case ForRangeStmt(:final name, :final start, :final endExclusive, :final body):
      if (!inline) out.buf.write(pad);
      out.buf.write(
        'for $name in ${_expr(start, indent)}..<${_expr(endExclusive, indent)} ',
      );
      _writeBlock(out, body, indent, leadingNewline: false);
    case ForCStmt(
        :final initName,
        :final initExpr,
        :final initDecl,
        :final cond,
        :final postName,
        :final postExpr,
        :final body
      ):
      if (!inline) out.buf.write(pad);
      out.buf.write('for ');
      if (initName != null && initExpr != null) {
        final op = initDecl ? ':=' : '=';
        out.buf.write('$initName $op ${_expr(initExpr, indent)}');
      }
      out.buf.write('; ');
      if (cond != null) out.buf.write(_expr(cond, indent));
      out.buf.write('; ');
      if (postName != null && postExpr != null) {
        out.buf.write('$postName = ${_expr(postExpr, indent)}');
      }
      out.buf.write(' ');
      _writeBlock(out, body, indent, leadingNewline: false);
    case ReturnStmt(:final value):
      if (!inline) out.buf.write(pad);
      if (value == null) {
        out.buf.write('return');
      } else {
        out.buf.write('return ${_expr(value, indent)}');
      }
      out.endLine(stmt.pos.line);
    case BreakStmt():
      if (!inline) out.buf.write(pad);
      out.buf.write('break');
      out.endLine(stmt.pos.line);
    case ContinueStmt():
      if (!inline) out.buf.write(pad);
      out.buf.write('continue');
      out.endLine(stmt.pos.line);
    case DeferStmt(:final body):
      if (!inline) out.buf.write(pad);
      out.buf.write('defer ');
      if (body is BlockStmt) {
        _writeBlock(out, body.block, indent, leadingNewline: false);
      } else {
        _writeStmt(out, body, 0, inline: true);
      }
    case BlockStmt(:final block):
      _writeBlock(out, block, indent, leadingNewline: true);
    case MatchStmt(:final subject, :final arms):
      if (!inline) out.buf.write(pad);
      out.buf.write('match ${_expr(subject, indent)} {');
      out.endLine(stmt.pos.line);
      for (final arm in arms) {
        final armPad = '$pad$indentUnit';
        out.writeLeading(arm.pattern.pos.line, armPad);
        out.buf.write(
          '$armPad${_armPatternText(arm.pattern, arm.when, indent)} {',
        );
        out.endLine(arm.pattern.pos.line);
        for (final s in arm.body.stmts) {
          _writeStmt(out, s, indent + 2);
        }
        final armClose = out.rBraceLine(arm.body.pos);
        if (armClose != null) {
          out.writeLeading(armClose, '$armPad$indentUnit');
        }
        out.buf.writeln('$armPad}');
      }
      final matchClose = out.firstRBraceAfter(stmt.pos);
      if (matchClose != null) out.writeLeading(matchClose, '$pad$indentUnit');
      out.buf.writeln('$pad}');
  }
}

String _armPatternText(MatchPattern pattern, Expr? when, int indent) {
  final base = _patternText(pattern, indent);
  if (when == null) return base;
  return '$base when ${_expr(when, indent)}';
}

String _patternText(MatchPattern pattern, int indent) {
  return switch (pattern) {
    LitPattern(:final values) =>
      values.map((v) => _expr(v, indent)).join(', '),
    RangePattern(:final start, :final endInclusive) =>
      '${_expr(start, indent)}..=${_expr(endInclusive, indent)}',
    RelPattern(:final op, :final rhs) => '$op ${_expr(rhs, indent)}',
    WildPattern() => '_',
    ElsePattern() => 'else',
  };
}

void _writeIf(_FmtOut out, IfStmt stmt, int indent, {required bool chained}) {
  final pad = indentUnit * indent;
  if (!chained) out.buf.write(pad);
  out.buf.write('if ${_expr(stmt.cond, indent)} {');
  out.endLine(stmt.pos.line);
  for (final s in stmt.thenBlock.stmts) {
    _writeStmt(out, s, indent + 1);
  }
  final thenClose = out.rBraceLine(stmt.thenBlock.pos);
  if (thenClose != null) out.writeLeading(thenClose, '$pad$indentUnit');
  final elseBranch = stmt.elseBranch;
  if (elseBranch == null) {
    out.buf.writeln('$pad}');
    return;
  }
  out.buf.write('$pad} else ');
  if (elseBranch is IfStmt) {
    _writeIf(out, elseBranch, indent, chained: true);
  } else if (elseBranch is BlockStmt) {
    out.buf.write('{');
    out.endLine(elseBranch.pos.line);
    for (final s in elseBranch.block.stmts) {
      _writeStmt(out, s, indent + 1);
    }
    final elseClose = out.rBraceLine(elseBranch.block.pos);
    if (elseClose != null) out.writeLeading(elseClose, '$pad$indentUnit');
    out.buf.writeln('$pad}');
  } else {
    throw StateError('unexpected else branch ${elseBranch.runtimeType}');
  }
}

String _expr(Expr expr, [int indent = 0]) {
  return switch (expr) {
    IntLit(:final lexeme) => lexeme,
    FloatLit(:final lexeme) => lexeme,
    BoolLit(:final value) => value ? 'true' : 'false',
    StringLit(:final value) => '"${_escapeString(value)}"',
    InterpolatedStringExpr(:final parts) => () {
        final out = StringBuffer('"');
        for (final part in parts) {
          switch (part) {
            case InterpText(:final text):
              out.write(_escapeInterpText(text));
            case InterpSlot(:final expr, :final formatRaw):
              if (expr is NameExpr && formatRaw == null) {
                out.write('\$${expr.name}');
              } else if (formatRaw == null) {
                out.write('\${${_expr(expr, indent)}}');
              } else {
                out.write('\${${_expr(expr, indent)}:$formatRaw}');
              }
          }
        }
        out.write('"');
        return out.toString();
      }(),
    NameExpr(:final name) => name,
    FieldExpr(:final object, :final name) => '${_expr(object, indent)}.$name',
    MethodCallExpr(:final receiver, :final name, :final args) =>
      '${_expr(receiver, indent)}.$name(${_argList(args, indent)})',
    StructLitExpr(
      :final moduleName,
      :final typeName,
      :final namedFields,
      :final positionalFields
    ) =>
      () {
        final type =
            moduleName == null ? typeName : '$moduleName.$typeName';
        if (namedFields != null) {
          final fields = namedFields.entries
              .map((e) => '${e.key}: ${_expr(e.value, indent)}')
              .join(', ');
          return '$type{ $fields }';
        }
        final fields =
            positionalFields!.map((e) => _expr(e, indent)).join(', ');
        return fields.isEmpty ? '$type{}' : '$type{ $fields }';
      }(),
    CallExpr(:final moduleName, :final callee, :final args) => () {
        final name = moduleName == null ? callee : '$moduleName.$callee';
        return '$name(${_argList(args, indent)})';
      }(),
    UnaryExpr(:final op, :final operand) =>
      op == '*' || op == '&' || op == '-' || op == '!' || op == '~'
          ? '$op${_expr(operand, indent)}'
          : '$op(${_expr(operand, indent)})',
    IndexExpr(:final object, :final index) =>
      '${_expr(object, indent)}[${_expr(index, indent)}]',
    SliceFromExpr(:final array) => '${_expr(array, indent)}[:]',
    ArrayLitExpr(:final elements) =>
      '[${elements.map((e) => _expr(e, indent)).join(', ')}]',
    CastExpr(:final typeName, :final expr) =>
      'cast($typeName, ${_expr(expr, indent)})',
    BinaryExpr(:final left, :final op, :final right) =>
      '${_expr(left, indent)} $op ${_expr(right, indent)}',
    PickExpr(:final cond, :final thenExpr, :final elseExpr) =>
      'pick ${_expr(cond, indent)} { ${_expr(thenExpr, indent)} } { ${_expr(elseExpr, indent)} }',
    GroupExpr(:final inner) => '(${_expr(inner, indent)})',
    ErrorExpr(:final code) => 'error(${_expr(code, indent)})',
    PropagateExpr(:final result) => '${_expr(result, indent)}!',
    AwaitExpr(:final operand) => '${_expr(operand, indent)}.await',
    OrExpr(:final result, :final fallback) =>
      '${_expr(result, indent)} or ${_formatOrBlock(fallback, indent)}',
    MatchExpr(:final subject, :final arms) =>
      _formatMatchExpr(subject, arms, indent),
  };
}

String _formatMatchExpr(Expr subject, List<MatchExprArm> arms, int indent) {
  final pad = indentUnit * indent;
  final inner = indentUnit * (indent + 1);
  final buf = StringBuffer('match ${_expr(subject, indent)} {\n');
  for (final arm in arms) {
    buf.writeln(
      '$inner${_armPatternText(arm.pattern, arm.when, indent + 1)} { ${_expr(arm.body, indent + 1)} }',
    );
  }
  buf.write('$pad}');
  return buf.toString();
}

String _formatOrBlock(OrBlock block, int indent) {
  final pad = indentUnit * indent;
  final inner = indentUnit * (indent + 1);
  if (block.stmts.isEmpty) {
    return '{ ${_expr(block.value, indent)} }';
  }
  final buf = StringBuffer('{\n');
  final innerFmt = _FmtOut(const [], const []);
  for (final stmt in block.stmts) {
    _writeStmt(innerFmt, stmt, indent + 1);
  }
  buf.write(innerFmt.buf.toString());
  buf.writeln('$inner${_expr(block.value, indent + 1)}');
  buf.write('$pad}');
  return buf.toString();
}

String _argList(List<Expr> args, [int indent = 0]) =>
    args.map((e) => _expr(e, indent)).join(', ');

String _escapeString(String value) {
  final buf = StringBuffer();
  for (final unit in value.codeUnits) {
    switch (unit) {
      case 0x5C: // \
        buf.write(r'\\');
      case 0x22: // "
        buf.write(r'\"');
      case 0x0A:
        buf.write(r'\n');
      case 0x0D:
        buf.write(r'\r');
      case 0x09:
        buf.write(r'\t');
      default:
        if (unit < 0x20) {
          buf.write('\\x${unit.toRadixString(16).padLeft(2, '0')}');
        } else {
          buf.writeCharCode(unit);
        }
    }
  }
  return buf.toString();
}

String _escapeInterpText(String value) {
  final buf = StringBuffer();
  for (final unit in value.codeUnits) {
    if (unit == 0x24) {
      // `$` — literal dollar inside interpolated string
      buf.write(r'\$');
      continue;
    }
    switch (unit) {
      case 0x5C:
        buf.write(r'\\');
      case 0x22:
        buf.write(r'\"');
      case 0x0A:
        buf.write(r'\n');
      case 0x0D:
        buf.write(r'\r');
      case 0x09:
        buf.write(r'\t');
      default:
        if (unit < 0x20) {
          buf.write('\\x${unit.toRadixString(16).padLeft(2, '0')}');
        } else {
          buf.writeCharCode(unit);
        }
    }
  }
  return buf.toString();
}
