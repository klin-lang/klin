part of '../emit_c.dart';

String _functionHeader(FuncDecl func) {
  if (func.name == 'main') return 'int main(void)';
  final returnType = func.resolvedReturnType;
  if (returnType == null) {
    throw StateError('emit: missing return type for function `${func.name}`');
  }
  final params = <String>[
    if (func.receiver case final receiver?)
      '${_cType(receiver.resolvedType!)}${receiver.isMut ? ' *' : ' '}${receiver.name}',
    ...func.params.map((param) {
      final type = param.resolvedType;
      if (type == null) {
        throw StateError('emit: missing type for parameter `${param.name}`');
      }
      return _cDecl(type, param.name);
    }),
  ];
  final codename = func.attrs
      .where((attr) => attr.name == 'codename')
      .map((attr) => attr.arg!)
      .firstOrNull;
  final name = func.name == 'main'
      ? 'main'
      : codename ??
          (func.receiver != null
              ? _methodCName(
                  func.moduleName,
                  _receiverTypeName(func.receiver!),
                  func.name,
                )
              : func.associatedType != null
                  ? _methodCName(
                      func.moduleName,
                      _lastTypeSegment(func.associatedType!),
                      func.name,
                    )
                  : _freeCName(func.moduleName, func.name));
  final staticPrefix = !func.isPub &&
          func.name != 'main' &&
          codename == null &&
          func.body != null
      ? 'static '
      : '';
  return '$staticPrefix${_cType(returnType)} $name(${params.isEmpty ? 'void' : params.join(', ')})';
}

String _receiverTypeName(Receiver receiver) =>
    _lastTypeSegment(receiver.typeName);

String _lastTypeSegment(String typeName) =>
    typeName.contains('.') ? typeName.split('.').last : typeName;

String _cType(KlinType type) => switch (type) {
      PrimType(:final kind) => kind.cType,
      VoidType() => 'void',
      StrType() => 'const char*',
      StructType(:final moduleName, :final name) =>
        _structCName(moduleName, name),
      EnumType(:final moduleName, :final name) =>
        _enumCName(moduleName, name),
      PtrType(:final pointee, :final isVolatile) =>
        '${isVolatile ? 'volatile ' : ''}${_cType(pointee)} *',
      ArrayType(:final elem) => _cType(elem),
      SliceType(:final elem) => _sliceCName(elem),
      ResultType(:final ok) => _resultCName(ok),
      FnType(:final params, :final ret) => _fnTypedefName(FnType(params, ret)),
      _ => throw StateError('emit: type `${type.displayName}` has no C type'),
    };

String _cDecl(KlinType type, String name) => switch (type) {
      ArrayType(:final elem, :final len) => '${_cType(elem)} $name[$len]',
      FnType(:final params, :final ret) => () {
          final ps = params.isEmpty
              ? 'void'
              : params.map(_cType).join(', ');
          return '${_cType(ret)} (*$name)($ps)';
        }(),
      _ => '${_cType(type)} $name',
    };

String _fnTypedefName(FnType type) {
  final ps = type.params.map(_typeToken).join('_');
  final ret = _typeToken(type.ret);
  return ps.isEmpty ? 'klin_fn_void_$ret' : 'klin_fn_${ps}__$ret';
}

int _fnTypeDepth(FnType type) {
  var depth = 0;
  for (final p in type.params) {
    if (p is FnType) {
      final d = _fnTypeDepth(p) + 1;
      if (d > depth) depth = d;
    }
  }
  if (type.ret is FnType) {
    final d = _fnTypeDepth(type.ret as FnType) + 1;
    if (d > depth) depth = d;
  }
  return depth;
}

String _sliceCName(PrimType elem) => 'klin_slice_${elem.kind.klinName}';

void _collectSliceTypes(KlinType? type, Set<PrimType> output) {
  if (type case SliceType(:final elem)) output.add(elem);
  if (type case PtrType(:final pointee)) _collectSliceTypes(pointee, output);
  if (type case ArrayType(:final elem)) _collectSliceTypes(elem, output);
  if (type case ResultType(:final ok)) _collectSliceTypes(ok, output);
  if (type case FnType(:final params, :final ret)) {
    for (final p in params) {
      _collectSliceTypes(p, output);
    }
    _collectSliceTypes(ret, output);
  }
}

void _collectFnTypes(KlinType? type, Set<FnType> output) {
  if (type case FnType()) {
    output.add(type);
    for (final p in type.params) {
      _collectFnTypes(p, output);
    }
    _collectFnTypes(type.ret, output);
  }
  if (type case PtrType(:final pointee)) _collectFnTypes(pointee, output);
  if (type case ArrayType(:final elem)) _collectFnTypes(elem, output);
  if (type case ResultType(:final ok)) _collectFnTypes(ok, output);
}

void _collectResultTypes(KlinType? type, Set<ResultType> output) {
  if (type case ResultType(:final ok)) {
    output.add(type);
    _collectResultTypes(ok, output);
  }
  if (type case PtrType(:final pointee)) _collectResultTypes(pointee, output);
  if (type case ArrayType(:final elem)) _collectResultTypes(elem, output);
  if (type case FnType(:final params, :final ret)) {
    for (final p in params) {
      _collectResultTypes(p, output);
    }
    _collectResultTypes(ret, output);
  }
}

/// Local `!T` from `match` / `error(n)` (issue 132) may not appear on a
/// function signature — walk bodies so typedefs still emit.
void _collectResultTypesFromBlock(Block block, Set<ResultType> output) {
  for (final stmt in block.stmts) {
    _collectResultTypesFromStmt(stmt, output);
  }
}

void _collectResultTypesFromStmt(Stmt stmt, Set<ResultType> output) {
  switch (stmt) {
    case LetStmt(:final init, :final resolvedType):
      _collectResultTypes(resolvedType, output);
      if (init != null) _collectResultTypesFromExpr(init, output);
    case LetDestructureStmt(:final source):
      _collectResultTypesFromExpr(source, output);
    case LetArrayDestructureStmt(:final source):
      _collectResultTypesFromExpr(source, output);
    case AssignStmt(:final value):
      _collectResultTypesFromExpr(value, output);
    case MultiAssignStmt(:final values):
      for (final v in values) {
        _collectResultTypesFromExpr(v, output);
      }
    case StructAssignStmt(:final source):
      _collectResultTypesFromExpr(source, output);
    case ReturnStmt(:final value):
      if (value != null) _collectResultTypesFromExpr(value, output);
    case IfStmt(:final cond, :final thenBlock, :final elseBranch):
      _collectResultTypesFromExpr(cond, output);
      _collectResultTypesFromBlock(thenBlock, output);
      if (elseBranch != null) _collectResultTypesFromStmt(elseBranch, output);
    case WhileStmt(:final cond, :final body):
      _collectResultTypesFromExpr(cond, output);
      _collectResultTypesFromBlock(body, output);
    case ForRangeStmt(:final start, :final endExclusive, :final body):
      _collectResultTypesFromExpr(start, output);
      _collectResultTypesFromExpr(endExclusive, output);
      _collectResultTypesFromBlock(body, output);
    case ForCStmt(:final initExpr, :final cond, :final postExpr, :final body):
      if (initExpr != null) _collectResultTypesFromExpr(initExpr, output);
      if (cond != null) _collectResultTypesFromExpr(cond, output);
      if (postExpr != null) _collectResultTypesFromExpr(postExpr, output);
      _collectResultTypesFromBlock(body, output);
    case MatchStmt(:final subject, :final arms):
      _collectResultTypesFromExpr(subject, output);
      for (final arm in arms) {
        if (arm.when != null) _collectResultTypesFromExpr(arm.when!, output);
        _collectResultTypesFromBlock(arm.body, output);
      }
    case BlockStmt(:final block):
      _collectResultTypesFromBlock(block, output);
    case DeferStmt(:final body):
      _collectResultTypesFromStmt(body, output);
    case CallStmt(:final args):
      for (final a in args) {
        _collectResultTypesFromExpr(a, output);
      }
    case MethodCallStmt(:final call):
      _collectResultTypesFromExpr(call, output);
    case AwaitStmt(:final expr):
      _collectResultTypesFromExpr(expr, output);
    default:
      break;
  }
}

void _collectResultTypesFromExpr(Expr expr, Set<ResultType> output) {
  _collectResultTypes(expr.resolvedType, output);
  switch (expr) {
    case BinaryExpr(:final left, :final right):
      _collectResultTypesFromExpr(left, output);
      _collectResultTypesFromExpr(right, output);
    case UnaryExpr(:final operand):
      _collectResultTypesFromExpr(operand, output);
    case GroupExpr(:final inner):
      _collectResultTypesFromExpr(inner, output);
    case CallExpr(:final args):
      for (final a in args) {
        _collectResultTypesFromExpr(a, output);
      }
    case MethodCallExpr(:final receiver, :final args):
      _collectResultTypesFromExpr(receiver, output);
      for (final a in args) {
        _collectResultTypesFromExpr(a, output);
      }
    case FieldExpr(:final object):
      _collectResultTypesFromExpr(object, output);
    case IndexExpr(:final object, :final index):
      _collectResultTypesFromExpr(object, output);
      _collectResultTypesFromExpr(index, output);
    case CastExpr(:final expr):
      _collectResultTypesFromExpr(expr, output);
    case OrExpr(:final result, :final fallback):
      _collectResultTypesFromExpr(result, output);
      for (final s in fallback.stmts) {
        _collectResultTypesFromStmt(s, output);
      }
      _collectResultTypesFromExpr(fallback.value, output);
    case PropagateExpr(:final result):
      _collectResultTypesFromExpr(result, output);
    case ErrorExpr(:final code):
      _collectResultTypesFromExpr(code, output);
    case MatchExpr(:final subject, :final arms):
      _collectResultTypesFromExpr(subject, output);
      for (final arm in arms) {
        if (arm.when != null) _collectResultTypesFromExpr(arm.when!, output);
        _collectResultTypesFromExpr(arm.body, output);
      }
    case PickExpr(:final cond, :final thenExpr, :final elseExpr):
      _collectResultTypesFromExpr(cond, output);
      _collectResultTypesFromExpr(thenExpr, output);
      _collectResultTypesFromExpr(elseExpr, output);
    case ArrayLitExpr(:final elements):
      for (final e in elements) {
        _collectResultTypesFromExpr(e, output);
      }
    case StructLitExpr(:final namedFields, :final positionalFields):
      if (namedFields != null) {
        for (final v in namedFields.values) {
          _collectResultTypesFromExpr(v, output);
        }
      }
      if (positionalFields != null) {
        for (final v in positionalFields) {
          _collectResultTypesFromExpr(v, output);
        }
      }
    case SliceFromExpr(:final array):
      _collectResultTypesFromExpr(array, output);
    case AwaitExpr(:final operand):
      _collectResultTypesFromExpr(operand, output);
    case InterpolatedStringExpr(:final parts):
      for (final part in parts) {
        if (part is InterpSlot) {
          _collectResultTypesFromExpr(part.expr, output);
        }
      }
    default:
      break;
  }
}

String _resultCName(KlinType ok) => 'klin_res_${_typeToken(ok)}';

String _typeToken(KlinType type) => switch (type) {
      PrimType(:final kind) => kind.klinName,
      VoidType() => 'void',
      StructType(:final moduleName, :final name) =>
        _structCName(moduleName, name),
      EnumType(:final moduleName, :final name) =>
        _enumCName(moduleName, name),
      SliceType(:final elem) => _sliceCName(elem),
      PtrType(:final pointee, :final isMut, :final isVolatile) =>
        '${isMut ? 'mut_' : ''}${isVolatile ? 'volatile_' : ''}ptr_${_typeToken(pointee)}',
      ArrayType(:final elem, :final len) => 'arr${len}_${_typeToken(elem)}',
      ResultType(:final ok) => 'res_${_typeToken(ok)}',
      FnType(:final params, :final ret) =>
        'fn_${params.map(_typeToken).join('_')}_${_typeToken(ret)}',
      StrType() => 'str',
      _ =>
        throw StateError('emit: missing type token for `${type.displayName}`'),
    };

final class _DeferFrame {
  /// Defer bodies registered in encounter order, not from the whole block in advance.
  final List<Stmt> defers = [];
  final bool isLoopBody;

  _DeferFrame({this.isLoopBody = false});
}

final class _EmitState {
  final List<_DeferFrame> deferStack = [];
  int _returnTemp = 0;
  int _valueTemp = 0;
  int _interpTemp = 0;

  String nextReturnTemp() => 'klin_ret_${_returnTemp++}';
  String nextValueTemp() => 'klin_val_${_valueTemp++}';
  String nextInterpBuf() => '_klin_i${_interpTemp++}';
}

final class _ExprCtx {
  final StringBuffer buf;
  final String sourcePath;
  final int indent;
  final bool bareReturnAsZero;
  final String returnCType;
  final _EmitState state;

  _ExprCtx({
    required this.buf,
    required this.sourcePath,
    required this.indent,
    required this.bareReturnAsZero,
    required this.returnCType,
    required this.state,
  });
}

