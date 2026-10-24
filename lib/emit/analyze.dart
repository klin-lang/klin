part of '../emit_c.dart';

/// Structs named by [type].
///
/// [throughPointer] is true when the caller needs the pointee present at all
/// (a header should still define it). It is false for emission order: a
/// pointer does not need a complete type, and counting it would make
/// `struct Node { next: *Node }` a cycle. The pointee is spelled
/// `struct Tag *`, so the tag can be completed later.
void _collectStructKeys(
  KlinType? type,
  Set<String> output, {
  bool throughPointer = true,
}) {
  if (type == null) return;
  switch (type) {
    case StructType(:final moduleName, :final name):
      output.add('$moduleName.$name');
    case PtrType(:final pointee):
      // A pointer to a struct may be incomplete (`struct Node *`).
      // A pointer to an array of that struct may not: `T (*)[N]` needs
      // `T` complete. Count that struct so the body is emitted first.
      if (throughPointer || typeNeedsCompleteStructArray(pointee)) {
        _collectStructKeys(pointee, output, throughPointer: throughPointer);
      }
    case ArrayType(:final elem):
      _collectStructKeys(elem, output, throughPointer: throughPointer);
    case SliceType(:final elem):
      _collectStructKeys(elem, output, throughPointer: throughPointer);
    case FnType(:final params, :final ret):
      for (final param in params) {
        _collectStructKeys(param, output, throughPointer: throughPointer);
      }
      _collectStructKeys(ret, output, throughPointer: throughPointer);
    case ResultType(:final ok):
      _collectStructKeys(ok, output, throughPointer: throughPointer);
    default:
      break;
  }
}

String _headerGuard(String sourcePath) {
  final name = sourcePath.split(RegExp(r'[/\\]')).last;
  final base = name.contains('.')
      ? name.substring(0, name.lastIndexOf('.'))
      : name;
  final cleaned = base
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  final token = cleaned.isEmpty ? 'FILE' : cleaned;
  return 'KLIN_${token}_H';
}

Set<String> _collectCIncludes(Program program) {
  final includes = <String>{};
  for (final decl in [...program.structs, ...program.funcs]) {
    final attrs = switch (decl) {
      StructDecl(:final attrs) => attrs,
      FuncDecl(:final attrs) => attrs,
      _ => const <Attr>[],
    };
    for (final attr in attrs) {
      if (attr.name == 'cinclude') {
        final arg = attr.arg!;
        includes.add(arg.startsWith('<') ? arg : '"$arg"');
      }
    }
  }
  if (program.funcs.any(_callsStdio)) includes.add('<stdio.h>');
  return includes;
}

bool _callsStdio(FuncDecl func) =>
    func.body?.stmts.any(_stmtCallsStdio) ?? false;

bool _isStdioName(String? name) =>
    name == 'puts' || name == 'printf' || name == '__klin_fmt_write';

bool _stmtCallsStdio(Stmt stmt) => switch (stmt) {
      CallStmt(:final callee, :final args, :final resolvedCallee) =>
        _isStdioName(callee) ||
            _isStdioName(resolvedCallee) ||
            args.any(_exprCallsStdio),
      MethodCallStmt(:final call) => _exprCallsStdio(call),
      AwaitStmt(:final expr) => _exprCallsStdio(expr),
      LetStmt(:final init) => init != null && _exprCallsStdio(init),
      LetDestructureStmt(:final source) => _exprCallsStdio(source),
      LetArrayDestructureStmt(:final source) => _exprCallsStdio(source),
      AssignStmt(:final target, :final value) =>
        _exprCallsStdio(target) || _exprCallsStdio(value),
      MultiAssignStmt(:final targets, :final values) =>
        targets.any(_exprCallsStdio) || values.any(_exprCallsStdio),
      StructAssignStmt(:final targets, :final source) =>
        _exprCallsStdio(source) || targets.any(_exprCallsStdio),
      IfStmt(:final cond, :final thenBlock, :final elseBranch) =>
        _exprCallsStdio(cond) ||
            thenBlock.stmts.any(_stmtCallsStdio) ||
            (elseBranch != null && _stmtCallsStdio(elseBranch)),
      WhileStmt(:final cond, :final body) =>
        _exprCallsStdio(cond) || body.stmts.any(_stmtCallsStdio),
      ForRangeStmt(:final start, :final endExclusive, :final body) =>
        _exprCallsStdio(start) ||
            _exprCallsStdio(endExclusive) ||
            body.stmts.any(_stmtCallsStdio),
      ForCStmt(:final initExpr, :final cond, :final postExpr, :final body) =>
        (initExpr != null && _exprCallsStdio(initExpr)) ||
            (cond != null && _exprCallsStdio(cond)) ||
            (postExpr != null && _exprCallsStdio(postExpr)) ||
            body.stmts.any(_stmtCallsStdio),
      ReturnStmt(:final value) => value != null && _exprCallsStdio(value),
      DeferStmt(:final body) => _stmtCallsStdio(body),
      BlockStmt(:final block) => block.stmts.any(_stmtCallsStdio),
      MatchStmt(:final subject, :final arms) => _exprCallsStdio(subject) ||
          arms.any((arm) =>
              (arm.when != null && _exprCallsStdio(arm.when!)) ||
              arm.body.stmts.any(_stmtCallsStdio)),
      _ => false,
    };

bool _exprCallsStdio(Expr expr) => switch (expr) {
      CallExpr(:final callee, :final args, :final resolvedCallee) =>
        _isStdioName(callee) ||
            _isStdioName(resolvedCallee) ||
            args.any(_exprCallsStdio) ||
            (args.length == 1 && args[0] is InterpolatedStringExpr) ||
            (args.length == 2 && args[1] is InterpolatedStringExpr),
      InterpolatedStringExpr() => true,
      MethodCallExpr(:final receiver, :final args) =>
        _exprCallsStdio(receiver) || args.any(_exprCallsStdio),
      FieldExpr(:final object) => _exprCallsStdio(object),
      IndexExpr(:final object, :final index) =>
        _exprCallsStdio(object) || _exprCallsStdio(index),
      SliceFromExpr(:final array, :final start, :final end) =>
        _exprCallsStdio(array) ||
            (start != null && _exprCallsStdio(start)) ||
            (end != null && _exprCallsStdio(end)),
      ArrayLitExpr(:final elements) => elements.any(_exprCallsStdio),
      CastExpr(:final expr) => _exprCallsStdio(expr),
      BinaryExpr(:final left, :final right) =>
        _exprCallsStdio(left) || _exprCallsStdio(right),
      UnaryExpr(:final operand) => _exprCallsStdio(operand),
      GroupExpr(:final inner) => _exprCallsStdio(inner),
      ErrorExpr(:final code) => _exprCallsStdio(code),
      PropagateExpr(:final result) => _exprCallsStdio(result),
      AwaitExpr(:final operand) => _exprCallsStdio(operand),
      OrExpr(:final result, :final fallback) => _exprCallsStdio(result) ||
          fallback.stmts.any(_stmtCallsStdio) ||
          (fallback.value != null && _exprCallsStdio(fallback.value!)),
      StructLitExpr(:final namedFields, :final positionalFields) =>
        namedFields?.values.any(_exprCallsStdio) ??
            positionalFields!.any(_exprCallsStdio),
      MatchExpr(:final subject, :final arms) => _exprCallsStdio(subject) ||
          arms.any((arm) =>
              (arm.when != null && _exprCallsStdio(arm.when!)) ||
              _exprCallsStdio(arm.body)),
      PickExpr(:final cond, :final thenExpr, :final elseExpr) =>
          _exprCallsStdio(cond) ||
          _exprCallsStdio(thenExpr) ||
          _exprCallsStdio(elseExpr),
      _ => false,
    };

bool _programNeedsTrimFrac(Program program) {
  for (final func in program.funcs) {
    if (func.body != null && _blockNeedsTrimFrac(func.body!)) return true;
  }
  return false;
}

/// `s.len` and `cstr_u8` call `strlen`. Indexing a `str` does not.
bool _programNeedsStrlen(Program program) {
  for (final func in program.funcs) {
    final body = func.body;
    if (body != null && body.stmts.any(_stmtNeedsStrlen)) return true;
  }
  for (final decl in program.globals) {
    final init = decl.init;
    if (init != null && _exprNeedsStrlen(init)) return true;
  }
  return false;
}

bool _stmtNeedsStrlen(Stmt stmt) => switch (stmt) {
      CallStmt(:final args, :final resolvedCallee) =>
        resolvedCallee == '__klin_cstr_u8' || args.any(_exprNeedsStrlen),
      MethodCallStmt(:final call) => _exprNeedsStrlen(call),
      AwaitStmt(:final expr) => _exprNeedsStrlen(expr),
      LetStmt(:final init) => init != null && _exprNeedsStrlen(init),
      LetDestructureStmt(:final source) => _exprNeedsStrlen(source),
      LetArrayDestructureStmt(:final source) => _exprNeedsStrlen(source),
      AssignStmt(:final target, :final value) =>
        _exprNeedsStrlen(target) || _exprNeedsStrlen(value),
      MultiAssignStmt(:final targets, :final values) =>
        targets.any(_exprNeedsStrlen) || values.any(_exprNeedsStrlen),
      StructAssignStmt(:final targets, :final source) =>
        _exprNeedsStrlen(source) || targets.any(_exprNeedsStrlen),
      IfStmt(:final cond, :final thenBlock, :final elseBranch) =>
        _exprNeedsStrlen(cond) ||
            thenBlock.stmts.any(_stmtNeedsStrlen) ||
            (elseBranch != null && _stmtNeedsStrlen(elseBranch)),
      WhileStmt(:final cond, :final body) =>
        _exprNeedsStrlen(cond) || body.stmts.any(_stmtNeedsStrlen),
      ForRangeStmt(:final start, :final endExclusive, :final body) =>
        _exprNeedsStrlen(start) ||
            _exprNeedsStrlen(endExclusive) ||
            body.stmts.any(_stmtNeedsStrlen),
      ForCStmt(:final initExpr, :final cond, :final postExpr, :final body) =>
        (initExpr != null && _exprNeedsStrlen(initExpr)) ||
            (cond != null && _exprNeedsStrlen(cond)) ||
            (postExpr != null && _exprNeedsStrlen(postExpr)) ||
            body.stmts.any(_stmtNeedsStrlen),
      ReturnStmt(:final value) => value != null && _exprNeedsStrlen(value),
      DeferStmt(:final body) => _stmtNeedsStrlen(body),
      BlockStmt(:final block) => block.stmts.any(_stmtNeedsStrlen),
      MatchStmt(:final subject, :final arms) => _exprNeedsStrlen(subject) ||
          arms.any((arm) =>
              (arm.when != null && _exprNeedsStrlen(arm.when!)) ||
              arm.body.stmts.any(_stmtNeedsStrlen)),
      _ => false,
    };

bool _exprNeedsStrlen(Expr expr) => switch (expr) {
      CallExpr(:final args, :final resolvedCallee) =>
        resolvedCallee == '__klin_cstr_u8' || args.any(_exprNeedsStrlen),
      MethodCallExpr(:final receiver, :final args) =>
        _exprNeedsStrlen(receiver) || args.any(_exprNeedsStrlen),
      FieldExpr(:final object, :final name) =>
        (name == 'len' && object.resolvedType is StrType) ||
            _exprNeedsStrlen(object),
      IndexExpr(:final object, :final index) =>
        _exprNeedsStrlen(object) || _exprNeedsStrlen(index),
      SliceFromExpr(:final array, :final start, :final end) =>
        _exprNeedsStrlen(array) ||
            (start != null && _exprNeedsStrlen(start)) ||
            (end != null && _exprNeedsStrlen(end)),
      ArrayLitExpr(:final elements) => elements.any(_exprNeedsStrlen),
      CastExpr(:final expr) => _exprNeedsStrlen(expr),
      BinaryExpr(:final left, :final right) =>
        _exprNeedsStrlen(left) || _exprNeedsStrlen(right),
      UnaryExpr(:final operand) => _exprNeedsStrlen(operand),
      GroupExpr(:final inner) => _exprNeedsStrlen(inner),
      ErrorExpr(:final code) => _exprNeedsStrlen(code),
      PropagateExpr(:final result) => _exprNeedsStrlen(result),
      AwaitExpr(:final operand) => _exprNeedsStrlen(operand),
      OrExpr(:final result, :final fallback) =>
        _exprNeedsStrlen(result) ||
            fallback.stmts.any(_stmtNeedsStrlen) ||
            (fallback.value != null && _exprNeedsStrlen(fallback.value!)),
      StructLitExpr(:final namedFields, :final positionalFields) =>
        namedFields?.values.any(_exprNeedsStrlen) ??
            positionalFields!.any(_exprNeedsStrlen),
      MatchExpr(:final subject, :final arms) => _exprNeedsStrlen(subject) ||
          arms.any((arm) =>
              (arm.when != null && _exprNeedsStrlen(arm.when!)) ||
              _exprNeedsStrlen(arm.body)),
      PickExpr(:final cond, :final thenExpr, :final elseExpr) =>
        _exprNeedsStrlen(cond) ||
            _exprNeedsStrlen(thenExpr) ||
            _exprNeedsStrlen(elseExpr),
      _ => false,
    };

bool _programNeedsMemHost(Program program) {
  for (final func in program.funcs) {
    for (final attr in func.attrs) {
      if (attr.name == 'codename' &&
          attr.arg != null &&
          attr.arg!.startsWith('klin_mem_')) {
        return true;
      }
    }
  }
  return false;
}

Set<String> _memHostCodename(Program program) {
  final names = <String>{};
  for (final func in program.funcs) {
    for (final attr in func.attrs) {
      if (attr.name == 'codename' &&
          attr.arg != null &&
          attr.arg!.startsWith('klin_mem_')) {
        names.add(attr.arg!);
      }
    }
  }
  return names;
}

