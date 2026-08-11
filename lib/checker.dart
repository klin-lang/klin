import 'ast.dart';
import 'token.dart';
import 'type.dart';

final class CheckError implements Exception {
  final String message;
  final SourcePos pos;

  /// File where the error was raised, when known (e.g. during function body
  /// check). Null for registration / single-unit errors without a path.
  final String? path;

  const CheckError(this.message, this.pos, {this.path});

  @override
  String toString() {
    final p = path;
    if (p == null || p.isEmpty) return '${pos.line}:${pos.col}: $message';
    return '$p:${pos.line}:${pos.col}: $message';
  }
}

/// Multiple [CheckError]s collected when [Checker.check] runs with
/// `collectErrors: true` (Language Server).
final class CheckErrors implements Exception {
  final List<CheckError> errors;

  const CheckErrors(this.errors);

  @override
  String toString() => errors.map((e) => e.toString()).join('\n');
}

/// Parses Klin integer lexemes used in array lengths: decimal / `0x` / `0b` /
/// `0o` / character `'A'` / `'\n'`. Returns null if invalid.
int? _parseIntLiteralValue(String lexeme) {
  if (lexeme.startsWith("'") && lexeme.endsWith("'") && lexeme.length >= 3) {
    final inner = lexeme.substring(1, lexeme.length - 1);
    if (inner.startsWith('\\') && inner.length == 2) {
      return switch (inner[1]) {
        'n' => 0x0A,
        't' => 0x09,
        '0' => 0x00,
        '\\' => 0x5C,
        "'" => 0x27,
        _ => null,
      };
    }
    if (inner.length == 1) return inner.codeUnitAt(0);
    return null;
  }
  final isHex = lexeme.startsWith('0x') || lexeme.startsWith('0X');
  final isBin = lexeme.startsWith('0b') || lexeme.startsWith('0B');
  final isOct = lexeme.startsWith('0o') || lexeme.startsWith('0O');
  return int.tryParse(
    isHex || isBin || isOct ? lexeme.substring(2) : lexeme,
    radix: isHex
        ? 16
        : isBin
            ? 2
            : isOct
                ? 8
                : 10,
  );
}

/// Index of the `]` that closes `[LEN]` in a type name. Character lengths
/// (`']'`, `'\''`) must not use a naive `indexOf(']')`.
int? _arrayTypeCloseBracket(String name) {
  if (!name.startsWith('[') || name.length < 3) return null;
  var i = 1;
  if (name[i] == "'") {
    i++; // opening '
    if (i >= name.length) return null;
    if (name[i] == '\\') {
      i += 2; // \ + escape letter
    } else {
      i++; // one char
    }
    if (i >= name.length || name[i] != "'") return null;
    i++; // closing '
  } else {
    while (i < name.length && name[i] != ']') {
      i++;
    }
  }
  if (i >= name.length || name[i] != ']') return null;
  return i;
}

final class _Symbol {
  final String name;
  final KlinType type;
  final bool isMut;
  final SourcePos pos;

  /// A mut method receiver becomes a pointer parameter (`T *`) in C.
  final bool isPtrReceiver;

  const _Symbol({
    required this.name,
    required this.type,
    required this.isMut,
    required this.pos,
    this.isPtrReceiver = false,
  });
}

final class _Scope {
  final _Scope? parent;
  final Map<String, _Symbol> _symbols = {};

  _Scope(this.parent);

  void define(_Symbol symbol) {
    if (_symbols.containsKey(symbol.name)) {
      throw CheckError(
        'redeclaration of `${symbol.name}` in the same scope',
        symbol.pos,
      );
    }
    _symbols[symbol.name] = symbol;
  }

  _Symbol? lookup(String name) {
    final local = _symbols[name];
    if (local != null) return local;
    return parent?.lookup(name);
  }
}

final class _FuncSignature {
  final List<KlinType> paramTypes;
  final KlinType returnType;
  final SourcePos pos;
  final bool isMutReceiver;
  final bool isPub;
  final bool isAsync;

  const _FuncSignature({
    required this.paramTypes,
    required this.returnType,
    required this.pos,
    this.isMutReceiver = false,
    this.isPub = false,
    this.isAsync = false,
  });
}

final class _CheckedCall {
  final KlinType type;
  final String? cName;
  final bool isAsync;
  final ResolvedDef? def;

  const _CheckedCall(this.type, this.cName, {this.isAsync = false, this.def});
}

/// Symbol table and type checker. Mutates `resolvedType` on AST nodes.
final class Checker {
  _Scope _scope = _Scope(null);
  int _loopDepth = 0;
  int _deferDepth = 0;
  final Map<String, _FuncSignature> _functions = {};
  final Map<String, StructDecl> _structs = {};
  final Map<String, EnumDecl> _enums = {};
  final Map<String, _FuncSignature> _methods = {};
  final Map<String, _FuncSignature> _assocFuncs = {};
  final List<FuncDecl> _allFunctions = [];
  Map<String, Map<String, String>> _importAliases = {};
  KlinType _currentReturn = const VoidType();
  String _currentFunction = '';
  String _currentModule = '';
  String? _currentSourcePath;
  bool _currentIsAsync = false;

  /// Names already reserved in the flat async state struct (params + lets).
  final Set<String> _asyncFlatNames = {};

  /// `match` as an expression is only valid as a `let` initializer or an
  /// assignment right-hand side (it lowers to statements in emission).
  bool _allowMatchExpr = false;

  /// Type-checks [program].
  ///
  /// When [requireMain] is true (CLI / `klin run` default), the program must
  /// contain exactly one parameterless `main`. Language Server analysis of
  /// library modules passes `false` so editing stdlib / packages does not
  /// report a spurious missing-`main` error (issue 086).
  ///
  /// When [collectErrors] is true, body-check failures are gathered per
  /// function and thrown together as [CheckErrors] (registration / `main`
  /// rules still fail fast as a single [CheckError]).
  void check(
    Program program, {
    bool requireMain = true,
    bool collectErrors = false,
  }) {
    _functions.clear();
    _structs.clear();
    _enums.clear();
    _methods.clear();
    _assocFuncs.clear();
    _allFunctions
      ..clear()
      ..addAll(program.funcs);
    _importAliases = program.importAliases;
    _checkAttrs(program);
    _registerStructs(program);
    _registerEnums(program);
    _registerFunctions(program);
    final main = program.funcs
        .where((func) =>
            func.receiver == null &&
            func.associatedType == null &&
            func.name == 'main')
        .toList();
    if (requireMain) {
      if (main.isEmpty) {
        throw CheckError('missing required `main` function', program.pos);
      }
      if (main.length != 1) {
        throw CheckError(
            'a project can contain only one `main` function', main[1].pos);
      }
      if (main.single.params.isNotEmpty) {
        throw CheckError(
            '`main` function cannot have parameters', main.single.pos);
      }
    } else if (main.length > 1) {
      throw CheckError(
          'a project can contain only one `main` function', main[1].pos);
    } else if (main.length == 1 && main.single.params.isNotEmpty) {
      throw CheckError(
          '`main` function cannot have parameters', main.single.pos);
    }

    final collected = <CheckError>[];
    for (final func in program.funcs) {
      if (_hasAttr(func.attrs, 'cimport')) continue;
      try {
        _checkFuncBody(func);
      } on CheckError catch (e) {
        if (!collectErrors) rethrow;
        collected.add(
          e.path != null
              ? e
              : CheckError(e.message, e.pos, path: _currentSourcePath),
        );
      }
    }
    if (collected.isNotEmpty) {
      throw CheckErrors(collected);
    }
  }

  void _checkFuncBody(FuncDecl func) {
    // Set before any early throw so collectErrors attributes the right file.
    _currentSourcePath = func.sourcePath;
    if (func.isAsync && func.name == 'main') {
      throw CheckError(
        '`main` cannot be `async`',
        func.pos,
        path: func.sourcePath,
      );
    }
    _scope = _Scope(null);
    _loopDepth = 0;
    _deferDepth = 0;
    _currentFunction = func.name;
    _currentModule = func.moduleName;
    _currentIsAsync = func.isAsync;
    _currentReturn = func.resolvedReturnType!;
    _asyncFlatNames
      ..clear()
      ..addAll(func.params.map((p) => p.name));
    final receiver = func.receiver;
    if (receiver != null) {
      _asyncFlatNames.add(receiver.name);
      _scope.define(
        _Symbol(
          name: receiver.name,
          type: receiver.resolvedType!,
          isMut: receiver.isMut,
          pos: receiver.pos,
          isPtrReceiver: receiver.isMut,
        ),
      );
    }
    for (final param in func.params) {
      _scope.define(
        _Symbol(
          name: param.name,
          type: param.resolvedType!,
          isMut: false,
          pos: param.pos,
        ),
      );
    }
    _checkBlock(func.body!);
    if (func.name != 'main' &&
        _currentReturn is! VoidType &&
        !_returnsOnAllPaths(func.body!)) {
      throw CheckError(
        'function `${func.name}` must return a value on all paths',
        func.pos,
      );
    }
  }

  void _checkAttrs(Program program) {
    final cNames = <String>{};
    for (final decl in [...program.structs, ...program.funcs]) {
      final attrs = switch (decl) {
        StructDecl(:final attrs) => attrs,
        FuncDecl(:final attrs) => attrs,
        _ => throw StateError('unknown declaration'),
      };
      for (final attr in attrs) {
        if (!{
          'codename',
          'cimport',
          'cexport',
          'cinclude',
          'link',
          'cheader',
          'isr',
        }.contains(attr.name)) {
          throw CheckError('unknown attribute `${attr.name}`', attr.pos);
        }
        final needsArg = attr.name == 'codename' ||
            attr.name == 'cinclude' ||
            attr.name == 'link';
        if (needsArg && attr.arg == null) {
          throw CheckError(
              'attribute `${attr.name}` requires a string', attr.pos);
        }
        if ((attr.name == 'cimport' ||
                attr.name == 'cheader' ||
                attr.name == 'cexport') &&
            attr.arg != null) {
          throw CheckError(
              '`${attr.name}` attribute does not accept an argument', attr.pos);
        }
        if (attr.name == 'codename' && !cNames.add(attr.arg!)) {
          throw CheckError('duplicate codename `${attr.arg}`', attr.pos);
        }
      }
      if (decl is StructDecl && _hasAttr(attrs, 'cimport')) {
        throw CheckError('`cimport` is allowed only on functions', decl.pos);
      }
      if (decl is StructDecl && _hasAttr(attrs, 'cheader')) {
        throw CheckError('`cheader` is allowed only on functions', decl.pos);
      }
      if (decl is StructDecl && _hasAttr(attrs, 'cexport')) {
        throw CheckError('`cexport` is allowed only on functions', decl.pos);
      }
      if (decl is StructDecl && _hasAttr(attrs, 'isr')) {
        throw CheckError('`isr` is allowed only on functions', decl.pos);
      }
      if (decl is FuncDecl) {
        final imported = _hasAttr(attrs, 'cimport');
        final exported = _hasAttr(attrs, 'cexport');
        final fromHeader = _hasAttr(attrs, 'cheader');
        final hasCodename = _hasAttr(attrs, 'codename');
        final isrAttr = _attrNamed(attrs, 'isr');
        final isIsr = isrAttr != null;
        if (fromHeader && !imported) {
          throw CheckError(
              '`cheader` requires `cimport` (declaration comes from a C header)',
              decl.pos);
        }
        if (imported && exported) {
          throw CheckError(
              'cannot combine `cimport` and `cexport`', decl.pos);
        }
        if (exported && decl.name == 'main') {
          throw CheckError(
              '`cexport` cannot be applied to `main` '
              '(entry point is always emitted as C `main`)',
              decl.pos);
        }
        if (exported && !hasCodename) {
          throw CheckError(
              '`cexport` requires `codename("…")` (stable C symbol name)',
              decl.pos);
        }
        if (exported && decl.body == null) {
          throw CheckError('`cexport` function requires a body', decl.pos);
        }
        if (imported && decl.body != null) {
          throw CheckError('`cimport` function cannot have a body', decl.pos);
        }
        if (!imported && decl.body == null) {
          throw CheckError(
              'function without `cimport` requires a body', decl.pos);
        }
        if (isIsr) {
          if (imported) {
            throw CheckError('cannot combine `isr` and `cimport`', decl.pos);
          }
          if (exported) {
            throw CheckError('cannot combine `isr` and `cexport`', decl.pos);
          }
          if (decl.name == 'main') {
            throw CheckError('`isr` cannot be applied to `main`', decl.pos);
          }
          if (decl.isAsync) {
            throw CheckError('`isr` cannot be applied to `async fn`', decl.pos);
          }
          if (decl.receiver != null || decl.associatedType != null) {
            throw CheckError(
                '`isr` is allowed only on free functions '
                '(not methods / associated functions)',
                decl.pos);
          }
          if (decl.body == null) {
            throw CheckError('`isr` function requires a body', decl.pos);
          }
          if (decl.params.isNotEmpty) {
            throw CheckError(
                '`isr` handler must take no parameters '
                '(vector ABI; match startup `.s`)',
                decl.pos);
          }
          if (decl.returnTypeName != null && decl.returnTypeName != 'void') {
            throw CheckError(
                '`isr` handler must return void (or omit the return type)',
                decl.pos);
          }
          final nameFromIsr = isrAttr.arg;
          final nameFromCode = _attrNamed(attrs, 'codename')?.arg;
          if (nameFromIsr == null && nameFromCode == null) {
            throw CheckError(
                '`isr` requires `isr("Vector_Handler")` or '
                '`@[isr, codename("Vector_Handler")]`',
                isrAttr.pos);
          }
          if (nameFromIsr != null &&
              nameFromCode != null &&
              nameFromIsr != nameFromCode) {
            throw CheckError(
                '`isr("${nameFromIsr}")` conflicts with '
                '`codename("${nameFromCode}")`',
                isrAttr.pos);
          }
          // `@[isr("…")]` sugar → synthesize `codename` for emission.
          if (nameFromIsr != null && nameFromCode == null) {
            if (!cNames.add(nameFromIsr)) {
              throw CheckError('duplicate codename `$nameFromIsr`', isrAttr.pos);
            }
            attrs.add(Attr('codename', nameFromIsr, isrAttr.pos));
          }
        }
      }
    }
  }

  bool _hasAttr(List<Attr> attrs, String name) =>
      attrs.any((attr) => attr.name == name);

  Attr? _attrNamed(List<Attr> attrs, String name) {
    for (final attr in attrs) {
      if (attr.name == name) return attr;
    }
    return null;
  }

  void _registerFunctions(Program program) {
    for (final func in program.funcs) {
      _currentModule = func.moduleName;
      final String key;
      final Map<String, _FuncSignature> collection;
      if (func.receiver != null) {
        final receiverType =
            _resolveType(func.receiver!.typeName, func.receiver!.pos);
        key = '${receiverType.displayName}.${func.name}';
        collection = _methods;
        if (_assocFuncs.containsKey(key)) {
          throw CheckError(
            'method `${receiverType.displayName}.${func.name}` conflicts with '
            'an associated function of the same C name',
            func.pos,
          );
        }
        _rejectEnumVariantCNameClash(
          receiverType,
          func.name,
          func.pos,
          'method',
        );
      } else if (func.associatedType != null) {
        final assocType = _resolveType(func.associatedType!, func.pos);
        if (assocType is! StructType && assocType is! EnumType) {
          throw CheckError(
              'associated function type must be a struct or enum', func.pos);
        }
        key = '${assocType.displayName}.${func.name}';
        collection = _assocFuncs;
        if (_methods.containsKey(key)) {
          throw CheckError(
            'associated function `${assocType.displayName}.${func.name}` '
            'conflicts with a method of the same C name',
            func.pos,
          );
        }
        _rejectEnumVariantCNameClash(
          assocType,
          func.name,
          func.pos,
          'associated function',
        );
      } else {
        key = _key(func.moduleName, func.name);
        collection = _functions;
      }
      if (collection.containsKey(key)) {
        throw CheckError('redeclaration of function `${func.name}`', func.pos);
      }
      final params = <KlinType>[];
      final paramNames = <String>{};
      for (final param in func.params) {
        if (!paramNames.add(param.name)) {
          throw CheckError(
            'redeclaration of parameter `${param.name}`',
            param.pos,
          );
        }
        final type = _resolveType(param.typeName, param.pos);
        param.resolvedType = type;
        params.add(type);
      }
      final returnType = switch (func.returnTypeName) {
        null || 'void' => const VoidType(),
        final name => _resolveType(name, func.pos),
      };
      if (returnType is ArrayType) {
        throw CheckError(
          'function cannot return an array (use slice `[]T`)',
          func.pos,
        );
      }
      func.resolvedReturnType = returnType;
      final receiver = func.receiver;
      if (receiver != null) {
        final receiverType = _resolveType(receiver.typeName, receiver.pos);
        if (receiverType is! StructType && receiverType is! EnumType) {
          throw CheckError(
              'method receiver must be a struct or enum', receiver.pos);
        }
        receiver.resolvedType = receiverType;
      }
      collection[key] = _FuncSignature(
        paramTypes: params,
        returnType: returnType,
        pos: func.pos,
        isMutReceiver: receiver?.isMut ?? false,
        isPub: func.isPub,
        isAsync: func.isAsync,
      );
    }
  }

  void _registerStructs(Program program) {
    for (final struct in program.structs) {
      final key = _key(struct.moduleName, struct.name);
      if (_structs.containsKey(key)) {
        throw CheckError(
            'redeclaration of struct `${struct.name}`', struct.pos);
      }
      _structs[key] = struct;
    }
    for (final struct in program.structs) {
      _currentModule = struct.moduleName;
      final names = <String>{};
      for (final field in struct.fields) {
        if (!names.add(field.name)) {
          throw CheckError('duplicate field `${field.name}`', field.pos);
        }
        field.resolvedType = _resolveType(field.typeName, field.pos);
      }
    }
  }

  void _registerEnums(Program program) {
    for (final decl in program.enums) {
      final key = _key(decl.moduleName, decl.name);
      if (_enums.containsKey(key) || _structs.containsKey(key)) {
        throw CheckError('redeclaration of type `${decl.name}`', decl.pos);
      }
      _enums[key] = decl;
    }
    for (final decl in program.enums) {
      _currentModule = decl.moduleName;
      final base = decl.baseTypeName == null
          ? const PrimType(PrimKind.i32)
          : _resolveType(decl.baseTypeName!, decl.pos);
      if (base is! PrimType || !base.kind.isInteger) {
        throw CheckError(
          'enum base type must be an integer type, got `${base.displayName}`',
          decl.pos,
        );
      }
      decl.baseType = base;
      decl.resolvedType = EnumType(decl.moduleName, decl.name, base);
      final names = <String>{};
      for (final variant in decl.variants) {
        if (!names.add(variant.name)) {
          throw CheckError(
              'duplicate enum variant `${variant.name}`', variant.pos);
        }
        final value = variant.value;
        if (value != null && value is! IntLit) {
          throw CheckError(
              'enum value must be an integer literal', value.pos);
        }
      }
    }
  }

  KlinType _resolveType(String name, SourcePos pos) {
    if (name.startsWith('!')) {
      final ok = _resolveType(name.substring(1), pos);
      if (ok is VoidType || ok is ArrayType || ok is ResultType) {
        throw CheckError('invalid result type `$name`', pos);
      }
      return ResultType(ok);
    }
    if (name.startsWith('fn(')) {
      return _resolveFnType(name, pos);
    }
    if (name.startsWith('*')) {
      var rest = name.substring(1);
      var isMut = false;
      var isVolatile = false;
      if (rest.startsWith('mut ')) {
        isMut = true;
        rest = rest.substring(4);
      }
      if (rest.startsWith('volatile ')) {
        isVolatile = true;
        rest = rest.substring(9);
      }
      if (rest.isEmpty) throw CheckError('missing pointee type', pos);
      return PtrType(
        _resolveType(rest, pos),
        isMut: isMut,
        isVolatile: isVolatile,
      );
    }
    if (name.startsWith('[]')) {
      final elem = _resolveType(name.substring(2), pos);
      if (elem is! PrimType) {
        throw CheckError('slice requires a primitive element type', pos);
      }
      return SliceType(elem);
    }
    if (name.startsWith('[')) {
      final close = _arrayTypeCloseBracket(name);
      if (close == null || close < 2) {
        throw CheckError('invalid array type `$name`', pos);
      }
      final lenText = name.substring(1, close).replaceAll('_', '');
      final len = _parseIntLiteralValue(lenText);
      if (len == null || len < 0 || close == name.length - 1) {
        throw CheckError('invalid array type `$name`', pos);
      }
      return ArrayType(_resolveType(name.substring(close + 1), pos), len);
    }
    if (name == 'void') return const VoidType();
    if (name == 'str') return const StrType();
    final parts = name.split('.');
    final qualifier = parts.length == 2 ? parts.first : null;
    final typeName = parts.length == 2 ? parts.last : name;
    if (parts.length > 2) {
      throw CheckError('invalid type name `$name`', pos);
    }
    final module = qualifier == null
        ? _currentModule
        : _resolveModuleQualifier(qualifier, pos);
    final struct = _structs[_key(module, typeName)];
    if (struct != null) {
      if (module != _currentModule && !struct.isPub) {
        final shown = qualifier ?? module;
        throw CheckError('struct `$shown.$typeName` is private', pos);
      }
      return StructType(module, struct.name);
    }
    final enumDecl = _enums[_key(module, typeName)];
    if (enumDecl != null) {
      if (module != _currentModule && !enumDecl.isPub) {
        final shown = qualifier ?? module;
        throw CheckError('enum `$shown.$typeName` is private', pos);
      }
      return enumDecl.resolvedType ??
          EnumType(
            module,
            enumDecl.name,
            enumDecl.baseType ?? const PrimType(PrimKind.i32),
          );
    }
    if (qualifier != null) {
      throw CheckError('unknown type `$qualifier.$typeName`', pos);
    }
    return _resolvePrimType(name, pos);
  }

  /// Parses encoded `fn(T1,T2):Ret` from [_typeName].
  KlinType _resolveFnType(String name, SourcePos pos) {
    if (!name.startsWith('fn(')) {
      throw CheckError('invalid function type `$name`', pos);
    }
    var i = 3;
    final params = <KlinType>[];
    if (i >= name.length) {
      throw CheckError('invalid function type `$name`', pos);
    }
    if (name[i] != ')') {
      while (true) {
        final (param, next) = _splitTypePrefix(name, i, pos);
        params.add(_resolveType(param, pos));
        i = next;
        if (i >= name.length) {
          throw CheckError('invalid function type `$name`', pos);
        }
        if (name[i] == ')') break;
        if (name[i] != ',') {
          throw CheckError('invalid function type `$name`', pos);
        }
        i++;
      }
    }
    i++; // ')'
    KlinType ret = const VoidType();
    if (i < name.length) {
      if (name[i] != ':') {
        throw CheckError('invalid function type `$name`', pos);
      }
      ret = _resolveType(name.substring(i + 1), pos);
    }
    if (ret is ArrayType || ret is ResultType) {
      throw CheckError(
        'function type cannot return `${ret.displayName}`',
        pos,
      );
    }
    return FnType(params, ret);
  }

  /// Reads one type spelling from [s] at [start]; returns (typeString, indexAfter).
  (String, int) _splitTypePrefix(String s, int start, SourcePos pos) {
    if (start >= s.length) {
      throw CheckError('invalid type list', pos);
    }
    if (s.startsWith('fn(', start)) {
      var i = start + 3;
      var depth = 1;
      while (i < s.length && depth > 0) {
        final c = s[i];
        if (c == '(') {
          depth++;
        } else if (c == ')') {
          depth--;
        }
        i++;
      }
      if (depth != 0) throw CheckError('invalid function type', pos);
      if (i < s.length && s[i] == ':') {
        i++;
        final (_, afterRet) = _splitTypePrefix(s, i, pos);
        return (s.substring(start, afterRet), afterRet);
      }
      return (s.substring(start, i), i);
    }
    if (s.startsWith('!', start)) {
      final (inner, after) = _splitTypePrefix(s, start + 1, pos);
      return ('!$inner', after);
    }
    if (s.startsWith('*', start)) {
      var i = start + 1;
      if (s.startsWith('mut ', i)) i += 4;
      if (s.startsWith('volatile ', i)) i += 9;
      final (inner, after) = _splitTypePrefix(s, i, pos);
      return (s.substring(start, after), after);
    }
    if (s.startsWith('[]', start)) {
      final (inner, after) = _splitTypePrefix(s, start + 2, pos);
      return ('[]$inner', after);
    }
    if (s.startsWith('[', start)) {
      final close = s.indexOf(']', start);
      if (close < 0) throw CheckError('invalid array type', pos);
      final (inner, after) = _splitTypePrefix(s, close + 1, pos);
      return (s.substring(start, after), after);
    }
    var i = start;
    while (i < s.length) {
      final c = s[i];
      if (c == ',' || c == ')') break;
      i++;
    }
    if (i == start) throw CheckError('invalid type list', pos);
    return (s.substring(start, i), i);
  }

  String _key(String module, String name) => '$module.$name';

  /// Rejects a method/associated function whose C mangling would collide with
  /// an enum variant constant (`Type_Variant` / `mod_Type_Variant`).
  void _rejectEnumVariantCNameClash(
    KlinType type,
    String memberName,
    SourcePos pos,
    String kind,
  ) {
    if (type is! EnumType) return;
    final decl = _enums[_key(type.moduleName, type.name)];
    if (decl == null) return;
    if (!decl.variants.any((v) => v.name == memberName)) return;
    throw CheckError(
      '$kind `${type.displayName}.$memberName` conflicts with enum variant '
      '`$memberName`',
      pos,
    );
  }

  /// Resolves a type-name expression used as `Type.member` or `mod.Type.member`.
  /// Returns `null` when [expr] denotes a value instead of a type.
  ({String module, String typeName, KlinType type})? _typeNameExpr(Expr expr) {
    if (expr is NameExpr) {
      if (_scope.lookup(expr.name) != null) return null;
      final key = _key(_currentModule, expr.name);
      if (!_enums.containsKey(key) && !_structs.containsKey(key)) return null;
      final type = _resolveType(expr.name, expr.pos);
      return (module: _currentModule, typeName: expr.name, type: type);
    }
    if (expr is FieldExpr && expr.object is NameExpr) {
      final modAlias = (expr.object as NameExpr).name;
      final typeName = expr.name;
      if (_scope.lookup(modAlias) != null) return null;
      final actual = _importAliases[_currentModule]?[modAlias];
      if (actual == null && modAlias != _currentModule) return null;
      final module = actual ?? modAlias;
      final key = _key(module, typeName);
      final enumDecl = _enums[key];
      final struct = _structs[key];
      if (enumDecl == null && struct == null) return null;
      if (enumDecl != null && module != _currentModule && !enumDecl.isPub) {
        throw CheckError('enum `$modAlias.$typeName` is private', expr.pos);
      }
      if (struct != null && module != _currentModule && !struct.isPub) {
        throw CheckError('struct `$modAlias.$typeName` is private', expr.pos);
      }
      final type = _resolveType('$modAlias.$typeName', expr.pos);
      return (module: module, typeName: typeName, type: type);
    }
    return null;
  }

  /// Resolves `Enum.Variant` / `mod.Enum.Variant` to an enum constant when
  /// [object] is an enum type name rather than a variable. Returns the enum
  /// type and annotates [node] with the C constant to emit, or `null` when
  /// this is a plain field access.
  KlinType? _tryEnumConstant(
    FieldExpr node,
    Expr object,
    String variant,
    SourcePos pos,
  ) {
    final typeInfo = _typeNameExpr(object);
    if (typeInfo == null || typeInfo.type is! EnumType) return null;
    final decl = _enums[_key(typeInfo.module, typeInfo.typeName)]!;
    if (!decl.variants.any((v) => v.name == variant)) {
      throw CheckError(
          'enum `${typeInfo.typeName}` has no variant `$variant`', pos);
    }
    node.enumConstCName =
        _enumConstCName(decl.moduleName, decl.name, variant);
    final variantDecl =
        decl.variants.firstWhere((v) => v.name == variant);
    node.resolvedDef = ResolvedDef(variantDecl.pos, decl.sourcePath);
    return decl.resolvedType ??
        EnumType(
          decl.moduleName,
          decl.name,
          decl.baseType ?? const PrimType(PrimKind.i32),
        );
  }

  static String _enumConstCName(String module, String name, String variant) =>
      module.isEmpty
          ? '${name}_$variant'
          : '${module}_${name}_$variant';

  /// Maps an `import X` alias to the file module name.
  String _resolveModuleQualifier(String qualifier, SourcePos pos) {
    if (qualifier == _currentModule) return qualifier;
    final actual = _importAliases[_currentModule]?[qualifier];
    if (actual == null) {
      throw CheckError('module `$qualifier` is not imported', pos);
    }
    return actual;
  }

  PrimType _resolvePrimType(String name, SourcePos pos) {
    final kind = PrimKind.tryParse(name);
    if (kind == null) throw CheckError('unknown type `$name`', pos);
    return PrimType(kind);
  }

  void _checkBlock(Block block) {
    _scope = _Scope(_scope);
    for (final stmt in block.stmts) {
      _checkStmt(stmt);
    }
    _scope = _scope.parent!;
  }

  void _checkStmt(Stmt stmt) {
    switch (stmt) {
      case AsmStmt():
        break;

      case LetStmt(
          :final isMut,
          :final name,
          :final typeName,
          :final init,
          :final pos
        ):
        KlinType? annotated;
        if (typeName != null) {
          annotated = _resolveType(typeName, pos);
        }

        final KlinType resolved;
        if (init != null) {
          final initType = _inferLetOrAssignValue(init);
          if (annotated != null) {
            _expectAssignable(annotated, initType, init.pos);
            resolved = annotated;
            _materialize(init, resolved);
          } else {
            resolved = _defaultConcrete(initType, init.pos);
            _materialize(init, resolved);
          }
          if (resolved is ArrayType && init is! ArrayLitExpr) {
            throw CheckError(
              'array initialization requires a `[...]` literal',
              init.pos,
            );
          }
        } else if (annotated != null) {
          // No initializer: use the annotated type.
          resolved = annotated;
        } else {
          throw CheckError(
            'zmienna `$name` wymaga typu lub inicjalizatora',
            pos,
          );
        }

        stmt.resolvedType = resolved;
        if (_currentIsAsync) {
          if (_asyncFlatNames.contains(name)) {
            throw CheckError(
              'async fn MVP does not allow reused `let $name` '
              '(flat state struct — including sibling scopes)',
              pos,
            );
          }
          _asyncFlatNames.add(name);
        }
        _scope.define(
          _Symbol(name: name, type: resolved, isMut: isMut, pos: pos),
        );

      case LetDestructureStmt(
          :final isMut,
          :final fields,
          :final binds,
          :final source,
          :final pos
        ):
        final sourceType =
            _defaultConcrete(_inferLetOrAssignValue(source), source.pos);
        if (sourceType is! StructType) {
          throw CheckError(
            'destructuring requires a struct, got `${sourceType.displayName}`',
            source.pos,
          );
        }
        _materialize(source, sourceType);
        final decl = _structs[_key(sourceType.moduleName, sourceType.name)]!;
        final fieldTypes = <KlinType>[];
        for (final fieldName in fields) {
          FieldDecl? field;
          for (final candidate in decl.fields) {
            if (candidate.name == fieldName) {
              field = candidate;
              break;
            }
          }
          if (field == null) {
            throw CheckError(
              'struct `${sourceType.name}` has no field `$fieldName`',
              pos,
            );
          }
          final fieldType = field.resolvedType!;
          if (fieldType is ArrayType) {
            throw CheckError(
              'cannot destructure array field `$fieldName` '
              '(bind the struct and index it instead)',
              pos,
            );
          }
          fieldTypes.add(fieldType);
        }
        stmt.sourceType = sourceType;
        stmt.fieldTypes = fieldTypes;
        for (var i = 0; i < binds.length; i++) {
          _scope.define(
            _Symbol(name: binds[i], type: fieldTypes[i], isMut: isMut, pos: pos),
          );
        }

      case LetArrayDestructureStmt(
          :final isMut,
          :final names,
          :final source,
          :final pos
        ):
        // The source must be indexable without side effects or an invalid C
        // array copy, so restrict phase C to array variables and literals.
        if (source is! NameExpr && source is! ArrayLitExpr) {
          throw CheckError(
            'array destructuring source must be an array variable or literal',
            source.pos,
          );
        }
        final sourceType =
            _defaultConcrete(_inferLetOrAssignValue(source), source.pos);
        if (sourceType is! ArrayType) {
          throw CheckError(
            'array destructuring requires a fixed-length array `[N]T`, '
            'got `${sourceType.displayName}`',
            source.pos,
          );
        }
        if (sourceType.len != names.length) {
          throw CheckError(
            'array has ${sourceType.len} element(s) but the pattern binds '
            '${names.length}',
            pos,
          );
        }
        final elemType = sourceType.elem;
        if (elemType is ArrayType) {
          throw CheckError(
            'cannot destructure a nested array element '
            '(bind the array and index it instead)',
            pos,
          );
        }
        _materialize(source, sourceType);
        stmt.elemType = elemType;
        for (final name in names) {
          if (name == null) continue; // `_` skip
          _scope.define(
            _Symbol(name: name, type: elemType, isMut: isMut, pos: pos),
          );
        }

      case AssignStmt(:final target, :final value, :final pos, :final compoundOp):
        final targetType = _checkAssignableTarget(target, pos);
        if (targetType is ArrayType) {
          throw CheckError(
            'cannot assign an entire array (assign elements or use a slice)',
            pos,
          );
        }
        // The target place carries its own type: emission of `or {}` / `!` /
        // `match` assignments reads it to declare the temporaries.
        target.resolvedType = targetType;
        if (compoundOp != null) {
          if (value is OrExpr || value is PropagateExpr || value is MatchExpr) {
            throw CheckError(
              'compound assignment values must be plain expressions',
              value.pos,
            );
          }
          // Type-check as `target = target op value` (issue 078).
          final resultType = _inferBinary(target, compoundOp, value, pos);
          _expectAssignable(targetType, resultType, value.pos);
          break;
        }
        final valueType = _inferLetOrAssignValue(value);
        _expectAssignable(targetType, valueType, value.pos);
        _materialize(value, targetType);

      case MultiAssignStmt(:final targets, :final values):
        for (var i = 0; i < targets.length; i++) {
          final target = targets[i];
          final value = values[i];
          // Special assignment forms need dedicated lowering; keep phase B to
          // plain values (use a separate statement for `or` / `!` / `match`).
          if (value is OrExpr || value is PropagateExpr || value is MatchExpr) {
            throw CheckError(
              'multi-assignment values must be plain expressions '
              '(assign `or` / `!` / `match` in its own statement)',
              value.pos,
            );
          }
          final targetType = _checkAssignableTarget(target, target.pos);
          if (targetType is ArrayType) {
            throw CheckError(
              'cannot assign an entire array (assign elements or use a slice)',
              target.pos,
            );
          }
          target.resolvedType = targetType;
          final valueType = _inferExpr(value);
          _expectAssignable(targetType, valueType, value.pos);
          _materialize(value, targetType);
        }

      case StructAssignStmt(
          :final fields,
          :final targets,
          :final source,
          :final pos
        ):
        final sourceType =
            _defaultConcrete(_inferLetOrAssignValue(source), source.pos);
        if (sourceType is! StructType) {
          throw CheckError(
            'destructuring requires a struct, got `${sourceType.displayName}`',
            source.pos,
          );
        }
        _materialize(source, sourceType);
        final decl = _structs[_key(sourceType.moduleName, sourceType.name)]!;
        final fieldTypes = <KlinType>[];
        for (var i = 0; i < fields.length; i++) {
          final fieldName = fields[i];
          FieldDecl? field;
          for (final candidate in decl.fields) {
            if (candidate.name == fieldName) {
              field = candidate;
              break;
            }
          }
          if (field == null) {
            throw CheckError(
              'struct `${sourceType.name}` has no field `$fieldName`',
              pos,
            );
          }
          final fieldType = field.resolvedType!;
          if (fieldType is ArrayType) {
            throw CheckError(
              'cannot destructure array field `$fieldName` '
              '(bind the struct and index it instead)',
              pos,
            );
          }
          final target = targets[i];
          final targetType = _checkAssignableTarget(target, target.pos);
          _expectAssignable(targetType, fieldType, target.pos);
          target.resolvedType = targetType;
          fieldTypes.add(fieldType);
        }
        stmt.sourceType = sourceType;
        stmt.fieldTypes = fieldTypes;

      case MatchStmt(:final subject, :final arms):
        _checkMatchSubject(subject);
        final subjectType = subject.resolvedType!;
        _checkMatchArmsOrder(arms.map((a) => a.pattern).toList());
        for (final arm in arms) {
          if (arm.pattern is! ElsePattern) {
            _checkMatchPattern(arm.pattern, subjectType);
          }
          final when = arm.when;
          if (when != null) {
            _expectBoolCond(when);
          }
          _checkBlock(arm.body);
        }

      case CallStmt(:final moduleName, :final callee, :final args, :final pos):
        if (_tryCheckInterpPrint(moduleName, callee, args, pos,
            onResolved: (cName) => stmt.resolvedCallee = cName)) {
          break;
        }
        final spawn = _tryCheckAsyncSpawn(moduleName, callee, args, pos);
        if (spawn != null) {
          throw CheckError(
            'result `${spawn.returnType.displayName}` from function `$callee` '
            'must be handled with `!` or `or`',
            pos,
          );
        }
        final call = _checkCall(callee, args, pos, moduleName: moduleName);
        if (call.isAsync) {
          throw CheckError(
            'async function `$callee` can only be used with `.await`',
            pos,
          );
        }
        if (call.type is ResultType) {
          throw CheckError(
            'result `${call.type.displayName}` from function `$callee` must be handled with `!` or `or`',
            pos,
          );
        }
        stmt.resolvedCallee = call.cName;
        stmt.resolvedDef = call.def;

      case MethodCallStmt(:final call):
        final type = _checkMethodCall(call);
        call.resolvedType = type;
        if (type is ResultType) {
          throw CheckError(
            'result `${type.displayName}` from method `${call.name}` must be handled with `!` or `or`',
            call.pos,
          );
        }

      case AwaitStmt(:final expr):
        _inferExpr(expr);

      case IfStmt(:final cond, :final thenBlock, :final elseBranch):
        _expectBoolCond(cond);
        _checkBlock(thenBlock);
        if (elseBranch != null) _checkStmt(elseBranch);

      case WhileStmt(:final cond, :final body):
        _expectBoolCond(cond);
        _loopDepth++;
        _checkBlock(body);
        _loopDepth--;

      case ForRangeStmt(
          :final name,
          :final start,
          :final endExclusive,
          :final body,
          :final pos
        ):
        final startTy = _inferExpr(start);
        final endTy = _inferExpr(endExclusive);
        final unified = _unifyNumeric(startTy, endTy, pos);
        final concrete = _defaultConcrete(unified, pos);
        if (concrete is! PrimType || !concrete.kind.isInteger) {
          throw CheckError(
            '`for` range requires integer types, got `${concrete.displayName}`',
            pos,
          );
        }
        _materialize(start, concrete);
        _materialize(endExclusive, concrete);
        stmt.resolvedType = concrete;

        _scope = _Scope(_scope);
        _scope.define(
          _Symbol(name: name, type: concrete, isMut: true, pos: pos),
        );
        _loopDepth++;
        _checkBlock(body);
        _loopDepth--;
        _scope = _scope.parent!;

      case ForCStmt(
          :final initName,
          :final initExpr,
          :final cond,
          :final postName,
          :final postExpr,
          :final body,
          :final pos
        ):
        _scope = _Scope(_scope);
        if (initName != null && initExpr != null) {
          final initTy = _inferExpr(initExpr);
          final concrete = _defaultConcrete(initTy, initExpr.pos);
          _materialize(initExpr, concrete);
          stmt.resolvedInitType = concrete;
          _scope.define(
            _Symbol(name: initName, type: concrete, isMut: true, pos: pos),
          );
        }
        if (cond != null) _expectBoolCond(cond);
        if (postName != null && postExpr != null) {
          final sym = _scope.lookup(postName);
          if (sym == null) {
            throw CheckError('unknown variable `$postName`', postExpr.pos);
          }
          if (!sym.isMut) {
            throw CheckError(
              'cannot assign to immutable variable `$postName`',
              postExpr.pos,
            );
          }
          final postTy = _inferExpr(postExpr);
          _expectAssignable(sym.type, postTy, postExpr.pos);
          _materialize(postExpr, sym.type);
        }
        _loopDepth++;
        _checkBlock(body);
        _loopDepth--;
        _scope = _scope.parent!;

      case ReturnStmt(:final value, :final pos):
        _checkReturn(value, pos);

      case BreakStmt(:final pos):
        if (_loopDepth == 0) {
          throw CheckError('`break` outside a loop', pos);
        }

      case ContinueStmt(:final pos):
        if (_loopDepth == 0) {
          throw CheckError('`continue` outside a loop', pos);
        }

      case DeferStmt(:final body, :final pos):
        if (_deferDepth > 0) {
          throw CheckError('`defer` inside `defer`', pos);
        }
        _deferDepth++;
        try {
          _checkStmt(body);
        } finally {
          _deferDepth--;
        }

      case BlockStmt(:final block):
        _checkBlock(block);
    }
  }

  void _expectBoolCond(Expr cond) {
    final t = _inferExpr(cond);
    // Comparisons already yield bool. A bool literal is valid; untyped values and numbers are not.
    if (t is PrimType && t.kind == PrimKind.bool_) {
      return;
    }
    throw CheckError(
      'condition requires type `bool`, got `${t.displayName}`',
      cond.pos,
    );
  }

  void _checkReturn(Expr? value, SourcePos pos) {
    if (_currentFunction == 'main') {
      if (value == null) return;
      final type = _defaultConcrete(_inferExpr(value), value.pos);
      if (type is! PrimType || !type.kind.isInteger) {
        throw CheckError(
          '`return` in main requires an integer type, got `${type.displayName}`',
          value.pos,
        );
      }
      _materialize(value, type);
      return;
    }
    if (_currentReturn is VoidType) {
      if (value != null) {
        throw CheckError('void function cannot return a value', value.pos);
      }
      return;
    }
    if (value == null) {
      throw CheckError(
        'function `${_currentFunction}` must return `${_currentReturn.displayName}`',
        pos,
      );
    }
    final valueType = _inferExpr(value);
    if (_currentReturn case ResultType(:final ok)) {
      if (valueType == _currentReturn) {
        _materialize(value, _currentReturn);
      } else {
        _expectAssignable(ok, valueType, value.pos);
        _materialize(value, ok);
      }
      return;
    }
    _expectAssignable(_currentReturn, valueType, value.pos);
    _materialize(value, _currentReturn);
  }

  /// If [args] is a single interpolated string to a print sink, resolve it and
  /// rewrite the call to `printf`. Returns true when handled.
  bool _tryCheckInterpPrint(
    String? moduleName,
    String callee,
    List<Expr> args,
    SourcePos pos, {
    required void Function(String cName) onResolved,
  }) {
    final hasInterp = args.any((a) => a is InterpolatedStringExpr);
    if (!hasInterp) return false;

    if (!_isInterpPrintSink(moduleName, callee)) {
      final bad = args.whereType<InterpolatedStringExpr>().first;
      throw CheckError(
        'interpolated string is print-only in MVP '
        '(use as the sole argument to puts / printf / io.print / io.println)',
        bad.pos,
      );
    }
    if (args.length != 1 || args[0] is! InterpolatedStringExpr) {
      throw CheckError(
        'interpolated string must be the sole argument of `$callee` in MVP',
        pos,
      );
    }
    final interp = args[0] as InterpolatedStringExpr;
    _resolveInterpolatedString(interp);
    interp.appendNewline = _interpSinkNeedsNewline(moduleName, callee);
    onResolved('printf');
    return true;
  }

  bool _isInterpPrintSink(String? moduleName, String callee) {
    if (callee == 'puts' || callee == 'printf') return true;
    if (moduleName == 'io' && (callee == 'print' || callee == 'println')) {
      return true;
    }
    return false;
  }

  bool _interpSinkNeedsNewline(String? moduleName, String callee) {
    if (callee == 'puts') return true;
    if (moduleName == 'io' && callee == 'println') return true;
    return false;
  }

  void _resolveInterpolatedString(InterpolatedStringExpr interp) {
    for (final part in interp.parts) {
      if (part is! InterpSlot) continue;
      final ty = _inferExpr(part.expr);
      final KlinType concrete;
      if (ty is UntypedInt || ty is UntypedFloat) {
        concrete = _defaultConcrete(ty, part.expr.pos);
        _materialize(part.expr, concrete);
      } else if (ty is PrimType || ty is StrType || ty is PtrType) {
        concrete = ty;
      } else {
        throw CheckError(
          'cannot interpolate value of type `${ty.displayName}`',
          part.expr.pos,
        );
      }
      final resolved =
          _resolveInterpFormat(part.formatRaw, concrete, part.expr.pos);
      if (resolved.trimFrac) {
        part.trimFrac = true;
        part.trimFracDigits = resolved.trimFracDigits;
        part.printfSpec = '%s';
      } else {
        part.trimFrac = false;
        part.printfSpec = resolved.printfSpec;
      }
    }
  }

  ({bool trimFrac, int trimFracDigits, String? printfSpec}) _resolveInterpFormat(
    String? raw,
    KlinType type,
    SourcePos pos,
  ) {
    if (raw == null || raw.isEmpty) {
      return (trimFrac: false, trimFracDigits: 0, printfSpec: _defaultPrintf(type, pos));
    }
    if (raw.startsWith('%')) {
      if (raw == '%' || raw.contains('%n')) {
        throw CheckError('invalid printf format `$raw`', pos);
      }
      return (trimFrac: false, trimFracDigits: 0, printfSpec: raw);
    }
    if (raw == 'hex') {
      _expectInterpNumeric(type, raw, pos);
      return (trimFrac: false, trimFracDigits: 0, printfSpec: '%x');
    }
    if (raw == 'HEX') {
      _expectInterpNumeric(type, raw, pos);
      return (trimFrac: false, trimFracDigits: 0, printfSpec: '%X');
    }
    if (raw == 'sci') {
      _expectInterpFloaty(type, raw, pos);
      return (trimFrac: false, trimFracDigits: 0, printfSpec: '%e');
    }
    if (raw == 'SCI') {
      _expectInterpFloaty(type, raw, pos);
      return (trimFrac: false, trimFracDigits: 0, printfSpec: '%E');
    }
    final sMatch = RegExp(r'^s(\d+)$').firstMatch(raw);
    if (sMatch != null) {
      if (type is! StrType) {
        throw CheckError(
          'format `$raw` requires `str`, got `${type.displayName}`',
          pos,
        );
      }
      return (
        trimFrac: false,
        trimFracDigits: 0,
        printfSpec: '%.${sMatch[1]}s',
      );
    }
    final fixed = RegExp(r'^0\.(0+)$').firstMatch(raw);
    if (fixed != null) {
      _expectInterpFloaty(type, raw, pos);
      return (
        trimFrac: false,
        trimFracDigits: 0,
        printfSpec: '%.${fixed[1]!.length}f',
      );
    }
    final opt = RegExp(r'^0\.(#+)$').firstMatch(raw);
    if (opt != null) {
      _expectInterpFloaty(type, raw, pos);
      return (
        trimFrac: true,
        trimFracDigits: opt[1]!.length,
        printfSpec: null,
      );
    }
    if (raw == '0') {
      if (type is PrimType &&
          (type.kind == PrimKind.f32 || type.kind == PrimKind.f64)) {
        return (trimFrac: false, trimFracDigits: 0, printfSpec: '%.0f');
      }
      if (type is UntypedFloat) {
        return (trimFrac: false, trimFracDigits: 0, printfSpec: '%.0f');
      }
      _expectInterpNumeric(type, raw, pos);
      return (trimFrac: false, trimFracDigits: 0, printfSpec: '%d');
    }
    final zeros = RegExp(r'^(0+)$').firstMatch(raw);
    if (zeros != null) {
      _expectInterpNumeric(type, raw, pos);
      return (
        trimFrac: false,
        trimFracDigits: 0,
        printfSpec: '%0${raw.length}d',
      );
    }
    throw CheckError(
      'unknown format `$raw` '
      '(use printf `%…`, masks `0.00` / `0.###`, `sN`, `hex`, or `sci`)',
      pos,
    );
  }

  void _expectInterpNumeric(KlinType type, String raw, SourcePos pos) {
    if (type is UntypedInt) return;
    if (type is PrimType && type.kind.isInteger) return;
    throw CheckError(
      'format `$raw` requires an integer type, got `${type.displayName}`',
      pos,
    );
  }

  void _expectInterpFloaty(KlinType type, String raw, SourcePos pos) {
    if (type is UntypedFloat || type is UntypedInt) return;
    if (type is PrimType &&
        (type.kind.isFloat || type.kind.isInteger)) {
      return;
    }
    throw CheckError(
      'format `$raw` requires a numeric type, got `${type.displayName}`',
      pos,
    );
  }

  String _defaultPrintf(KlinType type, SourcePos pos) {
    if (type is StrType) return '%s';
    if (type is PtrType) return '%p';
    if (type is UntypedInt) return '%d';
    if (type is UntypedFloat) return '%g';
    if (type is PrimType) {
      return switch (type.kind) {
        PrimKind.bool_ => '%d',
        PrimKind.f32 || PrimKind.f64 => '%g',
        PrimKind.i8 ||
        PrimKind.i16 ||
        PrimKind.i32 ||
        PrimKind.isize =>
          '%d',
        PrimKind.i64 => '%lld',
        PrimKind.u8 ||
        PrimKind.u16 ||
        PrimKind.u32 ||
        PrimKind.usize =>
          '%u',
        PrimKind.u64 => '%llu',
      };
    }
    throw CheckError(
      'cannot choose a default format for `${type.displayName}` — '
      'provide an explicit `:…` format',
      pos,
    );
  }

  _CheckedCall _checkCall(
    String callee,
    List<Expr> args,
    SourcePos pos, {
    String? moduleName,
  }) {
    final local = _scope.lookup(callee);
    if (local != null && moduleName == null) {
      final fnType = local.type;
      if (fnType is FnType) {
        final call = _checkFnTypeCall(fnType, callee, args, pos);
        return _CheckedCall(
          call.type,
          call.cName,
          isAsync: call.isAsync,
          def: ResolvedDef(local.pos, _currentSourcePath),
        );
      }
      throw CheckError(
        '`$callee` is not a function (it is a `${local.type.displayName}` variable)',
        pos,
      );
    }
    final String module;
    if (moduleName != null) {
      module = _resolveModuleQualifier(moduleName, pos);
    } else {
      module = _currentModule;
    }
    final signature = _functions[_key(module, callee)];
    if (signature == null) {
      if (moduleName != null) {
        throw CheckError('nieznana funkcja `$moduleName.$callee`', pos);
      }
      final elsewhere = _allFunctions
          .where((func) =>
              func.receiver == null &&
              func.associatedType == null &&
              func.name == callee)
          .toList();
      if (elsewhere.isNotEmpty) {
        final mod = elsewhere.first.moduleName;
        throw CheckError(
          'function `$callee` is in module `$mod` — use `$mod.$callee`',
          pos,
        );
      }
      // Host builtins with unknown/varargs signatures (issue 021).
      // Everything else requires an explicit `@[cimport]` declaration.
      if (callee == 'puts' || callee == 'printf') {
        for (final arg in args) {
          _inferExpr(arg);
        }
        return const _CheckedCall(PrimType(PrimKind.i32), null);
      }
      throw CheckError(
        'unknown function `$callee` — declare it with `@[cimport]` '
        '(or use host builtins `puts` / `printf`)',
        pos,
      );
    }
    final decl = _functionDecl(module, callee);
    if (module != _currentModule && !decl.isPub) {
      final shown = moduleName ?? module;
      throw CheckError('function `$shown.$callee` is private', pos);
    }
    if (args.length != signature.paramTypes.length) {
      throw CheckError(
        'function `$callee` expects ${signature.paramTypes.length} arguments, '
        'got ${args.length}',
        pos,
      );
    }
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      final expected = signature.paramTypes[i];
      final actual = _inferExpr(arg);
      _expectAssignable(expected, actual, arg.pos);
      _materialize(arg, expected);
    }
    return _CheckedCall(
      signature.returnType,
      _cNameForFunction(decl),
      isAsync: signature.isAsync,
      def: ResolvedDef(decl.pos, decl.sourcePath),
    );
  }

  /// `mod.spawn(ex, async_fn)` — second arg is an async function name.
  /// Returns spawn C name + async fn base, or null if not that sugar form.
  ({String spawnCName, String asyncFnBase, KlinType returnType})?
      _tryCheckAsyncSpawn(
    String? moduleName,
    String callee,
    List<Expr> args,
    SourcePos pos,
  ) {
    if (callee != 'spawn' || args.length != 2) return null;
    if (moduleName == null) return null;
    final module = _resolveModuleQualifier(moduleName, pos);
    final signature = _functions[_key(module, callee)];
    if (signature == null) return null;
    // Prefer dedicated spawn signature: (*mut Executor, …) — if lib exposes
    // `spawn`, treat name-arg form specially when arg1 is an async fn name.
    final fnArg = args[1];
    if (fnArg is! NameExpr) return null;
    final asyncName = fnArg.name;
    final asyncSig = _functions[_key(_currentModule, asyncName)] ??
        _functions[_key(module, asyncName)];
    // Also search all modules for the async fn (user code module).
    FuncDecl? asyncDecl;
    for (final func in _allFunctions) {
      if (func.receiver == null &&
          func.associatedType == null &&
          func.name == asyncName &&
          func.isAsync) {
        asyncDecl = func;
        break;
      }
    }
    if (asyncDecl == null && (asyncSig == null || !asyncSig.isAsync)) {
      return null;
    }
    final decl = asyncDecl ??
        _allFunctions.firstWhere((f) =>
            f.name == asyncName && f.isAsync && f.receiver == null);
    if (decl.params.isNotEmpty) {
      throw CheckError(
        '`spawn` MVP requires a zero-parameter `async fn` (got `$asyncName`)',
        fnArg.pos,
      );
    }
    // Typecheck executor pointer arg against spawn's first param if present.
    if (signature.paramTypes.isNotEmpty) {
      final expected = signature.paramTypes[0];
      final actual = _inferExpr(args[0]);
      _expectAssignable(expected, actual, args[0].pos);
      _materialize(args[0], expected);
    } else {
      _inferExpr(args[0]);
    }
    final spawnDecl = _functionDecl(module, callee);
    if (module != _currentModule && !spawnDecl.isPub) {
      throw CheckError('function `$moduleName.$callee` is private', pos);
    }
    return (
      spawnCName: _cNameForFunction(spawnDecl),
      asyncFnBase: _cNameForFunction(decl),
      returnType: signature.returnType,
    );
  }

  KlinType _checkAwait(AwaitExpr expr) {
    final operand = expr.operand;
    if (operand is CallExpr) {
      final call = _checkCall(
        operand.callee,
        operand.args,
        operand.pos,
        moduleName: operand.moduleName,
      );
      operand.resolvedCallee = call.cName;
      operand.resolvedDef = call.def;
      operand.resolvedType = call.type;
      if (call.isAsync) {
        expr.asyncCallee = call.cName;
        return const VoidType();
      }
      return _bindPollableAwait(expr, call.type);
    }
    final type = _inferExpr(operand);
    return _bindPollableAwait(expr, type);
  }

  KlinType _bindPollableAwait(AwaitExpr expr, KlinType type) {
    if (type is! StructType) {
      throw CheckError(
        '`.await` requires an async call or a pollable struct (got `${type.displayName}`)',
        expr.pos,
      );
    }
    expr.operand.resolvedType = type;
    final key = '${type.displayName}.poll';
    final poll = _methods[key];
    if (poll == null) {
      throw CheckError(
        'type `${type.displayName}` is not awaitable (missing `poll` method)',
        expr.pos,
      );
    }
    if (poll.paramTypes.isNotEmpty) {
      throw CheckError(
        'awaitable `poll` must take no arguments (besides receiver)',
        expr.pos,
      );
    }
    if (poll.returnType is! PrimType ||
        (poll.returnType as PrimType).kind != PrimKind.i32) {
      throw CheckError(
        'awaitable `poll` must return `i32` (0=Pending, 1=Ready)',
        expr.pos,
      );
    }
    if (!poll.isMutReceiver) {
      throw CheckError(
        'awaitable `poll` must use a `mut` receiver',
        expr.pos,
      );
    }
    final structKey = _key(type.moduleName, type.name);
    final struct = _structs[structKey];
    if (struct == null) {
      throw CheckError('unknown struct `${type.displayName}`', expr.pos);
    }
    expr.pollMangled = _methodCName(struct.moduleName, struct.name, 'poll');
    expr.pollByRef = true;
    return const VoidType();
  }

  String _methodCName(String module, String typeName, String method) =>
      module.isEmpty ? '${typeName}_$method' : '${module}_${typeName}_$method';

  _CheckedCall _checkFnTypeCall(
    FnType fnType,
    String callee,
    List<Expr> args,
    SourcePos pos,
  ) {
    if (args.length != fnType.params.length) {
      throw CheckError(
        'function `$callee` expects ${fnType.params.length} arguments, '
        'got ${args.length}',
        pos,
      );
    }
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      final expected = fnType.params[i];
      final actual = _inferExpr(arg);
      _expectAssignable(expected, actual, arg.pos);
      _materialize(arg, expected);
    }
    return _CheckedCall(fnType.ret, null);
  }

  /// Top-level free function as an `fn(...)` value (C decay).
  ({FnType type, String cName})? _fnTypeForName(String name, SourcePos pos) {
    final signature = _functions[_key(_currentModule, name)];
    if (signature == null) return null;
    final decl = _functionDecl(_currentModule, name);
    if (decl.receiver != null) return null;
    return (
      type: FnType(signature.paramTypes, signature.returnType),
      cName: _cNameForFunction(decl),
    );
  }

  FuncDecl _functionDecl(String module, String name) =>
      _allFunctions.firstWhere((func) =>
          func.receiver == null &&
          func.associatedType == null &&
          func.moduleName == module &&
          func.name == name);

  String _mangledFreeName(String module, String name) =>
      module.isEmpty ? name : '${module}_$name';

  String _cNameForFunction(FuncDecl func) {
    for (final attr in func.attrs) {
      if (attr.name == 'codename') return attr.arg!;
    }
    return _mangledFreeName(func.moduleName, func.name);
  }

  /// Resolves `Type.func(args)` / `mod.Type.func(args)` — an associated
  /// (static) function call where the "receiver" is a type name, not a value.
  /// Returns the result type, or `null` when this is a normal instance-method
  /// call.
  KlinType? _tryAssociatedCall(MethodCallExpr call) {
    final typeInfo = _typeNameExpr(call.receiver);
    if (typeInfo == null) return null;
    final type = typeInfo.type;
    if (type is! StructType && type is! EnumType) return null;
    final module = typeInfo.module;
    final typeName = typeInfo.typeName;
    final signature = _assocFuncs['${type.displayName}.${call.name}'];
    if (signature == null) {
      throw CheckError(
        'type `$typeName` has no associated function `${call.name}`',
        call.pos,
      );
    }
    if (module != _currentModule && !signature.isPub) {
      throw CheckError(
        'associated function `$module.$typeName.${call.name}` is private',
        call.pos,
      );
    }
    if (call.args.length != signature.paramTypes.length) {
      throw CheckError(
        'associated function `$typeName.${call.name}` expects '
        '${signature.paramTypes.length} arguments, got ${call.args.length}',
        call.pos,
      );
    }
    for (var i = 0; i < call.args.length; i++) {
      final arg = call.args[i];
      _expectAssignable(signature.paramTypes[i], _inferExpr(arg), arg.pos);
      _materialize(arg, signature.paramTypes[i]);
    }
    call.mangledName = module.isEmpty
        ? '${typeName}_${call.name}'
        : '${module}_${typeName}_${call.name}';
    call.isAssociated = true;
    final decl = _findAssociatedFunc(type.displayName, call.name);
    if (decl != null) {
      call.resolvedDef = ResolvedDef(decl.pos, decl.sourcePath);
    }
    return signature.returnType;
  }

  KlinType _checkMethodCall(MethodCallExpr call) {
    final assoc = _tryAssociatedCall(call);
    if (assoc != null) return assoc;
    final receiverType = _inferExpr(call.receiver);
    if (receiverType is! StructType && receiverType is! EnumType) {
      throw CheckError(
          'method requires a struct or enum, got `${receiverType.displayName}`',
          call.pos);
    }
    final String receiverModule;
    final String receiverName;
    switch (receiverType) {
      case StructType(:final moduleName, :final name):
        receiverModule = moduleName;
        receiverName = name;
      case EnumType(:final moduleName, :final name):
        receiverModule = moduleName;
        receiverName = name;
      default:
        throw StateError('unreachable: receiver is struct or enum');
    }
    final signature = _methods['${receiverType.displayName}.${call.name}'];
    if (signature == null) {
      throw CheckError(
          'type `$receiverName` has no method `${call.name}`',
          call.pos);
    }
    if (receiverModule != _currentModule && !signature.isPub) {
      throw CheckError(
        'method `$receiverModule.$receiverName.${call.name}` is private',
        call.pos,
      );
    }
    if (signature.isMutReceiver) {
      if (call.receiver is! NameExpr) {
        throw CheckError(
            'mutating method requires a mutable variable', call.receiver.pos);
      }
      final receiver = call.receiver as NameExpr;
      final symbol = _scope.lookup(receiver.name);
      if (symbol == null || !symbol.isMut) {
        throw CheckError(
            'cannot call a mutating method on an immutable variable',
            call.receiver.pos);
      }
    }
    if (call.args.length != signature.paramTypes.length) {
      throw CheckError(
        'method `${call.name}` expects ${signature.paramTypes.length} arguments, got ${call.args.length}',
        call.pos,
      );
    }
    for (var i = 0; i < call.args.length; i++) {
      final arg = call.args[i];
      final expected = signature.paramTypes[i];
      _expectAssignable(expected, _inferExpr(arg), arg.pos);
      _materialize(arg, expected);
    }
    call.mangledName = receiverModule.isEmpty
        ? '${receiverName}_${call.name}'
        : '${receiverModule}_${receiverName}_${call.name}';
    call.receiverByRef = signature.isMutReceiver;
    final decl = _findInstanceMethod(receiverType.displayName, call.name);
    if (decl != null) {
      call.resolvedDef = ResolvedDef(decl.pos, decl.sourcePath);
    }
    return signature.returnType;
  }

  FuncDecl? _findInstanceMethod(String typeDisplayName, String name) {
    for (final f in _allFunctions) {
      if (f.receiver == null || f.name != name) continue;
      final rt = f.receiver!.resolvedType;
      if (rt != null && rt.displayName == typeDisplayName) return f;
    }
    return null;
  }

  FuncDecl? _findAssociatedFunc(String typeDisplayName, String name) {
    for (final f in _allFunctions) {
      if (f.associatedType == null || f.name != name) continue;
      // Resolve the type name in the declaring module (not the caller's).
      final saved = _currentModule;
      _currentModule = f.moduleName;
      try {
        final t = _resolveType(f.associatedType!, f.pos);
        if (t.displayName == typeDisplayName) return f;
      } finally {
        _currentModule = saved;
      }
    }
    return null;
  }

  KlinType _checkAssignableTarget(Expr target, SourcePos pos) {
    final place = _unwrapGroups(target);
    if (place is NameExpr) {
      final symbol = _scope.lookup(place.name);
      if (symbol == null)
        throw CheckError('unknown variable `${place.name}`', pos);
      if (!symbol.isMut) {
        throw CheckError(
            'cannot assign to immutable variable `${place.name}`', pos);
      }
      place.isPtrReceiver = symbol.isPtrReceiver;
      return symbol.type;
    }
    if (place is FieldExpr) {
      final objectType = _inferExpr(place.object);
      if (objectType is ArrayType || objectType is SliceType) {
        throw CheckError('`len` is read-only', pos);
      }
      _requireMutableStructPlace(place.object, pos);
      return _inferExpr(place);
    }
    if (place is UnaryExpr && place.op == '*') {
      final pointer = _inferExpr(place.operand);
      if (pointer is! PtrType) {
        throw CheckError('dereference requires a pointer', pos);
      }
      if (!pointer.isMut) {
        throw CheckError('cannot write through an immutable pointer', pos);
      }
      return pointer.pointee;
    }
    if (place is IndexExpr) {
      final objectType = _inferExpr(place.object);
      // Slice header is a value; element storage is shared with the caller (Go-like).
      if (objectType is SliceType) {
        return _inferExpr(place);
      }
      final type = _inferExpr(place);
      _requireMutableArrayPlace(place.object, pos);
      return type;
    }
    throw CheckError('invalid assignment target', pos);
  }

  void _requireMutableStructPlace(Expr object, SourcePos pos) =>
      _requireMutablePlace(
        object,
        pos,
        immutableVarMessage: 'cannot assign to a field of an immutable variable',
        immutableExprMessage:
            'cannot assign to a field of an immutable expression',
      );

  void _requireMutableArrayPlace(Expr object, SourcePos pos) =>
      _requireMutablePlace(
        object,
        pos,
        immutableVarMessage: 'cannot assign to an immutable array',
        immutableExprMessage: 'cannot assign through an immutable expression',
      );

  /// Recursively verifies that [object] is a mutable place (an lvalue chain).
  ///
  /// Accepts nested places — struct fields, fixed-array elements reached through
  /// a `mut` receiver or variable, and writes through a `*mut` dereference —
  /// mirroring the recursive check used for `&` ([_isMutablePlace]). Slice
  /// element storage is shared with the caller (Go-like), so it stays writable.
  /// The two message parameters preserve the caller's context (field vs array)
  /// for the terminal error.
  void _requireMutablePlace(
    Expr object,
    SourcePos pos, {
    required String immutableVarMessage,
    required String immutableExprMessage,
  }) {
    final base = _unwrapGroups(object);
    if (base is NameExpr) {
      final symbol = _scope.lookup(base.name);
      if (symbol == null) {
        throw CheckError('nieznana zmienna `${base.name}`', pos);
      }
      if (!symbol.isMut) {
        throw CheckError(immutableVarMessage, pos);
      }
      base.isPtrReceiver = symbol.isPtrReceiver;
      return;
    }
    if (base is FieldExpr) {
      _requireMutablePlace(
        base.object,
        pos,
        immutableVarMessage: immutableVarMessage,
        immutableExprMessage: immutableExprMessage,
      );
      return;
    }
    if (base is IndexExpr) {
      if (_inferExpr(base.object) is SliceType) return;
      _requireMutablePlace(
        base.object,
        pos,
        immutableVarMessage: immutableVarMessage,
        immutableExprMessage: immutableExprMessage,
      );
      return;
    }
    if (base is UnaryExpr && base.op == '*') {
      final pointer = _inferExpr(base.operand);
      if (pointer is! PtrType) {
        throw CheckError('dereference requires a pointer', pos);
      }
      if (!pointer.isMut) {
        throw CheckError('cannot write through an immutable pointer', pos);
      }
      return;
    }
    throw CheckError(immutableExprMessage, pos);
  }

  Expr _unwrapGroups(Expr expr) {
    var current = expr;
    while (current is GroupExpr) {
      current = current.inner;
    }
    return current;
  }

  bool _returnsOnAllPaths(Block block) {
    for (final stmt in block.stmts) {
      if (_stmtReturns(stmt)) return true;
    }
    return false;
  }

  bool _stmtReturns(Stmt stmt) => switch (stmt) {
        ReturnStmt() => true,
        BlockStmt(:final block) => _returnsOnAllPaths(block),
        IfStmt(:final thenBlock, :final elseBranch) => elseBranch != null &&
            _returnsOnAllPaths(thenBlock) &&
            _stmtReturns(elseBranch),
        MatchStmt(:final arms) => arms.isNotEmpty &&
            arms.last.pattern is ElsePattern &&
            arms.every((arm) => _returnsOnAllPaths(arm.body)),
        _ => false,
      };

  /// Infers without context; may return an untyped type.
  KlinType _inferExpr(Expr expr) {
    final type = switch (expr) {
      IntLit() => const UntypedInt(),
      FloatLit() => const UntypedFloat(),
      BoolLit() => const PrimType(PrimKind.bool_),
      StringLit() => const StrType(),
      InterpolatedStringExpr(:final pos) => throw CheckError(
          'interpolated string is print-only in MVP '
          '(use as the sole argument to puts / printf / io.print / io.println)',
          pos,
        ),
      NameExpr nameExpr => () {
          final sym = _scope.lookup(nameExpr.name);
          if (sym != null) {
            nameExpr.isPtrReceiver = sym.isPtrReceiver;
            nameExpr.resolvedDef =
                ResolvedDef(sym.pos, _currentSourcePath);
            return sym.type;
          }
          final fnType = _fnTypeForName(nameExpr.name, nameExpr.pos);
          if (fnType != null) {
            nameExpr.resolvedFnCName = fnType.cName;
            final decl = _functionDecl(_currentModule, nameExpr.name);
            nameExpr.resolvedDef =
                ResolvedDef(decl.pos, decl.sourcePath);
            return fnType.type;
          }
          throw CheckError(
              'nieznana zmienna `${nameExpr.name}`', nameExpr.pos);
        }(),
      FieldExpr fieldExpr => () {
          final object = fieldExpr.object;
          final name = fieldExpr.name;
          final pos = fieldExpr.pos;
          // `Enum.Variant`: a type name (not a variable) followed by a variant.
          final enumConst = _tryEnumConstant(fieldExpr, object, name, pos);
          if (enumConst != null) return enumConst;
          final objectType = _inferExpr(object);
          if (name == 'len' && objectType is ArrayType) {
            return const PrimType(PrimKind.i32);
          }
          if (name == 'len' && objectType is SliceType) {
            return const PrimType(PrimKind.i32);
          }
          if (objectType is! StructType) {
            throw CheckError(
                'field access requires a struct, got `${objectType.displayName}`',
                pos);
          }
          FieldDecl? field;
          final struct =
              _structs[_key(objectType.moduleName, objectType.name)]!;
          for (final candidate in struct.fields) {
            if (candidate.name == name) {
              field = candidate;
              break;
            }
          }
          if (field == null) {
            throw CheckError(
                'struct `${objectType.name}` has no field `$name`', pos);
          }
          fieldExpr.resolvedDef =
              ResolvedDef(field.pos, struct.sourcePath);
          return field.resolvedType!;
        }(),
      IndexExpr(:final object, :final index, :final pos) => () {
          final objectType = _inferExpr(object);
          final indexType = _defaultConcrete(_inferExpr(index), index.pos);
          if (indexType is! PrimType || !indexType.kind.isInteger) {
            throw CheckError('index requires an integer type', index.pos);
          }
          _materialize(index, indexType);
          return switch (objectType) {
            ArrayType(:final elem) => elem,
            SliceType(:final elem) => elem,
            _ => throw CheckError(
                'indexing requires an array or slice, got `${objectType.displayName}`',
                pos,
              ),
          };
        }(),
      SliceFromExpr(:final array, :final pos) => () {
          if (!_isAddressablePlace(array)) {
            throw CheckError(
              '`[:]` requires an array l-value, not a literal or temporary expression',
              pos,
            );
          }
          final arrayType = _inferExpr(array);
          if (arrayType is! ArrayType || arrayType.elem is! PrimType) {
            throw CheckError(
                '`[:]` requires an array with a primitive element type', pos);
          }
          return SliceType(arrayType.elem as PrimType);
        }(),
      ArrayLitExpr(:final elements, :final pos) => () {
          if (elements.isEmpty) {
            throw CheckError('cannot infer the type of an empty array', pos);
          }
          var elemType = _inferExpr(elements.first);
          for (final element in elements.skip(1)) {
            final nextType = _inferExpr(element);
            elemType = (elemType is PrimType ||
                        elemType is UntypedInt ||
                        elemType is UntypedFloat) &&
                    (nextType is PrimType ||
                        nextType is UntypedInt ||
                        nextType is UntypedFloat)
                ? _unifyNumeric(elemType, nextType, element.pos)
                : (elemType == nextType
                    ? elemType
                    : throw CheckError(
                        'array element type mismatch: `${elemType.displayName}` and `${nextType.displayName}`',
                        element.pos,
                      ));
          }
          elemType = _defaultConcrete(elemType, pos);
          for (final element in elements) {
            _expectAssignable(elemType, _inferExpr(element), element.pos);
            _materialize(element, elemType);
          }
          return ArrayType(elemType, elements.length);
        }(),
      CastExpr(:final typeName, :final expr, :final pos) => () {
          final target = _resolveType(typeName, pos);
          final source = _inferExpr(expr);
          if (target is PtrType) {
            if (source is! UntypedInt &&
                source is! PrimType &&
                source is! PtrType) {
              throw CheckError(
                  'pointer cast requires an integer or pointer', pos);
            }
            return target;
          }
          // Explicit enum <-> integer conversion (issue 072).
          if (target is EnumType) {
            final concrete = _defaultConcrete(source, expr.pos);
            if (concrete is! PrimType || !concrete.kind.isInteger) {
              throw CheckError('cast to enum requires an integer', pos);
            }
            _materialize(expr, concrete);
            return target;
          }
          if (target is PrimType &&
              target.kind.isInteger &&
              source is EnumType) {
            return target;
          }
          throw CheckError(
              'MVP cast supports pointer or enum/integer conversions', pos);
        }(),
      MethodCallExpr() => _checkMethodCall(expr),
      StructLitExpr(
        :final moduleName,
        :final typeName,
        :final namedFields,
        :final positionalFields,
        :final pos
      ) =>
        () {
          final module = moduleName == null
              ? _currentModule
              : _resolveModuleQualifier(moduleName, pos);
          final struct = _structs[_key(module, typeName)];
          if (struct == null) {
            final shown =
                moduleName == null ? typeName : '$moduleName.$typeName';
            throw CheckError('unknown struct `$shown`', pos);
          }
          if (module != _currentModule && !struct.isPub) {
            final shown = moduleName ?? module;
            throw CheckError('struct `$shown.$typeName` is private', pos);
          }
          if (namedFields != null) {
            if (namedFields.length != struct.fields.length) {
              throw CheckError('literal `$typeName` requires all fields', pos);
            }
            for (final field in struct.fields) {
              final value = namedFields[field.name];
              if (value == null)
                throw CheckError(
                    'missing field `${field.name}` in literal', pos);
              _expectAssignable(
                  field.resolvedType!, _inferExpr(value), value.pos);
              _materialize(value, field.resolvedType!);
            }
          } else {
            final values = positionalFields!;
            if (values.length != struct.fields.length) {
              throw CheckError(
                  'literal `$typeName` expects ${struct.fields.length} fields',
                  pos);
            }
            for (var i = 0; i < values.length; i++) {
              _expectAssignable(struct.fields[i].resolvedType!,
                  _inferExpr(values[i]), values[i].pos);
              _materialize(values[i], struct.fields[i].resolvedType!);
            }
          }
          return StructType(module, typeName);
        }(),
      CallExpr(:final moduleName, :final callee, :final args, :final pos) =>
        () {
          if (_tryCheckInterpPrint(moduleName, callee, args, pos,
              onResolved: (cName) => expr.resolvedCallee = cName)) {
            // printf returns i32; treat like FFI.
            return const PrimType(PrimKind.i32);
          }
          final spawn = _tryCheckAsyncSpawn(moduleName, callee, args, pos);
          if (spawn != null) {
            expr.resolvedCallee = spawn.spawnCName;
            expr.asyncSpawnFn = spawn.asyncFnBase;
            return spawn.returnType;
          }
          final call = _checkCall(callee, args, pos, moduleName: moduleName);
          expr.resolvedCallee = call.cName;
          expr.resolvedDef = call.def;
          if (call.isAsync) {
            // Async calls are only valid as `.await` operands (handled there).
            throw CheckError(
              'async function `$callee` can only be used with `.await`',
              pos,
            );
          }
          if (call.type is VoidType) {
            throw CheckError(
              'result of void function `$callee` cannot be used as a value',
              pos,
            );
          }
          return call.type;
        }(),
      AwaitExpr() => () {
          if (!_currentIsAsync) {
            throw CheckError(
              '`.await` is only allowed inside `async fn`',
              expr.pos,
            );
          }
          return _checkAwait(expr);
        }(),
      ErrorExpr(:final code, :final pos) => () {
          final current = _currentReturn;
          if (current is! ResultType) {
            throw CheckError(
                '`error(...)` requires a function returning `!T`', pos);
          }
          final codeType = _inferExpr(code);
          _expectAssignable(const PrimType(PrimKind.i32), codeType, code.pos);
          _materialize(code, const PrimType(PrimKind.i32));
          return current;
        }(),
      PropagateExpr(:final result, :final pos) => () {
          final resultType = _inferExpr(result);
          if (resultType is! ResultType) {
            throw CheckError('postfix operator `!` requires a `!T` value', pos);
          }
          if (_currentReturn is! ResultType) {
            throw CheckError(
              'postfix operator `!` requires a function returning `!T`',
              pos,
            );
          }
          return resultType.ok;
        }(),
      OrExpr(:final result, :final fallback, :final pos) => () {
          final resultType = _inferExpr(result);
          if (resultType is! ResultType) {
            throw CheckError('left side of `or` must have type `!T`', pos);
          }
          _scope = _Scope(_scope);
          try {
            _scope.define(
              _Symbol(
                name: 'err',
                type: const PrimType(PrimKind.i32),
                isMut: false,
                pos: fallback.pos,
              ),
            );
            for (final stmt in fallback.stmts) {
              _checkStmt(stmt);
            }
            final fallbackType = _inferExpr(fallback.value);
            _expectAssignable(resultType.ok, fallbackType, fallback.value.pos);
            _materialize(fallback.value, resultType.ok);
          } finally {
            _scope = _scope.parent!;
          }
          return resultType.ok;
        }(),
      UnaryExpr(:final op, :final operand, :final pos) => () {
          if (op == '&') {
            if (!_isAddressablePlace(operand)) {
              throw CheckError(
                  'operator `&` requires an addressable location', pos);
            }
            final pointee = _inferExpr(operand);
            return PtrType(
              pointee,
              isMut: _isMutablePlace(operand),
            );
          }
          if (op == '*') {
            final pointer = _inferExpr(operand);
            if (pointer is! PtrType) {
              throw CheckError('dereference requires a pointer', pos);
            }
            return pointer.pointee;
          }
          if (op == '!') {
            final t = _inferExpr(operand);
            if (t is! PrimType || t.kind != PrimKind.bool_) {
              throw CheckError(
                'operator `!` requires type `bool`, got `${t.displayName}`',
                pos,
              );
            }
            return const PrimType(PrimKind.bool_);
          }
          if (op == '~') {
            final t = _inferExpr(operand);
            final concrete = _defaultConcrete(t, operand.pos);
            if (concrete is! PrimType || !concrete.kind.isInteger) {
              throw CheckError(
                'operator `~` requires an integer type, got `${concrete.displayName}`',
                pos,
              );
            }
            _materialize(operand, concrete);
            return concrete;
          }
          if (op != '-') {
            throw CheckError('unknown unary operator `$op`', pos);
          }
          final t = _inferExpr(operand);
          final concrete = _defaultConcrete(t, operand.pos);
          if (concrete is! PrimType ||
              !(concrete.kind.isInteger || concrete.kind.isFloat)) {
            throw CheckError(
              'operator `-` requires a numeric type, got `${concrete.displayName}`',
              pos,
            );
          }
          if (_isUnsigned(concrete.kind)) {
            throw CheckError(
              'operator `-` is not allowed for unsigned type `${concrete.displayName}`',
              pos,
            );
          }
          _materialize(operand, concrete);
          return concrete;
        }(),
      BinaryExpr(:final left, :final op, :final right, :final pos) =>
        _inferBinary(left, op, right, pos),
      GroupExpr(:final inner) => _inferExpr(inner),
      MatchExpr(:final subject, :final arms, :final pos) =>
        _inferMatchExpr(subject, arms, pos),
      PickExpr(:final cond, :final thenExpr, :final elseExpr, :final pos) =>
        _inferPickExpr(cond, thenExpr, elseExpr, pos),
    };
    if (type is PrimType ||
        type is StrType ||
        type is StructType ||
        type is EnumType ||
        type is PtrType ||
        type is ArrayType ||
        type is SliceType ||
        type is ResultType ||
        type is FnType ||
        type is VoidType) {
      expr.resolvedType = type;
    }
    return type;
  }

  bool _isMutablePlace(Expr expr) {
    final place = _unwrapGroups(expr);
    if (place is NameExpr) return _scope.lookup(place.name)?.isMut ?? false;
    if (place is FieldExpr) return _isMutablePlace(place.object);
    if (place is IndexExpr) return _isMutablePlace(place.object);
    return false;
  }

  bool _isAddressablePlace(Expr expr) {
    final place = _unwrapGroups(expr);
    return place is NameExpr || place is FieldExpr || place is IndexExpr;
  }

  static const _cmpOps = {'==', '!=', '<', '<=', '>', '>='};
  static const _arithOps = {'+', '-', '*', '/', '%'};
  static const _bitOps = {'&', '|', '^'};
  static const _shiftOps = {'<<', '>>'};
  static const _logicalOps = {'&&', '||'};

  KlinType _inferBinary(Expr left, String op, Expr right, SourcePos pos) {
    if (_logicalOps.contains(op)) {
      return _inferLogical(left, op, right, pos);
    }
    if (_cmpOps.contains(op)) {
      return _inferComparison(left, op, right, pos);
    }
    if (_bitOps.contains(op)) {
      return _inferBitwise(left, op, right, pos);
    }
    if (_shiftOps.contains(op)) {
      return _inferShift(left, op, right, pos);
    }
    if (!_arithOps.contains(op)) {
      throw CheckError('unknown operator `$op`', pos);
    }

    final lt = _inferExpr(left);
    final rt = _inferExpr(right);
    final unified = _unifyNumeric(lt, rt, pos);
    final concrete = unified is UntypedInt || unified is UntypedFloat
        ? _defaultConcrete(unified, pos)
        : unified;

    if (concrete is! PrimType ||
        !(concrete.kind.isInteger || concrete.kind.isFloat)) {
      throw CheckError(
        'operator `$op` requires numeric types, got `${concrete.displayName}`',
        pos,
      );
    }

    if (op == '%' && !concrete.kind.isInteger) {
      throw CheckError(
        'operator `%` requires integer types, got `${concrete.displayName}`',
        pos,
      );
    }

    _materialize(left, concrete);
    _materialize(right, concrete);
    return concrete;
  }

  /// Logical `&&` / `||` — both sides `bool`; short-circuit via C emission (097).
  KlinType _inferLogical(Expr left, String op, Expr right, SourcePos pos) {
    final lt = _inferExpr(left);
    final rt = _inferExpr(right);
    if (lt is! PrimType || lt.kind != PrimKind.bool_) {
      throw CheckError(
        'operator `$op` requires type `bool`, got `${lt.displayName}`',
        left.pos,
      );
    }
    if (rt is! PrimType || rt.kind != PrimKind.bool_) {
      throw CheckError(
        'operator `$op` requires type `bool`, got `${rt.displayName}`',
        right.pos,
      );
    }
    return const PrimType(PrimKind.bool_);
  }

  /// Bitwise `&` / `|` / `^` — integers only (issue 078).
  KlinType _inferBitwise(Expr left, String op, Expr right, SourcePos pos) {
    final lt = _inferExpr(left);
    final rt = _inferExpr(right);
    final unified = _unifyNumeric(lt, rt, pos);
    final concrete = unified is UntypedInt || unified is UntypedFloat
        ? _defaultConcrete(unified, pos)
        : unified;
    if (concrete is! PrimType || !concrete.kind.isInteger) {
      throw CheckError(
        'operator `$op` requires integer types, got `${concrete.displayName}`',
        pos,
      );
    }
    _materialize(left, concrete);
    _materialize(right, concrete);
    return concrete;
  }

  /// Shifts `<<` / `>>` — both sides integers; result type is the left side.
  /// Signed `>>` is arithmetic (two's complement C); unsigned is logical.
  KlinType _inferShift(Expr left, String op, Expr right, SourcePos pos) {
    final lt = _inferExpr(left);
    final rt = _inferExpr(right);
    final leftConcrete = _defaultConcrete(lt, left.pos);
    final rightConcrete = _defaultConcrete(rt, right.pos);
    if (leftConcrete is! PrimType || !leftConcrete.kind.isInteger) {
      throw CheckError(
        'operator `$op` requires an integer left operand, got `${leftConcrete.displayName}`',
        pos,
      );
    }
    if (rightConcrete is! PrimType || !rightConcrete.kind.isInteger) {
      throw CheckError(
        'operator `$op` requires an integer shift count, got `${rightConcrete.displayName}`',
        pos,
      );
    }
    _materialize(left, leftConcrete);
    _materialize(right, rightConcrete);
    return leftConcrete;
  }

  KlinType _inferComparison(Expr left, String op, Expr right, SourcePos pos) {
    final lt = _inferExpr(left);
    final rt = _inferExpr(right);

    // bool == bool / !=
    if (lt is PrimType &&
        lt.kind == PrimKind.bool_ &&
        rt is PrimType &&
        rt.kind == PrimKind.bool_) {
      if (op != '==' && op != '!=') {
        throw CheckError(
          'operator `$op` is not allowed for type `bool`',
          pos,
        );
      }
      return const PrimType(PrimKind.bool_);
    }

    // enum == enum / != (same type only); ordering is not defined for enums.
    if (lt is EnumType || rt is EnumType) {
      if (lt != rt) {
        throw CheckError(
          'cannot compare `${lt.displayName}` with `${rt.displayName}`',
          pos,
        );
      }
      if (op != '==' && op != '!=') {
        throw CheckError(
          'operator `$op` is not allowed for enum `${lt.displayName}`',
          pos,
        );
      }
      return const PrimType(PrimKind.bool_);
    }

    final unified = _unifyNumeric(lt, rt, pos);
    final concrete = unified is UntypedInt || unified is UntypedFloat
        ? _defaultConcrete(unified, pos)
        : unified;

    if (concrete is! PrimType ||
        !(concrete.kind.isInteger || concrete.kind.isFloat)) {
      throw CheckError(
        'operator `$op` requires numeric types, got `${concrete.displayName}`',
        pos,
      );
    }

    _materialize(left, concrete);
    _materialize(right, concrete);
    return const PrimType(PrimKind.bool_);
  }

  KlinType _unifyNumeric(KlinType lt, KlinType rt, SourcePos pos) {
    if (lt is UntypedInt && rt is UntypedInt) {
      return const UntypedInt();
    } else if (lt is UntypedFloat && rt is UntypedFloat) {
      return const UntypedFloat();
    } else if (lt is UntypedInt && rt is UntypedFloat) {
      return const UntypedFloat();
    } else if (lt is UntypedFloat && rt is UntypedInt) {
      return const UntypedFloat();
    } else if (lt is UntypedInt && rt is PrimType && rt.kind.isInteger) {
      return rt;
    } else if (rt is UntypedInt && lt is PrimType && lt.kind.isInteger) {
      return lt;
    } else if (lt is UntypedFloat && rt is PrimType && rt.kind.isFloat) {
      return rt;
    } else if (rt is UntypedFloat && lt is PrimType && lt.kind.isFloat) {
      return lt;
    } else if (lt is UntypedInt && rt is PrimType && rt.kind.isFloat) {
      return rt;
    } else if (rt is UntypedInt && lt is PrimType && lt.kind.isFloat) {
      return lt;
    } else if (lt == rt) {
      return lt;
    } else {
      throw CheckError(
        'type mismatch: `${lt.displayName}` and `${rt.displayName}`',
        pos,
      );
    }
  }

  /// Assigns a concrete type to an expression and recursively to subtrees
  /// containing untyped literals.
  void _materialize(Expr expr, KlinType type) {
    // `cast(T, x)` preserves its explicit type T; do not overwrite it from an outer context.
    if (expr is CastExpr) return;
    if (type is SliceType && expr.resolvedType is ArrayType) {
      expr.arrayToSliceFrom = expr.resolvedType as ArrayType;
    }
    expr.resolvedType = type;
    switch (expr) {
      case UnaryExpr(:final operand, :final op):
        if (op != '&' && op != '*') _materialize(operand, type);
      case BinaryExpr(:final left, :final right, :final op):
        if (_cmpOps.contains(op) || _logicalOps.contains(op)) {
          // Comparison / logical nodes are bool; operands already typed.
          // Do not push the outer bool into numeric comparison operands.
          break;
        }
        _materialize(left, type);
        _materialize(right, type);
      case GroupExpr(:final inner):
        _materialize(inner, type);
      case PropagateExpr() || OrExpr() || ErrorExpr() || AwaitExpr():
        break;
      case IntLit() ||
            FloatLit() ||
            BoolLit() ||
            StringLit() ||
            InterpolatedStringExpr() ||
            NameExpr() ||
            CallExpr() ||
            FieldExpr() ||
            MethodCallExpr() ||
            StructLitExpr() ||
            IndexExpr() ||
            SliceFromExpr() ||
            CastExpr():
        break;
      case ArrayLitExpr(:final elements):
        if (type is! ArrayType) break;
        for (final element in elements) {
          _expectAssignable(type.elem, _inferExpr(element), element.pos);
          _materialize(element, type.elem);
        }
      case MatchExpr(:final arms):
        for (final arm in arms) {
          _materialize(arm.body, type);
        }
      case PickExpr(:final thenExpr, :final elseExpr):
        _materialize(thenExpr, type);
        _materialize(elseExpr, type);
    }
  }

  KlinType _inferPickExpr(
    Expr cond,
    Expr thenExpr,
    Expr elseExpr,
    SourcePos pos,
  ) {
    _expectBoolCond(cond);
    _forbidStmtLoweringInPick(cond, 'condition');
    _forbidStmtLoweringInPick(thenExpr, 'then-expression');
    _forbidStmtLoweringInPick(elseExpr, 'else-expression');
    final thenType = _inferExpr(thenExpr);
    final elseType = _inferExpr(elseExpr);
    final unified = _unifyNumeric(thenType, elseType, pos);
    final concrete = _defaultConcrete(unified, pos);
    _materialize(thenExpr, concrete);
    _materialize(elseExpr, concrete);
    return concrete;
  }

  /// `pick` emits as a C ternary, so arms cannot contain forms that lower to
  /// statements (`match` / `or` / `!`).
  void _forbidStmtLoweringInPick(Expr expr, String role) {
    void walk(Expr e) {
      final node = _unwrapGroups(e);
      if (node is MatchExpr || node is OrExpr || node is PropagateExpr) {
        final kind = switch (node) {
          MatchExpr() => '`match`',
          OrExpr() => '`or`',
          PropagateExpr() => '`!`',
          _ => 'this expression',
        };
        throw CheckError(
          '`pick` $role cannot contain $kind (it emits as a C ternary)',
          node.pos,
        );
      }
      switch (node) {
        case PickExpr(:final cond, :final thenExpr, :final elseExpr):
          walk(cond);
          walk(thenExpr);
          walk(elseExpr);
        case BinaryExpr(:final left, :final right):
          walk(left);
          walk(right);
        case UnaryExpr(:final operand):
          walk(operand);
        case CallExpr(:final args):
          for (final arg in args) {
            walk(arg);
          }
        case MethodCallExpr(:final receiver, :final args):
          walk(receiver);
          for (final arg in args) {
            walk(arg);
          }
        case FieldExpr(:final object):
          walk(object);
        case IndexExpr(:final object, :final index):
          walk(object);
          walk(index);
        case SliceFromExpr(:final array):
          walk(array);
        case ArrayLitExpr(:final elements):
          for (final element in elements) {
            walk(element);
          }
        case CastExpr(:final expr):
          walk(expr);
        case StructLitExpr(:final namedFields, :final positionalFields):
          if (namedFields != null) {
            for (final value in namedFields.values) {
              walk(value);
            }
          }
          if (positionalFields != null) {
            for (final value in positionalFields) {
              walk(value);
            }
          }
        case InterpolatedStringExpr(:final parts):
          for (final part in parts) {
            if (part is InterpSlot) walk(part.expr);
          }
        case ErrorExpr(:final code):
          walk(code);
        case AwaitExpr(:final operand):
          walk(operand);
        default:
          break;
      }
    }

    walk(expr);
  }

  /// Infers a `let` initializer / assignment RHS. `match` is allowed only when
  /// it *is* that value (optionally wrapped in groups), not nested inside
  /// arithmetic, call arguments, etc.
  KlinType _inferLetOrAssignValue(Expr value) {
    if (_unwrapGroups(value) is MatchExpr) {
      return _withMatchExprAllowed(() => _inferExpr(value));
    }
    return _inferExpr(value);
  }

  /// Runs [fn] with `match` allowed as an expression (see
  /// [_inferLetOrAssignValue]).
  T _withMatchExprAllowed<T>(T Function() fn) {
    final saved = _allowMatchExpr;
    _allowMatchExpr = true;
    try {
      return fn();
    } finally {
      _allowMatchExpr = saved;
    }
  }

  void _checkMatchSubject(Expr subject) {
    final subjectType = _inferExpr(subject);
    final concrete = _defaultConcrete(subjectType, subject.pos);
    if (concrete is EnumType) {
      _materialize(subject, concrete);
      return;
    }
    if (concrete is! PrimType || !concrete.kind.isInteger) {
      throw CheckError(
        '`match` requires an integer or enum subject, '
        'got `${concrete.displayName}`',
        subject.pos,
      );
    }
    _materialize(subject, concrete);
  }

  void _checkMatchArmsOrder(List<MatchPattern> patterns) {
    for (var i = 0; i < patterns.length; i++) {
      final pattern = patterns[i];
      if (pattern is ElsePattern) {
        if (i != patterns.length - 1) {
          throw CheckError(
            '`else` must be the last arm of `match`',
            pattern.pos,
          );
        }
      }
    }
  }

  void _checkMatchPattern(MatchPattern pattern, KlinType subjectType) {
    switch (pattern) {
      case LitPattern(:final values):
        for (final value in values) {
          final valueType = _inferExpr(value);
          _expectAssignable(subjectType, valueType, value.pos);
          _materialize(value, subjectType);
        }
      case RangePattern(:final start, :final endInclusive):
        if (subjectType is EnumType) {
          throw CheckError(
            'range patterns are not allowed for enum `${subjectType.displayName}`',
            start.pos,
          );
        }
        final startType = _inferExpr(start);
        final endType = _inferExpr(endInclusive);
        _expectAssignable(subjectType, startType, start.pos);
        _expectAssignable(subjectType, endType, endInclusive.pos);
        _materialize(start, subjectType);
        _materialize(endInclusive, subjectType);
      case RelPattern(:final rhs, :final pos):
        if (subjectType is EnumType) {
          throw CheckError(
            'relational patterns are not allowed for enum `${subjectType.displayName}`',
            pos,
          );
        }
        final rhsType = _inferExpr(rhs);
        _expectAssignable(subjectType, rhsType, rhs.pos);
        _materialize(rhs, subjectType);
      case WildPattern():
        break;
      case ElsePattern():
        break;
    }
  }

  KlinType _inferMatchExpr(
    Expr subject,
    List<MatchExprArm> arms,
    SourcePos pos,
  ) {
    if (!_allowMatchExpr) {
      throw CheckError(
        '`match` as an expression is only allowed as a `let` initializer or an assignment right-hand side',
        pos,
      );
    }
    if (arms.isEmpty || arms.last.pattern is! ElsePattern) {
      throw CheckError(
        '`match` as an expression requires an `else` arm as the last arm',
        pos,
      );
    }
    _checkMatchSubject(subject);
    final subjectType = subject.resolvedType!;
    _checkMatchArmsOrder(arms.map((a) => a.pattern).toList());

    KlinType? resultType;
    // Arm bodies are ordinary expressions — not a fresh let/assign root —
    // so nested `match` expressions stay forbidden here.
    final savedAllow = _allowMatchExpr;
    _allowMatchExpr = false;
    try {
      for (final arm in arms) {
        if (arm.pattern is! ElsePattern) {
          _checkMatchPattern(arm.pattern, subjectType);
        }
        final when = arm.when;
        if (when != null) {
          _expectBoolCond(when);
        }
        final bodyType = _inferExpr(arm.body);
        resultType = resultType == null
            ? bodyType
            : _unifyNumeric(resultType, bodyType, arm.body.pos);
      }
    } finally {
      _allowMatchExpr = savedAllow;
    }

    final concrete = _defaultConcrete(resultType!, pos);
    for (final arm in arms) {
      _materialize(arm.body, concrete);
    }
    return concrete;
  }

  void _expectAssignable(KlinType target, KlinType source, SourcePos pos) {
    if (!_isAssignable(target, source)) {
      throw CheckError(
        'type mismatch: expected `${target.displayName}`, '
        'got `${source.displayName}`',
        pos,
      );
    }
  }

  bool _isAssignable(KlinType target, KlinType source) {
    if (target == source) return true;
    if (source is UntypedInt && target is PrimType && target.kind.isInteger) {
      return true;
    }
    if (source is UntypedFloat && target is PrimType && target.kind.isFloat) {
      return true;
    }
    if (source is UntypedInt && target is PrimType && target.kind.isFloat) {
      return true;
    }
    if (target is SliceType &&
        source is ArrayType &&
        source.elem == target.elem) {
      return true;
    }
    if (target is PtrType &&
        source is PtrType &&
        target.pointee == source.pointee &&
        target.isVolatile == source.isVolatile &&
        (!target.isMut || source.isMut)) {
      return true;
    }
    if (target is FnType && source is FnType && target == source) {
      return true;
    }
    return false;
  }

  KlinType _defaultConcrete(KlinType type, SourcePos pos) {
    return switch (type) {
      UntypedInt() => const PrimType(PrimKind.i32),
      UntypedFloat() => const PrimType(PrimKind.f64),
      PrimType() => type,
      StructType() => type,
      EnumType() => type,
      PtrType() => type,
      ArrayType() => type,
      SliceType() => type,
      FnType() => type,
      ResultType() => type,
      VoidType() => throw CheckError(
          'cannot use a void value in this context',
          pos,
        ),
      StrType() => throw CheckError(
          'cannot use a string in this context',
          pos,
        ),
    };
  }

  static bool _isUnsigned(PrimKind kind) => switch (kind) {
        PrimKind.u8 ||
        PrimKind.u16 ||
        PrimKind.u32 ||
        PrimKind.u64 ||
        PrimKind.usize =>
          true,
        _ => false,
      };
}
