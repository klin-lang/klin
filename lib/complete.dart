import 'analyze.dart';
import 'ast.dart';
import 'token.dart';
import 'type.dart';

/// Kind of a completion candidate (mapped to LSP CompletionItemKind).
enum KlinCompletionKind {
  keyword,
  function,
  method,
  struct,
  enumType,
  enumMember,
  field,
  variable,
  type,
}

final class KlinCompletionItem {
  final String label;
  final KlinCompletionKind kind;
  final String? detail;

  const KlinCompletionItem({
    required this.label,
    required this.kind,
    this.detail,
  });
}

const _keywords = <String>[
  'fn',
  'struct',
  'enum',
  'pub',
  'module',
  'import',
  'let',
  'mut',
  'cast',
  'volatile',
  'true',
  'false',
  'if',
  'else',
  'while',
  'for',
  'in',
  'return',
  'break',
  'continue',
  'defer',
  'or',
  'error',
  'asm',
  'match',
  'when',
  'pick',
  'async',
  'await',
];

const _primTypes = <String>[
  'i8',
  'i16',
  'i32',
  'i64',
  'u8',
  'u16',
  'u32',
  'u64',
  'f32',
  'f64',
  'bool',
  'usize',
  'isize',
  'int',
  'float',
  'void',
  'str',
];

/// Completions at 1-based [line]/[col] (cursor = insertion point).
///
/// When [trigger] is `'.'` or the buffer before the cursor ends with `.`
/// (optionally followed by a partial member name), returns member
/// completions. Prefer [fallbackProgram] when the current analysis has
/// parse errors (typical after typing `x.`, or after parse recovery).
///
/// Otherwise: keywords, primitive types, top-level decls, and locals.
/// Empty when [AnalysisResult.positionsSkewed].
List<KlinCompletionItem> completeAt(
  AnalysisResult result,
  int line,
  int col, {
  String? trigger,
  String? source,
  Program? fallbackProgram,
}) {
  if (result.positionsSkewed) return const [];

  final program = result.hasParseErrors
      ? (fallbackProgram ?? result.program)
      : (result.program ?? fallbackProgram);
  final text = source ?? '';
  final offset = _offsetOf(text, line, col);
  final before = offset <= text.length ? text.substring(0, offset) : text;
  final dot = trigger == '.' || _endsWithDot(before);
  final prefix = _identPrefix(before);

  // Editor coords for buffer prefix; expanded coords for AST scope walks.
  final map = result.sourceMap;
  final query = map != null
      ? map.toExpanded(SourcePos(line, col))
      : SourcePos(line, col);
  final qLine = query.line;
  final qCol = query.col;

  if (dot) {
    if (program == null) return const [];
    return _filterPrefix(
      _memberCompletions(program, before, qLine, qCol),
      prefix,
    );
  }

  final items = <KlinCompletionItem>[
    ..._keywordItems(),
    ..._primTypeItems(),
  ];
  if (program != null) {
    items.addAll(_topLevelItems(program));
    items.addAll(_localsAt(program, qLine, qCol));
  }
  return _dedupe(_filterPrefix(items, prefix));
}

List<KlinCompletionItem> _keywordItems() => [
      for (final k in _keywords)
        KlinCompletionItem(label: k, kind: KlinCompletionKind.keyword),
    ];

List<KlinCompletionItem> _primTypeItems() => [
      for (final t in _primTypes)
        KlinCompletionItem(label: t, kind: KlinCompletionKind.type),
    ];

List<KlinCompletionItem> _topLevelItems(Program program) {
  final out = <KlinCompletionItem>[];
  for (final f in program.funcs) {
    if (f.receiver != null || f.associatedType != null) continue;
    if (f.attrs.any((a) => a.name == 'cimport')) continue;
    out.add(
      KlinCompletionItem(
        label: f.name,
        kind: KlinCompletionKind.function,
        detail: _funcDetail(f),
      ),
    );
  }
  for (final s in program.structs) {
    out.add(
      KlinCompletionItem(
        label: s.name,
        kind: KlinCompletionKind.struct,
        detail: 'struct',
      ),
    );
  }
  for (final e in program.enums) {
    out.add(
      KlinCompletionItem(
        label: e.name,
        kind: KlinCompletionKind.enumType,
        detail: 'enum',
      ),
    );
  }
  return out;
}

String _funcDetail(FuncDecl f) {
  final params = f.params.map((p) => p.typeName).join(', ');
  final ret = f.returnTypeName ?? 'void';
  return 'fn($params): $ret';
}

List<KlinCompletionItem> _localsAt(Program program, int line, int col) {
  final f = _enclosingFunc(program, line, col);
  if (f == null) return const [];
  final map = <String, KlinCompletionItem>{};
  final receiver = f.receiver;
  if (receiver != null) {
    map[receiver.name] = KlinCompletionItem(
      label: receiver.name,
      kind: KlinCompletionKind.variable,
      detail: receiver.resolvedType?.displayName ?? receiver.typeName,
    );
  }
  for (final p in f.params) {
    map[p.name] = KlinCompletionItem(
      label: p.name,
      kind: KlinCompletionKind.variable,
      detail: p.resolvedType?.displayName ?? p.typeName,
    );
  }
  final body = f.body;
  if (body != null) {
    _collectLocalsInBlock(body, line, col, map);
  }
  return map.values.toList();
}

/// Top-level function whose source range contains [line]/[col].
///
/// Functions are ordered by declaration position; the enclosing one is the
/// last whose `pos` is at or before the cursor.
FuncDecl? _enclosingFunc(Program program, int line, int col) {
  FuncDecl? best;
  for (final f in program.funcs) {
    if (_isBefore(line, col, f.pos)) continue;
    if (best == null || !_posBefore(f.pos, best.pos)) {
      best = f;
    }
  }
  return best;
}

/// True when [a] is strictly before [b] in source order.
bool _posBefore(SourcePos a, SourcePos b) {
  if (a.line != b.line) return a.line < b.line;
  return a.col < b.col;
}

void _collectLocalsInBlock(
  Block block,
  int line,
  int col,
  Map<String, KlinCompletionItem> map,
) {
  final stmts = block.stmts;
  for (var i = 0; i < stmts.length; i++) {
    final s = stmts[i];
    if (_isBefore(line, col, s.pos)) break;
    final endExclusive = i + 1 < stmts.length ? stmts[i + 1].pos : null;
    final nestedVisible =
        endExclusive == null || _isBefore(line, col, endExclusive);
    _collectLocalsInStmt(s, line, col, map, nestedVisible: nestedVisible);
  }
}

void _collectLocalsInStmt(
  Stmt s,
  int line,
  int col,
  Map<String, KlinCompletionItem> map, {
  required bool nestedVisible,
}) {
  switch (s) {
    case LetStmt(:final name, :final resolvedType, :final typeName, :final pos):
      if (line > pos.line || (line == pos.line && col > pos.col)) {
        map[name] = KlinCompletionItem(
          label: name,
          kind: KlinCompletionKind.variable,
          detail: resolvedType?.displayName ?? typeName,
        );
      }
    case LetDestructureStmt(:final binds, :final fieldTypes, :final pos):
      if (!_isBefore(line, col, pos)) {
        for (var i = 0; i < binds.length; i++) {
          final b = binds[i];
          if (b == '_') continue;
          map[b] = KlinCompletionItem(
            label: b,
            kind: KlinCompletionKind.variable,
            detail: fieldTypes != null && i < fieldTypes.length
                ? fieldTypes[i].displayName
                : null,
          );
        }
      }
    case LetArrayDestructureStmt(:final names, :final elemType, :final pos):
      if (!_isBefore(line, col, pos)) {
        for (final n in names) {
          if (n == null || n == '_') continue;
          map[n] = KlinCompletionItem(
            label: n,
            kind: KlinCompletionKind.variable,
            detail: elemType?.displayName,
          );
        }
      }
    case IfStmt(:final thenBlock, :final elseBranch):
      if (!nestedVisible) break;
      if (elseBranch != null) {
        if (!_isBefore(line, col, elseBranch.pos)) {
          _collectLocalsInStmt(
            elseBranch,
            line,
            col,
            map,
            nestedVisible: true,
          );
        } else if (!_isBefore(line, col, thenBlock.pos)) {
          _collectLocalsInBlock(thenBlock, line, col, map);
        }
      } else if (!_isBefore(line, col, thenBlock.pos)) {
        _collectLocalsInBlock(thenBlock, line, col, map);
      }
    case WhileStmt(:final body):
      if (!nestedVisible) break;
      _collectLocalsInBlock(body, line, col, map);
    case ForRangeStmt(
        :final name,
        :final body,
        :final resolvedType,
      ):
      if (!nestedVisible) break;
      map[name] = KlinCompletionItem(
        label: name,
        kind: KlinCompletionKind.variable,
        detail: resolvedType?.displayName ?? 'i32',
      );
      _collectLocalsInBlock(body, line, col, map);
    case ForCStmt(
        :final initName,
        :final initDecl,
        :final resolvedInitType,
        :final body,
      ):
      if (!nestedVisible) break;
      if (initDecl && initName != null) {
        map[initName] = KlinCompletionItem(
          label: initName,
          kind: KlinCompletionKind.variable,
          detail: resolvedInitType?.displayName,
        );
      }
      _collectLocalsInBlock(body, line, col, map);
    case BlockStmt(:final block):
      if (!nestedVisible) break;
      _collectLocalsInBlock(block, line, col, map);
    case DeferStmt(:final body):
      if (!nestedVisible) break;
      _collectLocalsInStmt(body, line, col, map, nestedVisible: true);
    case MatchStmt(:final arms):
      if (!nestedVisible) break;
      for (var i = 0; i < arms.length; i++) {
        final arm = arms[i];
        final start = arm.body.pos;
        if (_isBefore(line, col, start)) continue;
        final end = i + 1 < arms.length ? arms[i + 1].body.pos : null;
        if (end != null && !_isBefore(line, col, end)) continue;
        _collectLocalsInBlock(arm.body, line, col, map);
      }
    default:
      break;
  }
}

bool _isBefore(int line, int col, SourcePos pos) {
  if (line < pos.line) return true;
  if (line > pos.line) return false;
  return col < pos.col;
}

List<KlinCompletionItem> _memberCompletions(
  Program program,
  String before,
  int line,
  int col,
) {
  final receiver = _receiverNameBeforeDot(before);
  if (receiver == null) return const [];

  for (final e in program.enums) {
    if (e.name == receiver) {
      return [
        for (final v in e.variants)
          KlinCompletionItem(
            label: v.name,
            kind: KlinCompletionKind.enumMember,
            detail: e.name,
          ),
        ..._methodsForType(program, e.moduleName, e.name, isEnum: true),
        ..._associatedForType(program, e.name),
      ];
    }
  }
  for (final s in program.structs) {
    if (s.name == receiver) {
      return _associatedForType(program, s.name);
    }
  }

  final type = _typeOfName(program, receiver, line, col);
  if (type == null) return const [];
  return _membersForType(program, type);
}

List<KlinCompletionItem> _membersForType(Program program, KlinType type) {
  switch (type) {
    case StructType(:final moduleName, :final name):
      final decl = _findStruct(program, moduleName, name);
      if (decl == null) return const [];
      return [
        for (final f in decl.fields)
          KlinCompletionItem(
            label: f.name,
            kind: KlinCompletionKind.field,
            detail: f.resolvedType?.displayName ?? f.typeName,
          ),
        ..._methodsForType(program, moduleName, name, isEnum: false),
      ];
    case EnumType(:final moduleName, :final name):
      return _methodsForType(program, moduleName, name, isEnum: true);
    case ArrayType() || SliceType():
      return const [
        KlinCompletionItem(
          label: 'len',
          kind: KlinCompletionKind.field,
          detail: 'i32',
        ),
      ];
    case PtrType(:final pointee):
      return _membersForType(program, pointee);
    default:
      return const [];
  }
}

List<KlinCompletionItem> _methodsForType(
  Program program,
  String moduleName,
  String typeName, {
  required bool isEnum,
}) {
  final out = <KlinCompletionItem>[];
  for (final f in program.funcs) {
    final recv = f.receiver;
    if (recv == null) continue;
    final rt = recv.resolvedType;
    if (rt == null) continue;
    final ok = isEnum
        ? rt is EnumType &&
            rt.moduleName == moduleName &&
            rt.name == typeName
        : rt is StructType &&
            rt.moduleName == moduleName &&
            rt.name == typeName;
    if (!ok) continue;
    out.add(
      KlinCompletionItem(
        label: f.name,
        kind: KlinCompletionKind.method,
        detail: _funcDetail(f),
      ),
    );
  }
  return out;
}

List<KlinCompletionItem> _associatedForType(Program program, String typeName) {
  final out = <KlinCompletionItem>[];
  for (final f in program.funcs) {
    if (f.associatedType != typeName) continue;
    out.add(
      KlinCompletionItem(
        label: f.name,
        kind: KlinCompletionKind.method,
        detail: _funcDetail(f),
      ),
    );
  }
  return out;
}

StructDecl? _findStruct(Program program, String moduleName, String name) {
  for (final s in program.structs) {
    if (s.moduleName == moduleName && s.name == name) return s;
  }
  return null;
}

KlinType? _typeOfName(Program program, String name, int line, int col) {
  final f = _enclosingFunc(program, line, col);
  if (f == null) return null;
  return _bindingTypeInFunc(f, name, line, col);
}

KlinType? _bindingTypeInFunc(
  FuncDecl f,
  String name,
  int line,
  int col,
) {
  KlinType? found;
  if (f.receiver?.name == name) found = f.receiver!.resolvedType;
  for (final p in f.params) {
    if (p.name == name) found = p.resolvedType;
  }

  late void Function(Block) walkBlock;
  late void Function(Stmt, {required bool nestedVisible}) walkStmt;

  walkBlock = (Block block) {
    final stmts = block.stmts;
    for (var i = 0; i < stmts.length; i++) {
      final s = stmts[i];
      if (_isBefore(line, col, s.pos)) break;
      final endExclusive = i + 1 < stmts.length ? stmts[i + 1].pos : null;
      final nestedVisible =
          endExclusive == null || _isBefore(line, col, endExclusive);
      walkStmt(s, nestedVisible: nestedVisible);
    }
  };

  walkStmt = (Stmt s, {required bool nestedVisible}) {
    switch (s) {
      case LetStmt stmt:
        if (stmt.name == name &&
            (line > stmt.pos.line ||
                (line == stmt.pos.line && col > stmt.pos.col))) {
          found = stmt.resolvedType;
        }
      case LetDestructureStmt(:final binds, :final fieldTypes, :final pos):
        if (!_isBefore(line, col, pos)) {
          for (var i = 0; i < binds.length; i++) {
            if (binds[i] == name) {
              found = fieldTypes != null && i < fieldTypes.length
                  ? fieldTypes[i]
                  : null;
            }
          }
        }
      case LetArrayDestructureStmt(:final names, :final elemType, :final pos):
        if (!_isBefore(line, col, pos)) {
          for (final n in names) {
            if (n == name) found = elemType;
          }
        }
      case IfStmt(:final thenBlock, :final elseBranch):
        if (!nestedVisible) break;
        if (elseBranch != null) {
          if (!_isBefore(line, col, elseBranch.pos)) {
            walkStmt(elseBranch, nestedVisible: true);
          } else if (!_isBefore(line, col, thenBlock.pos)) {
            walkBlock(thenBlock);
          }
        } else if (!_isBefore(line, col, thenBlock.pos)) {
          walkBlock(thenBlock);
        }
      case WhileStmt(:final body):
        if (!nestedVisible) break;
        walkBlock(body);
      case ForRangeStmt stmt:
        if (!nestedVisible) break;
        if (stmt.name == name) {
          found = stmt.resolvedType ?? const PrimType(PrimKind.i32);
        }
        walkBlock(stmt.body);
      case ForCStmt(
          :final initName,
          :final initDecl,
          :final resolvedInitType,
          :final body,
        ):
        if (!nestedVisible) break;
        if (initDecl && initName == name) found = resolvedInitType;
        walkBlock(body);
      case BlockStmt(:final block):
        if (!nestedVisible) break;
        walkBlock(block);
      case DeferStmt(:final body):
        if (!nestedVisible) break;
        walkStmt(body, nestedVisible: true);
      case MatchStmt(:final arms):
        if (!nestedVisible) break;
        for (var i = 0; i < arms.length; i++) {
          final arm = arms[i];
          final start = arm.body.pos;
          if (_isBefore(line, col, start)) continue;
          final end = i + 1 < arms.length ? arms[i + 1].body.pos : null;
          if (end != null && !_isBefore(line, col, end)) continue;
          walkBlock(arm.body);
        }
      default:
        break;
    }
  };

  final body = f.body;
  if (body != null) walkBlock(body);
  return found;
}

String? _receiverNameBeforeDot(String before) {
  var i = before.length - 1;
  while (i >= 0 &&
      (before[i] == ' ' || before[i] == '\t' || before[i] == '\n')) {
    i--;
  }
  // Skip partial member after `.`
  if (i >= 0 && _isIdentContinue(before[i])) {
    while (i >= 0 && _isIdentContinue(before[i])) {
      i--;
    }
    while (i >= 0 && (before[i] == ' ' || before[i] == '\t')) {
      i--;
    }
  }
  if (i < 0 || before[i] != '.') return null;
  i--;
  while (i >= 0 && (before[i] == ' ' || before[i] == '\t')) {
    i--;
  }
  if (i < 0 || !_isIdentContinue(before[i])) return null;
  final end = i + 1;
  while (i >= 0 && _isIdentContinue(before[i])) {
    i--;
  }
  return before.substring(i + 1, end);
}

bool _endsWithDot(String before) {
  var i = before.length - 1;
  while (i >= 0 &&
      (before[i] == ' ' || before[i] == '\t' || before[i] == '\n')) {
    i--;
  }
  if (i < 0) return false;
  if (before[i] == '.') return true;
  while (i >= 0 && _isIdentContinue(before[i])) {
    i--;
  }
  while (i >= 0 && (before[i] == ' ' || before[i] == '\t')) {
    i--;
  }
  return i >= 0 && before[i] == '.';
}

String _identPrefix(String before) {
  if (before.isEmpty) return '';
  var i = before.length - 1;
  while (i >= 0 && _isIdentContinue(before[i])) {
    i--;
  }
  return before.substring(i + 1);
}

bool _isIdentContinue(String c) {
  if (c.isEmpty) return false;
  final ch = c.codeUnitAt(0);
  return (ch >= 97 && ch <= 122) ||
      (ch >= 65 && ch <= 90) ||
      (ch >= 48 && ch <= 57) ||
      ch == 95;
}

int _offsetOf(String text, int line, int col) {
  var offset = 0;
  var curLine = 1;
  while (curLine < line && offset < text.length) {
    final next = text.indexOf('\n', offset);
    if (next < 0) return text.length;
    offset = next + 1;
    curLine++;
  }
  final lineEnd = text.indexOf('\n', offset);
  final maxCol = lineEnd < 0 ? text.length - offset : lineEnd - offset;
  final c = (col - 1).clamp(0, maxCol);
  return offset + c;
}

List<KlinCompletionItem> _filterPrefix(
  List<KlinCompletionItem> items,
  String prefix,
) {
  if (prefix.isEmpty) return items;
  return [
    for (final i in items)
      if (i.label.startsWith(prefix)) i,
  ];
}

List<KlinCompletionItem> _dedupe(List<KlinCompletionItem> items) {
  final seen = <String>{};
  final out = <KlinCompletionItem>[];
  for (final i in items) {
    if (seen.add(i.label)) out.add(i);
  }
  return out;
}
