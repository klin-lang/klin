part of '../emit_c.dart';

/// Emit state struct + init + poll (+ erased wrappers) for each `async fn`.
void _emitAsyncFunctions(StringBuffer buf, Program program, String defaultPath) {
  for (final func in program.funcs) {
    if (!func.isAsync || func.body == null) continue;
    _emitAsyncFunction(buf, func, program, func.sourcePath ?? defaultPath);
  }
}

void _emitAsyncFunction(
  StringBuffer buf,
  FuncDecl func,
  Program program,
  String sourcePath,
) {
  final base = _freeCName(func.moduleName, func.name);
  final stateName = '${base}_State';
  final awaits = <AwaitExpr>[];
  _collectAwaitsInBlock(func.body!, awaits);
  final lets = <LetStmt>[];
  _collectLetsInBlock(func.body!, lets);

  buf.writeln('typedef struct {');
  buf.writeln('    int32_t __stage;');
  for (final param in func.params) {
    final ty = param.resolvedType!;
    buf.writeln('    ${_cDecl(ty, param.name)};');
  }
  for (final let in lets) {
    final ty = let.resolvedType!;
    // A returned `[N]T` is the wrapper struct, same as a normal local.
    if (let.arrayByValue && ty is ArrayType) {
      buf.writeln('    ${_cValueType(ty)} ${let.name};');
    } else {
      buf.writeln('    ${_cDecl(ty, let.name)};');
    }
  }
  for (var i = 0; i < awaits.length; i++) {
    final aw = awaits[i];
    if (aw.asyncCallee != null) {
      buf.writeln('    ${aw.asyncCallee}_State __aw$i;');
    } else {
      // Pollable future — use the operand's resolved struct type.
      final op = aw.operand;
      final ty = op.resolvedType;
      if (ty is! StructType) {
        throw StateError('emit async: pollable await without struct type');
      }
      buf.writeln('    ${_cType(ty)} __aw$i;');
    }
  }
  buf.writeln('} $stateName;');
  buf.writeln();

  // init(st, params…)
  final initParams = StringBuffer('$stateName *st');
  for (final param in func.params) {
    initParams.write(', ${_cDecl(param.resolvedType!, param.name)}');
  }
  buf.writeln('static void ${base}_init($initParams) {');
  buf.writeln('    st->__stage = 0;');
  for (final param in func.params) {
    final ty = param.resolvedType!;
    if (ty is ArrayType) {
      // A C array parameter cannot be assigned. Copy each element.
      _emitAsyncArrayElemCopy(
        buf,
        dest: 'st->${param.name}',
        src: param.name,
        type: ty,
        indent: 1,
      );
    } else {
      buf.writeln('    st->${param.name} = ${param.name};');
    }
  }
  buf.writeln('}');
  buf.writeln();

  buf.writeln('static int32_t ${base}_poll($stateName *st) {');
  buf.writeln('    switch (st->__stage) {');
  buf.writeln('    case 0:');
  final ctx = _AsyncEmitCtx(
    buf: buf,
    sourcePath: sourcePath,
    stateName: stateName,
    base: base,
    awaits: awaits,
    indent: 2,
  );
  _emitAsyncBlock(func.body!, ctx);
  buf.writeln('        st->__stage = -1;');
  buf.writeln('        return 1;');
  buf.writeln('    default:');
  buf.writeln('        return 1;');
  buf.writeln('    }');
  buf.writeln('}');
  buf.writeln();

  // Erased wrappers for eventloop.spawn (zero-param async fn only).
  if (func.params.isEmpty) {
    buf.writeln('static void ${base}_init_erased(uint8_t *p) {');
    buf.writeln('    ${base}_init(($stateName *)p);');
    buf.writeln('}');
    buf.writeln();
    buf.writeln('static int32_t ${base}_poll_erased(uint8_t *p) {');
    buf.writeln('    return ${base}_poll(($stateName *)p);');
    buf.writeln('}');
    buf.writeln();
  }
}

final class _AsyncEmitCtx {
  final StringBuffer buf;
  final String sourcePath;
  final String stateName;
  final String base;
  final List<AwaitExpr> awaits;
  int indent;
  int awaitIndex = 0;

  _AsyncEmitCtx({
    required this.buf,
    required this.sourcePath,
    required this.stateName,
    required this.base,
    required this.awaits,
    required this.indent,
  });

  String get pad => '    ' * indent;
}

void _collectAwaitsInBlock(Block block, List<AwaitExpr> out) {
  for (final stmt in block.stmts) {
    _collectAwaitsInStmt(stmt, out);
  }
}

void _collectAwaitsInStmt(Stmt stmt, List<AwaitExpr> out) {
  switch (stmt) {
    case AwaitStmt(:final expr):
      out.add(expr);
    case IfStmt(:final thenBlock, :final elseBranch):
      _collectAwaitsInBlock(thenBlock, out);
      if (elseBranch != null) _collectAwaitsInStmt(elseBranch, out);
    case WhileStmt(:final body):
      _collectAwaitsInBlock(body, out);
    case BlockStmt(:final block):
      _collectAwaitsInBlock(block, out);
    default:
      break;
  }
}

void _collectLetsInBlock(Block block, List<LetStmt> out) {
  for (final stmt in block.stmts) {
    _collectLetsInStmt(stmt, out);
  }
}

void _collectLetsInStmt(Stmt stmt, List<LetStmt> out) {
  switch (stmt) {
    case LetStmt():
      out.add(stmt);
    case IfStmt(:final thenBlock, :final elseBranch):
      _collectLetsInBlock(thenBlock, out);
      if (elseBranch != null) _collectLetsInStmt(elseBranch, out);
    case WhileStmt(:final body):
      _collectLetsInBlock(body, out);
    case BlockStmt(:final block):
      _collectLetsInBlock(block, out);
    default:
      break;
  }
}

void _emitAsyncBlock(Block block, _AsyncEmitCtx ctx) {
  for (final stmt in block.stmts) {
    _emitAsyncStmt(stmt, ctx);
  }
}

void _emitAsyncStmt(Stmt stmt, _AsyncEmitCtx ctx) {
  final buf = ctx.buf;
  final pad = ctx.pad;
  switch (stmt) {
    case AwaitStmt(:final expr, :final pos):
      _line(buf, pos.line, ctx.sourcePath);
      final idx = ctx.awaitIndex++;
      final stage = idx + 1;
      final aw = expr;
      if (aw.asyncCallee != null) {
        final callee = aw.asyncCallee!;
        final call = aw.operand;
        if (call is! CallExpr) {
          throw StateError('emit async: async await operand must be a call');
        }
        final args = call.args
            .map((a) => _emitAsyncExpr(a, ctx))
            .join(', ');
        final initArgs = args.isEmpty ? '&st->__aw$idx' : '&st->__aw$idx, $args';
        buf.writeln('$pad${callee}_init($initArgs);');
        buf.writeln('${pad}st->__stage = $stage;');
        buf.writeln('${pad}/* fallthrough */');
        buf.writeln('${pad}case $stage:');
        buf.writeln(
            '${pad}if (${callee}_poll(&st->__aw$idx) == 0) return 0;');
      } else {
        final poll = aw.pollMangled!;
        buf.writeln(
            '${pad}st->__aw$idx = ${_emitAsyncExpr(aw.operand, ctx)};');
        buf.writeln('${pad}st->__stage = $stage;');
        buf.writeln('${pad}/* fallthrough */');
        buf.writeln('${pad}case $stage:');
        buf.writeln('${pad}if ($poll(&st->__aw$idx) == 0) return 0;');
      }

    case CallStmt(
        :final callee,
        :final args,
        :final pos,
        :final resolvedCallee,
        :final asyncSpawnFn,
      ):
      _line(buf, pos.line, ctx.sourcePath);
      if (asyncSpawnFn != null) {
        throw StateError('emit: spawn inside async fn is not supported in MVP');
      }
      if (args.length == 1 && args[0] is InterpolatedStringExpr) {
        // Lower via a temporary ExprCtx — stdio from async body.
        final state = _EmitState();
        final ectx = _ExprCtx(
          buf: buf,
          sourcePath: ctx.sourcePath,
          indent: ctx.indent,
          bareReturnAsZero: false,
          returnCType: 'int32_t',
          state: state,
        );
        _emitInterpPrintf(
          buf,
          args[0] as InterpolatedStringExpr,
          indent: ctx.indent,
          ctx: ectx,
          state: state,
        );
      } else {
        final argList = args.map((a) => _emitAsyncArg(a, ctx)).join(', ');
        buf.writeln('$pad${resolvedCallee ?? callee}($argList);');
      }

    case MethodCallStmt(:final call, :final pos):
      _line(buf, pos.line, ctx.sourcePath);
      buf.writeln('$pad${_emitAsyncExpr(call, ctx)};');

    case LetStmt(
        :final name,
        :final init,
        :final pos,
        :final arrayByValue,
        :final resolvedType
      ):
      _line(buf, pos.line, ctx.sourcePath);
      if (init != null) {
        final peeled = _peelEmitGroups(init);
        final ty = resolvedType;
        if (ty is ArrayType && !arrayByValue && peeled is ArrayLitExpr) {
          // `uint8_t xs[N]` is not assignable. Store each element.
          _emitAsyncArrayLitStore(buf, peeled, 'st->$name', ty, ctx);
        } else {
          buf.writeln('${pad}st->$name = ${_emitAsyncExpr(init, ctx)};');
        }
      }

    case AssignStmt(:final target, :final value, :final pos, :final compoundOp):
      _line(buf, pos.line, ctx.sourcePath);
      final lhs = _emitAsyncExpr(target, ctx);
      final rhs = _emitAsyncExpr(value, ctx);
      if (compoundOp != null) {
        buf.writeln('$pad$lhs $compoundOp= $rhs;');
      } else {
        buf.writeln('$pad$lhs = $rhs;');
      }

    case WhileStmt(:final cond, :final body, :final pos):
      _line(buf, pos.line, ctx.sourcePath);
      final label = '__async_loop_${ctx.awaitIndex}_${pos.line}';
      final end = '${label}_end';
      buf.writeln('$pad$label:');
      // Do not `break` — we are inside a `switch` for the state machine.
      buf.writeln(
          '${pad}if (!(${_emitAsyncExpr(cond, ctx)})) goto $end;');
      _emitAsyncBlock(body, ctx);
      buf.writeln('${pad}goto $label;');
      buf.writeln('$pad$end: ;');

    case IfStmt(:final cond, :final thenBlock, :final elseBranch, :final pos):
      _line(buf, pos.line, ctx.sourcePath);
      buf.writeln('${pad}if (${_emitAsyncExpr(cond, ctx)}) {');
      ctx.indent++;
      _emitAsyncBlock(thenBlock, ctx);
      ctx.indent--;
      if (elseBranch != null) {
        buf.writeln('$pad} else {');
        ctx.indent++;
        _emitAsyncStmt(elseBranch, ctx);
        ctx.indent--;
      }
      buf.writeln('$pad}');

    case BlockStmt(:final block):
      _emitAsyncBlock(block, ctx);

    case ReturnStmt(:final pos):
      _line(buf, pos.line, ctx.sourcePath);
      buf.writeln('${pad}st->__stage = -1;');
      buf.writeln('${pad}return 1;');

    default:
      throw StateError(
        'emit async MVP: unsupported statement `${stmt.runtimeType}`',
      );
  }
}

/// An array parameter wants the C array. A returned `[N]T` passes `.v`.
String _emitAsyncArg(Expr arg, _AsyncEmitCtx ctx) {
  if (!_exprIsArrayValue(arg)) return _emitAsyncExpr(arg, ctx);
  final raw = _emitAsyncExpr(arg, ctx);
  final simple = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(raw);
  return simple ? '$raw.v' : '($raw).v';
}

String _emitAsyncExpr(Expr expr, _AsyncEmitCtx ctx) {
  return switch (expr) {
    IntLit lit => _emitIntLit(lit),
    FloatLit(:final lexeme) => lexeme.replaceAll('_', ''),
    BoolLit(:final value) => value ? 'true' : 'false',
    StringLit(:final value) => '"${_escapeC(value)}"',
    ByteStringLit(:final value) => _emitByteString(value),
    NameExpr(:final name, :final resolvedFnCName, :final resolvedConstCName) =>
      resolvedConstCName ?? resolvedFnCName ?? 'st->$name',
    UnaryExpr(:final op, :final operand, :final resolvedType) =>
      _emitUnary(
        op,
        operand,
        resolvedType,
        (inner) => _emitAsyncExpr(inner, ctx),
      ),
    BinaryExpr(:final left, :final op, :final right) =>
      '(${_emitAsyncExpr(left, ctx)} $op ${_emitAsyncExpr(right, ctx)})',
    PickExpr(:final cond, :final thenExpr, :final elseExpr) =>
      expr.resolvedType is ArrayType
          ? '(${_emitAsyncExpr(cond, ctx)} ? ${_emitAsyncArrayValue(thenExpr, ctx)} : ${_emitAsyncArrayValue(elseExpr, ctx)})'
          : '(${_emitAsyncExpr(cond, ctx)} ? ${_emitAsyncExpr(thenExpr, ctx)} : ${_emitAsyncExpr(elseExpr, ctx)})',
    IndexExpr(:final object, :final index) => () {
        final indexC = _emitAsyncExpr(index, ctx);
        final obj = _emitAsyncExpr(object, ctx);
        if (object.resolvedType is SliceType) {
          return '($obj).ptr[$indexC]';
        }
        if (_exprIsArrayValue(object)) {
          final simple = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(obj);
          final base = simple ? '$obj.v' : '($obj).v';
          return '$base[$indexC]';
        }
        return '($obj)[$indexC]';
      }(),
    ArrayLitExpr lit => _emitAsyncArrayLit(lit, ctx),
    GroupExpr(:final inner) => '(${_emitAsyncExpr(inner, ctx)})',
    CallExpr(:final callee, :final args, :final resolvedCallee) =>
      '${resolvedCallee ?? callee}(${args.map((a) => _emitAsyncArg(a, ctx)).join(', ')})',
    MethodCallExpr(
      :final receiver,
      :final args,
      :final mangledName,
      :final receiverByRef,
      :final isAssociated,
    ) =>
      () {
        final callee =
            mangledName ?? (throw StateError('emit async: method without mangling'));
        final argList = args.map((a) => _emitAsyncArg(a, ctx)).join(', ');
        if (isAssociated) return '$callee($argList)';
        final recv =
            '${receiverByRef ? '&' : ''}${_emitAsyncExpr(receiver, ctx)}';
        return args.isEmpty ? '$callee($recv)' : '$callee($recv, $argList)';
      }(),
    FieldExpr(:final object, :final name, :final constCName) =>
      constCName ?? '${_emitAsyncExpr(object, ctx)}.$name',
    CastExpr(:final resolvedType, :final expr) => () {
        final target = resolvedType;
        if (target == null) throw StateError('emit async: cast without type');
        if (target is PtrType) {
          return '(${_cType(target)})(uintptr_t)(${_emitAsyncExpr(expr, ctx)})';
        }
        return '(${_cType(target)})(${_emitAsyncExpr(expr, ctx)})';
      }(),
    _ => throw StateError(
        'emit async MVP: unsupported expr `${expr.runtimeType}`',
      ),
  };
}

/// `[N]T` as a value in an async expression. A call or by-value binding is
/// already the wrapper. A literal or a C array is copied into `.v`.
String _emitAsyncArrayValue(Expr expr, _AsyncEmitCtx ctx) {
  if (_exprIsArrayValue(expr)) return _emitAsyncExpr(expr, ctx);
  final type = expr.resolvedType;
  if (type is! ArrayType) {
    throw StateError('emit async: array value without an array type');
  }
  return '(${_arrayValueCName(type)}){ .v = ${_emitAsyncArrayBrace(expr, type, ctx)} }';
}

String _emitAsyncArrayBrace(Expr expr, ArrayType type, _AsyncEmitCtx ctx) {
  final node = _peelEmitGroups(expr);
  if (node is ArrayLitExpr) {
    return _emitAsyncArrayLit(node, ctx, asInitializer: true);
  }
  return _emitArrayElements(_emitAsyncArrayObject(expr, ctx), type);
}

String _emitAsyncArrayObject(Expr expr, _AsyncEmitCtx ctx) {
  if (!_exprIsArrayValue(expr)) return _emitAsyncExpr(expr, ctx);
  final raw = _emitAsyncExpr(expr, ctx);
  final simple = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(raw);
  return simple ? '$raw.v' : '($raw).v';
}

String _emitAsyncArrayLit(
  ArrayLitExpr expr,
  _AsyncEmitCtx ctx, {
  bool asInitializer = false,
}) {
  final inner = expr.elements.map((element) {
    final peeled = _peelEmitGroups(element);
    if (peeled is ArrayLitExpr) {
      return _emitAsyncArrayLit(peeled, ctx, asInitializer: true);
    }
    return _emitAsyncExpr(element, ctx);
  }).join(', ');
  final braces = inner.isEmpty ? '{ }' : '{ $inner }';
  if (!asInitializer &&
      expr.resolvedType is ArrayType &&
      _arrayElemIsConcrete(expr.resolvedType! as ArrayType)) {
    return '(${_cArraySuffixType(expr.resolvedType! as ArrayType)})$braces';
  }
  return braces;
}

/// Store a literal into a C array field (`st->xs[i] = …`), including a
/// nested `[N][M]T`.
void _emitAsyncArrayLitStore(
  StringBuffer buf,
  ArrayLitExpr lit,
  String dest,
  ArrayType type,
  _AsyncEmitCtx ctx,
) {
  void walk(ArrayLitExpr node, ArrayType ty, String place) {
    for (var i = 0; i < ty.len; i++) {
      final element = node.elements[i];
      final slot = '$place[$i]';
      final elem = ty.elem;
      if (elem is ArrayType) {
        final inner = _peelEmitGroups(element);
        if (inner is! ArrayLitExpr) {
          throw StateError('emit async: nested array init must be a literal');
        }
        walk(inner, elem, slot);
      } else {
        buf.writeln('${ctx.pad}$slot = ${_emitAsyncExpr(element, ctx)};');
      }
    }
  }

  walk(lit, type, dest);
}

void _emitAsyncArrayElemCopy(
  StringBuffer buf, {
  required String dest,
  required String src,
  required ArrayType type,
  required int indent,
}) {
  final pad = '    ' * indent;
  void walk(String d, String s, KlinType ty) {
    if (ty is ArrayType) {
      for (var i = 0; i < ty.len; i++) {
        walk('$d[$i]', '$s[$i]', ty.elem);
      }
      return;
    }
    buf.writeln('$pad$d = $s;');
  }

  walk(dest, src, type);
}
