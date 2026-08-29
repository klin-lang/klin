part of '../emit_c.dart';

void _collectStructKeys(KlinType? type, Set<String> output) {
  if (type == null) return;
  switch (type) {
    case StructType(:final moduleName, :final name):
      output.add('$moduleName.$name');
    case PtrType(:final pointee):
      _collectStructKeys(pointee, output);
    case ArrayType(:final elem):
      _collectStructKeys(elem, output);
    case ResultType(:final ok):
      _collectStructKeys(ok, output);
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
      SliceFromExpr(:final array) => _exprCallsStdio(array),
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
          _exprCallsStdio(fallback.value),
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

