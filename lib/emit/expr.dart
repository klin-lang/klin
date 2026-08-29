part of '../emit_c.dart';

bool _exprIsPtrReceiver(Expr expr) {
  var current = expr;
  while (current is GroupExpr) {
    current = current.inner;
  }
  return current is NameExpr && current.isPtrReceiver;
}

String _emitExpr(Expr expr, _ExprCtx ctx) {
  final raw = _emitExprRaw(expr, ctx);
  final from = expr.arrayToSliceFrom;
  if (from != null) {
    final elem = from.elem;
    if (elem is! PrimType) {
      throw StateError(
          'emit: array-to-slice conversion requires a primitive type');
    }
    return '(${_sliceCName(elem)}){ $raw, ${from.len} }';
  }
  return raw;
}

String _emitExprRaw(Expr expr, _ExprCtx ctx) {
  return switch (expr) {
    IntLit(:final lexeme) => _cIntLiteral(lexeme),
    FloatLit(:final lexeme) => lexeme.replaceAll('_', ''),
    BoolLit(:final value) => value ? 'true' : 'false',
    StringLit(:final value) => '"${_escapeC(value)}"',
    NameExpr(:final name, :final resolvedFnCName) =>
      resolvedFnCName ?? name,
    FieldExpr(:final object, :final name, :final enumConstCName) => () {
        if (enumConstCName != null) return enumConstCName;
        final objectType = object.resolvedType;
        if (name == 'len' && objectType is ArrayType) {
          return objectType.len.toString();
        }
        return _exprIsPtrReceiver(object)
            ? '${_emitExpr(object, ctx)}->$name'
            : '${_emitExpr(object, ctx)}.$name';
      }(),
    MethodCallExpr(
      :final receiver,
      :final args,
      :final mangledName,
      :final receiverByRef,
      :final isAssociated,
    ) =>
      () {
        final callee =
            mangledName ?? (throw StateError('emit: method without mangling'));
        final argList = args.map((arg) => _emitExpr(arg, ctx)).join(', ');
        // Associated (static) call `Type.func(...)` — no receiver argument.
        if (isAssociated) return '$callee($argList)';
        final recv = '${receiverByRef ? '&' : ''}${_emitExpr(receiver, ctx)}';
        return args.isEmpty ? '$callee($recv)' : '$callee($recv, $argList)';
      }(),
    StructLitExpr(
      :final resolvedType,
      :final typeName,
      :final namedFields,
      :final positionalFields
    ) =>
      namedFields != null
          ? '(${_cType(resolvedType ?? (throw StateError('emit: literal without type `$typeName`')))}){ ${namedFields.entries.map((entry) => '.${entry.key} = ${_emitExpr(entry.value, ctx)}').join(', ')} }'
          : '(${_cType(resolvedType ?? (throw StateError('emit: literal without type `$typeName`')))}){ ${positionalFields!.map((field) => _emitExpr(field, ctx)).join(', ')} }',
    CallExpr(
      :final callee,
      :final args,
      :final resolvedCallee,
      :final asyncSpawnFn,
    ) =>
      asyncSpawnFn != null
          ? '${resolvedCallee ?? 'eventloop_spawn'}(${_emitExpr(args[0], ctx)}, '
              '${asyncSpawnFn}_poll_erased, ${asyncSpawnFn}_init_erased)'
          : resolvedCallee == '__klin_fmt_write' &&
                  args.length == 2 &&
                  args[1] is InterpolatedStringExpr
              ? _emitInterpWriteExpr(
                  args[0],
                  args[1] as InterpolatedStringExpr,
                  ctx,
                )
              : args.length == 1 && args[0] is InterpolatedStringExpr
                  ? _emitInterpPrintfExpr(
                      args[0] as InterpolatedStringExpr, ctx)
                  : '${resolvedCallee ?? callee}(${args.map((arg) => _emitExpr(arg, ctx)).join(', ')})',
    InterpolatedStringExpr() => throw StateError(
        'emit: interpolated string must be lowered via printf / fmt.write',
      ),
    UnaryExpr(:final op, :final operand) => '$op(${_emitExpr(operand, ctx)})',
    IndexExpr(:final object, :final index) => object.resolvedType is SliceType
        ? '${_emitExpr(object, ctx)}.ptr[${_emitExpr(index, ctx)}]'
        : '${_emitExpr(object, ctx)}[${_emitExpr(index, ctx)}]',
    SliceFromExpr(:final array) => () {
        final type = array.resolvedType;
        if (type is! ArrayType) {
          throw StateError('emit: `[:]` without an array type');
        }
        final elem = type.elem;
        if (elem is! PrimType) {
          throw StateError('emit: slice has a non-primitive element type');
        }
        return '(${_sliceCName(elem)}){ ${_emitExpr(array, ctx)}, ${type.len} }';
      }(),
    ArrayLitExpr(:final elements) =>
      '{ ${elements.map((element) => _emitExpr(element, ctx)).join(', ')} }',
    CastExpr(:final resolvedType, :final expr) => () {
        final target = resolvedType;
        if (target == null) throw StateError('emit: cast without type');
        // Pointer casts round-trip through uintptr_t; enum/integer and
        // numeric casts are a plain C cast (issues 072, 154).
        if (target is PtrType) {
          return '(${_cType(target)})(uintptr_t)(${_emitExpr(expr, ctx)})';
        }
        return '(${_cType(target)})(${_emitExpr(expr, ctx)})';
      }(),
    BinaryExpr(:final left, :final op, :final right) =>
      '(${_emitExpr(left, ctx)} $op ${_emitExpr(right, ctx)})',
    PickExpr(:final cond, :final thenExpr, :final elseExpr) =>
      '(${_emitExpr(cond, ctx)} ? ${_emitExpr(thenExpr, ctx)} : ${_emitExpr(elseExpr, ctx)})',
    GroupExpr(:final inner) => '(${_emitExpr(inner, ctx)})',
    ErrorExpr(:final code, :final resolvedType) => () {
        if (resolvedType is! ResultType) {
          throw StateError('emit: `error` without a result type');
        }
        return '(${_cType(resolvedType)}){ .is_err = true, .u.err = ${_emitExpr(code, ctx)} }';
      }(),
    PropagateExpr(:final result) => () {
        final temp = _emitPropagate(result, ctx);
        return '$temp.u.ok';
      }(),
    AwaitExpr() => throw StateError(
          'emit: `.await` must be lowered inside an async poll function',
        ),
    OrExpr(:final resolvedType) => () {
        final outType = resolvedType;
        if (outType == null) {
          throw StateError('emit: `or` without an expression result type');
        }
        final out = ctx.state.nextValueTemp();
        final pad = '    ' * ctx.indent;
        ctx.buf.writeln('$pad${_cType(outType)} $out;');
        _emitValueAssignment(
          ctx.buf,
          target: out,
          targetType: outType,
          value: expr,
          sourcePath: ctx.sourcePath,
          indent: ctx.indent,
          bareReturnAsZero: ctx.bareReturnAsZero,
          returnCType: ctx.returnCType,
          state: ctx.state,
        );
        return out;
      }(),
    MatchExpr(:final resolvedType) => () {
        final outType = resolvedType;
        if (outType == null) {
          throw StateError('emit: `match` without an expression result type');
        }
        final out = ctx.state.nextValueTemp();
        final pad = '    ' * ctx.indent;
        ctx.buf.writeln('$pad${_cType(outType)} $out;');
        _emitMatchAssign(
          ctx.buf,
          target: out,
          targetType: outType,
          match: expr,
          sourcePath: ctx.sourcePath,
          indent: ctx.indent,
          bareReturnAsZero: ctx.bareReturnAsZero,
          returnCType: ctx.returnCType,
          state: ctx.state,
        );
        return out;
      }(),
  };
}

String _structCName(String module, String name) =>
    module.isEmpty ? name : '${module}_$name';

String _enumCName(String module, String name) =>
    module.isEmpty ? name : '${module}_$name';

/// Emits an integer literal portably. Binary `0b…` and octal `0o…` are not C
/// syntax (`0o` at all; and we avoid C's leading-zero octal), so both are
/// rewritten to `0x…` with the same value; decimal, `0x…`, and character
/// literals `'A'` / `'\n'` pass through. `_` separators are stripped (not in
/// character form).
String _cIntLiteral(String lexeme) {
  if (lexeme.startsWith("'")) return lexeme;
  final s = lexeme.replaceAll('_', '');
  if (s.startsWith('0b') || s.startsWith('0B')) {
    return '0x${BigInt.parse(s.substring(2), radix: 2).toRadixString(16)}';
  }
  if (s.startsWith('0o') || s.startsWith('0O')) {
    return '0x${BigInt.parse(s.substring(2), radix: 8).toRadixString(16)}';
  }
  return s;
}

String _enumConstCName(String module, String name, String variant) =>
    module.isEmpty ? '${name}_$variant' : '${module}_${name}_$variant';

String _freeCName(String module, String name) =>
    module.isEmpty ? name : '${module}_$name';

String _methodCName(String module, String type, String method) =>
    module.isEmpty ? '${type}_$method' : '${module}_${type}_$method';

void _line(StringBuffer buf, int line, String path) {
  buf.writeln('#line $line "${_escapeC(path)}"');
}

String _escapeC(String s) {
  final out = StringBuffer();
  for (final cu in s.runes) {
    switch (cu) {
      case 0x0A: // \n
        out.write('\\n');
      case 0x09: // \t
        out.write('\\t');
      case 0x22: // "
        out.write('\\"');
      case 0x5C: // \
        out.write('\\\\');
      default:
        if (cu < 0x20 || cu == 0x7F) {
          out.write('\\x${cu.toRadixString(16).padLeft(2, '0')}');
        } else {
          out.writeCharCode(cu);
        }
    }
  }
  return out.toString();
}
