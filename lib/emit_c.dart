import 'ast.dart';
import 'type.dart';

part 'emit/analyze.dart';
part 'emit/host.dart';
part 'emit/interp.dart';
part 'emit/types.dart';
part 'emit/stmt.dart';
part 'emit/expr.dart';
part 'emit/async.dart';

/// Emits the AST as one readable .c file with `#line` directives.
String emitC(Program program, String sourcePath) {
  final buf = StringBuffer();
  for (final include in _collectCIncludes(program)) {
    buf.writeln('#include $include');
  }
  buf.writeln('#include <stdint.h>');
  buf.writeln('#include <stddef.h>');
  buf.writeln('#include <stdbool.h>');
  buf.writeln();
  _emitEnums(buf, program, sourcePath);
  _emitStructForwardDecls(buf, program.structs);
  final sliceTypes = <PrimType>{};
  for (final struct in program.structs) {
    for (final field in struct.fields) {
      _collectSliceTypes(field.resolvedType, sliceTypes);
    }
  }
  for (final constant in program.consts) {
    _collectSliceTypes(constant.resolvedType, sliceTypes);
  }
  for (final func in program.funcs) {
    _collectSliceTypes(func.resolvedReturnType, sliceTypes);
    for (final param in func.params) {
      _collectSliceTypes(param.resolvedType, sliceTypes);
    }
    if (func.receiver case final receiver?) {
      _collectSliceTypes(receiver.resolvedType, sliceTypes);
    }
  }
  // `let s = xs[:]` is not on a signature. Without the typedef, `s.ptr` is
  // not a struct member in C.
  _collectSliceTypesInBodies(program, sliceTypes);
  for (final type in sliceTypes) {
    final name = _sliceCName(type);
    buf.writeln(
        'typedef struct { ${type.kind.cType} *ptr; size_t len; } $name;');
  }
  if (sliceTypes.isNotEmpty) buf.writeln();
  final fnTypes = <FnType>{};
  for (final struct in program.structs) {
    for (final field in struct.fields) {
      _collectFnTypes(field.resolvedType, fnTypes);
    }
  }
  for (final func in program.funcs) {
    _collectFnTypes(func.resolvedReturnType, fnTypes);
    for (final param in func.params) {
      _collectFnTypes(param.resolvedType, fnTypes);
    }
  }
  final orderedFnTypes = fnTypes.toList()
    ..sort((a, b) => _fnTypeDepth(a).compareTo(_fnTypeDepth(b)));
  for (final type in orderedFnTypes) {
    final name = _fnTypedefName(type);
    final ps = type.params.isEmpty
        ? 'void'
        : type.params.map(_cType).join(', ');
    buf.writeln('typedef ${_cType(type.ret)} (*$name)($ps);');
  }
  if (orderedFnTypes.isNotEmpty) buf.writeln();
  if (_programNeedsTrimFrac(program)) {
    buf.writeln('#include <stdio.h>');
    buf.writeln('#include <string.h>');
    buf.writeln(
        'static void klin_fmt_trim_frac(char *buf, size_t n, double v, int max_frac) {');
    buf.writeln('    snprintf(buf, n, "%.*f", max_frac, v);');
    buf.writeln('    size_t len = strlen(buf);');
    buf.writeln('    while (len > 0 && buf[len - 1] == \'0\') {');
    buf.writeln('        buf[--len] = \'\\0\';');
    buf.writeln('    }');
    buf.writeln('    if (len > 0 && buf[len - 1] == \'.\') {');
    buf.writeln('        buf[--len] = \'\\0\';');
    buf.writeln('    }');
    buf.writeln('}');
    buf.writeln();
  }
  if (_programNeedsTimeHost(program)) {
    _emitTimeHostHelpers(buf);
  }
  if (_programNeedsFmtHost(program)) {
    _emitFmtHostHelpers(buf);
  }
  _emitStructTypedefs(
    buf,
    program,
    sourcePath,
    program.structs
        .map((s) => '${s.moduleName}.${s.name}')
        .toSet(),
  );
  final resultTypes = <ResultType>{};
  for (final struct in program.structs) {
    for (final field in struct.fields) {
      _collectResultTypes(field.resolvedType, resultTypes);
    }
  }
  for (final func in program.funcs) {
    _collectResultTypes(func.resolvedReturnType, resultTypes);
    for (final param in func.params) {
      _collectResultTypes(param.resolvedType, resultTypes);
    }
    if (func.body != null) {
      _collectResultTypesFromBlock(func.body!, resultTypes);
    }
  }
  for (final type in resultTypes) {
    final ok = _cType(type.ok);
    buf.writeln('typedef struct {');
    buf.writeln('    bool is_err;');
    buf.writeln('    union { $ok ok; int32_t err; } u;');
    buf.writeln('} ${_resultCName(type.ok)};');
    buf.writeln();
  }
  if (_programNeedsMemHost(program)) {
    _emitMemHostHelpers(buf, program);
  }
  _emitConsts(buf, program, sourcePath);
  for (final func in program.funcs) {
    // `@[cheader]` + `@[cimport]`: prototype lives in a C header (`cinclude`).
    if (func.attrs.any((a) => a.name == 'cheader')) continue;
    if (func.isAsync) continue;
    buf.writeln('${_functionHeader(func)};');
  }
  buf.writeln();
  _emitAsyncFunctions(buf, program, sourcePath);
  for (final func in program.funcs) {
    if (func.body == null) continue;
    if (func.isAsync) continue;
    _line(buf, func.pos.line, func.sourcePath ?? sourcePath);
    buf.writeln('${_functionHeader(func)} {');
    _emitBlock(
      buf,
      func.body!,
      func.sourcePath ?? sourcePath,
      indent: 1,
      bareReturnAsZero: func.name == 'main',
      returnCType:
          func.name == 'main' ? 'int' : _cType(func.resolvedReturnType!),
      state: _EmitState(),
    );
    if (func.name == 'main') buf.writeln('    return 0;');
    buf.writeln('}');
    buf.writeln();
  }
  return buf.toString();
}

/// Emits each enum as a portable `typedef <base>; enum { … }` pair (issue 072):
/// the typedef gives a distinct storage type (respecting `: T`) and an anonymous
/// enum supplies integer constants usable in `switch`/comparisons. This avoids
/// C23 `enum E : T` (unsupported by tcc) while keeping zero runtime cost.
void _emitEnums(StringBuffer buf, Program program, String sourcePath) {
  for (final decl in program.enums) {
    _line(buf, decl.pos.line, decl.sourcePath ?? sourcePath);
    final base = decl.baseType ?? const PrimType(PrimKind.i32);
    buf.writeln(
        'typedef ${base.kind.cType} ${_enumCName(decl.moduleName, decl.name)};');
    final parts = <String>[];
    for (final variant in decl.variants) {
      final name = _enumConstCName(decl.moduleName, decl.name, variant.name);
      final value = variant.value;
      if (value is IntLit) {
        parts.add('$name = ${_cIntLiteral(value.lexeme)}');
      } else {
        parts.add(name);
      }
    }
    buf.writeln('enum { ${parts.join(', ')} };');
    buf.writeln();
  }
}

/// `static const` when private, `const` when `pub`. After typedefs so a
/// `[]u8` constant can name `klin_slice_u8`.
void _emitConsts(StringBuffer buf, Program program, String sourcePath) {
  if (program.consts.isEmpty) return;
  for (final decl in program.consts) {
    final type = decl.resolvedType;
    if (type == null) {
      throw StateError('emit: missing type for constant `${decl.name}`');
    }
    _line(buf, decl.pos.line, decl.sourcePath ?? sourcePath);
    final linkage = decl.isPub ? 'const' : 'static const';
    final name = _freeCName(decl.moduleName, decl.name);
    buf.writeln(
      '$linkage ${_cType(type)} $name = ${_emitConstInitializer(decl)};',
    );
  }
  buf.writeln();
}

/// Named tag so a field `next: *Node` is `struct Node *` inside the typedef.
/// An anonymous `typedef struct { Node *next; } Node` is not valid C.
void _writeStructTypedef(StringBuffer buf, StructDecl struct) {
  final cName = _structCName(struct.moduleName, struct.name);
  buf.writeln('typedef struct $cName {');
  for (final field in struct.fields) {
    final type = field.resolvedType;
    if (type == null) {
      throw StateError('emit: missing type for field `${field.name}`');
    }
    buf.writeln('    ${_cDecl(type, field.name)};');
  }
  buf.writeln('} $cName;');
  buf.writeln();
}

/// `struct m_T;` for every struct before any typedef that may spell
/// `struct m_T *` (fn-pointer typedefs, self-referential fields). Without it,
/// `typedef int32_t (*f)(struct m_T *);` declares a new tag scoped to the
/// parameter list — a different type from the later `struct m_T`.
void _emitStructForwardDecls(StringBuffer buf, Iterable<StructDecl> structs) {
  var any = false;
  for (final struct in structs) {
    buf.writeln('struct ${_structCName(struct.moduleName, struct.name)};');
    any = true;
  }
  if (any) buf.writeln();
}

/// Emit `typedef struct` blocks so field dependencies appear before dependents.
/// Shared by [emitC] and [emitH] — declaration order alone breaks nested /
/// cross-module struct fields (C needs the field type typedef first).
void _emitStructTypedefs(
  StringBuffer buf,
  Program program,
  String sourcePath,
  Set<String> structKeys,
) {
  final byKey = <String, StructDecl>{
    for (final s in program.structs) '${s.moduleName}.${s.name}': s,
  };
  final emitted = <String>{};
  while (emitted.length < structKeys.length) {
    var progress = false;
    for (final key in structKeys) {
      if (emitted.contains(key)) continue;
      final struct = byKey[key];
      if (struct == null) continue;
      final fieldDeps = <String>{};
      for (final field in struct.fields) {
        // Pointer fields do not need the pointee complete (self-reference).
        _collectStructKeys(field.resolvedType, fieldDeps, throughPointer: false);
      }
      if (!fieldDeps.every(
          (dep) => !structKeys.contains(dep) || emitted.contains(dep))) {
        continue;
      }
      _line(buf, struct.pos.line, struct.sourcePath ?? sourcePath);
      _writeStructTypedef(buf, struct);
      emitted.add(key);
      progress = true;
    }
    if (!progress) {
      // Cycle or unresolved dep — fall back to declaration order.
      for (final struct in program.structs) {
        final key = '${struct.moduleName}.${struct.name}';
        if (!structKeys.contains(key) || emitted.contains(key)) continue;
        _line(buf, struct.pos.line, struct.sourcePath ?? sourcePath);
        _writeStructTypedef(buf, struct);
        emitted.add(key);
      }
      break;
    }
  }
}

/// Emits a C header with prototypes for `@[cexport]` functions (`--emit-h`).
String emitH(Program program, String sourcePath) {
  final exports =
      program.funcs.where((f) => f.attrs.any((a) => a.name == 'cexport')).toList();
  final guard = _headerGuard(sourcePath);
  final buf = StringBuffer();
  buf.writeln('/* Generated by klin --emit-h — do not edit. */');
  buf.writeln('#ifndef $guard');
  buf.writeln('#define $guard');
  buf.writeln();
  buf.writeln('#include <stdint.h>');
  buf.writeln('#include <stddef.h>');
  buf.writeln('#include <stdbool.h>');
  buf.writeln();
  _emitEnums(buf, program, sourcePath);

  final sliceTypes = <PrimType>{};
  final resultTypes = <ResultType>{};
  final structKeys = <String>{};
  void collectSig(KlinType? type) {
    _collectSliceTypes(type, sliceTypes);
    _collectResultTypes(type, resultTypes);
    _collectStructKeys(type, structKeys);
  }

  for (final func in exports) {
    collectSig(func.resolvedReturnType);
    for (final param in func.params) {
      collectSig(param.resolvedType);
    }
    if (func.receiver case final receiver?) {
      collectSig(receiver.resolvedType);
    }
  }

  // Fixed-point: nested struct fields may add keys (and their deps) later.
  var growing = true;
  while (growing) {
    final before = structKeys.length + sliceTypes.length + resultTypes.length;
    for (final struct in program.structs) {
      final key = '${struct.moduleName}.${struct.name}';
      if (!structKeys.contains(key)) continue;
      for (final field in struct.fields) {
        collectSig(field.resolvedType);
      }
    }
    growing =
        structKeys.length + sliceTypes.length + resultTypes.length > before;
  }

  for (final type in sliceTypes) {
    buf.writeln(
        'typedef struct { ${type.kind.cType} *ptr; size_t len; } ${_sliceCName(type)};');
  }
  if (sliceTypes.isNotEmpty) buf.writeln();

  _emitStructForwardDecls(
    buf,
    program.structs.where(
        (s) => structKeys.contains('${s.moduleName}.${s.name}')),
  );
  _emitStructTypedefs(buf, program, sourcePath, structKeys);

  for (final type in resultTypes) {
    final ok = _cType(type.ok);
    buf.writeln('typedef struct {');
    buf.writeln('    bool is_err;');
    buf.writeln('    union { $ok ok; int32_t err; } u;');
    buf.writeln('} ${_resultCName(type.ok)};');
    buf.writeln();
  }

  for (final func in exports) {
    _line(buf, func.pos.line, func.sourcePath ?? sourcePath);
    buf.writeln('${_functionHeader(func)};');
  }
  if (exports.isNotEmpty) buf.writeln();

  buf.writeln('#endif /* $guard */');
  return buf.toString();
}

