/// Source position (one-indexed line and column).
final class SourcePos {
  final int line;
  final int col;

  const SourcePos(this.line, this.col);

  @override
  String toString() => '$line:$col';
}

/// Error from `$fn` / `$peripherals_from_svd` expansion (before lex).
final class PreprocessError implements Exception {
  final String message;
  final SourcePos pos;
  final String path;

  const PreprocessError(this.message, this.pos, {this.path = '<input>'});

  @override
  String toString() => '$path:${pos.line}:${pos.col}: $message';
}

enum TokenKind {
  // keywords
  fn,
  struct,
  enum_,
  pub,
  module,
  import,
  let,
  mut,
  cast,
  volatile,
  true_,
  false_,
  if_,
  else_,
  while_,
  for_,
  in_,
  return_,
  break_,
  continue_,
  defer_,
  or_,
  error_,
  asm_,
  match_,
  when_,
  pick_,
  async_,
  await_,

  // literals and names
  ident,
  intLit,
  floatLit,
  string,

  // operators and punctuation
  plus,
  plusEqual, // `+=`
  minus,
  minusEqual, // `-=`
  star,
  starEqual, // `*=`
  slash,
  slashEqual, // `/=`
  percent,
  percentEqual, // `%=`
  ampersand, // unary address / binary bitwise AND
  ampAmp, // logical AND `&&`
  ampEqual, // `&=`
  pipe, // bitwise OR `|`
  pipePipe, // logical OR `||`
  pipeEqual, // `|=`
  caret, // bitwise XOR `^`
  caretEqual, // `^=`
  tilde, // bitwise NOT `~`
  atSign,
  colon,
  colonEqual, // :=
  equal,
  equalEqual,
  bang,
  bangEqual,
  less,
  lessLess, // `<<`
  lessLessEqual, // `<<=`
  lessEqual,
  greater,
  greaterGreater, // `>>`
  greaterGreaterEqual, // `>>=`
  greaterEqual,
  dot,
  dotDotLess, // ..<
  dotDotEqual, // ..=
  semicolon,
  comma,

  lParen,
  rParen,
  lBrace,
  rBrace,
  lBracket,
  rBracket,
  eof,
}

final class Token {
  final TokenKind kind;
  final String lexeme;
  final SourcePos pos;

  const Token(this.kind, this.lexeme, this.pos);

  @override
  String toString() => 'Token(${kind.name}, "$lexeme", $pos)';
}
