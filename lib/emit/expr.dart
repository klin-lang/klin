part of '../emit_c.dart';

bool _exprIsPtrReceiver(Expr expr) {
  var current = expr;
  while (current is GroupExpr) {
    current = current.inner;
  }
  return current is NameExpr && current.isPtrReceiver;
}

/// Argument for the method's receiver.
///
/// A `mut` receiver parameter is already `T *` in C. Another `mut` call
/// passes that pointer; a by-value call dereferences it. Every other place
/// is a value, so a `mut` call takes its address.
String _emitMethodReceiver(Expr receiver, bool byRef, _ExprCtx ctx) {
  final emitted = _emitExpr(receiver, ctx);
  final alreadyPointer = _exprIsPtrReceiver(receiver);
  if (byRef) return alreadyPointer ? emitted : '&$emitted';
  return alreadyPointer ? '*($emitted)' : emitted;
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
    ByteStringLit(:final value) => _emitByteString(value),
    NameExpr(:final name, :final resolvedFnCName, :final resolvedConstCName) =>
      resolvedConstCName ?? resolvedFnCName ?? name,
    FieldExpr(
      :final object,
      :final name,
      :final enumConstCName,
      :final constCName,
    ) =>
      () {
        if (enumConstCName != null) return enumConstCName;
        if (constCName != null) return constCName;
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
        final recv = _emitMethodReceiver(receiver, receiverByRef, ctx);
        return args.isEmpty ? '$callee($recv)' : '$callee($recv, $argList)';
      }(),
    StructLitExpr(
      :final resolvedType,
      :final typeName,
      :final namedFields,
      :final positionalFields
    ) =>
      namedFields != null
          ? '(${_cType(resolvedType ?? (throw StateError('emit: literal without type `$typeName`')))}){ ${namedFields.entries.map((entry) => '.${entry.key} = ${_emitArrayInit(entry.value, ctx)}').join(', ')} }'
          : '(${_cType(resolvedType ?? (throw StateError('emit: literal without type `$typeName`')))}){ ${positionalFields!.map((field) => _emitArrayInit(field, ctx)).join(', ')} }',
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
    ArrayLitExpr lit => _emitArrayLit(lit, ctx),
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

/// An array literal in expression position is a compound literal
/// (`take([1, 2])` → `take((uint8_t[2]){ 1, 2 })`). A brace list is not
/// an expression. Nested arrays and struct fields stay brace lists,
/// because they initialize an array.
String _emitArrayLit(ArrayLitExpr expr, _ExprCtx ctx, {bool asInitializer = false}) {
  final inner = expr.elements.map((element) {
    if (element is ArrayLitExpr) {
      return _emitArrayLit(element, ctx, asInitializer: true);
    }
    return _emitExpr(element, ctx);
  }).join(', ');
  if (!asInitializer &&
      expr.resolvedType is ArrayType &&
      _arrayElemIsConcrete(expr.resolvedType! as ArrayType)) {
    return '(${_cArraySuffixType(expr.resolvedType! as ArrayType)}){ $inner }';
  }
  return '{ $inner }';
}

/// Struct field: an array literal initializes the member, so it is a brace
/// list. Any other value is an ordinary expression.
String _emitArrayInit(Expr expr, _ExprCtx ctx) {
  if (expr is ArrayLitExpr) return _emitArrayLit(expr, ctx, asInitializer: true);
  return _emitExpr(expr, ctx);
}

/// `uint8_t[2]` or `uint8_t[1][2]` for a compound literal.
String _cArraySuffixType(ArrayType type) {
  final shape = _arrayShape(type);
  return '${_cType(shape.elem)}[${shape.lens.join('][')}]';
}

bool _arrayElemIsConcrete(ArrayType type) {
  KlinType elem = type.elem;
  while (elem is ArrayType) {
    elem = elem.elem;
  }
  return elem is! UntypedInt && elem is! UntypedFloat;
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

/// Brace-initialized so a `[]u8` constant is a real object, not a cast.
///
/// A folded integer expression is the decimal value. A lone literal, or
/// unary `-` / `~` on a literal, keeps its source spelling (`0x4`, `'A'`,
/// `~0`, `-128`) when that spelling is a valid C constant. `i64` minimum
/// and an unsigned value above `2^63-1` use a form gcc accepts. The value
/// is never a C `enum` or `constexpr`.
String _emitConstInitializer(ConstDecl decl) {
  final init = decl.init;
  if (!_constKeepsSourceSpelling(decl)) {
    final value = decl.intValue;
    final type = decl.resolvedType;
    if (value != null && type is PrimType && type.kind.isInteger) {
      return _cConstInt(value, type.kind);
    }
  }
  return switch (init) {
    IntLit(:final lexeme) => _cIntLiteral(lexeme),
    UnaryExpr(:final op, :final operand)
        when (op == '-' || op == '~') && operand is IntLit =>
      '$op${_cIntLiteral(operand.lexeme)}',
    BoolLit(:final value) => value ? 'true' : 'false',
    ByteStringLit(:final value) => () {
        final elem = const PrimType(PrimKind.u8);
        final n = _utf8ByteLength(value);
        return '{ (${elem.kind.cType} *)"${_escapeC(value)}", $n }';
      }(),
    _ => throw StateError('emit: constant initializer is not a literal'),
  };
}

/// `true` when the initializer's source spelling is a legal C constant.
///
/// `18446744073709551615` does not fit in a signed C integer. `-9223372036854775808`
/// is not a single C literal either. `~0` and `-128` stay as written.
bool _constKeepsSourceSpelling(ConstDecl decl) {
  final init = decl.init;
  final value = decl.intValue;
  final type = decl.resolvedType;
  if (init is UnaryExpr &&
      init.op == '~' &&
      init.operand is IntLit) {
    return true;
  }
  if (init is UnaryExpr && init.op == '-' && init.operand is IntLit) {
    if (value != null &&
        type is PrimType &&
        (type.kind == PrimKind.i64 || type.kind == PrimKind.isize) &&
        value == _i64Min) {
      return false;
    }
    return true;
  }
  if (init is IntLit) {
    if (value != null && value > _i64Max) return false;
    return true;
  }
  return init is BoolLit || init is ByteStringLit;
}

final BigInt _i64Max = BigInt.parse('9223372036854775807');
final BigInt _i64Min = -BigInt.parse('9223372036854775808');

/// Decimal C constant for a folded integer. Values that do not fit in a
/// signed 64-bit literal get a suffix or a split form gcc accepts.
String _cConstInt(BigInt value, PrimKind kind) {
  if ((kind == PrimKind.i64 || kind == PrimKind.isize) && value == _i64Min) {
    return '(-9223372036854775807LL - 1)';
  }
  if (value.isNegative) return value.toString();
  if (value > _i64Max) return '${value}ULL';
  return value.toString();
}

/// `b"..."` → `[]u8` over a static C string. `.len` is the byte count and
/// does not include the extra NUL the C compiler appends. An embedded `\0`
/// is part of that count. The pointer is valid for the whole program.
String _emitByteString(String value) {
  final elem = const PrimType(PrimKind.u8);
  final n = _utf8ByteLength(value);
  return '((${_sliceCName(elem)}){ (${elem.kind.cType} *)"${_escapeC(value)}", $n })';
}

/// UTF-8 size of [s]. Matches the bytes `_escapeC` writes into the `.c` file.
int _utf8ByteLength(String s) {
  var n = 0;
  for (final rune in s.runes) {
    if (rune <= 0x7F) {
      n += 1;
    } else if (rune <= 0x7FF) {
      n += 2;
    } else if (rune <= 0xFFFF) {
      n += 3;
    } else {
      n += 4;
    }
  }
  return n;
}

String _escapeC(String s) {
  final out = StringBuffer();
  for (final cu in s.runes) {
    switch (cu) {
      case 0x00:
        // Three octal digits. `\x00` would swallow a following hex digit
        // (`\x00a` is one byte), and a short `\0` would swallow an octal
        // digit. The slice length is emitted separately, never via strlen.
        out.write('\\000');
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
