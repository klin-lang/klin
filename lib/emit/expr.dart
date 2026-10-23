part of '../emit_c.dart';

bool _exprIsPtrReceiver(Expr expr) {
  var current = expr;
  while (current is GroupExpr) {
    current = current.inner;
  }
  return current is NameExpr && current.isPtrReceiver;
}

Expr _peelEmitGroups(Expr expr) {
  var current = expr;
  while (current is GroupExpr) {
    current = current.inner;
  }
  return current;
}

/// A returned `[N]T`: a call, a by-value binding, `pick`, or `match`.
/// A C array variable or literal is not one — those stay C arrays.
bool _exprIsArrayValue(Expr expr) {
  final node = _peelEmitGroups(expr);
  if (node is NameExpr) return node.arrayByValue;
  if (node is CallExpr ||
      node is MethodCallExpr ||
      node is PickExpr ||
      node is MatchExpr) {
    return node.resolvedType is ArrayType;
  }
  return false;
}

/// The C array object. A wrapper value is `expr.v` (the call is evaluated
/// once). A C array is the expression itself.
String _emitArrayObject(Expr expr, _ExprCtx ctx) {
  if (!_exprIsArrayValue(expr)) return _emitExpr(expr, ctx);
  final raw = _emitExpr(expr, ctx);
  final simple = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(raw);
  return simple ? '$raw.v' : '($raw).v';
}

/// Wrapper struct for a `[N]T` value. An array value is already that
/// struct. A literal or a C array is copied into `.v` with no loop and
/// no library call. The checker only allows a stable C array here, so
/// the element list does not evaluate a side-effecting index twice.
String _emitArrayValue(Expr expr, _ExprCtx ctx) {
  if (_exprIsArrayValue(expr)) return _emitExpr(expr, ctx);
  final type = expr.resolvedType;
  if (type is! ArrayType) {
    throw StateError('emit: array value without an array type');
  }
  return '(${_arrayValueCName(type)}){ .v = ${_emitArrayBrace(expr, type, ctx)} }';
}

String _emitArrayBrace(Expr expr, ArrayType type, _ExprCtx ctx) {
  final node = _peelEmitGroups(expr);
  if (node is ArrayLitExpr) {
    return _emitArrayLit(node, ctx, asInitializer: true);
  }
  return _emitArrayElements(_emitArrayObject(node, ctx), type);
}

String _emitArrayElements(String base, ArrayType type) {
  final elem = type.elem;
  if (elem is ArrayType) {
    final parts = [
      for (var i = 0; i < type.len; i++)
        _emitArrayElements('$base[$i]', elem),
    ];
    return '{ ${parts.join(', ')} }';
  }
  final parts = [for (var i = 0; i < type.len; i++) '$base[$i]'];
  return '{ ${parts.join(', ')} }';
}

String _emitCallArg(Expr arg, _ExprCtx ctx) {
  if (arg.arrayToSliceFrom != null) return _emitExpr(arg, ctx);
  if (_exprIsArrayValue(arg)) return _emitArrayObject(arg, ctx);
  return _emitExpr(arg, ctx);
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
    return '(${_sliceCName(from.elem)}){ $raw, ${from.len} }';
  }
  return raw;
}

/// A lone literal, unary `-` / `~` on a literal, and a lone constant name
/// keep their source spelling. A folded operator is the decimal.
bool _foldKeepsSourceSpelling(Expr expr) {
  var node = expr;
  while (node is GroupExpr) {
    node = node.inner;
  }
  if (node is IntLit || node is NameExpr) return true;
  if (node is FieldExpr && node.constCName != null) return true;
  if (node is UnaryExpr && (node.op == '-' || node.op == '~')) {
    var operand = node.operand;
    while (operand is GroupExpr) {
      operand = operand.inner;
    }
    return operand is IntLit;
  }
  return false;
}

String _emitExprRaw(Expr expr, _ExprCtx ctx) {
  final folded = expr.foldedInt;
  final foldedType = expr.resolvedType;
  if (folded != null &&
      foldedType is PrimType &&
      foldedType.kind.isInteger &&
      !_foldKeepsSourceSpelling(expr)) {
    return _cConstInt(folded, foldedType.kind);
  }
  return switch (expr) {
    IntLit lit => _emitIntLit(lit),
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
      :final name,
      :final args,
      :final mangledName,
      :final receiverByRef,
      :final isAssociated,
      :final isFieldCall,
    ) =>
      () {
        final argList = args.map((arg) => _emitCallArg(arg, ctx)).join(', ');
        // `h.cb(1)` — the field is a function pointer. Not a method.
        if (isFieldCall) {
          return '${_emitExpr(receiver, ctx)}.$name($argList)';
        }
        final callee =
            mangledName ?? (throw StateError('emit: method without mangling'));
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
                  : '${resolvedCallee ?? callee}(${args.map((arg) => _emitCallArg(arg, ctx)).join(', ')})',
    InterpolatedStringExpr() => throw StateError(
        'emit: interpolated string must be lowered via printf / fmt.write',
      ),
    UnaryExpr(:final op, :final operand, :final resolvedType) =>
      _emitUnary(op, operand, resolvedType, (inner) => _emitExpr(inner, ctx)),
    IndexExpr(:final object, :final index) => () {
        final indexC = _emitExpr(index, ctx);
        if (object.resolvedType is SliceType) {
          return '${_emitExpr(object, ctx)}.ptr[$indexC]';
        }
        return '${_emitArrayObject(object, ctx)}[$indexC]';
      }(),
    SliceFromExpr(:final array, :final start, :final end) =>
      _emitSliceFrom(array, start, end, ctx),
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
      expr.resolvedType is ArrayType
          ? '(${_emitExpr(cond, ctx)} ? ${_emitArrayValue(thenExpr, ctx)} : ${_emitArrayValue(elseExpr, ctx)})'
          : '(${_emitExpr(cond, ctx)} ? ${_emitExpr(thenExpr, ctx)} : ${_emitExpr(elseExpr, ctx)})',
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
        final outC = outType is ArrayType
            ? _cValueType(outType)
            : _cType(outType);
        ctx.buf.writeln('$pad$outC $out;');
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
  // An empty list is `{ }`, not `{  }` from interpolating nothing.
  final braces = inner.isEmpty ? '{ }' : '{ $inner }';
  if (!asInitializer &&
      expr.resolvedType is ArrayType &&
      _arrayElemIsConcrete(expr.resolvedType! as ArrayType)) {
    return '(${_cArraySuffixType(expr.resolvedType! as ArrayType)})$braces';
  }
  return braces;
}

/// Struct field: an array literal initializes the member, so it is a brace
/// list. A C array place is copied element by element. A call, `pick`, or
/// `match` is stored once, then copied — repeating `(pair()).v[i]` would
/// run the call once per element.
String _emitArrayInit(Expr expr, _ExprCtx ctx) {
  final node = _peelEmitGroups(expr);
  if (node is ArrayLitExpr) {
    return _emitArrayLit(node, ctx, asInitializer: true);
  }
  final type = expr.resolvedType;
  if (type is ArrayType) {
    if (_exprIsArrayValue(expr) && node is! NameExpr) {
      final tmp = ctx.state.nextValueTemp();
      final pad = '    ' * ctx.indent;
      ctx.buf.writeln(
        '$pad${_cValueType(type)} $tmp = ${_emitArrayValue(expr, ctx)};',
      );
      return _emitArrayElements('$tmp.v', type);
    }
    return _emitArrayElements(_emitArrayObject(expr, ctx), type);
  }
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

/// A coerced integer literal in an expression.
///
/// A decimal above `2^63-1` is not a C integer constant (`0x…` already
/// is). An unsigned destination gets the same `ULL` suffix as a folded
/// `const`. Enum constants keep calling [_cIntLiteral] directly: a C
/// `enum` value has to stay an `int` constant.
String _emitIntLit(IntLit lit) {
  final spelling = _cIntLiteral(lit.lexeme);
  if (!_decimalAboveI64Max(spelling)) return spelling;
  final type = lit.resolvedType;
  if (type is PrimType && !_primIsUnsigned(type.kind)) return spelling;
  return '${spelling}ULL';
}

bool _decimalAboveI64Max(String spelling) {
  if (spelling.isEmpty ||
      spelling.startsWith('0x') ||
      spelling.startsWith('0X') ||
      spelling.startsWith("'")) {
    return false;
  }
  final value = BigInt.tryParse(spelling);
  return value != null && value > _i64Max;
}

bool _primIsUnsigned(PrimKind kind) => switch (kind) {
      PrimKind.u8 ||
      PrimKind.u16 ||
      PrimKind.u32 ||
      PrimKind.u64 ||
      PrimKind.usize =>
        true,
      _ => false,
    };

/// `-(9223372036854775808)` is not a portable C constant. `i64` / `isize`
/// minimum uses the same split form as a folded `const`.
String _emitUnary(
  String op,
  Expr operand,
  KlinType? type,
  String Function(Expr) emitOperand,
) {
  if (op == '-' &&
      type is PrimType &&
      (type.kind == PrimKind.i64 || type.kind == PrimKind.isize)) {
    var node = operand;
    while (node is GroupExpr) {
      node = node.inner;
    }
    if (node is IntLit) {
      final mag = _intLitMagnitude(node.lexeme);
      if (mag != null && mag == -_i64Min) {
        return '(-9223372036854775807LL - 1)';
      }
    }
  }
  return '$op(${emitOperand(operand)})';
}

BigInt? _intLitMagnitude(String lexeme) {
  if (lexeme.startsWith("'")) return null;
  final s = lexeme.replaceAll('_', '');
  if (s.startsWith('0b') || s.startsWith('0B')) {
    return BigInt.tryParse(s.substring(2), radix: 2);
  }
  if (s.startsWith('0o') || s.startsWith('0O')) {
    return BigInt.tryParse(s.substring(2), radix: 8);
  }
  if (s.startsWith('0x') || s.startsWith('0X')) {
    return BigInt.tryParse(s.substring(2), radix: 16);
  }
  return BigInt.tryParse(s);
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

/// `xs[a:b]` / `xs[a:]` / `xs[:b]` / `xs[:]`. No bounds check (D15).
/// An array is used once as the pointer base; its length is the constant
/// `N`. A slice that is not a plain place is stored once when both `.ptr`
/// and `.len` are read (`s[a:]`, `s[:]`).
String _emitSliceFrom(Expr array, Expr? start, Expr? end, _ExprCtx ctx) {
  final type = array.resolvedType;
  if (type is ArrayType) {
    final base = _emitArrayObject(array, ctx);
    final ptr = start == null
        ? base
        : '($base) + (size_t)(${_emitExpr(start, ctx)})';
    final len = _sliceRangeLen('${type.len}', start, end, ctx);
    return '(${_sliceCName(type.elem)}){ $ptr, $len }';
  }
  if (type is! SliceType) {
    throw StateError('emit: slice range without an array or slice');
  }
  // End omitted means the length comes from the header, so both fields
  // are read. A call must not run twice.
  final needsLen = end == null;
  final String src;
  if (needsLen && !_exprIsSimplePlace(array)) {
    final tmp = ctx.state.nextValueTemp();
    final pad = '    ' * ctx.indent;
    ctx.buf.writeln('$pad${_cType(type)} $tmp = ${_emitExpr(array, ctx)};');
    src = tmp;
  } else {
    final raw = _emitExpr(array, ctx);
    src = _exprIsSimplePlace(array) ? raw : '($raw)';
  }
  final ptr = start == null
      ? '$src.ptr'
      : '($src.ptr) + (size_t)(${_emitExpr(start, ctx)})';
  final len = _sliceRangeLen('$src.len', start, end, ctx);
  return '(${_sliceCName(type.elem)}){ $ptr, $len }';
}

/// Length of a subslice. Each bound is converted to `size_t` before the
/// subtraction so the header field stays `size_t`. A negative bound or
/// `a > b` is undefined behavior, not a check.
String _sliceRangeLen(String full, Expr? start, Expr? end, _ExprCtx ctx) {
  if (start == null && end == null) return full;
  if (start == null) return '(size_t)(${_emitExpr(end!, ctx)})';
  if (end == null) {
    return '(($full) - (size_t)(${_emitExpr(start, ctx)}))';
  }
  return '((size_t)(${_emitExpr(end, ctx)}) - (size_t)(${_emitExpr(start, ctx)}))';
}

/// A name, or a field / index / dereference of one. Reading it twice does
/// not call a function. Anything else is stored in a temporary.
bool _exprIsSimplePlace(Expr expr) {
  final node = _peelEmitGroups(expr);
  return switch (node) {
    NameExpr() => true,
    FieldExpr(:final object) => _exprIsSimplePlace(object),
    IndexExpr(:final object, :final index) =>
      _exprIsSimplePlace(object) && _exprIsSimplePlace(index),
    UnaryExpr(:final op, :final operand) when op == '*' =>
      _exprIsSimplePlace(operand),
    _ => false,
  };
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
