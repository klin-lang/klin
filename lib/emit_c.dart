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
  _sliceTailElems.clear();
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
  final sliceTypes = <KlinType>{};
  for (final struct in program.structs) {
    for (final field in struct.fields) {
      _collectSliceTypes(field.resolvedType, sliceTypes);
    }
  }
  for (final constant in program.consts) {
    _collectSliceTypes(constant.resolvedType, sliceTypes);
  }
  for (final global in program.globals) {
    _collectSliceTypes(global.resolvedType, sliceTypes);
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
  // Primitive / struct / enum / str / pointer / nested-slice elements.
  // A struct element is `struct Tag *`, so the body can come later.
  // `[]*mut [N]Token` is `struct Token (**ptr)[N]` and waits for the body.
  // A slice of a function pointer waits until that typedef exists.
  _emitSliceTypedefs(
    buf,
    sliceTypes.where((elem) =>
        !_sliceElemNeedsFn(elem) && !_sliceNeedsCompleteStruct(elem)),
  );
  final arrayReturns = _arrayReturnTypes(program);
  // Primitive (and pointer / enum / slice) elements do not need a struct
  // to be complete. `[N]*mut [M]Token` does, so it waits. Function-pointer
  // typedefs that return the early wrappers come next.
  _emitArrayReturnTypedefs(
    buf,
    arrayReturns.where((type) {
      final elem = _arrayShape(type).elem;
      return elem is! FnType && !_arrayReturnAfterStruct(type);
    }),
  );
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
  // `let s = fs[:]` where `fs` is `[N]fn(...)` is not on a signature.
  // The slice typedef names the function typedef.
  for (final elem in sliceTypes) {
    _collectFnTypes(elem, fnTypes);
  }
  for (final global in program.globals) {
    _collectFnTypes(global.resolvedType, fnTypes);
  }
  final orderedFnTypes = fnTypes.toList()
    ..sort((a, b) => _fnTypeDepth(a).compareTo(_fnTypeDepth(b)));
  final earlyFnTypes =
      orderedFnTypes.where((type) => !_fnNeedsCompleteStruct(type)).toList();
  final lateFnTypes = orderedFnTypes.where(_fnNeedsCompleteStruct).toList();
  _emitFnTypedefs(buf, earlyFnTypes);
  // `[]fn(i32): i32` names the function typedef. Emit it before any
  // struct that stores that slice. A slice that needs an array of structs
  // waits until those structs are complete.
  _emitSliceTypedefs(
    buf,
    sliceTypes.where((elem) =>
        _sliceElemNeedsFn(elem) && !_sliceNeedsCompleteStruct(elem)),
  );
  // `[N]fn(): …` needs the function typedef first, unless that typedef
  // itself waits for a struct body.
  _emitArrayReturnTypedefs(
    buf,
    arrayReturns.where((type) {
      final elem = _arrayShape(type).elem;
      return elem is FnType && !_arrayReturnAfterLateFn(type);
    }),
  );
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
    program.structs.map((s) => '${s.moduleName}.${s.name}').toSet(),
  );
  // `[]*mut [N]Token`, `[N]Token`, `fn(): *mut [N]Token`, and the slices
  // and wrappers that name those typedefs. After the struct bodies.
  _emitLateStructTypedefs(buf, sliceTypes, lateFnTypes, arrayReturns);
  // After every slice typedef. `s[a:]` on a call is this helper, not a
  // statement temporary: a `while` condition must evaluate the call each
  // time it is checked.
  _emitSliceTailHelpers(buf);
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
  for (final global in program.globals) {
    _collectResultTypes(global.resolvedType, resultTypes);
  }
  for (final type in resultTypes) {
    final ok = _resultOkField(type.ok);
    buf.writeln('typedef struct {');
    buf.writeln('    bool is_err;');
    buf.writeln('    union { $ok; int32_t err; } u;');
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
  // After prototypes so a function-pointer initializer can name one, and
  // after typedefs so a struct or slice global names a complete type.
  _emitGlobals(buf, program, sourcePath);
  _emitAsyncFunctions(buf, program, sourcePath);
  for (final func in program.funcs) {
    if (func.body == null) continue;
    if (func.isAsync) continue;
    _line(buf, func.pos.line, func.sourcePath ?? sourcePath);
    buf.writeln('${_functionHeader(func)} {');
    if (func.name == 'main' && func.params.isNotEmpty) {
      final param = func.params.single;
      final host = _mainHostNames(func);
      // `char **` is not `const char **`. One cast; no copy of the strings.
      buf.writeln(
        '    ${_sliceCName(const StrType())} ${param.name} = '
        '{ (const char **)${host.argv}, (size_t)${host.argc} };',
      );
    }
    _emitBlock(
      buf,
      func.body!,
      func.sourcePath ?? sourcePath,
      indent: 1,
      bareReturnAsZero: func.name == 'main',
      returnCType:
          func.name == 'main' ? 'int' : _cValueType(func.resolvedReturnType!),
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

/// Private globals are `static`. `pub` has no `static` — every module is one
/// `.c`, and the checker rejects a cross-module use of a private name.
///
/// Each global is declared before any initializer so a global can name one
/// that appears later in the source (`let mut p: *mut i32 = &n` above `n`).
void _emitGlobals(StringBuffer buf, Program program, String sourcePath) {
  if (program.globals.isEmpty) return;
  for (final decl in program.globals) {
    final type = decl.resolvedType;
    if (type == null) {
      throw StateError('emit: missing type for global `${decl.name}`');
    }
    final name = _freeCName(decl.moduleName, decl.name);
    buf.writeln('${_globalLinkage(decl)}${_cDecl(type, name)};');
  }
  for (final decl in program.globals) {
    final type = decl.resolvedType!;
    _line(buf, decl.pos.line, decl.sourcePath ?? sourcePath);
    final name = _freeCName(decl.moduleName, decl.name);
    final init = decl.init == null
        ? _globalZero(type)
        : _emitGlobalExpr(program, decl.init!);
    buf.writeln('${_globalLinkage(decl)}${_cDecl(type, name)} = $init;');
  }
  buf.writeln();
}

String _globalLinkage(GlobalDecl decl) => decl.isPub ? '' : 'static ';

/// Zero-initialization. The same values a local without an initializer gets.
String _globalZero(KlinType type) => switch (type) {
      PrimType(:final kind) => kind.cZero,
      PtrType() => 'NULL',
      // `NULL` is `void *`. ISO C does not convert that to a function
      // pointer, and `gcc -std=c11 -pedantic-errors` rejects it. `0` is a
      // null pointer constant of any pointer type.
      FnType() => '0',
      ArrayType() => '{0}',
      SliceType() => '{ NULL, 0 }',
      StructType() => '{0}',
      EnumType() => '0',
      StrType() => 'NULL',
      _ => throw StateError(
          'emit: no zero value for global `${type.displayName}`',
        ),
    };

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
        _collectStructKeys(field.resolvedType, fieldDeps,
            throughPointer: false);
      }
      if (!fieldDeps
          .every((dep) => !structKeys.contains(dep) || emitted.contains(dep))) {
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
  final exports = program.funcs
      .where((f) => f.attrs.any((a) => a.name == 'cexport'))
      .toList();
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

  final sliceTypes = <KlinType>{};
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

  // The slice pointer field spells `struct Tag *` for a struct element.
  // The tag has to be in scope before that typedef.
  _emitStructForwardDecls(
    buf,
    program.structs
        .where((s) => structKeys.contains('${s.moduleName}.${s.name}')),
  );
  final fnTypes = <FnType>{};
  for (final elem in sliceTypes) {
    _collectFnTypes(elem, fnTypes);
  }
  final orderedFn = fnTypes.toList()
    ..sort((a, b) => _fnTypeDepth(a).compareTo(_fnTypeDepth(b)));
  _emitSliceTypedefs(
    buf,
    sliceTypes.where((elem) =>
        !_sliceElemNeedsFn(elem) && !_sliceNeedsCompleteStruct(elem)),
  );
  _emitFnTypedefs(
    buf,
    orderedFn.where((type) => !_fnNeedsCompleteStruct(type)).toList(),
  );
  _emitSliceTypedefs(
    buf,
    sliceTypes.where((elem) =>
        _sliceElemNeedsFn(elem) && !_sliceNeedsCompleteStruct(elem)),
  );
  _emitStructTypedefs(buf, program, sourcePath, structKeys);
  _emitLateStructTypedefs(
    buf,
    sliceTypes,
    orderedFn.where(_fnNeedsCompleteStruct).toList(),
    const <ArrayType>{},
  );

  for (final type in resultTypes) {
    final ok = _resultOkField(type.ok);
    buf.writeln('typedef struct {');
    buf.writeln('    bool is_err;');
    buf.writeln('    union { $ok; int32_t err; } u;');
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
