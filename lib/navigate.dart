import 'ast.dart';
import 'token.dart';
import 'type.dart';

/// A name-like site in the AST that can provide hover / go-to-definition.
sealed class NavTarget {
  SourcePos get pos;
  String get label;
  KlinType? get type;
  ResolvedDef? get def;
  int get nameLength;

  /// File containing this occurrence (not necessarily the definition file).
  String? get occurrencePath;
}

final class _NameNav extends NavTarget {
  final NameExpr expr;
  @override
  final String? occurrencePath;
  _NameNav(this.expr, this.occurrencePath);

  @override
  SourcePos get pos => expr.pos;
  @override
  String get label => expr.name;
  @override
  KlinType? get type => expr.resolvedType;
  @override
  ResolvedDef? get def => expr.resolvedDef;
  @override
  int get nameLength => expr.name.length;
}

final class _FieldNav extends NavTarget {
  final FieldExpr expr;
  @override
  final String? occurrencePath;
  _FieldNav(this.expr, this.occurrencePath);

  @override
  SourcePos get pos => expr.pos;
  @override
  String get label => expr.name;
  @override
  KlinType? get type => expr.resolvedType;
  @override
  ResolvedDef? get def => expr.resolvedDef;
  @override
  int get nameLength => expr.name.length;
}

final class _MethodNav extends NavTarget {
  final MethodCallExpr expr;
  @override
  final String? occurrencePath;
  _MethodNav(this.expr, this.occurrencePath);

  @override
  SourcePos get pos => expr.pos;
  @override
  String get label => expr.name;
  @override
  KlinType? get type => expr.resolvedType;
  @override
  ResolvedDef? get def => expr.resolvedDef;
  @override
  int get nameLength => expr.name.length;
}

final class _CallNav extends NavTarget {
  final CallExpr expr;
  @override
  final String? occurrencePath;
  _CallNav(this.expr, this.occurrencePath);

  @override
  SourcePos get pos => expr.pos;
  @override
  String get label =>
      expr.moduleName == null ? expr.callee : '${expr.moduleName}.${expr.callee}';
  @override
  KlinType? get type => expr.resolvedType;
  @override
  ResolvedDef? get def => expr.resolvedDef;
  @override
  int get nameLength {
    final mod = expr.moduleName;
    if (mod == null) return expr.callee.length;
    return mod.length + 1 + expr.callee.length;
  }
}

final class _CallStmtNav extends NavTarget {
  final CallStmt stmt;
  @override
  final String? occurrencePath;
  _CallStmtNav(this.stmt, this.occurrencePath);

  @override
  SourcePos get pos => stmt.pos;
  @override
  String get label => stmt.moduleName == null
      ? stmt.callee
      : '${stmt.moduleName}.${stmt.callee}';
  @override
  KlinType? get type => null;
  @override
  ResolvedDef? get def => stmt.resolvedDef;
  @override
  int get nameLength {
    final mod = stmt.moduleName;
    if (mod == null) return stmt.callee.length;
    return mod.length + 1 + stmt.callee.length;
  }
}

final class _LetNav extends NavTarget {
  final LetStmt stmt;
  @override
  final String? occurrencePath;
  _LetNav(this.stmt, this.occurrencePath);

  @override
  SourcePos get pos => stmt.pos;
  @override
  String get label => stmt.name;
  @override
  KlinType? get type => stmt.resolvedType;
  @override
  ResolvedDef? get def => ResolvedDef(stmt.pos, occurrencePath);
  @override
  int get nameLength => stmt.name.length;
}

bool _covers(SourcePos start, int length, int line, int col) {
  if (start.line != line) return false;
  if (col < start.col) return false;
  return col < start.col + length;
}

/// Deepest name/call/field/method covering 1-based [line]/[col], or null.
NavTarget? findNavTarget(Program program, int line, int col) {
  return _NavWalker(line, col).run(program);
}

/// Every nav site in [program] (for rename / references).
List<NavTarget> allNavTargets(Program program) {
  return _CollectNav().run(program);
}

/// Classification of a [NavTarget] for LSP semantic tokens (issue 094).
enum SemanticNavKind {
  function,
  method,
  parameter,
  variable,
  property,
  enumMember,
  call,
}

SemanticNavKind semanticNavKind(NavTarget t) {
  return switch (t) {
    _FuncNav(:final func) =>
      func.receiver != null ? SemanticNavKind.method : SemanticNavKind.function,
    _ParamNav() => SemanticNavKind.parameter,
    _LetNav() => SemanticNavKind.variable,
    _MethodNav() => SemanticNavKind.method,
    _CallNav() || _CallStmtNav() => SemanticNavKind.call,
    _FieldNav(:final expr) =>
      expr.enumConstCName != null
          ? SemanticNavKind.enumMember
          : expr.constCName != null
              ? SemanticNavKind.variable
              : SemanticNavKind.property,
    _NameNav(:final expr) =>
      (expr.resolvedFnCName != null || expr.resolvedType is FnType)
          ? SemanticNavKind.function
          : SemanticNavKind.variable,
  };
}

/// True for let/param/fn declaration sites (modifier `declaration`).
bool semanticNavIsDeclaration(NavTarget t) =>
    t is _FuncNav || t is _ParamNav || t is _LetNav;

/// True for non-mut `let` bindings (modifier `readonly`).
bool semanticNavIsReadonly(NavTarget t) =>
    (t is _LetNav && !t.stmt.isMut) ||
    (t is _NameNav && t.expr.resolvedConstCName != null) ||
    (t is _FieldNav && t.expr.constCName != null);

/// True when the function decl has `@[cimport]` (modifier `defaultLibrary`).
bool semanticNavIsCimport(NavTarget t) =>
    t is _FuncNav && t.func.attrs.any((a) => a.name == 'cimport');

bool sameResolvedDef(ResolvedDef? a, ResolvedDef? b) {
  if (a == null || b == null) return false;
  if (a.pos.line != b.pos.line || a.pos.col != b.pos.col) return false;
  final ap = a.path ?? '';
  final bp = b.path ?? '';
  // Both unknown → same analysis unit. One known + one unknown → not equal
  // (avoids colliding locals across files that share line/col).
  if (ap.isEmpty && bp.isEmpty) return true;
  if (ap.isEmpty || bp.isEmpty) return false;
  final na = ap.replaceAll('\\', '/');
  final nb = bp.replaceAll('\\', '/');
  if (na == nb) return true;
  // Relative vs absolute suffix match — not basename-only (distinct dirs).
  return na.endsWith('/$nb') || nb.endsWith('/$na');
}

final class _FuncNav extends NavTarget {
  final FuncDecl func;
  _FuncNav(this.func);

  @override
  // Occurrence span uses the name ident; [def] keeps `fn` pos so it matches
  // checker `ResolvedDef(decl.pos)` for rename / references.
  SourcePos get pos => func.namePos;
  @override
  String get label => func.name;
  @override
  KlinType? get type => func.resolvedReturnType;
  @override
  ResolvedDef? get def => ResolvedDef(func.pos, func.sourcePath);
  @override
  String? get occurrencePath => func.sourcePath;
  @override
  int get nameLength => func.name.length;
}

final class _ParamNav extends NavTarget {
  final Param param;
  final String? sourcePath;
  _ParamNav(this.param, this.sourcePath);

  @override
  SourcePos get pos => param.pos;
  @override
  String get label => param.name;
  @override
  KlinType? get type => param.resolvedType;
  @override
  ResolvedDef? get def => ResolvedDef(param.pos, sourcePath);
  @override
  String? get occurrencePath => sourcePath;
  @override
  int get nameLength => param.name.length;
}

final class _CollectNav {
  final List<NavTarget> out = [];
  String? _file;

  List<NavTarget> run(Program program) {
    for (final f in program.funcs) {
      _file = f.sourcePath;
      out.add(_FuncNav(f));
      for (final p in f.params) {
        out.add(_ParamNav(p, f.sourcePath));
      }
      final body = f.body;
      if (body != null) walkBlock(body);
    }
    return out;
  }

  void walkExpr(Expr e) {
    switch (e) {
      case NameExpr():
        out.add(_NameNav(e, _file));
      case FieldExpr(:final object):
        walkExpr(object);
        out.add(_FieldNav(e, _file));
      case MethodCallExpr(:final receiver, :final args):
        walkExpr(receiver);
        for (final a in args) {
          walkExpr(a);
        }
        out.add(_MethodNav(e, _file));
      case CallExpr(:final args):
        for (final a in args) {
          walkExpr(a);
        }
        out.add(_CallNav(e, _file));
      case UnaryExpr(:final operand):
        walkExpr(operand);
      case BinaryExpr(:final left, :final right):
        walkExpr(left);
        walkExpr(right);
      case GroupExpr(:final inner):
        walkExpr(inner);
      case IndexExpr(:final object, :final index):
        walkExpr(object);
        walkExpr(index);
      case SliceFromExpr(:final array):
        walkExpr(array);
      case ArrayLitExpr(:final elements):
        for (final el in elements) {
          walkExpr(el);
        }
      case StructLitExpr(:final namedFields, :final positionalFields):
        if (namedFields != null) {
          for (final v in namedFields.values) {
            walkExpr(v);
          }
        }
        if (positionalFields != null) {
          for (final v in positionalFields) {
            walkExpr(v);
          }
        }
      case InterpolatedStringExpr(:final parts):
        for (final p in parts) {
          if (p is InterpSlot) walkExpr(p.expr);
        }
      case CastExpr(:final expr):
        walkExpr(expr);
      case AwaitExpr(:final operand):
        walkExpr(operand);
      case ErrorExpr(:final code):
        walkExpr(code);
      case PropagateExpr(:final result):
        walkExpr(result);
      case OrExpr(:final result, :final fallback):
        walkExpr(result);
        for (final s in fallback.stmts) {
          walkStmt(s);
        }
        walkExpr(fallback.value);
      case MatchExpr(:final subject, :final arms):
        walkExpr(subject);
        for (final arm in arms) {
          if (arm.when != null) walkExpr(arm.when!);
          walkExpr(arm.body);
        }
      case PickExpr(:final cond, :final thenExpr, :final elseExpr):
        walkExpr(cond);
        walkExpr(thenExpr);
        walkExpr(elseExpr);
      case IntLit() || FloatLit() || BoolLit() || StringLit() || ByteStringLit():
        break;
    }
  }

  void walkStmt(Stmt s) {
    switch (s) {
      case LetStmt letStmt:
        out.add(_LetNav(letStmt, _file));
        if (letStmt.init != null) walkExpr(letStmt.init!);
      case LetDestructureStmt(:final source):
        walkExpr(source);
      case LetArrayDestructureStmt(:final source):
        walkExpr(source);
      case AssignStmt(:final target, :final value):
        walkExpr(target);
        walkExpr(value);
      case MultiAssignStmt(:final targets, :final values):
        for (final t in targets) {
          walkExpr(t);
        }
        for (final v in values) {
          walkExpr(v);
        }
      case StructAssignStmt(:final targets, :final source):
        for (final t in targets) {
          walkExpr(t);
        }
        walkExpr(source);
      case CallStmt callStmt:
        for (final a in callStmt.args) {
          walkExpr(a);
        }
        out.add(_CallStmtNav(callStmt, _file));
      case MethodCallStmt(:final call):
        walkExpr(call);
      case AwaitStmt(:final expr):
        walkExpr(expr);
      case IfStmt(:final cond, :final thenBlock, :final elseBranch):
        walkExpr(cond);
        walkBlock(thenBlock);
        if (elseBranch != null) walkStmt(elseBranch);
      case WhileStmt(:final cond, :final body):
        walkExpr(cond);
        walkBlock(body);
      case ForRangeStmt(:final start, :final endExclusive, :final body):
        walkExpr(start);
        walkExpr(endExclusive);
        walkBlock(body);
      case ForCStmt(
          :final initExpr,
          :final cond,
          :final postExpr,
          :final body,
        ):
        if (initExpr != null) walkExpr(initExpr);
        if (cond != null) walkExpr(cond);
        if (postExpr != null) walkExpr(postExpr);
        walkBlock(body);
      case ReturnStmt(:final value):
        if (value != null) walkExpr(value);
      case DeferStmt(:final body):
        walkStmt(body);
      case BlockStmt(:final block):
        walkBlock(block);
      case MatchStmt(:final subject, :final arms):
        walkExpr(subject);
        for (final arm in arms) {
          if (arm.when != null) walkExpr(arm.when!);
          walkBlock(arm.body);
        }
      case BreakStmt() || ContinueStmt() || AsmStmt():
        break;
    }
  }

  void walkBlock(Block block) {
    for (final s in block.stmts) {
      walkStmt(s);
    }
  }
}

final class _NavWalker {
  final int line;
  final int col;
  NavTarget? best;
  String? _file;

  _NavWalker(this.line, this.col);

  NavTarget? run(Program program) {
    for (final f in program.funcs) {
      _file = f.sourcePath;
      consider(_FuncNav(f));
      for (final p in f.params) {
        consider(_ParamNav(p, f.sourcePath));
      }
      final body = f.body;
      if (body != null) walkBlock(body);
    }
    return best;
  }

  void consider(NavTarget t) {
    if (!_covers(t.pos, t.nameLength, line, col)) return;
    if (best == null ||
        t.pos.line > best!.pos.line ||
        (t.pos.line == best!.pos.line && t.pos.col >= best!.pos.col)) {
      best = t;
    }
  }

  void walkExpr(Expr e) {
    switch (e) {
      case NameExpr():
        consider(_NameNav(e, _file));
      case FieldExpr(:final object):
        walkExpr(object);
        consider(_FieldNav(e, _file));
      case MethodCallExpr(:final receiver, :final args):
        walkExpr(receiver);
        for (final a in args) {
          walkExpr(a);
        }
        consider(_MethodNav(e, _file));
      case CallExpr(:final args):
        for (final a in args) {
          walkExpr(a);
        }
        consider(_CallNav(e, _file));
      case UnaryExpr(:final operand):
        walkExpr(operand);
      case BinaryExpr(:final left, :final right):
        walkExpr(left);
        walkExpr(right);
      case GroupExpr(:final inner):
        walkExpr(inner);
      case IndexExpr(:final object, :final index):
        walkExpr(object);
        walkExpr(index);
      case SliceFromExpr(:final array):
        walkExpr(array);
      case ArrayLitExpr(:final elements):
        for (final el in elements) {
          walkExpr(el);
        }
      case StructLitExpr(:final namedFields, :final positionalFields):
        if (namedFields != null) {
          for (final v in namedFields.values) {
            walkExpr(v);
          }
        }
        if (positionalFields != null) {
          for (final v in positionalFields) {
            walkExpr(v);
          }
        }
      case InterpolatedStringExpr(:final parts):
        for (final p in parts) {
          if (p is InterpSlot) walkExpr(p.expr);
        }
      case CastExpr(:final expr):
        walkExpr(expr);
      case AwaitExpr(:final operand):
        walkExpr(operand);
      case ErrorExpr(:final code):
        walkExpr(code);
      case PropagateExpr(:final result):
        walkExpr(result);
      case OrExpr(:final result, :final fallback):
        walkExpr(result);
        for (final s in fallback.stmts) {
          walkStmt(s);
        }
        walkExpr(fallback.value);
      case MatchExpr(:final subject, :final arms):
        walkExpr(subject);
        for (final arm in arms) {
          if (arm.when != null) walkExpr(arm.when!);
          walkExpr(arm.body);
        }
      case PickExpr(:final cond, :final thenExpr, :final elseExpr):
        walkExpr(cond);
        walkExpr(thenExpr);
        walkExpr(elseExpr);
      case IntLit() || FloatLit() || BoolLit() || StringLit() || ByteStringLit():
        break;
    }
  }

  void walkStmt(Stmt s) {
    switch (s) {
      case LetStmt letStmt:
        consider(_LetNav(letStmt, _file));
        if (letStmt.init != null) walkExpr(letStmt.init!);
      case LetDestructureStmt(:final source):
        walkExpr(source);
      case LetArrayDestructureStmt(:final source):
        walkExpr(source);
      case AssignStmt(:final target, :final value):
        walkExpr(target);
        walkExpr(value);
      case MultiAssignStmt(:final targets, :final values):
        for (final t in targets) {
          walkExpr(t);
        }
        for (final v in values) {
          walkExpr(v);
        }
      case StructAssignStmt(:final targets, :final source):
        for (final t in targets) {
          walkExpr(t);
        }
        walkExpr(source);
      case CallStmt callStmt:
        for (final a in callStmt.args) {
          walkExpr(a);
        }
        consider(_CallStmtNav(callStmt, _file));
      case MethodCallStmt(:final call):
        walkExpr(call);
      case AwaitStmt(:final expr):
        walkExpr(expr);
      case IfStmt(:final cond, :final thenBlock, :final elseBranch):
        walkExpr(cond);
        walkBlock(thenBlock);
        if (elseBranch != null) walkStmt(elseBranch);
      case WhileStmt(:final cond, :final body):
        walkExpr(cond);
        walkBlock(body);
      case ForRangeStmt(:final start, :final endExclusive, :final body):
        walkExpr(start);
        walkExpr(endExclusive);
        walkBlock(body);
      case ForCStmt(
          :final initExpr,
          :final cond,
          :final postExpr,
          :final body,
        ):
        if (initExpr != null) walkExpr(initExpr);
        if (cond != null) walkExpr(cond);
        if (postExpr != null) walkExpr(postExpr);
        walkBlock(body);
      case ReturnStmt(:final value):
        if (value != null) walkExpr(value);
      case DeferStmt(:final body):
        walkStmt(body);
      case BlockStmt(:final block):
        walkBlock(block);
      case MatchStmt(:final subject, :final arms):
        walkExpr(subject);
        for (final arm in arms) {
          if (arm.when != null) walkExpr(arm.when!);
          walkBlock(arm.body);
        }
      case BreakStmt() || ContinueStmt() || AsmStmt():
        break;
    }
  }

  void walkBlock(Block block) {
    for (final s in block.stmts) {
      walkStmt(s);
    }
  }
}

/// Hover plain text for a nav target, or null.
String? hoverText(NavTarget target) {
  final ty = target.type;
  if (ty != null) {
    return '${target.label}: ${ty.displayName}';
  }
  if (target.def != null) {
    return target.label;
  }
  return null;
}
