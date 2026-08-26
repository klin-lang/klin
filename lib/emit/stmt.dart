part of '../emit_c.dart';

void _emitValueAssignment(
  StringBuffer buf, {
  required String target,
  required KlinType targetType,
  required Expr value,
  required String sourcePath,
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final ctx = _ExprCtx(
    buf: buf,
    sourcePath: sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  final pad = '    ' * indent;
  if (value case PropagateExpr(:final result)) {
    final temp = _emitPropagate(result, ctx);
    buf.writeln('$pad$target = $temp.u.ok;');
    return;
  }
  if (value case OrExpr(:final result, :final fallback)) {
    final resultType = result.resolvedType;
    if (resultType is! ResultType) {
      throw StateError('emit: `or` without a result type');
    }
    final temp = state.nextValueTemp();
    buf.writeln('$pad${_cType(resultType)} $temp = ${_emitExpr(result, ctx)};');
    buf.writeln('${pad}if ($temp.is_err) {');
    final innerPad = '    ' * (indent + 1);
    buf.writeln('${innerPad}int32_t err = $temp.u.err;');
    for (final stmt in fallback.stmts) {
      _emitStmt(
        buf,
        stmt,
        sourcePath,
        indent: indent + 1,
        pad: innerPad,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
      );
    }
    _emitValueAssignment(
      buf,
      target: target,
      targetType: targetType,
      value: fallback.value,
      sourcePath: sourcePath,
      indent: indent + 1,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
    buf.writeln('$pad} else {');
    buf.writeln('${innerPad}$target = $temp.u.ok;');
    buf.writeln('$pad}');
    return;
  }
  // Success value assigned into a `!T` slot (match arm / annotated let).
  if (targetType is ResultType && value.resolvedType is! ResultType) {
    buf.writeln(
      '$pad$target = (${_cType(targetType)}){ .is_err = false, '
      '.u.ok = ${_emitExpr(value, ctx)} };',
    );
    return;
  }
  buf.writeln('$pad$target = ${_emitExpr(value, ctx)};');
}

String _emitPropagate(Expr result, _ExprCtx ctx) {
  final resultType = result.resolvedType;
  if (resultType is! ResultType) {
    throw StateError('emit: propagation without a result type');
  }
  final pad = '    ' * ctx.indent;
  final temp = ctx.state.nextValueTemp();
  ctx.buf
      .writeln('$pad${_cType(resultType)} $temp = ${_emitExpr(result, ctx)};');
  ctx.buf.writeln('${pad}if ($temp.is_err) {');
  _emitExitCleanups(
    ctx.buf,
    ctx.state.deferStack,
    ctx.sourcePath,
    indent: ctx.indent + 1,
    bareReturnAsZero: ctx.bareReturnAsZero,
    returnCType: ctx.returnCType,
    state: ctx.state,
  );
  ctx.buf.writeln('${'    ' * (ctx.indent + 1)}return $temp;');
  ctx.buf.writeln('$pad}');
  return temp;
}

void _emitBlock(
  StringBuffer buf,
  Block block,
  String sourcePath, {
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
  bool isLoopBody = false,
}) {
  final pad = '    ' * indent;
  final frame = _DeferFrame(isLoopBody: isLoopBody);
  state.deferStack.add(frame);
  for (final stmt in block.stmts) {
    _emitStmt(
      buf,
      stmt,
      sourcePath,
      indent: indent,
      pad: pad,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
  }
  _emitFrameCleanups(
    buf,
    frame,
    sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  state.deferStack.removeLast();
}

void _emitStmt(
  StringBuffer buf,
  Stmt stmt,
  String sourcePath, {
  required int indent,
  required String pad,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final ctx = _ExprCtx(
    buf: buf,
    sourcePath: sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  switch (stmt) {
    case AsmStmt(:final code, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}asm volatile("${_escapeC(code)}");');

    case LetStmt(:final name, :final init, :final pos, :final resolvedType):
      _line(buf, pos.line, sourcePath);
      final ty = resolvedType;
      if (ty == null) {
        throw StateError('emit: missing type for `$name` — run the checker');
      }
      if (init != null) {
        if (init is OrExpr || init is PropagateExpr) {
          buf.writeln('$pad${_cDecl(ty, name)};');
          _emitValueAssignment(
            buf,
            target: name,
            targetType: ty,
            value: init,
            sourcePath: sourcePath,
            indent: indent,
            bareReturnAsZero: bareReturnAsZero,
            returnCType: returnCType,
            state: state,
          );
        } else if (init is MatchExpr) {
          buf.writeln('$pad${_cDecl(ty, name)};');
          _emitMatchAssign(
            buf,
            target: name,
            targetType: ty,
            match: init,
            sourcePath: sourcePath,
            indent: indent,
            bareReturnAsZero: bareReturnAsZero,
            returnCType: returnCType,
            state: state,
          );
        } else {
          buf.writeln('$pad${_cDecl(ty, name)} = ${_emitExpr(init, ctx)};');
        }
      } else {
        final zero = switch (ty) {
          PrimType(:final kind) => kind.cZero,
          PtrType() => 'NULL',
          FnType() => 'NULL',
          ArrayType() => '{0}',
          SliceType() => '{ NULL, 0 }',
          StructType() => '{0}',
          EnumType() => '0',
          StrType() => 'NULL',
          ResultType() => '{0}',
          _ => throw StateError('emit: missing default value for `$name`'),
        };
        buf.writeln('$pad${_cDecl(ty, name)} = $zero;');
      }

    case LetDestructureStmt(
        :final fields,
        :final binds,
        :final source,
        :final pos,
        :final sourceType,
        :final fieldTypes
      ):
      _line(buf, pos.line, sourcePath);
      final st = sourceType!;
      final fts = fieldTypes!;
      // Evaluate the source once. A plain name is read in place, unless a
      // binding shadows it (possible via rename, e.g. `let { x: p } = p`), in
      // which case — like any non-name source — copy it into a fresh temp so
      // later field reads do not use a newly declared scalar.
      final String access;
      if (source is NameExpr && !binds.contains(source.name)) {
        access = _emitExpr(source, ctx) +
            (_exprIsPtrReceiver(source) ? '->' : '.');
      } else {
        final tmp = state.nextValueTemp();
        final rhs = source is NameExpr && _exprIsPtrReceiver(source)
            ? '*${_emitExpr(source, ctx)}'
            : _emitExpr(source, ctx);
        buf.writeln('$pad${_cDecl(st, tmp)} = $rhs;');
        access = '$tmp.';
      }
      for (var i = 0; i < fields.length; i++) {
        buf.writeln(
            '$pad${_cDecl(fts[i], binds[i])} = $access${fields[i]};');
      }

    case LetArrayDestructureStmt(
        :final names,
        :final source,
        :final pos,
        :final elemType
      ):
      _line(buf, pos.line, sourcePath);
      final et = elemType!;
      if (source is ArrayLitExpr) {
        // Evaluate every element into a fresh temp before binding, so a swap
        // like `let [a, b] = [b, a]` reads the outer values, not new bindings.
        // `_` positions are still evaluated (side effects are part of the
        // written literal) but not bound.
        final temps = <String>[];
        for (var i = 0; i < names.length; i++) {
          final t = state.nextValueTemp();
          temps.add(t);
          buf.writeln(
              '$pad${_cDecl(et, t)} = ${_emitExpr(source.elements[i], ctx)};');
        }
        for (var i = 0; i < names.length; i++) {
          final name = names[i];
          if (name == null) continue; // `_` skip: evaluated above, not bound
          buf.writeln('$pad${_cDecl(et, name)} = ${temps[i]};');
        }
      } else {
        // A plain array variable is indexed in place. If a binding shadows the
        // source name, capture the array via a pointer first so later reads do
        // not index a freshly-declared scalar.
        final base = _emitExpr(source, ctx);
        final String indexed;
        if (source is NameExpr && names.contains(source.name)) {
          final tmp = state.nextValueTemp();
          buf.writeln('$pad${_cType(et)} *$tmp = $base;');
          indexed = tmp;
        } else {
          indexed = base;
        }
        for (var i = 0; i < names.length; i++) {
          final name = names[i];
          if (name == null) continue; // `_` skip
          buf.writeln('$pad${_cDecl(et, name)} = $indexed[$i];');
        }
      }

    case AssignStmt(:final target, :final value, :final pos, :final compoundOp):
      _line(buf, pos.line, sourcePath);
      if (compoundOp != null) {
        // 1:1 C compound assign — LHS evaluated once.
        buf.writeln(
          '$pad${_emitExpr(target, ctx)} $compoundOp= ${_emitExpr(value, ctx)};',
        );
      } else if (value is OrExpr || value is PropagateExpr) {
        _emitValueAssignment(
          buf,
          target: _emitExpr(target, ctx),
          targetType: target.resolvedType!,
          value: value,
          sourcePath: sourcePath,
          indent: indent,
          bareReturnAsZero: bareReturnAsZero,
          returnCType: returnCType,
          state: state,
        );
      } else if (value is MatchExpr) {
        _emitMatchAssign(
          buf,
          target: _emitExpr(target, ctx),
          targetType: target.resolvedType!,
          match: value,
          sourcePath: sourcePath,
          indent: indent,
          bareReturnAsZero: bareReturnAsZero,
          returnCType: returnCType,
          state: state,
        );
      } else {
        buf.writeln(
            '$pad${_emitExpr(target, ctx)} = ${_emitExpr(value, ctx)};');
      }

    case MultiAssignStmt(:final targets, :final values, :final pos):
      _line(buf, pos.line, sourcePath);
      // Evaluate every value into a fresh temp before writing any target, so a
      // swap `a, b = b, a` uses the old values.
      final temps = <String>[];
      for (var i = 0; i < values.length; i++) {
        final tmp = state.nextValueTemp();
        temps.add(tmp);
        buf.writeln(
            '$pad${_cDecl(targets[i].resolvedType!, tmp)} = ${_emitExpr(values[i], ctx)};');
      }
      for (var i = 0; i < targets.length; i++) {
        buf.writeln('$pad${_emitExpr(targets[i], ctx)} = ${temps[i]};');
      }

    case StructAssignStmt(
        :final fields,
        :final targets,
        :final source,
        :final pos,
        :final sourceType
      ):
      _line(buf, pos.line, sourcePath);
      // Copy the source once so targets may alias it, then assign each field.
      final tmp = state.nextValueTemp();
      final rhs = source is NameExpr && _exprIsPtrReceiver(source)
          ? '*${_emitExpr(source, ctx)}'
          : _emitExpr(source, ctx);
      buf.writeln('$pad${_cDecl(sourceType!, tmp)} = $rhs;');
      for (var i = 0; i < fields.length; i++) {
        buf.writeln(
            '$pad${_emitExpr(targets[i], ctx)} = $tmp.${fields[i]};');
      }

    case CallStmt(
        :final callee,
        :final args,
        :final pos,
        :final resolvedCallee,
        :final asyncSpawnFn,
      ):
      _line(buf, pos.line, sourcePath);
      if (asyncSpawnFn != null) {
        // eventloop.spawn(&ex, async_fn) → spawn(ex, poll_erased, init_erased)
        final ex = _emitExpr(args[0], ctx);
        buf.writeln(
          '$pad(void)${resolvedCallee ?? 'eventloop_spawn'}($ex, '
          '${asyncSpawnFn}_poll_erased, ${asyncSpawnFn}_init_erased);',
        );
      } else if (args.length == 1 && args[0] is InterpolatedStringExpr) {
        _emitInterpPrintf(
          buf,
          args[0] as InterpolatedStringExpr,
          indent: indent,
          ctx: ctx,
          state: state,
        );
      } else {
        final argList = args.map((arg) => _emitExpr(arg, ctx)).join(', ');
        buf.writeln('$pad${resolvedCallee ?? callee}($argList);');
      }

    case MethodCallStmt(:final call):
      _line(buf, call.pos.line, sourcePath);
      buf.writeln('$pad${_emitExpr(call, ctx)};');

    case AwaitStmt():
      throw StateError(
        'emit: AwaitStmt must be lowered inside an async poll function',
      );

    case IfStmt(:final cond, :final thenBlock, :final elseBranch, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}if (${_emitExpr(cond, ctx)}) {');
      _emitBlock(
        buf,
        thenBlock,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
      );
      _emitElse(
        buf,
        elseBranch,
        sourcePath,
        indent: indent,
        pad: pad,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
      );

    case WhileStmt(:final cond, :final body, :final pos):
      _line(buf, pos.line, sourcePath);
      buf.writeln('${pad}while (${_emitExpr(cond, ctx)}) {');
      _emitBlock(
        buf,
        body,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
        isLoopBody: true,
      );
      buf.writeln('$pad}');

    case ForRangeStmt(
        :final name,
        :final start,
        :final endExclusive,
        :final body,
        :final pos,
        :final resolvedType
      ):
      _line(buf, pos.line, sourcePath);
      final ty = resolvedType;
      if (ty is! PrimType) {
        throw StateError('emit: missing type for loop variable `$name`');
      }
      buf.writeln(
        '${pad}for (${ty.kind.cType} $name = ${_emitExpr(start, ctx)}; '
        '$name < ${_emitExpr(endExclusive, ctx)}; $name++) {',
      );
      _emitBlock(
        buf,
        body,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
        isLoopBody: true,
      );
      buf.writeln('$pad}');

    case ForCStmt(
        :final initName,
        :final initExpr,
        :final initDecl,
        :final cond,
        :final postName,
        :final postExpr,
        :final body,
        :final pos,
        :final resolvedInitType
      ):
      _line(buf, pos.line, sourcePath);
      final initPart = () {
        if (initName == null || initExpr == null) return '';
        final rhs = _emitExpr(initExpr, ctx);
        if (!initDecl) {
          return '$initName = $rhs';
        }
        final ty = resolvedInitType;
        if (ty is! PrimType) {
          throw StateError('emit: missing type for initializer `$initName`');
        }
        return '${ty.kind.cType} $initName = $rhs';
      }();
      final condPart = cond == null ? '' : _emitExpr(cond, ctx);
      final postPart = (postName != null && postExpr != null)
          ? '$postName = ${_emitExpr(postExpr, ctx)}'
          : '';
      buf.writeln('${pad}for ($initPart; $condPart; $postPart) {');
      _emitBlock(
        buf,
        body,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
        isLoopBody: true,
      );
      buf.writeln('$pad}');

    case ReturnStmt(:final value, :final pos):
      _line(buf, pos.line, sourcePath);
      if (value == null) {
        _emitExitCleanups(
          buf,
          state.deferStack,
          sourcePath,
          indent: indent,
          bareReturnAsZero: bareReturnAsZero,
          returnCType: returnCType,
          state: state,
        );
        buf.writeln(bareReturnAsZero ? '${pad}return 0;' : '${pad}return;');
      } else {
        if (value is PropagateExpr) {
          final propagated = _emitPropagate(value.result, ctx);
          final resultType = value.result.resolvedType! as ResultType;
          final temp = state.nextReturnTemp();
          buf.writeln(
            '$pad$returnCType $temp = (${_cType(resultType)}){ '
            '.is_err = false, .u.ok = $propagated.u.ok };',
          );
          _emitExitCleanups(
            buf,
            state.deferStack,
            sourcePath,
            indent: indent,
            bareReturnAsZero: bareReturnAsZero,
            returnCType: returnCType,
            state: state,
          );
          buf.writeln('${pad}return $temp;');
          return;
        }
        final temp = state.nextReturnTemp();
        final valueType = value.resolvedType;
        final returnValue = valueType is ResultType
            ? _emitExpr(value, ctx)
            : returnCType.startsWith('klin_res_')
                ? '($returnCType){ .is_err = false, .u.ok = ${_emitExpr(value, ctx)} }'
                : _emitExpr(value, ctx);
        buf.writeln('$pad$returnCType $temp = $returnValue;');
        _emitExitCleanups(
          buf,
          state.deferStack,
          sourcePath,
          indent: indent,
          bareReturnAsZero: bareReturnAsZero,
          returnCType: returnCType,
          state: state,
        );
        buf.writeln('${pad}return $temp;');
      }

    case BreakStmt(:final pos):
      _line(buf, pos.line, sourcePath);
      _emitLoopExitCleanups(
        buf,
        state,
        sourcePath,
        indent: indent,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
      );
      buf.writeln('${pad}break;');

    case ContinueStmt(:final pos):
      _line(buf, pos.line, sourcePath);
      _emitLoopExitCleanups(
        buf,
        state,
        sourcePath,
        indent: indent,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
      );
      buf.writeln('${pad}continue;');

    case DeferStmt(:final body):
      // Register at the defer site: earlier exits must not see later defers.
      if (state.deferStack.isEmpty) {
        throw StateError('emit: `defer` outside a block');
      }
      state.deferStack.last.defers.add(body);

    case BlockStmt(:final block):
      _line(buf, block.pos.line, sourcePath);
      buf.writeln('$pad{');
      _emitBlock(
        buf,
        block,
        sourcePath,
        indent: indent + 1,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
      );
      buf.writeln('$pad}');

    case MatchStmt(:final pos):
      _line(buf, pos.line, sourcePath);
      _emitMatchStmt(
        buf,
        stmt,
        sourcePath,
        indent: indent,
        pad: pad,
        bareReturnAsZero: bareReturnAsZero,
        returnCType: returnCType,
        state: state,
      );
  }
}

/// Lowers a `match` statement to an `if`/`else if`/`else` chain. The subject
/// is evaluated once into a fresh temp so patterns with multiple values or
/// ranges don't re-evaluate it — zero runtime overhead beyond a plain `if`.
void _emitMatchStmt(
  StringBuffer buf,
  MatchStmt stmt,
  String sourcePath, {
  required int indent,
  required String pad,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final ctx = _ExprCtx(
    buf: buf,
    sourcePath: sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  final subjectType = stmt.subject.resolvedType!;
  final temp = state.nextValueTemp();
  buf.writeln(
      '$pad${_cDecl(subjectType, temp)} = ${_emitExpr(stmt.subject, ctx)};');
  for (var i = 0; i < stmt.arms.length; i++) {
    final arm = stmt.arms[i];
    final isElse = arm.pattern is ElsePattern;
    final cond = isElse
        ? null
        : _armCond(temp, arm.pattern, arm.when, ctx);
    if (i == 0) {
      buf.writeln(isElse ? '$pad{' : '${pad}if ($cond) {');
    } else {
      buf.writeln(isElse ? '$pad} else {' : '$pad} else if ($cond) {');
    }
    _emitBlock(
      buf,
      arm.body,
      sourcePath,
      indent: indent + 1,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
  }
  buf.writeln('$pad}');
}

/// Lowers a `match` expression's assignment: the subject is evaluated once,
/// then each arm assigns `target` inside its own `if`/`else if`/`else` branch
/// (reusing [_emitValueAssignment] so an arm body may itself be `or {}`/`!`).
void _emitMatchAssign(
  StringBuffer buf, {
  required String target,
  required KlinType targetType,
  required MatchExpr match,
  required String sourcePath,
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final ctx = _ExprCtx(
    buf: buf,
    sourcePath: sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  final pad = '    ' * indent;
  final subjectType = match.subject.resolvedType!;
  final temp = state.nextValueTemp();
  buf.writeln(
      '$pad${_cDecl(subjectType, temp)} = ${_emitExpr(match.subject, ctx)};');
  for (var i = 0; i < match.arms.length; i++) {
    final arm = match.arms[i];
    final isElse = arm.pattern is ElsePattern;
    final cond = isElse
        ? null
        : _armCond(temp, arm.pattern, arm.when, ctx);
    if (i == 0) {
      buf.writeln(isElse ? '$pad{' : '${pad}if ($cond) {');
    } else {
      buf.writeln(isElse ? '$pad} else {' : '$pad} else if ($cond) {');
    }
    _emitValueAssignment(
      buf,
      target: target,
      targetType: targetType,
      value: arm.body,
      sourcePath: sourcePath,
      indent: indent + 1,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
  }
  buf.writeln('$pad}');
}

/// Pattern condition optionally AND-ed with a `when` guard.
String _armCond(
  String temp,
  MatchPattern pattern,
  Expr? when,
  _ExprCtx ctx,
) {
  if (pattern is WildPattern) {
    if (when == null) {
      throw StateError('emit: wildcard pattern needs a `when` guard');
    }
    return '(${_emitExpr(when, ctx)})';
  }
  final patternCond = _patternCond(temp, pattern, ctx);
  if (when == null) return patternCond;
  return '(($patternCond) && (${_emitExpr(when, ctx)}))';
}

String _patternCond(String temp, MatchPattern pattern, _ExprCtx ctx) {
  return switch (pattern) {
    LitPattern(:final values) =>
      values.map((v) => '$temp == ${_emitExpr(v, ctx)}').join(' || '),
    RangePattern(:final start, :final endInclusive) =>
      '($temp >= ${_emitExpr(start, ctx)} && $temp <= ${_emitExpr(endInclusive, ctx)})',
    RelPattern(:final op, :final rhs) =>
      '$temp $op ${_emitExpr(rhs, ctx)}',
    WildPattern() =>
      throw StateError('emit: wildcard pattern needs a `when` guard'),
    ElsePattern() =>
      throw StateError('emit: `else` pattern has no condition'),
  };
}

void _emitFrameCleanups(
  StringBuffer buf,
  _DeferFrame frame,
  String sourcePath, {
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final pad = '    ' * indent;
  for (final body in frame.defers.reversed) {
    _emitStmt(
      buf,
      body,
      sourcePath,
      indent: indent,
      pad: pad,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
  }
}

void _emitExitCleanups(
  StringBuffer buf,
  Iterable<_DeferFrame> frames,
  String sourcePath, {
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  for (final frame in frames.toList().reversed) {
    _emitFrameCleanups(
      buf,
      frame,
      sourcePath,
      indent: indent,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
  }
}

void _emitLoopExitCleanups(
  StringBuffer buf,
  _EmitState state,
  String sourcePath, {
  required int indent,
  required bool bareReturnAsZero,
  required String returnCType,
}) {
  final frames = <_DeferFrame>[];
  for (final frame in state.deferStack.reversed) {
    frames.add(frame);
    if (frame.isLoopBody) break;
  }
  _emitExitCleanups(
    buf,
    frames.reversed,
    sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
}

void _emitElse(
  StringBuffer buf,
  Stmt? elseBranch,
  String sourcePath, {
  required int indent,
  required String pad,
  required bool bareReturnAsZero,
  required String returnCType,
  required _EmitState state,
}) {
  final ctx = _ExprCtx(
    buf: buf,
    sourcePath: sourcePath,
    indent: indent,
    bareReturnAsZero: bareReturnAsZero,
    returnCType: returnCType,
    state: state,
  );
  if (elseBranch == null) {
    buf.writeln('$pad}');
    return;
  }
  if (elseBranch is IfStmt) {
    _line(buf, elseBranch.pos.line, sourcePath);
    buf.writeln('$pad} else if (${_emitExpr(elseBranch.cond, ctx)}) {');
    _emitBlock(
      buf,
      elseBranch.thenBlock,
      sourcePath,
      indent: indent + 1,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
    _emitElse(
      buf,
      elseBranch.elseBranch,
      sourcePath,
      indent: indent,
      pad: pad,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
    return;
  }
  if (elseBranch is BlockStmt) {
    buf.writeln('$pad} else {');
    _emitBlock(
      buf,
      elseBranch.block,
      sourcePath,
      indent: indent + 1,
      bareReturnAsZero: bareReturnAsZero,
      returnCType: returnCType,
      state: state,
    );
    buf.writeln('$pad}');
    return;
  }
  throw StateError('emit: unexpected else branch ${elseBranch.runtimeType}');
}

