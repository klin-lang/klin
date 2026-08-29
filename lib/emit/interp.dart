part of '../emit_c.dart';

bool _blockNeedsTrimFrac(Block block) {
  for (final stmt in block.stmts) {
    if (_stmtNeedsTrimFrac(stmt)) return true;
  }
  return false;
}

bool _stmtNeedsTrimFrac(Stmt stmt) => switch (stmt) {
      CallStmt(:final args) => args.any(_exprNeedsTrimFrac),
      LetStmt(:final init) => init != null && _exprNeedsTrimFrac(init),
      LetDestructureStmt(:final source) => _exprNeedsTrimFrac(source),
      LetArrayDestructureStmt(:final source) => _exprNeedsTrimFrac(source),
      AssignStmt(:final value) => _exprNeedsTrimFrac(value),
      MultiAssignStmt(:final values) => values.any(_exprNeedsTrimFrac),
      StructAssignStmt(:final source) => _exprNeedsTrimFrac(source),
      ReturnStmt(:final value) => value != null && _exprNeedsTrimFrac(value),
      IfStmt(:final thenBlock, :final elseBranch, :final cond) =>
        _exprNeedsTrimFrac(cond) ||
            _blockNeedsTrimFrac(thenBlock) ||
            (elseBranch != null && _stmtNeedsTrimFrac(elseBranch)),
      WhileStmt(:final body, :final cond) =>
        _exprNeedsTrimFrac(cond) || _blockNeedsTrimFrac(body),
      ForRangeStmt(:final body) => _blockNeedsTrimFrac(body),
      ForCStmt(:final body) => _blockNeedsTrimFrac(body),
      BlockStmt(:final block) => _blockNeedsTrimFrac(block),
      DeferStmt(:final body) => _stmtNeedsTrimFrac(body),
      MethodCallStmt(:final call) => _exprNeedsTrimFrac(call),
      MatchStmt(:final subject, :final arms) => _exprNeedsTrimFrac(subject) ||
          arms.any((arm) =>
              (arm.when != null && _exprNeedsTrimFrac(arm.when!)) ||
              _blockNeedsTrimFrac(arm.body)),
      _ => false,
    };

bool _exprNeedsTrimFrac(Expr expr) => switch (expr) {
      InterpolatedStringExpr(:final parts) => parts.any(
          (p) => p is InterpSlot && p.trimFrac,
        ),
      CallExpr(:final args) => args.any(_exprNeedsTrimFrac),
      BinaryExpr(:final left, :final right) =>
        _exprNeedsTrimFrac(left) || _exprNeedsTrimFrac(right),
      UnaryExpr(:final operand) => _exprNeedsTrimFrac(operand),
      GroupExpr(:final inner) => _exprNeedsTrimFrac(inner),
      MethodCallExpr(:final receiver, :final args) =>
        _exprNeedsTrimFrac(receiver) || args.any(_exprNeedsTrimFrac),
      MatchExpr(:final subject, :final arms) => _exprNeedsTrimFrac(subject) ||
          arms.any((arm) =>
              (arm.when != null && _exprNeedsTrimFrac(arm.when!)) ||
              _exprNeedsTrimFrac(arm.body)),
      PickExpr(:final cond, :final thenExpr, :final elseExpr) =>
          _exprNeedsTrimFrac(cond) ||
          _exprNeedsTrimFrac(thenExpr) ||
          _exprNeedsTrimFrac(elseExpr),
      _ => false,
    };

void _emitInterpPrintf(
  StringBuffer buf,
  InterpolatedStringExpr interp, {
  required int indent,
  required _ExprCtx ctx,
  required _EmitState state,
}) {
  final pad = '    ' * indent;
  final prepared = _prepareInterpPrintf(interp, ctx, state, pad, buf);
  final args = prepared.argExprs.isEmpty
      ? ''
      : ', ${prepared.argExprs.join(', ')}';
  buf.writeln('${pad}printf("${prepared.fmt}"$args);');
}

String _emitInterpPrintfExpr(InterpolatedStringExpr interp, _ExprCtx ctx) {
  // Expression context: declare temps into ctx.buf, return printf(...) as expr.
  final pad = '    ' * ctx.indent;
  final prepared =
      _prepareInterpPrintf(interp, ctx, ctx.state, pad, ctx.buf);
  final args = prepared.argExprs.isEmpty
      ? ''
      : ', ${prepared.argExprs.join(', ')}';
  return 'printf("${prepared.fmt}"$args)';
}

/// `fmt.write(buf[:], "…")` → `snprintf` into the slice; returns length or -1.
String _emitInterpWriteExpr(
  Expr outBuf,
  InterpolatedStringExpr interp,
  _ExprCtx ctx,
) {
  final pad = '    ' * ctx.indent;
  final prepared =
      _prepareInterpPrintf(interp, ctx, ctx.state, pad, ctx.buf);
  final args = prepared.argExprs.isEmpty
      ? ''
      : ', ${prepared.argExprs.join(', ')}';
  final sliceTy = const PrimType(PrimKind.u8);
  final sliceName = ctx.state.nextValueTemp();
  final nName = ctx.state.nextValueTemp();
  ctx.buf.writeln(
    '$pad${_sliceCName(sliceTy)} $sliceName = ${_emitExpr(outBuf, ctx)};',
  );
  ctx.buf.writeln(
    '${pad}int32_t $nName = $sliceName.len <= 0 '
    '? (int32_t)-1 '
    ': snprintf((char *)$sliceName.ptr, (size_t)$sliceName.len, '
    '"${prepared.fmt}"$args);',
  );
  return '($nName < 0 || $nName >= (int32_t)$sliceName.len) '
      '? (int32_t)-1 : $nName';
}

({String fmt, List<String> argExprs}) _prepareInterpPrintf(
  InterpolatedStringExpr interp,
  _ExprCtx ctx,
  _EmitState state,
  String pad,
  StringBuffer buf,
) {
  final fmt = StringBuffer();
  final argExprs = <String>[];
  for (final part in interp.parts) {
    switch (part) {
      case InterpText(:final text):
        // `%` in literal text must be `%%` inside a printf format string.
        fmt.write(_escapeC(text).replaceAll('%', '%%'));
      case InterpSlot(
          :final expr,
          :final printfSpec,
          :final trimFrac,
          :final trimFracDigits
        ):
        if (trimFrac) {
          final name = state.nextInterpBuf();
          buf.writeln('${pad}char $name[64];');
          buf.writeln(
            '${pad}klin_fmt_trim_frac($name, sizeof($name), '
            '(double)(${_emitExpr(expr, ctx)}), $trimFracDigits);',
          );
          fmt.write('%s');
          argExprs.add(name);
        } else {
          fmt.write(printfSpec ?? '%s');
          argExprs.add(_emitExpr(expr, ctx));
        }
    }
  }
  if (interp.appendNewline) {
    fmt.write('\\n');
  }
  return (fmt: fmt.toString(), argExprs: argExprs);
}

