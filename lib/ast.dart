import 'token.dart';
import 'type.dart';

/// program := (struct | enum | func)+
final class Program {
  final List<StructDecl> structs;
  final List<FuncDecl> funcs;
  final List<EnumDecl> enums;
  final SourcePos pos;

  /// Per module: maps an `import X` alias to the loaded file’s actual `module` name.
  final Map<String, Map<String, String>> importAliases;

  const Program(
    this.structs,
    this.funcs,
    this.pos, {
    this.enums = const [],
    this.importAliases = const {},
  });
}

/// One `import` in a source unit (issue 048).
///   import geom              → spec `geom`,        qualifier `geom`
///   import geom oso          → spec `geom`,        qualifier `oso`
///   import "path/to/osa"     → spec `path/to/osa`, qualifier `osa`
///   import "path/to/osa" oso → spec `path/to/osa`, qualifier `oso`
final class ImportSpec {
  /// Resolution key: a module name (ident) or a relative path (string form).
  final String spec;

  /// True when written as `import "..."` (a path, may contain `/`).
  final bool isPath;

  /// Explicit local alias, if given.
  final String? alias;
  final SourcePos pos;

  const ImportSpec({
    required this.spec,
    required this.isPath,
    required this.alias,
    required this.pos,
  });

  /// Resolution key: [spec] without a trailing `.kl` (so `"a/b.kl"` and
  /// `"a/b"` resolve identically; the loader appends `.kl` itself).
  String get resolutionKey =>
      spec.endsWith('.kl') ? spec.substring(0, spec.length - 3) : spec;

  /// Last path segment of the resolution key.
  String get defaultQualifier {
    final key = resolutionKey;
    final slash = key.lastIndexOf('/');
    return slash >= 0 ? key.substring(slash + 1) : key;
  }

  /// The identifier used to qualify references in source.
  String get qualifier => alias ?? defaultQualifier;
}

/// One source unit before the project loader combines it.
final class ModuleUnit {
  final String? declaredName;
  final List<ImportSpec> imports;
  final List<StructDecl> structs;
  final List<EnumDecl> enums;
  final List<FuncDecl> funcs;

  /// Top-level declarations in source order (`StructDecl` / `EnumDecl` / `FuncDecl`).
  final List<Object> decls;
  final SourcePos pos;

  const ModuleUnit({
    required this.declaredName,
    required this.imports,
    required this.structs,
    required this.enums,
    required this.funcs,
    required this.decls,
    required this.pos,
  });
}

final class Attr {
  final String name;
  final String? arg;
  final SourcePos pos;

  const Attr(this.name, this.arg, this.pos);
}

final class StructDecl {
  final String name;
  final List<FieldDecl> fields;
  final List<Attr> attrs;
  final SourcePos pos;

  /// Position of the type name ident (may differ from [pos] on `struct`).
  final SourcePos namePos;
  bool isPub;
  String moduleName;
  String? sourcePath;

  StructDecl({
    required this.name,
    required this.fields,
    this.attrs = const [],
    required this.pos,
    SourcePos? namePos,
    this.isPub = false,
    this.moduleName = '',
    this.sourcePath,
  }) : namePos = namePos ?? pos;
}

/// enum Name [: BaseType] { Variant [= value], … }  (issue 072)
///
/// A C-like enum: a distinct named type over an integer base. Variants get
/// values 0,1,2,… unless an explicit `= value` restarts the sequence (C rules).
final class EnumDecl {
  final String name;
  final List<EnumVariant> variants;

  /// Base type spelling (e.g. `u8`), or `null` for the default `i32`.
  final String? baseTypeName;
  final List<Attr> attrs;
  final SourcePos pos;

  /// Position of the type name ident (may differ from [pos] on `enum`).
  final SourcePos namePos;
  bool isPub;
  String moduleName;
  String? sourcePath;

  /// Filled by the checker.
  KlinType? resolvedType;
  PrimType? baseType;

  EnumDecl({
    required this.name,
    required this.variants,
    required this.baseTypeName,
    this.attrs = const [],
    required this.pos,
    SourcePos? namePos,
    this.isPub = false,
    this.moduleName = '',
    this.sourcePath,
  }) : namePos = namePos ?? pos;
}

final class EnumVariant {
  final String name;

  /// Optional `= value` expression (integer literal in MVP).
  final Expr? value;
  final SourcePos pos;

  EnumVariant({
    required this.name,
    required this.value,
    required this.pos,
  });
}

/// name: primitive-type
final class FieldDecl {
  final String name;
  final String typeName;
  final SourcePos pos;

  /// Filled by the checker.
  KlinType? resolvedType;

  FieldDecl({
    required this.name,
    required this.typeName,
    required this.pos,
  });
}

/// fn [(mut)? name: Type] name(params): returnType? block
final class FuncDecl {
  final String name;
  final Receiver? receiver;

  /// For an associated (static) function `fn Type.name(…)`: the type name it is
  /// namespaced under (issue: associated functions). `null` for free functions
  /// and instance methods (which use [receiver]).
  final String? associatedType;
  final List<Param> params;
  final String? returnTypeName;
  final Block? body;
  final List<Attr> attrs;
  final SourcePos pos;

  /// Position of the function name ident (may differ from [pos] on `fn`).
  final SourcePos namePos;

  /// Issue 029 phase 4: `async fn` — lowered to state struct + `poll` in emit.
  final bool isAsync;
  bool isPub;
  String moduleName;
  String? sourcePath;

  /// Filled by the checker.
  KlinType? resolvedReturnType;

  FuncDecl({
    required this.name,
    required this.receiver,
    required this.params,
    required this.returnTypeName,
    required this.body,
    required this.pos,
    SourcePos? namePos,
    this.associatedType,
    this.attrs = const [],
    this.isAsync = false,
    this.isPub = false,
    this.moduleName = '',
    this.sourcePath,
  }) : namePos = namePos ?? pos;
}

final class Receiver {
  final String name;
  final String typeName;
  final bool isMut;
  final SourcePos pos;

  /// Filled by the checker.
  KlinType? resolvedType;

  Receiver({
    required this.name,
    required this.typeName,
    required this.isMut,
    required this.pos,
  });
}

/// name: type
final class Param {
  final String name;
  final String typeName;
  final SourcePos pos;

  /// Filled by the checker.
  KlinType? resolvedType;

  Param({
    required this.name,
    required this.typeName,
    required this.pos,
  });
}

final class Block {
  final List<Stmt> stmts;
  final SourcePos pos;

  const Block(this.stmts, this.pos);
}

sealed class Stmt {
  SourcePos get pos;
}

final class AsmStmt extends Stmt {
  final String code;
  final SourcePos pos;

  AsmStmt(this.code, this.pos);
}

/// let [mut] name [: type] [= expr]
/// or short decl: name := expr  (≡ let mut name = expr)
final class LetStmt extends Stmt {
  final bool isMut;
  final String name;
  final String? typeName;
  final Expr? init;
  final SourcePos pos;

  /// True when written as `name := expr` (sugar for `let mut`).
  final bool shortDecl;

  /// Filled by the checker.
  KlinType? resolvedType;

  LetStmt({
    required this.isMut,
    required this.name,
    required this.typeName,
    required this.init,
    required this.pos,
    this.shortDecl = false,
  });
}

/// Struct destructuring declaration (issue 056, phase A + D rename):
///   let { x, y } = expr
///   let mut { x, y } = expr
///   let { x: px, y: py } = expr   // rename (phase D)
/// Lowers to a sequence of plain field reads (`.field`) — no hidden cost.
final class LetDestructureStmt extends Stmt {
  final bool isMut;

  /// Struct field names to read, in declaration order.
  final List<String> fields;

  /// Local binding names, parallel to [fields] (equal to the field name unless
  /// renamed with `field: local`).
  final List<String> binds;

  /// The struct value being destructured; evaluated once.
  final Expr source;
  final SourcePos pos;

  /// Filled by the checker.
  KlinType? sourceType;
  List<KlinType>? fieldTypes;

  LetDestructureStmt({
    required this.isMut,
    required this.fields,
    required this.binds,
    required this.source,
    required this.pos,
  });
}

/// Fixed-array destructuring declaration (issue 056, phase C + D skip):
///   let [a, b] = xs        // xs : [2]T
///   let mut [a, b] = xs
///   let [_, _, c] = xs     // `_` skips a position (phase D)
/// Only fixed-length arrays `[N]T` with `N` == number of patterns. Lowers to
/// positional reads (`xs[i]`) or, for an array literal source, element-wise
/// binds — no hidden cost.
final class LetArrayDestructureStmt extends Stmt {
  final bool isMut;

  /// Binding names in positional order (index i binds element i). A `null`
  /// entry is a `_` skip — that element is not bound.
  final List<String?> names;

  /// The array value being destructured; a name is indexed in place, an array
  /// literal binds element-wise.
  final Expr source;
  final SourcePos pos;

  /// Filled by the checker (element type of the source array).
  KlinType? elemType;

  LetArrayDestructureStmt({
    required this.isMut,
    required this.names,
    required this.source,
    required this.pos,
  });
}

/// `target = expr` or compound `target op= expr` (arithmetic `+=`…`%=` and
/// bitwise `&=`…`>>=`). Target is a NameExpr / FieldExpr / IndexExpr / …
final class AssignStmt extends Stmt {
  final Expr target;
  final Expr value;
  final SourcePos pos;

  /// Binary operator without `=` when this is a compound assign (`+`, `&`,
  /// `<<`, …); `null` for plain `=`.
  final String? compoundOp;

  AssignStmt({
    required this.target,
    required this.value,
    required this.pos,
    this.compoundOp,
  });
}

/// Multi-assignment (issue 056, phase B):
///   a, b = b, a
/// Two or more assignable targets and an equal number of values. The values
/// are evaluated into temps before any target is written, so a swap works.
final class MultiAssignStmt extends Stmt {
  final List<Expr> targets;
  final List<Expr> values;
  final SourcePos pos;

  MultiAssignStmt({
    required this.targets,
    required this.values,
    required this.pos,
  });
}

/// Bare struct destructuring assignment to existing places (issue 056, phase A′):
///   { x, y } = p
///   { x: obj.a, y: b } = p
/// Assigns `source.field` to each target lvalue. The source is copied once, so
/// a target may safely alias it.
final class StructAssignStmt extends Stmt {
  final List<String> fields;

  /// Assignable target per field (defaults to a variable named like the field).
  final List<Expr> targets;
  final Expr source;
  final SourcePos pos;

  /// Filled by the checker.
  KlinType? sourceType;
  List<KlinType>? fieldTypes;

  StructAssignStmt({
    required this.fields,
    required this.targets,
    required this.source,
    required this.pos,
  });
}


/// call := ident "(" (expr ("," expr)*)? ")"
final class CallStmt extends Stmt {
  final String? moduleName;
  final String callee;
  final List<Expr> args;
  final SourcePos pos;
  String? resolvedCallee;

  /// When set, this is `eventloop.spawn(&ex, async_fn)` — emit uses init/poll
  /// wrappers for [asyncSpawnFn] (issue 029).
  String? asyncSpawnFn;

  /// Callee definition (LSP).
  ResolvedDef? resolvedDef;

  CallStmt({
    this.moduleName,
    required this.callee,
    required this.args,
    required this.pos,
  });
}

final class MethodCallStmt extends Stmt {
  final MethodCallExpr call;

  MethodCallStmt(this.call);

  @override
  SourcePos get pos => call.pos;
}

/// Statement form of `expr.await` inside an `async fn`.
final class AwaitStmt extends Stmt {
  final AwaitExpr expr;

  AwaitStmt(this.expr);

  @override
  SourcePos get pos => expr.pos;
}

/// if cond block [else (block | if)]
final class IfStmt extends Stmt {
  final Expr cond;
  final Block thenBlock;
  final Stmt? elseBranch; // BlockStmt or IfStmt
  final SourcePos pos;

  IfStmt({
    required this.cond,
    required this.thenBlock,
    required this.elseBranch,
    required this.pos,
  });
}

/// while cond block
final class WhileStmt extends Stmt {
  final Expr cond;
  final Block body;
  final SourcePos pos;

  WhileStmt({
    required this.cond,
    required this.body,
    required this.pos,
  });
}

/// for name in start..<end block
final class ForRangeStmt extends Stmt {
  final String name;
  final Expr start;
  final Expr endExclusive;
  final Block body;
  final SourcePos pos;

  /// Loop variable type, filled by the checker.
  KlinType? resolvedType;

  ForRangeStmt({
    required this.name,
    required this.start,
    required this.endExclusive,
    required this.body,
    required this.pos,
  });
}

/// for [name = init | name := init]; [cond]; [post] block
///
/// Init introduces mutable variable `name` (`=` or `:=`).
/// Post is an optional `name = expr` assignment.
final class ForCStmt extends Stmt {
  final String? initName;
  final Expr? initExpr;
  final Expr? cond;
  final String? postName;
  final Expr? postExpr;
  final Block body;
  final SourcePos pos;

  /// Initializer variable type, filled by the checker.
  KlinType? resolvedInitType;

  ForCStmt({
    required this.initName,
    required this.initExpr,
    required this.cond,
    required this.postName,
    required this.postExpr,
    required this.body,
    required this.pos,
  });
}

/// return [expr]
final class ReturnStmt extends Stmt {
  final Expr? value;
  final SourcePos pos;

  ReturnStmt({required this.value, required this.pos});
}

final class BreakStmt extends Stmt {
  final SourcePos pos;

  BreakStmt(this.pos);
}

final class ContinueStmt extends Stmt {
  final SourcePos pos;

  ContinueStmt(this.pos);
}

/// defer stmt: execute `body` when leaving the current block.
final class DeferStmt extends Stmt {
  final Stmt body;
  final SourcePos pos;

  DeferStmt({required this.body, required this.pos});
}

/// Nested block: a separate scope.
final class BlockStmt extends Stmt {
  final Block block;

  BlockStmt(this.block);

  @override
  SourcePos get pos => block.pos;
}

/// `match subject { arms }` — statement form (default break, no fallthrough).
final class MatchStmt extends Stmt {
  final Expr subject;
  final List<MatchStmtArm> arms;
  final SourcePos pos;

  MatchStmt({required this.subject, required this.arms, required this.pos});
}

final class MatchStmtArm {
  final MatchPattern pattern;
  /// Optional `when <bool expr>` guard; null means no guard.
  final Expr? when;
  final Block body;

  MatchStmtArm({required this.pattern, this.when, required this.body});
}

/// A single arm's pattern: literal group, inclusive range, relational,
/// wildcard (`_`), or `else`.
sealed class MatchPattern {
  SourcePos get pos;
}

/// `1, 2, 3`
final class LitPattern extends MatchPattern {
  final List<Expr> values;
  @override
  final SourcePos pos;

  LitPattern(this.values, this.pos);
}

/// `4..=10` (inclusive on both ends)
final class RangePattern extends MatchPattern {
  final Expr start;
  final Expr endInclusive;
  @override
  final SourcePos pos;

  RangePattern(this.start, this.endInclusive, this.pos);
}

/// `> 0`, `>= n`, `< 0`, `<= 0`, `!= 0`
final class RelPattern extends MatchPattern {
  /// One of `>`, `>=`, `<`, `<=`, `!=`.
  final String op;
  final Expr rhs;
  @override
  final SourcePos pos;

  RelPattern(this.op, this.rhs, this.pos);
}

/// `_` — always matches the subject; requires a `when` guard on the arm.
final class WildPattern extends MatchPattern {
  @override
  final SourcePos pos;

  WildPattern(this.pos);
}

/// `else`
final class ElsePattern extends MatchPattern {
  @override
  final SourcePos pos;

  ElsePattern(this.pos);
}

sealed class Expr {
  SourcePos get pos;

  /// Filled by the checker.
  KlinType? resolvedType;

  /// When an array expression is used as `[]T`, emission wraps it in a slice.
  ArrayType? arrayToSliceFrom;
}

/// Definition site for LSP go-to-definition / hover (issue 086 follow-up).
///
/// [path] is null when the definition is in the same analysis unit / unknown
/// (single-file analyze without `loadProject`).
final class ResolvedDef {
  final SourcePos pos;
  final String? path;

  const ResolvedDef(this.pos, [this.path]);
}

final class IntLit extends Expr {
  final String lexeme;
  final SourcePos pos;

  IntLit(this.lexeme, this.pos);
}

final class FloatLit extends Expr {
  final String lexeme;
  final SourcePos pos;

  FloatLit(this.lexeme, this.pos);
}

final class BoolLit extends Expr {
  final bool value;
  final SourcePos pos;

  BoolLit(this.value, this.pos);
}

final class StringLit extends Expr {
  final String value;
  final SourcePos pos;

  StringLit(this.value, this.pos);
}

/// Literal `$` in interpolated strings (lexer escape `\$`).
const String kInterpEscapedDollar = '\u{E000}';

sealed class InterpPart {}

final class InterpText extends InterpPart {
  final String text;
  InterpText(this.text);
}

final class InterpSlot extends InterpPart {
  final Expr expr;

  /// Raw format after `:`, or `null` for a default from the slot type.
  final String? formatRaw;

  /// Filled by the checker: printf specifier (e.g. `%d`), unused when [trimFrac].
  String? printfSpec;

  /// `0.###` style — emit via `klin_fmt_trim_frac` + `%s`.
  bool trimFrac = false;
  int trimFracDigits = 0;

  InterpSlot(this.expr, this.formatRaw);
}

/// `"hi $name"` / `"${n:%d}"` — print-only in MVP (sink → `printf`).
final class InterpolatedStringExpr extends Expr {
  final List<InterpPart> parts;
  final SourcePos pos;

  /// When true, emit appends `\n` (from `puts` / `io.println`).
  bool appendNewline = false;

  InterpolatedStringExpr(this.parts, this.pos);
}

final class NameExpr extends Expr {
  final String name;
  final SourcePos pos;

  /// Filled by the checker: a mut receiver is emitted as a pointer (`->`).
  bool isPtrReceiver = false;

  /// Top-level function used as a value (fn-pointer decay); C symbol to emit.
  String? resolvedFnCName;

  /// Binding / function definition (LSP).
  ResolvedDef? resolvedDef;

  NameExpr(this.name, this.pos);
}

final class FieldExpr extends Expr {
  final Expr object;
  final String name;
  final SourcePos pos;

  /// Filled by the checker when `object.name` is an enum constant
  /// (`Color.Red`): the C constant to emit instead of a field access.
  String? enumConstCName;

  /// Field or enum-variant definition (LSP).
  ResolvedDef? resolvedDef;

  FieldExpr({
    required this.object,
    required this.name,
    required this.pos,
  });
}

final class MethodCallExpr extends Expr {
  final Expr receiver;
  final String name;
  final List<Expr> args;
  final SourcePos pos;

  /// Filled by the checker.
  String? mangledName;
  bool receiverByRef = false;

  /// True when the "receiver" is a type name and this is an associated
  /// (static) function call `Type.func(…)` — emitted with no receiver argument.
  bool isAssociated = false;

  /// Method / associated-function definition (LSP).
  ResolvedDef? resolvedDef;

  MethodCallExpr({
    required this.receiver,
    required this.name,
    required this.args,
    required this.pos,
  });
}

final class StructLitExpr extends Expr {
  final String? moduleName;
  final String typeName;
  final Map<String, Expr>? namedFields;
  final List<Expr>? positionalFields;
  final SourcePos pos;

  StructLitExpr.named({
    this.moduleName,
    required this.typeName,
    required Map<String, Expr> fields,
    required this.pos,
  })  : namedFields = fields,
        positionalFields = null;

  StructLitExpr.positional({
    this.moduleName,
    required this.typeName,
    required List<Expr> fields,
    required this.pos,
  })  : namedFields = null,
        positionalFields = fields;
}

/// call := ident "(" (expr ("," expr)*)? ")"
final class CallExpr extends Expr {
  final String? moduleName;
  final String callee;
  final List<Expr> args;
  final SourcePos pos;
  String? resolvedCallee;

  /// Call through a fn-pointer variable (not a known top-level function).
  bool isFnPtrCall = false;

  /// When set, emit rewrites to `spawn(ex, fn_poll_erased, fn_init_erased)`.
  String? asyncSpawnFn;

  /// Callee definition (LSP); null for builtins / unknown FFI.
  ResolvedDef? resolvedDef;

  CallExpr({
    this.moduleName,
    required this.callee,
    required this.args,
    required this.pos,
  });
}

final class UnaryExpr extends Expr {
  final String op;
  final Expr operand;
  final SourcePos pos;

  UnaryExpr(this.op, this.operand, this.pos);
}

final class IndexExpr extends Expr {
  final Expr object;
  final Expr index;
  final SourcePos pos;

  IndexExpr({
    required this.object,
    required this.index,
    required this.pos,
  });
}

final class SliceFromExpr extends Expr {
  final Expr array;
  final SourcePos pos;

  SliceFromExpr({required this.array, required this.pos});
}

final class ArrayLitExpr extends Expr {
  final List<Expr> elements;
  final SourcePos pos;

  ArrayLitExpr({required this.elements, required this.pos});
}

final class CastExpr extends Expr {
  final String typeName;
  final Expr expr;
  final SourcePos pos;

  CastExpr({
    required this.typeName,
    required this.expr,
    required this.pos,
  });
}

final class BinaryExpr extends Expr {
  final Expr left;
  final String op;
  final Expr right;
  final SourcePos pos;

  BinaryExpr(this.left, this.op, this.right, this.pos);
}

final class GroupExpr extends Expr {
  final Expr inner;
  final SourcePos pos;

  GroupExpr(this.inner, this.pos);
}

/// `error(code)`: constructs the error branch of a `!T`.
/// In a function returning `!T`, that is the return type. Elsewhere
/// (issue 132) a `match` / typed `!T` context supplies the ok type.
final class ErrorExpr extends Expr {
  final Expr code;
  final SourcePos pos;

  ErrorExpr(this.code, this.pos);
}

/// Postfix `result!`: returns OK or propagates ERR from the function.
final class PropagateExpr extends Expr {
  final Expr result;
  final SourcePos pos;

  PropagateExpr(this.result, this.pos);
}

/// Postfix `.await` (issue 029). Operand is an async call or a pollable value.
final class AwaitExpr extends Expr {
  final Expr operand;
  final SourcePos pos;

  /// Filled by checker: async callee mangled base when operand is `async_fn(...)`.
  String? asyncCallee;

  /// Filled by checker: mangled `Type_poll` when operand is a pollable future.
  String? pollMangled;

  /// True when poll takes `*mut` / by-ref receiver.
  bool pollByRef = true;

  AwaitExpr(this.operand, this.pos);
}

/// Error branch body of `or`: statements and a required final value.
final class OrBlock {
  final List<Stmt> stmts;
  final Expr value;
  final SourcePos pos;

  const OrBlock(this.stmts, this.value, this.pos);
}

/// `result or { stmts; value }`.
final class OrExpr extends Expr {
  final Expr result;
  final OrBlock fallback;
  final SourcePos pos;

  OrExpr(this.result, this.fallback, this.pos);
}

/// `match subject { arm { value } … }` — expression form. Only valid as a
/// `let` initializer or assignment RHS (it lowers to statements in emission).
final class MatchExpr extends Expr {
  final Expr subject;
  final List<MatchExprArm> arms;
  final SourcePos pos;

  MatchExpr({required this.subject, required this.arms, required this.pos});
}

/// `pick cond { thenExpr } { elseExpr }` — expression form of a two-way
/// choice. Emits as C ternary `(cond ? thenExpr : elseExpr)`.
final class PickExpr extends Expr {
  final Expr cond;
  final Expr thenExpr;
  final Expr elseExpr;
  final SourcePos pos;

  PickExpr({
    required this.cond,
    required this.thenExpr,
    required this.elseExpr,
    required this.pos,
  });
}

final class MatchExprArm {
  final MatchPattern pattern;
  /// Optional `when <bool expr>` guard; null means no guard.
  final Expr? when;
  final Expr body;

  MatchExprArm({required this.pattern, this.when, required this.body});
}
